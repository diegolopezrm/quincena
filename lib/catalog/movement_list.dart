import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../format/dates.dart';
import '../format/money.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'shapes.dart';

part 'movement_list.genui.dart';

/// Payments from the statement.
@GenUiWidget(
  description:
      'A list of payments from the statement, each with its merchant, '
      'category, day and amount. Use it to show the payments behind a finding, '
      'such as the largest of the month or every payment in one category. '
      'Ten rows or fewer.',
)
class MovementList extends StatelessWidget {
  const MovementList({super.key, required this.title, required this.items});

  /// What the list is, such as "Los cinco pagos más grandes".
  final String title;

  /// The payments, in the order they should be read.
  final List<MovementItem> items;

  @override
  Widget build(BuildContext context) {
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: context.type.titleMedium),
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) Divider(color: context.colors.line, height: 1),
            _Row(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final MovementItem item;

  @override
  Widget build(BuildContext context) {
    final DateTime? date = parseDay(item.date);
    final String when = date == null ? item.date : dayShortMonth(date);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: <Widget>[
            CategoryBadge(item.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.merchant,
                    style: context.type.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${item.category.label} · $when',
                    style: context.type.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Figures(pesos(item.amount), style: context.type.titleSmall),
          ],
        ),
      ),
    );
  }
}
