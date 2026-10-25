import 'package:drift/drift.dart';

import 'attacks.dart';
import 'database.dart';
import 'dates.dart';

/// Alle Werte eines Tages. Fehlende Einträge bedeuten 0/false.
class DayData {
  const DayData({
    this.values = const {},
    this.newAttack = false,
    this.note = '',
    this.weather,
    this.prevPressure,
  });

  final Map<int, int> values; // symptomId -> Wert (nur ≠ 0)
  final bool newAttack;
  final String note;
  final WeatherDay? weather;

  /// Mittlerer Luftdruck des Vortags (für die Änderung).
  final double? prevPressure;

  int value(int symptomId) => values[symptomId] ?? 0;

  /// Änderung des mittleren Luftdrucks zum Vortag in hPa.
  double? get pressureDelta {
    final now = weather?.pressureMean;
    final before = prevPressure;
    return now == null || before == null ? null : now - before;
  }
}

class MonthData {
  const MonthData({
    required this.year,
    required this.month,
    required this.symptoms,
    required this.days,
    required this.migraineDays,
    required this.attacks,
    this.weather = const {},
  });

  final int year;
  final int month;

  /// Zeilen des Rasters: aktive Symptome plus archivierte mit Werten in diesem Monat.
  final List<Symptom> symptoms;
  final Map<String, DayData> days; // nur Tage mit Einträgen
  final int migraineDays;
  final int attacks;

  /// Wetter je Tag (inklusive Vortag des Monatsersten, für die Änderung).
  final Map<String, WeatherDay> weather;

  bool get hasWeather => weather.keys.any((k) => k.startsWith(
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}'));

  /// Tag mit Wetter und Luftdruckänderung (nur wenn Wetter vorliegt).
  DayData day(DateTime d) {
    final base = days[toKey(d)] ?? const DayData();
    final w = weather[toKey(d)];
    if (w == null) return base;
    return DayData(
      values: base.values,
      newAttack: base.newAttack,
      note: base.note,
      weather: w,
      prevPressure: weather[toKey(previousDay(d))]?.pressureMean,
    );
  }
}

class Repository {
  Repository(this.db);

  final AppDatabase db;

  Future<Symptom> _byKey(String key) =>
      (db.select(db.symptoms)..where((s) => s.key.equals(key))).getSingle();

  Future<int> _idOf(String key) async => (await _byKey(key)).id;

  /// Reaktion auf jede Änderung an einer der Tabellen.
  Stream<void> get changes => _changes();

  Stream<void> _changes() => db
      .customSelect('SELECT 1',
          readsFrom: {db.symptoms, db.dayValues, db.dayMeta, db.dayWeather})
      .watch()
      .map((_) {});

  // ── Symptome ────────────────────────────────────────────────

  Stream<List<Symptom>> watchSymptoms({bool includeArchived = false}) {
    final q = db.select(db.symptoms)
      ..orderBy([(s) => OrderingTerm.asc(s.sortOrder), (s) => OrderingTerm.asc(s.id)]);
    if (!includeArchived) q.where((s) => s.archived.equals(false));
    return q.watch();
  }

  Future<int> addSymptom(String name, SymptomGroup grp) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name fehlt');
    final maxOrder = db.symptoms.sortOrder.max();
    final row = await (db.selectOnly(db.symptoms)..addColumns([maxOrder])).getSingle();
    return db.into(db.symptoms).insert(SymptomsCompanion.insert(
          name: trimmed,
          kind: SymptomKind.flag,
          grp: grp,
          sortOrder: (row.read(maxOrder) ?? 0) + 1,
        ));
  }

  Future<void> renameSymptom(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name fehlt');
    await (db.update(db.symptoms)..where((s) => s.id.equals(id)))
        .write(SymptomsCompanion(name: Value(trimmed)));
  }

