import 'package:flutter/material.dart';

/// Textfeld, das beim Tippen speichert, aber fremde Updates nur übernimmt,
/// solange es nicht den Fokus hat.
class AutoSaveField extends StatefulWidget {
  const AutoSaveField({
    super.key,
    required this.text,
    required this.onChanged,
    required this.label,
    this.hint,
    this.minLines = 2,
    this.maxLines = 5,
  });

  final String text;
  final ValueChanged<String> onChanged;
  final String label;
  final String? hint;
  final int minLines;
  final int? maxLines;

  @override
  State<AutoSaveField> createState() => _AutoSaveFieldState();
}

class _AutoSaveFieldState extends State<AutoSaveField> {
  late final _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(AutoSaveField old) {
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
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
