import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import 'asset.dart';
import 'rates.dart';

/// Fetches current rates from public sources that need no key and allow
/// requests from a browser, so the web build can use them too.
///
/// - The TRM, the official dollar rate in pesos, from datos.gov.co.
/// - Crypto in tether, from Binance's public market data.
/// - Other currencies in dollars, from the European Central Bank's reference
///   rates, published by Frankfurter.
///
/// A source that fails is skipped: a stale rate is better than no total.
class RateFetcher {
  RateFetcher({http.Client? client, this.timeout = const Duration(seconds: 8)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// The TRM in force on [day]. Banco de la República publishes tomorrow's
  /// the afternoon before; banks quote the one in force today.
  static Uri _trm(
    DateTime day,
  ) => Uri.https('www.datos.gov.co', '/resource/32sa-8pi3.json', <
    String,
    String
  >{
    r'$limit': '1',
    r'$order': 'vigenciadesde DESC',
    r'$where':
        "vigenciadesde <= '${day.toIso8601String().substring(0, 10)}T23:59:59'",
  });

  /// Rates that let every asset in [assets] be converted to [base].
  Future<List<Rate>> fetch(Iterable<Asset> assets, Asset base) async {
    final Set<Asset> wanted = <Asset>{...assets, base};
    final List<String> crypto = <String>[
      for (final Asset a in wanted)
        if (a.isCrypto && a.code != 'USDT') a.code,
    ];
    final List<String> otherFiat = <String>[
      for (final Asset a in wanted)
        if (!a.isCrypto && a.code != 'USD' && a.code != 'COP') a.code,
    ];
    final bool needsCop = wanted.any((Asset a) => a.code == 'COP');
    final List<Future<List<Rate>>> calls = <Future<List<Rate>>>[
      if (needsCop) _guard(trm()),
      if (crypto.isNotEmpty) _guard(binance(crypto)),
      if (otherFiat.isNotEmpty) _guard(ecb(otherFiat)),
    ];
    return <Rate>[for (final List<Rate> r in await Future.wait(calls)) ...r];
  }

  Future<List<Rate>> _guard(Future<List<Rate>> call) =>
      call.timeout(timeout).catchError((Object _) => const <Rate>[]);

  /// USD/COP from the TRM in force today.
  Future<List<Rate>> trm() async {
    final List<Object?> rows = await _getList(_trm(DateTime.now()));
    if (rows.isEmpty) return const <Rate>[];
    final Map<String, Object?> row = rows.first! as Map<String, Object?>;
    final Decimal? value = Decimal.tryParse('${row['valor']}');
    final DateTime? asOf = DateTime.tryParse('${row['vigenciadesde']}');
    if (value == null || asOf == null) return const <Rate>[];
    return <Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: value,
        asOf: DateTime(asOf.year, asOf.month, asOf.day),
        source: 'trm',
      ),
    ];
  }

  /// Each of [codes] in USDT. Tickers Binance does not list are left out.
  Future<List<Rate>> binance(List<String> codes) async {
    final DateTime now = DateTime.now();
    final List<Rate> rates = <Rate>[];
    // One request per symbol: a single unknown symbol makes Binance reject
    // a whole batch.
    await Future.wait(<Future<void>>[
      for (final String code in codes)
        _getMap(
              Uri.https('data-api.binance.vision', '/api/v3/ticker/price', {
                'symbol': '${code}USDT',
              }),
            )
            .then((Map<String, Object?> row) {
              final Decimal? price = Decimal.tryParse('${row['price']}');
              if (price != null) {
                rates.add(
                  Rate(
                    asset: code,
                    quote: 'USDT',
                    value: price,
                    asOf: now,
                    source: 'binance',
                  ),
                );
              }
            })
            .catchError((Object _) {}),
    ]);
    return rates;
  }

  /// One dollar in each of [codes], from the ECB's reference rates.
  Future<List<Rate>> ecb(List<String> codes) async {
    final Map<String, Object?> body = await _getMap(
      Uri.https('api.frankfurter.dev', '/v1/latest', {
        'base': 'USD',
        'symbols': codes.join(','),
      }),
    );
    final DateTime asOf =
        DateTime.tryParse('${body['date']}') ?? DateTime.now();
    final Map<String, Object?> values =
        (body['rates'] as Map<String, Object?>?) ?? const <String, Object?>{};
    return <Rate>[
      for (final MapEntry<String, Object?> e in values.entries)
        if (Decimal.tryParse('${e.value}') case final Decimal v)
          Rate(asset: 'USD', quote: e.key, value: v, asOf: asOf, source: 'ecb'),
    ];
  }

  Future<List<Object?>> _getList(Uri uri) async =>
      jsonDecode(await _get(uri)) as List<Object?>;

  Future<Map<String, Object?>> _getMap(Uri uri) async =>
      jsonDecode(await _get(uri)) as Map<String, Object?>;

  Future<String> _get(Uri uri) async {
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return response.body;
  }

  void close() => _client.close();
}
