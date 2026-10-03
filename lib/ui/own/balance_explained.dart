import 'package:flutter/material.dart';

import '../../domain/account_trace.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../kit.dart';
import 'free_explained.dart';
import 'look.dart';

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: <Widget>[child],
        ),
      ),
    );

/// Shows how [account] got to its balance.
Future<void> showAccountExplained(
  BuildContext context,
  OwnController own,
  Account account,
) => _sheet(context, AccountExplained(own: own, account: account));

/// Shows how the accounts add up to the total.
Future<void> showTotalExplained(BuildContext context, OwnController own) =>
    _sheet(context, TotalExplained(own: own));

/// An account's balance taken apart: what it started with, what came in
/// and went out by kind, and, in another currency, the rate that converts
/// it.
class AccountExplained extends StatelessWidget {
  const AccountExplained({super.key, required this.own, required this.account});

  final OwnController own;
  final Account account;

  String _kind(AppLocalizations l, TracePart p) => switch (p.kind) {
    TraceKind.income => l.traceIncome(p.count),
    TraceKind.expense => l.traceExpense(p.count),
    TraceKind.transferIn => l.traceTransferIn(p.count),
    TraceKind.transferOut => l.traceTransferOut(p.count),
    TraceKind.bought => l.traceBought(p.count),
    TraceKind.sold => l.traceSold(p.count),
    TraceKind.adjustment => l.traceAdjustment(p.count),
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final AccountTrace t = traceAccount(
      account,
      own.snapshot?.entries ?? const <Entry>[],
      own.today,
    );
    String money(Money m) => moneyText(m, base: base, signed: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l.accountExplainTitle, style: context.type.headlineMedium),
        const SizedBox(height: 4),
        Text(account.name, style: context.type.bodyMedium),
        const SizedBox(height: 16),
        Block(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            children: <Widget>[
              ExplainSum(
                label: l.accountExplainOpening,
                value: moneyText(t.opening, base: base),
              ),
              for (final TracePart p in t.parts)
                ExplainSum(label: _kind(l, p), value: money(p.sum)),
              Divider(color: context.colors.line, height: 20),
              ExplainSum(
                label: l.accountExplainBalance,
                value: moneyText(t.balance, base: base),
                strong: true,
              ),
            ],
          ),
        ),
        if (base != null && account.asset != base) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            conversionDetail(l, own.rates, t.balance, base),
            style: context.type.bodyMedium,
          ),
        ],
        if (t.aheadCount > 0) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            l.accountExplainAhead(t.aheadCount, money(t.ahead)),
            style: context.type.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// The total taken apart: each account in the base currency, the rate
/// that converted it, and what has no rate yet.
class TotalExplained extends StatelessWidget {
  const TotalExplained({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    if (base == null) return const SizedBox.shrink();
    final List<Account> unpriced = <Account>[
      for (final Account a in own.accounts)
        if (own.partOfTotal(a) == null) a,
    ];
    // What the person has, and what they owe: an account below zero, a
    // credit card's debt.
    final List<(Account, Money)> have = <(Account, Money)>[];
    final List<(Account, Money)> owe = <(Account, Money)>[];
    for (final Account a in own.accounts) {
      if (own.partOfTotal(a) case final Money part) {
        (part.isNegative ? owe : have).add((a, part));
      }
    }
    Money sum(List<(Account, Money)> parts) => parts.fold(
      Money.zero(base),
      (Money total, (Account, Money) p) => total + p.$2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l.totalExplainTitle, style: context.type.headlineMedium),
        const SizedBox(height: 16),
        for (final (String title, List<(Account, Money)> parts)
            in <(String, List<(Account, Money)>)>[
              (l.totalExplainHave, have),
              (l.totalExplainOwe, owe),
            ])
          if (parts.isNotEmpty) ...<Widget>[
            SectionLabel(title),
            Panel(
              children: <Widget>[
                for (final (Account a, Money part) in parts)
                  ExplainLine(
                    title: a.name,
                    detail: a.asset == base
                        ? null
                        : conversionDetail(
                            l,
                            own.rates,
                            own.balances[a.id] ?? a.openingMoney,
                            base,
                          ),
                    value: moneyText(part, base: base),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        Block(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            children: <Widget>[
              if (owe.isNotEmpty) ...<Widget>[
                ExplainSum(
                  label: l.totalExplainHave,
                  value: moneyText(sum(have), base: base),
                ),
                ExplainSum(
                  label: l.totalExplainOwe,
                  value: moneyText(sum(owe), base: base),
                ),
              ],
              ExplainSum(
                label: l.netWorth,
                value: moneyText(own.total(), base: base),
                strong: true,
              ),
            ],
          ),
        ),
        if (unpriced.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            l.totalExplainUnpriced(
              unpriced.map((Account a) => a.name).join(', '),
            ),
            style: context.type.bodyMedium,
          ),
        ],
      ],
    );
  }
}
