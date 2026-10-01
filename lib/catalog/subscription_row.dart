import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../data/category.dart';
import '../data/clock.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';

part 'subscription_row.genui.dart';

/// One subscription, with a switch to keep it or not.
@GenUiWidget(
  description:
      'One subscription with its monthly price, when it was last used, and a '
      'switch to keep it. Bind `keep` to a data path: the switch writes there. '
      'Meant as the template row of a SubscriptionList, with every property '
      'bound to a path relative to the row.',
)
class SubscriptionRow extends StatelessWidget {
  const SubscriptionRow({
    super.key,
    required this.name,
    required this.price,
    required this.keep,
    @GenUiWrites('keep') this.onKeepChanged,
    this.lastUsed,
  });

  /// The service, as the statement names it.
  final String name;

  /// What it costs every month, in pesos.
  final double price;

  /// The last day it was used, written as YYYY-MM-DD.
  final String? lastUsed;

  /// Whether the person keeps paying for it.
  final bool keep;

  /// Called when the switch is flipped.
  final ValueChanged<bool>? onKeepChanged;

  @override
  Widget build(BuildContext context) {
    final DateTime? used = parseDay(lastUsed);
    final bool stale = used != null && appToday.difference(used).inDays > 30;
    final String usage = used == null
        ? 'Sin datos de uso'
        : 'Último uso ${ago(used)}';

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            const CategoryBadge(Category.subscriptions),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: context.type.bodyLarge?.copyWith(
                      decoration: keep ? null : TextDecoration.lineThrough,
                      color: keep ? null : context.colors.inkFaint,
                    ),
                  ),
                  Text(
                    usage,
                    style: context.type.bodySmall?.copyWith(
                      color: stale ? context.colors.caution : null,
                    ),
                  ),
                ],
              ),
            ),
            Figures(
              pesos(price),
              style: context.type.titleSmall?.copyWith(
                color: keep ? null : context.colors.inkFaint,
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: keep, onChanged: onKeepChanged),
          ],
        ),
      ),
    );
  }
}