  /// Symptome mit Systemschlüssel können nicht archiviert werden.
  Future<void> setArchived(int id, bool archived) async {
    final s = await (db.select(db.symptoms)..where((t) => t.id.equals(id))).getSingle();
    if (s.key != null && archived) {
      throw StateError('Systemsymptom kann nicht archiviert werden');
    }
    await (db.update(db.symptoms)..where((t) => t.id.equals(id)))
        .write(SymptomsCompanion(archived: Value(archived)));
  }

  // ── Tag ─────────────────────────────────────────────────────

  Stream<DayData> watchDay(DateTime date) =>
      _changes().asyncMap((_) => _loadDay(toKey(date)));

  Future<DayData> _loadDay(String key) async {
    final rows = await (db.select(db.dayValues)..where((v) => v.date.equals(key))).get();
    final meta = await (db.select(db.dayMeta)..where((m) => m.date.equals(key))).getSingleOrNull();
    final w = await (db.select(db.dayWeather)..where((t) => t.date.equals(key))).getSingleOrNull();
    final prev = await (db.select(db.dayWeather)
          ..where((t) => t.date.equals(toKey(previousDay(fromKey(key))))))
        .getSingleOrNull();
    return DayData(
      values: {for (final r in rows) r.symptomId: r.value},
      newAttack: meta?.newAttack ?? false,
      note: meta?.note ?? '',
      weather: w,
      prevPressure: prev?.pressureMean,
    );
  }

  Future<DayData> getDay(DateTime date) => _loadDay(toKey(date));

  /// 0 löscht die Zeile. Migräne auf 0 setzt „neue Attacke“ des Tages zurück.
  Future<void> setValue(DateTime date, int symptomId, int value) async {
    final key = toKey(date);
    await db.transaction(() async {
      if (value == 0) {
        await (db.delete(db.dayValues)
              ..where((v) => v.date.equals(key) & v.symptomId.equals(symptomId)))
            .go();
        if (symptomId == await _idOf(SymptomKey.migraine)) {
          await _writeMeta(key, newAttack: false);
        }
      } else {
        await db.into(db.dayValues).insertOnConflictUpdate(
            DayValuesCompanion.insert(date: key, symptomId: symptomId, value: value));
      }
    });
  }

  Future<void> setNewAttack(DateTime date, bool value) =>
      _writeMeta(toKey(date), newAttack: value);

  Future<void> setNote(DateTime date, String note) =>
      _writeMeta(toKey(date), note: note);

  Future<void> _writeMeta(String key, {bool? newAttack, String? note}) async {
    await db.transaction(() async {
      final old =
          await (db.select(db.dayMeta)..where((m) => m.date.equals(key))).getSingleOrNull();
      final na = newAttack ?? old?.newAttack ?? false;
      final nt = note ?? old?.note ?? '';
      if (!na && nt.trim().isEmpty) {
        await (db.delete(db.dayMeta)..where((m) => m.date.equals(key))).go();
      } else {
        await db.into(db.dayMeta).insertOnConflictUpdate(
            DayMetaCompanion.insert(date: key, newAttack: Value(na), note: Value(nt)));
      }
    });
  }

  // ── Monat ───────────────────────────────────────────────────

  Stream<MonthData> watchMonth(int year, int month) =>
      _changes().asyncMap((_) => getMonth(year, month));

  Future<MonthData> getMonth(int year, int month) async {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month, daysInMonth(year, month));
    final from = toKey(previousDay(first)); // Vortag für Attacken über die Monatsgrenze
    final fromMonth = toKey(first);
    final to = toKey(last);

