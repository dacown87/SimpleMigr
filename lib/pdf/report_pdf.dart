import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/report.dart';
import '../ui/util.dart' show monthName;
import 'month_pdf.dart' show latin1Safe;

const _dim = PdfColors.grey700;

/// `25.04.2026` bzw. ohne Jahr `25.04.`.
String _date(DateTime d, {bool year = true}) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.'
    '${year ? d.year : ''}';

String _dates(Iterable<DateTime> ds) => ds.map((d) => _date(d, year: false)).join(', ');

/// Satzende, ohne einen Punkt zu verdoppeln (Datumslisten enden schon auf „.“).
String _end(String s) => s.endsWith('.') ? s : '$s.';

String _monthLabel(ReportMonth m) => m.partial
    ? '${monthName(m.month)} ${m.year} (${m.firstDay}.-${m.lastDay}.)'
    : '${monthName(m.month)} ${m.year}';

String _monthShort(ReportMonth m) => monthName(m.month).substring(0, 3);

String _monthCompact(ReportMonth m) =>
    '${_monthShort(m)} ${m.year}${m.partial ? ' (${m.firstDay}.-${m.lastDay}.)' : ''}';

/// Einseitige Zusammenfassung für den Arzttermin (A4 hoch), das Diagramm neben
/// der Tabelle. Passt das nicht auf eine Seite, kommt das Diagramm auf eine eigene
/// letzte Seite; reicht der Platz dann noch immer nicht, läuft der Text weiter
/// statt abgeschnitten zu werden. Bei nur einem Monat gibt es kein Diagramm.
Future<Uint8List> buildReportPdf(Report r, {DateTime? now}) async {
  if (r.months.length < 2) return _build(r, now ?? DateTime.now(), chart: _Chart.none).save();
  var pages = 0;
  final inline = _build(r, now ?? DateTime.now(), chart: _Chart.inline, onPages: (n) => pages = n);
  final bytes = await inline.save();
  if (pages <= 1) return bytes;
  return _build(r, now ?? DateTime.now(), chart: _Chart.ownPage).save();
}

enum _Chart { none, inline, ownPage }

/// Höhe des Diagramms unter der Tabelle bzw. auf eigener Seite.
const _inlineChartHeight = 110.0;
const _pageChartHeight = 300.0;

pw.Document _build(
  Report r,
  DateTime now, {
  required _Chart chart,
  void Function(int pages)? onPages,
}) {
  final doc = pw.Document(title: 'Migräne-Zusammenfassung', author: 'SimpleMigr');
  const body = pw.TextStyle(fontSize: 9.5);
  final bold = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
        child: pw.Text(latin1Safe(text),
            style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
      );
  // Eigener Stichpunkt statt pw.Bullet: dessen Zeilenabstand beim Umbruch kostet zu viel Platz.
  pw.Widget bullet(String text, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1, bottom: 1, left: 6),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            width: 3,
            height: 3,
            margin: const pw.EdgeInsets.only(top: 4, right: 6),
            decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.black),
          ),
          pw.Expanded(child: pw.Text(latin1Safe(text), style: strong ? bold : body)),
        ]),
      );
  pw.Widget para(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Text(latin1Safe(text), style: body),
      );

  pw.Widget footer(pw.Context ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          latin1Safe('Erstellt aus Patiententagebuch; Angaben selbst erfasst, nicht ärztlich '
              'validiert.${ctx.pagesCount > 1 ? '  Seite ${ctx.pageNumber}/${ctx.pagesCount}' : ''}'),
          style: const pw.TextStyle(fontSize: 8, color: _dim),
        ),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
    footer: (ctx) {
      onPages?.call(ctx.pagesCount);
      return footer(ctx);
    },
    build: (_) => [
      pw.Text(latin1Safe('Migräne-Zusammenfassung'),
          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(
        latin1Safe('Zeitraum ${_date(r.from)} - ${_date(r.to)}'
            '${r.requestedFrom == null ? '' : ' (Tagebuch beginnt am ${_date(r.from)})'}'
            '  ·  erstellt am '
            '${_date(now)}'),
        style: const pw.TextStyle(fontSize: 10, color: _dim),
      ),
      heading('1. Kurzüberblick'),
      for (final t in overview(r)) bullet(t),
      heading('2. Verlauf'),
      if (chart == _Chart.inline)
        // Diagramm neben der Tabelle: kostet keine zusätzliche Höhe.
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 11, child: _table(r, compact: true)),
          pw.SizedBox(width: 10),
          pw.Expanded(flex: 9, child: _chart(r, _inlineChartHeight, width: 210)),
        ])
      else
        _table(r),
      for (final s in r.scaleNotes)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(latin1Safe('Skala laut Patientin: $s'),
              style: const pw.TextStyle(fontSize: 8, color: _dim)),
        ),
      heading('3. Aura- und Begleitsymptome'),
      ..._symptoms(r, bullet, para),
      heading('4. Zyklusbezug'),
      for (final t in cycleText(r)) para(t),
      heading('5. Bisherige Behandlung'),
      for (final t in medicationText(r)) bullet(t),
      if (r.questions.isNotEmpty) ...[
        heading('6. Fragen an die Ärztin/den Arzt'),
        for (var i = 0; i < r.questions.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2, left: 6),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 12, child: pw.Text('${i + 1}.', style: body)),
              pw.Expanded(child: pw.Text(latin1Safe(r.questions[i]), style: body)),
            ]),
          ),
      ],
    ],
  ));
  if (chart == _Chart.ownPage) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
      footer: footer,
      build: (_) => [
        heading('Verlauf als Diagramm'),
        pw.SizedBox(height: 4),
        _chart(r, _pageChartHeight, width: 520),
      ],
    ));
  }
  return doc;
}

