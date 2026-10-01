import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'tone.dart';
import '../ui/icons.dart';

part 'insight.genui.dart';

/// One thing worth knowing, said plainly.
@GenUiWidget(
  description:
      'One finding about the money, said plainly, with an optional action. '
      'Use one per finding, two or three per answer at most, and lead with '
      'the one that matters most. The title names the finding with its '
      'number; the body says why it happened.',
)
class Insight extends StatelessWidget {
  const Insight({
    super.key,
    required this.tone,
    required this.title,
    required this.body,
    this.actionLabel,
    @GenUiAction(eventName: 'insight_action') this.onAction,
  });

  /// `good` for good news, `caution` for something worth a look, `alert` for
  /// something that needs changing, `neutral` for a plain fact.
  final Tone tone;

  /// The finding with its number, such as "Restaurantes subió 67 %".
  final String title;

  /// Why it happened, in one or two sentences.
  final String body;

  /// The text of the action link, such as "Ver esos pagos". Leave it out
  /// when there is nothing to do.
  final String? actionLabel;

  /// What happens when the action link is pressed.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final Color accent = tone.color(context);
    return MergeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
        decoration: BoxDecoration(
          color: tone.soft(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(tone.icon, size: 22, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: context.type.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: context.type.bodyMedium?.copyWith(
                      color: context.colors.inkSoft,
                    ),
                  ),
                  if (actionLabel case final String label
                      when onAction != null) ...<Widget>[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onAction,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                label,
                                style: context.type.labelLarge?.copyWith(
                                  color: tone == Tone.neutral
                                      ? context.colors.brand
                                      : accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Glyph.arrowRight,
                              size: 16,
                              color: tone == Tone.neutral
                                  ? context.colors.brand
                                  : accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
