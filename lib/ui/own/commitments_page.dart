import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../data/ledger.dart';
import '../../domain/commitments.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'charge_sheet.dart';
import 'look.dart';

/// What is charged on its own every month or year: subscriptions, rent,
/// services. Counted as committed before it comes; never paid nor
/// cancelled from here.
class CommitmentsPage extends StatelessWidget {
  const CommitmentsPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final DateTime today = own.today;
      final List<RecurringCharge> all = <RecurringCharge>[...own.recurring]
        ..sort(
          (RecurringCharge a, RecurringCharge b) =>
              nextCharge(a, today).compareTo(nextCharge(b, today)),
        );
      bool subscription(RecurringCharge r) => r.category == 'subscriptions';
      final List<RecurringCharge> subscriptions = <RecurringCharge>[
        for (final RecurringCharge r in all)
          if (r.active && subscription(r)) r,
      ];
      final List<RecurringCharge> others = <RecurringCharge>[
        for (final RecurringCharge r in all)
          if (r.active && !subscription(r)) r,
      ];
      final List<RecurringCharge> paused = <RecurringCharge>[
        for (final RecurringCharge r in all)
          if (!r.active) r,
      ];
      final List<RecurringGuess> guesses = own.recurringGuesses;
      Widget rows(List<RecurringCharge> charges) => Panel(
        children: <Widget>[
          for (final RecurringCharge r in charges)
            _ChargeRow(own: own, ledger: ledger, charge: r),
        ],
      );
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.fixedTitle, style: context.type.titleLarge),
        ),
        floatingActionButton: ScrollAwareFab(
          child: FloatingActionButton.extended(
            onPressed: () => showChargeSheet(context, own: own),
            icon: const Icon(Glyph.plus),
            label: Text(l.chargeAdd),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Text(l.fixedBody, style: context.type.bodyMedium),
                const SizedBox(height: 16),
                if (ledger != null && all.any((RecurringCharge r) => r.active))
                  _Summary(ledger: ledger),
                if (all.isEmpty && guesses.isEmpty)
                  Block(
                    child: Text(l.fixedEmpty, style: context.type.bodyMedium),
                  ),
                // Until then the money to spend on the home is provisional.
                if (own.provisional)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _noneAtAll(context, own, guesses),
                      child: Text(l.noFixedPayments),
                    ),
                  ),
                if (guesses.isNotEmpty && ledger != null) ...<Widget>[
                  const SizedBox(height: 24),
                  SectionLabel(l.guessTitle),
                  for (final RecurringGuess g in guesses) ...<Widget>[
                    _GuessCard(own: own, ledger: ledger, guess: g),
                    const SizedBox(height: 12),
                  ],
                ],
                if (subscriptions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  SectionLabel(l.fixedSubscriptions),
                  rows(subscriptions),
                ],
                if (others.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  SectionLabel(l.fixedOthers),
                  rows(others),
                ],
                if (paused.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  SectionLabel(l.fixedPausedTitle),
                  rows(paused),
                ],
                const SizedBox(height: 20),
                Text(l.fixedNote, style: context.type.bodySmall),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The person says they pay nothing fixed. Rent, utilities or a loan the
/// history shows are asked about first: one of them is most likely a fixed
/// payment.
Future<void> _noneAtAll(
  BuildContext context,
  OwnController own,
  List<RecurringGuess> guesses,
) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final Ledger? ledger = own.ledger;
  final List<RecurringGuess> usual = <RecurringGuess>[
    for (final RecurringGuess g in guesses)
      if (monthlyKinds.contains(g.category)) g,
  ];
  if (usual.isNotEmpty && ledger != null) {
    final RecurringGuess first = usual.first;
    final Movement paid = first.evidence.last;
    final bool? none = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.fixedNoneAskTitle(first.name)),
        content: Text(
          l.fixedNoneAskBody(
            pesos(ledger.major(paid.amount)),
            dayMonth(paid.date),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.fixedNoneAskNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.fixedNoneAskAdd),
          ),
        ],
      ),
    );
    if (none == null || !context.mounted) return;
    if (!none) {
      await showChargeSheet(
        context,
        own: own,
        draft: _draftOf(first, ledger, own.profile?.base ?? Asset.cop),
      );
      return;
    }
    for (final RecurringGuess g in usual) {
      await own.notRecurring(g.name);
    }
  }
  final String done = l.fixedNoneDone;
  await own.sayNoFixedPayments(true);
  messenger.showSnackBar(SnackBar(content: Text(done)));
}

/// [guess] as a fixed payment to add, from its last charge.
ChargeDraft _draftOf(RecurringGuess guess, Ledger ledger, Asset base) =>
    ChargeDraft(
      name: guess.name,
      amount: Money(Decimal.parse('${ledger.major(guess.amount)}'), base),
      next: guess.next,
      category: guess.category.name,
    );

