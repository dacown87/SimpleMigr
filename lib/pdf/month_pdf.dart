import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database.dart';
import '../data/dates.dart';
import '../data/repository.dart';
import '../ui/month_screen.dart' show gridRows;
import '../ui/util.dart' show monthName;

const _yellow = PdfColor.fromInt(0xFFF2D95C);
const _red = PdfColor.fromInt(0xFFD66B6B);
const _line = PdfColors.grey500;

/// Ein Dokument, A4 quer, eine Seite pro Monat, aufgebaut wie die Papiertabelle.
/// Eine [description] der eigenen Migräne steht davor auf eigener Seite, je Zeile ein Punkt.
Future<Uint8List> buildMonthsPdf(List<MonthData> months, {String description = ''}) async {
  final doc = pw.Document(title: 'SimpleMigr', author: 'SimpleMigr');
  if (description.trim().isNotEmpty) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        pw.Text('Meine Migräne',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        for (final point in Repository.descriptionPoints(description))
          pw.Bullet(text: latin1Safe(point), style: const pw.TextStyle(fontSize: 12)),
      ],
    ));
  }
  for (final m in months) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => _monthPage(m),
    ));
  }
  return doc.save();
}

/// Die eingebaute PDF-Schrift kennt nur Latin-1. Typografische Zeichen, die
/// Handy-Tastaturen gern einsetzen, werden durch einfache ersetzt.
String latin1Safe(String text) => text
    .replaceAll(RegExp('[„“”‟]'), '"')
    .replaceAll(RegExp('[‚‘’‛]'), "'")
    .replaceAll(RegExp('[–—−]'), '-')
    .replaceAll('…', '...')
    .replaceAll('•', '·')
    .replaceAll(RegExp(r'[^\u0000-\u00FF]'), '');

pw.Widget _monthPage(MonthData m) {
  final days = monthDays(m.year, m.month);
  final rows = gridRows(m.symptoms);

  pw.Widget cell(String text,
          {PdfColor? fill, bool bold = false, pw.Alignment align = pw.Alignment.center}) =>
      pw.Container(
        height: 17,
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3),
        color: fill,
        child: pw.Text(text,
            maxLines: 1,
            style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null)),
      );

  String text(Symptom s, DayData d) {
    final v = d.value(s.id);
    if (v == 0) return '';
    if (s.kind == SymptomKind.scale0to3) return '$v';
    if (s.key == SymptomKey.migraine) return d.newAttack ? '/' : '';
    if (s.key == SymptomKey.period) return '';
    return 'X';
  }

  PdfColor? fill(Symptom s, DayData d) {
    if (d.value(s.id) == 0) return null;
    return switch (s.key) {
      SymptomKey.migraine => _yellow,
      SymptomKey.period => _red,
      _ => null,
    };
  }

  final table = pw.Table(
    border: pw.TableBorder.all(color: _line, width: 0.4),
    columnWidths: {
      0: const pw.FixedColumnWidth(95),
      for (var i = 1; i <= days.length; i++) i: const pw.FlexColumnWidth(),
      days.length + 1: const pw.FixedColumnWidth(30),
    },
    children: [
      pw.TableRow(children: [
        cell(''),
        for (final d in days) cell('${d.day}', bold: true),
        cell('Tage', bold: true),
      ]),
      for (final s in rows)
        pw.TableRow(children: [
          cell(s.name, align: pw.Alignment.centerLeft),
          for (final d in days)
            cell(text(s, m.day(d)), fill: fill(s, m.day(d)), bold: true),
          cell('${days.where((d) => m.day(d).value(s.id) != 0).length}'),
        ]),
      if (m.hasWeather) ...[
        pw.TableRow(children: [
          cell('Luftdruck', align: pw.Alignment.centerLeft),
          for (final d in days) cell(m.day(d).weather?.pressureMean?.round().toString() ?? ''),
          cell(''),
        ]),
        pw.TableRow(children: [
          cell('Druck +/-', align: pw.Alignment.centerLeft),
          for (final d in days)
            cell(m.day(d).pressureDelta == null
                ? ''
                : m.day(d).pressureDelta!.toStringAsFixed(1)),
          cell(''),
        ]),
      ],
    ],
  );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('${monthName(m.month)} ${m.year}',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      table,
      pw.SizedBox(height: 10),
      pw.Text('Migränetage: ${m.migraineDays} · Attacken: ${m.attacks}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(
        'Legende: gelb = Migräne, rot = Periode, Zahl = Schmerzstärke (0-3), '
        'X = ja, / = neue Attacke, Tage = Anzahl Tage',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    ],
  );
}
