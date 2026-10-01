import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../data/clock.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../l10n/l10n.dart';

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
        ? context.l10n.noUsage
        : context.l10n.used(ago(used));

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          // No category badge: every row in the list is a subscription, so
          // the same icon on each one would only take room from the text.
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodyLarge?.copyWith(
                      decoration: keep ? null : TextDecoration.lineThrough,
                      color: keep ? null : context.colors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: context.type.bodySmall,
                      children: <InlineSpan>[
                        TextSpan(
                          text: pesos(price),
                          style: TextStyle(
                            fontFeatures: tabular,
                            color: keep ? context.colors.inkSoft : null,
                          ),
                        ),
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: usage,
                          style: TextStyle(
                            color: stale ? context.colors.caution : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
