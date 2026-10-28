import 'attacks.dart';
import 'database.dart';
import 'dates.dart';
import 'repository.dart';

/// Kennzahlen eines Monats der Arzt-Zusammenfassung.
class ReportMonth {
  ReportMonth(this.year, this.month, {required this.firstDay, required this.lastDay});

  final int year;
  final int month;

  /// Erster und letzter Tag des Monats innerhalb des Zeitraums.
  final int firstDay;
  final int lastDay;

  int migraineDays = 0;
  int attacks = 0;
  int strongPainDays = 0;
  int auraDays = 0;
  int nauseaDays = 0;

  /// Der Zeitraum deckt den Monat nicht ganz ab.
  bool get partial => firstDay != 1 || lastDay != daysInMonth(year, month);
}

class ReportAttack {
  ReportAttack(this.start, this.days);

  final DateTime start;
  final List<DateTime> days;

  /// 0, wenn an keinem Tag Schmerzen eingetragen sind.
  int maxPain = 0;
  bool aura = false;

  /// Namen der Aura-Symptome (Sicht, Sprache, …) über alle Tage der Attacke.
  final auraKinds = <String>{};

  /// Startet im Fenster Tag −2 bis +3 um einen Periodenbeginn.
  bool perimenstrual = false;

  /// Zyklustag des Starts (Periodenbeginn = Tag 1), wenn bekannt und nicht perimenstruell.
  int? cycleDay;

  int get length => days.length;
}

/// Einnahme einer Substanz (oder „ohne Angabe“, wenn nur „Medikamente genommen“ gesetzt ist).
class ReportMedication {
  ReportMedication(this.name, {required this.triptan, this.unnamed = false});

  final String name;
  final bool triptan;
  final bool unnamed;

  /// Monatsindex in [Report.months] -> Einnahmetage.
  final daysPerMonth = <int, int>{};
  int helpedDays = 0;

  int get totalDays => daysPerMonth.values.fold(0, (a, b) => a + b);

  /// Ab so vielen Einnahmetagen pro Monat gibt die Zusammenfassung einen Hinweis.
  int get limit => triptan ? Report.triptanLimit : Report.painkillerLimit;
}

/// Häufung von Attacken außerhalb der Periode an ähnlichen Zyklustagen.
class CyclePattern {
  const CyclePattern(this.fromDay, this.toDay, this.attacks);

  final int fromDay;
  final int toDay;
  final List<ReportAttack> attacks;
}

/// Gruppen der eigenen Beschreibung (Abschnitt 3).
enum DescriptionGroup {
  prodrome('Vorboten und Nachphase'),
  speech('Sprache (Wortfindung, Sprachverständnis)'),
  motor('Motorik/Koordination'),
  sensory('Gefühl (Kribbeln, Taubheit)'),
  vision('Sehen'),
  cognition('Kognition/Reizverarbeitung'),
  other('Sonstiges');

  const DescriptionGroup(this.title);
  final String title;

  /// Motorische Symptome und Sprachstörungen müssen ärztlich gezielt eingeordnet werden.
  bool get highlight => this == speech || this == motor;
}

