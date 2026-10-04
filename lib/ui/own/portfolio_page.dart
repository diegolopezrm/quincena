import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../money/rates.dart';
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
import 'look.dart';
import 'portfolio_chart.dart';
import 'wallets_page.dart';

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

/// The last row of the Cripto section in Accounts: how the crypto did
/// against what it cost, a tap away from the whole of it. No total: the
/// rows above it already add up to that.
class CryptoPerformanceRow extends StatefulWidget {
  const CryptoPerformanceRow({super.key, required this.own});

  final OwnController own;

  @override
  State<CryptoPerformanceRow> createState() => _CryptoPerformanceRowState();
}

class _CryptoPerformanceRowState extends State<CryptoPerformanceRow> {
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
      final double? gain = _controller.portfolio?.gainRatio;
      return InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => PortfolioPage(own: widget.own),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Glyph.chartLineUp,
                    size: 20,
                    color: context.colors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.cryptoPerformanceRow,
                      style: context.type.titleSmall,
                    ),
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
              ),
              const SizedBox(width: 6),
              Icon(Glyph.caretRight, size: 18, color: context.colors.inkFaint),
            ],
          ),
        ),
      );
    },
  );
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

  /// Whether the chart draws what prices made (the default) or the value,
  /// which also moves with every purchase and sale.
  bool _performance = true;

  PortfolioController get _controller => widget.own.portfolio;

  @override
  void initState() {
    super.initState();
    _controller.watch();
    // Each of these tells its listeners as it starts: once this page is
    // built, not while it is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.loadChart(_range);
      if (BinanceLink.available) {
        widget.own.binance.syncIfOlder(const Duration(minutes: 30));
      }
      widget.own.wallets.syncIfOlder(const Duration(minutes: 30));
    });
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
        // When Binance or the wallets were read shows beside the coins.
        listenable: Listenable.merge(<Listenable>[
          _controller,
          widget.own.binance,
          widget.own.wallets,
        ]),
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
                    _ChartCard(
                      portfolio: p,
                      controller: _controller,
                      range: _range,
                      onRange: _pick,
                      performance: _performance,
                      onPerformance: (bool on) =>
                          setState(() => _performance = on),
                    ),
                    const SizedBox(height: 24),
                    for (final MapEntry<String, List<Holding>> place
                        in p.byInstitution.entries)
                      _Place(
                        own: widget.own,
                        name: place.key.isEmpty
                            ? l.portfolioOtherPlace
                            : place.key,
                        holdings: place.value,
                        base: p.base,
                      ),
                    const SizedBox(height: 4),
                    _Allocation(portfolio: p),
                    const SizedBox(height: 24),
                    // Where the balances come from, to connect or follow
                    // more: after what they show.
                    SectionLabel(l.portfolioSources),
                    Panel(
                      children: <Widget>[
                        if (BinanceLink.available)
                          BinanceCard(own: widget.own, compact: true),
                        WalletsRow(own: widget.own),
                      ],
                    ),
                    const SizedBox(height: 24),
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
    final Pair? gain = p.gain;
    final double? gainRatio = p.gainRatio;
    final Pair uncosted = p.uncostedValue;
    final ({Pair moved, double change})? day = controller.day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Headline(
          caption: l.portfolioWorth,
          value: moneyText(Money(p.value.base, base), base: base),
          // Dollars and coins share the page: the total says its currency.
          unit: base,
          detail: base.code == 'USD'
              ? null
              : moneyText(Money(p.value.usd, Asset.usd), base: base),
        ),
        const SizedBox(height: 6),
        _PriceStatus(controller: controller, base: base),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: day == null
                    ? _Figure(
                        label: l.portfolioToday,
                        value: l.portfolioNoData,
                        detail: controller.pricing
                            ? l.portfolioPricing
                            : l.portfolioNoData24h,
                      )
                    : _Figure(
                        label: l.portfolioToday,
                        value: moneyText(
                          Money(day.moved.base, base),
                          base: base,
                          signed: true,
                        ),
                        detail: l.portfolioDayDetail(percentText(day.change)),
                        // By the amount, as the chart colors it.
                        color: changeColor(context, day.moved.base.toDouble()),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Figure(
                  label: (gain?.base ?? Decimal.zero) >= Decimal.zero
                      ? l.portfolioGain
                      : l.portfolioLoss,
                  value: gain == null
                      ? l.portfolioNoData
                      : moneyText(
                          Money(gain.base, base),
                          base: base,
                          signed: true,
                        ),
                  detail: gainRatio == null
                      ? null
                      : '${percentText(gainRatio)} ${l.portfolioSinceBought}',
                  color: gain == null
                      ? null
                      : changeColor(context, gain.base.toDouble()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (uncosted.base > Decimal.zero)
          Text(
            l.portfolioGainUncosted(
              moneyText(Money(uncosted.base, base), base: base),
            ),
            style: context.type.bodySmall,
          ),
        Text(
          // It speaks of pesos, and of the dollar against the peso.
          base.code == 'COP'
              ? l.portfolioGainMeaning
              : l.portfolioGainMeaningPlain,
          style: context.type.bodySmall,
        ),
      ],
    );
  }
}

