import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/records.dart';
import '../../exchanges/binance_link.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../money/rates.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'account_page.dart';
import 'amount_input.dart';
import 'balance_explained.dart';
import 'look.dart';
import 'binance_page.dart';
import 'portfolio_page.dart';

/// What a credit card's balance means, in words: what is owed on it, what
/// is in the person's favor, or that it is paid off. A card's debt is not
/// money of a different sign but money owed.
String cardBalanceText(AppLocalizations l, Money balance, Asset? base) =>
    balance.isNegative
    ? l.cardOwed(moneyText(balance.abs(), base: base))
    : balance.isZero
    ? l.cardClear
    : l.cardInFavor(moneyText(balance, base: base));

/// One account: where it is, and what it holds in its own currency and in
/// the base one.
class AccountRow extends StatelessWidget {
  const AccountRow({super.key, required this.own, required this.account});

  final OwnController own;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final Money balance = own.balances[account.id] ?? account.openingMoney;
    final Asset? base = own.profile?.base;
    final Money? converted = account.asset == base ? null : own.inBase(balance);
    final bool card = account.kind == AccountKind.card;
    final List<String> detail = <String>[
      // A card sits under its own heading, which already says what it is.
      if (!card || account.institution.isEmpty)
        accountKindLabel(context, account.kind),
      if (account.institution.isNotEmpty) account.institution,
    ];
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AccountPage(own: own, accountId: account.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            if (account.asset.isCrypto)
              CoinMark(account.asset)
            else
              AccountTile(account.kind),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    account.name,
                    style: context.type.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    detail.join(' · '),
                    style: context.type.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (card && !balance.isZero)
                  Text(
                    balance.isNegative
                        ? context.l10n.cardOwedLabel
                        : context.l10n.cardInFavorLabel,
                    style: context.type.bodySmall,
                  ),
                Figures(
                  card && balance.isZero
                      ? context.l10n.cardClear
                      : moneyText(card ? balance.abs() : balance, base: base),
                  style: context.type.titleSmall?.copyWith(
                    color: balance.isNegative && !card
                        ? context.colors.negative
                        : context.colors.ink,
                  ),
                ),
                if (converted != null)
                  Figures(
                    '≈ ${moneyText(converted, base: base)}',
                    style: context.type.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Every account, grouped by what it is for: the net worth first, as what
/// the person has minus what they owe, then what is there to spend today,
/// the accounts to spend from, the credit cards as what is owed, savings
/// and investments, and a line of the rates behind the totals.
class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset base = own.profile?.base ?? Asset.cop;
    bool card(Account a) => a.kind == AccountKind.card;
    final List<Account> spend = <Account>[
      for (final Account a in own.accounts)
        if (a.spendable && !card(a)) a,
    ];
    final List<Account> cards = <Account>[
      for (final Account a in own.accounts)
        if (card(a)) a,
    ];
    final List<Account> kept = <Account>[
      for (final Account a in own.accounts)
        if (!a.spendable && !card(a)) a,
    ];
    final bool crypto = own.portfolio.hasHoldings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Headline(
          caption: l.netWorth,
          onExplain: () => showTotalExplained(context, own),
          value: moneyText(own.total(), base: base),
          detail: l.netWorthDetail,
        ),
        const SizedBox(height: 12),
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l.standingAvailable,
                    style: context.type.bodyMedium,
                  ),
                ),
                Figures(
                  moneyText(own.total(spendableOnly: true), base: base),
                  style: context.type.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (own.accounts.isEmpty)
          Text(l.noAccounts, style: context.type.bodyMedium),
        if (spend.isNotEmpty) ...<Widget>[
          SectionLabel(l.groupSpendable),
          Panel(
            children: <Widget>[
              for (final Account a in spend) AccountRow(own: own, account: a),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (cards.isNotEmpty) ...<Widget>[
          SectionLabel(l.groupCards),
          Panel(
            children: <Widget>[
              for (final Account a in cards) AccountRow(own: own, account: a),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (kept.isNotEmpty || crypto) ...<Widget>[
          SectionLabel(l.groupSaved),
          Panel(
            children: <Widget>[
              if (crypto) PortfolioCard(own: own, compact: true),
              for (final Account a in kept) AccountRow(own: own, account: a),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (!crypto && BinanceLink.available) ...<Widget>[
          BinanceCard(own: own),
          const SizedBox(height: 24),
        ],
        RatesSummary(own: own),
      ],
    );
  }
}

/// The rates behind the totals in one short line each, how current they
/// are, and the way to see where each comes from or type one by hand.
class RatesSummary extends StatelessWidget {
  const RatesSummary({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    if (base == null) return const SizedBox.shrink();
    final List<Asset> held = <Asset>{
      for (final Account a in own.accounts)
        if (a.asset != base) a.asset,
    }.toList();
    if (held.isEmpty) return const SizedBox.shrink();
    final RateTable table = own.rates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(l.ratesTitle),
        Panel(
          indent: 16,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final Asset a in held)
                        Figures(
                          '${a.code} ${shortRate(table.rate(a, base), base) ?? '—'}',
                          style: context.type.bodyMedium?.copyWith(
                            color: table.rate(a, base) == null
                                ? context.colors.caution
                                : context.colors.ink,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(ratesStatus(l, own), style: context.type.bodySmall),
                ],
              ),
            ),
            ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => RatesPage(own: own),
                ),
              ),
              title: Text(l.ratesSeeAll, style: context.type.bodyMedium),
              trailing: Icon(
                Glyph.caretRight,
                size: 18,
                color: context.colors.inkFaint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One unit of an asset in [base], short enough to read at a glance:
/// `$3.312,84` for a dollar, `$280,3 M` for a bitcoin. Null without a rate.
String? shortRate(Decimal? rate, Asset base) {
  if (rate == null) return null;
  if (rate >= Decimal.fromInt(1000000) && base == Asset.cop) {
    return pesosShort(rate.toDouble());
  }
  return formatAmount(
    rate,
    base,
    base: base,
    decimals: rate < Decimal.fromInt(10) ? 4 : 2,
  );
}

/// How current the rates are, as a line under them.
String ratesStatus(AppLocalizations l, OwnController own) {
  final DateTime? fetched = own.ratesFetchedAt;
  return own.refreshingRates
      ? l.ratesRefresh
      : own.ratesFailed
      ? (fetched == null ? l.ratesFailed : l.ratesFailedAt(dayAndTime(fetched)))
      : fetched == null
      ? l.ratesNever
      : l.ratesUpdated(dayAndTime(fetched));
}

/// Every rate the totals use, where each comes from, and the way to type
/// one by hand or go back to the fetched one.
class RatesPage extends StatelessWidget {
  const RatesPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) => Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(context.l10n.ratesTitle, style: context.type.titleLarge),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[RatesPanel(own: own)],
          ),
        ),
      ),
    ),
  );
}

/// Where the rates converting [asset] to [base] come from, as a person
/// knows them: `TRM`, `Binance`, or typed by hand.
String rateSources(
  AppLocalizations l,
  RateTable rates,
  Asset asset,
  Asset base,
) {
  final List<Rate> used = rates.used(asset, base);
  if (used.any((Rate r) => r.manual)) return l.rateManual;
  final List<String> names = <String>[
    for (final Rate r in used)
      switch (r.source) {
        'trm' => l.rateSourceTrm,
        'binance' => l.rateSourceBinance,
        'ecb' => l.rateSourceEcb,
        _ => r.source,
      },
  ];
  if (asset.code == 'USDT' || asset.code == 'USDC') {
    names.insert(0, l.stablecoinPeg(asset.code));
  }
  return names.toSet().join(' · ');
}

/// How current the conversions are, and each rate the totals use.
class RatesPanel extends StatelessWidget {
  const RatesPanel({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    if (base == null) return const SizedBox.shrink();
    final Set<Asset> held = <Asset>{
      for (final Account a in own.accounts)
        if (a.asset != base) a.asset,
    };
    if (held.isEmpty) return const SizedBox.shrink();
    final RateTable table = own.rates;
    final String status = ratesStatus(l, own);
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.ratesTitle, style: context.type.titleSmall),
                    Text(status, style: context.type.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.ratesRefresh,
                onPressed: own.refreshingRates
                    ? null
                    : () => own.refreshRates(force: true),
                icon: own.refreshingRates
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Glyph.arrowCounterClockwise, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final Asset a in held)
            _RateLine(
              own: own,
              asset: a,
              base: base,
              rate: table.rate(a, base),
            ),
        ],
      ),
    );
  }
}

