import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../data/ledger.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../money/rates.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../kit.dart';
import 'accounts_tab.dart';
import 'look.dart';

/// Shows how the money to spend until payday is worked out.
Future<void> showFreeExplained(BuildContext context, OwnController own) =>
    _explain(context, FreeExplained(own: own));

/// Shows how the money to spend until payday is worked out from [ledger]
/// alone, for a card with no accounts of its own behind it: the sample's.
Future<void> showLedgerExplained(BuildContext context, Ledger ledger) =>
    _explain(context, LedgerExplained(ledger: ledger));

Future<void> _explain(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (BuildContext context) => sheet,
    );

/// The amount to spend taken apart with the person's accounts: what each
/// everyday account holds today and the rate that converted it, what the
/// figure leaves out, and what waits in Por revisar, around the ledger's
/// own sum.
class FreeExplained extends StatelessWidget {
  const FreeExplained({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = own.ledger;
    final Asset? base = own.profile?.base;
    if (ledger == null || base == null) return const SizedBox.shrink();
    final List<Account> spendable = <Account>[
      for (final Account a in own.accounts)
        if (a.spendable && !a.archived) a,
    ];
    final List<Account> leftOut = <Account>[
      for (final Account a in own.accounts)
        if (!a.spendable && !a.archived) a,
    ];
    final Set<Asset> unpriced = own.unconverted;
    return LedgerExplained(
      ledger: ledger,
      cardDebt: own.spendableCardDebt,
      pending: own.pendingInbox.length,
      latePay: own.projection?.latePay,
      accounts: Panel(
        children: <Widget>[
          for (final Account a in spendable)
            _AccountPart(
              own: own,
              account: a,
              base: base,
              value: pesos(ledger.major(own.spendableParts[a.id] ?? 0)),
            ),
        ],
      ),
      leftOut: <String>[
        if (leftOut.isNotEmpty)
          l.freeExplainLeftOutBody(
            leftOut.map((Account a) => a.name).join(', '),
          ),
        if (unpriced.isNotEmpty)
          l.freeExplainUnpriced(unpriced.map((Asset a) => a.code).join(', ')),
      ],
    );
  }
}

/// The amount to spend taken apart from the ledger alone: the sum behind
/// it, what is due until payday, and what it assumes.
///
/// Every amount comes from the ledger's own arithmetic, so the parts add up
/// to the figure on the home card. Where the money is kept and what does
/// not count come from someone's own accounts, in [accounts] and
/// [leftOut]; the sample has neither.
class LedgerExplained extends StatelessWidget {
  const LedgerExplained({
    super.key,
    required this.ledger,
    this.cardDebt = 0,
    this.pending = 0,
    this.latePay,
    this.accounts,
    this.leftOut = const <String>[],
  });

  final Ledger ledger;

  /// What the credit cards counted here owe, in the ledger's smallest unit:
  /// with some, the sum starts from what the accounts hold and takes the
  /// debt off in a line of its own, as the home card does.
  final int cardDebt;

  /// How many movements wait in Por revisar, which the figure leaves out.
  final int pending;

  /// The payday that passed without the pay, when there is one.
  final DateTime? latePay;

  /// Each everyday account with what it adds.
  final Widget? accounts;

