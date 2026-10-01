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

  String _monthName(MonthTotal m) => switch (parseDay(m.month)) {
    final DateTime d => monthYear(d).split(' ').first,
    null => m.month,
  };

  @override
  Widget build(BuildContext context) {
    // Room above the tallest bar.
    final double top =
        <double>[
          ...months.map((MonthTotal m) => m.amount),
          reference ?? 0,
        ].reduce((double a, double b) => a > b ? a : b) *
        1.08;
    final MonthTotal? focus = months
        .where((MonthTotal m) => m.highlight)
        .firstOrNull;

    final String summary = months
        .map((MonthTotal m) => '${_monthName(m)} ${pesos(m.amount)}')
        .join(', ');

    return Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title case final String title)
            Text(title, style: context.type.titleMedium),
          // The highlighted month's amount and the reference are said in
          // words above the chart, where they cannot collide with the bars.
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: <Widget>[
              if (focus != null)
                _Legend(
                  mark: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.colors.brand,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  label: _monthName(focus),
                  amount: focus.amount,
                ),
              if (reference != null)
                _Legend(
                  mark: const _Dashes(),
                  label: referenceLabel ?? 'Referencia',
                  amount: reference!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label:
                '${title ?? ''} $summary'
                '${reference == null ? '' : '. ${referenceLabel ?? ''} ${pesos(reference!)}'}',
            image: true,
            excludeSemantics: true,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 150,
                  child: DrawIn(
                    builder: (BuildContext context, double progress) =>
                        CustomPaint(
                          size: Size.infinite,
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

class _Legend extends StatelessWidget {
  const _Legend({
    required this.mark,
    required this.label,
    required this.amount,
  });

  final Widget mark;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      mark,
      const SizedBox(width: 8),
      Text(label, style: context.type.bodySmall),
      const SizedBox(width: 6),
      Figures(
        pesosShort(amount),
        style: context.type.labelMedium?.copyWith(color: context.colors.ink),
      ),
    ],
  );
}

/// The reference line's key: three dashes and the two gaps between them.
class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    child: Row(
      children: <Widget>[
        for (var i = 0; i < 3; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 3),
          Container(width: 4, height: 1.6, color: context.colors.inkFaint),
        ],
      ],
    ),
  );
}
