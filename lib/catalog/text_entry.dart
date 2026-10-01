import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'text_entry.genui.dart';

/// A short line of text the person types.
@GenUiWidget(
  description:
      'A one-line text input, such as a note or a merchant name. Bind `value` '
      'to a data path and the field writes what is typed there.',
)
class TextEntry extends StatefulWidget {
  const TextEntry({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    @GenUiWrites('value') this.onChanged,
    @GenUiChecked() this.error,
  });

  /// The caption above the field.
  final String label;

  /// What the field holds.
  final String value;

  /// Greyed text shown while the field is empty, such as "Opcional".
  final String? hint;

  /// Called with the new text as the person types.
  final ValueChanged<String>? onChanged;

  /// The message of the first failing check, or null while all pass.
  final String? error;

  @override
  State<TextEntry> createState() => _TextEntryState();
}

class _TextEntryState extends State<TextEntry> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(TextEntry old) {
    super.didUpdateWidget(old);
    if (widget.value != _text.text) _text.text = widget.value;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _text,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          errorText: widget.error,
        ),
      ),
    );
  }
}
