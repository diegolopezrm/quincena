import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../portfolio/cost_basis.dart';
import '../../portfolio/market.dart';
import '../../portfolio/portfolio.dart';
import '../../portfolio/portfolio_controller.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../charts.dart';
import '../icons.dart';
import '../kit.dart';
import '../../exchanges/binance_link.dart';
import 'account_page.dart';
import 'binance_page.dart';
import 'wallets_page.dart';
import 'look.dart';

/// [fraction] as a percentage: `+1,2 %` in Spanish, `+1.2%` in English.
String percentText(double fraction, {bool signed = true}) {
  final double value = fraction * 100;
  final bool en = englishFormatting;
  final String digits = value.abs() >= 100
      ? value.abs().toStringAsFixed(0)
      : value.abs().toStringAsFixed(value.abs() >= 10 ? 1 : 2);
  final String number = en ? digits : digits.replaceAll('.', ',');
  final String sign = !signed || value.abs() < 0.005
      ? ''
      : (value > 0 ? '+' : '−');
  return en ? '$sign$number%' : '$sign$number %';
}

/// The color of a change: up, down or flat.
Color changeColor(BuildContext context, num change) => change > 0
    ? context.colors.positive
    : change < 0
    ? context.colors.negative
    : context.colors.inkSoft;

/// A coin's own color, the one its project uses, so it reads the same in
/// the chart, the list and the account.
Color coinColor(BuildContext context, Asset asset) {
  const Map<String, Color> known = <String, Color>{
    'BTC': Color(0xFFF7931A),
    'ETH': Color(0xFF627EEA),
    'USDT': Color(0xFF26A17B),
    'USDC': Color(0xFF2775CA),
    'BNB': Color(0xFFE0A100),
    'SOL': Color(0xFF9945FF),
    'XRP': Color(0xFF3D8BD8),
    'ADA': Color(0xFF2A6FDB),
    'DOGE': Color(0xFFC2A633),
  };
  final Color? own = known[asset.code];
  if (own != null) return own;
  final List<Color> palette = context.colors.categories.values.toList();
  final int hash = asset.code.codeUnits.fold(0, (int s, int c) => s * 31 + c);
  return palette[hash.abs() % palette.length];
}

/// A coin's mark: its symbol where the icons have one, its ticker
/// otherwise, on a soft disc of its color.
class CoinMark extends StatelessWidget {
  const CoinMark(this.asset, {super.key, this.size = 40});

