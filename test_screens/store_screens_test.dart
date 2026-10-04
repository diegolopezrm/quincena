// Renders the screenshots for the App Store and Google Play, in Spanish and
// English, with an example person: never anyone's real data.
//
// Not part of `flutter test`, like the rest of this folder. Regenerate with:
//
//   flutter test test_screens/store_screens_test.dart --update-goldens
//
// They are written straight into docs/store/screenshots.
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/portfolio/market.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/portfolio_page.dart';
import 'package:quincena/ui/own/statement_page.dart';

import '../test/fonts.dart';
import '../test/own_flow_test.dart' show fakeRates, settle;

final DateTime _now = DateTime(2026, 10, 3, 10);
Decimal d(String s) => Decimal.parse(s);

/// The stores' sizes, in logical pixels and the ratio that makes them: the
/// App Store's 6.9-inch iPhone, 1320 by 2868, and 13-inch iPad, 2064 by
/// 2752, and Google Play's phone, 1080 by 2400.
const Map<String, (Size, double)> stores = <String, (Size, double)>{
  'appstore': (Size(440, 956), 3),
  'appstore-ipad': (Size(1032, 1376), 2),
  'play': (Size(360, 800), 3),
};

/// Market data for the screenshots: prices that moved a little over the
/// week, the way markets do.
class ExampleMarket extends MarketData {
  static const Map<String, (String, String)> _prices =
      <String, (String, String)>{
        'BTC': ('84616.92', '83102.40'),
        'ETH': ('2678.00', '2701.50'),
      };

  @override
  Future<Map<String, Ticker>> tickers(Iterable<String> codes) async =>
      <String, Ticker>{
        for (final String c in codes)
          if (c == 'USDT')
            c: Ticker.peg(c, _now)
          else if (_prices[c] case (final String now, final String open))
            c: Ticker(
              asset: c,
              price: d(now),
              open: d(open),
              high: d(now),
              low: d(open),
              at: _now,
            ),
      };

  @override
  Future<List<Candle>> candles(String code, ChartRange range) async {
    final (String now, String _) = _prices[code] ?? ('1', '1');
    final double last = double.parse(now);
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
          _now.subtract(range.step * i),
          Decimal.parse(at(i).toStringAsFixed(2)),
        ),
    ];
  }

  @override
  Future<List<Rate>> dollarHistory(Asset base, DateTime from) async => <Rate>[
    for (
      var day = DateTime(2026, 1, 1);
      !day.isAfter(_now);
      day = DateTime(day.year, day.month, day.day + 1)
    )
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: d('3312.84'),
        asOf: day,
        source: 'trm',
      ),
  ];
}

