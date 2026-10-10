import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../data/ledger.dart';
import '../../domain/commitments.dart';
import '../../domain/freelance.dart';
import '../../domain/plan.dart';
import '../../domain/records.dart';
import '../../domain/trips.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'coming_days_page.dart';
import 'commitments_page.dart';
import 'cushion_page.dart';
import 'detective_page.dart';
import 'envelopes_page.dart';
import 'freelance_page.dart';
import 'goal_contribution.dart';
import 'goal_sheet.dart';
import 'instalments_page.dart';
import 'look.dart';
import 'shared_page.dart';
import 'trips_page.dart';
import 'what_if_page.dart';
import 'wishes_page.dart';

/// Planning the money ahead, in four groups by what the person wants to
/// do: organize their money, with the split until payday, the income that
/// varies and the fixed payments; what they want to achieve, with goals,
/// trips and things wanted for later; what they are paying off; and the
/// tools to weigh what comes.
class PlanTab extends StatelessWidget {
  const PlanTab({super.key, required this.own});

  final OwnController own;

  void _open(BuildContext context, Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = own.ledger;
    if (ledger == null) return const SizedBox.shrink();
    final List<SavingsGoal> goals =
        own.snapshot?.goals ?? const <SavingsGoal>[];
    final CushionDays cushion = cushionDays(
      ledger,
      reserve: reserveOf(own, own.cushionSettings),
      essentials: own.cushionSettings.essentials,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(l.planOrganize),
        _EnvelopesCard(own: own, ledger: ledger),
        const SizedBox(height: 8),
        _BudgetExtras(own: own, ledger: ledger, open: _open),
        const SizedBox(height: 20),
        SectionLabel(
          l.planAchieve,
          trailing: TextButton.icon(
            onPressed: () => showGoalSheet(context, own: own),
            icon: const Icon(Glyph.plus, size: 18),
            label: Text(l.goalAdd),
          ),
        ),
        // No goal yet is a line, not a box: the button above adds one.
        if (goals.isEmpty)
          Text(l.planNoGoals, style: context.type.bodyMedium)
        else
          Panel(
            indent: 16,
            children: <Widget>[
              for (final SavingsGoal g in goals)
                _GoalRow(own: own, ledger: ledger, goal: g),
            ],
          ),
        const SizedBox(height: 8),
        Panel(
          children: <Widget>[
            _TripsRow(own: own, open: _open),
            _ToolRow(
              icon: Glyph.gift,
              title: l.wishesTitle,
              detail: own.wishes.isEmpty
                  ? l.planWishesNone
                  : l.planWishes(own.wishes.length),
              onTap: () => _open(context, WishesPage(own: own)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionLabel(l.planPaying),
        _PaymentsPanel(own: own, ledger: ledger, open: _open),
        const SizedBox(height: 20),
        SectionLabel(l.planTools),
        Panel(
          children: <Widget>[
            _ToolRow(
              icon: Glyph.calendarBlank,
              title: l.comingTitle,
              detail: l.planComing,
              onTap: () => _open(context, ComingDaysPage(own: own)),
            ),
            _ToolRow(
              icon: Glyph.sparkle,
              title: l.whatIfTitle,
              detail: l.planWhatIf,
              onTap: () => _open(context, WhatIfPage(own: own)),
            ),
            _ToolRow(
              icon: Glyph.vault,
              title: l.cushionDaysTitle,
              detail: switch (cushion.gap) {
                null => l.cushionDaysCovers(cushion.days!),
                CushionGap.noReserve => l.planCushionChoose,
                _ => l.planCushionSoon,
              },
              onTap: () => _open(context, CushionPage(own: own)),
            ),
            _DetectiveRow(own: own, open: _open),
          ],
        ),
      ],
    );
  }
}

/// The charges worth a look, among the tools: none is a payment yet.
class _DetectiveRow extends StatelessWidget {
  const _DetectiveRow({required this.own, required this.open});

  final OwnController own;
  final void Function(BuildContext context, Widget page) open;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final int alerts = <ChargeAlert>[
      for (final ChargeAlert a in own.alerts)
        if (own.detective.answers[a.id] == null) a,
    ].length;
    return _ToolRow(
      icon: Glyph.magnifyingGlass,
      title: l.detectiveTitle,
      detail: alerts == 0 ? l.planDetectiveNone : l.planDetective(alerts),
      onTap: () => open(context, DetectivePage(own: own)),
    );
  }
}

/// The trips, with what is left of the one under way.
class _TripsRow extends StatelessWidget {
  const _TripsRow({required this.own, required this.open});

  final OwnController own;
  final void Function(BuildContext context, Widget page) open;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Trip? trip = own.trips
        .where((Trip t) => t.daysLeft(own.today) > 0)
        .lastOrNull;
    return _ToolRow(
      icon: Glyph.airplaneTilt,
      title: l.tripsTitle,
      detail: switch (trip) {
        null => l.planTripsNone,
        final Trip t => switch (own.tripSummary(t).left) {
          final Decimal left => l.planTripLeft(
            t.name,
            moneyText(Money(left, t.asset), base: own.profile?.base),
          ),
          null => t.name,
        },
      },
      onTap: () => open(context, TripsPage(own: own)),
    );
  }
}

/// What is being paid off: purchases in instalments, and what is owed
/// among friends, loans with them included.
class _PaymentsPanel extends StatelessWidget {
  const _PaymentsPanel({
    required this.own,
    required this.ledger,
    required this.open,
  });

