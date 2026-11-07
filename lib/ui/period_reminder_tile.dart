import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../period_reminder.dart';
import 'util.dart';

/// Schalter und Zykluslänge für die Periodenerinnerung.
class PeriodReminderTile extends StatefulWidget {
  const PeriodReminderTile({super.key, required this.reminder});

  final PeriodReminder reminder;

  @override
  State<PeriodReminderTile> createState() => _PeriodReminderTileState();
}

class _PeriodReminderTileState extends State<PeriodReminderTile> {
  PeriodReminder get r => widget.reminder;
  late Future<DateTime?> _next;

  @override
  void initState() {
    super.initState();
    _next = r.nextStart();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _next = r.nextStart();
    });
  }

  Future<void> _toggle(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final ok = await r.enable();
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Ohne Benachrichtigungs-Erlaubnis gibt es keine Periodenerinnerung. '
              'Bitte in den Android-Einstellungen erlauben.',
            ),
          ),
        );
      }
    } else {
      await r.disable();
    }
    _refresh();
  }

  Future<void> _pickLength() async {
    final controller = TextEditingController(text: '${r.cycleLength}');
    int? parse() {
      final n = int.tryParse(controller.text.trim());
      return n != null && n >= minCycleLength && n <= maxCycleLength ? n : null;
    }

    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zykluslänge'),
        content: TextField(
          key: const ValueKey('cycle-length-field'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            suffixText: 'Tage',
            helperText:
                'Vom ersten Tag einer Periode bis zum ersten Tag der nächsten '
                '($minCycleLength–$maxCycleLength)',
            helperMaxLines: 3,
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(parse()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            key: const ValueKey('cycle-length-ok'),
            onPressed: () => Navigator.of(ctx).pop(parse()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (days != null) {
      await r.setCycleLength(days);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('period-reminder-switch'),
          title: const Text('Periodenerinnerung'),
          subtitle: FutureBuilder<DateTime?>(
            future: _next,
            builder: (context, snap) {
              final next = snap.data;
              if (snap.connectionState != ConnectionState.done) {
                return const Text(
                  '$periodReminderLeadDays Tage vorher um $periodReminderHour Uhr',
                );
              }
              return Text(
                next == null
                    ? 'Trag deine Periode im Tagebuch ein, dann kann die App sie vorhersagen.'
                    : '$periodReminderLeadDays Tage vorher um $periodReminderHour Uhr. '
                          'Nächste erwartet: ${germanDate(next)}',
              );
            },
          ),
          value: r.enabled,
          onChanged: _toggle,
        ),
        ListTile(
          key: const ValueKey('cycle-length'),
          enabled: r.enabled,
          title: const Text('Zykluslänge'),
          trailing: Text('${r.cycleLength} Tage'),
          onTap: r.enabled ? _pickLength : null,
        ),
      ],
    );
  }
}
