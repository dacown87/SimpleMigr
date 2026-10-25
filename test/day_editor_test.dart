import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/app.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/ui/theme.dart';
import 'package:simplemigr/ui/today_screen.dart';
import 'package:simplemigr/ui/util.dart';

import 'helpers.dart';

Widget app(TestEnv env, {DateTime Function()? clock}) => MaterialApp(
      theme: buildTheme(),
      home: TodayScreen(repo: env.repo, clock: clock ?? () => DateTime(2026, 9, 4, 10)),
    );

void main() {
  final today = DateTime(2026, 9, 4);

  dbWidgetTest('Migräne an → sofort gespeichert, Neustart → noch da', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    await tester.tap(find.text('MIGRÄNE'));
    await settle(tester);

    final id = await tester.runAsync(() => env.idOf(SymptomKey.migraine));
    var day = (await tester.runAsync(() => env.repo.getDay(today)))!;
    expect(day.value(id!), 1);

    // „Neustart“: Widgetbaum komplett neu aufbauen, gleiche Datenbank.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.text('Neue Attacke (/)'), findsOneWidget); // nur sichtbar, wenn Migräne an
  });

  dbWidgetTest('Schmerz 2 → 2 erneut tippen → zurückgesetzt', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    final pain = (await tester.runAsync(() => env.idOf(SymptomKey.pain)))!;

    await tester.tap(find.byKey(const ValueKey('pain-2')));
    await settle(tester);
    expect((await tester.runAsync(() => env.repo.getDay(today)))!.value(pain), 2);

    await tester.tap(find.byKey(const ValueKey('pain-2')));
    await settle(tester);
    expect((await tester.runAsync(() => env.repo.getDay(today)))!.value(pain), 0);
  });

  dbWidgetTest('Aura an → Aura-Symptome sichtbar; aus → versteckt', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.text('Sicht'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('switch-Aura')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Sicht'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('switch-Aura')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Sicht'), findsNothing);
  });

  dbWidgetTest('„Neue Attacke“ nur sichtbar, wenn Migräne an', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.text('Neue Attacke (/)'), findsNothing);
    await tester.tap(find.text('MIGRÄNE'));
    await settle(tester);
    expect(find.text('Neue Attacke (/)'), findsOneWidget);
    await tester.tap(find.text('MIGRÄNE'));
    await settle(tester);
    expect(find.text('Neue Attacke (/)'), findsNothing);
  });

  dbWidgetTest('Tageswechsel: Resume berechnet das Datum neu', (tester, env) async {
    var now = DateTime(2026, 9, 4, 23, 50);
    await tester.pumpWidget(app(env, clock: () => now));
    await settle(tester);
    expect(find.text(germanDate(DateTime(2026, 9, 4))), findsOneWidget);

    now = DateTime(2026, 9, 5, 0, 10);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text(germanDate(DateTime(2026, 9, 5))), findsOneWidget);

    await tester.tap(find.text('MIGRÄNE'));
    await settle(tester);
    final id = (await tester.runAsync(() => env.idOf(SymptomKey.migraine)))!;
    expect((await tester.runAsync(() => env.repo.getDay(DateTime(2026, 9, 5))))!.value(id), 1);
    expect((await tester.runAsync(() => env.repo.getDay(DateTime(2026, 9, 4))))!.value(id), 0);
  });

  dbWidgetTest('App-Shell: Navigation zwischen den Tabs', (tester, env) async {
    await tester.pumpWidget(SimpleMigrApp(repo: env.repo, clock: () => today));
    await settle(tester);
    await tester.tap(find.text('Monat'));
    await settle(tester);
    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.text('Einstellungen'));
    await settle(tester);
    expect(find.text('Einstellungen'), findsWidgets);
    expect(find.text('Symptome'), findsOneWidget);
  });

  dbWidgetTest('Periode ist ein Schalter; Übelkeit liegt im Block „Symptome“', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.widgetWithText(SwitchListTile, 'Periode'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Übelkeit'), findsNothing);
    expect(find.text('Mehr'), findsNothing);
    expect(find.text('Übelkeit'), findsNothing); // Block zu, solange der Schalter aus ist

    await tester.tap(find.widgetWithText(SwitchListTile, 'Periode'));
    await settle(tester);
    final period = (await tester.runAsync(() => env.idOf(SymptomKey.period)))!;
    expect((await tester.runAsync(() => env.repo.getDay(today)))!.value(period), 1);

    await tester.tap(find.byKey(const ValueKey('switch-Symptome')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Übelkeit'), findsOneWidget);
    await tester.tap(find.text('Übelkeit'));
    await settle(tester);
    final nausea = (await tester.runAsync(() => env.idOf(SymptomKey.nausea)))!;
    expect((await tester.runAsync(() => env.repo.getDay(today)))!.value(nausea), 1);

    // Schalter aus wählt die Symptome des Tages ab und klappt zu.
    await tester.tap(find.byKey(const ValueKey('switch-Symptome')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect((await tester.runAsync(() => env.repo.getDay(today)))!.value(nausea), 0);
    expect(find.text('Übelkeit'), findsNothing);
  });

  dbWidgetTest('Auslöser: Inhalt erst nach Aktivieren des Schalters', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.text('Stress'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('switch-Auslöser')));
    await tester.tap(find.byKey(const ValueKey('switch-Auslöser')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Stress'), findsOneWidget);
    await tester.tap(find.text('Stress'));
    await settle(tester);
    final id = (await tester.runAsync(() async =>
        (await env.db.select(env.db.symptoms).get()).firstWhere((s) => s.name == 'Stress').id))!;
    expect((await tester.runAsync(() => env.repo.getDay(today)))!.value(id), 1);
  });

  dbWidgetTest('Medikamente: „Hat geholfen“ erst nach dem Schalter, Ausschalten setzt zurück',
      (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.text('Hat geholfen'), findsNothing);
    final sw = find.byKey(const ValueKey('switch-Medikamente'));
    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Hat geholfen'), findsOneWidget);
    await tester.tap(find.text('Hat geholfen'));
    await settle(tester);
    final ids = (await tester.runAsync(() async => {
          for (final k in [SymptomKey.medication, SymptomKey.medHelped]) k: await env.idOf(k),
        }))!;
    var d = (await tester.runAsync(() => env.repo.getDay(today)))!;
    expect(d.value(ids[SymptomKey.medication]!), 1);
    expect(d.value(ids[SymptomKey.medHelped]!), 1);
    await tester.tap(sw);
    await settle(tester);
    d = (await tester.runAsync(() => env.repo.getDay(today)))!;
    expect(d.value(ids[SymptomKey.medication]!), 0);
    expect(d.value(ids[SymptomKey.medHelped]!), 0);
  });

  dbWidgetTest('Gewählte Auslöser: Schalter von selbst an, Block offen', (tester, env) async {
    final id = (await tester.runAsync(() async =>
        (await env.db.select(env.db.symptoms).get()).firstWhere((s) => s.name == 'Stress').id))!;
    await tester.runAsync(() => env.repo.setValue(today, id, 1));
    await tester.pumpWidget(app(env));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byKey(const ValueKey('switch-Auslöser'))).value, isTrue);
    expect(find.text('Stress'), findsOneWidget);
  });

  dbWidgetTest('Wetterkarte erscheint nur mit Wetterdaten, inkl. Druckänderung', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.byKey(const ValueKey('weather-card'), skipOffstage: false), findsNothing);

    await tester.runAsync(() => env.repo.saveWeather([
          DayWeatherCompanion.insert(
              date: '2026-09-03', pressureMean: const Value(1015.0)),
          DayWeatherCompanion.insert(
              date: '2026-09-04',
              pressureMean: const Value(1010.5),
              tempMin: const Value(8.0),
              tempMax: const Value(14.0),
              humidity: const Value(73.0),
              precipitation: const Value(4.1),
              windMax: const Value(16.0)),
        ]));
    await settle(tester);
    expect(find.byKey(const ValueKey('weather-card'), skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Luftdruck 1011 hPa (−4,5 zum Vortag)', skipOffstage: false), findsOneWidget);
    expect(find.text('Niederschlag 4,1 mm', skipOffstage: false), findsOneWidget);
  });

  dbWidgetTest('Reihenfolge: Periode, Symptome, Aura, Auslöser', (tester, env) async {
    await tester.pumpWidget(app(env));
    await settle(tester);
    double y(Finder f) => tester.getTopLeft(f).dy;
    final period = y(find.widgetWithText(SwitchListTile, 'Periode'));
    final symptome = y(find.text('Symptome'));
    final aura = y(find.text('Aura'));
    final triggers = y(find.text('Auslöser'));
    expect(symptome, greaterThan(period));
    expect(aura, greaterThan(symptome));
    expect(triggers, greaterThan(aura));
  });
}