  /// What the figure leaves out, a line each.
  final List<String> leftOut;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String amount(int minor) => pesos(ledger.major(minor));
    final List<Movement> committed = ledger.committed;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: <Widget>[
          Text(l.freeExplainTitle, style: context.type.headlineMedium),
          const SizedBox(height: 16),
          Block(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              children: <Widget>[
                ExplainSum(
                  label: l.freeExplainSpendable,
                  value: amount(ledger.balance + cardDebt),
                ),
                if (cardDebt > 0)
                  ExplainSum(
                    label: l.standingCardDebtLine,
                    value: amount(-cardDebt),
                  ),
                ExplainSum(
                  label: l.freeExplainCommitted(
                    dayShortMonth(ledger.nextPayday),
                  ),
                  value: amount(-ledger.committedUntilPayday),
                ),
                if (ledger.cushion > 0)
                  ExplainSum(
                    label: l.freeExplainCushion,
                    value: amount(-ledger.cushion),
                  ),
                if (ledger.setAside > 0)
                  ExplainSum(
                    label: l.freeExplainSetAside,
                    value: amount(-ledger.setAside),
                  ),
                if (ledger.reserved > 0)
                  ExplainSum(
                    label: l.freeExplainReserved,
                    value: amount(-ledger.reserved),
                  ),
                Divider(color: context.colors.line, height: 20),
                ExplainSum(
                  label: l.freeUntil(dayMonth(ledger.nextPayday)),
                  value: amount(ledger.freeUntilPayday),
                  strong: true,
                ),
              ],
            ),
          ),
          if (accounts case final Widget panel) ...<Widget>[
            const SizedBox(height: 24),
            SectionLabel(l.freeExplainSpendableSection),
            panel,
          ],
          const SizedBox(height: 24),
          SectionLabel(
            l.freeExplainCommitted(dayShortMonth(ledger.nextPayday)),
          ),
          if (committed.isEmpty)
            Text(
              l.freeExplainNothingCommitted(dayShortMonth(ledger.nextPayday)),
              style: context.type.bodyMedium,
            )
          else
            Panel(
              children: <Widget>[
                for (final Movement m in committed)
                  ExplainLine(
                    title: m.merchant,
                    detail: dayShortMonth(m.date),
                    value: amount(-m.amount),
                  ),
              ],
            ),
          if (leftOut.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            SectionLabel(l.freeExplainLeftOut),
            for (final (int i, String line) in leftOut.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Text(line, style: context.type.bodyMedium),
              ),
          ],
          const SizedBox(height: 24),
          SectionLabel(l.freeExplainAssumptions),
          for (final String line in <String>[
            l.freeExplainAssumeToday(dayMonth(ledger.nextPayday)),
            if (pending > 0) l.freeExplainAssumePending(pending),
            if (ledger.pay case final int pay)
              l.freeExplainAssumePay(amount(pay), dayMonth(ledger.nextPayday))
            else
              l.freeExplainAssumeNoPay,
            if (latePay case final DateTime late) l.payLate(dayMonth(late)),
            if (ledger.cushion > 0)
              l.freeExplainAssumeCushion(amount(ledger.cushion))
            else
              l.freeExplainAssumeNoCushion,
            l.freeExplainEstimate,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: context.type.bodyMedium),
            ),
        ],
      ),
    );
  }
}

/// One line of a sum: a label and an amount, the total in bold.
class ExplainSum extends StatelessWidget {
  const ExplainSum({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = strong
        ? context.type.titleMedium
        : context.type.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text(label, style: style)),
            const SizedBox(width: 12),
            Figures(value, style: style),
          ],
        ),
      ),
    );
  }
}

/// What one spendable account adds, and the rate that converted it when
/// it is not in the base currency.
class _AccountPart extends StatelessWidget {
  const _AccountPart({
    required this.own,
    required this.account,
    required this.base,
    required this.value,
  });

  final OwnController own;
  final Account account;
  final Asset base;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Money held = own.balances[account.id] ?? account.openingMoney;
    final String? detail = account.asset == base
        ? null
        : conversionDetail(l, own.rates, held, base);
    return ExplainLine(title: account.name, detail: detail, value: value);
  }
}

/// A name, what explains it, and an amount.
class ExplainLine extends StatelessWidget {
  const ExplainLine({
    super.key,
    required this.title,
    required this.value,
    this.detail,
  });

  final String title;
  final String? detail;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.type.titleSmall),
                if (detail case final String text)
                  Text(text, style: context.type.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Figures(value, style: context.type.titleSmall),
        ],
      ),
    ),
  );
}

/// How [held] became the base currency: at what rate, then each step of
/// it on its own line, from where and as of when; or that no rate converts
/// it.
String conversionDetail(
  AppLocalizations l,
  RateTable rates,
  Money held,
  Asset base,
) {
  final Decimal? rate = rates.rate(held.asset, base);
  if (rate == null) return l.ratesMissing(held.asset.code);
  return <String>[
    l.freeExplainHeldAt(
      moneyText(held, base: base),
      formatAmount(
        rate,
        base,
        base: base,
        decimals: rate < Decimal.fromInt(10) ? 4 : 2,
      ),
    ),
    ...rateStepLines(l, rates, held.asset, base),
  ].join('\n');
}
