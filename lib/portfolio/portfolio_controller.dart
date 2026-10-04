import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../domain/records.dart';
import '../money/asset.dart';
import '../money/rates.dart';
import '../own/own_controller.dart';
import '../store/store.dart';
import 'cost_basis.dart';
import 'market.dart';
import 'portfolio.dart';

/// The person's crypto, priced as it moves.
///
/// Prices come from Binance's public market data when a screen that shows
/// them is open, every [every]; the latest are also saved as the app's
/// rates, so every total in the app agrees with the portfolio. Past dollar
/// rates are kept on the device, so what a coin cost in dollars is read
/// once and never asked again.
class PortfolioController extends ChangeNotifier {
  PortfolioController(
    this.own, {
    MarketData? market,
    this.every = const Duration(seconds: 30),
  }) : _market = market ?? MarketData() {
    own.addListener(_ownChanged);
  }

  final OwnController own;
  final MarketData _market;

  /// How often prices are read while someone is looking.
  final Duration every;

  Map<String, Ticker> _tickers = const <String, Ticker>{};
  DateTime? _pricedAt;
  bool _pricing = false;
  bool _pricingFailed = false;
  DollarHistory _history = DollarHistory(const <Rate>[]);
  bool _historyLoaded = false;
  Portfolio? _portfolio;
  int _watchers = 0;
  Timer? _timer;
  bool _disposed = false;

  final Map<ChartRange, List<ValuePoint>> _charts =
      <ChartRange, List<ValuePoint>>{};
  final Map<ChartRange, DateTime> _chartedAt = <ChartRange, DateTime>{};
  final Set<ChartRange> _charting = <ChartRange>{};

  /// What the person holds now, or null before onboarding.
  Portfolio? get portfolio {
    final StoreSnapshot? s = own.snapshot;
    if (s == null) return null;
    return _portfolio ??= buildPortfolio(
      s,
      tickers: _tickers,
      history: _history,
      pricedAt: _pricedAt,
    );
  }

  /// Whether the person holds any crypto at all.
  bool get hasHoldings => own.accounts.any((Account a) => a.asset.isCrypto);

  bool get pricing => _pricing;
  bool get pricingFailed => _pricingFailed;
  DateTime? get pricedAt => _pricedAt;

  /// The portfolio's value over [range], or null while it is being read.
  List<ValuePoint>? chart(ChartRange range) => _charts[range];
  bool charting(ChartRange range) => _charting.contains(range);

  /// What prices made over the last 24 hours on what was held, and as a
  /// fraction: from the day's chart, so the figure and the chart are one
  /// calculation, or from the tickers while it is read. Null when neither
  /// knows.
  ({Pair moved, double change})? get day {
    final List<ValuePoint>? points = _charts[ChartRange.day];
    if (points != null && points.length > 1) {
      return (moved: points.last.gain, change: points.last.ratio);
    }
    final Portfolio? p = portfolio;
    final Pair? moved = p?.moved24h;
    final double? change = p?.change24h;
    if (moved == null || change == null) return null;
    return (moved: moved, change: change);
  }

  void _ownChanged() {
    _portfolio = null;
    // Movements change what was held, so every chart has to be drawn again;
    // new rates alone do not.
    final int held = _heldSignature();
    if (held != _held) {
      _held = held;
      _charts.clear();
      _chartedAt.clear();
    }
    // A coin just added is priced now, not at the next tick.
    if (_watchers > 0 && !_pricing && _missingPrices()) unawaited(refresh());
    _notify();
  }

  bool _missingPrices() => own.accounts.any(
    (Account a) =>
        a.asset.isCrypto &&
        !_tickers.containsKey(a.asset.code) &&
        !_tried.contains(a.asset.code),
  );

  /// Codes already asked for, so one Binance does not list is not asked
  /// again on every change.
  final Set<String> _tried = <String>{};

  int? _held;