  final OwnController own;
  final Ledger ledger;
  final void Function(BuildContext context, Widget page) open;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String amount(int minor) => pesos(ledger.major(minor));
    final List<Instalments> plans = own.instalments;
    var owed = 0;
    var estimated = false;
    for (final Instalments p in plans) {
      final int? left = p.remaining;
      if (left == null) continue;
      owed += left;
      if (!p.totalKnown && left > 0) estimated = true;
    }
    final (int owedToYou, int youOwe) = own.sharedBalance;
    return Panel(
      children: <Widget>[
        _ToolRow(
          icon: Glyph.creditCard,
          title: l.instalTitle,
          detail: plans.isEmpty
              ? l.planInstalNone
              : estimated
              ? l.planInstalOwedEstimated(amount(owed))
              : l.planInstalOwed(amount(owed)),
          onTap: () => open(context, InstalmentsPage(own: own)),
        ),
        _ToolRow(
          icon: Glyph.usersThree,
          title: l.sharedTitle,
          // Only what is not zero: «Te deben $0» says nothing.
          detail: switch ((own.groups.isEmpty, owedToYou, youOwe)) {
            (true, _, _) => l.planSharedNone,
            (_, 0, 0) => l.planSharedEven,
            (_, final int owed, 0) => l.planSharedOwed(amount(owed)),
            (_, 0, final int owing) => l.planSharedOwing(amount(owing)),
            _ => l.planShared(amount(owedToYou), amount(youOwe)),
          },
          onTap: () => open(context, SharedPage(own: own)),
        ),
      ],
    );
  }
}

/// What organizes the money besides the split: income that varies, which
/// some budgets never need, and the fixed payments.
class _BudgetExtras extends StatelessWidget {
  const _BudgetExtras({
    required this.own,
    required this.ledger,
    required this.open,
  });

  final OwnController own;
  final Ledger ledger;
  final void Function(BuildContext context, Widget page) open;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String amount(int minor) => pesos(ledger.major(minor));
    final FreelancePlan freelance = own.freelance;
    final DateTime today = own.today;
    final List<ExpectedIncome> pending = <ExpectedIncome>[
      ...freelance.by(IncomeStatus.pending),
    ];
    final int late = pending
        .where((ExpectedIncome i) => i.overdue(today))
        .length;
    final DateTime until = ledger.today.add(const Duration(days: 30));
    final int fixed = <Movement>[
      for (final Movement m in ledger.upcoming)
        if (!m.id.startsWith('instalment:') && !m.date.isAfter(until)) m,
    ].fold(0, (int sum, Movement m) => sum + m.amount);
    final bool anyFixed = own.recurring.any((RecurringCharge r) => r.active);
    return Panel(
      children: <Widget>[
        _ToolRow(
          icon: Glyph.briefcase,
          title: l.freelanceTitle,
          detail: freelance.isEmpty
              ? l.planFreelanceNone
              : late > 0
              ? l.planFreelanceLate(late)
              : l.planFreelance(
                  amount(
                    pending.fold(0, (int s, ExpectedIncome i) => s + i.amount),
                  ),
                ),
          onTap: () => open(context, FreelancePage(own: own)),
        ),
        _ToolRow(
          icon: Glyph.repeat,
          title: l.fixedTitle,
          detail: anyFixed
              ? l.planFixedNext30(amount(fixed))
              : own.recurringGuesses.isNotEmpty
              ? l.planFixedGuesses(own.recurringGuesses.length)
              : l.planFixedNone,
          onTap: () => open(context, CommitmentsPage(own: own)),
        ),
      ],
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      LinkRow(icon: icon, title: title, detail: detail, onTap: onTap);
}

/// This period's envelopes, or the way to make them.
class _EnvelopesCard extends StatelessWidget {
  const _EnvelopesCard({required this.own, required this.ledger});

