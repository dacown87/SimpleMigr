import 'package:flutter/material.dart';

import '../celebration.dart';
import '../data/repository.dart';
import 'celebration_screen.dart';

/// Schalter für die Monatsfeier und Vorschau mit den Zahlen des laufenden Monats.
class CelebrationTile extends StatefulWidget {
  const CelebrationTile({
    super.key,
    required this.celebration,
    required this.repo,
    this.clock = DateTime.now,
  });

  final Celebration celebration;
  final Repository repo;
  final DateTime Function() clock;

  @override
  State<CelebrationTile> createState() => _CelebrationTileState();
}

class _CelebrationTileState extends State<CelebrationTile> {
  Celebration get c => widget.celebration;

  Future<void> _toggle(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final ok = await c.enable();
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Ohne Benachrichtigungs-Erlaubnis gibt es keine Monatsfeier. '
              'Bitte in den Android-Einstellungen erlauben.'),
        ));
      }
    } else {
      await c.disable();
    }
    if (mounted) setState(() {});
  }

  void _preview() {
    final now = widget.clock();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CelebrationScreen(
        repo: widget.repo,
        year: now.year,
        month: now.month,
        clock: widget.clock,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('celebration-switch'),
          title: const Text('Monatsfeier'),
          subtitle: const Text('Am Monatsende um 20 Uhr'),
          value: c.enabled,
          onChanged: _toggle,
        ),
        ListTile(
          key: const ValueKey('celebration-preview'),
          title: const Text('Vorschau'),
          trailing: const Icon(Icons.celebration),
          onTap: _preview,
        ),
      ],
    );
  }
}