/// Ordnet einen Punkt der Beschreibung per Stichwort einer Gruppe zu.
/// Die Reihenfolge zählt: der erste Treffer gewinnt.
DescriptionGroup describeGroup(String point) {
  final t = point.toLowerCase();
  bool any(List<String> words) => words.any(t.contains);
  if (RegExp(r'^vor\b(?! allem)|\bvorher\b|vorbote').hasMatch(t) ||
      any(['danach', 'nachher', 'kater', 'gereizt', 'gähn', 'heißhunger'])) {
    return DescriptionGroup.prodrome;
  }
  if (any(['sprach', 'sprech', 'wort', 'wörter', 'satz', 'sätze', 'buchstab', 'lesen'])) {
    return DescriptionGroup.speech;
  }
  if (any([
    'greif', 'griff', 'fallen', 'runter', 'stoß', 'stoss', 'stolper', 'laufe', 'gangbild',
    'kau', 'zunge', 'schluck', 'lähm', 'paraly', 'koordin', 'handlung', 'bewegung',
    'gleichgewicht', 'schwindel',
  ])) {
    return DescriptionGroup.motor;
  }
  if (any(['kribbel', 'taub', 'pelzig', 'ameisen'])) return DescriptionGroup.sensory;
  if (any([
    'seh', 'sicht', 'sieh', 'blitz', 'flimmer', 'zacken', 'auge', 'blind', 'verschwomm',
    'doppel', 'schleier',
  ])) {
    return DescriptionGroup.vision;
  }
  if (any([
    'konzentr', 'reiz', 'aufnahme', 'denk', 'verwirr', 'kurzschluss', 'licht', 'lärm',
    'geräusch', 'geruch', 'vergess', 'gedächtnis', 'benommen',
  ])) {
    return DescriptionGroup.cognition;
  }
  return DescriptionGroup.other;
}

/// Arzt-Zusammenfassung eines Zeitraums. Rechnet nur, was erfasst ist; was fehlt,
/// bleibt leer bzw. `null` und erscheint im PDF als „nicht erfasst“.
class Report {
  Report._(this.from, this.to, {this.requestedFrom});

  static const triptanLimit = 10;
  static const painkillerLimit = 15;

  /// Periodenbeginn = erster Periodentag nach so vielen periodenfreien Tagen.
  static const periodGap = 5;

  /// Längere Abstände zwischen zwei Periodenbeginnen gelten als Erfassungslücke.
  static const maxCycle = 60;

  /// Erster ausgewerteter Tag. Liegt der gewählte Beginn vor dem ersten Eintrag
  /// im Tagebuch, beginnt die Auswertung erst dort (davor ist nichts erfasst).
  final DateTime from;

  /// Der gewählte Beginn, wenn er vor dem ersten Eintrag lag.
  final DateTime? requestedFrom;
  final DateTime to;
  final months = <ReportMonth>[];
  final attacks = <ReportAttack>[];

  /// Periodenbeginne im Zeitraum. `null`, wenn es keine Periode gibt oder keine eingetragen ist.
  List<DateTime>? periodStarts;
  final cycleLengths = <int>[];
  CyclePattern? pattern;

  final medications = <ReportMedication>[];

  /// Tage je Aura-Symptom (Sicht, Sprache, …) im Zeitraum, nur mit Einträgen.
  final auraSymptomDays = <String, int>{};

  /// Punkte der eigenen Beschreibung je Gruppe (nur Gruppen mit Punkten).
  final description = <DescriptionGroup, List<String>>{};

  /// Skalen-Erklärungen aus der Beschreibung („Schmerzen: 1 = leicht, …“).
  final scaleNotes = <String>[];

  /// Datenbasierte Fragen an die Ärztin/den Arzt.
  final questions = <String>[];

  bool get hasPeriodData => periodStarts != null;

  /// Monate, die der Zeitraum ganz abdeckt (für Spanne und Trend).
  List<ReportMonth> get fullMonths => [for (final m in months) if (!m.partial) m];

  List<ReportAttack> get perimenstrualAttacks => [for (final a in attacks) if (a.perimenstrual) a];

  static Future<Report> load(Repository repo, DateTime from, DateTime to) async {
    final db = repo.db;
    return compute(
      from: from,
      to: to,
      symptoms: await db.select(db.symptoms).get(),
      values: await db.select(db.dayValues).get(),
      newAttackDays: [
        for (final m in await db.select(db.dayMeta).get())
          if (m.newAttack) fromKey(m.date),
      ],
      description: await repo.getDescription(),
    );
  }

