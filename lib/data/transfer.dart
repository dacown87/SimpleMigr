import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';
import 'dates.dart';
import 'repository.dart';

/// Ein Symptom aus der Importdatei. [localId] ist gesetzt, wenn es lokal schon existiert;
/// sonst wird es beim Übernehmen angelegt.
class ImportSymptom {
  ImportSymptom(
    this.name,
    this.grp, {
    this.kind = SymptomKind.flag,
    this.key,
    this.archived = false,
    this.localId,
  });

  final String name;
  final SymptomGroup grp;
  final SymptomKind kind;
  final String? key;
  final bool archived;
  int? localId;
}

class ImportDay {
  /// Index in [ImportData.symptoms] -> Wert. Fehlende Symptome der Datei zählen als 0.
  final values = <int, int>{};

  /// `null` = unverändert lassen.
  bool? newAttack;
  String? note;
}

/// Gelesene Importdatei, noch nicht gespeichert.
class ImportData {
  ImportData({
    required this.isBackup,
    required this.symptoms,
    required this.days,
    this.weather = const [],
    this.description,
    this.ignoredColumns = const [],
    this.skippedRows = 0,
  });

  final bool isBackup;
  final List<ImportSymptom> symptoms;
  final Map<String, ImportDay> days;
  final List<DayWeatherCompanion> weather;
  final String? description;
  final List<String> ignoredColumns;

  /// Zeilen ohne lesbares Datum.
  final int skippedRows;

  List<ImportSymptom> get newSymptoms => [
    for (final s in symptoms)
      if (s.localId == null) s,
  ];

  (String, String)? get range {
    if (days.isEmpty) return null;
    final keys = days.keys.toList()..sort();
    return (keys.first, keys.last);
  }
}

class ImportFormatException implements Exception {
  ImportFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sicherung (JSON, alles inklusive Wetter und Beschreibung) und Tabelle
/// (CSV, eine Zeile pro Tag, Spalten = Symptome).
///
/// Beim Import gilt: Für jeden Tag aus der Datei ersetzen die Werte der Datei die
/// lokalen Werte der enthaltenen Symptome. Andere Tage bleiben unverändert.
class DataTransfer {
  DataTransfer(this.repo);

  final Repository repo;
  AppDatabase get db => repo.db;

  static const backupFormat = 'simplemigr-backup';
  static const _auraPrefix = 'Aura: ';
  static const _triggerPrefix = 'Auslöser: ';
  static const _medPrefix = 'Medikament: ';

  // ── Export ──────────────────────────────────────────────────

  Future<String> exportBackup({DateTime? now}) async {
    final symptoms = await db.select(db.symptoms).get();
    final values = await db.select(db.dayValues).get();
    final metas = await db.select(db.dayMeta).get();
    final weather = await db.select(db.dayWeather).get();
    return const JsonEncoder.withIndent(' ').convert({
      'format': backupFormat,
      'version': 1,
      'created': (now ?? DateTime.now()).toIso8601String(),
      'description': await repo.getDescription(),
      'symptoms': [
        for (final s in symptoms)
          {
            'id': s.id,
            'name': s.name,
            'kind': s.kind.name,
            'group': s.grp.name,
            'key': s.key,
            'sortOrder': s.sortOrder,
            'archived': s.archived,
          },
      ],
      'values': [
        for (final v in values) {'date': v.date, 'symptom': v.symptomId, 'value': v.value},
      ],
      'days': [
        for (final m in metas) {'date': m.date, 'newAttack': m.newAttack, 'note': m.note},
      ],
      'weather': [for (final w in weather) w.toJson()],
    });
  }

  /// Tabelle mit `;` als Trenner und BOM, damit Excel/LibreOffice Umlaute richtig lesen.
  Future<String> exportCsv() async {
    final symptoms = await (db.select(
      db.symptoms,
    )..orderBy([(s) => OrderingTerm.asc(s.sortOrder), (s) => OrderingTerm.asc(s.id)])).get();
    final cols = [for (final g in SymptomGroup.values) ...symptoms.where((s) => s.grp == g)];
    final values = await db.select(db.dayValues).get();
    final metas = {for (final m in await db.select(db.dayMeta).get()) m.date: m};
    final byDay = <String, Map<int, int>>{};
    for (final v in values) {
      (byDay[v.date] ??= {})[v.symptomId] = v.value;
    }
    final dates = {...byDay.keys, ...metas.keys}.toList()..sort();

    final rows = <List<String>>[
      ['Datum', for (final s in cols) _columnName(s), 'Neue Attacke', 'Notiz'],
      for (final d in dates)
        [
          d,
          for (final s in cols) _cell(s, byDay[d]?[s.id] ?? 0),
          metas[d]?.newAttack == true ? 'X' : '',
          metas[d]?.note ?? '',
        ],
    ];
    return '﻿${rows.map((r) => r.map(_quote).join(';')).join('\r\n')}\r\n';
  }

