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
import 'account_leaving.dart';
import 'account_page.dart';
import 'account_sheet.dart';
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
    // A card's debt in pesos too reads as owed, not as money of another sign.
    final Money? converted = account.asset == base
        ? null
        : own.inBase(
            account.kind == AccountKind.card ? balance.abs() : balance,
          );
    final bool card = account.kind == AccountKind.card;
    final Money? left = account.creditLeft(balance);
    final List<String> detail = <String>[
      // A card sits under its own heading, which already says what it is.
      if (!card || account.institution.isEmpty)
        accountKindLabel(context, account.kind),
      if (account.institution.isNotEmpty) account.institution,
    ];
    // With large text the row is read top to bottom, as iOS lays out its
    // own at those sizes: the tile, the name whole, then the amounts. Side
    // by side neither could be read whole.
    final bool large = largeText(context);
    final Widget tile = account.asset.isCrypto
        ? CoinMark(account.asset)
        : AccountTile(account.kind);
    final Widget names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          account.name,
          style: context.type.titleSmall,
          maxLines: large ? null : 1,
          overflow: large ? null : TextOverflow.ellipsis,
        ),
        Text(
          detail.join(' · '),
          style: context.type.bodySmall,
          maxLines: large ? null : 1,
          overflow: large ? null : TextOverflow.ellipsis,
        ),
      ],
    );
    final Widget amounts = Column(
      crossAxisAlignment: large
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
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
    );
    // Under the amount, across the whole row: at a large text size it
    // wraps rather than pushing the amount past the edge.
    final Widget? creditLeft = left == null
        ? null
        : Figures(
            context.l10n.cardCreditLeft(moneyText(left, base: base)),
            style: context.type.bodySmall,
            textAlign: large ? TextAlign.start : TextAlign.end,
          );
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AccountPage(own: own, accountId: account.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: large
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.stretch,
          children: <Widget>[
            if (large) ...<Widget>[
              tile,
              const SizedBox(height: 8),
              names,
              const SizedBox(height: 4),
              amounts,
            ] else
              Row(
                children: <Widget>[
                  tile,
                  const SizedBox(width: 12),
                  Expanded(child: names),
                  const SizedBox(width: 12),
                  amounts,
                ],
              ),
            ?creditLeft,
          ],
        ),
      ),
    );
  }
}

/// One line under the net worth: what the everyday accounts hold, or what
/// everyday cards owe.
class _SpendLine extends StatelessWidget {
  const _SpendLine({
    required this.label,
    required this.value,
    required this.base,
  });

  final String label;
  final Money value;
  final Asset base;

  @override
  Widget build(BuildContext context) {
    final Widget figure = Figures(
      moneyText(value, base: base),
      style: context.type.titleMedium,
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        // With large text the amount goes under what it is: beside it, the
        // words would have no room.
        child: largeText(context)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: context.type.bodyMedium),
                  figure,
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(child: Text(label, style: context.type.bodyMedium)),
                  figure,
                ],
              ),
      ),
    );
  }
}

