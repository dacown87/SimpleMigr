import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/repository.dart';

/// Testdaten im Stil der Papiertabelle. HINWEIS: synthetisch nach dem Beispiel
/// im Plan (2.–6.9. mit `/` am 4.9.), noch NICHT mit dem Foto abgeglichen.
/// Zum Abgleich die Einträge unten durch die echten Papierdaten ersetzen und
/// die erwarteten Summen anpassen.
class PaperDay {
  const PaperDay(this.m, this.d, {this.pain = 0, this.period = false, this.slash = false});
  final int m, d, pain;
  final bool period, slash;
}

const paper = [
  PaperDay(8, 28, pain: 1),
  PaperDay(8, 29, pain: 2, period: true),
  PaperDay(8, 30, pain: 2, period: true),
  PaperDay(8, 31, pain: 1),
  PaperDay(9, 1, pain: 1),
  PaperDay(9, 2, pain: 2),
  PaperDay(9, 3, pain: 3),
  PaperDay(9, 4, pain: 3, slash: true),
  PaperDay(9, 5, pain: 2),
  PaperDay(9, 6, pain: 1),
  PaperDay(9, 12, pain: 1),
  PaperDay(9, 20, pain: 2),
  PaperDay(9, 21, pain: 2),
];

void main() {
  test('Papierdaten Aug/Sep 2026: Summen', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = Repository(db);
    final all = await db.select(db.symptoms).get();
    int id(String k) => all.firstWhere((s) => s.key == k).id;

    for (final p in paper) {
      final date = DateTime(2026, p.m, p.d);
      await repo.setValue(date, id('migraine'), 1);
      if (p.pain > 0) await repo.setValue(date, id('pain'), p.pain);
      if (p.period) await repo.setValue(date, id('period'), 1);
      if (p.slash) await repo.setNewAttack(date, true);
    }

    final aug = await repo.getMonth(2026, 8);
    final sep = await repo.getMonth(2026, 9);
    // Aug: 28.–31. = 4 Tage, 1 Attacke (läuft in den September)
    expect((aug.migraineDays, aug.attacks), (4, 1));
    // Sep: 1.–6. (6), 12 (1), 20.–21. (2) = 9 Tage;
    // Attacken: 1.–3. (Fortsetzung aus Aug, zählt nicht), 4.–6. (/), 12., 20.–21. = 3
    expect((sep.migraineDays, sep.attacks), (9, 3));
    expect(sep.day(DateTime(2026, 9, 4)).newAttack, isTrue);
    expect(aug.day(DateTime(2026, 8, 29)).value(id('period')), 1);
  });
}
