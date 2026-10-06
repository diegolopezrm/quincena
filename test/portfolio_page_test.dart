// The Cripto page says what each figure measures: no number where there is
// no data, one calculation for the day's move, and the currency of a total
// on a screen of many.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/exchanges/binance_link.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/portfolio/market.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/icons.dart';
import 'package:quincena/ui/kit.dart';
import 'package:quincena/ui/own/portfolio_chart.dart';
import 'package:quincena/ui/own/portfolio_page.dart';
import 'package:quincena/ui/own/position_panel.dart';

import 'binance_page_test.dart' show MemoryVault;
import 'fonts.dart';
import 'own_flow_test.dart' show screen, settle;
import 'portfolio_test.dart' show FakeMarket;

final DateTime _now = DateTime(2026, 10, 3, 10);

/// [moment] as [screen] reads it, with a plain space before `a. m.`.
String _seen(DateTime moment) => dayAndTime(moment).replaceAll('\u00a0', ' ');

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

/// A market that cannot be reached, where tether still draws its flat line
/// at one dollar, as [MarketData.candles] draws it without asking anyone.
class OfflineMarket extends DownMarket {
  @override
  Future<List<Candle>> candles(String code, ChartRange range) async {
    if (code != 'USDT') return const <Candle>[];
    return <Candle>[
      for (var i = range.points - 1; i >= 0; i--)
        Candle(_now.subtract(range.step * i), Decimal.one),
    ];
  }
}

