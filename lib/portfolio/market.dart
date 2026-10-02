import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../money/asset.dart';
import '../money/rates.dart';

/// What a coin trades at now and traded at a day ago, in tether.
@immutable
class Ticker {
  const Ticker({
    required this.asset,
    required this.price,
    required this.open,
    required this.high,
    required this.low,
    required this.at,
  });

  /// A stablecoin worth one dollar, which Binance does not quote in itself.
  Ticker.peg(this.asset, this.at)
    : price = Decimal.one,
      open = Decimal.one,
      high = Decimal.one,
      low = Decimal.one;

  final String asset;
  final Decimal price;

  /// The price 24 hours ago.
  final Decimal open;
  final Decimal high;
  final Decimal low;
  final DateTime at;

  /// The change over the last 24 hours, as a fraction: 0.012 is 1,2 %.
  double get change =>
      open == Decimal.zero ? 0 : ((price - open) / open).toDouble();
}

/// A coin's closing price at one point of a chart, in tether.
@immutable
class Candle {
  const Candle(this.at, this.close);

  /// When the candle opened.
  final DateTime at;
  final Decimal close;
}

/// The stretches of time a portfolio chart can show.
enum ChartRange {
  day('15m', 96, Duration(minutes: 15)),
  week('1h', 168, Duration(hours: 1)),
  month('4h', 180, Duration(hours: 4)),
  year('1d', 365, Duration(days: 1));

  const ChartRange(this.interval, this.points, this.step);

  /// Binance's name for the length of one candle.
  final String interval;

  /// How many candles make the range.
  final int points;
  final Duration step;

  Duration get span => step * points;
}

