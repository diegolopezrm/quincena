import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../format/money.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'tone.dart';

part 'big_amount.genui.dart';

/// One amount, large.
@GenUiWidget(
  description:
      'One amount of money shown large, with a label above and a caption '
      'below. Use it for the single number an answer turns on, at most once '
      'per surface.',
)
class BigAmount extends StatelessWidget {
  const BigAmount({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.tone = Tone.neutral,
  });

  /// What the amount is, such as "Gastado en septiembre".
  final String label;

  /// The amount in pesos.
  final double amount;

  /// A short line under the amount that puts it in context, such as "de
  /// $ 4.800.000 que entraron".
  final String? caption;

  /// Colors the caption: `good` when the number is fine, `caution` when it is
  /// worth a look, `alert` when something has to change.
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final String spoken =
        '$label: ${pesos(amount)}'
        '${caption == null ? '' : '. $caption'}';
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Block(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: context.type.labelMedium),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Figures(pesos(amount), style: context.type.displayMedium),
            ),
            if (caption case final String caption) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                caption,
                style: context.type.bodyMedium?.copyWith(
                  color: tone == Tone.neutral
                      ? context.colors.inkSoft
                      : tone.color(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