/// Reihen des Diagramms: Name, Farbe, Wert je Monat.
final _series = <(String, PdfColor, int Function(ReportMonth))>[
  ('Migränetage', const PdfColor.fromInt(0xFFE0B830), (m) => m.migraineDays),
  ('Aura-Tage', const PdfColor.fromInt(0xFF7B6BB0), (m) => m.auraDays),
  ('Tage Schmerz stark', const PdfColor.fromInt(0xFFD66B6B), (m) => m.strongPainDays),
];

/// Balken je Monat, gruppiert nach [_series]. Werte stehen über den Balken,
/// damit es auch schwarz-weiß gedruckt lesbar bleibt.
/// [width]: ungefähre Breite, nur für die Balkenbreite.
pw.Widget _chart(Report r, double height, {required double width}) {
  final n = r.months.length;
  final maxValue = [
    for (final m in r.months)
      for (final s in _series) s.$3(m),
  ].fold(0, (a, b) => a > b ? a : b);
  final step = maxValue > 20 ? 5 : (maxValue > 8 ? 2 : 1);
  final top = ((maxValue + step) ~/ step) * step;
  // Balkenbreite passend zur Zahl der Monate, Gruppe nimmt ~60 % des Platzes.
  final barWidth = (width * 0.6 / (n * _series.length)).clamp(2.0, 16.0);
  // Platz links/rechts, damit die äußeren Balken nicht an der Achse kleben.
  final margin = (width / n / 2).clamp(12.0, 40.0);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        height: height,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis.fromStrings(
              [for (final m in r.months) latin1Safe(_monthShort(m) + (m.partial ? '*' : ''))],
              marginStart: margin,
              marginEnd: margin,
              ticks: true,
              textStyle: pw.TextStyle(fontSize: n > 8 ? 6 : 8),
            ),
            yAxis: pw.FixedAxis(
              [for (var v = 0; v <= top; v += step) v],
              divisions: true,
              divisionsColor: PdfColors.grey300,
              textStyle: const pw.TextStyle(fontSize: 8),
            ),
          ),
          datasets: [
            for (var s = 0; s < _series.length; s++)
              pw.BarDataSet(
                color: _series[s].$2,
                width: barWidth,
                offset: (s - (_series.length - 1) / 2) * (barWidth + 1),
                drawSurface: true,
                valuePosition: pw.ValuePosition.top,
                data: [
                  for (var i = 0; i < n; i++)
                    pw.PointChartValue(i.toDouble(), _series[s].$3(r.months[i]).toDouble()),
                ],
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Wrap(spacing: 10, runSpacing: 2, children: [
        for (final s in _series)
          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
            pw.Container(width: 8, height: 8, color: s.$2),
            pw.SizedBox(width: 3),
            pw.Text(latin1Safe(s.$1), style: const pw.TextStyle(fontSize: 8)),
          ]),
        if (r.months.any((m) => m.partial))
          pw.Text('* Monat nicht vollständig im Zeitraum',
              style: const pw.TextStyle(fontSize: 8, color: _dim)),
      ]),
    ],
  );
}

