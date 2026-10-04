import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
import '../store/store.dart';
import 'cost_basis.dart';
import 'market.dart';

Decimal _divide(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 18);

/// One investment account with what it is worth now.
@immutable
class Holding {
  const Holding({
    required this.position,
    required this.price,
    required this.value,
    required this.change24h,
    this.pegged = false,
  });

  final Position position;

  /// One unit, in the base currency and in dollars; null without a price.
  final Pair? price;

  /// What it holds is worth; null without a price.
  final Pair? value;

  /// The fraction its price moved in the last 24 hours, when known.
  final double? change24h;

  /// A stablecoin, held at one dollar: its price does not move by the day,
  /// so it has no [change24h] to show.
  final bool pegged;

  Account get account => position.account;
  Asset get asset => position.asset;

  /// What the part of it with a known cost is worth; null without a price.
  Pair? get costedValue {
    final Pair? v = value;
    final Decimal q = position.quantity;
    if (v == null || position.uncosted <= Decimal.zero) return v;
    return v.share(q - position.uncosted, q);
  }

  /// What the part of it that came in with no known cost is worth, left out
  /// of [gain]; null without a price.
  Pair? get uncostedValue {
    final Pair? v = value;
    final Pair? costed = costedValue;
    return v == null || costed == null ? null : v - costed;
  }

  /// What it gained against what it cost, while held, on the part whose
  /// cost is known: what came in with no purchase price is not gain. Null
  /// without a price, or when none of it has a known cost.
  Pair? get gain {
    final Pair? costed = costedValue;
    if (costed == null || position.quantity <= position.uncosted) return null;
    return costed - position.cost;
  }

  /// [gain] as a fraction of the cost; null when nothing of it cost
  /// anything known.
  double? get gainRatio {
    final Pair? g = gain;
    if (g == null || position.cost.base <= Decimal.zero) return null;
    return _divide(g.base, position.cost.base).toDouble();
  }

  /// What its value moved in the last 24 hours.
  Pair? get moved24h {
    final Pair? v = value;
    final double? c = change24h;
    if (v == null || c == null) return null;
    // From now and the change, what it was worth a day ago.
    final Decimal before = Decimal.parse((1 + c).toStringAsFixed(12));
    if (before == Decimal.zero) return null;
    return v - Pair(_divide(v.base, before), _divide(v.usd, before));
  }
}

/// Everything the person holds in crypto, priced now.
@immutable
class Portfolio {
  const Portfolio({
    required this.base,
    required this.holdings,
    required this.pricedAt,
    required this.realized,
  });

  final Asset base;

  /// Every investment account that holds something, largest first; those
  /// without a price last.
  final List<Holding> holdings;

  /// What was gained in sales and conversions already made, in every
  /// investment account, those emptied or archived since included.
  final Pair realized;

  /// When the prices were read, or null if they never were.
  final DateTime? pricedAt;

  bool get isEmpty => holdings.isEmpty;

  Iterable<Holding> get priced =>
      holdings.where((Holding h) => h.value != null);

  /// The assets held that have no price, so their value is left out.
  List<Asset> get unpriced => <Asset>[
    for (final Holding h in holdings)
      if (h.value == null && h.position.quantity != Decimal.zero) h.asset,
  ];

  Pair get value => priced.fold(Pair.zero, (Pair s, Holding h) => s + h.value!);

  /// What the priced holdings cost.
  Pair get cost =>
      priced.fold(Pair.zero, (Pair s, Holding h) => s + h.position.cost);

  /// What the priced holdings hold that came in with no known cost: left
  /// out of [gain], and said apart.
  Pair get uncostedValue =>
      priced.fold(Pair.zero, (Pair s, Holding h) => s + h.uncostedValue!);

  /// What is still held gained against what it cost, on the part whose cost
  /// is known; null when nothing priced has a known cost.
  Pair? get gain {
    Pair? sum;
    for (final Holding h in priced) {
      if (h.gain case final Pair g) sum = (sum ?? Pair.zero) + g;
    }
    return sum;
  }

  double? get gainRatio {
    final Pair? g = gain;
    if (g == null || cost.base <= Decimal.zero) return null;
    return _divide(g.base, cost.base).toDouble();
  }

  /// What the value moved in the last 24 hours, from each coin's ticker; a
  /// stablecoin moves nothing. Null when some coin has no price from a day
  /// ago, or when only stablecoins have a price and there is more, so that
  /// a missing price never reads as no change.
  Pair? get moved24h {
    var sum = Pair.zero;
    var measured = false;
    for (final Holding h in priced) {
      if (h.pegged) continue;
      final Pair? moved = h.moved24h;
      if (moved == null) return null;
      sum = sum + moved;
      measured = true;
    }
    if (priced.isEmpty) return null;
    if (!measured && holdings.any((Holding h) => !h.pegged)) return null;
    return sum;
  }

  /// The fraction the whole moved in the last 24 hours, when known.
  double? get change24h {
    final Pair? moved = moved24h;
    if (moved == null) return null;
    final Pair before = value - moved;
    if (before.base <= Decimal.zero) return null;
    return _divide(moved.base, before.base).toDouble();
  }

