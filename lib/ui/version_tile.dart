import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../update/updater.dart';

/// Datum des Release-Commits, vom Release-Workflow per `--dart-define` gesetzt
/// (`YYYY-MM-DD`). Lokale Builds haben keins.
const buildDate = String.fromEnvironment('BUILD_DATE');

/// Lädt das Update und öffnet den Installer. Fehlt die Erlaubnis zum Installieren,
/// wird sie vorher erklärt und eingeholt; Fortschritt als SnackBar, Fehler als Fenster.
Future<void> installUpdate(BuildContext context, Updater updater, UpdateInfo info) async {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentMaterialBanner();
  try {
    if (!await updater.canInstall()) {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('install-permission'),
          title: const Text('Installation erlauben'),
          content: const Text('Damit SimpleMigr das Update installieren kann, braucht es einmalig '
              'die Erlaubnis „Unbekannte Apps installieren“.\n\n'
              'Im nächsten Fenster den Schalter „Zulassen“ einschalten und dann '
              'mit „Zurück“ zur App wechseln. Danach startet das Update.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Weiter')),
          ],
        ),
      );
      if (ok != true) return;
      if (!await updater.requestInstallPermission()) {
        throw const UpdateException('Die Erlaubnis „Unbekannte Apps installieren“ fehlt. '
            'Ohne sie kann Android das Update nicht installieren.');
      }
    }
    final progress = ValueNotifier<double?>(null);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(minutes: 10),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p == null ? 'Update wird geladen …' : 'Update wird geladen … ${(p * 100).round()} %'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: p),
          ],
        ),
      ),
    ));
    try {
      await updater.install(info, onProgress: (p) => progress.value = p);
    } finally {
      messenger.hideCurrentSnackBar();
    }
  } catch (e) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('update-error'),
        title: const Text('Update fehlgeschlagen'),
        content: SelectableText('$e'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }
}

/// Installierte Version mit Datum und Knopf „Nach Updates suchen“.
class VersionTile extends StatefulWidget {
  const VersionTile({super.key, this.updater, this.date = buildDate});

  /// `null` blendet den Knopf aus.
  final Updater? updater;
  final String date;

  static String formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? 'Testversion' : 'vom ${d.day}.${d.month}.${d.year}';
  }

  @override
  State<VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<VersionTile> {
  final _info = PackageInfo.fromPlatform();
  bool _checking = false;

  Future<void> _check(Updater updater) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checking = true);
    final info = await updater.check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Keine neuere Version gefunden')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Version ${info.version} verfügbar'),
        content: const Text('Jetzt herunterladen und installieren?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Später')),
          TextButton(
            key: const ValueKey('install-update'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Installieren'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await installUpdate(context, updater, info);
  }

  @override
  Widget build(BuildContext context) {
    final updater = widget.updater;
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snap) {
        final info = snap.data;
        return ListTile(
          key: const ValueKey('version'),
          leading: const Icon(Icons.info_outline),
          title: Text(info == null ? 'Version' : 'Version ${info.version} (${info.buildNumber})'),
          subtitle: Text(VersionTile.formatDate(widget.date)),
          trailing: updater == null
              ? null
              : _checking
                  ? const SizedBox.square(
                      dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      key: const ValueKey('check-update'),
                      onPressed: () => _check(updater),
                      child: const Text('Nach Updates\nsuchen', textAlign: TextAlign.center),
                    ),
        );
      },
    );
  }
}
