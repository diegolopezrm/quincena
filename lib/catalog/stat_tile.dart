import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'tone.dart';

part 'stat_tile.genui.dart';

/// A small figure with its label, meant to sit beside others.
@GenUiWidget(
  description:
      'A compact figure with a label and an optional caption. Put two to four '
      'inside a Tiles component to compare numbers side by side. The value is '
      'text, so format money with the `money` function rather than writing '
      'digits by hand.',
)
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.tone = Tone.neutral,
  });

  /// What the figure is, in two or three words.
  final String label;

  /// The figure, already formatted, such as "$ 589.300" or "+67 %".
  final String value;

  /// A short line under the figure, such as "contra $ 353.600 en agosto".
  final String? caption;

  /// Colors the value: `good`, `caution`, `alert`, or `neutral` for no claim.
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${caption == null ? '' : '. $caption'}',
      excludeSemantics: true,
      child: Block(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: context.type.labelMedium, maxLines: 2),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Figures(
                value,
                style: context.type.headlineLarge?.copyWith(
                  color: tone == Tone.neutral ? null : tone.color(context),
                ),
              ),
            ),
            if (caption case final String caption) ...<Widget>[
              const SizedBox(height: 4),
              Text(caption, style: context.type.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