/// The Cripto page over 0,01 BTC bought for 3.000.000, 500 USDT with no
/// purchase price and some PEPE that Binance has no price for, all written
/// by hand but, with [syncedTether], the tether; plus whatever [data] adds.
Future<OwnController> openCrypto(
  WidgetTester tester,
  MarketData market, {
  double textScale = 1,
  bool reward = false,
  Asset base = Asset.cop,
  bool syncedTether = false,
  Future<void> Function(QuincenaStore store)? data,
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
      Profile(name: 'Ana', base: base, schedule: const TwiceMonthly()),
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
    final Account bitcoin = await store.addAccount(
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
      opening: Decimal.parse('0.01'),
      institution: 'Binance',
      spendable: false,
      openingCost: Money(Decimal.fromInt(3000000), Asset.cop),
    );
    // As much again, from a reward with no purchase price.
    if (reward) {
      await store.addEntry(
        accountId: bitcoin.id,
        amount: Decimal.parse('0.01'),
        kind: EntryKind.income,
        date: DateTime(2026, 9, 1),
      );
    }
    await store.addAccount(
      name: 'Tether',
      kind: AccountKind.exchange,
      asset: Asset.usdt,
      opening: Decimal.fromInt(500),
      institution: 'Binance',
      spendable: false,
      syncRef: syncedTether ? 'binance:USDT' : null,
    );
    await store.addAccount(
      name: 'Pepe',
      kind: AccountKind.wallet,
      asset: Asset.of('PEPE'),
      opening: Decimal.fromInt(1000000),
      institution: 'MetaMask',
      spendable: false,
    );
    await data?.call(store);
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
    expect(find.textContaining('0,00\u00a0%'), findsNothing);
    // Tether's day is its peg, so it shows none.
    await reveal(tester, find.text('Sin precio'));
    expect(screen(tester), contains('500 USDT'));
    expect(screen(tester), isNot(contains('USDT ·')));
    // A coin with no price says so.
    expect(find.text('Sin precio'), findsOneWidget);
  });

  testWidgets('offline, a chart of tether alone is not a day without change', (
    tester,
  ) async {
    final OwnController own = await openCrypto(tester, OfflineMarket());

    // Bitcoin keeps the last price saved, but nothing says how it moved.
    expect(own.portfolio.day, isNull);
    expect(find.text('Sin dato'), findsOneWidget);
    expect(find.textContaining('0,00\u00a0%'), findsNothing);
    expect(portfolioAnswer(own)['change24hInBase'], isNull);
  });

  testWidgets('the day on top is the day the chart draws', (tester) async {
    await openCrypto(tester, CandleMarket());

    // 0,01 BTC from 98.000 to 100.000 dollars at 4.000 pesos: 80.000, on
    // 5.920.000 held with the tether. The ticker would have said 120.000.
    expect(find.text('+$signJoiner\$80.000'), findsOneWidget);
    expect(find.text('+1,35\u00a0% por precio'), findsOneWidget);
    expect(find.text('+$signJoiner\$120.000'), findsNothing);

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
    expect(find.text('+$signJoiner\$1.000.000'), findsOneWidget);
    expect(find.text('+33,3\u00a0% sobre lo que pagaste'), findsOneWidget);
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

  testWidgets('one account tells its gain the way the page does', (
    tester,
  ) async {
    final OwnController own = await openCrypto(
      tester,
      CandleMarket(),
      reward: true,
    );
    final Account bitcoin = own.accounts.firstWhere(
      (Account a) => a.asset == Asset.btc,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: Scaffold(
          body: PositionPanel(own: own, account: bitcoin),
        ),
      ),
    );
    await settle(tester);

    // 0,02 BTC worth 8.000.000, half of it bought for 3.000.000 and half a
    // reward: the gain and the average are on the half that was bought.
    expect(screen(tester), contains('\$8.000.000'));
    expect(screen(tester), contains('+\$1.000.000 · +33,3 %'));
    expect(screen(tester), contains('\$300.000.000'));
    expect(
      find.text('Sin contar \$4.000.000 que llegó sin precio de compra.'),
      findsOneWidget,
    );
  });

  testWidgets('with nothing held, it offers the ways to bring crypto in', (
    tester,
  ) async {
    await openCrypto(
      tester,
      FakeMarket(),
      data: (QuincenaStore store) async {
        // Everything sold: crypto accounts at zero hold nothing.
        for (final Account a in await store.accounts()) {
          await store.addEntry(
            accountId: a.id,
            amount: -a.opening,
            kind: EntryKind.expense,
            date: DateTime(2026, 10, 2),
            cost: Money(Decimal.fromInt(1000), Asset.cop),
          );
        }
      },
    );
    expect(
      find.text(
        'Aún no tienes cripto. Agrega una billetera o conecta Binance.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tu cripto vale'), findsNothing);
    // What the words name is there to tap.
    expect(find.text('Billeteras propias'), findsOneWidget);
    expect(find.text('Binance'), findsOneWidget);
    await tester.tap(find.text('Billeteras propias'));
    await settle(tester);
    expect(find.text('Aún no sigues ninguna billetera.'), findsOneWidget);
  });

  testWidgets('the total is its coins added up, each as its row shows it', (
    tester,
  ) async {
    final OwnController own = await openCrypto(
      tester,
      FakeMarket(
        prices: const <String, (String, String)>{
          'BTC': ('84616.92', '83102.40'),
        },
      ),
      data: (QuincenaStore store) async {
        await store.saveRates(<Rate>[
          Rate(
            asset: 'USD',
            quote: 'COP',
            value: Decimal.parse('3312.84'),
            asOf: DateTime(2026, 10, 3),
            source: 'trm',
          ),
        ]);
        await store.addAccount(
          name: 'Tether suelto',
          kind: AccountKind.exchange,
          asset: Asset.usdt,
          opening: Decimal.parse('0.5'),
          institution: 'Binance',
          spendable: false,
        );
      },
    );

    // 2.803.223,17 + 1.656.420 + 1.656,42: each coin rounds to the peso in
    // its row and in Cuentas, and the total adds those, not the cents
    // under them, which would make it 4.461.300.
    var rows = Decimal.zero;
    for (final Account a in own.accounts) {
      if (own.partOfTotal(a) case final Money part) rows += part.amount;
    }
    expect(rows, Decimal.parse('4461299'));
    expect(find.text('\$4.461.299'), findsOneWidget);
    expect(find.text('\$4.461.300'), findsNothing);
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

    // Nothing further down overflows either: the price line and its
    // button, the coins with no price, the notes.
    await reveal(tester, find.textContaining('asesoría de inversión'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('in another currency, nothing speaks of pesos', (tester) async {
    await openCrypto(tester, CandleMarket(), base: Asset.eur);

    expect(
      find.text(
        'Lo que vale hoy lo que aún tienes menos lo que pagaste por eso. '
        'Incluye las comisiones de Binance; lo que ya vendiste va aparte.',
      ),
      findsOneWidget,
    );
    await reveal(tester, find.text('1 a'));
    await tester.tap(find.text('1 a'));
    await settle(tester);
    expect(
      find.text(
        'Lo que movieron los precios y el dólar frente a tu moneda: comprar '
        'o vender no cambia esta línea.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('peso'), findsNothing);
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
  testWidgets('the chart and the coins come before where they are read from', (
    tester,
  ) async {
    await openCrypto(tester, CandleMarket());
    // Tall enough for the whole page at once.
    tester.view.physicalSize = const Size(1080, 9000);
    await settle(tester);

    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    expect(top('Rendimiento'), lessThan(top('BINANCE')));
    expect(top('BINANCE'), lessThan(top('METAMASK')));
    expect(top('METAMASK'), lessThan(top('DISTRIBUCIÓN')));
    expect(top('DISTRIBUCIÓN'), lessThan(top('GESTIONAR FUENTES')));
    expect(top('GESTIONAR FUENTES'), lessThan(top('Billeteras propias')));
    expect(
      top('Billeteras propias'),
      lessThan(
        top(
          'Precios de mercado de Binance, que cambian a cada '
          'momento. Quincena no da asesoría de inversión.',
        ),
      ),
    );
    // Among the sources, no list of promises: Binance's own page has it.
    expect(find.text('No permite retiros'), findsNothing);
  });

  testWidgets('a balance written by hand says so, and connecting Binance '
      'says why', (tester) async {
    await openCrypto(tester, CandleMarket());
    tester.view.physicalSize = const Size(1080, 9000);
    await settle(tester);

    // Once for each place, as every coin in it was written by hand.
    expect(find.text('Anotado a mano: no se actualiza solo'), findsNWidgets(2));
    expect(
      find.text(
        'Tus saldos de Binance están anotados a mano. Conéctala para que se '
        'actualicen solos.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('coins of one place read different ways each say their own', (
    tester,
  ) async {
    await openCrypto(tester, CandleMarket(), syncedTether: true);
    tester.view.physicalSize = const Size(1080, 9000);
    await settle(tester);

    final String text = screen(tester);
    // Binance holds a coin kept by hand and one it reads: each says so.
    expect(
      text,
      contains(
        'Bitcoin\n0,01 BTC · +3,09 % 24 h\nAnotado a mano: no se '
        'actualiza solo',
      ),
    );
    // Read from Binance, with no key here: it says so, as the sources do.
    expect(text, contains('500 USDT\nLeída de Binance · sin conectar'));
    expect(text, isNot(contains('Conectada a Binance')));
    // MetaMask's one coin says it once, for the place.
    expect(text, contains('Anotado a mano: no se actualiza solo\nPEPE'));
    expect(find.text('Anotado a mano: no se actualiza solo'), findsNWidgets(2));
  });

  testWidgets('a coin read from an address says when, and once the address '
      'is no longer followed, says that instead', (tester) async {
    await openCrypto(
      tester,
      CandleMarket(),
      data: (QuincenaStore store) async {
        // Read a moment ago: the page does not read it again.
        await store.setSetting(
          'wallets',
          jsonEncode(<String, Object?>{
            'wallets': <Object?>[
              <String, Object?>{
                'chain': 'bitcoin',
                'address': 'bc1qfollowed',
                'label': 'Ledger',
              },
            ],
            'syncedAt': _now.toIso8601String(),
          }),
        );
        for (final (String place, String address) in <(String, String)>[
          ('Ledger', 'bc1qfollowed'),
          ('Trezor', 'bc1qstopped'),
        ]) {
          await store.addAccount(
            name: 'Bitcoin',
            kind: AccountKind.wallet,
            asset: Asset.btc,
            opening: Decimal.parse('0.001'),
            institution: place,
            spendable: false,
            syncRef: 'wallet:bitcoin:$address:BTC',
          );
        }
      },
    );
    tester.view.physicalSize = const Size(1080, 9000);
    await settle(tester);

    final String read = 'Por dirección pública · leída ${dayAndTime(_now)}';
    const String stopped = 'Leída por dirección pública · ya no la sigues';
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('LEDGER'), lessThan(top(read)));
    expect(top(read), lessThan(top('TREZOR')));
    expect(top('TREZOR'), lessThan(top(stopped)));
  });

  test('a coin read from Binance says when while the key is here, and that '
      'it is not connected once the key goes', () async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => _now,
    );
    addTearDown(store.close);
    await store.setSetting(
      'binance',
      jsonEncode(<String, Object?>{'syncedAt': _now.toIso8601String()}),
    );
    final Account btc = await store.addAccount(
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
      opening: Decimal.parse('0.01'),
      institution: 'Binance',
      syncRef: 'binance:BTC',
    );
    final OwnController own = OwnController(
      store,
      now: () => _now,
      readNative: false,
      binance: BinanceLink(
        store,
        vault: MemoryVault(('key', 'secret')),
        now: () => _now,
      ),
    );
    addTearDown(own.dispose);
    final AppLocalizations l = lookupAppLocalizations(const Locale('es'));

    // Not read yet: nothing rather than a guess.
    expect(holdingSourceText(l, own, btc), isNull);
    await own.binance.load();
    expect(
      holdingSourceText(l, own, btc),
      'Conectada a Binance · leída ${dayAndTime(_now)}',
    );
    // What it brought stays, and no longer updates from here.
    await own.binance.disconnect();
    expect(holdingSourceText(l, own, btc), 'Leída de Binance · sin conectar');
  });

  testWidgets('dragging along the chart shows each moment and what it was, '
      'and letting go brings the range back', (tester) async {
    await openCrypto(tester, CandleMarket());
    const String hint =
        'Toca la línea y desliza el dedo para ver cada momento.';
    expect(find.text(hint), findsOneWidget);
    expect(find.text('Ahora'), findsOneWidget);
    // Zero is drawn while the chart shows what prices made.
    expect(find.text('0 = como empezó el periodo'), findsOneWidget);
    // A week of hourly closes: the first one, 167 hours ago.
    final DateTime start = _now.subtract(const Duration(hours: 167));
    expect(find.text(dayShortMonth(start)), findsOneWidget);

    final Rect line = tester.getRect(
      find
          .descendant(
            of: find.byType(PortfolioChart),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final TestGesture finger = await tester.startGesture(
      line.centerLeft + const Offset(0.4, 0),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(screen(tester), contains('${_seen(start)}: \$0 desde el inicio'));
    for (var i = 0; i < 10; i++) {
      await finger.moveBy(Offset(line.width / 10, 0));
      await tester.pump();
    }
    // The end of the line: what prices made over the week.
    expect(
      screen(tester),
      contains('${_seen(_now)}: +\$80.000 desde el inicio'),
    );
    expect(screen(tester), isNot(contains('en 7 días')));

    await finger.up();
    await settle(tester);
    expect(screen(tester), contains('+\$80.000 (+1,35 %) en 7 días'));
    expect(find.textContaining('desde el inicio'), findsNothing);
    // Tried once, the hint goes.
    expect(find.text(hint), findsNothing);

    // The value, at the first moment: the bitcoin and the tether then.
    await tester.tap(find.text('Valor'));
    await settle(tester);
    expect(find.text('0 = como empezó el periodo'), findsNothing);
    final TestGesture again = await tester.startGesture(
      line.centerLeft + const Offset(0.4, 0),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(screen(tester), contains('${_seen(start)}: valía \$5.920.000'));
    await again.up();
    await settle(tester);
    expect(find.textContaining('valía'), findsNothing);

    // A quick tap lifts as soon as it lands: the range comes back too.
    await tester.tapAt(line.center);
    await settle(tester);
    expect(find.textContaining('valía'), findsNothing);
  });

  testWidgets('over a year, the chart says the year of each day', (
    tester,
  ) async {
    await openCrypto(tester, CandleMarket());
    await reveal(tester, find.text('1 a'));
    await tester.tap(find.text('1 a'));
    await settle(tester);
    // A year of daily closes: the first one is in 2025.
    final DateTime start = _now.subtract(
      ChartRange.year.step * (ChartRange.year.points - 1),
    );
    expect(start.year, 2025);
    expect(find.text(shortDate(start)), findsOneWidget);

    await tester.ensureVisible(find.byType(PortfolioChart));
    await settle(tester);
    final Rect line = tester.getRect(
      find
          .descendant(
            of: find.byType(PortfolioChart),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final TestGesture finger = await tester.startGesture(
      line.centerLeft + const Offset(0.4, 0),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      screen(tester),
      contains('${shortDate(start)}: \$0 desde el inicio'),
    );
    await finger.up();
    await settle(tester);
  });

  testWidgets('a screen reader steps through the chart\'s moments', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await openCrypto(tester, CandleMarket());
    final SemanticsNode node = tester.getSemantics(find.byType(PortfolioChart));
    expect(
      node.label,
      'Ganancia por precio en 7 días: +$signJoiner\$80.000, +1,35\u00a0%',
    );
    expect(
      node.value,
      '${dayAndTime(_now)}: +$signJoiner\$80.000 desde el inicio',
    );

    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await settle(tester);
    final DateTime hourBefore = _now.subtract(const Duration(hours: 1));
    expect(
      tester.getSemantics(find.byType(PortfolioChart)).value,
      startsWith('${dayAndTime(hourBefore)}: +$signJoiner\$'),
    );
    semantics.dispose();
  });
}
