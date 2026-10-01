import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../format/money.dart';
import '../theme/tokens.dart';
import '../ui/charts.dart';
import '../ui/kit.dart';
import 'shapes.dart';

part 'spending_donut.genui.dart';

/// Where a period's money went, by category.
@GenUiWidget(
  description:
      'A donut chart of spending by category, with a legend listing each '
      'category, its amount and its share. Use it to answer where the money '
      'went in a period. Send every category with spending, largest first.',
)
class SpendingDonut extends StatelessWidget {
  const SpendingDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.title,
  });

  /// A heading above the chart, such as "Por categoría".
  final String? title;

  /// The categories and their amounts, largest first.
  final List<CategorySlice> slices;

  /// A word or two under the total in the middle of the ring, such as
  /// "septiembre".
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final double total = slices.fold(
      0,
      (double s, CategorySlice e) => s + e.amount,
    );
    final String summary = slices
        .map(
          (CategorySlice s) => '${s.category.label} ${_share(s.amount, total)}',
        )
        .join(', ');

    return Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title case final String title) ...<Widget>[
            Text(title, style: context.type.titleMedium),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final bool wide = box.maxWidth >= 520;
              final Widget ring = _Ring(
                slices: slices,
                total: total,
                centerLabel: centerLabel,
                semantics: '$centerLabel, ${pesos(total)} en total: $summary',
              );
              final Widget legend = _Legend(slices: slices, total: total);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(width: 210, height: 210, child: ring),
                    const SizedBox(width: 36),
                    // A legend as wide as the card sends the eye a long way
                    // from each name to its amount.
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: legend,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  SizedBox(width: 220, height: 220, child: ring),
                  const SizedBox(height: 18),
                  legend,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _share(double amount, double total) =>
    total <= 0 ? '0 %' : '${(amount / total * 100).round()} %';

class _Ring extends StatelessWidget {
  const _Ring({
    required this.slices,
    required this.total,
    required this.centerLabel,
    required this.semantics,
  });

  final List<CategorySlice> slices;
  final double total;
  final String centerLabel;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      image: true,
      excludeSemantics: true,
      child: DrawIn(
        builder: (BuildContext context, double progress) => CustomPaint(
          painter: DonutPainter(
            progress: progress,
            track: context.colors.sunken,
            segments: <DonutSegment>[
              for (final CategorySlice s in slices)
                DonutSegment(s.amount, s.category.color(context)),
            ],
          ),
          // The middle of the ring has a fixed size, and the label is the
          // agent's to write: it gets two lines, and the total shrinks to fit.
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Figures(
                      pesosShort(total),
                      style: context.type.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centerLabel,
                    style: context.type.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.slices, required this.total});

  final List<CategorySlice> slices;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final CategorySlice s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.category.color(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.category.label,
                    style: context.type.bodyMedium?.copyWith(
                      color: context.colors.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Figures(
                  pesos(s.amount),
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.ink,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Figures(
                    _share(s.amount, total),
                    textAlign: TextAlign.right,
                    style: context.type.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
