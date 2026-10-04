import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rate_sources.dart';
import 'package:quincena/money/rates.dart';

Decimal d(String s) => Decimal.parse(s);

String plain(String s) => s.replaceAll(' ', ' ');

void main() {
  tearDown(() => Intl.defaultLocale = 'es_CO');

  group('amounts as the interface writes them', () {
    test('Spanish keeps the bare symbol for the person\'s own currency', () {
      Intl.defaultLocale = 'es_CO';
      expect(plain(formatAmount(d('45900'), Asset.cop)), r'$45.900');
      expect(
        plain(formatAmount(d('1250.5'), Asset.usd, base: Asset.cop)),
        r'US$1.250,50',
      );
      expect(
        plain(formatAmount(d('-4719400'), Asset.cop, base: Asset.cop)),
        r'−$4.719.400',
      );
      expect(
        plain(formatAmount(d('12'), Asset.eur, base: Asset.cop, signed: true)),
        '+€12,00',
      );
    });

    test('English writes the symbol against the number', () {
      Intl.defaultLocale = 'en_US';
      expect(formatAmount(d('45900'), Asset.cop), r'$45,900');
      expect(
        formatAmount(d('1250.5'), Asset.usd, base: Asset.cop),
        r'US$1,250.50',
      );
      expect(
        formatAmount(d('1250.5'), Asset.usd, base: Asset.usd),
        r'$1,250.50',
      );
    });

    test(
      'crypto keeps its decimals, drops trailing zeros, ends in the ticker',
      () {
        Intl.defaultLocale = 'es_CO';
        expect(plain(formatAmount(d('0.00420000'), Asset.btc)), '0,0042 BTC');
        expect(
          plain(formatAmount(d('0.12345678'), Asset.btc)),
          '0,12345678 BTC',
        );
        expect(plain(formatAmount(d('1520.5'), Asset.usdt)), '1.520,5 USDT');
        Intl.defaultLocale = 'en_US';
        expect(plain(formatAmount(d('1520.5'), Asset.usdt)), '1,520.5 USDT');
      },
    );

    test('an asset the app does not know is still written', () {
      Intl.defaultLocale = 'es_CO';
      expect(Asset.of('pepe').code, 'PEPE');
      expect(
        plain(formatAmount(d('1000000'), Asset.of('PEPE'))),
        '1.000.000 PEPE',
      );
    });
  });

  group('amounts as a person types them', () {
    test('Spanish', () {
      expect(parseAmount('45.900', english: false), d('45900'));
      expect(parseAmount(r'$ 1.250,50', english: false), d('1250.50'));
      expect(parseAmount('0,0042', english: false), d('0.0042'));
      // A dot followed by one or two digits is a decimal point.
      expect(parseAmount('0.5', english: false), d('0.5'));
      expect(parseAmount('-12.000', english: false), d('-12000'));
    });

    test('English', () {
      expect(parseAmount('45,900', english: true), d('45900'));
      expect(parseAmount(r'$1,250.50', english: true), d('1250.50'));
      expect(parseAmount('0,5', english: true), d('0.5'));
    });

    test('nonsense is not an amount', () {
      expect(parseAmount('', english: false), isNull);
      expect(parseAmount('abc', english: false), isNull);
      expect(parseAmount('1,2,3', english: false), isNull);
    });
  });

  group('conversions through known rates', () {
    final RateTable table = RateTable(<Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: d('4000'),
        asOf: DateTime(2026, 10, 1),
        source: 'trm',
      ),
      Rate(
        asset: 'BTC',
        quote: 'USDT',
        value: d('80000'),
        asOf: DateTime(2026, 10, 1),
        source: 'binance',
      ),
      Rate(
        asset: 'USD',
        quote: 'EUR',
        value: d('0.8'),
        asOf: DateTime(2026, 9, 30),
        source: 'ecb',
      ),
    ]);

    test('directly, and backwards', () {
      expect(
        table.convert(Money(d('10'), Asset.usd), Asset.cop),
        Money(d('40000'), Asset.cop),
      );
      expect(
        table.convert(Money(d('40000'), Asset.cop), Asset.usd)!.amount,
        d('10'),
      );
    });

    test('crypto reaches pesos through tether and the dollar', () {
      final Money? pesos = table.convert(
        Money(d('0.001'), Asset.btc),
        Asset.cop,
      );
      expect(pesos, Money(d('320000'), Asset.cop));
      expect(
        table.used(Asset.btc, Asset.cop).map((Rate r) => r.source),
        <String>['binance', 'trm'],
      );
    });

    test('a conversion comes apart into its steps, in order', () {
      final List<RateStep> steps = table.steps(Asset.btc, Asset.cop);
      expect(steps.map((RateStep s) => '${s.from}/${s.to}'), <String>[
        'BTC/USDT',
        'USDT/USD',
        'USD/COP',
      ]);
      expect(steps.map((RateStep s) => s.kind), <RateStepKind>[
        RateStepKind.price,
        RateStepKind.peg,
        RateStepKind.conversion,
      ]);
      expect(steps.map((RateStep s) => s.value), <Decimal>[
        d('80000'),
        Decimal.one,
        d('4000'),
      ]);
      expect(steps.map((RateStep s) => s.rate?.source), <String?>[
        'binance',
        null,
        'trm',
      ]);
      // Euros go to the dollar against the way the rate is quoted.
      final List<RateStep> euros = table.steps(Asset.eur, Asset.cop);
      expect(euros.first.from, 'EUR');
      expect(euros.first.value, d('1.25'));
      expect(euros.first.rate!.pair, 'USD/EUR');
      expect(table.steps(Asset.cop, Asset.cop), isEmpty);
      expect(table.steps(Asset.of('PEPE'), Asset.cop), isEmpty);
    });

    test('a rate typed by hand is a step of its own kind', () {
      final RateTable typed = RateTable(<Rate>[
        Rate(
          asset: 'USD',
          quote: 'COP',
          value: d('3400'),
          asOf: DateTime(2026, 10, 4),
          source: 'manual',
          manual: true,
        ),
      ]);
      expect(
        typed.steps(Asset.usdt, Asset.cop).map((RateStep s) => s.kind),
        <RateStepKind>[RateStepKind.peg, RateStepKind.manual],
      );
    });

    test('euros reach pesos through the dollar', () {
      expect(
        table.convert(Money(d('8'), Asset.eur), Asset.cop)!.amount,
        d('40000'),
      );
    });

    test('an asset with no rate cannot be converted', () {
      expect(table.convert(Money(d('1'), Asset.of('PEPE')), Asset.cop), isNull);
      expect(
        table.convert(Money(d('5'), Asset.cop), Asset.cop),
        Money(d('5'), Asset.cop),
      );
    });
  });

  group('the public rate sources', () {
    MockClient sources({bool binanceFails = false}) => MockClient((
      http.Request request,
    ) async {
      switch (request.url.host) {
        case 'www.datos.gov.co':
          return http.Response(
            jsonEncode(<Object>[
              <String, String>{
                'valor': '3312.84',
                'unidad': 'COP',
                'vigenciadesde': '2026-10-01T00:00:00.000',
              },
            ]),
            200,
          );
        case 'data-api.binance.vision':
          if (binanceFails) return http.Response('{"code":-1121}', 400);
          final String symbol = request.url.queryParameters['symbol']!;
          if (symbol == 'PEPEUSDT') return http.Response('{"code":-1121}', 400);
          return http.Response(
            jsonEncode(<String, String>{'symbol': symbol, 'price': '84616.92'}),
            200,
          );
        case 'api.frankfurter.dev':
          return http.Response(
            jsonEncode(<String, Object>{
              'base': 'USD',
              'date': '2026-10-01',
              'rates': <String, double>{'EUR': 0.88511},
            }),
            200,
          );
      }
      return http.Response('not found', 404);
    });

    test('bring what every held asset needs to reach the base', () async {
      final RateFetcher fetcher = RateFetcher(client: sources());
      final List<Rate> rates = await fetcher.fetch(<Asset>[
        Asset.cop,
        Asset.usd,
        Asset.btc,
        Asset.usdt,
        Asset.eur,
        Asset.of('PEPE'),
      ], Asset.cop);
      expect(rates.map((Rate r) => r.pair).toSet(), <String>{
        'USD/COP',
        'BTC/USDT',
        'USD/EUR',
      });
      final RateTable table = RateTable(rates);
      expect(table.rate(Asset.usdt, Asset.cop), d('3312.84'));
    });

    test('a source that fails is skipped, not fatal', () async {
      final RateFetcher fetcher = RateFetcher(
        client: sources(binanceFails: true),
      );
      final List<Rate> rates = await fetcher.fetch(<Asset>[
        Asset.btc,
        Asset.usd,
      ], Asset.cop);
      expect(rates.map((Rate r) => r.pair), <String>['USD/COP']);
    });
  });
}