  final OwnController own;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String amount(int minor) => pesos(ledger.major(minor));
    final EnvelopePlan? plan = own.plan;
    void open() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EnvelopesPage(own: own),
      ),
    );
    // The period it covers, which the section's title no longer says.
    final Widget until = Text(
      l.planUntil(dayMonth(ledger.nextPayday)),
      style: context.type.bodySmall,
    );
    if (plan == null) {
      return Block(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            until,
            const SizedBox(height: 2),
            Text(l.planSplitTitle, style: context.type.titleSmall),
            const SizedBox(height: 4),
            Text(
              l.planSplitBody(amount(allocatable(ledger))),
              style: context.type.bodyMedium,
            ),
            const SizedBox(height: 10),
            // Plan's main action, while the pay has no split.
            FilledButton.icon(
              onPressed: open,
              icon: const Icon(Glyph.wallet, size: 18),
              label: Text(l.planSplit),
            ),
          ],
        ),
      );
    }
    final int daily = plan.daily;
    // Only what was spent from it after the split: what went before, or
    // was committed then, was never in it.
    final int spent = dailySpent(ledger, plan);
    final bool over = daily > 0 && spent > daily;
    final int left = unassigned(ledger, plan, spent: spent);
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          until,
          const SizedBox(height: 2),
          Text(l.envelopeDaily, style: context.type.titleSmall),
          const SizedBox(height: 2),
          Text(
            l.planDailySpent(amount(spent), amount(daily)),
            style: context.type.bodyMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: daily <= 0 ? 0 : (spent / daily).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: context.colors.sunken,
              color: over ? context.colors.caution : context.colors.positive,
            ),
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.planDailyOver(amount(spent - daily)),
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.caution,
                ),
              ),
            ),
          const SizedBox(height: 12),
          for (final Envelope e in plan.envelopes)
            if (e.kind != EnvelopeKind.daily)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: <Widget>[
                    Icon(
                      e.kind == EnvelopeKind.goal
                          ? Glyph.piggyBank
                          : Glyph.handCoins,
                      size: 16,
                      color: context.colors.inkSoft,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.name, style: context.type.bodyMedium),
                    ),
                    Figures(amount(e.amount), style: context.type.bodyMedium),
                  ],
                ),
              ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    left < 0 ? l.envelopesOverShort : l.envelopesFree,
                    style: context.type.bodyMedium,
                  ),
                ),
                // «Te pasas por» already says it is over: no minus.
                Figures(amount(left.abs()), style: context.type.bodyMedium),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: open, child: Text(l.planAdjust)),
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.own, required this.ledger, required this.goal});

  final OwnController own;
  final Ledger ledger;
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final GoalShare? share = own.goalShares
        .where((GoalShare g) => g.id == goal.id)
        .firstOrNull;
    final DateTime? arrives = share == null
        ? null
        : arrival(share, from: own.today);
    final double done = goal.target.amount.toDouble() <= 0
        ? 0
        : (goal.saved.amount.toDouble() / goal.target.amount.toDouble()).clamp(
            0,
            1,
          );
    // With a date, whether it is reached by then, and what it takes when
    // it is not: the date is there to be checked against, not only shown.
    final DateTime? deadline = goal.deadline;
    final bool reached = goal.saved.amount >= goal.target.amount;
    final bool onTime =
        arrives != null && deadline != null && !arrives.isAfter(deadline);
    final int? needed = share == null || deadline == null || reached || onTime
        ? null
        : monthlyToReach(
            share,
            deadline,
            from: own.today,
            // Pesos round to ten thousand, other currencies to ten.
            step: ledger.currency.decimals == 0 ? 10000 : 1000,
          );
    final bool late = deadline != null && !reached && !onTime;
    final TextStyle? small = context.type.bodySmall;
    return InkWell(
      onTap: () => showGoalSheet(context, own: own, goal: goal),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(goal.name, style: context.type.titleSmall),
                  ),
                  Text(percent((done * 100).round()), style: small),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: done,
                  minHeight: 6,
                  backgroundColor: context.colors.sunken,
                  color: context.colors.positive,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              <String>[
                l.goalSavedOf(
                  moneyText(goal.saved, base: own.profile?.base),
                  moneyText(goal.target, base: own.profile?.base),
                ),
                // Reached, it says so, not the month it would arrive in.
                if (reached)
                  l.goalReached
                else if (arrives != null)
                  l.goalArrives(monthYear(arrives))
                else
                  l.goalNoMonthly,
                if (onTime) l.goalOnTime(dayMonthYear(deadline)),
              ].join(' · '),
              style: small,
            ),
            if (late) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                needed == null
                    ? l.goalLatePassed(dayMonthYear(deadline))
                    : l.goalLate(
                        dayMonthYear(deadline),
                        pesos(ledger.major(needed)),
                      ),
                style: small?.copyWith(color: context.colors.caution),
              ),
            ],
            Wrap(
              alignment: WrapAlignment.end,
              children: <Widget>[
                if (late && needed != null && needed > 0)
                  TextButton(
                    onPressed: () => own.store.updateGoal(
                      SavingsGoal(
                        id: goal.id,
                        name: goal.name,
                        target: goal.target,
                        saved: goal.saved,
                        monthly: Money(
                          Decimal.fromInt(
                            needed,
                          ).shift(-goal.monthly.asset.decimals),
                          goal.monthly.asset,
                        ),
                        deadline: goal.deadline,
                      ),
                    ),
                    child: Text(l.goalUseMonthly(pesos(ledger.major(needed)))),
                  ),
                if (!reached)
                  TextButton.icon(
                    onPressed: () =>
                        showGoalContribution(context, own: own, goal: goal),
                    icon: const Icon(Glyph.plus, size: 18),
                    label: Text(l.goalContribute),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
