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

    await tester.tap(find.widgetWithText(SwitchListTile, 'Aura'));
    await settle(tester);
    expect(find.text('Sicht'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Aura'));
    await settle(tester);
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
}
