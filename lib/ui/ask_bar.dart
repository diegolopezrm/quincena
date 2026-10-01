import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'icons.dart';

/// Where the person types a question.
class AskBar extends StatefulWidget {
  const AskBar({super.key, required this.onAsk, required this.enabled});

  final ValueChanged<String> onAsk;
  final bool enabled;

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: context.type.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Pregúntale algo a tu plata',
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
          tooltip: 'Preguntar',
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
