import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/attacks.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);
List<DateTime> days(int m, Iterable<int> ds) => [for (final x in ds) d(m, x)];

void main() {
  test('leer → 0', () {
    expect(attacksInMonth(2026, 9, [], []), 0);
  });

  test('2.–6.9. ohne / → 1', () {
    expect(attacksInMonth(2026, 9, days(9, [2, 3, 4, 5, 6]), []), 1);
  });

  test('2.–6.9. mit / am 4.9. → 2', () {
    expect(attacksInMonth(2026, 9, days(9, [2, 3, 4, 5, 6]), days(9, [4])), 2);
  });

  test('/ am ersten Tag einer Folge → 1, nicht 2', () {
    expect(attacksInMonth(2026, 9, days(9, [2, 3, 4]), days(9, [2])), 1);
  });

  test('Lücke 2.,4. → 2', () {
    expect(attacksInMonth(2026, 9, days(9, [2, 4]), []), 2);
  });

  test('Attacke 30.8.–2.9. zählt im August, nicht im September', () {
    final m = [d(8, 30), d(8, 31), d(9, 1), d(9, 2)];
    expect(attacksInMonth(2026, 8, m, []), 1);
    expect(attacksInMonth(2026, 9, m, []), 0);
  });

  test('/ an Nicht-Migränetag wirkt nicht', () {
    expect(attacksInMonth(2026, 9, days(9, [2, 3]), days(9, [10])), 1);
  });

  test('Eingabe unsortiert und mit Duplikaten', () {
    expect(attackStarts(days(9, [4, 2, 3, 3]), []), [d(9, 2)]);
  });

  test('Jahreswechsel', () {
    final m = [DateTime(2025, 12, 31), DateTime(2026, 1, 1)];
    expect(attacksInMonth(2025, 12, m, []), 1);
    expect(attacksInMonth(2026, 1, m, []), 0);
  });
}
