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

/// One subscription, with a box to tick it for cancelling.
@GenUiWidget(
  description:
      'One subscription with its monthly price, when it was last used, and a '
      'checkbox to tick it for cancelling. Bind `keep` to a data path: ticking '
      'the box writes false there. Set `cancelled` only after the person says '
      'they cancelled it with the service: the row is then struck through, '
      'with no box. Meant as the template row of a SubscriptionList, with '
      'every property bound to a path relative to the row.',
)
class SubscriptionRow extends StatelessWidget {
  const SubscriptionRow({
    super.key,
    required this.name,
    required this.price,
    required this.keep,
    @GenUiWrites('keep') this.onKeepChanged,
    this.lastUsed,
    this.cancelled = false,
  });

  /// The service, as the statement names it.
  final String name;

  /// What it costs every month, in pesos.
  final double price;

  /// The last day it was used, written as YYYY-MM-DD.
  final String? lastUsed;

  /// Whether the person keeps paying for it. False while its box is ticked.
  final bool keep;

  /// Called when the box is ticked or cleared, with the new [keep].
  final ValueChanged<bool>? onKeepChanged;

  /// Whether the person already cancelled it with the service. Quincena
  /// cancels nothing: this only shows what they said they did.
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final DateTime? used = parseDay(lastUsed);
    final bool stale = used != null && appToday.difference(used).inDays > 30;
    final String usage = used == null
        ? context.l10n.noUsage
        : context.l10n.used(ago(used));
    // Ticked is only a choice; struck through is what the person did.
    final bool ticked = !keep && !cancelled;

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
                  // The box's own label says the name, with what ticking
                  // it does.
                  ExcludeSemantics(
                    excluding: !cancelled,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.bodyLarge?.copyWith(
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                        color: cancelled ? context.colors.inkFaint : null,
                      ),
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
                            color: cancelled ? null : context.colors.inkSoft,
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
            if (cancelled)
              _Tag(
                context.l10n.subscriptionCancelled,
                color: context.colors.inkSoft,
                background: context.colors.sunken,
              )
            else ...<Widget>[
              if (ticked)
                _Tag(
                  context.l10n.subscriptionToCancel,
                  color: context.colors.caution,
                  background: context.colors.cautionSoft,
                ),
              Checkbox(
                value: ticked,
                semanticLabel: context.l10n.subscriptionSelect(name),
                onChanged: onKeepChanged == null
                    ? null
                    : (bool? on) => onKeepChanged!(on != true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A short state next to the box, such as "Para cancelar".
class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text, style: context.type.labelSmall?.copyWith(color: color)),
  );
}
