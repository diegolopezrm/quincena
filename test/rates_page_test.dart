import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rate_sources.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/free_explained.dart';

import 'own_flow_test.dart' show fakeRates, settle;

Decimal d(String s) => Decimal.parse(s);

/// Every source down, as when the phone is offline.
RateFetcher downRates() =>
    RateFetcher(client: MockClient((_) async => http.Response('', 500)));

void main() {
  final DateTime now = DateTime(2026, 10, 4, 10);
  late QuincenaStore store;

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// The rates page for someone with an account in [held], and its rate
  /// typed by hand when [typed]: a dollar in pesos, a coin in dollars.
  Future<OwnController> open(
    WidgetTester tester, {
    required RateFetcher fetcher,
    Asset held = Asset.usd,
    String? typed,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      fetcher: fetcher,
      now: () => now,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await store.addAccount(
        name: held.code,
        kind: held.isCrypto ? AccountKind.wallet : AccountKind.bank,
        asset: held,
        opening: d(held.isCrypto ? '0.01' : '100'),
        spendable: false,
      );
      if (typed != null) {
        await store.setManualRate(
          held.code,
          held.isCrypto ? 'USD' : 'COP',
          d(typed),
        );
      }
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: RatesPage(own: own),
      ),
    );
    await settle(tester);
    return own;
  }

  Future<Rate> storedDollar(WidgetTester tester) async =>
      (await tester.runAsync(
        store.rates,
      ))!.firstWhere((Rate r) => r.pair == 'USD/COP');

  testWidgets('a rate typed by hand says so, and goes back to the automatic', (
    tester,
  ) async {
    await open(tester, fetcher: fakeRates(), typed: '3400');

    expect(find.text(r'1 USD = $3.400'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Escrita a mano el 4 oct'), findsOneWidget);
    // Its one step is the line above: not said twice.
    expect(find.textContaining('· escrita a mano'), findsNothing);
    // The fetch on opening brought the TRM, which did not replace it.
    expect(find.text(r'La automática hoy: $4.000'), findsOneWidget);
    expect((await storedDollar(tester)).manual, isTrue);

    await tester.tap(find.text('Usar la automática'));
    await settle(tester);

    expect(find.text(r'1 USD = $4.000'), findsOneWidget);
    expect(find.textContaining('TRM oficial'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
    expect(find.text('Usar la automática'), findsNothing);
    final Rate dollar = await storedDollar(tester);
    expect(dollar.manual, isFalse);
    expect(dollar.value, d('4000'));
  });

  testWidgets('offline, the typed rate stays and a notice says why', (
    tester,
  ) async {
    await open(tester, fetcher: downRates(), typed: '3400');

    // From the dialog, the long way back.
    await tester.tap(find.text(r'1 USD = $3.400'));
    await settle(tester);
    await tester.tap(find.text('Volver a la tasa automática'));
    await settle(tester);

    expect(
      find.text(
        'No se pudo traer la tasa automática. Sigue la tuya; intenta de '
        'nuevo con conexión.',
      ),
      findsOneWidget,
    );
    expect(find.text(r'1 USD = $3.400'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.textContaining('Sin tasa'), findsNothing);
    final Rate dollar = await storedDollar(tester);
    expect(dollar.manual, isTrue);
    expect(dollar.value, d('3400'));
  });

  testWidgets('an automatic rate has nothing to go back to', (tester) async {
    await open(tester, fetcher: fakeRates());

    expect(find.text(r'1 USD = $4.000'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
    expect(find.text('Usar la automática'), findsNothing);

    await tester.tap(find.text(r'1 USD = $4.000'));
    await settle(tester);
    expect(find.text('Escribir una tasa'), findsOneWidget);
    expect(find.text('Volver a la tasa automática'), findsNothing);

    // Saving an empty field keeps the rate rather than dropping it.
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(find.text(r'1 USD = $4.000'), findsOneWidget);
    expect((await storedDollar(tester)).source, 'trm');
  });

  testWidgets('a coin shows its market price apart from the pesos', (
    tester,
  ) async {
    await open(tester, fetcher: fakeRates(), held: Asset.btc);

    // 80.000 tether a bitcoin, tether as a dollar, 4.000 pesos a dollar.
    final List<Finder> lines = <Finder>[
      find.text(r'1 BTC = $320.000.000'),
      find.textContaining('Precio de mercado: 1 BTC = 80.000 USDT · Binance, '),
      find.text(r'USDT se cuenta como 1 US$'),
      find.text(r'Conversión a COP: 1 US$ = $4.000 · TRM oficial del 3 oct'),
    ];
    for (final Finder line in lines) {
      expect(line, findsOneWidget);
    }
    final List<double> tops = <double>[
      for (final Finder line in lines) tester.getTopLeft(line).dy,
    ];
    expect(tops, orderedEquals(<double>[...tops]..sort()));
  });

  testWidgets('a coin priced by hand keeps the dollar step automatic', (
    tester,
  ) async {
    await open(tester, fetcher: fakeRates(), held: Asset.btc, typed: '90000');

    expect(find.text(r'1 BTC = $360.000.000'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text(r'1 BTC = US$90.000 · escrita a mano'), findsOneWidget);
    expect(
      find.text(r'Conversión a COP: 1 US$ = $4.000 · TRM oficial del 3 oct'),
      findsOneWidget,
    );
    expect(find.textContaining('Precio de mercado'), findsNothing);
    expect(find.text(r'La automática hoy: US$80.000'), findsOneWidget);
  });

  test('the sheets explain a conversion with the same steps', () {
    final AppLocalizations l = lookupAppLocalizations(const Locale('es'));
    final RateTable rates = RateTable(<Rate>[
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
        value: d('84791.98'),
        asOf: DateTime(2026, 10, 3, 10),
        source: 'binance',
      ),
    ]);
    expect(
      conversionDetail(
        l,
        rates,
        Money(d('0.0123'), Asset.btc),
        Asset.cop,
      ).split('\n'),
      <String>[
        '0,0123 BTC a \$280.902.263,02',
        'Precio de mercado: 1 BTC = 84.791,98 USDT · Binance, '
            '${dayAndTime(DateTime(2026, 10, 3, 10))}',
        r'USDT se cuenta como 1 US$',
        r'Conversión a COP: 1 US$ = $3.312,84 · TRM oficial del 3 oct',
      ],
    );
  });
}
