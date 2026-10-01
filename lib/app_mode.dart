import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/clock.dart';
import 'format/money.dart' as format;
import 'money/asset.dart';
import 'money/rate_sources.dart';
import 'own/own_controller.dart';
import 'store/store.dart';

/// What the app is showing.
enum AppMode {
  /// Opening the database.
  loading,

  /// First launch: the person picks their own accounts or the sample.
  choosing,

  /// Setting up their own accounts.
  onboarding,

  /// The sample account.
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
  }) : now = now ?? DateTime.now;

  /// Where rates come from; tests pass one that never leaves the machine.
  final RateFetcher? fetcher;

  /// The clock the person's own accounts are read with.
  final DateTime Function() now;

  /// A controller for the person's own accounts, with this one's clock and
  /// rates.
  OwnController newOwn() => OwnController(store!, fetcher: fetcher, now: now);

  /// Null where the build cannot keep a database: the demo is all there is.
  final QuincenaStore? store;

  /// Open on the demo unless the person already chose their own accounts,
  /// as the published web demo does.
  final bool startInDemo;

  static const String _modeKey = 'app.mode';

  AppMode _mode = AppMode.loading;
  AppMode get mode => _mode;

  OwnController? _own;
  OwnController? get own => _own;

  /// Whether the person can use their own accounts in this build.
  bool get canUseOwn => store != null;

  /// Whether there are own accounts to go back to from the demo.
  bool _hasOwn = false;
  bool get hasOwn => _hasOwn;

  Future<void> start() async {
    final QuincenaStore? s = store;
    if (s == null) return _set(AppMode.demo);
    final String? saved = await s.setting(_modeKey);
    _hasOwn = await s.profile() != null;
    if (saved == 'own' && _hasOwn) return _enterOwn();
    if (saved == 'demo' || startInDemo) return _set(AppMode.demo);
    _set(AppMode.choosing);
  }

  /// The sample account. The person's own data stays where it is.
  Future<void> useDemo() async {
    await store?.setSetting(_modeKey, 'demo');
    _leaveOwn();
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
    _set(AppMode.demo);
  }

  /// The person's own accounts, through onboarding the first time.
  Future<void> useOwn() async {
    final QuincenaStore? s = store;
    if (s == null) return;
    if (await s.profile() == null) return _set(AppMode.onboarding);
    await s.setSetting(_modeKey, 'own');
    await _enterOwn();
  }

  /// Onboarding finished: the profile and the first accounts are saved.
  Future<void> finishedOnboarding() async {
    await store?.setSetting(_modeKey, 'own');
    _hasOwn = true;
    await _enterOwn();
  }

  /// The person backed out of onboarding: back to the first screen.
  void cancelOnboarding() => _set(AppMode.choosing);

  /// Everything was deleted: back to the first screen.
  Future<void> wiped() async {
    _leaveOwn();
    _hasOwn = false;
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
    _set(AppMode.choosing);
  }

  Future<void> _enterOwn() async {
    _leaveOwn();
    final OwnController own = newOwn();
    _own = own;
    await own.start();
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
    super.dispose();
  }
}