  final Asset asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = coinColor(context, asset);
    final IconData? icon = switch (asset.code) {
      'BTC' => Glyph.currencyBtc,
      'ETH' => Glyph.currencyEth,
      _ => null,
    };
    final String letters = asset.code.length <= 4
        ? asset.code
        : asset.code.substring(0, 4);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: icon != null
            ? Icon(icon, size: size * 0.52, color: color)
            : FittedBox(
                child: Padding(
                  padding: EdgeInsets.all(size * 0.18),
                  child: Text(
                    letters,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.3,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// What the person's crypto is worth now: in the Accounts tab, above the
/// accounts, and a tap away from the whole portfolio.
class PortfolioCard extends StatefulWidget {
  const PortfolioCard({super.key, required this.own});

  final OwnController own;

  @override
  State<PortfolioCard> createState() => _PortfolioCardState();
}

class _PortfolioCardState extends State<PortfolioCard> {
  PortfolioController get _controller => widget.own.portfolio;

  @override
  void initState() {
    super.initState();
    _controller.watch();
  }

  @override
  void dispose() {
    _controller.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Portfolio? p = _controller.portfolio;
      if (p == null || p.isEmpty) return const SizedBox.shrink();
      final Asset base = p.base;
      final double? day = p.change24h;
      final double? gain = p.gainRatio;
      return Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => PortfolioPage(own: widget.own),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: <Widget>[
                _Stack(
                  assets: <Asset>[
                    for (final (Asset a, Pair _) in p.allocation.take(3)) a,
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.portfolioTitle, style: context.type.titleSmall),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Figures(
                          moneyText(Money(p.value.base, base), base: base),
                          style: context.type.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (day != null)
                            _ChangePill(fraction: day, label: l.rangeDay),
                          if (gain != null)
                            Text(
                              '${gain >= 0 ? l.portfolioGain : l.portfolioLoss} '
                              '${percentText(gain)}',
                              style: context.type.bodySmall?.copyWith(
                                color: changeColor(context, gain),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Glyph.caretRight,
                  size: 18,
                  color: context.colors.inkFaint,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Up to three coin marks, overlapping.
class _Stack extends StatelessWidget {
  const _Stack({required this.assets});

  final List<Asset> assets;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const CoinMark(Asset.btc);
    const double size = 34;
    return SizedBox(
      width: size + (assets.length - 1) * 16,
      height: size,
      child: Stack(
        children: <Widget>[
          for (var i = assets.length - 1; i >= 0; i--)
            Positioned(
              left: i * 16.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 2),
                  color: context.colors.surface,
                ),
                child: CoinMark(assets[i], size: size - 4),
              ),
            ),
        ],
      ),
    );
  }
}

/// A change in a soft pill of its color, with what it measures above.
class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.fraction, required this.label});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = changeColor(context, fraction);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            fraction >= 0 ? Glyph.trendUp : Glyph.trendDown,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Figures(
            '${percentText(fraction)} $label',
            style: context.type.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Everything the person holds in crypto: what it is worth now, how it
/// moved, what it cost and where it is kept.
class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key, required this.own});

  final OwnController own;

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  ChartRange _range = ChartRange.week;

  PortfolioController get _controller => widget.own.portfolio;

  @override
  void initState() {
    super.initState();
    _controller.watch();
    _controller.loadChart(_range);
    if (BinanceLink.available) {
      widget.own.binance.syncIfOlder(const Duration(minutes: 30));
    }
    widget.own.wallets.syncIfOlder(const Duration(minutes: 30));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.own.binance.labels = binanceLabels(context.l10n);
  }

  @override
  void dispose() {
    _controller.unwatch();
    super.dispose();
  }

  void _pick(ChartRange range) {
    setState(() => _range = range);
    _controller.loadChart(range);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.portfolioTitle, style: context.type.titleLarge),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, _) {
          final Portfolio? p = _controller.portfolio;
          if (p == null) return const SizedBox.shrink();
          if (p.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.portfolioEmpty, style: context.type.bodyMedium),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await _controller.refresh();
              await _controller.loadChart(_range);
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: <Widget>[
                    _Hero(portfolio: p, controller: _controller),
                    const SizedBox(height: 20),
                    if (BinanceLink.available) ...<Widget>[
                      BinanceCard(own: widget.own),
                      const SizedBox(height: 12),
                    ],
                    WalletsCard(own: widget.own),
                    const SizedBox(height: 16),
                    _ChartCard(
                      portfolio: p,
                      controller: _controller,
                      range: _range,
                      onRange: _pick,
                    ),
                    const SizedBox(height: 24),
                    _Allocation(portfolio: p),
                    const SizedBox(height: 24),
                    for (final MapEntry<String, List<Holding>> place
                        in p.byInstitution.entries) ...<Widget>[
                      SectionLabel(
                        place.key.isEmpty ? l.portfolioOtherPlace : place.key,
                      ),
                      Panel(
                        children: <Widget>[
                          for (final Holding h in place.value)
                            HoldingRow(
                              own: widget.own,
                              holding: h,
                              base: p.base,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    _Notes(portfolio: p),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The value now, in the base currency and in dollars, with how it moved
/// today and against what it cost.
class _Hero extends StatelessWidget {
  const _Hero({required this.portfolio, required this.controller});

  final Portfolio portfolio;
  final PortfolioController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Portfolio p = portfolio;
    final Asset base = p.base;
    final DateTime? at = controller.pricedAt;
    final String status = controller.pricing && at == null
        ? l.portfolioPricing
        : controller.pricingFailed
        ? l.portfolioPricingFailed
        : at == null
        ? l.portfolioNeverPriced
        : l.portfolioPricedAt(timeOfDay(at));
    final Pair gain = p.gain;
    final double? gainRatio = p.gainRatio;
    final double? day = p.change24h;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Headline(
          caption: l.portfolioWorth,
          value: moneyText(Money(p.value.base, base), base: base),
          detail: base.code == 'USD'
              ? null
              : moneyText(Money(p.value.usd, Asset.usd), base: base),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _LiveDot(active: controller.pricing),
            const SizedBox(width: 6),
            Expanded(child: Text(status, style: context.type.bodySmall)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: _Figure(
                label: l.portfolioToday,
                value: day == null
                    ? '—'
                    : moneyText(
                        Money(p.moved24h.base, base),
                        base: base,
                        signed: true,
                      ),
                detail: day == null ? null : percentText(day),
                color: day == null ? null : changeColor(context, day),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Figure(
                label: gain.base >= Decimal.zero
                    ? l.portfolioGain
                    : l.portfolioLoss,
                value: moneyText(
                  Money(gain.base, base),
                  base: base,
                  signed: true,
                ),
                detail: gainRatio == null
                    ? l.portfolioSinceBought
                    : '${percentText(gainRatio)} ${l.portfolioSinceBought}',
                color: changeColor(context, gain.base.toDouble()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A pulsing dot while prices are being read.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? context.colors.caution : context.colors.positive,
    ),
  );
}

/// One figure in a box: what it is, the amount, and a detail under it.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.detail,
    this.color,
  });

  final String label;
  final String value;
  final String? detail;
  final Color? color;

  @override
  Widget build(BuildContext context) => Block(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.type.labelMedium),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Figures(
            value,
            style: context.type.titleMedium?.copyWith(color: color),
          ),
        ),
        if (detail != null)
          Text(
            detail!,
            style: context.type.bodySmall?.copyWith(color: color),
            maxLines: 3,
          ),
      ],
    ),
  );
}

/// The value over a range the person picks, with how much it moved.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.portfolio,
    required this.controller,
    required this.range,
    required this.onRange,
  });

  final Portfolio portfolio;
  final PortfolioController controller;
  final ChartRange range;
  final ValueChanged<ChartRange> onRange;

  String _short(AppLocalizations l, ChartRange r) => switch (r) {
    ChartRange.day => l.rangeDay,
    ChartRange.week => l.rangeWeek,
    ChartRange.month => l.rangeMonth,
    ChartRange.year => l.rangeYear,
  };

  String _long(AppLocalizations l, ChartRange r) => switch (r) {
    ChartRange.day => l.rangeDayLong,
    ChartRange.week => l.rangeWeekLong,
    ChartRange.month => l.rangeMonthLong,
    ChartRange.year => l.rangeYearLong,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset base = portfolio.base;
    final List<ValuePoint>? points = controller.chart(range);
    // The last candle can be minutes old: the line ends at the value now,
    // when everything held has a price to count it with.
    final List<double> values = <double>[
      for (final ValuePoint v in points ?? const <ValuePoint>[])
        v.value.base.toDouble(),
      if (points != null && points.isNotEmpty && portfolio.unpriced.isEmpty)
        portfolio.value.base.toDouble(),
    ];
    final double? first = values.isEmpty ? null : values.first;
    // What prices made over the range on what was held, not what was
    // bought or sold in it.
    final Pair made = points == null || points.isEmpty
        ? Pair.zero
        : points.last.gain;
    final double moved = made.base.toDouble();
    final double changed = values.isEmpty ? 0 : values.last - values.first;
    final bool flows =
        first != null && (changed - moved).abs() > (first.abs() * 0.01 + 1);
    final Color color = changeColor(context, moved);
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (first != null && first > 0)
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text:
                        '${moneyText(Money(made.base.round(scale: base.decimals), base), base: base, signed: true)} '
                        '(${percentText(moved / first)}) ',
                    style: context.type.titleSmall?.copyWith(color: color),
                  ),
                  TextSpan(
                    text: _long(l, range),
                    style: context.type.bodySmall,
                  ),
                ],
              ),
            ),
          if (flows) Text(l.chartWithoutTrades, style: context.type.bodySmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: values.length < 2
                ? Center(
                    child: controller.charting(range)
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.chartEmpty, style: context.type.bodySmall),
                  )
                : Semantics(
                    label:
                        '${l.portfolioWorth} ${_long(l, range)}: '
                        '${percentText(first! > 0 ? moved / first : 0)}',
                    child: DrawIn(
                      key: ValueKey<ChartRange>(range),
                      builder: (BuildContext context, double progress) =>
                          CustomPaint(
                            painter: LinePainter(
                              values: values,
                              color: color,
                              progress: progress,
                            ),
                          ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.colors.sunken,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                for (final ChartRange r in ChartRange.values)
                  Expanded(
                    child: _RangeTab(
                      label: _short(l, r),
                      selected: range == r,
                      onTap: () => onRange(r),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(l.chartWithHoldings, style: context.type.bodySmall),
        ],
      ),
    );
  }
}

