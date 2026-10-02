import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/portfolio/cost_basis.dart';
import 'package:quincena/portfolio/market.dart';
import 'package:quincena/portfolio/portfolio.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

/// Market data that answers from memory, as Binance would.
class FakeMarket extends MarketData {
  FakeMarket({
    this.prices = const <String, (String, String)>{},
    this.history = const <Rate>[],
  });

  /// Each coin's price now and a day ago, in tether.
  final Map<String, (String, String)> prices;
  final List<Rate> history;
  int asked = 0;

  @override
  Future<Map<String, Ticker>> tickers(Iterable<String> codes) async {
    asked++;
    final DateTime now = DateTime(2026, 10, 2, 12);
    return <String, Ticker>{
      for (final String c in codes)
        if (c == 'USDT')
          c: Ticker.peg(c, now)
        else if (prices[c] case (final String price, final String open))
          c: Ticker(
            asset: c,
            price: d(price),
            open: d(open),
            high: d(price),
            low: d(open),
            at: now,
          ),
    };
  }

  @override
  Future<List<Rate>> dollarHistory(Asset base, DateTime from) async => history;

  @override
  Future<List<Candle>> candles(String code, ChartRange range) async =>
      const <Candle>[];
}

Rate trm(String value, DateTime day) =>
    Rate(asset: 'USD', quote: 'COP', value: d(value), asOf: day, source: 'trm');