  /// Whether some cost had to be converted with another day's rate.
  bool get approximate => holdings.any((Holding h) => h.position.approximate);

  /// What each asset is worth, over every account that holds it, largest
  /// first.
  List<(Asset, Pair)> get allocation {
    final Map<Asset, Pair> by = <Asset, Pair>{};
    for (final Holding h in priced) {
      by[h.asset] = (by[h.asset] ?? Pair.zero) + h.value!;
    }
    return by.entries
        .map((MapEntry<Asset, Pair> e) => (e.key, e.value))
        .toList()
      ..sort(
        ((Asset, Pair) a, (Asset, Pair) b) => b.$2.base.compareTo(a.$2.base),
      );
  }

  /// Holdings by where they are kept: an exchange, a wallet.
  Map<String, List<Holding>> get byInstitution {
    final Map<String, List<Holding>> out = <String, List<Holding>>{};
    for (final Holding h in holdings) {
      out.putIfAbsent(h.account.institution, () => <Holding>[]).add(h);
    }
    return out;
  }
}

/// Where an account's balance comes from.
enum HoldingSource {
  /// Written by the person: it changes only when they change it.
  manual,

  /// Read from Binance with a key that can only read.
  binance,

  /// Read from a public address on its blockchain.
  wallet;

  /// Where [account]'s balance comes from, by what keeps it in sync, as
  /// `binance:BTC` or `wallet:bitcoin:<address>:BTC`; null for a sync this
  /// app does not know.
  static HoldingSource? of(Account account) => switch (account.syncRef) {
    null => HoldingSource.manual,
    final String ref when ref.startsWith('binance:') => HoldingSource.binance,
    final String ref when ref.startsWith('wallet:') => HoldingSource.wallet,
    _ => null,
  };
}

/// The past rates of one dollar in the base currency, for looking up a
/// day's.
class DollarHistory {
  DollarHistory(Iterable<Rate> rates)
    : _days = <Rate>[...rates]
        ..sort((Rate a, Rate b) => a.asOf.compareTo(b.asOf));

  final List<Rate> _days;

  bool get isEmpty => _days.isEmpty;
  DateTime? get first => _days.isEmpty ? null : _days.first.asOf;
  DateTime? get last => _days.isEmpty ? null : _days.last.asOf;

  /// The rate of [day], or of the closest day before it within a week; null
  /// when there is none that close.
  Decimal? on(DateTime day) {
    if (_days.isEmpty) return null;
    final DateTime target = DateTime(day.year, day.month, day.day);
    var lo = 0;
    var hi = _days.length - 1;
    var found = -1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      if (_days[mid].asOf.isAfter(target)) {
        hi = mid - 1;
      } else {
        found = mid;
        lo = mid + 1;
      }
    }
    if (found < 0) return null;
    final Rate r = _days[found];
    return target.difference(r.asOf).inDays > 7 ? null : r.value;
  }
}

/// The portfolio of [s], with [tickers] for prices where there are some
/// and the snapshot's rates otherwise.
Portfolio buildPortfolio(
  StoreSnapshot s, {
  required Map<String, Ticker> tickers,
  required DollarHistory history,
  DateTime? pricedAt,
}) {
  final Asset base = s.profile.base;
  final RateTable rates = RateTable(s.rates);
  final List<Position> all = positions(
    accounts: s.accounts,
    entries: s.entries,
    base: base,
    today: rates,
    dollarOn: history.on,
  );
  final Decimal? dollar = base.code == 'USD'
      ? Decimal.one
      : rates.rate(Asset.usd, base);

  Pair? priceOf(Asset asset) {
    final Ticker? t = tickers[asset.code];
    final Decimal? usd = t?.price ?? rates.rate(asset, Asset.usd);
    if (usd == null || dollar == null) return null;
    return Pair(usd * dollar, usd);
  }

  final List<Holding> holdings =
      <Holding>[
        for (final Position p in all)
          if (!p.account.archived && p.quantity != Decimal.zero)
            () {
              final Pair? price = priceOf(p.asset);
              final bool pegged = MarketData.pegged.contains(p.asset.code);
              return Holding(
                position: p,
                price: price,
                value: price == null
                    ? null
                    : Pair(price.base * p.quantity, price.usd * p.quantity),
                // A stablecoin's ticker is its peg, not a measurement.
                change24h: pegged ? null : tickers[p.asset.code]?.change,
                pegged: pegged,
              );
            }(),
      ]..sort((Holding a, Holding b) {
        if ((a.value == null) != (b.value == null)) {
          return a.value == null ? 1 : -1;
        }
        return (b.value?.base ?? Decimal.zero).compareTo(
          a.value?.base ?? Decimal.zero,
        );
      });
  return Portfolio(
    base: base,
    holdings: holdings,
    pricedAt: pricedAt,
    realized: all.fold(Pair.zero, (Pair sum, Position p) => sum + p.realized),
  );
}

/// One point of the portfolio's value over time.
@immutable
class ValuePoint {
  ValuePoint(this.at, this.value, [Pair? gain, this.ratio = 0])
    : gain = gain ?? Pair.zero;

