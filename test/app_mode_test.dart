// Where the app goes when the person backs out of onboarding or deletes
// everything: the first screen, or the example where the app opens on it,
// as the web does, which never shows that screen. The example account
// lives in memory, apart from the person's own, and nothing of it stays.
// And where the person's own accounts read crypto prices.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/data/example_prices.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'portfolio_test.dart' show FakeMarket;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppModeController> open({required bool startInDemo}) async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
    );
    addTearDown(store.close);
    final AppModeController modes = AppModeController(
      store: store,
      startInDemo: startInDemo,
      // Fixed rates, from no server.
      fetcher: ExampleRates(),
    );
    addTearDown(modes.dispose);
    await modes.start();
    return modes;
  }

  /// Until the example, opened without waiting, is open.
  Future<void> opened(AppModeController modes) async {
    for (var i = 0; i < 200 && modes.mode != AppMode.demo; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(modes.mode, AppMode.demo);
  }

  test('where the app opens on the sample, it never reaches the first '
      'screen', () async {
    final AppModeController modes = await open(startInDemo: true);
    expect(modes.mode, AppMode.demo);
    expect(modes.hasStart, isFalse);

    await modes.useOwn();
    expect(modes.mode, AppMode.onboarding);
    modes.cancelOnboarding();
    await opened(modes);

    await modes.wiped();
    expect(modes.mode, AppMode.demo);
    expect(modes.hasOwn, isFalse);

    // There is no first screen to go back to.
    await modes.backToStart();
    expect(modes.mode, AppMode.demo);
  });

  test('the sample is Valentina\'s whole account, in memory, on her own '
      'clock, and the person\'s database only keeps the choice', () async {
    final AppModeController modes = await open(startInDemo: false);
    await modes.useDemo();
    expect(modes.mode, AppMode.demo);
    expect(modes.own, isNull);
    final OwnController example = modes.example!;
    expect(example.example, isTrue);
    expect(identical(example.store, modes.store), isFalse);
    expect(example.profile!.name, 'Valentina');
    expect(example.now(), exampleNow);
    expect(example.accounts, isNotEmpty);
    expect(example.ledger!.today, DateTime(2026, 10, 1));

    // In the person's database: no profile, no account, no movement; only
    // that the example was chosen.
    final QuincenaStore mine = modes.store!;
    expect(await mine.profile(), isNull);
    expect(await mine.accounts(archived: true), isEmpty);
    expect(await mine.entries(), isEmpty);
    expect(await mine.inbox(), isEmpty);
    expect(await mine.setting('app.mode'), 'demo');
  });

  test('what is done in the example goes with it, and it opens fresh next '
      'time', () async {
    final AppModeController modes = await open(startInDemo: false);
    await modes.useDemo();
    final OwnController first = modes.example!;
    final int entries = first.snapshot!.entries.length;
    await first.store.addEntry(
      accountId: first.accounts.first.id,
      amount: Decimal.parse('50000'),
      kind: EntryKind.expense,
      date: exampleNow,
      payee: 'Algo de prueba',
    );

    // Left for the first screen: the choice is forgotten with it.
    await modes.backToStart();
    expect(modes.mode, AppMode.choosing);
    expect(modes.example, isNull);
    expect(await modes.store!.setting('app.mode'), '');

    await modes.useDemo();
    final OwnController again = modes.example!;
    expect(identical(again, first), isFalse);
    expect(again.snapshot!.entries, hasLength(entries));
    expect(
      again.snapshot!.entries.where((Entry e) => e.payee == 'Algo de prueba'),
      isEmpty,
    );
  });

  test(
    'where the build keeps no database, the example is all there is',
    () async {
      final AppModeController modes = AppModeController(
        fetcher: ExampleRates(),
      );
      addTearDown(modes.dispose);
      await modes.start();
      expect(modes.mode, AppMode.demo);
      expect(modes.example!.profile!.name, 'Valentina');
      expect(modes.canUseOwn, isFalse);
      expect(modes.hasStart, isFalse);
    },
  );

  test('the remembered example opens again on a new start', () async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
    );
    addTearDown(store.close);
    await store.setSetting('app.mode', 'demo');
    final AppModeController modes = AppModeController(store: store);
    addTearDown(modes.dispose);
    await modes.start();
    expect(modes.mode, AppMode.demo);
    expect(modes.example!.profile!.name, 'Valentina');
  });

  test(
    'from the example, the person\'s own accounts open as they were',
    () async {
      final AppModeController modes = await open(startInDemo: false);
      final QuincenaStore mine = modes.store!;
      await mine.saveProfile(
        const Profile(name: 'Laura', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await mine.addAccount(
        name: 'Banco',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: Decimal.parse('800000'),
      );
      await modes.useOwn();
      expect(modes.mode, AppMode.own);
      await modes.useDemo();
      expect(modes.own, isNull);
      expect(modes.hasOwn, isTrue);

      await modes.useOwn();
      expect(modes.mode, AppMode.own);
      expect(modes.example, isNull);
      expect(modes.own!.profile!.name, 'Laura');
      expect(modes.own!.accounts.single.name, 'Banco');
      expect(await mine.entries(), isEmpty);
      expect(await mine.setting('app.mode'), 'own');
    },
  );

  test('elsewhere, both go back to the first screen', () async {
    final AppModeController modes = await open(startInDemo: false);
    expect(modes.mode, AppMode.choosing);

    await modes.useOwn();
    expect(modes.mode, AppMode.onboarding);
    modes.cancelOnboarding();
    expect(modes.mode, AppMode.choosing);

    await modes.wiped();
    expect(modes.mode, AppMode.choosing);
  });

  test('onboarding left after the profile and before any account picks up '
      'again, rather than opening on an empty home', () async {
    final AppModeController modes = await open(startInDemo: false);
    await modes.useOwn();
    // The pay step saves the profile; the person backs out on the next.
    await modes.store!.saveProfile(
      const Profile(name: 'Laura', base: Asset.cop, schedule: TwiceMonthly()),
    );
    modes.cancelOnboarding();

    await modes.useOwn();
    expect(modes.mode, AppMode.onboarding);
  });

  test('the own accounts read prices from the market the app was given, as '
      'the store pictures and the tour give one with fixed prices', () async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
    );
    addTearDown(store.close);
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
    // The dollar, just read: nothing else is fetched, and bitcoin's price
    // can only come from the market.
    await store.saveRates(<Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: Decimal.parse('4000'),
        asOf: DateTime.now(),
        source: 'trm',
      ),
    ]);
    await store.addAccount(
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
      opening: Decimal.parse('0.01'),
    );
    final FakeMarket market = FakeMarket(
      prices: const <String, (String, String)>{'BTC': ('100000', '98000')},
    );
    final AppModeController modes = AppModeController(
      store: store,
      market: market,
    );
    addTearDown(modes.dispose);
    final OwnController own = modes.newOwn(readNative: false);
    addTearDown(own.dispose);
    await own.start();
    await own.portfolio.refresh();

    expect(market.asked, 1);
    expect(
      own.portfolio.portfolio!.holdings.single.price!.usd,
      Decimal.parse('100000'),
    );
  });
}