  static Report compute({
    required DateTime from,
    required DateTime to,
    required List<Symptom> symptoms,
    required List<DayValue> values,
    required List<DateTime> newAttackDays,
    String description = '',
  }) {
    final firstEntry = values.where((v) => v.value != 0).map((v) => v.date).fold<String?>(
        null, (a, b) => a == null || b.compareTo(a) < 0 ? b : a);
    var start = dateOnly(from);
    DateTime? requested;
    if (firstEntry != null &&
        fromKey(firstEntry).isAfter(start) &&
        !fromKey(firstEntry).isAfter(dateOnly(to))) {
      requested = start;
      start = fromKey(firstEntry);
    }
    final r = Report._(start, dateOnly(to), requestedFrom: requested);
    final byKey = {for (final s in symptoms) if (s.key != null) s.key!: s};
    final days = <String, Map<int, int>>{};
    for (final v in values) {
      if (v.value != 0) (days[v.date] ??= {})[v.symptomId] = v.value;
    }
    int value(DateTime d, String key) {
      final s = byKey[key];
      return s == null ? 0 : days[toKey(d)]?[s.id] ?? 0;
    }

    final auraSymptoms = [for (final s in symptoms) if (s.grp == SymptomGroup.aura) s];
    bool auraDay(DateTime d) =>
        value(d, SymptomKey.aura) != 0 ||
        auraSymptoms.any((s) => (days[toKey(d)]?[s.id] ?? 0) != 0);
    bool inRange(DateTime d) => !d.isBefore(r.from) && !d.isAfter(r.to);

    // ── Monate ──
    final monthIndex = <String, int>{};
    var y = r.from.year, m = r.from.month;
    while (y < r.to.year || (y == r.to.year && m <= r.to.month)) {
      monthIndex['$y-$m'] = r.months.length;
      r.months.add(ReportMonth(
        y,
        m,
        firstDay: y == r.from.year && m == r.from.month ? r.from.day : 1,
        lastDay: y == r.to.year && m == r.to.month ? r.to.day : daysInMonth(y, m),
      ));
      if (++m > 12) {
        m = 1;
        y++;
      }
    }
    ReportMonth monthOf(DateTime d) => r.months[monthIndex['${d.year}-${d.month}']!];

    for (var d = r.from; !d.isAfter(r.to); d = DateTime(d.year, d.month, d.day + 1)) {
      final m = monthOf(d);
      if (value(d, SymptomKey.migraine) != 0) m.migraineDays++;
      if (value(d, SymptomKey.pain) == 3) m.strongPainDays++;
      if (auraDay(d)) m.auraDays++;
      if (value(d, SymptomKey.nausea) != 0) m.nauseaDays++;
      for (final s in auraSymptoms) {
        if ((days[toKey(d)]?[s.id] ?? 0) != 0) {
          r.auraSymptomDays[s.name] = (r.auraSymptomDays[s.name] ?? 0) + 1;
        }
      }
    }

    // ── Attacken (alle Daten, damit Attacken über den Zeitraumbeginn richtig zählen) ──
    final migraineDays = [
      for (final e in days.entries)
        if (value(fromKey(e.key), SymptomKey.migraine) != 0) fromKey(e.key),
    ];
    final migraineSet = {for (final d in migraineDays) toKey(d)};
    final starts = attackStarts(migraineDays, newAttackDays);
    final startSet = {for (final s in starts) toKey(s)};
    for (final start in starts.where(inRange)) {
      final attackDays = [start];
      for (var d = DateTime(start.year, start.month, start.day + 1);
          migraineSet.contains(toKey(d)) && !startSet.contains(toKey(d));
          d = DateTime(d.year, d.month, d.day + 1)) {
        attackDays.add(d);
      }
      final a = ReportAttack(start, attackDays);
      for (final d in attackDays) {
        a.maxPain = value(d, SymptomKey.pain) > a.maxPain ? value(d, SymptomKey.pain) : a.maxPain;
        if (auraDay(d)) a.aura = true;
        for (final s in auraSymptoms) {
          if ((days[toKey(d)]?[s.id] ?? 0) != 0) a.auraKinds.add(s.name);
        }
      }
      r.attacks.add(a);
      monthOf(start).attacks++;
    }

    // ── Zyklus ──
    final period = byKey[SymptomKey.period];
    final periodDays = [
      if (period != null)
        for (final e in days.entries)
          if (e.value.containsKey(period.id)) fromKey(e.key),
    ]..sort();
    if (periodDays.isNotEmpty) {
      final periodSet = {for (final d in periodDays) toKey(d)};
      final allStarts = [
        for (final d in periodDays)
          if (List.generate(periodGap, (i) => DateTime(d.year, d.month, d.day - i - 1))
              .every((p) => !periodSet.contains(toKey(p))))
            d,
      ];
      r.periodStarts = allStarts.where(inRange).toList();
      for (var i = 1; i < allStarts.length; i++) {
        final len = allStarts[i].difference(allStarts[i - 1]).inDays;
        if (inRange(allStarts[i]) && len <= maxCycle) r.cycleLengths.add(len);
      }
      for (final a in r.attacks) {
        final offsets = [for (final p in allStarts) _dayDiff(p, a.start)];
        if (offsets.any((o) => o >= -2 && o <= 3)) {
          a.perimenstrual = true;
        } else {
          final before = offsets.where((o) => o > 0 && o < maxCycle);
          if (before.isNotEmpty) a.cycleDay = before.reduce((x, y) => x < y ? x : y) + 1;
        }
      }
      r.pattern = _findPattern(r.attacks);
    }

    // ── Medikamente ──
    final medication = byKey[SymptomKey.medication];
    final helped = byKey[SymptomKey.medHelped];
    final substances = [for (final s in symptoms) if (s.grp == SymptomGroup.medication) s]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final meds = {
      for (final s in substances) s.id: ReportMedication(s.name, triptan: isTriptan(s.name)),
    };
    final unnamed = ReportMedication('Ohne Angabe der Substanz', triptan: false, unnamed: true);
    for (var d = r.from; !d.isAfter(r.to); d = DateTime(d.year, d.month, d.day + 1)) {
      final day = days[toKey(d)] ?? const {};
      final taken = [for (final id in day.keys) if (meds.containsKey(id)) meds[id]!];
      if (taken.isEmpty && medication != null && day.containsKey(medication.id)) {
        taken.add(unnamed);
      }
      final mi = monthIndex['${d.year}-${d.month}']!;
      for (final m in taken) {
        m.daysPerMonth[mi] = (m.daysPerMonth[mi] ?? 0) + 1;
        if (helped != null && day.containsKey(helped.id)) m.helpedDays++;
      }
    }
    r.medications.addAll([...meds.values, unnamed].where((m) => m.totalDays > 0));

    // ── Beschreibung ──
    for (final line in Repository.descriptionPoints(description)) {
      final point = line.replaceFirst(RegExp(r'^[-•*–]\s*'), '').trim();
      // Zwischenüberschriften („Während einer Attacke:“) tragen keinen Inhalt.
      if (point.isEmpty || point.endsWith(':')) continue;
      if (RegExp(r'\d\s*=').hasMatch(point)) {
        r.scaleNotes.add(point);
        continue;
      }
      (r.description[describeGroup(point)] ??= []).add(point);
    }

    r._addQuestions();
    return r;
  }