/// When the prices were read, and with which day's dollar they became the
/// base currency, with a way to read them again: pulling the page down is
/// not something everyone finds.
class _PriceStatus extends StatelessWidget {
  const _PriceStatus({required this.controller, required this.base});

  final PortfolioController controller;
  final Asset base;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final DateTime? at = controller.pricedAt;
    final bool reading = controller.pricing;
    // Prices that could not be read, or never were, are a warning; a read
    // that worked needs no light of its own.
    final bool warn = controller.pricingFailed || (at == null && !reading);
    final String status = reading && at == null
        ? l.portfolioPricing
        : controller.pricingFailed
        ? (at == null
              ? l.portfolioPricingFailed
              : l.portfolioPricingFailedAt(dayAndTime(at)))
        : at == null
        ? l.portfolioNeverPriced
        : l.portfolioPricedAt(dayAndTime(at));
    DateTime? trm;
    for (final Rate r in controller.own.rates.used(Asset.usd, base)) {
      if (r.source == 'trm') trm = r.asOf;
    }
    return Row(
      children: <Widget>[
        if (warn) ...<Widget>[
          Icon(Glyph.warningCircle, size: 16, color: context.colors.caution),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                liveRegion: warn,
                child: Text(status, style: context.type.bodySmall),
              ),
              if (trm != null)
                Text(
                  l.portfolioConvertedWith(dayShortMonth(trm)),
                  style: context.type.bodySmall,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: reading ? null : () => unawaited(controller.refresh()),
          icon: reading
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Glyph.arrowsClockwise, size: 18),
          label: Text(
            l.portfolioRefresh,
            semanticsLabel: l.portfolioRefreshLabel,
          ),
        ),
      ],
    );
  }
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
          Text(detail!, style: context.type.bodySmall?.copyWith(color: color)),
      ],
    ),
  );
}

/// The value over a range the person picks, with how much it moved, and
/// any moment of it under a finger.
class _ChartCard extends StatefulWidget {
  const _ChartCard({
    required this.portfolio,
    required this.controller,
    required this.range,
    required this.onRange,
    required this.performance,
    required this.onPerformance,
  });

  final Portfolio portfolio;
  final PortfolioController controller;
  final ChartRange range;
  final ValueChanged<ChartRange> onRange;

  /// Draw what prices made on what was held, from zero, rather than the
  /// value: a purchase lifts the value in one step, which reads as a rally.
  final bool performance;
  final ValueChanged<bool> onPerformance;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  /// The moment picked on the line, while a finger is on it.
  int? _touched;

  /// Whether the line was touched on this visit: the hint goes after.
  bool _tried = false;