void main() {
  group('the past rate of a day', () {
    final DollarHistory history = DollarHistory(<Rate>[
      trm('4000', DateTime(2026, 9, 1)),
      trm('3900', DateTime(2026, 9, 2)),
      trm('3800', DateTime(2026, 9, 10)),
    ]);

    test('is the day\'s, or the closest before it within a week', () {
      expect(history.on(DateTime(2026, 9, 2, 15)), d('3900'));
      expect(history.on(DateTime(2026, 9, 5)), d('3900'));
      expect(history.on(DateTime(2026, 9, 10)), d('3800'));
    });

    test('is unknown before the first, or more than a week after one', () {
      expect(history.on(DateTime(2026, 8, 31)), isNull);
      expect(history.on(DateTime(2026, 9, 30)), isNull);
    });
  });

  group('a portfolio priced now', () {
    final DateTime march = DateTime(2026, 3, 10);
    final Account btc = Account(
      id: 'btc',
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
      opening: Decimal.zero,
      institution: 'Binance',
      spendable: false,
    );
    final Account usdt = Account(
      id: 'usdt',
      name: 'Tether',
      kind: AccountKind.exchange,
      asset: Asset.usdt,
      opening: Decimal.zero,
      institution: 'Binance',
      spendable: false,
    );
    final Account pepe = Account(
      id: 'pepe',
      name: 'Pepe',
      kind: AccountKind.wallet,
      asset: Asset.of('PEPE'),
      opening: d('1000000'),
      institution: 'MetaMask',
      spendable: false,
    );
    StoreSnapshot snapshot() => StoreSnapshot(
      profile: const Profile(
        name: 'Diego',
        base: Asset.cop,
        schedule: TwiceMonthly(),
      ),
      accounts: <Account>[btc, usdt, pepe],
      entries: <Entry>[
        Entry(
          id: 'b',
          accountId: 'btc',
          amount: d('0.01'),
          date: march,
          kind: EntryKind.income,
          cost: Money(d('3000000'), Asset.cop),
        ),
        Entry(
          id: 'u',
          accountId: 'usdt',
          amount: d('250'),
          date: march,
          kind: EntryKind.income,
          cost: Money(d('1000000'), Asset.cop),
        ),
      ],
      recurring: const <RecurringCharge>[],
      goals: const <SavingsGoal>[],
      rates: <Rate>[trm('4000', DateTime(2026, 10, 2))],
      categories: const <CategoryItem>[],
    );

    final Portfolio p = buildPortfolio(
      snapshot(),
      tickers: <String, Ticker>{
        'BTC': Ticker(
          asset: 'BTC',
          price: d('100000'),
          open: d('80000'),
          high: d('100000'),
          low: d('80000'),
          at: DateTime(2026, 10, 2, 12),
        ),
        'USDT': Ticker.peg('USDT', DateTime(2026, 10, 2, 12)),
      },
      history: DollarHistory(<Rate>[trm('4000', march)]),
    );

    test('values each holding at its price, in pesos and dollars', () {
      final Holding bitcoin = p.holdings.first;
      expect(bitcoin.asset, Asset.btc);
      expect(bitcoin.value, Pair(d('4000000'), d('1000')));
      expect(bitcoin.gain!.base, d('1000000'));
      expect(bitcoin.gainRatio, closeTo(1 / 3, 1e-9));
      expect(bitcoin.change24h, closeTo(0.25, 1e-9));
      // A day ago it was worth 800 dollars.
      expect(bitcoin.moved24h!.usd, d('200'));
    });

    test('adds up what has a price, and names what does not', () {
      expect(p.value, Pair(d('5000000'), d('1250')));
      expect(p.cost.base, d('4000000'));
      expect(p.gain.base, d('1000000'));
      expect(p.unpriced, <Asset>[Asset.of('PEPE')]);
      expect(p.holdings.last.asset, Asset.of('PEPE'));
      expect(p.change24h, closeTo(200 / 1050, 1e-9));
    });

    test('splits by coin, largest first, and by place', () {
      expect(p.allocation.map(((Asset, Pair) e) => e.$1.code), <String>[
        'BTC',
        'USDT',
      ]);
      expect(
        p.byInstitution.keys,
        containsAll(<String>['Binance', 'MetaMask']),
      );
    });
  });

  test('the value over time follows what was held at each moment', () {
    final Account btc = Account(
      id: 'btc',
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
      opening: d('0.01'),
      spendable: false,
    );
    final DateTime t0 = DateTime(2026, 10, 1, 10);
    final DateTime t1 = DateTime(2026, 10, 1, 11);
    final DateTime t2 = DateTime(2026, 10, 1, 12);
    final List<ValuePoint> points = valueOverTime(
      accounts: <Account>[btc],
      entries: <Entry>[
        Entry(
          id: 'more',
          accountId: 'btc',
          amount: d('0.01'),
          date: DateTime(2026, 10, 1, 11, 30),
          kind: EntryKind.income,
        ),
      ],
      candles: <String, List<Candle>>{
        'BTC': <Candle>[
          Candle(t0, d('100000')),
          Candle(t1, d('110000')),
          Candle(t2, d('120000')),
        ],
      },
      dollarOn: (_) => d('4000'),
      base: Asset.cop,
    );
    expect(points.map((ValuePoint v) => v.value.usd), <Decimal>[
      d('1000'),
      d('1100'),
      d('2400'),
    ]);
    expect(points.last.value.base, d('9600000'));
    // Prices made 200 dollars on what was held; the purchase is not gain.
    expect(points.map((ValuePoint v) => v.gain.usd), <Decimal>[
      d('0'),
      d('100'),
      d('200'),
    ]);
    expect(points.last.gain.base, d('800000'));
  });

  group('the portfolio tool', () {
    late QuincenaStore store;
    late OwnController own;
    late FakeMarket market;
    final DateTime now = DateTime(2026, 10, 2, 12);

    setUp(() async {
      Intl.defaultLocale = 'es_CO';
      store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => now,
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
      );
      final Account btc = await store.addAccount(
        name: 'Binance BTC',
        kind: AccountKind.exchange,
        asset: Asset.btc,
        opening: d('0.02'),
        institution: 'Binance',
        openingCost: Money(d('6000000'), Asset.cop),
      );
      await store.addEntry(
        accountId: btc.id,
        amount: d('0.001'),
        kind: EntryKind.income,
        date: DateTime(2026, 9, 1),
      );
      await store.saveRates(<Rate>[trm('4000', now)]);
      market = FakeMarket(
        prices: <String, (String, String)>{'BTC': ('100000', '98000')},
        history: <Rate>[trm('4000', DateTime(2026, 9, 1))],
      );
      own = OwnController(
        store,
        now: () => now,
        readNative: false,
        market: market,
      );
      await own.start();
    });

    tearDown(() async {
      own.dispose();
      await store.close();
    });

    test('answers with prices read for it, and the gain in pesos', () async {
      final Map<String, Object?> answer = portfolioAnswer(own);
      expect(answer['holdings'], isNotEmpty);
      await own.portfolio.refreshIfOlder(const Duration(minutes: 1));
      final Map<String, Object?> priced = portfolioAnswer(own);
      expect(priced['baseCurrency'], 'COP');
      expect(priced['pricesFrom'], 'Binance');
      // 0,021 BTC at 100.000 dollars and 4.000 pesos a dollar.
      expect(priced['totalValueInBase'], 8400000);
      expect(priced['totalValueInUsd'], 2100);
      expect(priced['totalCostInBase'], 6000000);
      expect(priced['gainInBase'], 2400000);
      expect(priced['gainPercent'], 40);
      final Map<Object?, Object?> held =
          (priced['holdings']! as List<Object?>).single!
              as Map<Object?, Object?>;
      expect(held['quantityText'], '0,021 BTC');
      expect(held['heldWithoutCostText'], '0,001 BTC');
      expect(held['change24hPercent'], 2.04);
    });

    test('prices read a moment ago are not read again', () async {
      await own.portfolio.refreshIfOlder(const Duration(minutes: 1));
      await own.portfolio.refreshIfOlder(const Duration(minutes: 1));
      expect(market.asked, 1);
    });

    test('the prices read become the app\'s rates too', () async {
      await own.portfolio.refresh();
      final RateTable rates = RateTable(await store.rates());
      expect(rates.rate(Asset.btc, Asset.cop), d('400000000'));
    });
  });
}
