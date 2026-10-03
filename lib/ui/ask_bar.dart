import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'icons.dart';

/// Where the person types a question.
///
/// While it is empty and untouched, its hint turns, every few seconds, to
/// one of [examples]: questions this account can answer, which teach what
/// to ask without a tour.
class AskBar extends StatefulWidget {
  const AskBar({
    super.key,
    required this.onAsk,
    required this.enabled,
    this.examples = const <String>[],
  });

  final ValueChanged<String> onAsk;
  final bool enabled;
  final List<String> examples;

  /// How long each hint stays.
  static const Duration turn = Duration(seconds: 7);

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _turning;

  /// Which hint shows: the plain one first, then each example in turn.
  int _hint = 0;

  @override
  void initState() {
    super.initState();
    _turning = Timer.periodic(AskBar.turn, (_) {
      if (widget.examples.isEmpty || _focus.hasFocus || _text.text.isNotEmpty) {
        return;
      }
      setState(() => _hint = (_hint + 1) % (widget.examples.length + 1));
    });
  }

  @override
  void dispose() {
    _turning?.cancel();
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  String _hintText(BuildContext context) {
    final List<String> examples = widget.examples;
    if (_hint == 0 || examples.isEmpty) return context.l10n.askHint;
    return context.l10n.askExample(examples[(_hint - 1) % examples.length]);
  }

  void _send() {
    final String value = _text.text.trim();
    if (value.isEmpty || !widget.enabled) return;
    widget.onAsk(value);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _text,
            focusNode: _focus,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: context.type.bodyLarge,
            decoration: InputDecoration(
              hintText: _hintText(context),
              hintMaxLines: 1,
              filled: true,
              fillColor: context.colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(99),
                borderSide: BorderSide(color: context.colors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(99),
                borderSide: BorderSide(color: context.colors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(99),
                borderSide: BorderSide(color: context.colors.brand, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: widget.enabled ? _send : null,
          tooltip: context.l10n.ask,
          style: IconButton.styleFrom(
            backgroundColor: context.colors.brand,
            foregroundColor: context.colors.onBrand,
            fixedSize: const Size(52, 52),
          ),
          icon: const Icon(Glyph.paperPlaneRight, size: 22),
        ),
      ],
    );
  }
}
