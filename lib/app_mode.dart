import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/clock.dart';
import 'data/example_account.dart';
import 'format/money.dart' as format;
import 'money/asset.dart';
import 'money/rate_sources.dart';
import 'ai/allowance.dart';
import 'own/own_controller.dart';
import 'portfolio/market.dart';
import 'store/store.dart';
import 'widget/home_widget.dart';

/// What the app is showing.
enum AppMode {
  /// Opening the database.
  loading,

  /// First launch: the person picks their own accounts or the sample.
  choosing,

  /// Setting up their own accounts.
  onboarding,

  /// Valentina's example account: the whole app on made-up money, kept in
  /// memory apart from the person's own.
  demo,

  /// Their own accounts.
  own,
}

/// Decides between the sample account and the person's own, and remembers
/// the choice.
class AppModeController extends ChangeNotifier {
  AppModeController({
    this.store,
    this.startInDemo = false,
    this.fetcher,
    DateTime Function()? now,
    this.market,
  }) : now = now ?? DateTime.now;

  /// Where rates come from; tests pass one that never leaves the machine.
  final RateFetcher? fetcher;

  /// Where crypto prices come from; tests and the store's screenshots pass
  /// one with fixed prices.
  final MarketData? market;

  /// The clock the person's own accounts are read with.
  final DateTime Function() now;

  /// A controller for the person's own accounts, with this one's clock,
  /// rates and prices. [readNative] false leaves what was captured where it
  /// is.
  OwnController newOwn({bool readNative = true}) => OwnController(
    store!,
    fetcher: fetcher,
    now: now,
    readNative: readNative,
    market: market,
  );

  /// Null where the build cannot keep a database: the example is all there
  /// is.
  final QuincenaStore? store;

  /// The day's questions to Gemini through Quincena, shared by the sample
  /// and the person's own accounts. Null without a database to count in.
  late final Allowance? allowance = store == null
      ? null
      : (Allowance(store!, now: now)..load());

  /// Open on the example unless the person already chose their own
  /// accounts, as the published web demo does.
  final bool startInDemo;

  static const String _modeKey = 'app.mode';

  AppMode _mode = AppMode.loading;
  AppMode get mode => _mode;

  OwnController? _own;
  OwnController? get own => _own;

  /// Valentina's example account while the app shows it, in a database in
  /// memory: built afresh each time it opens, closed and gone when it is
  /// left, so nothing done in it stays.
  OwnController? _example;
  OwnController? get example => _example;
  QuincenaStore? _exampleStore;

  /// Whether the example can go back to the first screen: not where the
  /// app opens on it, as the web does, which never shows that screen.
  bool get hasStart => store != null && !startInDemo;

  /// Whether the person can use their own accounts in this build.
  bool get canUseOwn => store != null;

  /// Whether there are own accounts to go back to from the demo.
  bool _hasOwn = false;
  bool get hasOwn => _hasOwn;

  Future<void> start() async {
    final QuincenaStore? s = store;
    if (s == null) return _enterExample();
    final String? saved = await s.setting(_modeKey);
    _hasOwn = await s.profile() != null;
    if (saved == 'own' && _hasOwn) return _enterOwn();
    if (saved == 'demo' || startInDemo) return _enterExample();
    _set(AppMode.choosing);
  }

  /// Valentina's example account, the whole app on it. The person's own
  /// accounts stay where they are, untouched: only the choice is kept, so
  /// the app opens on the example again, as fresh as the first time.
  Future<void> useDemo() async {
    await store?.setSetting(_modeKey, 'demo');
    _leaveOwn();
    await _enterExample();
  }

  /// Back to the first screen from the example, which forgets it was
  /// chosen.
  Future<void> backToStart() async {
    if (!hasStart) return;
    await store?.setSetting(_modeKey, '');
    _leaveExample();
    _noAccount();
    _set(AppMode.choosing);
  }

  /// The person's own accounts, through onboarding the first time, and
  /// again while it was left before any account: it picks up where it
  /// stopped instead of opening on nothing.
  Future<void> useOwn() async {
    final QuincenaStore? s = store;
    if (s == null) return;
    if (await s.profile() == null ||
        (await s.accounts(archived: true)).isEmpty) {
      _leaveExample();
      _noAccount();
      return _set(AppMode.onboarding);
    }
    await s.setSetting(_modeKey, 'own');
    await _enterOwn();
  }

  /// Onboarding finished: the profile and the first accounts are saved.
  Future<void> finishedOnboarding() async {
    await store?.setSetting(_modeKey, 'own');
    _hasOwn = true;
    await _enterOwn();
  }

  /// The person backed out of onboarding: back to the first screen, or to
  /// the sample where the app opens on it, as the web does.
  void cancelOnboarding() =>
      startInDemo ? unawaited(useDemo()) : _set(AppMode.choosing);

  /// Everything was deleted: back to the first screen, or to the sample
  /// where the app opens on it.
  Future<void> wiped() async {
    _leaveOwn();
    unawaited(HomeWidget.show(null));
    _hasOwn = false;
    _noAccount();
    if (startInDemo) return _enterExample();
    _set(AppMode.choosing);
  }

  /// Counts the times the example was opened or left, so one that was
  /// left while it opened is closed instead of shown.
  int _visit = 0;

  Future<void> _enterExample() async {
    _leaveExample();
    final int visit = _visit;
    // Nothing to show while it is written: a moment, in memory.
    _set(AppMode.loading);
    final QuincenaStore s = await openExample();
    if (visit != _visit) return s.close();
    final OwnController example = OwnController(
      s,
      example: true,
      now: () => exampleNow,
      readNative: false,
    );
    _exampleStore = s;
    _example = example;
    await example.start();
    // Left before it finished opening.
    if (!identical(_example, example)) return;
    _set(AppMode.demo);
  }

  void _leaveExample() {
    _visit++;
    final QuincenaStore? s = _exampleStore;
    _example?.dispose();
    _example = null;
    _exampleStore = null;
    if (s != null) unawaited(s.close());
  }

  /// Back to the day and the currency the app starts with, when no account
  /// is open to set its own.
  void _noAccount() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  }

  Future<void> _enterOwn() async {
    _leaveOwn();
    final OwnController own = newOwn();
    _own = own;
    await own.start();
    // The example stays on screen until the person's own accounts are
    // ready to take its place.
    _leaveExample();
    _hasOwn = true;
    _set(AppMode.own);
  }

  void _leaveOwn() {
    _own?.dispose();
    _own = null;
  }

  void _set(AppMode mode) {
    _mode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    _leaveOwn();
    _leaveExample();
    super.dispose();
  }
}