/// Abschnitt 1, je Eintrag ein Stichpunkt.
List<String> overview(Report r) {
  final out = <String>[];
  final full = r.fullMonths;
  final last = r.months.last;
  if (full.isNotEmpty) {
    out.add('Migränetage pro Monat: ${spanText([for (final m in full) m.migraineDays])} '
        '(ganze Monate), aktuell ${last.migraineDays} '
        '(${monthName(last.month)}${last.partial ? ' bis ${last.lastDay}.' : ''})');
  } else {
    out.add('Migränetage im Zeitraum: ${last.migraineDays}');
  }

  final n = r.attacks.length;
  if (n == 0) {
    out.add('Keine Attacken im Zeitraum');
    return out;
  }
  final lengths = [for (final a in r.attacks) a.length];
  final strong = r.attacks.where((a) => a.maxPain == 3).length;
  out.add('Attacken gesamt: $n, Dauer typisch ${formatDecimal(median(lengths))} '
      '${median(lengths) == 1 ? 'Tag' : 'Tage'} (Median, Spanne ${spanText(lengths)}); '
      'Schmerz stark (3) bei $strong von $n');

  final aura = r.attacks.where((a) => a.aura).length;
  var auraLine = 'Aura bei $aura von $n Attacken (${percent(aura, n)})';
  if (r.hasPeriodData) {
    final peri = r.perimenstrualAttacks.length;
    auraLine += '; perimenstruell $peri von $n (${percent(peri, n)})';
  } else {
    auraLine += '; Periode nicht erfasst';
  }
  out.add(auraLine);

  // Trend: erste gegen letzte ganze Monate, nur beschrieben.
  if (full.length >= 2) {
    final k = full.length >= 4 ? 2 : 1;
    final a = full.take(k).toList(), b = full.skip(full.length - k).toList();
    String label(List<ReportMonth> ms) =>
        ms.length == 1 ? _monthShort(ms.first) : '${_monthShort(ms.first)}-${_monthShort(ms.last)}';
    out.add('Verlauf: Ø ${formatDecimal(average([for (final m in a) m.migraineDays]))} '
        'Migränetage/Monat (${label(a)}), zuletzt Ø '
        '${formatDecimal(average([for (final m in b) m.migraineDays]))} (${label(b)})');
  }
  return out;
}

/// [compact]: schmal neben dem Diagramm, mit zweizeiligen Spaltenköpfen.
pw.Widget _table(Report r, {bool compact = false}) {
  pw.Widget cell(String text, {bool bold = false, bool left = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: pw.Text(latin1Safe(text),
            textAlign: left ? pw.TextAlign.left : pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null)),
      );
  final headers = compact
      ? ['Monat', 'Migräne-\ntage', 'Atta-\ncken', 'Schmerz\nstark', 'Aura-\nTage', 'Übel-\nkeit']
      : ['Monat', 'Migränetage', 'Attacken', 'Tage Schmerz stark', 'Aura-Tage', 'Übelkeit-Tage'];
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
    columnWidths: {0: const pw.FlexColumnWidth(2.2)},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          for (var i = 0; i < headers.length; i++) cell(headers[i], bold: true, left: i == 0),
        ],
      ),
      for (final m in r.months)
        pw.TableRow(children: [
          cell(compact ? _monthCompact(m) : _monthLabel(m), left: true),
          cell('${m.migraineDays}'),
          cell('${m.attacks}'),
          cell('${m.strongPainDays}'),
          cell('${m.auraDays}'),
          cell('${m.nauseaDays}'),
        ]),
    ],
  );
}

/// Gruppen im PDF: links die ärztlich gezielt einzuordnenden, rechts der Rest.
const _leftGroups = [DescriptionGroup.vision, DescriptionGroup.speech, DescriptionGroup.motor];
const _rightGroups = [
  DescriptionGroup.sensory,
  DescriptionGroup.cognition,
  DescriptionGroup.prodrome,
  DescriptionGroup.other,
];

