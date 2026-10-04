// The account the screen renders and the tour of the app use: Diego's,
// with a bank, a wallet, cash, a credit card with its limit, dollars and
// crypto with what it cost, a month of movements, a recurring charge, and,
// with [withCaptures], what the phone caught one morning.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/places.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

/// The moment the screens believe it is.
final DateTime screensNow = DateTime(2026, 10, 3, 10);
Decimal d(String s) => Decimal.parse(s);

Future<QuincenaStore> seeded() async {
  final store = QuincenaStore(
    QuincenaDatabase(NativeDatabase.memory()),
    now: () => screensNow,
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
      asOf: screensNow,
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
    creditLimit: d('3000000'),
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
    // What each coin cost, so the gain is the gain: one without its
    // purchase price is left out of it, and would be most of the money.
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
    now: () => screensNow,
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
