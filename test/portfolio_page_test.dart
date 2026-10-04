// The Cripto page says what each figure measures: no number where there is
// no data, one calculation for the day's move, and the currency of a total
// on a screen of many.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/portfolio/market.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/icons.dart';
import 'package:quincena/ui/kit.dart';
import 'package:quincena/ui/own/portfolio_page.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show screen, settle;
import 'portfolio_test.dart' show FakeMarket;

final DateTime _now = DateTime(2026, 10, 3, 10);

/// Prices for the day that climbed from 98.000 to 100.000 dollars a
/// bitcoin, while Binance's ticker says it opened at 97.000: two ways of
/// telling the same day that do not agree.
class CandleMarket extends FakeMarket {
  CandleMarket()
    : super(
        prices: const <String, (String, String)>{'BTC': ('100000', '97000')},
      );

  @override
  Future<List<Candle>> candles(String code, ChartRange range) async {
    if (code != 'BTC') return const <Candle>[];
    final int n = range.points;
    return <Candle>[
      for (var i = 0; i < n; i++)
        Candle(
          _now.subtract(range.step * (n - 1 - i)),
          Decimal.fromInt(98000 + (2000 * i) ~/ (n - 1)),
        ),
    ];
  }
}

/// A market that cannot be reached.
class DownMarket extends FakeMarket {
  @override
  Future<Map<String, Ticker>> tickers(Iterable<String> codes) async {
    asked++;
    return const <String, Ticker>{};
  }
}

/// The Cripto page over 0,01 BTC bought for 3.000.000, 500 USDT with no
/// purchase price and some PEPE that Binance has no price for.
Future<OwnController> openCrypto(
  WidgetTester tester,
  MarketData market, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final QuincenaStore store = (await tester.runAsync(() async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => _now,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
    );
    await store.saveRates(<Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: Decimal.fromInt(4000),
        asOf: DateTime(2026, 10, 3),
        source: 'trm',
      ),
      // What the last read left: the price, never the day's change.
      Rate(
        asset: 'BTC',
        quote: 'USDT',
        value: Decimal.fromInt(100000),
        asOf: _now,
        source: 'binance',
      ),
    ]);
    await store.addAccount(
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
      opening: Decimal.parse('0.01'),
      institution: 'Binance',
      spendable: false,
      openingCost: Money(Decimal.fromInt(3000000), Asset.cop),
    );
    await store.addAccount(
      name: 'Tether',
      kind: AccountKind.exchange,
      asset: Asset.usdt,
      opening: Decimal.fromInt(500),
      institution: 'Binance',
      spendable: false,
    );
    await store.addAccount(
      name: 'Pepe',
      kind: AccountKind.wallet,
      asset: Asset.of('PEPE'),
      opening: Decimal.fromInt(1000000),
      institution: 'MetaMask',
      spendable: false,
    );
    return store;
  }))!;
  addTearDown(() => tester.runAsync(store.close));
  final OwnController own = OwnController(
    store,
    now: () => _now,
    readNative: false,
    market: market,
  );
  addTearDown(own.dispose);
  await tester.runAsync(own.start);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: quincenaTheme(Brightness.light),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appLocales,
      home: PortfolioPage(own: own),
    ),
  );
  await settle(tester);
  // Read once more while the page looks, as its timer would.
  await tester.runAsync(own.portfolio.refresh);
  await settle(tester);
  return own;
}

/// Scrolls the page until [finder] is on screen.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await settle(tester);
}

