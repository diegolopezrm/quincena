// Renders the screens for someone's own accounts to PNG, for review.
//
// Not part of `flutter test`, like the rest of this folder. Regenerate with:
//
//   flutter test test_screens/own_screens_test.dart --update-goldens
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/places.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import '../test/fonts.dart';
import '../test/own_flow_test.dart' show fakeRates, settle;

final DateTime _now = DateTime(2026, 10, 3, 10);
Decimal d(String s) => Decimal.parse(s);

Future<QuincenaStore> seeded() async {
  final store = QuincenaStore(
    QuincenaDatabase(NativeDatabase.memory()),
    now: () => _now,
  );
  await store.ensureCategories();
  await store.saveProfile(
    const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
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
  await store.addAccount(
    name: 'Efectivo',
    kind: AccountKind.cash,
    asset: Asset.cop,
    opening: d('60000'),
  );
  final Account card = await store.addAccount(
    name: 'Visa',
    kind: AccountKind.card,
    asset: Asset.cop,
    opening: d('-480000'),
    institution: 'Bancolombia',
  );
  final Account dollars = await store.addAccount(
    name: 'Cuenta en dólares',
    kind: AccountKind.bank,
    asset: Asset.usd,
    opening: d('1250'),
    institution: 'Global66',
    spendable: false,
  );
  final Account binance = await store.addAccount(
    name: 'Binance',
    kind: AccountKind.exchange,
    asset: Asset.usdt,
    opening: d('1520.5'),
    institution: 'Binance',
  );
  await store.addAccount(
    name: 'Bitcoin',
    kind: AccountKind.exchange,
    asset: Asset.btc,
    opening: d('0.0123'),
    institution: 'Binance',
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
  await store.addEntry(
    accountId: dollars.id,
    amount: d('10.99'),
    kind: EntryKind.expense,
    date: DateTime(2026, 10, 2, 9),
    category: 'subscriptions',
    payee: 'Spotify',
  );
  await store.addTransfer(
    fromAccountId: bank.id,
    toAccountId: binance.id,
    sent: d('400000'),
    received: d('118.2'),
    date: DateTime(2026, 10, 1, 18),
    note: 'Ahorro en USDT',
  );
  await store.addRecurring(
    name: 'Netflix',
    amount: Money(d('26900'), Asset.cop),
    cadence: Cadence.monthly,
    nextDate: DateTime(2026, 10, 12),
    accountId: card.id,
    category: 'subscriptions',
  );
  return store;
}

/// What the phone caught over a morning: a purchase the alert names no shop
/// for, found by where the phone was; a transfer from a friend; and the
/// same Spotify charge already entered by hand.
Future<QuincenaStore> withCaptures() async {
  final QuincenaStore store = await seeded();
  final PlaceFinder photon = PlaceFinder(
    client: MockClient(
      (http.Request request) async => http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, Object>{
            'features': <Object>[
              <String, Object>{
                'geometry': <String, Object>{
                  'coordinates': <double>[-75.60178, 6.24634],
                },
                'properties': <String, String>{
                  'name': 'Éxito Laureles',
                  'osm_key': 'shop',
                  'osm_value': 'supermarket',
                },
              },
            ],
          }),
        ),
        200,
      ),
    ),
  );
  await store.saveCaptureSettings(
    (await store.captureSettings()).copyWith(useLocation: true),
  );
  await CaptureService(
    store,
    places: photon,
    now: () => _now,
  ).ingest(<CaptureEvent>[
    CaptureEvent(
      source: CaptureSource.sms,
      at: DateTime(2026, 10, 2, 9, 1),
      sender: '85784',
      text:
          r'Bancolombia le informa Compra por US$10,99 en SPOTIFY. 02/10/2026 09:00',
    ),
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
      text: r'Bancolombia · Compra por $63.200 POS 4512 T.Deb *1234',
      latitude: 6.2463,
      longitude: -75.60175,
      accuracy: 12,
    ),
  ]);
  return store;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  tearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });

  Future<void> open(
    WidgetTester tester,
    QuincenaStore store,
    Size size,
    Brightness brightness,
  ) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
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
  }

  const Size phone = Size(390, 844);
  const Size desktop = Size(1280, 860);

  Future<void> shoot(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/own-$name.png'),
  );

  testWidgets('start', (tester) async {
    final QuincenaStore store = (await tester.runAsync(
      () async => QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => _now,
      ),
    ))!;
    await open(tester, store, phone, Brightness.light);
    await shoot('start');
    await tester.tap(find.text('Con mis cuentas'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Diego');
    await settle(tester);
    await shoot('onboarding-1');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);
    await shoot('onboarding-2');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);
    await shoot('onboarding-3');
  });

  for (final Brightness b in Brightness.values) {
    testWidgets('tabs ${b.name}', (tester) async {
      final QuincenaStore store = (await tester.runAsync(seeded))!;
      await open(tester, store, phone, b);
      await shoot('home-${b.name}');
      await tester.tap(find.text('Movimientos'));
      await settle(tester);
      await shoot('movements-${b.name}');
      await tester.tap(find.text('Cuentas'));
      await settle(tester);
      await shoot('accounts-${b.name}');
    });
  }

  testWidgets('free explained', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('¿De dónde sale?'));
    await settle(tester);
    await shoot('free-explained');
  });

  testWidgets('sheets', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '45.900');
    await tester.tap(find.text('Mercado'));
    await settle(tester);
    await shoot('entry-sheet');
    await tester.tap(find.text('Transferencia'));
    await settle(tester);
    await shoot('transfer-sheet');
  });

  testWidgets('account page', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Cuentas'));
    await settle(tester);
    await tester.ensureVisible(find.text('Binance').first);
    await settle(tester);
    await tester.tap(find.text('Binance').first);
    await settle(tester);
    await shoot('account-binance');
  });

  testWidgets('capture', (tester) async {
    final QuincenaStore store = (await tester.runAsync(withCaptures))!;
    await open(tester, store, phone, Brightness.light);
    await shoot('home-inbox');
    await tester.tap(find.byTooltip('Por revisar'));
    await settle(tester);
    await shoot('inbox');
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    await shoot('settings');
    await tester.tap(find.text('Captura automática'));
    await settle(tester);
    await shoot('capture');
    await tester.tap(find.text('Reglas aprendidas'));
    await settle(tester);
    await shoot('rules');
  });

  testWidgets('coming days', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await shoot('home-coming');
    await tester.tap(find.text('Ver 30 días'));
    await settle(tester);
    await shoot('coming');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.text('¿Me alcanza?'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '350.000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '¿Qué es? (opcional)'),
      'Audífonos',
    );
    await settle(tester);
    await shoot('buy');
    await tester.tap(find.byTooltip('Cierre de la quincena'));
    await settle(tester);
    await shoot('close');
  });

  testWidgets('plan', (tester) async {
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = await seeded();
      await store.addGoal(
        name: 'Viaje a Cartagena',
        target: Money(Decimal.parse('2400000'), Asset.cop),
        saved: Money(Decimal.parse('650000'), Asset.cop),
        monthly: Money(Decimal.parse('300000'), Asset.cop),
      );
      return store;
    }))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Plan'));
    await settle(tester);
    await shoot('plan');
    await tester.tap(find.text('Repartir en sobres'));
    await settle(tester);
    await shoot('envelopes');
  });

  testWidgets('explained', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Cuentas'));
    await settle(tester);
    await tester.tap(find.text('¿De dónde sale?').first);
    await settle(tester);
    await shoot('total-explained');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.text('Bancolombia').first);
    await settle(tester);
    await tester.tap(find.text('¿De dónde sale?').first);
    await settle(tester);
    await shoot('account-explained');
  });

  testWidgets('desktop', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, desktop, Brightness.dark);
    await shoot('desktop-home');
  });
}