/// Every account, grouped by what it is for: the net worth first, as what
/// the person has minus what they owe, then what the everyday accounts
/// hold and what everyday cards owe, the everyday accounts, the credit
/// cards as what is owed, savings and investments, crypto with its total
/// and a row to how it did, the way to add an account, and a line of the
/// rates behind the totals.
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
        if (!a.spendable && !card(a) && !a.asset.isCrypto) a,
    ];
    // Crypto in a section of its own, whose total is the sum of its rows,
    // as each converts: how it did is a row, never the total again.
    final List<Account> coins = <Account>[
      for (final Account a in own.accounts)
        if (!a.spendable && !card(a) && a.asset.isCrypto) a,
    ];
    var coinsTotal = Money.zero(base);
    for (final Account a in coins) {
      if (own.partOfTotal(a) case final Money part) coinsTotal += part;
    }
    final bool crypto = own.portfolio.hasHoldings;
    // What the money to spend starts from, as on the home card: what the
    // everyday accounts hold, and apart what everyday cards owe.
    var everyday = Money.zero(base);
    var cardDebt = Money.zero(base);
    for (final Account a in own.accounts) {
      if (!a.spendable) continue;
      if (own.partOfTotal(a) case final Money part) {
        if (card(a) && part.isNegative) {
          cardDebt += part;
        } else {
          everyday += part;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Headline(
          caption: l.netWorth,
          onExplain: () => showTotalExplained(context, own),
          value: moneyText(own.netWorth().total, base: base),
          // The code only where other currencies show beside it.
          unit: own.accounts.any((Account a) => a.asset != base) ? base : null,
          detail: l.netWorthDetail,
        ),
        const SizedBox(height: 12),
        _SpendLine(label: l.standingAvailable, value: everyday, base: base),
        if (cardDebt.isNegative)
          _SpendLine(
            label: l.standingCardDebtLine,
            value: cardDebt,
            base: base,
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
        if (kept.isNotEmpty) ...<Widget>[
          SectionLabel(l.groupSaved),
          Panel(
            children: <Widget>[
              for (final Account a in kept) AccountRow(own: own, account: a),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (crypto) ...<Widget>[
          SectionLabel(
            l.groupCrypto,
            trailing: coins.isEmpty
                ? null
                : Figures(
                    moneyText(coinsTotal, base: base),
                    style: context.type.titleSmall,
                  ),
          ),
          Panel(
            children: <Widget>[
              for (final Account a in coins) AccountRow(own: own, account: a),
              CryptoPerformanceRow(own: own),
            ],
          ),
          const SizedBox(height: 24),
        ] else if (BinanceLink.available) ...<Widget>[
          BinanceCard(own: own),
          const SizedBox(height: 24),
        ],
        OutlinedButton.icon(
          onPressed: () => showAccountSheet(context, own: own),
          icon: const Icon(Glyph.plus, size: 18),
          label: Text(l.addAccount),
        ),
        const SizedBox(height: 24),
        if (own.archivedAccounts.isNotEmpty) ...<Widget>[
          ArchivedAccountsRow(own: own),
          const SizedBox(height: 16),
        ],
        RatesSummary(own: own),
      ],
    );
  }
}

/// The rates behind the totals, folded into one row that opens them, with
/// how current they are. A rate shows on the tab only when one is missing.
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
    final List<Asset> missing = <Asset>[
      for (final Asset a in held)
        if (table.rate(a, base) == null) a,
    ];
    final Widget mark = Icon(
      Glyph.arrowsLeftRight,
      color: context.colors.brand,
    );
    final Widget name = Text(l.ratesSeeAll, style: context.type.titleSmall);
    return Panel(
      children: <Widget>[
        ListTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => RatesPage(own: own),
            ),
          ),
          // With large text the icon goes above the title, as in Plan.
          leading: largeText(context) ? null : mark,
          title: largeText(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[mark, const SizedBox(height: 4), name],
                )
              : name,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(ratesStatus(l, own), style: context.type.bodySmall),
              // In the panel: caution text is too faint on the canvas.
              if (missing.isNotEmpty)
                Text(
                  l.ratesMissing(missing.map((Asset a) => a.code).join(', ')),
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.caution,
                  ),
                ),
            ],
          ),
          trailing: Icon(
            Glyph.caretRight,
            size: 18,
            color: context.colors.inkFaint,
          ),
        ),
      ],
    );
  }
}

