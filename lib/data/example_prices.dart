// The rates and crypto prices of the example account and the store's
// pictures: fixed, so every picture shows the same totals, and asked of no
// one, so the example never reaches the network.
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import '../money/asset.dart';
import '../money/rate_sources.dart';
import '../money/rates.dart';
import '../portfolio/market.dart';
import 'clock.dart';

/// The official dollar the example is converted with, in pesos.
const String exampleTrm = '3312.84';

/// Each coin's price in tether now and a day before: they moved a little,
/// the way markets do.
const Map<String, (String, String)> examplePrices = <String, (String, String)>{
  'BTC': ('84616.92', '83102.40'),
  'ETH': ('2678.00', '2701.50'),
};

/// A dollar in the other currencies the app knows, as the European Central
/// Bank would publish it.
const Map<String, String> _exampleFiat = <String, String>{
  'EUR': '0.9210',
  'MXN': '18.2400',
  'BRL': '5.4200',
  'GBP': '0.7850',
  'CAD': '1.3680',
};

/// Every rate the example needs, as the sources would give them at [at].
List<Rate> exampleRates(DateTime at) {
  final DateTime day = DateTime(at.year, at.month, at.day);
  return <Rate>[
    Rate(
      asset: 'USD',
      quote: 'COP',
      value: Decimal.parse(exampleTrm),
      asOf: day,
      source: 'trm',
    ),
    for (final MapEntry<String, (String, String)> p in examplePrices.entries)
      Rate(
        asset: p.key,
        quote: 'USDT',
        value: Decimal.parse(p.value.$1),
        asOf: at,
        source: 'binance',
      ),
    for (final MapEntry<String, String> f in _exampleFiat.entries)
      Rate(
        asset: 'USD',
        quote: f.key,
        value: Decimal.parse(f.value),
        asOf: day,
        source: 'ecb',
      ),
  ];
}

/// Rates for the example: the fixed ones, without asking anyone.
class ExampleRates extends RateFetcher {
  ExampleRates({DateTime Function()? now})
    : _now = now ?? (() => exampleNow),
      super(client: offline());

  final DateTime Function() _now;

  @override
  Future<List<Rate>> fetch(
    Iterable<Asset> assets,
    Asset base, {
    DateTime? at,
  }) async => exampleRates(at ?? _now());
}

/// Market data for the example and the store's pictures: prices that moved
/// a little over the week, the same on every run, from no server.
class ExampleMarket extends MarketData {
  ExampleMarket({DateTime Function()? now})
    : _now = now ?? (() => exampleNow),
      super(client: offline());

  final DateTime Function() _now;

  @override
  Future<Map<String, Ticker>> tickers(Iterable<String> codes) async {
    final DateTime now = _now();
    return <String, Ticker>{
      for (final String c in codes)
        if (c == 'USDT')
          c: Ticker.peg(c, now)
        else if (examplePrices[c] case (final String price, final String open))
          c: Ticker(
            asset: c,
            price: Decimal.parse(price),
            open: Decimal.parse(open),
            high: Decimal.parse(price),
            low: Decimal.parse(open),
            at: now,
          ),
    };
  }

  @override
  Future<List<Candle>> candles(String code, ChartRange range) async {
    final DateTime now = _now();
    final (String price, String _) = examplePrices[code] ?? ('1', '1');
    final double last = double.parse(price);
    // A gentle climb with the small waves of any market, the same each run.
    double at(int i) =>
        last *
        (1 -
            0.03 * i / range.points +
            0.008 * math.sin(i / 6) +
            0.004 * math.sin(i / 2.3));
    return <Candle>[
      for (var i = range.points - 1; i >= 0; i--)
        Candle(
          now.subtract(range.step * i),
          Decimal.parse(at(i).toStringAsFixed(2)),
        ),
    ];
  }

  @override
  Future<List<Rate>> dollarHistory(Asset base, DateTime from) async {
    final DateTime now = _now();
    return <Rate>[
      for (
        var day = DateTime(2026, 1, 1);
        !day.isAfter(now);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        Rate(
          asset: 'USD',
          quote: 'COP',
          value: Decimal.parse(exampleTrm),
          asOf: day,
          source: 'trm',
        ),
    ];
  }
}

/// An HTTP client that never connects: whatever asks it is told it is
/// offline, so nothing the example does reaches the network.
http.Client offline() => _Offline();

class _Offline extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw http.ClientException('The example account works offline.');
}
