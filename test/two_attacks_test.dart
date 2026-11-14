import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/ui/month_screen.dart';
import 'package:simplemigr/ui/theme.dart';

import 'helpers.dart';

void main() {
  dbWidgetTest('Monatsansicht: 1.–3. und 6.–8. sind 2 Attacken', (tester, env) async {
    await tester.runAsync(() async {
      final m = await env.idOf(SymptomKey.migraine);
      for (final d in [1, 2, 3, 6, 7, 8]) {
        await env.repo.setValue(DateTime(2026, 11, d), m, 1);
      }
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MonthScreen(repo: env.repo, clock: () => DateTime(2026, 11, 14)),
    ));
    await settle(tester);
    expect(find.text('Migränetage: 6 · Attacken: 2'), findsOneWidget);
  });
}
