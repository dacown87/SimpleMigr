import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import '../data/dates.dart';

class GeoPlace {
  const GeoPlace({required this.name, required this.lat, required this.lon});

  final String name;
  final double lat;
  final double lon;

  Map<String, Object> toJson() => {'name': name, 'lat': lat, 'lon': lon};

  static GeoPlace? fromJson(Map<String, dynamic> j) => j['name'] is String
      ? GeoPlace(
          name: j['name'] as String,
          lat: (j['lat'] as num).toDouble(),
          lon: (j['lon'] as num).toDouble(),
        )
      : null;
}

/// Wetterdaten von Open-Meteo.com (CC BY 4.0, kein Schlüssel, nicht-kommerziell).
abstract class WeatherApi {
  Future<List<GeoPlace>> searchPlaces(String query);

  /// Tageswerte für [start]..[end] (einschließlich).
  Future<List<DayWeatherCompanion>> fetchDaily(GeoPlace place, DateTime start, DateTime end);
}

const _dailyVars = 'pressure_msl_mean,pressure_msl_min,pressure_msl_max,'
    'temperature_2m_min,temperature_2m_max,relative_humidity_2m_mean,'
    'precipitation_sum,wind_speed_10m_max';

/// Antwort von Open-Meteo (`daily`-Block) in Tabellenzeilen umwandeln.
List<DayWeatherCompanion> parseDaily(Map<String, dynamic> json) {
  final daily = json['daily'] as Map<String, dynamic>;
  final times = (daily['time'] as List).cast<String>();
  double? at(String name, int i) {
    final list = daily[name] as List?;
    final v = list == null ? null : list[i];
    return v is num ? v.toDouble() : null;
  }

  return [
    for (var i = 0; i < times.length; i++)
      if (at('pressure_msl_mean', i) != null) // Tage ohne Daten überspringen
        DayWeatherCompanion(
          date: Value(times[i]),
          pressureMean: Value(at('pressure_msl_mean', i)),
          pressureMin: Value(at('pressure_msl_min', i)),
          pressureMax: Value(at('pressure_msl_max', i)),
          tempMin: Value(at('temperature_2m_min', i)),
          tempMax: Value(at('temperature_2m_max', i)),
          humidity: Value(at('relative_humidity_2m_mean', i)),
          precipitation: Value(at('precipitation_sum', i)),
          windMax: Value(at('wind_speed_10m_max', i)),
        ),
  ];
}

class OpenMeteoApi implements WeatherApi {
  OpenMeteoApi({HttpClient? client, DateTime Function()? clock})
      : _client = client ?? HttpClient(),
        _clock = clock ?? DateTime.now {
    _client.connectionTimeout = const Duration(seconds: 10);
  }

  final HttpClient _client;
  final DateTime Function() _clock;

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final req = await _client.getUrl(uri);
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: uri);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  @override
  Future<List<GeoPlace>> searchPlaces(String query) async {
    final json = await _get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '6',
      'language': 'de',
      'format': 'json',
    }));
    return [
      for (final r in (json['results'] as List? ?? const []).cast<Map<String, dynamic>>())
        GeoPlace(
          name: [r['name'], r['admin1'], r['country']].whereType<String>().join(', '),
          lat: (r['latitude'] as num).toDouble(),
          lon: (r['longitude'] as num).toDouble(),
        ),
    ];
  }

  @override
  Future<List<DayWeatherCompanion>> fetchDaily(GeoPlace place, DateTime start, DateTime end) async {
    // Das Archiv hinkt ca. 5 Tage hinterher; neuere Tage kommen aus der Vorhersage-API.
    final archiveEnd = dateOnly(_clock()).subtract(const Duration(days: 6));
    final out = <DayWeatherCompanion>[];
    Future<void> load(String host, String path, DateTime s, DateTime e) async {
      final json = await _get(Uri.https(host, path, {
        'latitude': '${place.lat}',
        'longitude': '${place.lon}',
        'daily': _dailyVars,
        'timezone': 'auto',
        'start_date': toKey(s),
        'end_date': toKey(e),
      }));
      out.addAll(parseDaily(json));
    }

    if (!start.isAfter(archiveEnd)) {
      await load('archive-api.open-meteo.com', '/v1/archive', start,
          end.isAfter(archiveEnd) ? archiveEnd : end);
    }
    if (end.isAfter(archiveEnd)) {
      final s = start.isAfter(archiveEnd) ? start : archiveEnd.add(const Duration(days: 1));
      await load('api.open-meteo.com', '/v1/forecast', s, end);
    }
    return out;
  }
}
