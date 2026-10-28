import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../update/updater.dart';

/// Datum des Release-Commits, vom Release-Workflow per `--dart-define` gesetzt
/// (`YYYY-MM-DD`). Lokale Builds haben keins.
const buildDate = String.fromEnvironment('BUILD_DATE');

/// Lädt das Update und öffnet den Installer; Fortschritt und Fehler als SnackBar.
Future<void> installUpdate(ScaffoldMessengerState messenger, Updater updater, UpdateInfo info) async {
  messenger
    ..hideCurrentMaterialBanner()
    ..showSnackBar(const SnackBar(content: Text('Update wird geladen …')));
  try {
    await updater.install(info);
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Update fehlgeschlagen')));
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
    if (ok == true) await installUpdate(messenger, updater, info);
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
