import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/dates.dart';
import '../data/repository.dart';
import 'day_editor.dart';
import 'theme.dart';
import 'util.dart';
import 'weather_card.dart' show signed1;

const double _cell = 44;
const double _nameWidth = 120;

class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key, required this.repo, this.clock = DateTime.now});

  final Repository repo;
  final DateTime Function() clock;

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  late int _year = widget.clock().year;
  late int _month = widget.clock().month;

  void _shift(int delta) {
    final d = DateTime(_year, _month + delta);
    setState(() {
      _year = d.year;
      _month = d.month;
    });
  }

  void _openDay(DateTime date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(germanDate(date),
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: DayEditor(repo: widget.repo, date: date)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Vorheriger Monat',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shift(-1),
            ),
            Text('${monthName(_month)} $_year'),
            IconButton(
              tooltip: 'Nächster Monat',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shift(1),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<MonthData>(
        stream: widget.repo.watchMonth(_year, _month),
        builder: (context, snap) {
          final m = snap.data;
          if (m == null || m.year != _year || m.month != _month) {
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              Expanded(
                child: MonthGrid(
                  key: ValueKey((m.year, m.month)),
                  data: m,
                  today: dateOnly(widget.clock()),
                  onDayTap: _openDay,
                ),
              ),
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false,
                  child: Text(
                    'Migränetage: ${m.migraineDays} · Attacken: ${m.attacks}',
                    key: const ValueKey('summary'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reihenfolge der Zeilen: Gruppe, dann Sortierung.
List<Symptom> gridRows(List<Symptom> symptoms) => [
      for (final g in SymptomGroup.values)
        ...symptoms.where((s) => s.grp == g),
    ];

/// Ausklappbarer Abschnitt des Rasters, analog zu den Blöcken im Tages-Editor.
class _GridSection {
  const _GridSection(this.title, this.symptoms, {this.switchKey});

  final String title;
  final List<Symptom> symptoms;

  /// Symptom, das im Editor der Schalter des Blocks ist (Aura, Medikamente).
  final String? switchKey;
}

/// Hauptzeilen (immer sichtbar) und Abschnitte (aufklappbar) des Rasters.
(List<Symptom>, List<_GridSection>) _gridLayout(List<Symptom> all) {
  const mainKeys = [SymptomKey.migraine, SymptomKey.pain, SymptomKey.period];
  const auraKeys = [SymptomKey.aura];
  const medKeys = [SymptomKey.medication, SymptomKey.medHelped];
  final rows = gridRows(all);
  final main = [
    for (final k in mainKeys) ...rows.where((s) => s.key == k),
  ];
  final sections = [
    _GridSection('Symptome', [
      for (final s in rows)
        if (s.grp == SymptomGroup.general && (s.key == null || s.key == SymptomKey.nausea)) s,
    ]),
    _GridSection('Aura', switchKey: SymptomKey.aura, [
      for (final s in rows)
        if (auraKeys.contains(s.key) || s.grp == SymptomGroup.aura) s,
    ]),
    _GridSection('Medikamente', switchKey: SymptomKey.medication, [
      for (final s in rows)
        if (medKeys.contains(s.key)) s,
    ]),
    _GridSection('Auslöser', [
      for (final s in rows)
        if (s.grp == SymptomGroup.trigger) s,
    ]),
  ];
  return (main, [for (final g in sections) if (g.symptoms.isNotEmpty) g]);
}

class MonthGrid extends StatefulWidget {
  const MonthGrid({super.key, required this.data, required this.today, required this.onDayTap});

  final MonthData data;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid> {
  // Im aktuellen Monat startet das Raster in der Nähe von heute.
  late final _scroll = ScrollController(
    initialScrollOffset: widget.today.year == widget.data.year &&
            widget.today.month == widget.data.month
        ? (widget.today.day - 3).clamp(0, 31) * _cell
        : 0,
  );

  final _open = <String>{};

  void _toggle(String title) =>
      setState(() => _open.contains(title) ? _open.remove(title) : _open.add(title));

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data, today = widget.today, onDayTap = widget.onDayTap;
    final days = monthDays(data.year, data.month);
    final (main, sections) = _gridLayout(data.symptoms);
    final line = BorderSide(color: AppColors.surfaceHigh.withValues(alpha: 0.8));

    Widget nameCell(String text, {bool dim = false}) => Container(
          height: _cell,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(border: Border(top: line)),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: dim ? AppColors.textDim : AppColors.text)),
        );

    // Kopfzeile eines Abschnitts: Name mit Pfeil; zugeklappt stehen je Tag die
    // Kürzel der gewählten Einträge darin. Ist nur der Schalter des Blocks an
    // (Aura, Medikamente), steht dort ein Haken.
    Widget header(String title, bool open, {required Key key, required VoidCallback onTap}) =>
        InkWell(
          key: key,
          onTap: onTap,
          child: Container(
            height: _cell,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 20),
              ],
            ),
          ),
        );

    Widget headerDayCell(_GridSection? g, bool open, DateTime d) {
      final chosen = open || g == null
          ? const <Symptom>[]
          : [for (final s in g.symptoms) if (data.day(d).value(s.id) != 0) s];
      final switchKey = g?.switchKey;
      final details = [for (final s in chosen) if (switchKey == null || s.key != switchKey) s];
      return Container(
        width: _cell,
        height: _cell,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: line),
        ),
        child: details.isNotEmpty
            ? _CollapsedCell(symptoms: details, day: data.day(d))
            : chosen.isNotEmpty
                ? const Icon(Icons.check, size: 20, color: AppColors.text)
                : null,
      );
    }

    const weatherTitle = 'Wetter';
    final weatherOpen = _open.contains(weatherTitle);

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feste Spalte mit den Namen
          SizedBox(
            width: _nameWidth,
            child: Column(
              children: [
                const SizedBox(height: _cell),
                for (final s in main) nameCell(s.name, dim: s.archived),
                for (final g in sections) ...[
                  header(g.title, _open.contains(g.title),
                      key: ValueKey('section-${g.title}'), onTap: () => _toggle(g.title)),
                  if (_open.contains(g.title))
                    for (final s in g.symptoms) nameCell(s.name, dim: s.archived),
                ],
                if (data.hasWeather) ...[
                  header(weatherTitle, weatherOpen,
                      key: const ValueKey('section-$weatherTitle'),
                      onTap: () => _toggle(weatherTitle)),
                  if (weatherOpen)
                    for (final label in const ['Luftdruck', 'Druck ±'])
                      nameCell(label, dim: true),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final d in days)
                    InkWell(
                      key: ValueKey('day-${d.day}'),
                      onTap: () => onDayTap(d),
                      child: Column(
                        children: [
                          Container(
                            width: _cell,
                            height: _cell,
                            alignment: Alignment.center,
                            decoration: d == today
                                ? BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(color: AppColors.accent, width: 3)),
                                  )
                                : null,
                            child: Text('${d.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: d == today ? FontWeight.bold : null,
                                )),
                          ),
                          for (final s in main) _GridCell(symptom: s, day: data.day(d)),
                          for (final g in sections) ...[
                            headerDayCell(g, _open.contains(g.title), d),
                            if (_open.contains(g.title))
                              for (final s in g.symptoms) _GridCell(symptom: s, day: data.day(d)),
                          ],
                          if (data.hasWeather) ...[
                            headerDayCell(null, weatherOpen, d),
                            if (weatherOpen) ...[
                              _WeatherCell(
                                text: data.day(d).weather?.pressureMean?.round().toString() ?? '',
                              ),
                              _WeatherCell(
                                text: data.day(d).pressureDelta == null
                                    ? ''
                                    : signed1(data.day(d).pressureDelta!),
                                strong: (data.day(d).pressureDelta ?? 0).abs() >= 5,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.symptom, required this.day});

  final Symptom symptom;
  final DayData day;

  @override
  Widget build(BuildContext context) {
    final v = day.value(symptom.id);
    final color = colorForKey(symptom.key);
    String text = '';
    if (v != 0) {
      if (symptom.kind == SymptomKind.scale0to3) {
        text = '$v';
      } else if (symptom.key == SymptomKey.migraine) {
        text = day.newAttack ? '/' : '';
      } else if (color == null) {
        text = 'X';
      }
    }
    return Container(
      width: _cell,
      height: _cell,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: v != 0 && color != null ? color : null,
        border: Border(
          top: BorderSide(color: AppColors.surfaceHigh.withValues(alpha: 0.8)),
          left: BorderSide(color: AppColors.surfaceHigh.withValues(alpha: 0.4)),
        ),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: v != 0 && color != null ? AppColors.onMigraine : AppColors.text,
          )),
    );
  }
}

/// Zugeklappter Abschnitt: Kürzel der gewählten Einträge untereinander, bei mehr als
/// drei die ersten zwei und „+n“.
class _CollapsedCell extends StatelessWidget {
  const _CollapsedCell({required this.symptoms, required this.day});

  final List<Symptom> symptoms;
  final DayData day;

  static String abbreviation(Symptom s, int value) {
    final name = s.name.trim();
    final short = name.length <= 4 ? name : name.substring(0, 3);
    return s.kind == SymptomKind.scale0to3 ? '$short $value' : short;
  }

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final s in symptoms.length > 3 ? symptoms.take(2) : symptoms)
        abbreviation(s, day.value(s.id)),
      if (symptoms.length > 3) '+${symptoms.length - 2}',
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final l in lines)
          Text(l,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              )),
      ],
    );
  }
}

class _WeatherCell extends StatelessWidget {
  const _WeatherCell({required this.text, this.strong = false});

  final String text;

  /// Große Druckänderung (≥ 5 hPa) wird rosa hinterlegt.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cell,
      height: _cell,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: strong ? AppColors.accent.withValues(alpha: 0.35) : null,
        border: Border(
          top: BorderSide(color: AppColors.surfaceHigh.withValues(alpha: 0.8)),
          left: BorderSide(color: AppColors.surfaceHigh.withValues(alpha: 0.4)),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
    );
  }
}