/// One of the chart's ranges, as a tab.
class _RangeTab extends StatelessWidget {
  const _RangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? context.colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: context.type.labelMedium?.copyWith(
              color: selected ? context.colors.ink : context.colors.inkSoft,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    ),
  );
}

/// How the value splits between coins.
class _Allocation extends StatelessWidget {
  const _Allocation({required this.portfolio});

  final Portfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final List<(Asset, Pair)> all = portfolio.allocation;
    final Decimal total = portfolio.value.base;
    if (all.isEmpty || total <= Decimal.zero) return const SizedBox.shrink();
    // Five slices at most; the rest together.
    final List<(Asset?, Decimal)> slices = <(Asset?, Decimal)>[
      for (final (Asset a, Pair v) in all.take(all.length > 5 ? 4 : 5))
        (a, v.base),
      if (all.length > 5)
        (
          null,
          all
              .skip(4)
              .fold(
                Decimal.zero,
                (Decimal s, (Asset, Pair) e) => s + e.$2.base,
              ),
        ),
    ];
    Color colorOf(Asset? a) =>
        a == null ? context.colors.inkFaint : coinColor(context, a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(l.portfolioAllocation),
        Block(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final Widget donut = SizedBox.square(
                dimension: 108,
                child: DrawIn(
                  builder: (BuildContext context, double progress) =>
                      CustomPaint(
                        painter: DonutPainter(
                          segments: <DonutSegment>[
                            for (final (Asset? a, Decimal v) in slices)
                              DonutSegment(v.toDouble(), colorOf(a)),
                          ],
                          track: context.colors.sunken,
                          thickness: 16,
                          progress: progress,
                        ),
                      ),
                ),
              );
              final Widget legend = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final (Asset? a, Decimal v) in slices)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colorOf(a),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a?.code ?? l.portfolioOtherAssets,
                              style: context.type.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Figures(
                            percentText(
                              (v / total)
                                  .toDecimal(scaleOnInfinitePrecision: 6)
                                  .toDouble(),
                              signed: false,
                            ),
                            style: context.type.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              );
              // Beside the ring where there is room, under it where not.
              if (box.maxWidth < 300) {
                return Column(
                  children: <Widget>[donut, const SizedBox(height: 14), legend],
                );
              }
              return Row(
                children: <Widget>[
                  donut,
                  const SizedBox(width: 18),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One investment account: the coin, how much, what it is worth and how it
/// did.
class HoldingRow extends StatelessWidget {
  const HoldingRow({
    super.key,
    required this.own,
    required this.holding,
    required this.base,
  });

  final OwnController own;
  final Holding holding;
  final Asset base;

  @override
  Widget build(BuildContext context) {
    final String lang = Localizations.localeOf(context).languageCode;
    final Holding h = holding;
    final Pair? value = h.value;
    final double? day = h.change24h;
    final double? gain = h.gainRatio;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AccountPage(own: own, accountId: h.account.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            CoinMark(h.asset),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    h.asset.name(lang),
                    style: context.type.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: moneyText(
                            Money(h.position.quantity, h.asset),
                            base: base,
                          ),
                        ),
                        if (day != null) ...<InlineSpan>[
                          const TextSpan(text: ' · '),
                          TextSpan(
                            text:
                                '${percentText(day)} ${context.l10n.rangeDay}',
                            style: TextStyle(color: changeColor(context, day)),
                          ),
                        ],
                      ],
                    ),
                    style: context.type.bodySmall?.copyWith(
                      fontFeatures: tabular,
                    ),
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
                  value == null
                      ? '—'
                      : moneyText(Money(value.base, base), base: base),
                  style: context.type.titleSmall,
                ),
                if (gain != null)
                  Figures(
                    percentText(gain),
                    style: context.type.bodySmall?.copyWith(
                      color: changeColor(context, gain),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the figures leave out or assume, said plainly.
class _Notes extends StatelessWidget {
  const _Notes({required this.portfolio});

  final Portfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Portfolio p = portfolio;
    final Asset base = p.base;
    final List<String> uncosted = <String>[
      for (final Holding h in p.holdings)
        if (h.position.uncosted > Decimal.zero)
          moneyText(Money(h.position.uncosted, h.asset), base: base),
    ];
    final List<String> notes = <String>[
      if (p.realized.base != Decimal.zero)
        p.realized.base > Decimal.zero
            ? l.portfolioRealized(
                moneyText(Money(p.realized.base, base), base: base),
              )
            : l.portfolioRealizedLoss(
                moneyText(Money(-p.realized.base, base), base: base),
              ),
      if (uncosted.isNotEmpty) l.portfolioUncosted(uncosted.join(', ')),
      if (p.unpriced.isNotEmpty)
        l.portfolioUnpriced(
          p.unpriced.map((Asset a) => a.code).toSet().join(', '),
        ),
      l.portfolioDisclaimer,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Glyph.info,
                      size: 14,
                      color: context.colors.inkFaint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(n, style: context.type.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
