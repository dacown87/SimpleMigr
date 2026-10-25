import 'package:flutter/material.dart';

import '../reminder.dart';

/// Schalter und Uhrzeit für die tägliche Erinnerung.
class ReminderTile extends StatefulWidget {
  const ReminderTile({super.key, required this.reminder});

  final Reminder reminder;

  @override
  State<ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<ReminderTile> {
  Reminder get r => widget.reminder;

  Future<void> _toggle(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final ok = await r.enable();
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Ohne Benachrichtigungs-Erlaubnis gibt es keine Erinnerung. '
              'Bitte in den Android-Einstellungen erlauben.'),
        ));
      }
    } else {
      await r.disable();
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: r.time);
    if (t != null) {
      await r.setTime(t);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('reminder-switch'),
          title: const Text('Tägliche Erinnerung'),
          value: r.enabled,
          onChanged: _toggle,
        ),
        ListTile(
          key: const ValueKey('reminder-time'),
          enabled: r.enabled,
          title: const Text('Uhrzeit'),
          trailing: Text(r.time.format(context)),
          onTap: r.enabled ? _pickTime : null,
        ),
      ],
    );
  }
}