/// The box of the figure labeled [label].
Finder figure(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Block)).first;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('without a price from a day ago, the day says there is no data', (
    tester,
  ) async {
    await openCrypto(tester, FakeMarket());

    // No "$0 · 0,00 %" that reads like a measurement.
    expect(find.text('Sin dato'), findsOneWidget);
    expect(find.text('Aún no hay precio de hace 24 horas.'), findsOneWidget);
    expect(find.textContaining('0,00 %'), findsNothing);
    // Tether's day is its peg, so it shows none.
    await reveal(tester, find.text('Sin precio'));
    expect(screen(tester), contains('500 USDT'));
    expect(screen(tester), isNot(contains('USDT ·')));
    // A coin with no price says so.
    expect(find.text('Sin precio'), findsOneWidget);
  });

  testWidgets('the day on top is the day the chart draws', (tester) async {
    await openCrypto(tester, CandleMarket());

    // 0,01 BTC from 98.000 to 100.000 dollars at 4.000 pesos: 80.000, on
    // 5.920.000 held with the tether. The ticker would have said 120.000.
    expect(find.text('+\$80.000'), findsOneWidget);
    expect(find.text('+1,35 % por precio'), findsOneWidget);
    expect(find.text('+\$120.000'), findsNothing);

    await reveal(tester, find.text('24 h'));
    await tester.tap(find.text('24 h'));
    await settle(tester);
    expect(screen(tester), contains('+\$80.000 (+1,35 %) en 24 horas'));
  });

  testWidgets('the gain is the unrealized one, on what has a known cost', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await openCrypto(tester, CandleMarket());

    expect(find.text('Ganancia no realizada'), findsOneWidget);
    // 4.000.000 for what cost 3.000.000; the tether is left out.
    expect(find.text('+\$1.000.000'), findsOneWidget);
    expect(find.text('+33,3 % sobre lo que pagaste'), findsOneWidget);
    expect(
      find.text('Sin contar \$2.000.000 que llegó sin precio de compra.'),
      findsOneWidget,
    );
    expect(find.textContaining('las comisiones de Binance'), findsOneWidget);

    // The total says its currency, on a page with dollars and coins.
    expect(find.text('\$6.000.000'), findsOneWidget);
    expect(find.text('COP'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'6\.000\.000[\s\S]*Peso colombiano')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('it says where the prices and the dollar come from, and when', (
    tester,
  ) async {
    await openCrypto(tester, CandleMarket());

    expect(
      find.textContaining('Precios de Binance del 3 oct · 10:00'),
      findsOneWidget,
    );
    expect(find.text('Pasados a pesos con la TRM del 3 oct'), findsOneWidget);
    // A read that worked needs no light.
    expect(find.byIcon(Glyph.warningCircle), findsNothing);
  });

  testWidgets('prices that could not be read warn, and can be read again', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final DownMarket market = DownMarket();
    await openCrypto(tester, market);

    expect(find.byIcon(Glyph.warningCircle), findsOneWidget);
    expect(
      find.text(
        'No se pudieron leer los precios: se muestran los últimos guardados.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Actualizar precios'), findsOneWidget);
    final int asked = market.asked;
    await tester.tap(find.text('Actualizar'));
    await settle(tester);
    expect(market.asked, asked + 1);
    semantics.dispose();
  });

  testWidgets('the two figures stand as tall as each other in large text', (
    tester,
  ) async {
    await openCrypto(tester, CandleMarket(), textScale: 2);

    expect(tester.takeException(), isNull);
    final double day = tester.getSize(figure('En 24 horas')).height;
    final double gain = tester.getSize(figure('Ganancia no realizada')).height;
    expect(day, gain);
  });

  testWidgets('over a month or a year, the note says the dollar moves too', (
    tester,
  ) async {
    await openCrypto(tester, CandleMarket());
    const String prices =
        'Solo lo que movieron los precios de tus monedas, con el dólar de '
        'hoy: comprar o vender no cambia esta línea.';
    const String withDollar =
        'Lo que movieron los precios y el dólar frente al peso: comprar o '
        'vender no cambia esta línea.';

    await reveal(tester, find.text('1 a'));
    expect(find.text(prices), findsOneWidget);
    expect(find.text(withDollar), findsNothing);

    await tester.tap(find.text('1 a'));
    await settle(tester);
    expect(find.text(withDollar), findsOneWidget);
    expect(find.text(prices), findsNothing);

    await tester.tap(find.text('7 d'));
    await settle(tester);
    expect(find.text(prices), findsOneWidget);
  });
}
