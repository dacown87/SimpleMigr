import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/repository.dart';
import 'theme.dart';
import 'util.dart';

/// Eingabe für einen Tag. Gleiche Komponente für „Heute“ und das Monatsraster.
/// Kein Speichern-Button: jeder Tap schreibt sofort.
class DayEditor extends StatefulWidget {
  const DayEditor({super.key, required this.repo, required this.date});

  final Repository repo;
  final DateTime date;

  @override
  State<DayEditor> createState() => _DayEditorState();
}

class _DayEditorState extends State<DayEditor> {
  late Stream<List<Symptom>> _symptoms;
  late Stream<DayData> _day;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(DayEditor old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date || old.repo != widget.repo) _subscribe();
  }

  void _subscribe() {
    _symptoms = widget.repo.watchSymptoms(includeArchived: true);
    _day = widget.repo.watchDay(widget.date);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Symptom>>(
      stream: _symptoms,
      builder: (context, sy) => StreamBuilder<DayData>(
        stream: _day,
        builder: (context, dy) {
          if (!sy.hasData || !dy.hasData) return const SizedBox.shrink();
          return _content(context, sy.data!, dy.data!);
        },
      ),
    );
  }

  Widget _content(BuildContext context, List<Symptom> all, DayData day) {
    // Archivierte nur, wenn sie an diesem Tag einen Wert haben.
    final list = [
      for (final s in all)
        if (!s.archived || day.value(s.id) != 0) s,
    ];
    Symptom byKey(String k) => all.firstWhere((s) => s.key == k);
    final migraine = byKey(SymptomKey.migraine);
    final pain = byKey(SymptomKey.pain);
    final aura = byKey(SymptomKey.aura);
    final period = byKey(SymptomKey.period);
    final nausea = byKey(SymptomKey.nausea);
    final auraSymptoms =
        list.where((s) => s.grp == SymptomGroup.aura).toList();
    final custom = list
        .where((s) => s.grp == SymptomGroup.general && s.key == null)
        .toList();
    final triggers = list.where((s) => s.grp == SymptomGroup.trigger).toList();

    final migraineOn = day.value(migraine.id) != 0;
    final auraOn = day.value(aura.id) != 0;
    final repo = widget.repo;
    final date = widget.date;

    void setFlag(Symptom s, bool on) =>
        guarded(context, () => repo.setValue(date, s.id, on ? 1 : 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _BigToggle(
          label: 'MIGRÄNE',
          on: migraineOn,
          onTap: () => setFlag(migraine, !migraineOn),
        ),
        const SizedBox(height: 16),
        Text('Schmerzen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var v = 0; v <= 3; v++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: v == 0 ? 0 : 8),
                  child: _PainBox(
                    value: v,
                    selected: day.value(pain.id) == v,
                    onTap: () => guarded(
                      context,
                      // Erneutes Tippen auf das gewählte Feld setzt zurück.
                      () => repo.setValue(
                          date, pain.id, day.value(pain.id) == v ? 0 : v),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (migraineOn)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Neue Attacke (/)'),
            subtitle: const Text('Hier endet eine Attacke, eine neue beginnt'),
            value: day.newAttack,
            onChanged: (v) => guarded(context, () => repo.setNewAttack(date, v)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(aura.name),
          value: auraOn,
          onChanged: (v) => setFlag(aura, v),
        ),
        if (auraOn)
          _ChipWrap(
            symptoms: auraSymptoms,
            day: day,
            onToggle: (s, on) => setFlag(s, on),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Mehr'),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(period.name),
                value: day.value(period.id) != 0,
                onChanged: (v) => setFlag(period, v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(nausea.name),
                value: day.value(nausea.id) != 0,
                onChanged: (v) => setFlag(nausea, v),
              ),
              for (final s in custom)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name),
                  value: day.value(s.id) != 0,
                  onChanged: (v) => setFlag(s, v),
                ),
              if (triggers.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Auslöser'),
                  ),
                ),
                _ChipWrap(
                  symptoms: triggers,
                  day: day,
                  onToggle: (s, on) => setFlag(s, on),
                ),
              ],
              const SizedBox(height: 12),
              _NoteField(
                key: ValueKey(date),
                text: day.note,
                onChanged: (t) => guarded(context, () => repo.setNote(date, t)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigToggle extends StatelessWidget {
  const _BigToggle({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: Material(
        color: on ? AppColors.migraine : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            height: 110,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: on ? AppColors.onMigraine : AppColors.textDim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PainBox extends StatelessWidget {
  const _PainBox({required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 84,
          child: Center(
            child: Text(
              '$value',
              key: ValueKey('pain-$value'),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: selected ? const Color(0xFF0B1320) : AppColors.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.symptoms, required this.day, required this.onToggle});

  final List<Symptom> symptoms;
  final DayData day;
  final void Function(Symptom, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in symptoms)
            FilterChip(
              label: Text(s.name, style: const TextStyle(fontSize: 18)),
              selected: day.value(s.id) != 0,
              onSelected: (on) => onToggle(s, on),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
        ],
      ),
    );
  }
}

/// Textfeld, das beim Tippen speichert, aber fremde Updates nur übernimmt,
/// solange es nicht den Fokus hat.
class _NoteField extends StatefulWidget {
  const _NoteField({super.key, required this.text, required this.onChanged});

  final String text;
  final ValueChanged<String> onChanged;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_NoteField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      minLines: 2,
      maxLines: 5,
      style: const TextStyle(fontSize: 18),
      decoration: const InputDecoration(
        labelText: 'Notiz',
        border: OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
