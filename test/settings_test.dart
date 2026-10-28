import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/ui/settings_screen.dart';
import 'package:simplemigr/ui/theme.dart';
import 'package:simplemigr/ui/today_screen.dart';

import 'helpers.dart';

Future<void> showGroup(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('entries-$label')));
  await tester.pumpAndSettle();
}

void main() {
  dbWidgetTest('Auslöser anlegen → erscheint unter „Auslöser“', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    await showGroup(tester, 'Auslöser');
    await reveal(tester, find.byKey(const ValueKey('add-trigger')));
    await tester.tap(find.byKey(const ValueKey('add-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Koffein');
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.pumpAndSettle(); // Dialog schließt
    expect(find.widgetWithText(ListTile, 'Koffein'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: TodayScreen(repo: env.repo, clock: () => DateTime(2026, 9, 4))));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('switch-Auslöser')));
    await tester.pumpAndSettle();
    expect(find.text('Koffein'), findsOneWidget);
  });

  dbWidgetTest('Systemsymptom: kein Archivieren möglich', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    final period = await tester.runAsync(() => env.idOf(SymptomKey.period));
    final tile = find.byKey(ValueKey('symptom-$period'));
    expect(tile, findsOneWidget);
    // Systemsymptome: Haken immer an und nicht änderbar
    final sys = tester.widget<Checkbox>(find.byKey(ValueKey('check-$period')));
    expect(sys.value, isTrue);
    expect(sys.onChanged, isNull);

    // Eigene Symptome (Auslöser) lassen sich abwählen
    await showGroup(tester, 'Auslöser');
    await reveal(tester, find.text('Stress'));
    final stress = find.widgetWithText(ListTile, 'Stress');
    expect(
      tester.widget<Checkbox>(find.descendant(of: stress, matching: find.byType(Checkbox))).onChanged,
      isNotNull,
    );
  });

  dbWidgetTest('Archivieren blendet Auslöser in „Heute“ aus', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    await showGroup(tester, 'Auslöser');
    await reveal(tester, find.text('Stress'));
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'Stress'), matching: find.byType(Checkbox)));
    await settle(tester);
    final list = (await tester.runAsync(() => env.repo.watchSymptoms().first))!;
    expect(list.map((s) => s.name), isNot(contains('Stress')));
  });

  dbWidgetTest('Löschen im Dialog: Symptom und Einträge sind weg', (tester, env) async {
    final id = (await tester.runAsync(() => env.repo.addSymptom('Koffein', SymptomGroup.trigger)))!;
    await tester.runAsync(() => env.repo.setValue(DateTime(2026, 9, 4), id, 1));
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    await showGroup(tester, 'Auslöser');
    await reveal(tester, find.text('Koffein'));
    await tester.tap(find.text('Koffein'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-in-dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Koffein'), findsNothing);
    final rows = (await tester.runAsync(() => env.db.select(env.db.dayValues).get()))!;
    expect(rows.where((r) => r.symptomId == id), isEmpty);
  });

  dbWidgetTest('Wischen löscht ein eigenes Symptom, Systemsymptome nicht', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    final period = await tester.runAsync(() => env.idOf(SymptomKey.period));
    expect(find.byKey(ValueKey('dismiss-$period')), findsNothing);
    await showGroup(tester, 'Auslöser');
    await reveal(tester, find.text('Stress'));
    await tester.drag(find.text('Stress'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Stress'), findsNothing);
  });

  dbWidgetTest('Löschen: Knopf im Dialog entfernt Symptom samt Einträgen', (tester, env) async {
    final id = (await tester.runAsync(() => env.repo.addSymptom('Käse', SymptomGroup.trigger)))!;
    await tester.runAsync(() => env.repo.setValue(DateTime(2026, 9, 4), id, 1));
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    await showGroup(tester, 'Auslöser');
    await reveal(tester, find.text('Käse'));
    await tester.tap(find.text('Käse'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-in-dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Käse'), findsNothing);
    final rows = (await tester.runAsync(() => env.db.select(env.db.dayValues).get()))!;
    expect(rows.where((r) => r.symptomId == id), isEmpty);
  });

  dbWidgetTest('Einträge: Segmente zeigen je eine Gruppe', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    expect(find.text('Periode'), findsOneWidget);
    expect(find.text('Sicht'), findsNothing);
    await showGroup(tester, 'Aura');
    expect(find.text('Sicht'), findsOneWidget);
    expect(find.text('Periode'), findsNothing);
    expect(find.byKey(const ValueKey('add-aura')), findsOneWidget);
  });

  dbWidgetTest('Löschen: Systemsymptom hat keinen Löschen-Knopf', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    await tester.tap(find.text('Periode'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-in-dialog')), findsNothing);
  });
}
