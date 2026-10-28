import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/repository.dart';
import 'package:simplemigr/data/transfer.dart';
import 'package:simplemigr/ui/data_tiles.dart';
import 'package:simplemigr/ui/description_screen.dart';
import 'package:simplemigr/ui/theme.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late Repository repo;
  late DataTransfer transfer;
  late Map<String, int> ids;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
    transfer = DataTransfer(repo);
    ids = {for (final s in await db.select(db.symptoms).get()) s.key ?? s.name: s.id};
  });
  tearDown(() => db.close());

  Future<ImportData> readText(String text) => transfer.read(utf8.encode(text));

  group('parseDate', () {
    test('übliche Formate', () {
      expect(parseDate('2026-09-01'), DateTime(2026, 9, 1));
      expect(parseDate('01.09.2026'), DateTime(2026, 9, 1));
      expect(parseDate('1.9.26'), DateTime(2026, 9, 1));
      expect(parseDate('01/09/2026'), DateTime(2026, 9, 1));
      expect(parseDate('2026-09-01 00:00:00'), DateTime(2026, 9, 1));
      expect(parseDate('31.02.2026'), isNull);
      expect(parseDate('Summe'), isNull);
    });
  });

  test('parseCsv: Trenner erkennen, Anführungszeichen', () {
    expect(parseCsv('a;b\r\n1;"x;""y"""\n'), [
      ['a', 'b'],
      ['1', 'x;"y"'],
    ]);
    expect(parseCsv('a,b\n1,2'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('CSV aus eigener Tabelle: Aliase, /, Präfixe, neue und ignorierte Spalten', () async {
    final data = await readText(
      'Datum;Wochentag;Migränetag;Schmerz;Übelkeit;Aura: Kribbeln;'
      'Auslöser: Stress;Koffein;Leer;Bemerkung\n'
      '02.09.2026;Mi;x;2;;;x;;;\n'
      '03.09.2026;Do;x;3;ja;x;;x;;"zwei; Tage"\n'
      '04.09.2026;Fr;/;1;;;;;;\n'
      'Summe;;3;;;;;;;\n',
    );
    expect(data.isBackup, isFalse);
    expect(data.days.keys, ['2026-09-02', '2026-09-03', '2026-09-04']);
    expect(data.skippedRows, 1);
    expect(data.ignoredColumns, ['Wochentag', 'Leer']);
    expect(data.newSymptoms.map((s) => (s.name, s.grp)), [
      ('Kribbeln', SymptomGroup.aura),
      ('Koffein', SymptomGroup.general),
    ]);

    expect(await transfer.apply(data), 3);
    final d3 = await repo.getDay(DateTime(2026, 9, 3));
    expect(d3.value(ids['migraine']!), 1);
    expect(d3.value(ids['pain']!), 3);
    expect(d3.value(ids['nausea']!), 1);
    expect(d3.note, 'zwei; Tage');
    expect(d3.newAttack, isFalse);
    expect((await repo.getDay(DateTime(2026, 9, 2))).value(ids['Stress']!), 1);
    expect((await repo.getDay(DateTime(2026, 9, 4))).newAttack, isTrue);

    final month = await repo.getMonth(2026, 9);
    expect(month.migraineDays, 3);
    expect(month.attacks, 2);
    final kribbeln = month.symptoms.firstWhere((s) => s.name == 'Kribbeln');
    expect(kribbeln.grp, SymptomGroup.aura);
    expect(month.day(DateTime(2026, 9, 3)).value(kribbeln.id), 1);
  });

  test('Import ersetzt nur die Spalten und Tage aus der Datei', () async {
    final day = DateTime(2026, 9, 2);
    await repo.setValue(day, ids['pain']!, 3);
    await repo.setValue(day, ids['period']!, 1);
    await repo.setNote(day, 'alt');
    await repo.setValue(DateTime(2026, 9, 20), ids['migraine']!, 1);

    await transfer.apply(await readText('Datum;Schmerzen;Notiz\n2026-09-02;1;\n'));
    final d = await repo.getDay(day);
    expect(d.value(ids['pain']!), 1);
    expect(d.value(ids['period']!), 1); // Spalte nicht in der Datei
    expect(d.note, 'alt'); // leere Notiz überschreibt nicht
    expect((await repo.getDay(DateTime(2026, 9, 20))).value(ids['migraine']!), 1);
  });

  test('Fehlende Datumsspalte → verständlicher Fehler', () async {
    expect(() => readText('Migräne;Schmerzen\nx;2\n'), throwsA(isA<ImportFormatException>()));
    expect(() => readText('{"foo": 1}'), throwsA(isA<ImportFormatException>()));
  });

  test('Sicherung: alles kommt in einer frischen Datenbank wieder an', () async {
    final day = DateTime(2026, 9, 3);
    await repo.setValue(day, ids['migraine']!, 1);
    await repo.setValue(DateTime(2026, 9, 2), ids['migraine']!, 1);
    await repo.setNewAttack(day, true);
    await repo.setValue(day, ids['pain']!, 2);
    final own = await repo.addSymptom('Nackenschmerz', SymptomGroup.general);
    await repo.setValue(day, own, 1);
    await repo.setNote(day, 'Notiz');
    await repo.setDescription('Beginnt mit Flimmern.');
    await repo.saveWeather([
      DayWeatherCompanion.insert(date: '2026-09-03', pressureMean: const Value(1003.5)),
    ]);

    final json = await transfer.exportBackup(now: DateTime(2026, 10, 1));
    final csv = await transfer.exportCsv();
    expect(csv, startsWith('﻿Datum;Migräne;Schmerzen;'));
    expect(csv, contains('Aura: Sicht'));
    expect(csv, contains('Auslöser: Stress'));
    expect(csv, contains('2026-09-03;X;2;'));

    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final repo2 = Repository(db2);
    final t2 = DataTransfer(repo2);
    final data = await t2.read(utf8.encode(json));
    expect(data.isBackup, isTrue);
    expect(data.newSymptoms.map((s) => s.name), ['Nackenschmerz']);
    await t2.apply(data);

    final d = await repo2.getDay(day);
    final own2 = (await db2.select(db2.symptoms).get()).firstWhere(
      (s) => s.name == 'Nackenschmerz',
    );
    final pain2 = (await db2.select(db2.symptoms).get()).firstWhere((s) => s.key == 'pain');
    expect(d.value(own2.id), 1);
    expect(d.value(pain2.id), 2);
    expect(d.newAttack, isTrue);
    expect(d.note, 'Notiz');
    expect(d.weather?.pressureMean, 1003.5);
    expect(await repo2.getDescription(), 'Beginnt mit Flimmern.');

    // CSV-Export der Kopie lässt sich wieder einlesen und ändert nichts
    final again = await t2.read(utf8.encode(await t2.exportCsv()));
    expect(again.newSymptoms, isEmpty);
    await t2.apply(again);
    expect((await repo2.getDay(day)).value(own2.id), 1);
    expect((await repo2.getDay(day)).newAttack, isTrue);
  });

  dbWidgetTest('Import über die Kachel: Vorschau, dann Meldung mit Wetterhinweis', (
    tester,
    env,
  ) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: DataTiles(
            transfer: DataTransfer(env.repo),
            pick: () async => utf8.encode('Datum;Migräne\n01.09.2026;x\n02.09.2026;x\n'),
            save: (name, bytes, mime) async {
              saved = name;
              return true;
            },
            afterImport: () => 'Wetter wird nachgeladen.',
            clock: () => DateTime(2026, 10, 1),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('import')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tabelle importieren?'), findsOneWidget);
    expect(find.textContaining('2 Tage, 1.9.2026 bis 2.9.2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-import')));
    await settle(tester);
    await tester.pump();
    expect(find.text('2 Tage importiert. Wetter wird nachgeladen.'), findsOneWidget);
    final month = (await tester.runAsync(() => env.repo.getMonth(2026, 9)))!;
    expect(month.migraineDays, 2);

    await tester.tap(find.byKey(const ValueKey('export-backup')));
    await settle(tester);
    expect(saved, 'simplemigr_sicherung_2026-10-01.json');
  });

  dbWidgetTest('Meine Migräne: Punkte hinzufügen, löschen, alter Text wird zu Punkten',
      (tester, env) async {
    await tester.runAsync(() => env.repo.setDescription('Flimmern vorher\n\nPochend, rechts'));
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: DescriptionScreen(repo: env.repo)));
    await settle(tester);
    expect(find.text('Flimmern vorher'), findsOneWidget);
    expect(find.text('Pochend, rechts'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('new-point')), 'Dauer 2 Tage');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Dauer 2 Tage'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('new-point'))).controller!.text, '');
    expect(await tester.runAsync(() => env.repo.getDescription()),
        'Flimmern vorher\nPochend, rechts\nDauer 2 Tage');

    await tester.drag(find.text('Pochend, rechts'), const Offset(-600, 0));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Pochend, rechts'), findsNothing);
    expect(await tester.runAsync(() => env.repo.getDescription()), 'Flimmern vorher\nDauer 2 Tage');
    await tester.tap(find.text('Rückgängig'));
    await settle(tester);
    expect(find.text('Pochend, rechts'), findsOneWidget);

    // Papierkorb am Punkt und „Löschen“ im Bearbeiten-Dialog
    await tester.tap(find.byKey(const ValueKey('delete-point-0')));
    await settle(tester);
    expect(find.text('Flimmern vorher'), findsNothing);
    await tester.tap(find.text('Dauer 2 Tage'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-point-in-dialog')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => env.repo.getDescription()), 'Pochend, rechts');
  });
}