  final DateTime at;
  final Pair value;

  /// What prices made since the first point, on what was held at each
  /// moment: buying or selling moves [value], not this.
  final Pair gain;

  /// [gain] as a fraction, in the base currency: each step's against what
  /// was held at its start, chained. Money put in along the way neither
  /// inflates nor dilutes it, as it would against the first point's value.
  final double ratio;
}

/// What the portfolio was worth at every candle of [candles], with what
/// each account held at that moment, and what prices made from one candle
/// to the next on what was held: a purchase raises the value, not the
/// gain.
///
/// [candles] are each asset's closing prices in tether over the same
/// range. A moment some held asset has no candle for is left out, rather
/// than drawn as if that asset were worth nothing.
List<ValuePoint> valueOverTime({
  required List<Account> accounts,
  required List<Entry> entries,
  required Map<String, List<Candle>> candles,
  required Decimal? Function(DateTime day) dollarOn,
  required Asset base,
}) {
  final List<Account> held = <Account>[
    for (final Account a in accounts)
      if (a.asset.isCrypto) a,
  ];
  if (held.isEmpty) return const <ValuePoint>[];
  final Set<DateTime> times = <DateTime>{
    for (final List<Candle> c in candles.values)
      for (final Candle x in c) x.at,
  };
  final List<DateTime> axis = times.toList()..sort();
  final Map<String, Map<DateTime, Decimal>> closes =
      <String, Map<DateTime, Decimal>>{
        for (final MapEntry<String, List<Candle>> e in candles.entries)
          e.key: <DateTime, Decimal>{
            for (final Candle c in e.value) c.at: c.close,
          },
      };
  // Each account's movements oldest first, walked once along the axis.
  final Map<String, List<Entry>> byAccount = <String, List<Entry>>{};
  for (final Entry e in entries) {
    byAccount.putIfAbsent(e.accountId, () => <Entry>[]).add(e);
  }
  for (final List<Entry> list in byAccount.values) {
    list.sort((Entry a, Entry b) => a.date.compareTo(b.date));
  }
  final Map<String, Decimal> quantities = <String, Decimal>{
    for (final Account a in held) a.id: a.opening,
  };
  final Map<String, int> walked = <String, int>{
    for (final Account a in held) a.id: 0,
  };

  final List<ValuePoint> out = <ValuePoint>[];
  // Each account's quantity and price at the last point drawn.
  final Map<String, Decimal> heldBefore = <String, Decimal>{};
  final Map<String, Decimal> priceBefore = <String, Decimal>{};
  Decimal? dollarBefore;
  var gain = Pair.zero;
  var ratio = 0.0;
  for (final DateTime t in axis) {
    var usd = Decimal.zero;
    var complete = true;
    final Map<String, Decimal> priceNow = <String, Decimal>{};
    for (final Account a in held) {
      final List<Entry> list = byAccount[a.id] ?? const <Entry>[];
      var i = walked[a.id]!;
      var quantity = quantities[a.id]!;
      while (i < list.length && !list[i].date.isAfter(t)) {
        quantity += list[i].amount;
        i++;
      }
      walked[a.id] = i;
      quantities[a.id] = quantity;
      if (quantity == Decimal.zero) continue;
      final Decimal? close = a.asset.code == 'USDT'
          ? Decimal.one
          : closes[a.asset.code]?[t];
      if (close == null) {
        // An asset with no candles at all is left out of the chart, the way
        // the total leaves out what has no price.
        if (closes[a.asset.code]?.isNotEmpty ?? false) complete = false;
        continue;
      }
      usd += quantity * close;
      priceNow[a.id] = close;
    }
    if (!complete) continue;
    final Decimal? dollar = base.code == 'USD' ? Decimal.one : dollarOn(t);
    if (dollar == null) continue;
    // What the move from the last point made on what was held then; the
    // peso's own move counts too, in the base currency.
    final Decimal? before = dollarBefore;
    if (before != null) {
      var stepUsd = Decimal.zero;
      var stepBase = Decimal.zero;
      var startBase = Decimal.zero;
      for (final MapEntry<String, Decimal> h in heldBefore.entries) {
        final Decimal? was = priceBefore[h.key];
        final Decimal? now = priceNow[h.key];
        if (was == null || now == null) continue;
        stepUsd += h.value * (now - was);
        stepBase += h.value * (now * dollar - was * before);
        startBase += h.value * was * before;
      }
      gain = gain + Pair(stepBase, stepUsd);
      if (startBase > Decimal.zero) {
        ratio = (1 + ratio) * (1 + _divide(stepBase, startBase).toDouble()) - 1;
      }
    }
    heldBefore
      ..clear()
      ..addAll(<String, Decimal>{
        for (final Account a in held)
          if (priceNow.containsKey(a.id)) a.id: quantities[a.id]!,
      });
    priceBefore
      ..clear()
      ..addAll(priceNow);
    dollarBefore = dollar;
    out.add(ValuePoint(t, Pair(usd * dollar, usd), gain, ratio));
  }
  return out;
}

/// [money] as the portfolio screens write a pair's base side.
Money baseMoney(Pair pair, Asset base) => Money(pair.base, base);
