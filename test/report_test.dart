import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/report.dart';
import 'package:simplemigr/data/repository.dart';
import 'package:simplemigr/data/transfer.dart';
import 'package:simplemigr/pdf/report_pdf.dart';
import 'package:simplemigr/ui/report_tile.dart';
import 'package:simplemigr/ui/theme.dart';
import 'package:simplemigr/ui/today_screen.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late Repository repo;
  late Map<String, int> ids;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
    ids = {for (final s in await db.select(db.symptoms).get()) s.key ?? s.name: s.id};
  });
  tearDown(() => db.close());

  Future<void> mark(String key, List<DateTime> days, [int value = 1]) async {
    for (final d in days) {
      await repo.setValue(d, ids[key]!, value);
    }
  }

  List<DateTime> span(int m1, int d1, int m2, int d2) => [
        for (var d = DateTime(2026, m1, d1);
            !d.isAfter(DateTime(2026, m2, d2));
            d = DateTime(d.year, d.month, d.day + 1))
          d,
      ];

  DateTime day(int m, int d) => DateTime(2026, m, d);

  /// Mai/Juni 2026: Periode ab 1.5., 29.5., 26.6. (Zyklus 28 Tage).
  Future<void> seed() async {
    await mark('period', [...span(5, 1, 5, 4), ...span(5, 29, 6, 1), ...span(6, 26, 6, 29)]);
    await mark('migraine', [
      ...span(5, 2, 5, 3), day(5, 14), day(5, 30), ...span(6, 11, 6, 12), ...span(6, 25, 6, 28),
    ]);
    await repo.setNewAttack(day(6, 27), true);
    await mark('pain', [day(5, 2)], 3);
    await mark('pain', [day(5, 14)], 2);
    await mark('aura', [day(5, 14)]);
    await mark('Sprache', [day(5, 14)]);
    await mark('nausea', [day(5, 3)]);
  }

  test('Monate, Attacken, Zyklus und Muster', () async {
    await seed();
    final r = await Report.load(repo, day(5, 1), day(6, 30));

    expect(r.months.map((m) => m.partial), [false, false]);
    final may = r.months[0], june = r.months[1];
    expect([may.migraineDays, may.attacks, may.strongPainDays, may.auraDays, may.nauseaDays],
        [4, 3, 1, 1, 1]);
    expect([june.migraineDays, june.attacks], [6, 3]);

    expect(r.attacks.map((a) => a.start),
        [day(5, 2), day(5, 14), day(5, 30), day(6, 11), day(6, 25), day(6, 27)]);
    expect(r.attacks.map((a) => a.length), [2, 1, 1, 2, 2, 2]);
    expect(r.attacks[0].maxPain, 3);
    expect(r.attacks[1].aura, isTrue);
    expect(r.attacks[1].auraKinds, {'Sprache'});
    expect(r.auraSymptomDays, {'Sprache': 1});

    expect(r.periodStarts, [day(5, 1), day(5, 29), day(6, 26)]);
    expect(r.cycleLengths, [28, 28]);
    expect(r.attacks.map((a) => a.perimenstrual), [true, false, true, false, true, true]);
    expect(r.attacks[1].cycleDay, 14);
    expect(r.attacks[3].cycleDay, 14);
    expect(r.pattern!.attacks.map((a) => a.start), [day(5, 14), day(6, 11)]);
    expect(r.medications, isEmpty);

    expect(cycleText(r).join(' '), contains('Zyklustag 14 (14.05. = Tag 14, 11.06. = Tag 14)'));
    expect(overview(r).join('\n'), contains('perimenstruell 4 von 6 (67 %)'));
  });

  test('Attacke über den Zeitraumbeginn zählt nicht im Zeitraum, Teilmonat markiert', () async {
    await seed();
    final r = await Report.load(repo, day(5, 3), day(6, 15));
    expect(r.attacks.first.start, day(5, 14));
    expect(r.months.map((m) => m.partial), [true, true]);
    expect(r.months.first.migraineDays, 3);
  });

  test('Zeitraum beginnt frühestens mit dem ersten Eintrag', () async {
    await seed();
    final r = await Report.load(repo, DateTime(2025, 11, 1), day(6, 30));
    expect(r.from, day(5, 1));
    expect(r.requestedFrom, DateTime(2025, 11, 1));
    expect(r.months.map((m) => m.month), [5, 6]);
    final unchanged = await Report.load(repo, day(5, 10), day(6, 30));
    expect([unchanged.from, unchanged.requestedFrom], [day(5, 10), null]);
  });

  test('Ohne Periode und Medikamente: „nicht erfasst“', () async {
    await mark('migraine', [day(5, 2)]);
    final r = await Report.load(repo, day(5, 1), day(5, 31));
    expect(r.hasPeriodData, isFalse);
    expect(cycleText(r), ['Periode nicht erfasst.']);
    expect(medicationText(r).single, startsWith('Nicht erfasst'));
    expect(r.questions, [contains('Akutmedikation ist sinnvoll')]);
  });

  test('Medikamente: Substanzen je Monat, ohne Angabe, Hinweis ab 10 Triptantagen', () async {
    final suma = await repo.addSymptom('Sumatriptan', SymptomGroup.medication);
    final ibu = await repo.addSymptom('Ibuprofen', SymptomGroup.medication);
    for (final d in span(6, 1, 6, 10)) {
      await repo.setValue(d, suma, 1);
    }
    await repo.setValue(day(6, 1), ibu, 1);
    await mark('med_helped', [day(6, 1), day(6, 2)]);
    await mark('medication', [day(5, 20)]);

    final r = await Report.load(repo, day(5, 1), day(6, 30));
    expect(r.medications.map((m) => m.name), ['Sumatriptan', 'Ibuprofen', 'Ohne Angabe der Substanz']);
    final s = r.medications.first;
    expect([s.triptan, s.totalDays, s.helpedDays, s.daysPerMonth], [true, 10, 2, {1: 10}]);
    expect(r.medications[1].triptan, isFalse);
    expect(r.medications[2].daysPerMonth, {0: 1});

    final text = medicationText(r);
    expect(text[0], contains('Sumatriptan (Triptan): 10 Einnahmetage (Jun 10)'));
    expect(text[0], contains('an 10 oder mehr Tagen im Monat genommen (Jun)'));
    expect(text[1], isNot(contains('Hinweis')));
    expect(r.questions.last, contains('Medikamentenübergebrauch'));
  });

  test('Beschreibung: Gruppen per Stichwort, Überschriften fallen weg', () async {
    await repo.setDescription('Während einer Attacke:\n'
        '- Gedachte Handlungen werden falsch ausgeübt\n'
        '- Mir fallen Sachen ständig runter / kein richtiges Greifen\n'
        '- Stoße mich oder laufe gegen Ecken & Wände\n'
        '- Kau- & Zungenmuskulatur ist unkoordiniert\n'
        '- Ab & an „Gliederschmerzen“\n'
        '- Sehr selten „Paralyse“\n'
        '- Danach Migräne-Kater\n'
        '- Wortfindungsstörung\n'
        '- Sprachverständnis (klingt wie fremde Sprache)\n'
        '\n'
        'Weitere Beobachtungen:\n'
        '- Vor fast jeder Attacke stark gereizt\n'
        '- Währenddessen wenig Konzentration / keine Aufnahme\n'
        '- Keinen Reizfilter → Gefühl, kurz vor Kurzschluss zu sein\n'
        '- Zickzack-Linien im Sehfeld\n'
        '- Kribbeln in der Hand');
    await mark('migraine', [day(5, 2)]);
    await mark('aura', [day(5, 2)]);
    final r = await Report.load(repo, day(5, 1), day(5, 31));
    final g = r.description;
    expect(g[DescriptionGroup.motor], hasLength(5));
    expect(g[DescriptionGroup.speech],
        ['Wortfindungsstörung', 'Sprachverständnis (klingt wie fremde Sprache)']);
    expect(g[DescriptionGroup.prodrome],
        ['Danach Migräne-Kater', 'Vor fast jeder Attacke stark gereizt']);
    expect(g[DescriptionGroup.cognition], hasLength(2));
    expect(g[DescriptionGroup.vision], ['Zickzack-Linien im Sehfeld']);
    expect(g[DescriptionGroup.sensory], ['Kribbeln in der Hand']);
    expect(g[DescriptionGroup.other], ['Ab & an „Gliederschmerzen“']);
    expect(r.questions.first, contains('motorische'));
    // Ohne Periode keine Frage zu hormonellen Optionen.
    expect(r.questions.join(), isNot(contains('hormonell')));

    final bytes = await buildReportPdf(r, now: day(10, 28));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('PDF: volle Daten ohne Fehler', () async {
    await seed();
    final r = await Report.load(repo, day(4, 1), day(6, 15));
    final bytes = await buildReportPdf(r, now: day(10, 28));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(_pageCount(bytes), 1);

    // Zu viel Text: das Diagramm wandert auf eine eigene letzte Seite.
    await repo.setDescription(List.generate(40, (i) => 'Punkt $i zur Attacke').join('\n'));
    final long = await buildReportPdf(await Report.load(repo, day(4, 1), day(6, 15)));
    expect(_pageCount(long), greaterThanOrEqualTo(2));
  });

  test('Vorauswahl: 6 Monate bis heute, über den Jahreswechsel', () {
    final r = ReportTile.defaultRange(DateTime(2026, 3, 10, 15));
    expect([r.start, r.end], [DateTime(2025, 10, 1), DateTime(2026, 3, 10)]);
  });

  test('CSV: Substanzen mit Präfix, Import ordnet sie der Gruppe zu', () async {
    final suma = await repo.addSymptom('Sumatriptan', SymptomGroup.medication);
    await repo.setValue(day(6, 1), suma, 1);
    final transfer = DataTransfer(repo);
    final csv = await transfer.exportCsv();
    expect(csv, contains('Medikament: Sumatriptan'));

    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final t2 = DataTransfer(Repository(db2));
    final data = await t2.read(utf8.encode(csv));
    expect(data.newSymptoms.single.grp, SymptomGroup.medication);
    expect(data.newSymptoms.single.name, 'Sumatriptan');
  });

  dbWidgetTest('Editor: Substanz wählen schaltet „Medikamente genommen“ mit ein', (tester, env) async {
    final id = (await tester.runAsync(
        () => env.repo.addSymptom('Ibuprofen', SymptomGroup.medication)))!;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: TodayScreen(repo: env.repo, clock: () => DateTime(2026, 9, 4, 10)),
    ));
    await settle(tester);
    final sw = find.byKey(const ValueKey('switch-Medikamente'));
    await tester.ensureVisible(sw);
    await tester.tap(find.text('Medikamente'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ibuprofen'));
    await tester.tap(find.text('Ibuprofen'));
    await settle(tester);
    final med = (await tester.runAsync(() => env.idOf(SymptomKey.medication)))!;
    var d = (await tester.runAsync(() => env.repo.getDay(DateTime(2026, 9, 4))))!;
    expect([d.value(id), d.value(med)], [1, 1]);

    await tester.tap(sw);
    await settle(tester);
    d = (await tester.runAsync(() => env.repo.getDay(DateTime(2026, 9, 4))))!;
    expect([d.value(id), d.value(med)], [0, 0]);
  });
}

int _pageCount(List<int> pdf) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(pdf)).length;