  @override
  void didUpdateWidget(_ChartCard old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range || old.performance != widget.performance) {
      _touched = null;
    }
  }

  void _select(int? i) {
    if (i == _touched) return;
    setState(() {
      if (i == null) _tried = true;
      _touched = i;
    });
  }

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

  /// A moment of the line as the range reads it: the hour within a day,
  /// the day within a year, both in between.
  String _when(DateTime t) => switch (widget.range) {
    ChartRange.day => timeOfDay(t),
    ChartRange.year => dayShortMonth(t),
    _ => dayAndTime(t),
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Portfolio portfolio = widget.portfolio;
    final PortfolioController controller = widget.controller;
    final ChartRange range = widget.range;
    final bool performance = widget.performance;
    final Asset base = portfolio.base;
    // A chart that could not read some coin's prices would show it
    // standing still: none rather than that.
    final List<ValuePoint> points = controller.drewAll(range)
        ? controller.chart(range) ?? const <ValuePoint>[]
        : const <ValuePoint>[];
    // The last candle can be minutes old: the line ends at the value now,
    // when everything held has a price to count it with.
    final bool now = points.isNotEmpty && portfolio.unpriced.isEmpty;
    final List<double> worth = <double>[
      for (final ValuePoint v in points) v.value.base.toDouble(),
      if (now) portfolio.value.base.toDouble(),
    ];
    final List<double> values = performance
        ? <double>[for (final ValuePoint v in points) v.gain.base.toDouble()]
        : worth;
    // Each moment's own amount, as the header says it.
    Money amountAt(int i) => Money(
      (performance
              ? points[i].gain.base
              : i < points.length
              ? points[i].value.base
              : portfolio.value.base)
          .round(scale: base.decimals),
      base,
    );
    DateTime timeAt(int i) =>
        i < points.length ? points[i].at : controller.own.now();
    String describe(int i) => performance
        ? l.chartPointGain(
            _when(timeAt(i)),
            moneyText(amountAt(i), base: base, signed: true),
          )
        : l.chartPointValue(
            _when(timeAt(i)),
            moneyText(amountAt(i), base: base),
          );
    final double? first = worth.isEmpty ? null : worth.first;
    // What prices made over the range on what was held, not what was
    // bought or sold in it; as a fraction, step by step, so money put in
    // along the way does not read as a return.
    final ValuePoint? last = points.isEmpty ? null : points.last;
    final Pair made = last?.gain ?? Pair.zero;
    final double moved = made.base.toDouble();
    final double ratio = last?.ratio ?? 0;
    final String madeText = moneyText(
      Money(made.base.round(scale: base.decimals), base),
      base: base,
      signed: true,
    );
    final double changed = worth.isEmpty ? 0 : worth.last - worth.first;
    final bool flows =
        !performance &&
        first != null &&
        (changed - moved).abs() > (first.abs() * 0.01 + 1);
    final Color color = changeColor(context, moved);
    final int? touched = _touched != null && _touched! < values.length
        ? _touched
        : null;
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (touched != null)
            Text(describe(touched), style: context.type.titleSmall)
          else if (last != null)
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$madeText (${percentText(ratio)}) ',
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l.chartPerformance),
                ),
                ButtonSegment<bool>(value: false, label: Text(l.chartValue)),
              ],
              selected: <bool>{performance},
              onSelectionChanged: (Set<bool> s) =>
                  widget.onPerformance(s.first),
            ),
          ),
          const SizedBox(height: 12),
          if (values.length < 2)
            SizedBox(
              height: 168,
              child: controller.charting(range)
                  ? Semantics(
                      liveRegion: true,
                      label: l.chartLoading,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Skeleton(height: 120, radius: 12),
                          SizedBox(height: 8),
                          Skeleton(height: 10, width: 120),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(l.chartEmpty, style: context.type.bodySmall),
                    ),
            )
          else ...<Widget>[
            DrawIn(
              key: ValueKey<(ChartRange, bool)>((range, performance)),
              builder: (BuildContext context, double progress) =>
                  PortfolioChart(
                    values: values,
                    color: color,
                    progress: progress,
                    selected: touched,
                    onSelect: _select,
                    describe: describe,
                    semanticsLabel: performance
                        ? l.chartSemanticsGain(
                            _long(l, range),
                            madeText,
                            percentText(ratio),
                          )
                        : '${l.portfolioWorth} ${_long(l, range)}: '
                              '${percentText(ratio)}',
                    zero: performance,
                    zeroLabel: l.chartZero,
                    startLabel: range == ChartRange.day
                        ? timeOfDay(timeAt(0))
                        : dayShortMonth(timeAt(0)),
                    endLabel: l.chartNow,
                  ),
            ),
            if (!_tried) ...<Widget>[
              const SizedBox(height: 6),
              Text(l.chartTouchHint, style: context.type.bodySmall),
            ],
          ],
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
                      onTap: () => widget.onRange(r),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            !performance
                ? l.chartWithHoldings
                // Over a month or a year each day has its own dollar, so the
                // line also moves with it; within a week, today's.
                : base.code == 'USD' ||
                      range == ChartRange.day ||
                      range == ChartRange.week
                ? l.chartPerformanceNote
                : base.code == 'COP'
                ? l.chartPerformanceNoteFx
                : l.chartPerformanceNoteFxPlain,
            style: context.type.bodySmall,
          ),
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