    final values = await (db.select(db.dayValues)
          ..where((v) => v.date.isBiggerOrEqualValue(from) & v.date.isSmallerOrEqualValue(to)))
        .get();
    final metas = await (db.select(db.dayMeta)
          ..where((m) => m.date.isBiggerOrEqualValue(fromMonth) & m.date.isSmallerOrEqualValue(to)))
        .get();
    final all = await (db.select(db.symptoms)
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder), (s) => OrderingTerm.asc(s.id)]))
        .get();

    final migraineId = all.firstWhere((s) => s.key == SymptomKey.migraine).id;
    final migraineDays = [
      for (final v in values)
        if (v.symptomId == migraineId && v.value != 0) fromKey(v.date),
    ];
    final slashDays = [
      for (final m in metas)
        if (m.newAttack) fromKey(m.date),
    ];

    final byDay = <String, Map<int, int>>{};
    for (final v in values) {
      if (v.date.compareTo(fromMonth) < 0) continue;
      (byDay[v.date] ??= {})[v.symptomId] = v.value;
    }
    final metaByDay = {for (final m in metas) m.date: m};
    final days = <String, DayData>{
      for (final k in {...byDay.keys, ...metaByDay.keys})
        k: DayData(
          values: byDay[k] ?? const {},
          newAttack: metaByDay[k]?.newAttack ?? false,
          note: metaByDay[k]?.note ?? '',
        ),
    };

    final usedIds = {for (final d in days.values) ...d.values.keys};
    final rows = [
      for (final s in all)
        if (!s.archived || usedIds.contains(s.id)) s,
    ];

    final weatherRows = await (db.select(db.dayWeather)
          ..where((w) => w.date.isBiggerOrEqualValue(from) & w.date.isSmallerOrEqualValue(to)))
        .get();

    return MonthData(
      weather: {for (final w in weatherRows) w.date: w},
      year: year,
      month: month,
      symptoms: rows,
      days: days,
      migraineDays: migraineDays.where((d) => d.month == month && d.year == year).length,
      attacks: attacksInMonth(year, month, migraineDays, slashDays),
    );
  }

  // ── Wetter ──────────────────────────────────────────────────

  /// Tage vor dem ersten und nach dem letzten Migränetag jeder Attacke, für die
  /// Wetter geholt wird (der erste Tag dient nur der Druckänderung).
  static const weatherDaysBefore = 3;
  static const weatherDaysAfter = 2;

  /// Tage rund um Migränetage ohne gespeichertes Wetter. Nur abgeschlossene
  /// Tage (vor [today]), aufsteigend.
  Future<List<DateTime>> missingWeatherDays(DateTime today) async {
    final migraineId = await _idOf(SymptomKey.migraine);
    final rows = await (db.select(db.dayValues)
          ..where((v) => v.symptomId.equals(migraineId) & v.value.equals(0).not())
          ..orderBy([(v) => OrderingTerm.asc(v.date)]))
        .get();
    final have = {for (final w in await db.select(db.dayWeather).get()) w.date};
    final cutoff = dateOnly(today);

    // Zusammenhängende Migränetage bilden einen Lauf.
    final runs = <(DateTime, DateTime)>[];
    for (final r in rows) {
      final d = fromKey(r.date);
      if (runs.isNotEmpty && toKey(runs.last.$2.add(const Duration(days: 1))) == r.date) {
        runs[runs.length - 1] = (runs.last.$1, d);
      } else {
        runs.add((d, d));
      }
    }

    final needed = <String>{};
    for (final (start, end) in runs) {
      final last = DateTime(end.year, end.month, end.day + weatherDaysAfter);
      for (var d = DateTime(start.year, start.month, start.day - weatherDaysBefore);
          !d.isAfter(last);
          d = DateTime(d.year, d.month, d.day + 1)) {
        if (d.isBefore(cutoff) && !have.contains(toKey(d))) needed.add(toKey(d));
      }
    }
    return (needed.toList()..sort()).map(fromKey).toList();
  }

  /// Löscht ein eigenes Symptom samt aller Einträge. Systemsymptome bleiben.
  Future<void> deleteSymptom(int id) async {
    final s = await (db.select(db.symptoms)..where((t) => t.id.equals(id))).getSingle();
    if (s.key != null) throw StateError('Systemsymptom kann nicht gelöscht werden');
    await db.transaction(() async {
      await (db.delete(db.dayValues)..where((v) => v.symptomId.equals(id))).go();
      await (db.delete(db.symptoms)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> saveWeather(Iterable<DayWeatherCompanion> rows) async {
    await db.batch((b) => b.insertAllOnConflictUpdate(db.dayWeather, rows.toList()));
  }
}
