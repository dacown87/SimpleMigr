import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/repository.dart';

/// Papiertabelle August/September 2026, abgelesen vom Foto
/// `docs/papier-aug-sep-2026.png`. Zeilen: Migräne (gelb), Schmerzen,
/// Periode (rot), Übelkeit, Sicht, Sprache; `/` am 4.9.
///
/// Auf dem Papier sind im September auch in der Spalte „31“ Migräne, Periode,
/// Übelkeit und Schmerz 1 eingetragen. Den 31.9. gibt es nicht; er fehlt hier.
class PaperMonth {
  const PaperMonth({
    required this.month,
    required this.migraine,
    required this.pain,
    required this.period,
    required this.nausea,
    required this.sicht,
    required this.sprache,
    this.slash = const [],
  });

  final int month;
  final List<int> migraine;
  final Map<int, int> pain; // Tag -> Stärke (0 auf dem Papier = nichts gespeichert)
  final List<int> period, nausea, sicht, sprache, slash;
}

const august = PaperMonth(
  month: 8,
  migraine: [10, 11, 12, 15, 16, 17, 29, 30, 31],
  pain: {10: 1, 11: 1, 12: 1, 15: 3, 16: 3, 17: 3, 29: 2, 30: 2, 31: 2},
  period: [10, 11, 12, 13, 14],
  nausea: [10, 29, 30, 31],
  sicht: [15, 16, 29, 30],
  sprache: [15, 16, 29, 30, 31],
);

const september = PaperMonth(
  month: 9,
  migraine: [2, 3, 4, 5, 6, 10, 11, 12, 27, 29, 30],
  pain: {2: 2, 3: 2, 4: 0, 5: 0, 6: 0, 10: 3, 11: 3, 12: 3, 27: 3, 29: 1, 30: 1},
  period: [4, 5, 6, 7, 8, 29, 30],
  nausea: [2, 3, 4, 5, 6, 29, 30],
  sicht: [4, 5, 6, 10, 11, 12],
  sprache: [4, 5, 6, 10, 11, 12],
  slash: [4],
);

void main() {
  test('Papierdaten Aug/Sep 2026: Summen und Zeilen wie auf dem Foto', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = Repository(db);
    final all = await db.select(db.symptoms).get();
    int key(String k) => all.firstWhere((s) => s.key == k).id;
    int name(String n) => all.firstWhere((s) => s.name == n).id;

    for (final m in [august, september]) {
      DateTime d(int day) => DateTime(2026, m.month, day);
      Future<void> flag(List<int> days, int id) async {
        for (final day in days) {
          await repo.setValue(d(day), id, 1);
        }
      }

      await flag(m.migraine, key(SymptomKey.migraine));
      for (final e in m.pain.entries) {
        await repo.setValue(d(e.key), key(SymptomKey.pain), e.value);
      }
      await flag(m.period, key(SymptomKey.period));
      await flag(m.nausea, key(SymptomKey.nausea));
      await flag(m.sicht, name('Sicht'));
      await flag(m.sprache, name('Sprache'));
      for (final day in m.slash) {
        await repo.setNewAttack(d(day), true);
      }
    }

    final aug = await repo.getMonth(2026, 8);
    final sep = await repo.getMonth(2026, 9);

    // Aug: 10.–12., 15.–17., 29.–31. = 9 Tage, 3 Attacken
    expect((aug.migraineDays, aug.attacks), (9, 3));
    // Sep: 2.–3., 4.–6. (/ am 4.), 10.–12., 27., 29.–30. = 11 Tage, 5 Attacken
    expect((sep.migraineDays, sep.attacks), (11, 5));

    int count(MonthData m, int id) =>
        m.days.values.where((d) => d.value(id) != 0).length;
    expect(count(aug, key(SymptomKey.period)), 5);
    expect(count(sep, key(SymptomKey.period)), 7);
    expect(count(aug, key(SymptomKey.nausea)), 4);
    expect(count(sep, key(SymptomKey.nausea)), 7);
    expect(count(aug, name('Sicht')), 4);
    expect(count(aug, name('Sprache')), 5);
    expect(count(sep, name('Sicht')), 6);
    expect(count(sep, name('Sprache')), 6);
    // Schmerz 0 (auf dem Papier eingekreist) wird nicht gespeichert
    expect(count(sep, key(SymptomKey.pain)), 8);
    expect(sep.day(DateTime(2026, 9, 5)).value(key(SymptomKey.pain)), 0);
    expect(sep.day(DateTime(2026, 9, 4)).newAttack, isTrue);
    expect(sep.day(DateTime(2026, 9, 27)).value(key(SymptomKey.pain)), 3);
  });
}