  int _heldSignature() {
    final StoreSnapshot? s = own.snapshot;
    if (s == null) return 0;
    return Object.hash(
      Object.hashAll(<Object>[
        for (final Account a in s.accounts)
          if (a.asset.isCrypto) Object.hash(a.id, a.opening),
      ]),
      Object.hashAll(<Object>[
        for (final Entry e in s.entries) Object.hash(e.id, e.amount, e.date),
      ]),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A screen that shows prices opened: they are read now and then every
  /// [every] until the last such screen closes.
  void watch() {
    _watchers++;
    if (_watchers > 1) return;
    // Screens call this while they are being built: the first read starts
    // once that is over, so no one is told of it mid-build.
    unawaited(Future<void>.microtask(refresh));
    _timer = Timer.periodic(every, (_) => refresh());
  }

  void unwatch() {
    if (_watchers == 0) return;
    _watchers--;
    if (_watchers > 0) return;
    _timer?.cancel();
    _timer = null;
  }

  /// Reads the prices again when they are older than [age], as when Gemini
  /// asks for them.
  Future<void> refreshIfOlder(Duration age) async {
    final DateTime? at = _pricedAt;
    if (at != null && own.now().difference(at) < age) return;
    await refresh();
  }

  /// Reads the prices of everything held, and the past dollar rates the
  /// costs need the first time.
  Future<void> refresh() async {
    final Profile? profile = own.profile;
    if (profile == null || _pricing || !hasHoldings) return;
    _pricing = true;
    _notify();
    final Set<String> codes = <String>{
      for (final Account a in own.accounts)
        if (a.asset.isCrypto) a.asset.code,
    };
    _tried.addAll(codes);
    try {
      if (!_historyLoaded) await _loadHistory(profile.base);
      final Map<String, Ticker> fetched = await _market.tickers(codes);
      _pricingFailed = fetched.isEmpty;
      if (fetched.isNotEmpty) {
        _tickers = <String, Ticker>{..._tickers, ...fetched};
        _pricedAt = own.now();
        // The same prices for every total in the app.
        await own.store.saveRates(<Rate>[
          for (final Ticker t in fetched.values)
            if (t.asset != 'USDT')
              Rate(
                asset: t.asset,
                quote: 'USDT',
                value: t.price,
                asOf: t.at,
                source: 'binance',
              ),
        ]);
      }
    } finally {
      _pricing = false;
      _portfolio = null;
      _notify();
    }
    // The day's move comes from the day's candles while someone looks.
    if (_watchers > 0) await loadChart(ChartRange.day);
  }

  /// The past dollar rates from the first movement in an investment on,
  /// from the device and, for the days it lacks, from their source.
  Future<void> _loadHistory(Asset base) async {
    if (base.code == 'USD') {
      _historyLoaded = true;
      return;
    }
    final DateTime? first = _firstInvestmentDay();
    if (first == null) return;
    final List<Rate> kept = await own.store.dailyRates('USD', base.code);
    final DateTime today = own.today;
    final DateTime? lastKept = kept.isEmpty ? null : kept.last.asOf;
    final bool coversStart = kept.isNotEmpty && !kept.first.asOf.isAfter(first);
    final List<Rate> fetched = <Rate>[];
    if (!coversStart) {
      fetched.addAll(await _market.dollarHistory(base, first));
    } else if (lastKept != null && lastKept.isBefore(today)) {
      fetched.addAll(
        await _market.dollarHistory(
          base,
          lastKept.add(const Duration(days: 1)),
        ),
      );
    }
    if (fetched.isNotEmpty) await own.store.saveDailyRates(fetched);
    _history = DollarHistory(<Rate>[...kept, ...fetched]);
    // Read again next time if the source could not be reached.
    _historyLoaded = coversStart || fetched.isNotEmpty;
    _portfolio = null;
  }

  DateTime? _firstInvestmentDay() {
    final StoreSnapshot? s = own.snapshot;
    if (s == null) return null;
    final Set<String> invested = <String>{
      for (final Account a in s.accounts)
        if (a.asset.isCrypto) a.id,
    };
    DateTime? first;
    for (final Entry e in s.entries) {
      if (!invested.contains(e.accountId)) continue;
      if (first == null || e.date.isBefore(first)) first = e.date;
    }
    final DateTime today = own.today;
    // What an account started with is valued from the day it shows up;
    // without movements, from a year back, enough for the year's chart.
    return first ?? DateTime(today.year - 1, today.month, today.day);
  }

  /// Draws the value over [range], unless it was drawn recently.
  Future<void> loadChart(ChartRange range) async {
    final StoreSnapshot? s = own.snapshot;
    if (s == null || _charting.contains(range) || !hasHoldings) return;
    final DateTime? at = _chartedAt[range];
    if (_charts[range] != null &&
        at != null &&
        own.now().difference(at) < range.step) {
      return;
    }
    _charting.add(range);
    _notify();
    // Within a week the peso barely moves against the dollar: today's TRM,
    // which also covers the hours before the day's is published.
    final bool recent = range == ChartRange.day || range == ChartRange.week;
    try {
      if (!recent && !_historyLoaded) await _loadHistory(s.profile.base);
      final Set<String> codes = <String>{
        for (final Account a in s.accounts)
          if (a.asset.isCrypto) a.asset.code,
      };
      final Map<String, List<Candle>> candles = <String, List<Candle>>{};
      await Future.wait(<Future<void>>[
        for (final String code in codes)
          _market
              .candles(code, range)
              .then((List<Candle> c) => candles[code] = c),
      ]);
      final Asset base = s.profile.base;
      final Decimal? dollarNow = base.code == 'USD'
          ? Decimal.one
          : RateTable(s.rates).rate(Asset.usd, base);
      _charts[range] = valueOverTime(
        accounts: s.accounts,
        entries: s.entries,
        candles: candles,
        dollarOn: (DateTime day) =>
            recent ? dollarNow : (_history.on(day) ?? dollarNow),
        base: base,
      );
      _chartedAt[range] = own.now();
    } finally {
      _charting.remove(range);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    own.removeListener(_ownChanged);
    _market.close();
    super.dispose();
  }
}
