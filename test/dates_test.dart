import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/dates.dart';

void main() {
  test('toKey/fromKey Roundtrip und Padding', () {
    expect(toKey(DateTime(2026, 9, 2)), '2026-09-02');
    expect(fromKey('2026-09-02'), DateTime(2026, 9, 2));
    expect(fromKey(toKey(DateTime(2024, 2, 29))), DateTime(2024, 2, 29));
  });

  test('toKey ignoriert die Uhrzeit', () {
    expect(toKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
  });

  test('Monatsgrenzen und Schaltjahr', () {
    expect(daysInMonth(2026, 2), 28);
    expect(daysInMonth(2024, 2), 29);
    expect(daysInMonth(2100, 2), 28);
    expect(previousDay(DateTime(2026, 3, 1)), DateTime(2026, 2, 28));
    expect(previousDay(DateTime(2026, 1, 1)), DateTime(2025, 12, 31));
  });

  test('Tage eines Monats (28/29/30/31)', () {
    expect(monthDays(2026, 2), hasLength(28));
    expect(monthDays(2024, 2), hasLength(29));
    expect(monthDays(2026, 9), hasLength(30));
    expect(monthDays(2026, 8), hasLength(31));
    expect(monthDays(2026, 8).first, DateTime(2026, 8, 1));
    expect(monthDays(2026, 8).last, DateTime(2026, 8, 31));
  });
}
