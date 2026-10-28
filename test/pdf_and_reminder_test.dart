import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/repository.dart';
import 'package:simplemigr/pdf/month_pdf.dart';
import 'package:simplemigr/reminder.dart';
import 'package:simplemigr/ui/reminder_tile.dart';
import 'package:simplemigr/ui/theme.dart';

class FakeReminder implements Reminder {
  FakeReminder({this.grant = true});
  final bool grant;
  @override
  bool enabled = false;
  @override
  TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);
  @override
  Future<bool> enable() async => enabled = grant;
  @override
  Future<void> disable() async => enabled = false;
  @override
  Future<void> setTime(TimeOfDay t) async => time = t;
}

void main() {
  test('PDF-Builder: leerer und voller Monat ohne Fehler', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = Repository(db);
    final empty = await repo.getMonth(2026, 9);

    final all = await db.select(db.symptoms).get();
    for (final s in all) {
      for (var d = 1; d <= 31; d++) {
        await repo.setValue(DateTime(2026, 8, d), s.id, s.kind == SymptomKind.scale0to3 ? 3 : 1);
      }
    }
    await repo.setNewAttack(DateTime(2026, 8, 5), true);
    final full = await repo.getMonth(2026, 8);

    final bytes = await buildMonthsPdf([empty, full]);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));

    // Beschreibung mit typografischen Zeichen als eigene erste Seite
    final withText = await buildMonthsPdf([full],
        description: 'Vorboten: Gähnen – dann „Blitze“ links.\n\nDauer 1–3 Tage.');
    expect(withText.length, greaterThan(bytes.length ~/ 3));
    expect(latin1Safe('„Blitze“ – 1…2 😖'), '"Blitze" - 1...2 ');
  });

  testWidgets('Erinnerung: Berechtigung abgelehnt → Schalter bleibt aus + Hinweis', (tester) async {
    final r = FakeReminder(grant: false);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: ReminderTile(reminder: r)),
    ));
    await tester.tap(find.byKey(const ValueKey('reminder-switch')));
    await tester.pump();
    await tester.pump();
    expect(r.enabled, isFalse);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('reminder-switch'))).value,
        isFalse);
    expect(find.textContaining('Erlaubnis'), findsOneWidget);
  });

  testWidgets('Erinnerung: erlaubt → an, Uhrzeit wählbar', (tester) async {
    final r = FakeReminder();
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: ReminderTile(reminder: r)),
    ));
    await tester.tap(find.byKey(const ValueKey('reminder-switch')));
    await tester.pump();
    await tester.pump();
    expect(r.enabled, isTrue);
    expect(find.text('Erinnerung'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reminder-time')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });
}