/// What comes in the next 30 days, and the subscriptions in a year.
class _Summary extends StatelessWidget {
  const _Summary({required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final DateTime until = ledger.today.add(const Duration(days: 30));
    final int month = <Movement>[
      for (final Movement m in ledger.upcoming)
        if (!m.id.startsWith('instalment:') && !m.date.isAfter(until)) m,
    ].fold(0, (int sum, Movement m) => sum + m.amount);
    final int year =
        ledger.subscriptions.fold(
          0,
          (int sum, Subscription s) => sum + s.price,
        ) *
        12;
    Widget figure(String caption, int amount) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(caption, style: context.type.labelMedium),
          const SizedBox(height: 2),
          Figures(pesos(ledger.major(amount)), style: context.type.titleLarge),
        ],
      ),
    );
    return Block(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          figure(l.fixedNext30, month),
          if (year > 0) ...<Widget>[
            const SizedBox(width: 16),
            figure(l.fixedSubscriptionsYear, year),
          ],
        ],
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({
    required this.own,
    required this.ledger,
    required this.charge,
  });

  final OwnController own;
  final Ledger? ledger;
  final RecurringCharge charge;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final ChargeMemory memory = own.memoryOf(charge.id);
    final DateTime today = own.today;
    final Ledger? ledger = this.ledger;
    final PriceChange? change = ledger == null
        ? null
        : lastPriceChange(ledger, charge.name);
    final Movement? last = ledger == null
        ? null
        : lastChargeOf(ledger, charge.name);
    final DateTime? trial = memory.trialEnds;
    final Money yearly = Money(
      charge.amount.amount * Decimal.fromInt(perYear(charge.cadence).round()),
      charge.amount.asset,
    );
    final TextStyle? note = context.type.bodySmall;
    return InkWell(
      onTap: () => showChargeSheet(context, own: own, charge: charge),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CategoryDisc(charge.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(charge.name, style: context.type.titleSmall),
                  Text(
                    <String>[
                      '${moneyText(charge.amount, base: base)} '
                          '${cadenceAfter(l, charge.cadence)}',
                      if (charge.active)
                        l.fixedNextOn(dayMonth(nextCharge(charge, today)))
                      else
                        l.fixedPaused,
                    ].join(' · '),
                    style: note,
                  ),
                  if (charge.active && trial != null && !trial.isBefore(today))
                    _Note(
                      icon: Glyph.hourglass,
                      text: l.fixedTrial(dayMonth(trial)),
                      color: context.colors.brand,
                    ),
                  if (charge.active && memory.inUse == false)
                    _Note(
                      icon: Glyph.piggyBank,
                      text: l.fixedNotUsed(moneyText(yearly, base: base)),
                      color: context.colors.brand,
                    ),
                  if (change != null &&
                      ledger != null &&
                      today.difference(change.on).inDays <= 120)
                    _Note(
                      icon: change.to > change.from
                          ? Glyph.trendUp
                          : Glyph.trendDown,
                      text: change.to > change.from
                          ? l.fixedPriceUp(
                              pesos(ledger.major(change.from)),
                              pesos(ledger.major(change.to)),
                              dayMonth(change.on),
                            )
                          : l.fixedPriceDown(
                              pesos(ledger.major(change.from)),
                              pesos(ledger.major(change.to)),
                              dayMonth(change.on),
                            ),
                      color: change.to > change.from
                          ? context.colors.caution
                          : context.colors.inkSoft,
                    ),
                  // The last charge differs from what is saved: offer to
                  // follow it.
                  if (charge.active &&
                      ledger != null &&
                      last != null &&
                      charge.amount.asset == base &&
                      ledger.minor(charge.amount.amount.toDouble()) !=
                          last.amount)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => own.store.updateRecurring(
                        charge.id,
                        amount: Money(
                          Decimal.parse('${ledger.major(last.amount)}'),
                          charge.amount.asset,
                        ),
                      ),
                      child: Text(
                        l.fixedFollowLast(pesos(ledger.major(last.amount))),
                      ),
                    ),
                ],
              ),
            ),
            if (memory.remindDays != null || trial != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(
                  Glyph.bell,
                  size: 16,
                  color: context.colors.inkFaint,
                  semanticLabel: l.fixedReminds,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: context.type.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

/// A merchant that charged about the same each month: offered as a fixed
/// payment, with the charges that make it look like one.
class _GuessCard extends StatelessWidget {
  const _GuessCard({
    required this.own,
    required this.ledger,
    required this.guess,
  });

  final OwnController own;
  final Ledger ledger;
  final RecurringGuess guess;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset base = own.profile?.base ?? Asset.cop;
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CategoryDisc(guess.category.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(guess.name, style: context.type.titleSmall),
                    Text(
                      guess.evidence.length == 1
                          ? l.guessOnce(
                              pesos(ledger.major(guess.amount)),
                              dayMonth(guess.evidence.single.date),
                            )
                          : l.guessEvidence(
                              guess.evidence.length,
                              pesos(ledger.major(guess.amount)),
                              guess.evidence
                                  .map((Movement m) => dayShortMonth(m.date))
                                  .join(', '),
                            ),
                      style: context.type.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => own.notRecurring(guess.name),
                child: Text(l.guessNot),
              ),
              TextButton.icon(
                onPressed: () => showChargeSheet(
                  context,
                  own: own,
                  draft: _draftOf(guess, ledger, base),
                ),
                icon: const Icon(Glyph.plus, size: 18),
                label: Text(l.guessAdd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
