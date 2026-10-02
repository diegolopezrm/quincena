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

/// Shows how the money free until payday is worked out.
Future<void> showFreeExplained(BuildContext context, OwnController own) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (BuildContext context) => FreeExplained(own: own),
    );

/// The free amount taken apart: what each spendable account holds today
/// and the rate that converted it, what is committed before payday, and
/// what the figure leaves out.
///
/// Every amount comes from the ledger's own arithmetic, so the parts add up
/// to the figure on the home screen.
class FreeExplained extends StatelessWidget {
  const FreeExplained({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = own.ledger;
    final Asset? base = own.profile?.base;
    if (ledger == null || base == null) return const SizedBox.shrink();
    String amount(int minor) => pesos(ledger.major(minor));
    final List<Account> spendable = <Account>[
      for (final Account a in own.accounts)
        if (a.spendable && !a.archived) a,
    ];
    final List<Account> leftOut = <Account>[
      for (final Account a in own.accounts)
        if (!a.spendable && !a.archived) a,
    ];
    final List<Movement> committed = ledger.committed;
    final Set<Asset> unpriced = own.unconverted;

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
                _Sum(
                  label: l.freeExplainSpendable,
                  value: amount(ledger.balance),
                ),
                _Sum(
                  label: l.freeExplainCommitted,
                  value: amount(-ledger.committedUntilPayday),
                ),
                Divider(color: context.colors.line, height: 20),
                _Sum(
                  label: l.freeUntil(dayMonth(ledger.nextPayday)),
                  value: amount(ledger.freeUntilPayday),
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionLabel(l.freeExplainSpendable),
          Panel(
            children: <Widget>[
              for (final Account a in spendable)
                _AccountPart(
                  own: own,
                  account: a,
                  base: base,
                  value: amount(own.spendableParts[a.id] ?? 0),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SectionLabel(l.freeExplainCommitted),
          if (committed.isEmpty)
            Text(l.freeExplainNothingCommitted, style: context.type.bodyMedium)
          else
            Panel(
              children: <Widget>[
                for (final Movement m in committed)
                  _Line(
                    title: m.merchant,
                    detail: dayShortMonth(m.date),
                    value: amount(-m.amount),
                  ),
              ],
            ),
          if (leftOut.isNotEmpty || unpriced.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            SectionLabel(l.freeExplainLeftOut),
            if (leftOut.isNotEmpty)
              Text(
                l.freeExplainLeftOutBody(
                  leftOut.map((Account a) => a.name).join(', '),
                ),
                style: context.type.bodyMedium,
              ),
            if (unpriced.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l.freeExplainUnpriced(
                  unpriced.map((Asset a) => a.code).join(', '),
                ),
                style: context.type.bodyMedium,
              ),
            ],
          ],
          const SizedBox(height: 24),
          Text(l.freeExplainEstimate, style: context.type.bodySmall),
        ],
      ),
    );
  }
}

/// One line of the sum.
class _Sum extends StatelessWidget {
  const _Sum({required this.label, required this.value, this.strong = false});

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
    final RateTable rates = own.rates;
    String? detail;
    if (account.asset != base) {
      final Decimal? rate = rates.rate(account.asset, base);
      if (rate == null) {
        detail = l.ratesMissing(account.asset.code);
      } else {
        final List<Rate> used = rates.used(account.asset, base);
        detail = <String>[
          l.freeExplainHeldAt(
            moneyText(held, base: base),
            formatAmount(
              rate,
              base,
              base: base,
              decimals: rate < Decimal.fromInt(10) ? 4 : 2,
            ),
          ),
          rateSources(l, rates, account.asset, base),
          if (used.isNotEmpty)
            l.freeExplainRateOf(dayShortMonth(used.first.asOf)),
        ].join(' · ');
      }
    }
    return _Line(title: account.name, detail: detail, value: value);
  }
}

/// A name, what explains it, and an amount.
class _Line extends StatelessWidget {
  const _Line({required this.title, required this.value, this.detail});

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
