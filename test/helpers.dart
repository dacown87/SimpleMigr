import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/repository.dart';

class TestEnv {
  TestEnv(this.db) : repo = Repository(db);
  final AppDatabase db;
  final Repository repo;

  Future<int> idOf(String key) async =>
      (await db.select(db.symptoms).get()).firstWhere((s) => s.key == key).id;
}

/// Widget-Tests mit echter In-Memory-Datenbank. Datenbankzugriffe laufen
/// außerhalb der FakeAsync-Zone von `testWidgets`, daher `runAsync`.
void dbWidgetTest(String name, Future<void> Function(WidgetTester, TestEnv) body) {
  testWidgets(name, (tester) async {
    final env = TestEnv(AppDatabase(NativeDatabase.memory()));
    await body(tester, env);
    await tester.pumpWidget(const SizedBox());
    // Drift räumt abgebrochene Streams per Timer auf; einmal durchlaufen lassen.
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(seconds: 1));
  });
}

/// Pumpt, bis asynchrone DB-Streams ihre Daten geliefert haben.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

/// Scrollt zu einem Eintrag einer lazy aufgebauten Liste und macht ihn ganz sichtbar.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pump();
}
