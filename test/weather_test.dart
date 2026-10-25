import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/dates.dart';
import 'package:simplemigr/data/repository.dart';
import 'package:simplemigr/ui/theme.dart';
import 'package:simplemigr/ui/weather_tile.dart';
import 'package:simplemigr/weather/weather_api.dart';
import 'package:simplemigr/weather/weather_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

class FakeApi implements WeatherApi {
  final calls = <(DateTime, DateTime)>[];
  bool fail = false;

  @override
  Future<List<GeoPlace>> searchPlaces(String q) async {
    if (fail) throw Exception('offline');
    return const [GeoPlace(name: 'München, Bayern, Deutschland', lat: 48.1, lon: 11.6)];
  }

  @override
  Future<List<DayWeatherCompanion>> fetchDaily(GeoPlace p, DateTime s, DateTime e) async {
    if (fail) throw Exception('offline');
    calls.add((s, e));
    return [
      for (var d = s; !d.isAfter(e); d = DateTime(d.year, d.month, d.day + 1))
        DayWeatherCompanion.insert(date: toKey(d), pressureMean: const Value(1013.0)),
    ];
  }
}

const place = GeoPlace(name: 'München', lat: 48.1, lon: 11.6);
final today = DateTime(2026, 10, 25);

void main() {
  late AppDatabase db;
  late Repository repo;
  late int migraine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
    migraine = (await db.select(db.symptoms).get()).firstWhere((s) => s.key == 'migraine').id;
  });
  tearDown(() => db.close());

  Future<void> migraineOn(List<DateTime> days) async {
    for (final d in days) {
      await repo.setValue(d, migraine, 1);
    }
  }

  List<String> keys(List<DateTime> l) => l.map(toKey).toList();

  test('parseDaily: Open-Meteo-Antwort, Tage ohne Daten fehlen', () {
    final rows = parseDaily({
      'daily': {
        'time': ['2026-10-24', '2026-10-25'],
        'pressure_msl_mean': [1010.3, null],
        'pressure_msl_min': [1009.0, null],
        'pressure_msl_max': [1012.0, null],
        'temperature_2m_min': [7.5, null],
        'temperature_2m_max': [12.1, null],
        'relative_humidity_2m_mean': [70, null],
        'precipitation_sum': [0.4, null],
        'wind_speed_10m_max': [21.1, null],
      }
    });
    expect(rows, hasLength(1));
    expect(rows.single.date.value, '2026-10-24');
    expect(rows.single.humidity.value, 70.0);
  });

  test('Fehlende Tage: 3 vor bis 2 nach dem Lauf, nur abgeschlossene Tage', () async {
    await migraineOn([DateTime(2026, 9, 10), DateTime(2026, 9, 11)]);
    expect(keys(await repo.missingWeatherDays(today)),
        ['2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10', '2026-09-11', '2026-09-12', '2026-09-13']);
  });

  test('Fehlende Tage: Zukunft und heute werden ausgelassen', () async {
    await migraineOn([DateTime(2026, 10, 24), DateTime(2026, 10, 25)]);
    final days = keys(await repo.missingWeatherDays(today));
    expect(days.last, '2026-10-24');
    expect(days, isNot(contains('2026-10-25')));
  });

  test('Fehlende Tage: vorhandenes Wetter wird nicht erneut geholt', () async {
    await migraineOn([DateTime(2026, 9, 10)]);
    await repo.saveWeather([
      DayWeatherCompanion.insert(date: '2026-09-09', pressureMean: const Value(1000.0)),
    ]);
    expect(keys(await repo.missingWeatherDays(today)), isNot(contains('2026-09-09')));
  });

  test('Fehlende Tage: ohne Migräne nichts, zwei Attacken zwei Fenster', () async {
    expect(await repo.missingWeatherDays(today), isEmpty);
    await migraineOn([DateTime(2026, 8, 1), DateTime(2026, 9, 1)]);
    final days = await repo.missingWeatherDays(today);
    expect(days, hasLength(12)); // 2 × (3 + 1 + 2)
  });

  test('WeatherSync: holt Bereiche einmal, danach nichts mehr; ohne Ort nichts', () async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi();
    final loc = await LocationStore.load();
    final sync = WeatherSync(repo: repo, api: api, location: loc, clock: () => today);
    await migraineOn([DateTime(2026, 9, 10)]);

    expect(await sync.run(), 0); // kein Ort
    expect(api.calls, isEmpty);

    await loc.set(place);
    expect(await sync.run(), 6);
    expect(api.calls, hasLength(1));
    expect(toKey(api.calls.single.$1), '2026-09-07');
    expect(toKey(api.calls.single.$2), '2026-09-12');

    expect(await sync.run(), 0);
    expect(api.calls, hasLength(1));
    final day = await repo.getDay(DateTime(2026, 9, 10));
    expect(day.weather?.pressureMean, 1013.0);
  });

  test('WeatherSync: offline → keine Wirkung, später erneut', () async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi()..fail = true;
    final loc = await LocationStore.load();
    await loc.set(place);
    final sync = WeatherSync(repo: repo, api: api, location: loc, clock: () => today);
    await migraineOn([DateTime(2026, 9, 10)]);
    expect(await sync.run(), 0);
    expect(await db.select(db.dayWeather).get(), isEmpty);
    api.fail = false;
    expect(await sync.run(), 6);
  });

  test('LocationStore speichert den Ort dauerhaft', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await LocationStore.load();
    expect(a.value, isNull);
    await a.set(place);
    final b = await LocationStore.load();
    expect(b.value?.name, 'München');
    expect(b.value?.lat, 48.1);
    await b.set(null);
    expect((await LocationStore.load()).value, isNull);
  });

  test('Migration von Schema 1 auf 2: Daten bleiben, Wettertabelle entsteht', () async {
    final old = NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE symptoms (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
          'kind INTEGER NOT NULL, grp INTEGER NOT NULL, "key" TEXT NULL UNIQUE, '
          'sort_order INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)))');
      raw.execute('CREATE TABLE day_values (date TEXT NOT NULL, symptom_id INTEGER NOT NULL '
          'REFERENCES symptoms (id), value INTEGER NOT NULL, PRIMARY KEY (date, symptom_id))');
      raw.execute('CREATE TABLE day_meta (date TEXT NOT NULL, new_attack INTEGER NOT NULL DEFAULT 0 '
          'CHECK (new_attack IN (0, 1)), note TEXT NOT NULL DEFAULT \'\', PRIMARY KEY (date))');
      raw.execute("INSERT INTO symptoms (name, kind, grp, \"key\", sort_order) VALUES ('Migräne', 0, 0, 'migraine', 0)");
      raw.execute("INSERT INTO day_values VALUES ('2026-09-04', 1, 1)");
      raw.execute('PRAGMA user_version = 1');
    });
    final upgraded = AppDatabase(old);
    addTearDown(upgraded.close);
    expect(await upgraded.select(upgraded.dayValues).get(), hasLength(1));
    expect(await upgraded.select(upgraded.dayWeather).get(), isEmpty);
    await upgraded.into(upgraded.dayWeather).insert(
        DayWeatherCompanion.insert(date: '2026-09-04', pressureMean: const Value(1000.0)));
    expect(await upgraded.select(upgraded.dayWeather).get(), hasLength(1));
  });

  test('Monatsraster: Wetter inkl. Vortag des Monatsersten', () async {
    await repo.saveWeather([
      DayWeatherCompanion.insert(date: '2026-08-31', pressureMean: const Value(1020.0)),
      DayWeatherCompanion.insert(date: '2026-09-01', pressureMean: const Value(1014.0)),
    ]);
    final m = await repo.getMonth(2026, 9);
    expect(m.hasWeather, isTrue);
    expect(m.day(DateTime(2026, 9, 1)).pressureDelta, closeTo(-6.0, 1e-9));
    expect((await repo.getMonth(2026, 10)).hasWeather, isFalse);
  });

  dbWidgetTest('Ort wählen: Suche → Ergebnis antippen → gespeichert', (tester, env) async {
    SharedPreferences.setMockInitialValues({});
    final loc = (await tester.runAsync(LocationStore.load))!;
    final api = FakeApi();
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: WeatherPlaceTile(location: loc, api: api)),
    ));
    expect(find.text('nicht gesetzt – kein Wetter'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weather-place')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('place-field')), 'München');
    await tester.tap(find.byKey(const ValueKey('place-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('München, Bayern, Deutschland'));
    await tester.pumpAndSettle();
    expect(loc.value?.name, 'München, Bayern, Deutschland');
    expect(find.text('München, Bayern, Deutschland'), findsOneWidget);
  });

  dbWidgetTest('Ort wählen: Suche offline → Hinweis', (tester, env) async {
    SharedPreferences.setMockInitialValues({});
    final loc = (await tester.runAsync(LocationStore.load))!;
    final api = FakeApi()..fail = true;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: WeatherPlaceTile(location: loc, api: api)),
    ));
    await tester.tap(find.byKey(const ValueKey('weather-place')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('place-field')), 'x');
    await tester.tap(find.byKey(const ValueKey('place-search')));
    await tester.pumpAndSettle();
    expect(find.textContaining('fehlgeschlagen'), findsOneWidget);
    expect(loc.value, isNull);
  });
}
