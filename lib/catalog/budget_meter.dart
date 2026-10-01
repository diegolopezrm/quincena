import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../data/category.dart';
import '../format/money.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';

part 'budget_meter.genui.dart';

/// How much of a limit is gone.
@GenUiWidget(
  description:
      'A bar showing how much of a limit one category has used, such as '
      'restaurants against what was spent last month. Turns red past the '
      'limit. Use one per category being compared.',
)
class BudgetMeter extends StatelessWidget {
  const BudgetMeter({
    super.key,
    required this.category,
    required this.spent,
    required this.limit,
    this.caption,
  });

  /// The category being measured.
  final Category category;

  /// Pesos spent so far.
  final double spent;

  /// The amount it is measured against.
  final double limit;

  /// What the limit is, such as "lo de agosto" or "tu tope".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final double share = limit <= 0 ? 1 : spent / limit;
    final bool over = share > 1;
    final Color fill = over ? context.colors.negative : category.color(context);
    final String limitText =
        '${pesos(limit)}${caption == null ? '' : ' (${caption!})'}';

    return Semantics(
      label:
          '${category.label}: ${pesos(spent)} de $limitText'
          '${over ? ', pasado del límite' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                CategoryBadge(category, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(category.label, style: context.type.titleSmall),
                ),
                Figures(
                  pesos(spent),
                  style: context.type.titleSmall?.copyWith(
                    color: over ? context.colors.negative : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ColoredBox(color: context.colors.sunken),
                    ),
                    FractionallySizedBox(
                      widthFactor: share.clamp(0, 1),
                      heightFactor: 1,
                      child: ColoredBox(color: fill),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              over
                  ? '${pesos(spent - limit)} por encima de $limitText'
                  : '${pesos(limit - spent)} por debajo de $limitText',
              style: context.type.bodySmall?.copyWith(
                color: over ? context.colors.negative : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
