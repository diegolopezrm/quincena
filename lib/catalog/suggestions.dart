import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../theme/tokens.dart';
import '../ui/icons.dart';

part 'suggestions.genui.dart';

/// What to ask next.
@GenUiWidget(
  description:
      'Two or three follow-up questions the person might ask next, as chips. '
      'End most answers with one. Each child is a Suggestion.',
)
class Suggestions extends StatelessWidget {
  const Suggestions({super.key, required this.children});

  /// The Suggestion chips.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );
}

/// One follow-up question.
@GenUiWidget(
  description:
      'One follow-up question, as a chip inside Suggestions. Its action should '
      'be an event named "ask" whose context carries the question text, so '
      'pressing it asks you that question.',
)
class Suggestion extends StatelessWidget {
  const Suggestion({
    super.key,
    required this.label,
    @GenUiAction(eventName: 'ask') this.onPressed,
  });

  /// The question, in the person's words, such as "¿Cómo voy contra agosto?".
  final String label;

  /// Asks the question.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: StadiumBorder(side: BorderSide(color: context.colors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Glyph.chatCircleDots, size: 18, color: context.colors.brand),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: context.type.labelLarge?.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