/// How current the rates are, and how many the person typed by hand, as
/// the lines under them.
String ratesStatus(AppLocalizations l, OwnController own) {
  final DateTime? fetched = own.ratesFetchedAt;
  final Asset? base = own.profile?.base;
  final RateTable table = own.rates;
  final int typed = base == null
      ? 0
      : <String>{
          for (final Account a in own.accounts)
            for (final Rate r in table.used(a.asset, base))
              if (r.manual) r.pair,
        }.length;
  final String? state = own.refreshingRates
      ? l.ratesRefresh
      : own.ratesFailed
      ? (fetched == null ? l.ratesFailed : l.ratesFailedAt(dayAndTime(fetched)))
      : fetched != null
      ? l.ratesUpdated(dayAndTime(fetched))
      // Rates typed by hand are rates too: not "none yet".
      : typed > 0
      ? null
      : l.ratesNever;
  return <String>[?state, if (typed > 0) l.ratesManualCount(typed)].join('\n');
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

/// The conversion of [asset] to [base], one leg per line, as a person
/// reads it: the market price of a coin, a stablecoin counted as a dollar,
/// and the rate that takes it to [base], each with where and when it comes
/// from. Each rate is written as its source gives it, with its currency
/// named, so a `$` beside pesos is never a dollar.
List<String> rateStepLines(
  AppLocalizations l,
  RateTable rates,
  Asset asset,
  Asset base,
) => <String>[
  for (final RateStep step in rates.steps(asset, base))
    _stepLine(l, step, base),
];

/// One leg of a conversion, as [rateStepLines] writes it.
String _stepLine(AppLocalizations l, RateStep step, Asset base) {
  final Rate? r = step.rate;
  if (r == null) {
    // Only a stablecoin and the dollar meet without a rate.
    return l.stablecoinPeg(step.from == 'USD' ? step.to : step.from);
  }
  final Asset one = Asset.of(r.asset);
  // English reads a currency's code, as the line above it does: `1 USD`.
  final String unit = one.isCrypto || englishFormatting
      ? one.code
      : one.symbol ?? one.code;
  final String value = formatAmount(
    r.value,
    Asset.of(r.quote),
    base: base,
    decimals: r.value < Decimal.fromInt(10) ? 4 : 2,
  );
  final String source = switch (r.source) {
    'trm' => l.rateSourceTrm,
    'binance' => l.rateSourceBinance,
    'ecb' => l.rateSourceEcb,
    _ => r.source,
  };
  return switch (step.kind) {
    RateStepKind.manual => l.rateStepManual(unit, value),
    RateStepKind.price => l.rateStepPrice(
      unit,
      value,
      source,
      dayAndTime(r.asOf),
    ),
    _ => l.rateStepConvert(step.to, unit, value, source, dayShortMonth(r.asOf)),
  };
}

/// What the rates are for, how current they are, and each rate the totals
/// use.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l.ratesIntro(base.code), style: context.type.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(ratesStatus(l, own), style: context.type.bodySmall),
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
        const SizedBox(height: 4),
        Block(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final Asset a in held)
                _RateLine(
                  own: own,
                  asset: a,
                  base: base,
                  rate: table.rate(a, base),
                ),
            ],
          ),
        ),
      ],
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

  /// The pair typed by hand is the one the person thinks in: dollars in
  /// pesos, bitcoin in dollars.
  Asset get _quote => asset.isCrypto && base.code != 'USD' ? Asset.usd : base;

  /// The rate the person typed for [asset], when the totals use one.
  Rate? get _typed => own.rates
      .used(asset, base)
      .where((Rate r) => r.manual && r.pair == '${asset.code}/${_quote.code}')
      .firstOrNull;

  Future<void> _edit(BuildContext context) async {
    final Asset quote = _quote;
    final _RateChoice? choice = await showDialog<_RateChoice>(
      context: context,
      builder: (BuildContext context) => _RateDialog(
        asset: asset,
        quote: quote,
        current: own.rates.rate(asset, quote),
        typedByHand: _typed != null,
      ),
    );
    if (choice == null) return;
    if (choice.restore) {
      if (context.mounted) await _restore(context);
      return;
    }
    final Decimal? typed = choice.typed;
    if (typed == null || typed <= Decimal.zero) return;
    await own.store.setManualRate(asset.code, quote.code, typed);
  }

  /// Back to the automatic rate, or a word that the typed one stays when
  /// the automatic one could not be fetched.
  Future<void> _restore(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String failed = context.l10n.rateRestoreFailed;
    if (!await own.restoreAutomaticRate(asset.code, _quote.code)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Decimal? r = rate;
    final Rate? typed = _typed;
    final Decimal? fetched = typed == null
        ? null
        : own.fetchedRate(asset, _quote);
    final List<String> steps = rateStepLines(l, own.rates, asset, base);
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Figures(
                        text,
                        style: context.type.bodyMedium?.copyWith(
                          color: r == null
                              ? context.colors.caution
                              : context.colors.ink,
                        ),
                      ),
                      if (typed != null) const _ManualTag(),
                    ],
                  ),
                  // A rate typed for the pair itself is the line above:
                  // its one step would only say it again.
                  if (typed == null || steps.length > 1)
                    for (final String step in steps)
                      Figures(step, style: context.type.bodySmall),
                  if (typed != null) ...<Widget>[
                    Text(
                      l.rateManualOn(dayShortMonth(typed.asOf)),
                      style: context.type.bodySmall,
                    ),
                    if (fetched != null)
                      Figures(
                        l.rateAutomaticNow(
                          formatAmount(
                            fetched,
                            _quote,
                            base: base,
                            decimals: fetched < Decimal.fromInt(10) ? 4 : 2,
                          ),
                        ),
                        style: context.type.bodySmall,
                      ),
                    TextButton(
                      // One way back at a time: it waits for any fetch.
                      onPressed: own.refreshingRates
                          ? null
                          : () => _restore(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(l.rateUseFetchedShort),
                    ),
                  ],
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

/// What the rate dialog ended in: a rate typed, or the way back to the
/// automatic one.
typedef _RateChoice = ({Decimal? typed, bool restore});

/// One unit of [asset] in [quote], typed by hand.
class _RateDialog extends StatefulWidget {
  const _RateDialog({
    required this.asset,
    required this.quote,
    required this.current,
    required this.typedByHand,
  });

  final Asset asset;
  final Asset quote;
  final Decimal? current;

  /// Whether the rate in use was typed by hand: only then is there an
  /// automatic one to go back to.
  final bool typedByHand;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final TextEditingController _value = TextEditingController(
    text: switch (widget.current) {
      null => '',
      final Decimal current => formatDecimal(
        current,
        decimals: widget.quote.decimals > 0 ? 6 : 2,
        trim: true,
      ),
    },
  );

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.rateEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.rateEditBody(widget.asset.code, widget.quote.code),
            style: context.type.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            autofocus: true,
            inputFormatters: <TextInputFormatter>[
              AmountInputFormatter(maxDecimals: 8),
            ],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: widget.quote.code),
          ),
        ],
      ),
      actions: <Widget>[
        if (widget.typedByHand)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop<_RateChoice>((typed: null, restore: true)),
            child: Text(l.rateUseFetched),
          ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop<_RateChoice>((typed: parseAmount(_value.text), restore: false)),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Says a rate was typed by hand, in a soft pill beside it.
class _ManualTag extends StatelessWidget {
  const _ManualTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: context.colors.cautionSoft,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      context.l10n.rateManualTag,
      style: context.type.labelSmall?.copyWith(color: context.colors.caution),
    ),
  );
}
