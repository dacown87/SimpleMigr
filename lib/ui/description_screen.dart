import 'package:flutter/material.dart';

import '../data/repository.dart';
import 'autosave_field.dart';
import 'util.dart';

/// Allgemeine Beschreibung der eigenen Migräne. Steht auch im PDF-Export.
class DescriptionScreen extends StatelessWidget {
  const DescriptionScreen({super.key, required this.repo});

  final Repository repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Migräne')),
      body: StreamBuilder<String>(
        stream: repo.watchDescription(),
        builder: (context, snap) {
          final text = snap.data;
          if (text == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Wie läuft eine Attacke bei dir typischerweise ab? Das hilft beim Arztgespräch '
                'und steht im PDF-Export auf der ersten Seite.',
              ),
              const SizedBox(height: 16),
              AutoSaveField(
                key: const ValueKey('description-field'),
                text: text,
                label: 'Beschreibung',
                hint:
                    'z. B. Vorboten, wo und wie der Schmerz sitzt, Dauer, '
                    'Begleitsymptome, was hilft, Medikamente',
                minLines: 10,
                maxLines: null,
                onChanged: (t) => guarded(context, () => repo.setDescription(t)),
              ),
            ],
          );
        },
      ),
    );
  }
}
