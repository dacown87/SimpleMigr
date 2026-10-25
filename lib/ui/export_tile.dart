import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/repository.dart';
import '../pdf/month_pdf.dart';
import 'util.dart';

/// Wählt einen Zeitraum und teilt die Monate als PDF (A4 quer, eine Seite pro Monat).
class ExportTile extends StatelessWidget {
  const ExportTile({super.key, required this.repo, this.clock = DateTime.now});

  final Repository repo;
  final DateTime Function() clock;

  Future<void> _export(BuildContext context) async {
    final now = clock();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month, now.day),
      ),
      helpText: 'Zeitraum (ganze Monate)',
      saveText: 'Exportieren',
    );
    if (range == null || !context.mounted) return;
    await guarded(context, () async {
      final months = <MonthData>[];
      var y = range.start.year, mo = range.start.month;
      while (y < range.end.year || (y == range.end.year && mo <= range.end.month)) {
        months.add(await repo.getMonth(y, mo));
        mo++;
        if (mo > 12) {
          mo = 1;
          y++;
        }
      }
      final bytes = await buildMonthsPdf(months);
      final first = months.first, last = months.last;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'simplemigr_${first.year}-${first.month.toString().padLeft(2, '0')}'
            '_${last.year}-${last.month.toString().padLeft(2, '0')}.pdf',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('export-pdf'),
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: const Text('Als PDF teilen'),
      subtitle: const Text('Ein oder mehrere Monate, A4 quer'),
      onTap: () => _export(context),
    );
  }
}
