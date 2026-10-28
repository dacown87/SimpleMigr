import 'package:flutter/material.dart';

import '../data/repository.dart';
import 'theme.dart';
import 'util.dart';

/// Allgemeine Beschreibung der eigenen Migräne als Liste einzelner Punkte.
/// Steht auch im PDF-Export.
class DescriptionScreen extends StatelessWidget {
  const DescriptionScreen({super.key, required this.repo});

  final Repository repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Migräne')),
      body: StreamBuilder<List<String>>(
        stream: repo.watchDescriptionPoints(),
        builder: (context, snap) {
          final points = snap.data;
          if (points == null) return const SizedBox.shrink();
          return _PointList(points: points, repo: repo);
        },
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({required this.points, required this.repo});

  final List<String> points;
  final Repository repo;

  Future<void> _save(BuildContext context, List<String> next) =>
      guarded(context, () => repo.setDescriptionPoints(next));

  Future<void> _edit(BuildContext context, int i) async {
    final controller = TextEditingController(text: points[i]);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Punkt bearbeiten'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            key: const ValueKey('delete-point-in-dialog'),
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Löschen'),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (text == null || !context.mounted) return;
    // „Löschen“ oder leer gespeichert = Punkt entfernen.
    if (text.trim().isEmpty) return _remove(context, i);
    await _save(context, [...points]..[i] = text);
  }

  Future<void> _remove(BuildContext context, int i) async {
    final before = points;
    await _save(context, [...points]..removeAt(i));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Punkt gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () => repo.setDescriptionPoints(before),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            header: const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Wie läuft eine Attacke bei dir typischerweise ab? Ein Punkt pro Beobachtung, '
                'z. B. Vorboten, wo der Schmerz sitzt, Dauer, was hilft. '
                'Antippen bearbeitet, Papierkorb oder Wischen löscht, am Griff verschieben. '
                'Die Punkte stehen im PDF-Export auf der ersten Seite.',
                style: TextStyle(color: AppColors.textDim),
              ),
            ),
            itemCount: points.length,
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              final next = [...points];
              next.insert(to, next.removeAt(from));
              _save(context, next);
            },
            itemBuilder: (context, i) => Dismissible(
              // Text im Schlüssel: nach Löschen/Verschieben passt die Zuordnung.
              key: ValueKey('point-$i-${points[i]}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppColors.period,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (_) => _remove(context, i),
              child: ListTile(
                leading: const Icon(Icons.circle, size: 10, color: AppColors.accent),
                minLeadingWidth: 12,
                title: Text(points[i], style: const TextStyle(fontSize: 18)),
                onTap: () => _edit(context, i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('delete-point-$i'),
                      tooltip: 'Löschen',
                      icon: const Icon(Icons.delete_outline, color: AppColors.textDim),
                      onPressed: () => _remove(context, i),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle, color: AppColors.textDim),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _NewPointField(onAdd: (text) => _save(context, [...points, text])),
      ],
    );
  }
}

/// Eingabe für einen neuen Punkt. Bleibt nach dem Hinzufügen offen für den nächsten.
class _NewPointField extends StatefulWidget {
  const _NewPointField({required this.onAdd});

  final ValueChanged<String> onAdd;

  @override
  State<_NewPointField> createState() => _NewPointFieldState();
}

class _NewPointFieldState extends State<_NewPointField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('new-point'),
                controller: _controller,
                focusNode: _focus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Neuer Punkt',
                  border: OutlineInputBorder(),
                ),
                // Statt onSubmitted: Tastatur bleibt offen für den nächsten Punkt.
                onEditingComplete: _add,
              ),
            ),
            IconButton(
              key: const ValueKey('add-point'),
              tooltip: 'Punkt hinzufügen',
              iconSize: 32,
              icon: const Icon(Icons.add_circle, color: AppColors.accent),
              onPressed: _add,
            ),
          ],
        ),
      ),
    );
  }
}
