import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../format/dates.dart';
import '../format/money.dart';
import '../theme/tokens.dart';
import '../ui/charts.dart';
import '../ui/kit.dart';
import 'shapes.dart';

part 'month_bars.genui.dart';

/// Spending month by month.
@GenUiWidget(
  description:
      'A bar chart of spending over several months, oldest on the left, with '
      'an optional dashed line for a reference such as income. Use it to '
      'answer how one month compares with the ones before. Highlight the month '
      'the answer is about.',
)
class MonthBars extends StatelessWidget {
  const MonthBars({
    super.key,
    required this.months,
    this.title,
    this.reference,
    this.referenceLabel,
  });

  /// A heading above the chart, such as "Últimos seis meses".
  final String? title;

  /// One entry per month, oldest first.
  final List<MonthTotal> months;

  /// An amount drawn as a dashed line across the chart, such as the monthly
  /// income.
  final double? reference;

  /// What the dashed line is, such as "Ingresos".
  final String? referenceLabel;

  @override
  Widget build(BuildContext context) {
    // Room above the tallest bar for its label.
    final double top =
        <double>[
          ...months.map((MonthTotal m) => m.amount),
          reference ?? 0,
        ].reduce((double a, double b) => a > b ? a : b) *
        1.12;

    final String summary = months
        .map((MonthTotal m) {
          final DateTime? date = parseDay(m.month);
          return '${date == null ? m.month : monthYear(date)} ${pesos(m.amount)}';
        })
        .join(', ');

    return Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (title case final String title)
                Expanded(child: Text(title, style: context.type.titleMedium))
              else
                const Spacer(),
              if (reference != null && referenceLabel != null)
                _Key(label: referenceLabel!, amount: reference!),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label:
                '${title ?? ''} $summary'
                '${reference == null ? '' : '. ${referenceLabel ?? ''} ${pesos(reference!)}'}',
            image: true,
            excludeSemantics: true,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 170,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: DrawIn(
                          builder: (BuildContext context, double progress) =>
                              CustomPaint(
                                painter: BarsPainter(
                                  progress: progress,
                                  max: top,
                                  reference: reference,
                                  lineColor: context.colors.inkFaint,
                                  bars: <Bar>[
                                    for (final MonthTotal m in months)
                                      Bar(
                                        value: m.amount,
                                        color: m.highlight
                                            ? context.colors.brand
                                            : context.colors.sunken,
                                      ),
                                  ],
                                ),
                              ),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          children: <Widget>[
                            for (final MonthTotal m in months)
                              Expanded(
                                child: m.highlight
                                    ? Align(
                                        alignment: Alignment(
                                          0,
                                          1 - (m.amount / top) * 2 - 0.16,
                                        ),
                                        child: Figures(
                                          pesosShort(m.amount),
                                          style: context.type.labelMedium
                                              ?.copyWith(
                                                color: context.colors.ink,
                                              ),
                                        ),
                                      )
                                    : const SizedBox(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    for (final MonthTotal m in months)
                      Expanded(
                        child: Text(
                          switch (parseDay(m.month)) {
                            final DateTime d => monthShort(d),
                            null => m.month,
                          },
                          textAlign: TextAlign.center,
                          style: context.type.labelMedium?.copyWith(
                            color: m.highlight
                                ? context.colors.ink
                                : context.colors.inkFaint,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        width: 18,
        child: Row(
          children: <Widget>[
            // Three dashes and the two gaps between them: 4 + 3 + 4 + 3 + 4.
            for (var i = 0; i < 3; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 3),
              Container(width: 4, height: 1.6, color: context.colors.inkFaint),
            ],
          ],
        ),
      ),
      const SizedBox(width: 6),
      Text('$label ${pesosShort(amount)}', style: context.type.bodySmall),
    ],
  );
}
