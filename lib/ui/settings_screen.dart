import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/repository.dart';
import 'util.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repo, this.extraTiles = const []});

  final Repository repo;

  /// Zusätzliche Einträge oben (Erinnerung, Export).
  final List<Widget> extraTiles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: StreamBuilder<List<Symptom>>(
        stream: repo.watchSymptoms(includeArchived: true),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const SizedBox.shrink();
          return ListView(
            children: [
              ...extraTiles,
              _section(context, 'Symptome', SymptomGroup.general, all),
              _section(context, 'Aura', SymptomGroup.aura, all),
              _section(context, 'Auslöser', SymptomGroup.trigger, all),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title, SymptomGroup grp, List<Symptom> all) {
    final items = all.where((s) => s.grp == grp).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                key: ValueKey('add-${grp.name}'),
                tooltip: '$title hinzufügen',
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final name = await _askName(context, 'Neu: $title');
                  if (name != null && context.mounted) {
                    await guarded(context, () => repo.addSymptom(name, grp));
                  }
                },
              ),
            ],
          ),
        ),
        for (final s in items)
          ListTile(
            key: ValueKey('symptom-${s.id}'),
            title: Text(s.name,
                style: s.archived
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null),
            onTap: () async {
              final name = await _askName(context, 'Umbenennen', initial: s.name);
              if (name != null && context.mounted) {
                await guarded(context, () => repo.renameSymptom(s.id, name));
              }
            },
            trailing: s.key != null
                ? null // Systemsymptome: nur umbenennen
                : IconButton(
                    tooltip: s.archived ? 'Wiederherstellen' : 'Archivieren',
                    icon: Icon(s.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                    onPressed: () =>
                        guarded(context, () => repo.setArchived(s.id, !s.archived)),
                  ),
          ),
      ],
    );
  }

  Future<String?> _askName(BuildContext context, String title, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((v) => (v == null || v.trim().isEmpty) ? null : v);
  }
}
