import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../format/dates.dart';
import '../format/money.dart';
import '../functions/money_functions.dart';
import '../money/money.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import '../ui/icons.dart';
import '../ui/own/amount_input.dart';
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
      'reaches the goal in time and stops on it. Moving it saves nothing.',
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
    this.current,
    this.deadline,
    this.contributionDay = 16,
    this.spendable,
    this.payday,
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

  /// Today's monthly amount, at a path of its own: away from it, the
  /// planner says it is a simulation and offers to go back.
  final double? current;

  /// The deadline, YYYY-MM-DD, at the path the functions read.
  final String? deadline;

  /// The day of the month contributions land.
  final int contributionDay;

  /// What can be spent until payday: freeUntilPayday. With `payday`, the
  /// planner says what the monthly amount changes in it.
  final double? spendable;

  /// The next payday, YYYY-MM-DD.
  final String? payday;

  /// What it takes to reach the goal in time, when that is something the
  /// slider can offer: never an amount the status line would call late.
  double? get _need {
    final double? need = needed;
    if (need == null || need <= 0) return null;
    final String? limit = deadline;
    if (parseDay(limit) != null && !arrivesBy(target, saved, need, limit!)) {
      return null;
    }
    return need;
  }

  /// Where the slider lands for [value]: on a notch, or on [needed] when it
  /// is within a notch and a half of it.
  double _landing(double value, double lo, double hi) {
    final double notch = (value / step).round() * step;
    final double? need = _need;
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
    final double? need = _need;
    // A light tick as the amount that reaches the goal is reached, either
    // way across it.
    if (need != null &&
        next != monthly &&
        (next == need || (monthly < need) != (next < need))) {
      HapticFeedback.selectionClick();
    }
    onMonthlyChanged!(next);
  }

  /// Asks for an exact monthly amount, which may be one the slider does
  /// not reach.
  Future<void> _type(BuildContext context) async {
    final double? typed = await showDialog<double>(
      context: context,
      builder: (BuildContext context) => _AmountDialog(monthly: monthly),
    );
    if (typed != null) onMonthlyChanged!(typed);
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
    final AppLocalizations l = context.l10n;
    final double? need = _need;
    final double? now = current;
    final int contributions = contributionsToGo(target, saved, monthly);

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
                percent((progress * 100).round()),
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(l.setAsideMonthly, style: context.type.labelMedium),
              ),
              Tooltip(
                message: l.goalTypeAmount,
                excludeFromSemantics: true,
                child: Semantics(
                  button: onMonthlyChanged != null,
                  label: l.goalTypeAmount,
                  child: InkWell(
                    onTap: onMonthlyChanged == null
                        ? null
                        : () => _type(context),
                    borderRadius: BorderRadius.circular(10),
                    // As tall as a finger, with the amount where it was:
                    // the spacing around the row gives the height back.
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Figures(
                            pesos(monthly),
                            style: context.type.headlineSmall,
                          ),
                          if (onMonthlyChanged != null) ...<Widget>[
                            const SizedBox(width: 6),
                            Icon(
                              Glyph.pencilSimple,
                              size: 18,
                              color: context.colors.brand,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          if (need != null && need > lo && need < hi)
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
          // Under the slider, never above it: what appears as it moves must
          // not move it from under the finger.
          if (now != null && now != monthly)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Figures(
                l.goalSimulating(pesos(now)),
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.inkSoft,
                ),
              ),
            ),
          if (onMonthlyChanged != null)
            Wrap(
              spacing: 16,
              children: <Widget>[
                if (now != null && now != monthly)
                  TextButton.icon(
                    style: _flush,
                    onPressed: () => onMonthlyChanged!(now),
                    icon: const Icon(Glyph.arrowCounterClockwise, size: 16),
                    label: Text(l.goalBackToCurrent(pesos(now))),
                  ),
                if (need != null && need != monthly)
                  TextButton.icon(
                    style: _flush,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onMonthlyChanged!(need);
                    },
                    icon: const Icon(Glyph.flag, size: 16),
                    label: Text(l.goalUseNeeded(pesos(need))),
                  ),
              ],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // With nothing going in there is no month to name,
                        // and "you get there in never" is no sentence.
                        if (contributions < 0)
                          Text(
                            l.goalNeverArrives,
                            style: context.type.bodyMedium?.copyWith(
                              color: context.colors.ink,
                            ),
                          )
                        else
                          Text.rich(
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
                                      ? context.l10n.beforeDeadline(
                                          deadlineLabel,
                                        )
                                      : context.l10n.afterDeadline(
                                          deadlineLabel,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        // Fifty years of them is no plan worth dating.
                        if (contributions > 0 &&
                            contributions <= 600) ...<Widget>[
                          const SizedBox(height: 4),
                          Figures(
                            l.goalPlanContributions(
                              contributions,
                              pesos(monthly),
                              dayMonthAhead(
                                contributionOn(0, day: contributionDay),
                              ),
                              dayMonthAhead(
                                contributionOn(
                                  contributions - 1,
                                  day: contributionDay,
                                ),
                              ),
                            ),
                            style: context.type.bodySmall?.copyWith(
                              color: context.colors.inkSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_effect(context) case final List<String> lines) ...<Widget>[
            const SizedBox(height: 16),
            Text(l.goalEffectTitle, style: context.type.labelMedium),
            for (final String line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Figures(
                  line,
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.ink,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// What the monthly amount changes in what the person can spend: until
  /// payday, and in each period after it. Null without the figures to say
  /// it, or when the goal needs nothing more.
  List<String>? _effect(BuildContext context) {
    final double? free = spendable;
    final DateTime? next = parseDay(payday);
    if (free == null || next == null || target - saved <= 0) return null;
    final AppLocalizations l = context.l10n;
    final DateTime first = contributionOn(0, day: contributionDay);
    final double? now = current;
    // Short of payday, it says by how much, as the home does: never "you
    // can spend" a negative amount.
    return <String>[
      if (first.isAfter(next))
        free < 0
            ? l.goalEffectUntilPaydayShort(
                pesos(-free),
                dayMonth(next),
                dayMonth(first),
              )
            : l.goalEffectUntilPayday(
                dayMonth(next),
                pesos(free),
                dayMonth(first),
              )
      else if (free - monthly < 0)
        l.goalEffectBeforePayShort(
          dayMonth(first),
          pesos(monthly - free),
          dayMonth(next),
        )
      else
        l.goalEffectBeforePay(
          dayMonth(first),
          dayMonth(next),
          pesos(free - monthly),
        ),
      if (now != null)
        if (monthly > now)
          l.goalEffectMore(dayMonth(next), pesos(monthly - now))
        else if (monthly < now)
          l.goalEffectLess(dayMonth(next), pesos(now - monthly))
        else
          l.goalEffectSame,
    ];
  }
}

/// An exact monthly amount, typed.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.monthly});

  final double monthly;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.monthly <= 0
        ? ''
        : formatDecimal(
            Decimal.parse(widget.monthly.toString()),
            decimals: baseCurrency.decimals,
            trim: true,
          ),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _use() {
    final Decimal? value = parseAmount(_amount.text);
    if (value == null || value <= Decimal.zero) {
      setState(() => _error = context.l10n.goalAmountInvalid);
      return;
    }
    Navigator.of(context).pop(value.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.goalAmountTitle),
      content: TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(
          decimal: baseCurrency.decimals > 0,
        ),
        inputFormatters: <TextInputFormatter>[
          AmountInputFormatter(maxDecimals: baseCurrency.decimals),
        ],
        onSubmitted: (_) => _use(),
        style: context.type.headlineSmall?.copyWith(fontFeatures: tabular),
        decoration: InputDecoration(
          labelText: l.amount,
          prefixText: switch (baseCurrency.localSymbol ?? baseCurrency.symbol) {
            final String sign => '$sign ',
            null => null,
          },
          errorText: _error,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _use, child: Text(l.goalAmountUse)),
      ],
    );
  }
}

/// A text button whose icon lines up with the text above it.
final ButtonStyle _flush = TextButton.styleFrom(
  padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 12, 8),
);

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