class _RateLine extends StatelessWidget {
  const _RateLine({
    required this.own,
    required this.asset,
    required this.base,
    required this.rate,
  });

  final OwnController own;
  final Asset asset;
  final Asset base;
  final Decimal? rate;

  String _sources(AppLocalizations l) => rateSources(l, own.rates, asset, base);

  Future<void> _edit(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    // The pair typed by hand is the one the person thinks in: dollars in
    // pesos, bitcoin in dollars.
    final Asset quote = asset.isCrypto && base.code != 'USD' ? Asset.usd : base;
    final Decimal? current = own.rates.rate(asset, quote);
    final TextEditingController value = TextEditingController(
      text: current == null
          ? ''
          : formatDecimal(
              current,
              decimals: quote.decimals > 0 ? 6 : 2,
              trim: true,
            ),
    );
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.rateEdit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l.rateEditBody(asset.code, quote.code),
              style: context.type.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: value,
              autofocus: true,
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: 8),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(suffixText: quote.code),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l.rateUseFetched),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(value.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    value.dispose();
    if (typed == null) return;
    final Decimal? parsed = typed.isEmpty ? null : parseAmount(typed);
    if (typed.isNotEmpty && (parsed == null || parsed <= Decimal.zero)) return;
    await own.store.setManualRate(asset.code, quote.code, parsed);
    if (parsed == null) await own.refreshRates(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Decimal? r = rate;
    final String text = r == null
        ? l.ratesMissing(asset.code)
        : '1 ${asset.code} = ${formatAmount(r, base, base: base, decimals: r < Decimal.fromInt(10) ? 4 : 2)}';
    return InkWell(
      onTap: () => _edit(context),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Figures(
                    text,
                    style: context.type.bodyMedium?.copyWith(
                      color: r == null
                          ? context.colors.caution
                          : context.colors.ink,
                    ),
                  ),
                  if (r != null)
                    Text(_sources(l), style: context.type.bodySmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Glyph.pencilSimple,
                size: 16,
                color: context.colors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
