import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/dates.dart';
import '../data/repository.dart';
import 'weather_api.dart';

/// Gewählter Ort für die Wetterdaten (lokal gespeichert).
class LocationStore extends ValueNotifier<GeoPlace?> {
  LocationStore._(this._prefs, super.value);

  static const _key = 'weather_place';
  final SharedPreferences _prefs;

  static Future<LocationStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    GeoPlace? place;
    if (raw != null) {
      try {
        place = GeoPlace.fromJson((jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return LocationStore._(prefs, place);
  }

  Future<void> set(GeoPlace? place) async {
    if (place == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jsonEncode(place.toJson()));
    }
    value = place;
  }
}

/// Holt fehlendes Wetter rund um Migränetage: beim Start, beim Zurückkehren in
/// die App, nach Änderungen an den Einträgen und wenn der Ort wechselt.
/// Ohne Ort oder ohne Internet passiert nichts; der nächste Auslöser versucht es erneut.
class WeatherSync with WidgetsBindingObserver {
  WeatherSync({
    required this.repo,
    required this.api,
    required this.location,
    this.clock = DateTime.now,
    this.debounce = const Duration(seconds: 3),
  });

  final Repository repo;
  final WeatherApi api;
  final ValueListenable<GeoPlace?> location;
  final DateTime Function() clock;
  final Duration debounce;

  StreamSubscription<void>? _sub;
  Timer? _timer;
  bool _running = false;
  bool _again = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    location.addListener(_schedule);
    _sub = repo.changes.listen((_) => _schedule());
    _schedule();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    location.removeListener(_schedule);
    _sub?.cancel();
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, run);
  }

  /// Ein Abgleich; läuft nie doppelt. Gibt die Zahl geholter Tage zurück.
  Future<int> run() async {
    if (_running) {
      _again = true;
      return 0;
    }
    final place = location.value;
    if (place == null) return 0;
    _running = true;
    var fetched = 0;
    try {
      final days = await repo.missingWeatherDays(clock());
      for (final range in _ranges(days)) {
        final rows = await api.fetchDaily(place, range.$1, range.$2);
        await repo.saveWeather(rows);
        fetched += rows.length;
      }
    } catch (_) {
      // offline oder Dienst gerade nicht erreichbar: später erneut
    } finally {
      _running = false;
    }
    if (_again) {
      _again = false;
      _schedule();
    }
    return fetched;
  }

  static List<(DateTime, DateTime)> _ranges(List<DateTime> days) {
    final out = <(DateTime, DateTime)>[];
    for (final d in days) {
      if (out.isNotEmpty && toKey(previousDay(d)) == toKey(out.last.$2)) {
        out[out.length - 1] = (out.last.$1, d);
      } else {
        out.add((d, d));
      }
    }
    return out;
  }
}
