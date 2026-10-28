import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/repository.dart';
import 'theme.dart';
import 'util.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.repo,
    this.generalTiles = const [],
    this.dataTiles = const [],
  });

  final Repository repo;

  /// Tab „Allgemein“ (Erinnerung, Wetter-Ort).
  final List<Widget> generalTiles;

  /// Tab „Daten“ (PDF-Export, Sicherung, Import).
  final List<Widget> dataTiles;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Einstellungen'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Einträge'),
              Tab(text: 'Allgemein'),
              Tab(text: 'Daten'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _entries(context),
            ListView(children: generalTiles),
            ListView(children: dataTiles),
          ],
        ),
      ),
    );
  }

  /// Eine Gruppe auf einmal, umschaltbar über Segmente statt einer langen Liste.
  Widget _entries(BuildContext context) {
    return StreamBuilder<List<Symptom>>(
      stream: repo.watchSymptoms(includeArchived: true),
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const SizedBox.shrink();
        return _EntryGroups(
          labels: const ['Basis', 'Symptome', 'Aura', 'Auslöser', 'Medis'],
          builder: (i) => switch (i) {
            // Fest eingebaute Einträge: nur umbenennen, nichts hinzufügen.
            0 => _section(
                context,
                'Grundeinträge',
                'Fest eingebaut, lassen sich nur umbenennen.',
                SymptomGroup.general,
                all.where(_isBasic).toList(),
                canAdd: false,
              ),
            1 => _section(
                context,
                'Symptome',
                'Erscheinen im Block „Symptome“.',
                SymptomGroup.general,
                all
                    .where((s) => s.grp == SymptomGroup.general && !_isBasic(s))
                    .toList(),
              ),
            2 => _section(
                context,
                'Aura',
                'Erscheinen, wenn Aura eingeschaltet ist.',
                SymptomGroup.aura,
                all.where((s) => s.grp == SymptomGroup.aura).toList(),
              ),
            3 => _section(
                context,
                'Auslöser',
                'Mögliche Auslöser einer Attacke.',
                SymptomGroup.trigger,
                all.where((s) => s.grp == SymptomGroup.trigger).toList(),
              ),
            _ => _section(
                context,
                'Medikamente',
                'Erscheinen im Block „Medikamente“. Namen mit „triptan“ '
                    'zählen in der Arzt-Zusammenfassung als Triptan.',
                SymptomGroup.medication,
                all.where((s) => s.grp == SymptomGroup.medication).toList(),
              ),
          },
        );
      },
    );
  }

  /// Migräne, Schmerzen, Periode, Aura: eigene Felder im Editor, keine „Symptome“.
  static bool _isBasic(Symptom s) =>
      s.grp == SymptomGroup.general &&
      const {
        SymptomKey.migraine,
        SymptomKey.pain,
        SymptomKey.period,
        SymptomKey.aura,
      }.contains(s.key);

  Widget _section(
    BuildContext context,
    String title,
    String hint,
    SymptomGroup grp,
    List<Symptom> items, {
    bool canAdd = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(color: AppColors.textDim),
                ),
              ),
              if (canAdd)
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
        for (final s in items) _tile(context, s),
      ],
    );
  }

  Widget _tile(BuildContext context, Symptom s) {
    final tile = ListTile(
      key: ValueKey('symptom-${s.id}'),
      title: Text(
        s.name,
        style: s.archived ? const TextStyle(color: AppColors.textDim) : null,
      ),
      onTap: () async {
        final r = await _edit(context, s);
        if (r == null || !context.mounted) return;
        if (r.delete) {
          await _delete(context, s);
        } else {
          await guarded(context, () => repo.renameSymptom(s.id, r.name));
        }
      },
      // Haken = wird angezeigt; Systemsymptome sind immer an.
      trailing: Checkbox(
        key: ValueKey('check-${s.id}'),
        value: !s.archived,
        onChanged: s.key != null
            ? null
            : (v) =>
                  guarded(context, () => repo.setArchived(s.id, !(v ?? true))),
      ),
    );
    if (s.key != null) return tile;
    return Dismissible(
      key: ValueKey('dismiss-${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.period,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _delete(context, s);
        return false; // Die Liste aktualisiert sich über den Stream.
      },
      child: tile,
    );
  }

  Future<void> _delete(BuildContext context, Symptom s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${s.name}“ löschen?'),
        content: const Text(
          'Das Symptom und alle bisherigen Einträge dazu werden '
          'endgültig gelöscht. Zum bloßen Ausblenden den Haken entfernen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guarded(context, () => repo.deleteSymptom(s.id));
    }
  }

  Future<String?> _askName(BuildContext context, String title) async {
    final r = await _dialog(context, title, '', canDelete: false);
    return r?.name;
  }

  Future<_NameResult?> _edit(BuildContext context, Symptom s) =>
      _dialog(context, 'Umbenennen', s.name, canDelete: s.key == null);

  Future<_NameResult?> _dialog(
    BuildContext context,
    String title,
    String initial, {
    required bool canDelete,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<_NameResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(ctx).pop(_NameResult(v)),
        ),
        actions: [
          if (canDelete)
            TextButton(
              key: const ValueKey('delete-in-dialog'),
              onPressed: () =>
                  Navigator.of(ctx).pop(const _NameResult('', delete: true)),
              child: const Text('Löschen'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_NameResult(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then(
      (r) => (r == null || (!r.delete && r.name.trim().isEmpty)) ? null : r,
    );
  }
}

class _NameResult {
  const _NameResult(this.name, {this.delete = false});

  final String name;
  final bool delete;
}

/// Segmente oben, darunter der Inhalt des gewählten Segments.
class _EntryGroups extends StatefulWidget {
  const _EntryGroups({required this.labels, required this.builder});

  final List<String> labels;
  final Widget Function(int index) builder;

  @override
  State<_EntryGroups> createState() => _EntryGroupsState();
}

class _EntryGroupsState extends State<_EntryGroups> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < widget.labels.length; i++)
                ButtonSegment(
                  value: i,
                  label: Text(
                    widget.labels[i],
                    key: ValueKey('entries-${widget.labels[i]}'),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
            ],
            selected: {_index},
            onSelectionChanged: (s) => setState(() => _index = s.first),
          ),
        ),
        widget.builder(_index),
        const SizedBox(height: 24),
      ],
    );
  }
}