  static String _columnName(Symptom s) => switch (s.grp) {
    SymptomGroup.aura => '$_auraPrefix${s.name}',
    SymptomGroup.trigger => '$_triggerPrefix${s.name}',
    SymptomGroup.medication => '$_medPrefix${s.name}',
    SymptomGroup.general => s.name,
  };

  static String _cell(Symptom s, int v) =>
      v == 0 ? '' : (s.kind == SymptomKind.scale0to3 ? '$v' : 'X');

  static String _quote(String f) =>
      RegExp(r'[;"\r\n]').hasMatch(f) ? '"${f.replaceAll('"', '""')}"' : f;

  // ── Import lesen ────────────────────────────────────────────

  /// Erkennt Sicherung (JSON) oder Tabelle (CSV) am Inhalt.
  Future<ImportData> read(List<int> bytes) async {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.contains('�')) text = latin1.decode(bytes); // alte Excel-CSV
    if (text.startsWith('﻿')) text = text.substring(1);
    final data = text.trimLeft().startsWith('{') ? _parseBackup(text) : _parseCsv(text);
    await _resolve(data);
    return data;
  }

  ImportData _parseBackup(String text) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw ImportFormatException('Die Datei ist keine gültige Sicherung.');
    }
    if (j['format'] != backupFormat) {
      throw ImportFormatException('Die Datei ist keine SimpleMigr-Sicherung.');
    }
    final symptoms = <ImportSymptom>[];
    final indexById = <int, int>{};
    for (final s in (j['symptoms'] as List).cast<Map<String, dynamic>>()) {
      indexById[s['id'] as int] = symptoms.length;
      symptoms.add(
        ImportSymptom(
          s['name'] as String,
          SymptomGroup.values.byName(s['group'] as String),
          kind: SymptomKind.values.byName(s['kind'] as String),
          key: s['key'] as String?,
          archived: s['archived'] as bool? ?? false,
        ),
      );
    }
    final days = <String, ImportDay>{};
    for (final v in (j['values'] as List).cast<Map<String, dynamic>>()) {
      final i = indexById[v['symptom'] as int];
      if (i == null) continue;
      (days[v['date'] as String] ??= ImportDay()).values[i] = v['value'] as int;
    }
    for (final m in (j['days'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final d = days[m['date'] as String] ??= ImportDay();
      d.newAttack = m['newAttack'] as bool? ?? false;
      d.note = m['note'] as String? ?? '';
    }
    // Ohne Eintrag in `days` gab es an dem Tag weder Notiz noch „/“.
    for (final d in days.values) {
      d.newAttack ??= false;
    }
    return ImportData(
      isBackup: true,
      symptoms: symptoms,
      days: days,
      description: j['description'] as String?,
      weather: [
        for (final w in (j['weather'] as List? ?? const []).cast<Map<String, dynamic>>())
          WeatherDay.fromJson(w).toCompanion(true),
      ],
    );
  }

  static const _dateNames = {'datum', 'tag', 'date', 'day'};
  static const _noteNames = {
    'notiz',
    'notizen',
    'bemerkung',
    'bemerkungen',
    'kommentar',
    'note',
    'notes',
  };
  static const _newAttackNames = {'neue attacke', '/', 'new attack'};
  static const _ignoredNames = {'wochentag', 'weekday', 'kw', 'monat', 'jahr'};

  /// Andere übliche Spaltennamen für die Systemsymptome.
  static const _aliases = {
    'migräne': SymptomKey.migraine,
    'migraene': SymptomKey.migraine,
    'migränetag': SymptomKey.migraine,
    'migraine': SymptomKey.migraine,
    'schmerzen': SymptomKey.pain,
    'schmerz': SymptomKey.pain,
    'schmerzstärke': SymptomKey.pain,
    'stärke': SymptomKey.pain,
    'intensität': SymptomKey.pain,
    'periode': SymptomKey.period,
    'menstruation': SymptomKey.period,
    'regel': SymptomKey.period,
    'aura': SymptomKey.aura,
    'übelkeit': SymptomKey.nausea,
    'medikamente genommen': SymptomKey.medication,
    'medikamente': SymptomKey.medication,
    'medikament': SymptomKey.medication,
    'hat geholfen': SymptomKey.medHelped,
    'geholfen': SymptomKey.medHelped,
  };

  ImportData _parseCsv(String text) {
    final rows = parseCsv(text).where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
    if (rows.isEmpty) throw ImportFormatException('Die Datei ist leer.');
    final header = [for (final h in rows.first) h.trim()];
    final dateCol = header.indexWhere((h) => _dateNames.contains(h.toLowerCase()));
    if (dateCol < 0) {
      throw ImportFormatException('Keine Spalte „Datum“ gefunden.');
    }
    final body = rows.skip(1).toList();
    bool empty(int col) => body.every((r) => col >= r.length || r[col].trim().isEmpty);

    final symptoms = <ImportSymptom>[];
    final symptomCol = <int, int>{}; // Spalte -> Index in symptoms
    final ignored = <String>[];
    int? noteCol, newAttackCol;
    for (var c = 0; c < header.length; c++) {
      if (c == dateCol) continue;
      final h = header[c], lower = h.toLowerCase();
      if (_noteNames.contains(lower)) {
        noteCol = c;
      } else if (_newAttackNames.contains(lower)) {
        newAttackCol = c;
      } else if (h.isEmpty || _ignoredNames.contains(lower) || empty(c)) {
        if (h.isNotEmpty) ignored.add(h);
      } else {
        symptomCol[c] = symptoms.length;
        symptoms.add(_symptomFromHeader(h));
      }
    }
    // „/“ in der Migräne-Spalte bedeutet wie auf Papier: neue Attacke.
    final migraineIndex = symptoms.indexWhere((s) => s.key == SymptomKey.migraine);
    final migraineCol = [
      for (final e in symptomCol.entries)
        if (e.value == migraineIndex) e.key,
    ].firstOrNull;

    final days = <String, ImportDay>{};
    var skipped = 0;
    for (final r in body) {
      final date = dateCol < r.length ? parseDate(r[dateCol]) : null;
      if (date == null) {
        skipped++;
        continue;
      }
      final day = days[toKey(date)] = ImportDay();
      String at(int c) => c < r.length ? r[c].trim() : '';
      for (final MapEntry(key: c, value: i) in symptomCol.entries) {
        day.values[i] = _parseValue(at(c), symptoms[i].kind);
      }
      if (noteCol != null && at(noteCol).isNotEmpty) day.note = at(noteCol);
      if (newAttackCol != null || migraineCol != null) {
        day.newAttack =
            (migraineCol != null && at(migraineCol) == '/') ||
            (newAttackCol != null && _parseValue(at(newAttackCol), SymptomKind.flag) != 0);
      }
    }
    return ImportData(
      isBackup: false,
      symptoms: symptoms,
      days: days,
      ignoredColumns: ignored,
      skippedRows: skipped,
    );
  }

  static ImportSymptom _symptomFromHeader(String h) {
    if (h.startsWith(_auraPrefix.trim()) && h.length > _auraPrefix.trim().length) {
      return ImportSymptom(h.substring(_auraPrefix.trim().length).trim(), SymptomGroup.aura);
    }
    if (h.startsWith(_triggerPrefix.trim())) {
      return ImportSymptom(h.substring(_triggerPrefix.trim().length).trim(), SymptomGroup.trigger);
    }
    if (h.startsWith(_medPrefix.trim()) && h.length > _medPrefix.trim().length) {
      return ImportSymptom(h.substring(_medPrefix.trim().length).trim(), SymptomGroup.medication);
    }
    final key = _aliases[h.toLowerCase()];
    return ImportSymptom(
      h,
      SymptomGroup.general,
      key: key,
      kind: key == SymptomKey.pain ? SymptomKind.scale0to3 : SymptomKind.flag,
    );
  }

  static const _falsy = {'', '0', '-', 'nein', 'n', 'no', 'false', 'falsch'};

  static int _parseValue(String raw, SymptomKind kind) {
    final v = raw.trim().toLowerCase();
    if (_falsy.contains(v)) return 0;
    if (kind == SymptomKind.scale0to3) {
      final n = int.tryParse(v) ?? double.tryParse(v.replaceAll(',', '.'))?.round();
      return (n ?? 1).clamp(0, 3);
    }
    return 1;
  }

  /// Ordnet die Symptome der Datei lokalen Symptomen zu: Systemschlüssel, dann
  /// Name in derselben Gruppe, bei Tabellen ohne Präfix auch Name in anderer Gruppe.
  Future<void> _resolve(ImportData data) async {
    final local = await db.select(db.symptoms).get();
    String norm(String s) => s.trim().toLowerCase();
    for (final s in data.symptoms) {
      Symptom? hit;
      if (s.key != null) hit = local.where((l) => l.key == s.key).firstOrNull;
      hit ??= local.where((l) => l.grp == s.grp && norm(l.name) == norm(s.name)).firstOrNull;
      if (!data.isBackup && s.grp == SymptomGroup.general) {
        hit ??= local.where((l) => norm(l.name) == norm(s.name)).firstOrNull;
      }
      s.localId = hit?.id;
    }
  }

  // ── Import übernehmen ───────────────────────────────────────

  /// Schreibt alles in einer Transaktion. Gibt die Zahl der Tage zurück.
  Future<int> apply(ImportData data) async {
    await db.transaction(() async {
      final maxOrder = db.symptoms.sortOrder.max();
      final row = await (db.selectOnly(db.symptoms)..addColumns([maxOrder])).getSingle();
      var order = (row.read(maxOrder) ?? 0) + 1;
      for (final s in data.newSymptoms) {
        s.localId = await db
            .into(db.symptoms)
            .insert(
              SymptomsCompanion.insert(
                name: s.name,
                kind: s.kind,
                grp: s.grp,
                sortOrder: order++,
                archived: Value(s.archived),
              ),
            );
      }
      final ids = [for (final s in data.symptoms) s.localId!];
      final migraineId = (await (db.select(
        db.symptoms,
      )..where((s) => s.key.equals(SymptomKey.migraine))).getSingle()).id;

      for (final MapEntry(key: date, value: day) in data.days.entries) {
        for (var i = 0; i < ids.length; i++) {
          final v = day.values[i] ?? 0;
          if (v == 0) {
            await (db.delete(
              db.dayValues,
            )..where((t) => t.date.equals(date) & t.symptomId.equals(ids[i]))).go();
          } else {
            await db
                .into(db.dayValues)
                .insertOnConflictUpdate(
                  DayValuesCompanion.insert(date: date, symptomId: ids[i], value: v),
                );
          }
        }
        final old = await (db.select(
          db.dayMeta,
        )..where((m) => m.date.equals(date))).getSingleOrNull();
        final isMigraine =
            await (db.select(db.dayValues)
                  ..where((t) => t.date.equals(date) & t.symptomId.equals(migraineId)))
                .getSingleOrNull() !=
            null;
        final na = isMigraine && (day.newAttack ?? old?.newAttack ?? false);
        final nt = day.note ?? old?.note ?? '';
        if (!na && nt.trim().isEmpty) {
          await (db.delete(db.dayMeta)..where((m) => m.date.equals(date))).go();
        } else {
          await db
              .into(db.dayMeta)
              .insertOnConflictUpdate(
                DayMetaCompanion.insert(date: date, newAttack: Value(na), note: Value(nt)),
              );
        }
      }

      if (data.weather.isNotEmpty) {
        await db.batch((b) => b.insertAllOnConflictUpdate(db.dayWeather, data.weather));
      }
      final desc = data.description;
      if (desc != null && desc.trim().isNotEmpty) await repo.setDescription(desc);
    });
    return data.days.length;
  }
}

/// Liest CSV mit `;`, `,` oder Tab als Trenner (aus der ersten Zeile erkannt) und
/// Anführungszeichen nach RFC 4180.
List<List<String>> parseCsv(String text) {
  final firstLine = text.split('\n').first;
  final sep = [
    ';',
    '\t',
    ',',
  ].reduce((a, b) => b.allMatches(firstLine).length > a.allMatches(firstLine).length ? b : a);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"' && field.isEmpty) {
      quoted = true;
    } else if (ch == sep) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// `2026-09-01`, `01.09.2026`, `1.9.26`, `01/09/2026` (Tag zuerst). Uhrzeit dahinter wird ignoriert.
DateTime? parseDate(String raw) {
  final s = raw.trim().split(RegExp(r'[ T]')).first;
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  int y, mo, d;
  if (m != null) {
    (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  } else {
    m = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{2}|\d{4})$').firstMatch(s);
    if (m == null) return null;
    (d, mo, y) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (y < 100) y += 2000;
  }
  final date = DateTime(y, mo, d);
  return date.month == mo && date.day == d ? date : null;
}
