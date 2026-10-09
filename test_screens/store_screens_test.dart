// Renders the screenshots for the App Store and Google Play, in Spanish and
// English, every one from the app's own example account as «Con datos de
// ejemplo» opens it, the answer included, so every picture is a tap away
// in the app and the two cannot drift apart. Never anyone's real data.
//
// Not part of `flutter test`, like the rest of this folder. Regenerate with:
//
//   flutter test test_screens/store_screens_test.dart --update-goldens
//
// They are written straight into docs/store/screenshots.
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
import 'package:quincena/data/example_prices.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

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

/// A designer in Medellín paid twice a month, with pesos in two banks, a
/// card, dollars, and some crypto on Binance: what the accessibility tests
/// read the screens with. The store's pictures show the app's own example.
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
      value: d(exampleTrm),
      asOf: DateTime(2026, 10, 3),
      source: 'trm',
    ),
    for (final MapEntry<String, (String, String)> p in examplePrices.entries)
      Rate(
        asset: p.key,
        quote: 'USDT',
        value: d(p.value.$1),
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
    creditLimit: d('3000000'),
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

  Future<void> back(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
  }

  /// Taps [text] on the page on top, scrolled to the top of its list.
  Future<void> tapFound(WidgetTester tester, String text) async {
    final Finder f = find.text(text);
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        300,
        scrollable: find
            .byWidgetPredicate(
              (Widget w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    await tester.ensureVisible(f.last);
    await settle(tester);
    await tester.tap(f.last);
    await settle(tester);
  }

  Future<void> shoot(String store, String language, String name) => expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile('../docs/store/screenshots/$store/$language/$name.png'),
  );

  for (final MapEntry<String, (Size, double)> s in stores.entries) {
    for (final String language in <String>['es', 'en']) {
      final String tag = '${s.key} $language';

      testWidgets('example $tag', (tester) async {
        device(tester, s.value, language);
        final AppLocalizations l = lookupAppLocalizations(Locale(language));
        // A phone with nothing of anyone's: every picture is the example
        // that «Con datos de ejemplo» opens, as a reviewer finds it, one
        // tap from where the last one was taken.
        final QuincenaStore store = QuincenaStore(
          QuincenaDatabase(NativeDatabase.memory()),
        );
        addTearDown(() => tester.runAsync(store.close));
        await tester.pumpWidget(
          QuincenaApp(store: store, startInDemo: false, fetcher: fakeRates()),
        );
        await settle(tester);
        await tester.tap(find.text(l.startDemoTitle));
        await settle(tester);
        await shoot(s.key, language, '02-home');

        // «Pregúntale a tu plata» on Inicio, answered by the script over
        // the same account.
        await tapFound(tester, ScriptedAgent.startersFor(language)[1]);
        await shoot(s.key, language, '01-answer');
        await back(tester);

        await tester.tap(find.byTooltip(l.inboxTitle));
        await settle(tester);
        await shoot(s.key, language, '03-inbox');
        await back(tester);

        await tester.tap(find.text(l.tabAccounts).last);
        await settle(tester);
        await shoot(s.key, language, '06-accounts');

        await tapFound(tester, l.cryptoPerformanceRow);
        await shoot(s.key, language, '04-crypto');
        await back(tester);

        // «Importar extracto» with the example's own statement.
        await tester.tap(find.byTooltip(l.settingsTitle));
        await settle(tester);
        await tapFound(tester, l.statementTitle);
        await tapFound(tester, l.exampleStatementUse);
        // The statement is read from the app's own files.
        for (var i = 0; i < 50; i++) {
          if (find.text(l.exampleStatementUse).evaluate().isEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        await settle(tester);
        await shoot(s.key, language, '05-statement');
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      });
    }
  }
}
