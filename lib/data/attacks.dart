import 'dates.dart';

/// Erster Tag jeder Attacke, aufsteigend.
///
/// [migraineDays]: alle Migränetage (Reihenfolge egal, Duplikate egal).
/// [newAttackDays]: Tage mit „neue Attacke“ (`/`); wirken nur an Migränetagen.
///
/// Ein Migränetag beginnt eine Attacke, wenn der Vortag kein Migränetag war
/// oder wenn der Tag selbst `/` trägt.
List<DateTime> attackStarts(
  Iterable<DateTime> migraineDays,
  Iterable<DateTime> newAttackDays,
) {
  final migraine = {for (final d in migraineDays) toKey(d)};
  final slash = {for (final d in newAttackDays) toKey(d)};
  final days = migraine.map(fromKey).toList()..sort();
  return [
    for (final d in days)
      if (!migraine.contains(toKey(previousDay(d))) || slash.contains(toKey(d))) d,
  ];
}

/// Attacken, deren erster Tag im Monat liegt.
/// Für Attacken über die Monatsgrenze muss der letzte Tag des Vormonats
/// in [migraineDays] enthalten sein.
int attacksInMonth(
  int year,
  int month,
  Iterable<DateTime> migraineDays,
  Iterable<DateTime> newAttackDays,
) =>
    attackStarts(migraineDays, newAttackDays)
        .where((d) => d.year == year && d.month == month)
        .length;