  /// Tage von [a] bis [b] (positiv, wenn [b] später liegt), sommerzeitfest.
  static int _dayDiff(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// Fenster von 4 Zyklustagen mit den meisten Attacken außerhalb der Periode.
  /// Nur ein Muster, wenn es mindestens 2 Attacken und die Hälfte davon trifft.
  static CyclePattern? _findPattern(List<ReportAttack> attacks) {
    final known = [for (final a in attacks) if (a.cycleDay != null) a];
    CyclePattern? best;
    for (final a in known) {
      final from = a.cycleDay!, to = from + 3;
      final hits = [for (final b in known) if (b.cycleDay! >= from && b.cycleDay! <= to) b];
      if (best == null || hits.length > best.attacks.length) {
        final days = [for (final h in hits) h.cycleDay!];
        best = CyclePattern(
          days.reduce((x, y) => x < y ? x : y),
          days.reduce((x, y) => x > y ? x : y),
          hits,
        );
      }
    }
    if (best == null || best.attacks.length < 2 || best.attacks.length * 2 < known.length) {
      return null;
    }
    return best;
  }

  /// Fragen, die nur erscheinen, wenn die Daten sie begründen. Höchstens 6.
  void _addQuestions() {
    final motorOrSpeech = description.keys.any((g) => g.highlight) ||
        attacks.any((a) => a.auraKinds.any((k) => describeGroup(k) == DescriptionGroup.speech));
    final auraAttacks = attacks.where((a) => a.aura).length;
    final hasAura = auraAttacks > 0 || motorOrSpeech;

    if (motorOrSpeech) {
      questions.add('Wie sind die Aura-Symptome einzuordnen (typische Aura oder motorische '
          'bzw. Hirnstamm-Aura)? Ist weitere Diagnostik (z. B. MRT) nötig?');
    } else if (hasAura) {
      questions.add('Wie ist die Aura einzuordnen, und ist weitere Diagnostik nötig?');
    }

    final counted = fullMonths.isNotEmpty ? fullMonths : months;
    final perMonth = [for (final m in counted) m.migraineDays];
    if (perMonth.isNotEmpty && perMonth.reduce((a, b) => a > b ? a : b) >= 4) {
      questions.add('Ist bei ${formatDecimal(average(perMonth))} Migränetagen pro Monat '
          '(${spanText(perMonth)}) eine vorbeugende Behandlung (Prophylaxe) angezeigt, '
          'und welche kommt infrage?');
    }

    final triptans = [for (final m in medications) if (m.triptan) m.name];
    if (hasAura) {
      questions.add('Welche Akutmedikation ist bei dieser Aura-Form geeignet '
          '(z. B. Triptane ja/nein)?${triptans.isEmpty ? '' : ' Derzeit: ${triptans.join(', ')}.'}');
    } else if (medications.isEmpty) {
      questions.add('Welche Akutmedikation ist sinnvoll, und wie oft darf sie genommen werden?');
    }

    if (hasAura && (periodStarts?.isNotEmpty ?? false)) {
      questions.add('Welche hormonellen Optionen (z. B. Verhütung) kommen bei Migräne mit '
          'Aura infrage – östrogenfrei?');
    }

    final peri = perimenstrualAttacks.length;
    if (hasPeriodData && attacks.length >= 3 && peri * 10 >= attacks.length * 4) {
      questions.add('${percent(peri, attacks.length)} der Attacken beginnen rund um die '
          'Periode. Kommt eine gezielte Behandlung in diesen Tagen infrage?');
    }

    final over = [
      for (final m in medications)
        if (m.daysPerMonth.values.any((d) => d >= m.limit)) m.name,
    ];
    if (over.isNotEmpty) {
      questions.add('Besteht bei der Einnahmehäufigkeit (${over.join(', ')}) ein Risiko für '
          'Kopfschmerz durch Medikamentenübergebrauch?');
    }

    if (questions.length > 6) questions.removeRange(6, questions.length);
  }
}

double average(List<int> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

double median(List<int> xs) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid].toDouble() : (s[mid - 1] + s[mid]) / 2;
}

/// `3,5`, aber `4` statt `4,0`.
String formatDecimal(double v) {
  final rounded = (v * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
}

/// `2–7` bzw. `4`, wenn alle Werte gleich sind.
String spanText(List<int> xs) {
  final lo = xs.reduce((a, b) => a < b ? a : b), hi = xs.reduce((a, b) => a > b ? a : b);
  return lo == hi ? '$lo' : '$lo–$hi';
}

String percent(int part, int whole) => whole == 0 ? '0 %' : '${(part * 100 / whole).round()} %';
