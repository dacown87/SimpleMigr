import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/dates.dart';
import '../data/report.dart';
import '../data/repository.dart';
import '../pdf/report_pdf.dart';
import 'util.dart';

/// Einseitige Zusammenfassung für den Arzttermin als PDF teilen.
class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.repo, this.clock = DateTime.now});

  final Repository repo;
  final DateTime Function() clock;

  /// Vorauswahl: die letzten 6 Monate inklusive des laufenden, bis heute.
  static DateTimeRange defaultRange(DateTime now) =>
      DateTimeRange(start: DateTime(now.year, now.month - 5, 1), end: dateOnly(now));

  Future<void> _share(BuildContext context) async {
    final now = clock();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: dateOnly(now),
      initialDateRange: defaultRange(now),
      helpText: 'Zeitraum für die Zusammenfassung',
      saveText: 'Erstellen',
    );
    if (range == null || !context.mounted) return;
    await guarded(context, () async {
      final report = await Report.load(repo, range.start, range.end);
      final bytes = await buildReportPdf(report, now: now);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'migraene_zusammenfassung_${toKey(range.start)}_${toKey(range.end)}.pdf',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('report-pdf'),
      leading: const Icon(Icons.summarize_outlined),
      title: const Text('Zusammenfassung für den Arzt'),
      subtitle: const Text('Eine Seite: Verlauf, Symptome, Zyklus, Medikamente, Fragen'),
      onTap: () => _share(context),
    );
  }
}
