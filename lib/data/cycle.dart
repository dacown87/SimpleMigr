import 'dates.dart';

/// Periodenbeginn = erster Periodentag nach so vielen periodenfreien Tagen.
const periodGap = 5;

/// Beginne aller Perioden, aufsteigend. [periodDays] in beliebiger Reihenfolge.
List<DateTime> periodStarts(Iterable<DateTime> periodDays) {
  final set = {for (final d in periodDays) toKey(d)};
  final days = set.map(fromKey).toList()..sort();
  return [
    for (final d in days)
      if (List.generate(
        periodGap,
        (i) => DateTime(d.year, d.month, d.day - i - 1),
      ).every((p) => !set.contains(toKey(p))))
        d,
  ];
}