/// Valentina's money: a designer in Medellín paid twice a month, with pesos
/// in two banks, a card, dollars, and some crypto on Binance.
Future<QuincenaStore> example() async {
  final QuincenaStore store = QuincenaStore(
    QuincenaDatabase(NativeDatabase.memory()),
    now: () => _now,
  );
  await store.ensureCategories();
  await store.saveProfile(
    const Profile(name: 'Valentina', base: Asset.cop, schedule: TwiceMonthly()),
  );
  await store.setSetting('app.mode', 'own');
  await store.saveRates(<Rate>[
    Rate(
      asset: 'USD',
      quote: 'COP',
      value: d('3312.84'),
      asOf: DateTime(2026, 10, 3),
      source: 'trm',
    ),
    Rate(
      asset: 'BTC',
      quote: 'USDT',
      value: d('84616.92'),
      asOf: _now,
      source: 'binance',
    ),
    Rate(
      asset: 'ETH',
      quote: 'USDT',
      value: d('2678'),
      asOf: _now,
      source: 'binance',
    ),
  ]);
  final Account bank = await store.addAccount(
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: d('820000'),
    institution: 'Bancolombia',
  );
  final Account nequi = await store.addAccount(
    name: 'Nequi',
    kind: AccountKind.wallet,
    asset: Asset.cop,
    opening: d('35000'),
    institution: 'Nequi',
  );
  final Account card = await store.addAccount(
    name: 'Visa',
    kind: AccountKind.card,
    asset: Asset.cop,
    opening: d('-480000'),
    institution: 'Bancolombia',
  );
  await store.addAccount(
    name: 'Cuenta en dólares',
    kind: AccountKind.bank,
    asset: Asset.usd,
    opening: d('1250'),
    institution: 'Global66',
    spendable: false,
  );
  final Account usdt = await store.addAccount(
    name: 'Tether',
    kind: AccountKind.exchange,
    asset: Asset.usdt,
    opening: d('1520.5'),
    institution: 'Binance',
    openingCost: Money(d('4900000'), Asset.cop),
  );
  await store.addAccount(
    name: 'Bitcoin',
    kind: AccountKind.exchange,
    asset: Asset.btc,
    opening: d('0.0123'),
    institution: 'Binance',
    openingCost: Money(d('3000000'), Asset.cop),
  );
  await store.addAccount(
    name: 'Ether',
    kind: AccountKind.exchange,
    asset: Asset.eth,
    opening: d('0.35'),
    institution: 'Binance',
    openingCost: Money(d('2900000'), Asset.cop),
  );

  Future<void> spend(
    Account a,
    String amount,
    int day,
    String category,
    String payee,
  ) => store.addEntry(
    accountId: a.id,
    amount: d(amount),
    kind: EntryKind.expense,
    date: DateTime(2026, day > 3 ? 9 : 10, day, 12),
    category: category,
    payee: payee,
  );
  await store.addEntry(
    accountId: bank.id,
    amount: d('2400000'),
    kind: EntryKind.income,
    date: DateTime(2026, 9, 30, 8),
    category: 'salary',
    payee: 'Nómina',
  );
  await spend(bank, '1650000', 5, 'housing', 'Arriendo octubre');
  await spend(bank, '187400', 2, 'groceries', 'Éxito Laureles');
  await spend(nequi, '23500', 3, 'restaurants', 'Crepes & Waffles');
  await spend(card, '42900', 2, 'shopping', 'Falabella');
  await spend(bank, '15600', 1, 'transport', 'Uber');
  await spend(bank, '119000', 1, 'subscriptions', 'Fit24 gimnasio');
  await spend(nequi, '9800', 3, 'transport', 'Metro de Medellín');
  await store.addTransfer(
    fromAccountId: bank.id,
    toAccountId: usdt.id,
    sent: d('400000'),
    received: d('118.2'),
    date: DateTime(2026, 10, 1, 18),
  );
  await store.addRecurring(
    name: 'Netflix',
    amount: Money(d('26900'), Asset.cop),
    cadence: Cadence.monthly,
    nextDate: DateTime(2026, 10, 12),
    accountId: card.id,
    category: 'subscriptions',
  );
  await CaptureService(store, now: () => _now).ingest(<CaptureEvent>[
    CaptureEvent(
      source: CaptureSource.notification,
      at: DateTime(2026, 10, 3, 8, 12),
      app: 'com.nequi.MobileApp',
      appName: 'Nequi',
      title: 'Nequi',
      text: r'Nequi · Laura Gómez te envió $85.000',
    ),
    CaptureEvent(
      source: CaptureSource.notification,
      at: DateTime(2026, 10, 3, 9, 40),
      app: 'com.todo1.mobile',
      appName: 'Bancolombia',
      title: 'Bancolombia',
      text: r'Bancolombia · Compra por $63.200 en EXITO LAURELES T.Deb *1234',
    ),
  ]);
  return store;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  tearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });

  void device(WidgetTester tester, (Size, double) screen, String language) {
    final (Size size, double ratio) = screen;
    tester.view.physicalSize = size * ratio;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = <Locale>[Locale(language)];
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    Intl.defaultLocale = language == 'en' ? 'en_US' : 'es_CO';
  }

  Future<void> shoot(String store, String language, String name) => expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile('../docs/store/screenshots/$store/$language/$name.png'),
  );

  for (final MapEntry<String, (Size, double)> s in stores.entries) {
    for (final String language in <String>['es', 'en']) {
      final String tag = '${s.key} $language';

      testWidgets('answer $tag', (tester) async {
        device(tester, s.value, language);
        final Session session = Session(thinking: Duration.zero);
        addTearDown(session.dispose);
        await tester.pumpWidget(QuincenaApp(session: session));
        await tester.pumpAndSettle();
        final Future<void> answered = session.ask(
          ScriptedAgent.startersFor(language)[1],
        );
        await tester.pumpAndSettle();
        await answered;
        await shoot(s.key, language, '01-answer');
      });

      testWidgets('own $tag', (tester) async {
        device(tester, s.value, language);
        final QuincenaStore store = (await tester.runAsync(example))!;
        addTearDown(() => tester.runAsync(store.close));
        await tester.pumpWidget(
          QuincenaApp(
            store: store,
            startInDemo: false,
            fetcher: fakeRates(),
            now: () => _now,
          ),
        );
        await settle(tester);
        await shoot(s.key, language, '02-home');
        await tester.tap(
          find.byTooltip(language == 'en' ? 'Needs review' : 'Por revisar'),
        );
        await settle(tester);
        await shoot(s.key, language, '03-inbox');
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await settle(tester);
        await tester.tap(
          find.text(language == 'en' ? 'Accounts' : 'Cuentas').last,
        );
        await settle(tester);
        await shoot(s.key, language, '06-accounts');
      });

      testWidgets('crypto and statements $tag', (tester) async {
        device(tester, s.value, language);
        final QuincenaStore store = (await tester.runAsync(example))!;
        addTearDown(() => tester.runAsync(store.close));
        final OwnController own = OwnController(
          store,
          now: () => _now,
          readNative: false,
          market: ExampleMarket(),
        );
        addTearDown(own.dispose);
        await tester.runAsync(own.start);
        Widget app(Widget home) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: quincenaTheme(Brightness.light),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
          home: home,
        );
        await tester.pumpWidget(app(PortfolioPage(own: own)));
        await settle(tester);
        await tester.runAsync(() => own.portfolio.refresh());
        await tester.runAsync(() => own.portfolio.loadChart(ChartRange.week));
        await settle(tester);
        await shoot(s.key, language, '04-crypto');

        final Account bank = own.accounts.firstWhere(
          (Account a) => a.name == 'Bancolombia',
        );
        await tester.pumpWidget(
          app(
            StatementPage(
              own: own,
              accountId: bank.id,
              statement: readTable(
                parseCsv(
                  'Fecha;Descripción;Valor;Saldo\n'
                  '28/09/2026;COMPRA EN D1 LAURELES;-32.400;1.245.600\n'
                  '27/09/2026;PAGO PSE CLARO HOGAR;-98.900;1.278.000\n'
                  '26/09/2026;TRANSFERENCIA DE CAMILO RIOS;150.000;1.376.900\n'
                  '25/09/2026;COMPRA EN RAPPI RESTAURANTES;-41.500;1.226.900\n'
                  '24/09/2026;PAGO TARJETA VISA;-480.000;1.268.400\n'
                  '23/09/2026;COMPRA EN TERPEL LAS PALMAS;-120.000;1.748.400\n',
                ),
              ),
            ),
          ),
        );
        await settle(tester);
        await shoot(s.key, language, '05-statement');
      });
    }
  }
}