/// Market data from public sources that need no key and that a browser may
/// ask: prices and candles from Binance, and past dollar rates.
class MarketData {
  MarketData({http.Client? client, this.timeout = const Duration(seconds: 8)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const String _host = 'data-api.binance.vision';

  /// Tether, what everything is quoted in, counted as one dollar as
  /// [RateTable] counts it.
  static const Set<String> pegged = <String>{'USDT'};

  /// The 24-hour ticker of each of [codes] against tether. A code Binance
  /// does not list against tether is left out.
  Future<Map<String, Ticker>> tickers(Iterable<String> codes) async {
    final DateTime now = DateTime.now();
    final Map<String, Ticker> out = <String, Ticker>{};
    // One request per symbol: a single unknown symbol makes Binance reject
    // a whole batch.
    await Future.wait(<Future<void>>[
      for (final String code in codes.toSet())
        if (pegged.contains(code))
          Future<void>.sync(() => out[code] = Ticker.peg(code, now))
        else
          _getMap(
                Uri.https(_host, '/api/v3/ticker/24hr', <String, String>{
                  'symbol': '${code}USDT',
                }),
              )
              .then((Map<String, Object?> row) {
                final Decimal? price = Decimal.tryParse('${row['lastPrice']}');
                final Decimal? open = Decimal.tryParse('${row['openPrice']}');
                if (price == null || open == null) return;
                out[code] = Ticker(
                  asset: code,
                  price: price,
                  open: open,
                  high: Decimal.tryParse('${row['highPrice']}') ?? price,
                  low: Decimal.tryParse('${row['lowPrice']}') ?? price,
                  at: _time(row['closeTime']) ?? now,
                );
              })
              .catchError((Object _) {}),
    ]);
    return out;
  }

  /// The closing prices of [code] in tether over [range], oldest first.
  /// Empty when Binance does not list it against tether; a stablecoin is a
  /// flat line at one dollar.
  Future<List<Candle>> candles(String code, ChartRange range) async {
    if (pegged.contains(code)) {
      final DateTime end = DateTime.now();
      return <Candle>[
        for (var i = range.points - 1; i >= 0; i--)
          Candle(end.subtract(range.step * i), Decimal.one),
      ];
    }
    try {
      final List<Object?> rows = await _getList(
        Uri.https(_host, '/api/v3/klines', <String, String>{
          'symbol': '${code}USDT',
          'interval': range.interval,
          'limit': '${range.points}',
        }),
      );
      return <Candle>[
        for (final Object? row in rows)
          if (row is List &&
              _time(row[0]) != null &&
              Decimal.tryParse('${row[4]}') != null)
            Candle(_time(row[0])!, Decimal.parse('${row[4]}')),
      ];
    } on Object {
      return const <Candle>[];
    }
  }

  /// One dollar in [base] on every day from [from] to today, oldest first:
  /// the TRM for pesos, the European Central Bank's reference rate for the
  /// rest. Days without a published rate take the one before.
  Future<List<Rate>> dollarHistory(Asset base, DateTime from) async {
    if (base.code == 'USD') return const <Rate>[];
    final DateTime start = DateTime(from.year, from.month, from.day);
    try {
      return base.code == 'COP'
          ? await _trmSince(start)
          : await _ecbSince(base.code, start);
    } on Object {
      return const <Rate>[];
    }
  }

  Future<List<Rate>> _trmSince(DateTime start) async {
    final String since = start.toIso8601String().substring(0, 10);
    final List<Object?> rows = await _getList(
      Uri.https(
        'www.datos.gov.co',
        '/resource/32sa-8pi3.json',
        <String, String>{
          r'$select': 'valor,vigenciadesde,vigenciahasta',
          r'$where': "vigenciahasta >= '${since}T00:00:00'",
          r'$order': 'vigenciadesde ASC',
          r'$limit': '5000',
        },
      ),
    );
    final List<Rate> out = <Rate>[];
    for (final Object? row in rows) {
      if (row is! Map) continue;
      final Decimal? value = Decimal.tryParse('${row['valor']}');
      final DateTime? first = DateTime.tryParse('${row['vigenciadesde']}');
      final DateTime? last = DateTime.tryParse('${row['vigenciahasta']}');
      if (value == null || first == null || last == null) continue;
      // One row covers a weekend or a holiday with the same TRM.
      for (
        var day = DateTime(first.year, first.month, first.day);
        !day.isAfter(last);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        if (day.isBefore(start)) continue;
        out.add(
          Rate(
            asset: 'USD',
            quote: 'COP',
            value: value,
            asOf: day,
            source: 'trm',
          ),
        );
      }
    }
    return out;
  }

  Future<List<Rate>> _ecbSince(String code, DateTime start) async {
    final String since = start.toIso8601String().substring(0, 10);
    final Map<String, Object?> body = await _getMap(
      Uri.https('api.frankfurter.dev', '/v1/$since..', <String, String>{
        'base': 'USD',
        'symbols': code,
      }),
    );
    final Map<String, Object?> days =
        (body['rates'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final List<Rate> published = <Rate>[
      for (final MapEntry<String, Object?> e in days.entries)
        if (DateTime.tryParse(e.key) case final DateTime day)
          if (Decimal.tryParse('${(e.value as Map?)?[code]}')
              case final Decimal v)
            Rate(asset: 'USD', quote: code, value: v, asOf: day, source: 'ecb'),
    ]..sort((Rate a, Rate b) => a.asOf.compareTo(b.asOf));
    // Weekends and holidays take the rate before them.
    final List<Rate> out = <Rate>[];
    for (var i = 0; i < published.length; i++) {
      final Rate r = published[i];
      final DateTime next = i + 1 < published.length
          ? published[i + 1].asOf
          : DateTime.now().add(const Duration(days: 1));
      for (
        var day = r.asOf;
        day.isBefore(next);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        out.add(
          Rate(
            asset: r.asset,
            quote: r.quote,
            value: r.value,
            asOf: day,
            source: r.source,
          ),
        );
      }
    }
    return out;
  }

  static DateTime? _time(Object? millis) => millis is int
      ? DateTime.fromMillisecondsSinceEpoch(millis)
      : (int.tryParse('$millis') == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(int.parse('$millis')));

  Future<List<Object?>> _getList(Uri uri) async =>
      jsonDecode(await _get(uri)) as List<Object?>;

  Future<Map<String, Object?>> _getMap(Uri uri) async =>
      jsonDecode(await _get(uri)) as Map<String, Object?>;

  Future<String> _get(Uri uri) async {
    final http.Response response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return response.body;
  }

  void close() => _client.close();
}
