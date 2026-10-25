import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/ui/month_screen.dart';
import 'package:simplemigr/ui/theme.dart';
import 'package:simplemigr/ui/util.dart';

import 'helpers.dart';

Widget app(TestEnv env) => MaterialApp(
      theme: buildTheme(),
      home: MonthScreen(repo: env.repo, clock: () => DateTime(2026, 9, 10)),
    );

Future<void> seed(WidgetTester t, TestEnv env) async {
  await t.runAsync(() async {
    final m = await env.idOf(SymptomKey.migraine);
    final pain = await env.idOf(SymptomKey.pain);
    final period = await env.idOf(SymptomKey.period);
    final nausea = await env.idOf(SymptomKey.nausea);
    for (final d in [2, 3, 4, 5, 6]) {
      await env.repo.setValue(DateTime(2026, 9, d), m, 1);
    }
    await env.repo.setNewAttack(DateTime(2026, 9, 4), true);
    await env.repo.setValue(DateTime(2026, 9, 3), pain, 3);
    await env.repo.setValue(DateTime(2026, 9, 2), period, 1);
    await env.repo.setValue(DateTime(2026, 9, 2), nausea, 1);
  });
}

void main() {
  dbWidgetTest('Raster zeigt gelb/rot/Zahl/X//', (tester, env) async {
    await seed(tester, env);
    await tester.pumpWidget(app(env));
    await settle(tester);

    expect(find.text('3'), findsWidgets); // Schmerz 3 (und Tageszahl 3)
    expect(find.text('/'), findsOneWidget);
    // Erweiterte Zeilen sind zugeklappt, nur ein Punkt zeigt den Eintrag.
    expect(find.text('Übelkeit'), findsNothing);
    expect(find.text('X'), findsNothing);
    expect(find.byIcon(Icons.circle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('section-Symptome')));
    await settle(tester);
    expect(find.text('Übelkeit'), findsOneWidget);
    expect(find.text('X'), findsOneWidget); // Übelkeit am 2.
    expect(find.byIcon(Icons.circle), findsNothing);

    Iterable<Color?> fills() => tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color);
    expect(fills().where((c) => c == AppColors.migraine), hasLength(5));
    expect(fills().where((c) => c == AppColors.period), hasLength(1));
  });

  dbWidgetTest('Summenzeile: Migränetage und Attacken', (tester, env) async {
    await seed(tester, env);
    await tester.pumpWidget(app(env));
    await settle(tester);
    expect(find.text('Migränetage: 5 · Attacken: 2'), findsOneWidget);
  });

  dbWidgetTest('Monatsnavigation', (tester, env) async {
    await seed(tester, env);
    await tester.pumpWidget(app(env));
    await settle(tester);
    await tester.tap(find.byTooltip('Nächster Monat'));
    await settle(tester);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.text('Migränetage: 0 · Attacken: 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Vorheriger Monat'));
    await tester.tap(find.byTooltip('Vorheriger Monat'));
    await settle(tester);
    expect(find.text('August 2026'), findsOneWidget);
  });

  dbWidgetTest('Tag antippen → DayEditor für diesen Tag', (tester, env) async {
    await seed(tester, env);
    await tester.pumpWidget(app(env));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('day-8')));
    await tester.pumpAndSettle(); // Sheet-Animation
    await settle(tester);
    expect(find.text(germanDate(DateTime(2026, 9, 8))), findsOneWidget);
    expect(find.text('MIGRÄNE'), findsOneWidget);

    await tester.tap(find.text('MIGRÄNE'));
    await settle(tester);
    final id = (await tester.runAsync(() => env.idOf(SymptomKey.migraine)))!;
    expect((await tester.runAsync(() => env.repo.getDay(DateTime(2026, 9, 8))))!.value(id), 1);
    // Raster im Hintergrund aktualisiert sich über den Stream
    expect(find.text('Migränetage: 6 · Attacken: 3'), findsOneWidget);
  });
}
