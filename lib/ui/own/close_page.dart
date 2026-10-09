import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart' hide Flow;

import '../../data/category.dart';
import '../../data/ledger.dart';
import '../../domain/decisions.dart';
import '../../domain/plan.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'coming_days_page.dart';
import 'goal_contribution.dart';

/// The pay period that just ended, in three cards: what changed against the
/// one before, what comes until the next payday, and one thing to do. Each
/// conclusion opens the movements behind it.
class ClosePage extends StatelessWidget {
  const ClosePage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final PeriodClose? close = ledger == null
          ? null
          : closePeriod(
              ledger,
              hasGoals: own.snapshot?.goals.isNotEmpty ?? false,
            );
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.closeTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: <Widget>[
                if (ledger == null || close == null)
                  Block(
                    child: Text(l.closeNone, style: context.type.bodyMedium),
                  )
                else
                  ..._cards(context, ledger, close),
              ],
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _cards(BuildContext context, Ledger ledger, PeriodClose close) {
    final AppLocalizations l = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;
    String amount(int minor) => pesos(ledger.major(minor));
    final DateTime last = close.end.subtract(const Duration(days: 1));
    final int? before = close.spentBefore;
    final int committed = close.coming.fold(
      0,
      (int a, Movement m) => a + m.amount,
    );

    void payments(Category category) {
      final List<Movement> inPeriod = close.movementsOf(ledger, category);
      // A category that fell to nothing: what it was, so the sheet is not
      // empty and the difference has its payments.
      final List<Movement> shown = inPeriod.isEmpty
          ? close.movementsBefore(ledger, category)
          : inPeriod;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.colors.surface,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (BuildContext context) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l.closePaymentsTitle(
                  category.labelIn(lang),
                  dayShortMonth(close.start),
                  dayShortMonth(last),
                ),
                style: context.type.headlineMedium,
              ),
              const SizedBox(height: 12),
              if (inPeriod.isEmpty) ...<Widget>[
                Text(
                  l.closePaymentsNone(category.labelIn(lang)),
                  style: context.type.bodyMedium,
                ),
                const SizedBox(height: 6),
              ],
              for (final Movement m in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              m.merchant.isEmpty
                                  ? category.labelIn(lang)
                                  : m.merchant,
                              style: context.type.titleSmall,
                            ),
                            Text(
                              dayShortMonth(m.date),
                              style: context.type.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Figures(
                        amount(-m.amount),
                        style: context.type.titleSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    void days() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ComingDaysPage(own: own),
      ),
    );

    final String spentLine = close.spent == 0
        ? l.closeSpentNone
        : before == null
        ? l.closeSpentFirst(amount(close.spent))
        : close.spent > before
        ? l.closeSpentMore(amount(close.spent), amount(close.spent - before))
        : close.spent < before
        ? l.closeSpentLess(amount(close.spent), amount(before - close.spent))
        : l.closeSpentSame(amount(close.spent));

    return <Widget>[
      Text(
        l.closeRange(dayMonth(close.start), dayMonth(last)),
        style: context.type.bodyMedium,
      ),
      const SizedBox(height: 16),
      _Card(
        title: l.closeChanged,
        children: <Widget>[
          Text(spentLine, style: context.type.bodyMedium),
          const SizedBox(height: 8),
          for (final CategoryChange c in close.changes.take(3))
            InkWell(
              onTap: () => payments(c.category),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        c.category.labelIn(lang),
                        style: context.type.titleSmall,
                      ),
                    ),
                    Figures(amount(c.now), style: context.type.titleSmall),
                    if (c.before != null) ...<Widget>[
                      const SizedBox(width: 10),
                      Figures(
                        c.difference == 0
                            ? '='
                            : pesos(ledger.major(c.difference), signed: true),
                        style: context.type.bodySmall,
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Glyph.caretRight,
                      size: 16,
                      color: context.colors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          // Paid once a month, they fall in one fortnight or the other: they
          // are compared month to month, apart from the day to day.
          if (close.monthly.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(l.closeMonthly, style: context.type.bodySmall),
            for (final CategoryChange c in close.monthly)
              _MonthlyRow(
                label: c.category.labelIn(lang),
                amount: amount(c.now),
                difference: switch (c.before) {
                  null => null,
                  _ when c.difference == 0 => '=',
                  _ => pesos(ledger.major(c.difference), signed: true),
                },
              ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _Card(
        title: l.closeComing,
        children: <Widget>[
          Text(
            committed > 0
                ? l.closeComingTotal(
                    dayMonth(ledger.nextPayday),
                    amount(committed),
                  )
                : l.closeComingNone(dayMonth(ledger.nextPayday)),
            style: context.type.bodyMedium,
          ),
          for (final Movement m in close.coming.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${dayShortMonth(m.date)} · ${m.merchant}',
                      style: context.type.bodyMedium,
                    ),
                  ),
                  Figures(amount(-m.amount), style: context.type.bodyMedium),
                ],
              ),
            ),
          if (close.coming.length > 5)
            Text(
              l.closeComingMore(close.coming.length - 5),
              style: context.type.bodySmall,
            ),
          const SizedBox(height: 8),
          // Below nothing, what is missing, as the home card says it.
          Text(
            ledger.freeUntilPayday < 0
                ? l.closeShort(amount(-ledger.freeUntilPayday))
                : l.closeFree(amount(ledger.freeUntilPayday)),
            style: context.type.titleSmall?.copyWith(
              color: ledger.freeUntilPayday < 0
                  ? context.colors.negative
                  : null,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: days, child: Text(l.closeSeeDays)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _Card(
        title: l.closeAction,
        children: <Widget>[
          Text(switch (close.action) {
            CloseAction.tightDay =>
              (ledger.cushion > 0 ? l.closeActionTight : l.closeActionRunsOut)(
                dayMonth(close.tightDay!),
              ),
            CloseAction.lookAtCategory => () {
              final CategoryChange c = close.changes.firstWhere(
                (CategoryChange x) => x.category == close.actionCategory,
              );
              return l.closeActionCategory(
                c.category.labelIn(lang),
                amount(c.before ?? 0),
                amount(c.now),
              );
            }(),
            CloseAction.moveToGoal => l.closeActionGoal(
              amount(ledger.freeUntilPayday),
            ),
            null => l.closeActionNone,
          }, style: context.type.bodyMedium),
          if (close.action == CloseAction.tightDay)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: days, child: Text(l.closeSeeDays)),
            ),
          if (close.actionCategory case final Category category)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => payments(category),
                child: Text(l.closeSeePayments),
              ),
            ),
          // What is left to spend can go to a goal: from here, as money
          // that moves to where the goal is saved.
          if (close.action == CloseAction.moveToGoal)
            if (_openGoals.firstOrNull case final SavingsGoal goal)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      showGoalContribution(context, own: own, goal: goal),
                  icon: const Icon(Glyph.plus, size: 18),
                  label: Text(l.closeContributeTo(goal.name)),
                ),
              ),
        ],
      ),
      // What the period's envelopes kept for each goal is still only on
      // paper: at the close it can go to where the goal is saved.
      if (_goalEnvelopes(ledger, close) case final List<_GoalEnvelope> goals
          when goals.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        _Card(
          title: l.closeGoalsTitle,
          children: <Widget>[
            for (final _GoalEnvelope g in goals)
              if (g.left > 0)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l.closeGoalEnvelope(g.goal.name, amount(g.left)),
                        style: context.type.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => showGoalContribution(
                        context,
                        own: own,
                        goal: g.goal,
                        amount: Decimal.parse('${ledger.major(g.left)}'),
                      ),
                      child: Text(l.closeGoalMove),
                    ),
                  ],
                )
              else
                Text(
                  l.closeGoalMoved(g.goal.name, amount(g.envelope)),
                  style: context.type.bodyMedium,
                ),
          ],
        ),
      ],
    ];
  }

  /// Goals still short of what they are for, the ones with a monthly
  /// part first.
  List<SavingsGoal> get _openGoals =>
      <SavingsGoal>[
        for (final SavingsGoal g
            in own.snapshot?.goals ?? const <SavingsGoal>[])
          if (g.saved.amount < g.target.amount) g,
      ]..sort(
        (SavingsGoal a, SavingsGoal b) =>
            b.monthly.amount.compareTo(a.monthly.amount),
      );

  /// What the envelopes of the closed period, or of the one that starts,
  /// set aside for each goal still short, and what of it is still to move:
  /// what went from the money to spend in the goal's name since counts as
  /// moved.
  List<_GoalEnvelope> _goalEnvelopes(Ledger ledger, PeriodClose close) {
    final EnvelopePlan? plan = own.lastPlan;
    if (plan == null || plan.period.isBefore(close.start)) {
      return const <_GoalEnvelope>[];
    }
    int moved(SavingsGoal goal) => <Movement>[
      for (final Movement m in ledger.movements)
        if (m.flow == Flow.saving &&
            m.merchant == goal.name &&
            !m.date.isBefore(plan.period))
          m,
    ].fold(0, (int a, Movement m) => a + m.amount);
    return <_GoalEnvelope>[
      for (final Envelope e in plan.envelopes)
        if (e.kind == EnvelopeKind.goal && e.amount > 0)
          for (final SavingsGoal g in _openGoals)
            if (g.id == e.goalId)
              _GoalEnvelope(g, e.amount, math.max(0, e.amount - moved(g))),
    ];
  }
}

/// A goal's envelope at the close: what it set aside, and what of that is
/// still in the money to spend.
class _GoalEnvelope {
  const _GoalEnvelope(this.goal, this.envelope, this.left);

  final SavingsGoal goal;
  final int envelope;
  final int left;
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Block(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: context.type.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

/// A monthly payment at the close: its month and how it compares with the
/// month before, the figures under the name when the text is large.
class _MonthlyRow extends StatelessWidget {
  const _MonthlyRow({
    required this.label,
    required this.amount,
    required this.difference,
  });

  final String label;
  final String amount;

  /// Against the month before; null without one recorded.
  final String? difference;

  @override
  Widget build(BuildContext context) {
    final Widget name = Text(label, style: context.type.bodyMedium);
    final List<Widget> figures = <Widget>[
      Figures(amount, style: context.type.bodyMedium),
      if (difference case final String d) ...<Widget>[
        const SizedBox(width: 10),
        Figures(d, style: context.type.bodySmall),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: largeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                name,
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: figures,
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: name),
                ...figures,
                // Lined up with the rows above, which open their payments.
                const SizedBox(width: 20),
              ],
            ),
    );
  }
}
