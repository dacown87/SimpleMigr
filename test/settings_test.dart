import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/ui/settings_screen.dart';
import 'package:simplemigr/ui/theme.dart';
import 'package:simplemigr/ui/today_screen.dart';

import 'helpers.dart';

void main() {
  dbWidgetTest('Auslöser anlegen → erscheint in „Mehr“', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('add-trigger')));
    await tester.pump();
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
    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    expect(find.text('Koffein'), findsOneWidget);
  });

  dbWidgetTest('Systemsymptom: kein Archivieren möglich', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    final period = await tester.runAsync(() => env.idOf(SymptomKey.period));
    final tile = find.byKey(ValueKey('symptom-$period'));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.byType(IconButton)), findsNothing);

    // Eigene Symptome (Auslöser) haben den Button
    await tester.ensureVisible(find.text('Stress'));
    await tester.pump();
    final stress = find.widgetWithText(ListTile, 'Stress');
    expect(find.descendant(of: stress, matching: find.byTooltip('Archivieren')), findsOneWidget);
  });

  dbWidgetTest('Archivieren blendet Auslöser in „Heute“ aus', (tester, env) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SettingsScreen(repo: env.repo)));
    await settle(tester);
    await tester.ensureVisible(find.text('Stress'));
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'Stress'), matching: find.byTooltip('Archivieren')));
    await settle(tester);
    final list = (await tester.runAsync(() => env.repo.watchSymptoms().first))!;
    expect(list.map((s) => s.name), isNot(contains('Stress')));
  });
}
