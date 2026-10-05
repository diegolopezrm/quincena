// Where the app goes when the person backs out of onboarding or deletes
// everything: the first screen, or the sample where the app opens on it,
// as the web does, which never shows that screen. And where the person's
// own accounts read crypto prices.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app_mode.dart';
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
    );
    addTearDown(modes.dispose);
    await modes.start();
    return modes;
  }

  test('where the app opens on the sample, it never reaches the first '
      'screen', () async {
    final AppModeController modes = await open(startInDemo: true);
    expect(modes.mode, AppMode.demo);

    await modes.useOwn();
    expect(modes.mode, AppMode.onboarding);
    modes.cancelOnboarding();
    await pumpEventQueue();
    expect(modes.mode, AppMode.demo);

    await modes.wiped();
    expect(modes.mode, AppMode.demo);
    expect(modes.hasOwn, isFalse);
  });

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
