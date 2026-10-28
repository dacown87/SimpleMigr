import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/dates.dart';
import '../data/transfer.dart';

/// Liest eine vom Nutzer gewählte Datei; `null` bei Abbruch.
typedef PickBytes = Future<List<int>?> Function();

/// Speichert Bytes an einem vom Nutzer gewählten Ort; `false` bei Abbruch.
typedef SaveBytes = Future<bool> Function(String fileName, List<int> bytes, String mimeType);

Future<List<int>?> _pickWithSystem() async {
  final f = await FilePicker.pickFile();
  return f?.xFile.readAsBytes();
}

Future<bool> _saveWithSystem(String fileName, List<int> bytes, String mimeType) async =>
    await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: mimeType,
    ) !=
    null;

/// Sicherung (JSON), Tabelle (CSV) und Import für den Tab „Daten“.
class DataTiles extends StatelessWidget {
  const DataTiles({
    super.key,
    required this.transfer,
    this.afterImport,
    this.pick = _pickWithSystem,
    this.save = _saveWithSystem,
    this.clock = DateTime.now,
  });

  final DataTransfer transfer;

  /// Nach erfolgreichem Import (z. B. Wetter nachladen). Liefert einen Zusatz
  /// für die Erfolgsmeldung.
  final String Function()? afterImport;

  final PickBytes pick;
  final SaveBytes save;
  final DateTime Function() clock;

  void _show(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export(BuildContext context, {required bool backup}) async {
    try {
      final stamp = toKey(clock());
      final ok = backup
          ? await save(
              'simplemigr_sicherung_$stamp.json',
              utf8.encode(await transfer.exportBackup(now: clock())),
              'application/json',
            )
          : await save(
              'simplemigr_tabelle_$stamp.csv',
              utf8.encode(await transfer.exportCsv()),
              'text/csv',
            );
      if (ok && context.mounted) _show(context, 'Gespeichert');
    } catch (_) {
      if (context.mounted) _show(context, 'Speichern fehlgeschlagen');
    }
  }

  Future<void> _import(BuildContext context) async {
    final ImportData data;
    try {
      final bytes = await pick();
      if (bytes == null) return;
      data = await transfer.read(bytes);
    } on ImportFormatException catch (e) {
      if (context.mounted) _show(context, e.message);
      return;
    } catch (_) {
      if (context.mounted) _show(context, 'Datei konnte nicht gelesen werden');
      return;
    }
    if (!context.mounted) return;
    if (data.days.isEmpty) {
      _show(context, 'Keine Tage in der Datei gefunden');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ImportPreview(data: data),
    );
    if (ok != true || !context.mounted) return;
    try {
      final n = await transfer.apply(data);
      final extra = afterImport?.call();
      if (context.mounted) {
        _show(context, '$n Tage importiert.${extra == null ? '' : ' $extra'}');
      }
    } catch (_) {
      if (context.mounted) _show(context, 'Import fehlgeschlagen, nichts geändert');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          key: const ValueKey('import'),
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Daten importieren'),
          subtitle: const Text('Sicherung (.json) oder eigene Tabelle (.csv)'),
          onTap: () => _import(context),
        ),
        ListTile(
          key: const ValueKey('export-backup'),
          leading: const Icon(Icons.save_outlined),
          title: const Text('Sicherung speichern'),
          subtitle: const Text('Alles inklusive Wetter, z. B. für ein neues Handy'),
          onTap: () => _export(context, backup: true),
        ),
        ListTile(
          key: const ValueKey('export-csv'),
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Als Tabelle speichern (CSV)'),
          subtitle: const Text('Für Excel/LibreOffice, auch als Vorlage für den Import'),
          onTap: () => _export(context, backup: false),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(72, 0, 16, 8),
          child: Text(
            'Tabelle: eine Zeile pro Tag, Spalte „Datum“ (z. B. 01.09.2026), dann eine '
            'Spalte je Symptom mit X, Schmerzen als 0–3, „/“ bei Migräne = neue Attacke. '
            'Unbekannte Spalten werden als neue Symptome angelegt, „Aura: …“ und '
            '„Auslöser: …“ landen in der passenden Gruppe.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({required this.data});

  final ImportData data;

  static String _date(String key) {
    final d = fromKey(key);
    return '${d.day}.${d.month}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final (first, last) = data.range!;
    final created = data.newSymptoms.map((s) => s.name).join(', ');
    return AlertDialog(
      title: Text(data.isBackup ? 'Sicherung einspielen?' : 'Tabelle importieren?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${data.days.length} Tage, ${_date(first)} bis ${_date(last)}'),
            if (created.isNotEmpty) ...[const SizedBox(height: 8), Text('Neu angelegt: $created')],
            if (data.ignoredColumns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ignoriert: ${data.ignoredColumns.join(', ')}'),
            ],
            if (data.skippedRows > 0) ...[
              const SizedBox(height: 8),
              Text('${data.skippedRows} Zeilen ohne gültiges Datum werden übersprungen.'),
            ],
            const SizedBox(height: 12),
            const Text(
              'Für diese Tage ersetzen die Werte aus der Datei die bisherigen Einträge. '
              'Andere Tage bleiben unverändert. Wetter wird danach automatisch nachgeladen.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          key: const ValueKey('confirm-import'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Importieren'),
        ),
      ],
    );
  }
}
