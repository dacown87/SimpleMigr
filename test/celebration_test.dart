import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/celebration.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/ui/celebration_screen.dart';
import 'package:simplemigr/ui/celebration_tile.dart';

import 'helpers.dart';

class FakeCelebration implements Celebration {
  FakeCelebration({this.grant = true});
  final bool grant;
  @override
  bool enabled = false;
  @override
  Future<bool> enable() async => enabled = grant;
  @override
  Future<void> disable() async => enabled = false;
}

void main() {
  test('Monatsenden: letzter Tag 20 Uhr, über den Jahreswechsel', () {
    final ends = upcomingMonthEnds(DateTime(2026, 11, 15), count: 4);
    expect(ends, [
      DateTime(2026, 11, 30, 20),
      DateTime(2026, 12, 31, 20),
      DateTime(2027, 1, 31, 20),
      DateTime(2027, 2, 28, 20),
    ]);
    // Nach 20 Uhr am Monatsletzten zählt erst der nächste Monat.
    expect(upcomingMonthEnds(DateTime(2026, 10, 31, 20, 30), count: 1),
        [DateTime(2026, 11, 30, 20)]);
    expect(upcomingMonthEnds(DateTime(2028, 2, 1), count: 1), [DateTime(2028, 2, 29, 20)]);
  });

  test('Payload: Monat lesen, fremde Payloads ignorieren', () {
    expect(celebrationMonth('celebration:2026-10'), (year: 2026, month: 10));
    expect(celebrationMonth(null), isNull);
    expect(celebrationMonth('anderes'), isNull);
    expect(celebrationMonth('celebration:kaputt'), isNull);
  });

  test('Texte: Einzahl, Mehrzahl, migränefreier Monat', () {
    expect(celebrationText(0).headline, contains('Kein einziger'));
    expect(celebrationText(1).headline, contains('1 Migränetag!'));
    expect(celebrationText(6).headline, contains('6 Migränetage'));
    expect(celebrationText(14).headline, contains('immer noch da'));
  });

  dbWidgetTest('Vorschau zeigt die Migränetage des laufenden Monats', (tester, env) async {
    final migraine = await env.idOf(SymptomKey.migraine);
    await tester.runAsync(() async {
      for (final d in [3, 4, 10]) {
        await env.repo.setValue(DateTime(2026, 10, d), migraine, 1);
      }
    });
    final c = FakeCelebration();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CelebrationTile(
          celebration: c,
          repo: env.repo,
          clock: () => DateTime(2026, 10, 20),
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('celebration-switch')));
    await tester.pump();
    expect(c.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('celebration-preview')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.text('🎉 OKTOBER GESCHAFFT! 🎉'), findsOneWidget);
    expect(find.textContaining('3 Migränetage'), findsOneWidget);
    // 20 Tage bisher, 3 davon mit Migräne
    expect(find.text('17'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('celebration-cheer')));
    await tester.pump();
    expect(find.text('Legende! ✨'), findsOneWidget);
  });

  dbWidgetTest('Ohne Erlaubnis bleibt die Monatsfeier aus', (tester, env) async {
    final c = FakeCelebration(grant: false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CelebrationTile(celebration: c, repo: env.repo)),
    ));
    await tester.tap(find.byKey(const ValueKey('celebration-switch')));
    await tester.pump();
    expect(c.enabled, isFalse);
    expect(find.textContaining('keine Monatsfeier'), findsOneWidget);
  });
}