/// Where [account]'s balance comes from, in words: written by hand, or
/// read from Binance or a public address, and when; or read there once and
/// not from here any more, with no key on this device or the address no
/// longer followed. Null while that is not known yet.
String? holdingSourceText(
  AppLocalizations l,
  OwnController own,
  Account account,
) => switch (HoldingSource.of(account)) {
  HoldingSource.manual => l.portfolioSourceManual,
  HoldingSource.binance when own.binance.connected =>
    switch (own.binance.syncedAt) {
      final DateTime at => l.portfolioSourceBinance(dayAndTime(at)),
      null => l.portfolioSourceBinanceNever,
    },
  HoldingSource.binance when own.binance.loaded => l.portfolioSourceBinanceOff,
  HoldingSource.wallet when own.wallets.follows(account) =>
    switch (own.wallets.syncedAt) {
      final DateTime at => l.portfolioSourceWallet(dayAndTime(at)),
      null => l.portfolioSourceWalletNever,
    },
  HoldingSource.wallet when own.wallets.loaded => l.portfolioSourceWalletOff,
  _ => null,
};

/// Whether [account]'s balance is read again by itself from here.
bool _updates(OwnController own, Account account) =>
    switch (HoldingSource.of(account)) {
      HoldingSource.binance => own.binance.connected,
      HoldingSource.wallet => own.wallets.follows(account),
      _ => false,
    };

/// The coins kept in one place, with where their balances come from: once
/// under the place's name when they all come the same way, on each coin
/// when not.
class _Place extends StatelessWidget {
  const _Place({
    required this.own,
    required this.name,
    required this.holdings,
    required this.base,
  });

  final OwnController own;
  final String name;
  final List<Holding> holdings;
  final Asset base;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Set<String?> sources = <String?>{
      for (final Holding h in holdings) holdingSourceText(l, own, h.account),
    };
    final String? shared = sources.length == 1 ? sources.single : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(name),
        if (shared != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _updates(own, holdings.first.account)
                        ? Glyph.arrowsClockwise
                        : HoldingSource.of(holdings.first.account) ==
                              HoldingSource.manual
                        ? Glyph.pencilSimple
                        : Glyph.pause,
                    size: 14,
                    color: context.colors.inkSoft,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(shared, style: context.type.bodySmall)),
              ],
            ),
          ),
        Panel(
          children: <Widget>[
            for (final Holding h in holdings)
              HoldingRow(
                own: own,
                holding: h,
                base: base,
                source: shared == null
                    ? holdingSourceText(l, own, h.account)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 20),
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
    this.source,
  });

  final OwnController own;
  final Holding holding;
  final Asset base;

  /// Where its balance comes from, when the place it is kept does not say
  /// it once for all its coins.
  final String? source;

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
                  if (source != null)
                    Text(source!, style: context.type.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Figures(
                  value == null
                      ? context.l10n.portfolioNoPrice
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
