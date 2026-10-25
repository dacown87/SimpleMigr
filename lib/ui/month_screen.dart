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

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data, today = widget.today, onDayTap = widget.onDayTap;
    final days = monthDays(data.year, data.month);
    final rows = gridRows(data.symptoms);
    final line = BorderSide(color: AppColors.surfaceHigh.withValues(alpha: 0.8));

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
                for (final s in rows)
                  Container(
                    height: _cell,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    decoration: BoxDecoration(border: Border(top: line)),
                    child: Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: s.archived ? AppColors.textDim : AppColors.text,
                        )),
                  ),
                if (data.hasWeather)
                  for (final label in const ['Luftdruck', 'Druck ±'])
                    Container(
                      height: _cell,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      decoration: BoxDecoration(border: Border(top: line)),
                      child: Text(label,
                          style: const TextStyle(fontSize: 15, color: AppColors.textDim)),
                    ),
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
                          for (final s in rows)
                            _GridCell(symptom: s, day: data.day(d)),
                          if (data.hasWeather) ...[
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
