import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/cycle.dart';
import 'package:simplemigr/period_reminder.dart';
import 'package:simplemigr/ui/period_reminder_tile.dart';

class FakePeriodReminder implements PeriodReminder {
  FakePeriodReminder({this.grant = true, this.next});
  final bool grant;
  final DateTime? next;
  @override
  bool enabled = false;
  @override
  int cycleLength = 28;
  @override
  Future<bool> enable() async => enabled = grant;
  @override
  Future<void> disable() async => enabled = false;
  @override
  Future<void> setCycleLength(int days) async => cycleLength = days;
  @override
  Future<DateTime?> nextStart() async => next;
}

void main() {
  test('Periodenbeginne: erster Tag nach mindestens 5 freien Tagen', () {
    final days = [
      DateTime(2026, 9, 3),
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 2), // unsortiert
      DateTime(2026, 9, 6), // Lücke von 2 Tagen: gleiche Periode
      DateTime(2026, 9, 29), DateTime(2026, 9, 30),
    ];
    expect(periodStarts(days), [DateTime(2026, 9, 1), DateTime(2026, 9, 29)]);
    expect(periodStarts(const []), isEmpty);
  });

  test(
    'Erwarteter Beginn: Zykluslänge nach dem letzten, überfällige rücken vor',
    () {
      final last = DateTime(2026, 10, 20);
      // Erinnerung am 14.11. 9 Uhr für Beginn am 17.11.
      expect(
        expectedStart(last, 28, DateTime(2026, 11, 1)),
        DateTime(2026, 11, 17),
      );
      expect(
        expectedStart(last, 28, DateTime(2026, 11, 14, 8)),
        DateTime(2026, 11, 17),
      );
      // Erinnerung schon vorbei: der nächste Zyklus.
      expect(
        expectedStart(last, 28, DateTime(2026, 11, 14, 10)),
        DateTime(2026, 12, 15),
      );
      expect(
        upcomingPeriodReminders(last, 28, DateTime(2026, 11, 1), count: 3),
        [
          DateTime(2026, 11, 14, 9),
          DateTime(2026, 12, 12, 9),
          DateTime(2027, 1, 9, 9),
        ],
      );
    },
  );

  testWidgets('Einstellungen: einschalten, Zykluslänge ändern, Vorhersage', (
    tester,
  ) async {
    final r = FakePeriodReminder(next: DateTime(2026, 11, 17));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PeriodReminderTile(reminder: r)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('17. November 2026'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('cycle-length')))
          .enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('period-reminder-switch')));
    await tester.pumpAndSettle();
    expect(r.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('cycle-length')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cycle-length-field')),
      '31',
    );
    await tester.tap(find.byKey(const ValueKey('cycle-length-ok')));
    await tester.pumpAndSettle();
    expect(r.cycleLength, 31);
    expect(find.text('31 Tage'), findsOneWidget);

    // Unsinnige Werte werden nicht übernommen.
    await tester.tap(find.byKey(const ValueKey('cycle-length')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cycle-length-field')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('cycle-length-ok')));
    await tester.pumpAndSettle();
    expect(r.cycleLength, 31);
  });

  testWidgets('Ohne Periode: Hinweis zum Eintragen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeriodReminderTile(reminder: FakePeriodReminder()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Trag deine Periode'), findsOneWidget);
  });
}
