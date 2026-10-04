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
import 'goal_sheet.dart';
import 'instalments_page.dart';
import 'look.dart';
import 'shared_page.dart';
import 'trips_page.dart';
import 'what_if_page.dart';
import 'wishes_page.dart';

/// Planning the money ahead, in four groups: the budget until payday, with
/// the income that varies and the trips; the savings goals, with the
/// things wanted for later; the payments already promised; and the tools
/// to weigh what comes.
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
        SectionLabel(l.planPeriod(dayMonth(ledger.nextPayday))),
        _EnvelopesCard(own: own, ledger: ledger),
        const SizedBox(height: 12),
        _BudgetExtras(own: own, ledger: ledger, open: _open),
        const SizedBox(height: 28),
        SectionLabel(
          l.planGoals,
          trailing: TextButton.icon(
            onPressed: () => showGoalSheet(context, own: own),
            icon: const Icon(Glyph.plus, size: 18),
            label: Text(l.goalAdd),
          ),
        ),
        if (goals.isEmpty)
          Block(child: Text(l.planNoGoals, style: context.type.bodyMedium))
        else
          Panel(
            indent: 16,
            children: <Widget>[
              for (final SavingsGoal g in goals)
                _GoalRow(own: own, ledger: ledger, goal: g),
            ],
          ),
        const SizedBox(height: 12),
        Panel(
          children: <Widget>[
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
        const SizedBox(height: 28),
        SectionLabel(l.planCommitments),
        _PaymentsPanel(own: own, ledger: ledger, open: _open),
        const SizedBox(height: 28),
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
          ],
        ),
      ],
    );
  }
}

/// What is already promised ahead: fixed payments, instalments, what is
/// owed among friends, and the charges worth a look.
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
    final DateTime until = ledger.today.add(const Duration(days: 30));
    final int fixed = <Movement>[
      for (final Movement m in ledger.upcoming)
        if (!m.id.startsWith('instalment:') && !m.date.isAfter(until)) m,
    ].fold(0, (int sum, Movement m) => sum + m.amount);
    final bool anyFixed = own.recurring.any((RecurringCharge r) => r.active);
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
    final int alerts = <ChargeAlert>[
      for (final ChargeAlert a in own.alerts)
        if (own.detective.answers[a.id] == null) a,
    ].length;
    return Panel(
      children: <Widget>[
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
          detail: own.groups.isEmpty
              ? l.planSharedNone
              : l.planShared(amount(owedToYou), amount(youOwe)),
          onTap: () => open(context, SharedPage(own: own)),
        ),
        _ToolRow(
          icon: Glyph.magnifyingGlass,
          title: l.detectiveTitle,
          detail: alerts == 0 ? l.planDetectiveNone : l.planDetective(alerts),
          onTap: () => open(context, DetectivePage(own: own)),
        ),
      ],
    );
  }
}

/// What some budgets need and others never will: income that varies, and
/// a trip with its own budget. Each can be left alone.
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
    final Trip? trip = own.trips
        .where((Trip t) => t.daysLeft(today) > 0)
        .lastOrNull;
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
  Widget build(BuildContext context) {
    final Widget mark = Icon(icon, color: context.colors.brand);
    final Widget name = Text(title, style: context.type.titleSmall);
    // With large text the icon goes above the title, as iOS lays out its
    // own rows at those sizes, and the words have the whole width.
    final bool large = largeText(context);
    return ListTile(
      onTap: onTap,
      leading: large ? null : mark,
      title: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[mark, const SizedBox(height: 4), name],
            )
          : name,
      subtitle: Text(detail, style: context.type.bodySmall),
      trailing: Icon(
        Glyph.caretRight,
        size: 18,
        color: context.colors.inkFaint,
      ),
    );
  }
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
    if (plan == null) {
      return Block(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.planSplitTitle, style: context.type.titleSmall),
            const SizedBox(height: 4),
            Text(
              l.planSplitBody(amount(allocatable(ledger))),
              style: context.type.bodyMedium,
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: open,
              icon: const Icon(Glyph.wallet, size: 18),
              label: Text(l.planSplit),
            ),
          ],
        ),
      );
    }
    final int daily = plan.daily;
    final int spent = spentThisPeriod(ledger);
    final bool over = daily > 0 && spent > daily;
    final int left = allocatable(ledger) - plan.assigned;
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
              color: over ? context.colors.caution : context.colors.brand,
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
                Figures(amount(left), style: context.type.bodyMedium),
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
    return InkWell(
      onTap: () => showGoalSheet(context, own: own, goal: goal),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(goal.name, style: context.type.titleSmall),
                ),
                Text(
                  percent((done * 100).round()),
                  style: context.type.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: done,
                minHeight: 6,
                backgroundColor: context.colors.sunken,
                color: context.colors.brand,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              <String>[
                l.goalSavedOf(
                  moneyText(goal.saved, base: own.profile?.base),
                  moneyText(goal.target, base: own.profile?.base),
                ),
                if (arrives != null)
                  l.goalArrives(monthYear(arrives))
                else
                  l.goalNoMonthly,
              ].join(' · '),
              style: context.type.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