List<pw.Widget> _symptoms(
  Report r,
  pw.Widget Function(String, {bool strong}) bullet,
  pw.Widget Function(String) para,
) {
  final out = <pw.Widget>[];
  if (r.auraSymptomDays.isNotEmpty) {
    out.add(para('Im Tagebuch erfasst: ${[
      for (final e in r.auraSymptomDays.entries) '${e.key} an ${e.value} Tagen',
    ].join(', ')}.'));
  }
  if (r.description.isEmpty) {
    out.add(para('Beschreibung der Patientin: nicht erfasst.'));
    return out;
  }
  out.add(para('Beschreibung der Patientin (sinngemäß gruppiert):'));

  List<pw.Widget> column(List<DescriptionGroup> groups) => [
        for (final g in groups)
          if (r.description[g] case final points?) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(latin1Safe(g.title),
                  style: pw.TextStyle(
                      fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _dim)),
            ),
            for (final p in points) bullet(p, strong: g.highlight),
          ],
      ];
  final left = column(_leftGroups), right = column(_rightGroups);
  // Eine Spalte, wenn eine Seite leer bliebe.
  if (left.isEmpty || right.isEmpty) return out..addAll([...left, ...right]);
  out.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: left)),
    pw.SizedBox(width: 12),
    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: right)),
  ]));
  return out;
}

/// Abschnitt 4 als kurze Sätze mit Daten als Beleg.
List<String> cycleText(Report r) {
  final starts = r.periodStarts;
  if (starts == null) return ['Periode nicht erfasst.'];
  final out = <String>[];
  var line = starts.isEmpty
      ? 'Kein Periodenbeginn im Zeitraum erfasst.'
      : _end('Periodenbeginne: ${_dates(starts)}');
  if (r.cycleLengths.isNotEmpty) {
    line += ' Zykluslänge ${spanText(r.cycleLengths)} Tage '
        '(Median ${formatDecimal(median(r.cycleLengths))}).';
  }
  out.add(line);
  if (r.attacks.isEmpty) return out;

  final peri = r.perimenstrualAttacks;
  out.add(_end('${peri.length} von ${r.attacks.length} Attacken begannen perimenstruell '
      '(Tag -2 bis +3 um den Periodenbeginn)'
      '${peri.isEmpty ? '' : ': ${_dates([for (final a in peri) a.start])}'}'));

  final others = [for (final a in r.attacks) if (!a.perimenstrual) a];
  final p = r.pattern;
  if (p != null) {
    final range = p.fromDay == p.toDay ? '${p.fromDay}' : '${p.fromDay}-${p.toDay}';
    out.add('Wiederkehrend: ${p.attacks.length} Attacken außerhalb der Periode begannen an '
        'Zyklustag $range (${[
      for (final a in p.attacks) '${_date(a.start, year: false)} = Tag ${a.cycleDay}',
    ].join(', ')}).');
  } else if (others.isNotEmpty && others.length <= 6) {
    out.add('Übrige Attacken: ${[
      for (final a in others)
        '${_date(a.start, year: false)} (${a.cycleDay == null ? 'Zyklustag unbekannt' : 'Zyklustag ${a.cycleDay}'})',
    ].join(', ')}.');
  }
  return out;
}

/// Abschnitt 5, je Substanz ein Stichpunkt plus neutrale Hinweise auf häufige Einnahme.
List<String> medicationText(Report r) {
  if (r.medications.isEmpty) return ['Nicht erfasst - bitte im Gespräch ergänzen.'];
  final out = <String>[];
  for (final m in r.medications) {
    final perMonth = [
      for (var i = 0; i < r.months.length; i++)
        if (m.daysPerMonth[i] != null) '${_monthShort(r.months[i])} ${m.daysPerMonth[i]}',
    ];
    final kind = m.unnamed ? '' : (m.triptan ? ' (Triptan)' : '');
    var line = '${m.name}$kind: ${m.totalDays} Einnahmetage (${perMonth.join(', ')}); '
        '${m.helpedDays == 0 ? 'Wirkung nicht erfasst' : 'hat geholfen an ${m.helpedDays} '
            'von ${m.totalDays} Tagen'}';
    final over = [
      for (var i = 0; i < r.months.length; i++)
        if ((m.daysPerMonth[i] ?? 0) >= m.limit) _monthShort(r.months[i]),
    ];
    if (over.isNotEmpty) {
      line += '. Hinweis: an ${m.limit} oder mehr Tagen im Monat genommen (${over.join(', ')})';
    }
    out.add(line);
  }
  return out;
}
