/// Datum als `YYYY-MM-DD` in lokaler Zeit. Einzige Stelle, die Schlüssel erzeugt.
String toKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime fromKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Mitternacht lokal, ohne Uhrzeit.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Alle Tage eines Monats.
List<DateTime> monthDays(int year, int month) => [
      for (var d = 1; d <= daysInMonth(year, month); d++) DateTime(year, month, d),
    ];

/// Vortag (DateTime-Konstruktor rechnet Monats-/Jahresgrenzen und Sommerzeit korrekt).
DateTime previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
