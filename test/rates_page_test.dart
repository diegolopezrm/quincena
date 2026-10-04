import 'dart:async';
import 'dart:convert';

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

import 'fonts.dart';
import 'own_flow_test.dart' show fakeRates, settle;

Decimal d(String s) => Decimal.parse(s);

/// Every source down, as when the phone is offline.
RateFetcher downRates() =>
    RateFetcher(client: MockClient((_) async => http.Response('', 500)));

void main() {
  final DateTime now = DateTime(2026, 10, 4, 10);
  late DateTime clock;
  late QuincenaStore store;

  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  setUp(() => clock = now);

  /// The rates page for someone with an account in [held], and its rate
  /// typed by hand when [typed]: a dollar in pesos, a coin in dollars. The
  /// Cuentas tab instead when [tab]. [others] are more accounts, with no
  /// rate typed. When [large], on the smallest common phone with the text
  /// at twice its size.
  Future<OwnController> open(
    WidgetTester tester, {
    required RateFetcher fetcher,
    Asset held = Asset.usd,
    String? typed,
    bool tab = false,
    List<Asset> others = const <Asset>[],
    Brightness brightness = Brightness.light,
    bool large = false,
  }) async {
    tester.view.physicalSize = large
        ? const Size(1080, 2400)
        : const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (large) {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => clock,
    );
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      fetcher: fetcher,
      now: () => clock,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      for (final Asset a in <Asset>[held, ...others]) {
        await store.addAccount(
          name: a.code,
          kind: a.isCrypto ? AccountKind.wallet : AccountKind.bank,
          asset: a,
          opening: d(a.isCrypto ? '0.01' : '100'),
          spendable: false,
        );
      }
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
        theme: quincenaTheme(brightness),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: tab
            ? Scaffold(
                body: ListenableBuilder(
                  listenable: own,
                  builder: (BuildContext context, _) =>
                      SingleChildScrollView(child: AccountsTab(own: own)),
                ),
              )
            : RatesPage(own: own),
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

  testWidgets('going back waits for its fetch before it can be asked again', (
    tester,
  ) async {
    Completer<void>? gate;
    final RateFetcher slow = RateFetcher(
      client: MockClient((http.Request request) async {
        await gate?.future;
        if (request.url.host != 'www.datos.gov.co') {
          return http.Response('{}', 404);
        }
        return http.Response(
          jsonEncode(<Object>[
            <String, String>{
              'valor': '4000',
              'vigenciadesde': '2026-10-03T00:00:00.000',
            },
          ]),
          200,
        );
      }),
    );
    await open(tester, fetcher: slow, typed: '3400');

    gate = Completer<void>();
    await tester.tap(find.text('Usar la automática'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Usar la automática'),
          )
          .onPressed,
      isNull,
    );
    // The typed rate holds until the automatic one is here.
    expect(find.text(r'1 USD = $3.400'), findsOneWidget);

    gate.complete();
    await settle(tester);
    expect(find.text(r'1 USD = $4.000'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
  });

  testWidgets('the automatic rate beside a typed one is only today\'s', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      fetcher: fakeRates(),
      typed: '3400',
    );
    expect(own.fetchedRate(Asset.usd, Asset.cop), d('4000'));
    expect(find.text(r'La automática hoy: $4.000'), findsOneWidget);

    // The next morning, before anything is fetched again.
    clock = now.add(const Duration(days: 1));
    expect(own.fetchedRate(Asset.usd, Asset.cop), isNull);
  });

  testWidgets('Cuentas folds the rates into one row that opens them', (
    tester,
  ) async {
    await open(tester, fetcher: fakeRates(), typed: '3400', tab: true);

    expect(find.text('Ver tasas usadas'), findsOneWidget);
    // Only the typed dollar is in use, which is a rate, not "none yet".
    expect(find.text('1 tasa escrita a mano'), findsOneWidget);
    expect(find.textContaining('Aún sin tasas'), findsNothing);
    // No figures on the tab while every rate is there.
    expect(find.textContaining(r'$3.400'), findsNothing);
    expect(find.textContaining('Sin tasa para'), findsNothing);

    await tester.ensureVisible(find.text('Ver tasas usadas'));
    await tester.tap(find.text('Ver tasas usadas'));
    await settle(tester);
    expect(
      find.text(
        'Así pasamos a COP lo que tienes en otras monedas. Solo cambian los '
        'totales, no los saldos de tus cuentas.',
      ),
      findsOneWidget,
    );
    // The title is the page's, said once.
    expect(find.text('Tasas'), findsOneWidget);
    expect(find.text(r'1 USD = $3.400'), findsOneWidget);
    expect(find.text('1 tasa escrita a mano'), findsOneWidget);
  });

  testWidgets('a missing rate is what Cuentas shows of the rates', (
    tester,
  ) async {
    await open(tester, fetcher: downRates(), held: Asset.btc, tab: true);

    expect(find.text('Ver tasas usadas'), findsOneWidget);
    expect(
      find.text('No se pudieron actualizar. Se usan las últimas guardadas.'),
      findsOneWidget,
    );
    expect(
      find.text('Sin tasa para BTC: cuenta como cero en los totales.'),
      findsOneWidget,
    );
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

    // Back to the market: no BTC/USD comes back, but tether reaches it.
    await tester.tap(find.text('Usar la automática'));
    await settle(tester);
    expect(find.text(r'1 BTC = $320.000.000'), findsOneWidget);
    expect(find.textContaining('Precio de mercado: 1 BTC'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
    expect(
      (await tester.runAsync(store.rates))!.where((Rate r) => r.manual),
      isEmpty,
    );
  });

  for (final Brightness brightness in Brightness.values) {
    for (final bool tab in <bool>[false, true]) {
      testWidgets(
        '${tab ? 'Cuentas' : 'the rates page'} holds at twice the text size, '
        '${brightness.name}',
        (tester) async {
          final SemanticsHandle semantics = tester.ensureSemantics();
          // A coin priced by hand, a dollar fetched, and euros without a
          // rate: the pill, the way back, the steps and the warning.
          await open(
            tester,
            fetcher: fakeRates(),
            held: Asset.btc,
            typed: '90000',
            others: <Asset>[Asset.usd, Asset.eur],
            tab: tab,
            brightness: brightness,
            large: true,
          );
          if (tab) {
            await tester.scrollUntilVisible(find.text('Ver tasas usadas'), 300);
            await settle(tester);
            expect(find.textContaining('Sin tasa para EUR'), findsOneWidget);
          } else {
            expect(find.text('Manual'), findsOneWidget);
            expect(find.text('Usar la automática'), findsOneWidget);
          }

          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        },
      );
    }
  }

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
