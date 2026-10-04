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
      expect(p.gain!.base, d('1000000'));
      expect(p.unpriced, <Asset>[Asset.of('PEPE')]);
      expect(p.holdings.last.asset, Asset.of('PEPE'));
      // Tether is held at one dollar: it moves nothing, and has no 24 hours
      // of its own to show.
      expect(p.change24h, closeTo(200 / 1050, 1e-9));
      final Holding tether = p.holdings[1];
      expect(tether.pegged, isTrue);
      expect(tether.change24h, isNull);
    });

    test('without prices from a day ago, the day\'s move is unknown', () {
      final Portfolio offline = buildPortfolio(
        snapshot(),
        tickers: const <String, Ticker>{},
        history: DollarHistory(<Rate>[trm('4000', march)]),
      );
      expect(offline.moved24h, isNull);
      expect(offline.change24h, isNull);

      // A ticker with no price a day ago is no measurement either.
      final Portfolio unopened = buildPortfolio(
        snapshot(),
        tickers: <String, Ticker>{
          'BTC': Ticker(
            asset: 'BTC',
            price: d('100000'),
            open: Decimal.zero,
            high: d('100000'),
            low: d('100000'),
            at: DateTime(2026, 10, 2, 12),
          ),
          'USDT': Ticker.peg('USDT', DateTime(2026, 10, 2, 12)),
        },
        history: DollarHistory(<Rate>[trm('4000', march)]),
      );
      expect(unopened.holdings.first.change24h, isNull);
      expect(unopened.change24h, isNull);
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

  group('what came in with no purchase price', () {
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
      opening: d('500'),
      institution: 'Binance',
      spendable: false,
    );
    StoreSnapshot snapshot(List<Entry> entries) => StoreSnapshot(
      profile: const Profile(
        name: 'Diego',
        base: Asset.cop,
        schedule: TwiceMonthly(),
      ),
      accounts: <Account>[btc, usdt],
      entries: entries,
      recurring: const <RecurringCharge>[],
      goals: const <SavingsGoal>[],
      rates: <Rate>[trm('4000', DateTime(2026, 10, 2))],
      categories: const <CategoryItem>[],
    );
    final Map<String, Ticker> tickers = <String, Ticker>{
      'BTC': Ticker(
        asset: 'BTC',
        price: d('100000'),
        open: d('100000'),
        high: d('100000'),
        low: d('100000'),
        at: DateTime(2026, 10, 2, 12),
      ),
      'USDT': Ticker.peg('USDT', DateTime(2026, 10, 2, 12)),
    };
    final DollarHistory history = DollarHistory(<Rate>[
      trm('4000', DateTime(2026, 3, 10)),
    ]);

    test('is left out of the gain, and its value said apart', () {
      final Portfolio p = buildPortfolio(
        snapshot(<Entry>[
          // A reward with no cost, then a purchase for 3.000.000.
          Entry(
            id: 'reward',
            accountId: 'btc',
            amount: d('0.01'),
            date: DateTime(2026, 4, 1),
            kind: EntryKind.income,
          ),
          Entry(
            id: 'bought',
            accountId: 'btc',
            amount: d('0.01'),
            date: DateTime(2026, 3, 10),
            kind: EntryKind.income,
            cost: Money(d('3000000'), Asset.cop),
          ),
        ]),
        tickers: tickers,
        history: history,
      );
      final Holding bitcoin = p.holdings.first;
      expect(bitcoin.value!.base, d('8000000'));
      expect(bitcoin.uncostedValue!.base, d('4000000'));
      // 4.000.000 for what cost 3.000.000, not 8.000.000.
      expect(bitcoin.gain!.base, d('1000000'));
      expect(bitcoin.gainRatio, closeTo(1 / 3, 1e-9));
      // The tether the account started with has no cost either.
      expect(p.uncostedValue.base, d('6000000'));
      expect(p.gain!.base, d('1000000'));
      expect(p.gainRatio, closeTo(1 / 3, 1e-9));
    });

    test('with nothing of known cost, there is no gain to tell', () {
      final Portfolio p = buildPortfolio(
        snapshot(const <Entry>[]),
        tickers: tickers,
        history: history,
      );
      expect(p.gain, isNull);
      expect(p.gainRatio, isNull);
      // Only tether: its day is the peg, and that is all there is.
      expect(p.moved24h, Pair.zero);
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
    // Step by step, 10 % and then 9,09 % on what was held: 20 % in all,
    // as against the first value, since the purchase came after the rise.
    expect(points[1].ratio, closeTo(0.1, 1e-9));
    expect(points.last.ratio, closeTo(0.2, 1e-9));
  });

  test('money put in before a rise is not counted as a return', () {
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
        // Nine times as much bought while the price stood still.
        Entry(
          id: 'more',
          accountId: 'btc',
          amount: d('0.09'),
          date: DateTime(2026, 10, 1, 10, 30),
          kind: EntryKind.income,
        ),
      ],
      candles: <String, List<Candle>>{
        'BTC': <Candle>[
          Candle(t0, d('100000')),
          Candle(t1, d('100000')),
          Candle(t2, d('110000')),
        ],
      },
      dollarOn: (_) => d('4000'),
      base: Asset.cop,
    );
    // The rise made 1.000 dollars on 0,1 BTC: the whole first value, but
    // only 10 % on what was held when it came.
    expect(points.last.gain.usd, d('1000'));
    final double againstFirst =
        points.last.gain.base.toDouble() / points.first.value.base.toDouble();
    expect(againstFirst, closeTo(1, 1e-9));
    expect(points.last.ratio, closeTo(0.1, 1e-9));
  });

  test('the dollar\'s own move counts in the return in pesos', () {
    final Account usdt = Account(
      id: 'usdt',
      name: 'Tether',
      kind: AccountKind.exchange,
      asset: Asset.usdt,
      opening: d('100'),
      spendable: false,
    );
    final DateTime t0 = DateTime(2026, 9, 1);
    final DateTime t1 = DateTime(2026, 9, 2);
    final List<ValuePoint> points = valueOverTime(
      accounts: <Account>[usdt],
      entries: const <Entry>[],
      candles: <String, List<Candle>>{
        'USDT': <Candle>[Candle(t0, Decimal.one), Candle(t1, Decimal.one)],
      },
      dollarOn: (DateTime day) => day == t0 ? d('4000') : d('4200'),
      base: Asset.cop,
    );
    expect(points.last.gain, Pair(d('20000'), Decimal.zero));
    expect(points.last.ratio, closeTo(0.05, 1e-9));
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
      // Before any price, the day's move is unknown, not zero.
      expect(answer.containsKey('change24hInBase'), isTrue);
      expect(answer['change24hInBase'], isNull);
      expect(answer['change24hPercent'], isNull);
      await own.portfolio.refreshIfOlder(const Duration(minutes: 1));
      final Map<String, Object?> priced = portfolioAnswer(own);
      expect(priced['baseCurrency'], 'COP');
      expect(priced['pricesFrom'], 'Binance');
      // 0,021 BTC at 100.000 dollars and 4.000 pesos a dollar.
      expect(priced['totalValueInBase'], 8400000);
      expect(priced['totalValueInUsd'], 2100);
      expect(priced['totalCostInBase'], 6000000);
      // The 0,001 BTC with no purchase price is not gain: 0,02 BTC are
      // worth 8.000.000 and cost 6.000.000.
      expect(priced['gainInBase'], 2000000);
      expect(priced['gainPercent'], 33.33);
      expect(priced['valueWithoutCostInBase'], 400000);
      // 0,021 BTC a day ago at 98.000 dollars were worth 8.232.000.
      expect(priced['change24hInBase'], 168000);
      final Map<Object?, Object?> held =
          (priced['holdings']! as List<Object?>).single!
              as Map<Object?, Object?>;
      expect(held['quantityText'], '0,021 BTC');
      expect(held['heldWithoutCostText'], '0,001 BTC');
      expect(held['change24hPercent'], 2.04);
    });

    test('a screen that starts watching is not told while it is built', () {
      var told = 0;
      void count() => told++;
      own.portfolio.addListener(count);
      addTearDown(() => own.portfolio.removeListener(count));
      // Screens call this from initState, in the middle of a build.
      own.portfolio.watch();
      addTearDown(own.portfolio.unwatch);
      expect(told, 0);
      return Future<void>.delayed(Duration.zero, () {
        expect(told, greaterThan(0));
      });
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
