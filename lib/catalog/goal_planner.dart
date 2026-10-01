import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../format/money.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import '../ui/icons.dart';
import '../l10n/l10n.dart';

part 'goal_planner.genui.dart';

/// A savings goal, and a control for how fast to reach it.
@GenUiWidget(
  description:
      'A savings goal with its progress and a slider for how much to put '
      'aside each month. Bind `monthly` to a data path: the slider writes '
      'there as it moves. Bind `arrival` to the `arrivalMonth` function and '
      '`onTime` to the `arrivesBy` function over the same paths, and the '
      'answer recalculates on the device as the person drags, with no new '
      'message from you.',
)
class GoalPlanner extends StatelessWidget {
  const GoalPlanner({
    super.key,
    required this.name,
    required this.target,
    required this.saved,
    required this.monthly,
    required this.max,
    required this.arrival,
    required this.onTime,
    required this.deadlineLabel,
    @GenUiWrites('monthly') this.onMonthlyChanged,
    this.min = 0,
    this.step = 10000,
  });

  /// What the money is for, such as "Cartagena".
  final String name;

  /// The full amount the goal needs, in pesos.
  final double target;

  /// What is already put aside, in pesos.
  final double saved;

  /// How much goes into the goal each month. Bind it to a data path so the
  /// slider can change it.
  final double monthly;

  /// The lowest monthly amount the slider offers.
  final double min;

  /// The highest monthly amount the slider offers. Keep it within what the
  /// person could actually put aside.
  final double max;

  /// How far one notch of the slider moves, in pesos.
  final double step;

  /// When the goal is reached at the current pace, as text such as "mayo de
  /// 2027". Bind it to the `arrivalMonth` function.
  final String arrival;

  /// Whether the goal is reached by the deadline at the current pace. Bind it
  /// to the `arrivesBy` function.
  final bool onTime;

  /// The deadline as day and month, such as "20 de diciembre".
  final String deadlineLabel;

  /// Called with the new monthly amount as the slider moves.
  final ValueChanged<double>? onMonthlyChanged;

  @override
  Widget build(BuildContext context) {
    final double progress = target <= 0 ? 0 : (saved / target).clamp(0, 1);
    final double lo = min;
    final double hi = max <= lo ? lo + step : max;
    final int divisions = ((hi - lo) / step).round().clamp(1, 200);
    final Color status = onTime
        ? context.colors.positive
        : context.colors.caution;

    return Block(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Glyph.airplaneTilt,
                  color: context.colors.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name, style: context.type.titleLarge),
                    Figures(
                      englishFormatting
                          ? '${pesos(saved)} of ${pesos(target)}'
                          : '${pesos(saved)} de ${pesos(target)}',
                      style: context.type.bodySmall,
                    ),
                  ],
                ),
              ),
              Figures(
                _percent(progress),
                style: context.type.titleMedium?.copyWith(
                  color: context.colors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: context.l10n.goalProgress((progress * 100).round()),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: context.colors.sunken,
                color: context.colors.brand,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.setAsideMonthly,
                  style: context.type.labelMedium,
                ),
              ),
              Figures(pesos(monthly), style: context.type.headlineSmall),
            ],
          ),
          const SizedBox(height: 6),
          // A slider announces its value on its own, and nothing else; the
          // name is what tells a screen reader user what the value is of.
          // Merged, so the name lands on the slider's own node; a label on a
          // separate parent is a node of its own that announces nothing.
          MergeSemantics(
            child: Semantics(
              label: context.l10n.goalSlider(name),
              child: Slider(
                value: monthly.clamp(lo, hi),
                min: lo,
                max: hi,
                divisions: divisions,
                // The track lines up with the labels under it; the amount is
                // already shown large above, so no bubble repeats it.
                padding: EdgeInsets.zero,
                semanticFormatterCallback: (double value) =>
                    context.l10n.perMonth(pesos(value)),
                onChanged: onMonthlyChanged == null
                    ? null
                    : (double value) =>
                          onMonthlyChanged!((value / step).round() * step),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: <Widget>[
                Figures(pesosShort(lo), style: context.type.bodySmall),
                const Spacer(),
                Figures(pesosShort(hi), style: context.type.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    onTime ? Glyph.checkCircle : Glyph.calendarBlank,
                    color: status,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: context.type.bodyMedium?.copyWith(
                          color: context.colors.ink,
                        ),
                        children: <InlineSpan>[
                          TextSpan(text: context.l10n.arrivesIn),
                          TextSpan(
                            text: arrival,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontVariations: const <FontVariation>[
                                FontVariation('wght', 620),
                              ],
                              fontFeatures: tabular,
                              color: status,
                            ),
                          ),
                          TextSpan(
                            text: onTime
                                ? context.l10n.beforeDeadline(deadlineLabel)
                                : context.l10n.afterDeadline(deadlineLabel),
                          ),
                        ],
                      ),
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

/// A share of the goal: `36 %` in Spanish, `36%` in English.
String _percent(double share) =>
    '${(share * 100).round()}${englishFormatting ? '' : '\u00a0'}%';
