import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'message from you. Bind `needed` to the `monthlyNeeded` function over '
      'the same paths and deadline: the slider marks the amount that '
      'reaches the goal in time and stops on it.',
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
    this.needed,
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

  /// The monthly amount that reaches the goal by the deadline. Bind it to
  /// the `monthlyNeeded` function over the same paths: the slider marks
  /// it, stops on it when dragged near, and the phone ticks as it is
  /// reached.
  final double? needed;

  /// Where the slider lands for [value]: on a notch, or on [needed] when it
  /// is within a notch and a half of it.
  double _landing(double value, double lo, double hi) {
    final double notch = (value / step).round() * step;
    final double? need = needed;
    if (need != null &&
        need > lo &&
        need < hi &&
        (notch - need).abs() <= step * 1.5) {
      return need;
    }
    return notch;
  }

  void _move(double value, double lo, double hi) {
    final double next = _landing(value, lo, hi);
    final double? need = needed;
    // A light tick as the amount that reaches the goal is reached, either
    // way across it.
    if (need != null &&
        next != monthly &&
        (next == need || (monthly < need) != (next < need))) {
      HapticFeedback.selectionClick();
    }
    onMonthlyChanged!(next);
  }

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
                      target - saved <= 0
                          ? context.l10n.goalReached
                          : '${context.l10n.goalSoFar(pesos(saved))} · '
                                '${context.l10n.goalMissing(pesos(target - saved))}',
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
                    : (double value) => _move(value, lo, hi),
              ),
            ),
          ),
          if (needed case final double need when need > lo && need < hi)
            _NeedMark(fraction: (need - lo) / (hi - lo), amount: need),
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

/// Where on the slider the goal is reached in time, and how much that is.
class _NeedMark extends StatelessWidget {
  const _NeedMark({required this.fraction, required this.amount});

  /// How far along the track the amount sits, from 0 to 1.
  final double fraction;
  final double amount;

  @override
  Widget build(BuildContext context) {
    const double width = 140;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double x = fraction * box.maxWidth;
        return SizedBox(
          height: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: x - 1,
                top: 2,
                child: Container(
                  width: 2,
                  height: 8,
                  color: context.colors.brand,
                ),
              ),
              Positioned(
                left: (x - width / 2).clamp(0, box.maxWidth - width),
                top: 10,
                width: width,
                child: Figures(
                  context.l10n.goalNeedMark(pesos(amount)),
                  textAlign: TextAlign.center,
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.brand,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A share of the goal: `36 %` in Spanish, `36%` in English.
String _percent(double share) =>
    '${(share * 100).round()}${englishFormatting ? '' : '\u00a0'}%';
