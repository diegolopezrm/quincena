import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import '../ui/icons.dart';
import '../l10n/l10n.dart';

part 'subscription_list.genui.dart';

/// Subscriptions, each one keep-or-cancel, with what cancelling saves.
@GenUiWidget(
  description:
      'The person\'s subscriptions, one SubscriptionRow per item, with a '
      'footer saying what cancelling the unticked ones would save. Send the '
      'rows as a template over the list in the data model, and bind `savings` '
      'to `money` over `savingsIfCancelled` on that same list: the footer then '
      'updates on the device as switches flip.',
)
class SubscriptionList extends StatelessWidget {
  const SubscriptionList({
    super.key,
    required this.title,
    @GenUiProp(template: true) required this.rows,
    required this.savings,
  });

  /// A heading, such as "Tus suscripciones".
  final String title;

  /// One SubscriptionRow per subscription.
  final List<Widget> rows;

  /// What cancelling the switched-off rows saves each month, formatted.
  final String savings;

  @override
  Widget build(BuildContext context) {
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: context.type.titleMedium),
          const SizedBox(height: 4),
          ...rows,
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Glyph.piggyBank, color: context.colors.brand, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.cancelSaves,
                          style: context.type.bodyMedium?.copyWith(
                            color: context.colors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.perMonth(savings),
                          style: context.type.headlineSmall?.copyWith(
                            color: context.colors.brand,
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
