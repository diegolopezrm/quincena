import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/records.dart';
import '../../exchanges/binance_link.dart';
import '../../format/dates.dart';
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
import 'look.dart';
import 'binance_page.dart';
import 'portfolio_page.dart';

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
    final List<String> detail = <String>[
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
                Figures(
                  moneyText(balance, base: base),
                  style: context.type.titleSmall?.copyWith(
                    color: balance.isNegative
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

/// Every account, what they hold together, and the rates behind the total.
class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset base = own.profile?.base ?? Asset.cop;
    final List<Account> spend = <Account>[
      for (final Account a in own.accounts)
        if (a.spendable) a,
    ];
    final List<Account> kept = <Account>[
      for (final Account a in own.accounts)
        if (!a.spendable) a,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Headline(
          caption: l.netWorth,
          value: moneyText(own.total(), base: base),
          detail:
              '${l.groupSpendable}: ${moneyText(own.total(spendableOnly: true), base: base)}',
        ),
        const SizedBox(height: 20),
        if (own.portfolio.hasHoldings) ...<Widget>[
          PortfolioCard(own: own),
          const SizedBox(height: 16),
        ] else if (BinanceLink.available) ...<Widget>[
          BinanceCard(own: own),
          const SizedBox(height: 16),
        ],
        RatesPanel(own: own),
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
        if (kept.isNotEmpty) ...<Widget>[
          SectionLabel(l.groupSaved),
          Panel(
            children: <Widget>[
              for (final Account a in kept) AccountRow(own: own, account: a),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
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
    final DateTime? fetched = own.ratesFetchedAt;
    final String status = own.refreshingRates
        ? l.ratesRefresh
        : own.ratesFailed
        ? l.ratesFailed
        : fetched == null
        ? l.ratesNever
        : l.ratesUpdated(dayAndTime(fetched));
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

  String _sources(AppLocalizations l) {
    final List<Rate> used = own.rates.used(asset, base);
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
