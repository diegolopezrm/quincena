import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../capture/capture_service.dart';
import '../capture/event.dart';
import '../capture/inbox.dart';
import '../capture/native_channel.dart';
import '../capture/native_inbox.dart';
import '../capture/merchants.dart';
import '../capture/places.dart';
import '../agent/tools.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../domain/ledger_builder.dart';
import '../domain/plan.dart';
import '../domain/projection.dart';
import '../domain/records.dart';
import '../format/money.dart' as format;
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rate_sources.dart';
import '../money/rates.dart';
import '../exchanges/binance_link.dart';
import '../exchanges/p2p_match.dart';
import '../exchanges/wallets.dart';
import '../portfolio/market.dart';
import '../portfolio/portfolio_controller.dart';
import '../reminders/reminders.dart';
import '../store/store.dart';

/// The person's own accounts, kept current for the screens.
///
/// Rebuilds everything the screens read whenever the database changes, so a
/// movement saved in a sheet shows on every tab without anyone asking.
class OwnController extends ChangeNotifier {
  OwnController(
    this.store, {
    RateFetcher? fetcher,
    DateTime Function()? now,
    this.ratesMaxAge = const Duration(hours: 6),
    PlaceFinder? places,
    this.readNative = true,
    this._market,
    this._binance,
  }) : _fetcher = fetcher ?? RateFetcher(),
       _now = now ?? DateTime.now {
    capture = CaptureService(store, places: places ?? PlaceFinder(), now: _now);
  }

  /// Turns captured events into movements through the inbox.
  late final CaptureService capture;

  /// Whether to read what the native side captured; tests leave it out.
  final bool readNative;

  final QuincenaStore store;
  final RateFetcher _fetcher;
  final MarketData? _market;
  final DateTime Function() _now;

  /// The moment now, by the clock the controller was given.
  DateTime now() => _now();

  /// The person's crypto, priced as it moves.
  PortfolioController get portfolio =>
      _portfolio ??= PortfolioController(this, market: _market);
  PortfolioController? _portfolio;

  /// Their Binance account, when they link it.
  BinanceLink get binance => _binance ??= BinanceLink(store);
  BinanceLink? _binance;

  /// The wallets they follow by public address.
  WalletLink get wallets => _wallets ??= WalletLink(store, now: _now);
  WalletLink? _wallets;

  /// How old the rates may be before opening the app fetches new ones.
  final Duration ratesMaxAge;

  StoreSnapshot? _snapshot;
  LedgerBuild? _build;
  Map<String, Money> _balances = const <String, Money>{};
  DateTime? _ratesFetchedAt;
  bool _refreshing = false;
  bool _ratesFailed = false;
  StreamSubscription<void>? _changes;
  List<InboxItem> _inbox = const <InboxItem>[];
  List<InboxItem> _automatic = const <InboxItem>[];

  /// The envelopes last saved, of this period or one before.
  EnvelopePlan? _plan;
  List<Wish> _wishes = const <Wish>[];
  List<Scenario> _scenarios = const <Scenario>[];

  /// The accounts that hold the emergency fund, the categories that are
  /// essential, and how many days the person wants it to cover.
  CushionSettings _cushion = const CushionSettings();

  /// The reminder's words as saved when it was turned on, or null when it
  /// is off.
  Map<String, String>? _reminder;

  /// The schedule the reminders were last set for.
  String? _remindedFor;
  CaptureSettings _captureSettings = const CaptureSettings();
  bool _pulling = false;
  bool _pullAgain = false;
  String? _configured;
  Timer? _pending;
  bool _disposed = false;

  StoreSnapshot? get snapshot => _snapshot;

  /// Captures waiting for the person, and the ones that may be repeats.
  List<InboxItem> get inbox => _inbox;

  /// What was recorded without asking in the last two weeks, newest first,
  /// to undo or correct.
  List<InboxItem> get recentAutomatic => _automatic;

  /// This period's envelopes, or null when it has none yet.
  EnvelopePlan? get plan {
    final Ledger? l = ledger;
    final EnvelopePlan? p = _plan;
    if (l == null || p == null || p.period != periodStart(l)) return null;
    return p;
  }

  /// Whether a pay arrived in this period, an income filed as salary since
  /// the payday that started it, and the period has no envelopes yet.
  bool get paidWithoutPlan {
    final Ledger? l = ledger;
    final StoreSnapshot? s = _snapshot;
    if (l == null || s == null || plan != null) return false;
    final DateTime start = periodStart(l);
    return s.entries.any(
      (Entry e) =>
          e.kind == EntryKind.income &&
          e.category == 'salary' &&
          !DateTime(e.date.year, e.date.month, e.date.day).isBefore(start) &&
          !e.date.isAfter(endOfDay(l.today)),
    );
  }

  /// The envelopes last saved, whatever their period: the next plan starts
  /// from them.
  EnvelopePlan? get lastPlan => _plan;

  List<Wish> get wishes => _wishes;
  List<Scenario> get scenarios => _scenarios;
  CushionSettings get cushionSettings => _cushion;

  /// The goals in the base currency's smallest unit, for planning.
  List<GoalShare> get goalShares {
    final Ledger? l = ledger;
    final Asset? base = profile?.base;
    if (l == null || base == null) return const <GoalShare>[];
    int inUnit(Money m) {
      final Money? converted = inBase(m);
      return converted == null ? 0 : l.minor(converted.amount.toDouble());
    }

    return <GoalShare>[
      for (final SavingsGoal g in _snapshot?.goals ?? const <SavingsGoal>[])
        GoalShare(
          id: g.id,
          name: g.name,
          target: inUnit(g.target),
          saved: inUnit(g.saved),
          monthly: inUnit(g.monthly),
        ),
    ];
  }

  Future<void> savePlan(EnvelopePlan plan) =>
      store.setSetting(_planKey, jsonEncode(plan.toJson()));

  Future<void> saveWishes(List<Wish> wishes) => store.setSetting(
    _wishesKey,
    jsonEncode(<Object?>[for (final Wish w in wishes) w.toJson()]),
  );

  Future<void> saveScenarios(List<Scenario> scenarios) => store.setSetting(
    _scenariosKey,
    jsonEncode(<Object?>[for (final Scenario x in scenarios) x.toJson()]),
  );

  Future<void> saveCushionSettings(CushionSettings settings) =>
      store.setSetting(_cushionKey, jsonEncode(settings.toJson()));

  static const String _planKey = 'plan.envelopes';
  static const String _wishesKey = 'plan.wishes';
  static const String _scenariosKey = 'plan.scenarios';
  static const String _cushionKey = 'plan.cushion';

  /// Whether the close of each fortnight is reminded on payday.
  bool get remindsClose => _reminder != null;

  /// Turns the payday reminder on, once the system lets the app notify,
  /// or off. [title] and [body] are what it says, with no amounts. False
  /// when the system said no.
  Future<bool> remindClose(
    bool on, {
    required String title,
    required String body,
  }) async {
    if (!on) {
      await store.setSetting(_reminderKey, '');
      await Reminders.cancel();
      _remindedFor = null;
      return true;
    }
    if (!await Reminders.ask()) return false;
    await store.setSetting(
      _reminderKey,
      jsonEncode(<String, String>{'title': title, 'body': body}),
    );
    _remindedFor = null;
    return true;
  }

  static const String _reminderKey = 'reminders.close';

  static List<Object?> _list(String? text) => switch (_json(text)) {
    final List<Object?> list => list,
    _ => const <Object?>[],
  };

  static Object? _json(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// Sets the reminders again when the schedule they follow changed.
  Future<void> _remind() async {
    final Profile? p = profile;
    final Map<String, String>? words = _reminder;
    if (p == null || words == null) return;
    final String forSchedule = jsonEncode(p.schedule.toJson());
    if (forSchedule == _remindedFor) return;
    _remindedFor = forSchedule;
    await Reminders.schedule(
      p.schedule,
      _now(),
      title: words['title'] ?? '',
      body: words['body'] ?? '',
    );
  }

  List<InboxItem> get pendingInbox => <InboxItem>[
    for (final InboxItem i in _inbox)
      if (i.status == InboxStatus.pending) i,
  ];
  CaptureSettings get captureSettings => _captureSettings;
  Profile? get profile => _snapshot?.profile;
  Ledger? get ledger => _build?.ledger;

  /// The coming days, from the ledger as it is now.
  Projection? get projection {
    final Ledger? l = ledger;
    if (l == null) return null;
    if (!identical(_projected?.ledger, l)) _projected = Projection.of(l);
    return _projected;
  }

  Projection? _projected;

  /// Assets held somewhere that no known rate converts to the base.
  Set<Asset> get unconverted => _build?.unconverted ?? const <Asset>{};

  /// What each spendable account adds to the money until payday, in the
  /// ledger's smallest unit.
  Map<String, int> get spendableParts => _build?.parts ?? const <String, int>{};
  Map<String, Money> get balances => _balances;
  DateTime? get ratesFetchedAt => _ratesFetchedAt;
  bool get refreshingRates => _refreshing;
  bool get ratesFailed => _ratesFailed;

  List<Account> get accounts => <Account>[
    for (final Account a in _snapshot?.accounts ?? const <Account>[])
      if (!a.archived) a,
  ];

  List<CategoryItem> get categories =>
      _snapshot?.categories ?? const <CategoryItem>[];

  DateTime get today {
    final DateTime now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  RateTable get rates => RateTable(_snapshot?.rates ?? const <Rate>[]);

  /// [money] in the base currency, or null without a rate for it.
  Money? inBase(Money money) {
    final Profile? p = profile;
    if (p == null) return null;
    return rates.convert(money, p.base);
  }

  /// What [account] holds in the base currency, to the base currency's
  /// smallest unit, as a total adds it; null without a rate.
  Money? partOfTotal(Account account) {
    final Money? converted = inBase(
      _balances[account.id] ?? account.openingMoney,
    );
    if (converted == null) return null;
    return Money(
      converted.amount.round(scale: converted.asset.decimals),
      converted.asset,
    );
  }

  /// What the accounts hold together in the base currency: all of them, or
  /// only those whose money is to spend. Each account is rounded to the
  /// base currency's smallest unit first, so the parts add up to it.
  Money total({bool spendableOnly = false}) {
    final Asset base = profile?.base ?? Asset.cop;
    var sum = Money.zero(base);
    for (final Account a in accounts) {
      if (spendableOnly && !a.spendable) continue;
      final Money? part = partOfTotal(a);
      if (part != null) sum += part;
    }
    return sum;
  }

  Future<void> start() async {
    await store.ensureCategories();
    await _reload();
    _changes = store.watchChanges().listen((_) => _schedule());
    unawaited(refreshRates());
    if (readNative) CaptureChannel.listen(this, pullCaptures);
    unawaited(pullCaptures());
  }

  /// Fetches rates for every asset held, unless they are recent enough and
  /// [force] is false.
  Future<void> refreshRates({bool force = false}) async {
    final Profile? p = profile;
    if (p == null || _refreshing) return;
    final DateTime? last = _ratesFetchedAt;
    if (!force && last != null && _now().difference(last) < ratesMaxAge) {
      return;
    }
    _refreshing = true;
    _notify();
    final List<Rate> fetched = await _fetcher.fetch(<Asset>[
      for (final Account a in accounts) a.asset,
    ], p.base);
    _ratesFailed =
        fetched.isEmpty && accounts.any((Account a) => a.asset != p.base);
    if (fetched.isNotEmpty) await store.saveRates(fetched);
    _refreshing = false;
    await _reload();
  }

  /// Takes what the native side captured since the last time and runs it
  /// through the inbox. Called on start, whenever the app comes back, and
  /// when the platform says something arrived while it was open.
  ///
  /// A call during a pull makes that pull look again when it ends, so an
  /// event that lands meanwhile is not left waiting for the next return.
  Future<IngestReport> pullCaptures() async {
    if (!readNative) return const IngestReport();
    if (_pulling) {
      _pullAgain = true;
      return const IngestReport();
    }
    _pulling = true;
    var report = const IngestReport();
    try {
      do {
        _pullAgain = false;
        report += await capture.ingest(await takeNativeEvents());
      } while (_pullAgain && !_disposed);
      if (report.added + report.recorded > 0) await joinTransfers();
    } finally {
      _pulling = false;
    }
    return report;
  }

  /// Joins movements that are two sides of one transfer: a Binance P2P
  /// order and the bank's payment for it.
  Future<int> joinTransfers() => linkP2pPayments(store);

  /// Text read from screenshots, photos or PDFs the person picked.
  Future<IngestReport> ingestRead(Iterable<String> texts) =>
      capture.ingest(<CaptureEvent>[
        for (final String text in texts)
          CaptureEvent(
            source: CaptureSource.screenshot,
            at: _now(),
            text: text,
          ),
      ]);

  /// Saves an expense the person confirmed in a conversation, and waits
  /// until every screen and the next answer count it.
  ///
  /// It goes to the account the person named, or else the first one to
  /// spend from in the base currency. An account in another currency gets
  /// the amount converted, when there is a rate for it.
  Future<void> recordExpense(ExpenseToRecord expense) async {
    final Profile? p = profile;
    final Ledger? l = ledger;
    if (p == null || l == null) return;
    final Money inBase = Money(
      Decimal.parse('${l.major(expense.amount)}'),
      p.base,
    );
    Account? account = _accountNamed(expense.account);
    Money amount = inBase;
    if (account != null && account.asset != p.base) {
      final Money? converted = rates.convert(inBase, account.asset);
      if (converted == null) {
        account = null;
      } else {
        amount = converted;
      }
    }
    account ??= _mainAccount(p.base);
    if (account == null) return;
    await store.addEntry(
      accountId: account.id,
      amount: amount.amount.abs(),
      kind: EntryKind.expense,
      date: _now(),
      category: expense.category.name,
      payee: expense.note,
      source: 'gemini',
    );
    _pending?.cancel();
    await _reload();
  }

  Account? _accountNamed(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final String wanted = normalize(name);
    for (final Account a in accounts) {
      final String n = normalize(a.name);
      if (n == wanted || n.contains(wanted) || wanted.contains(n)) return a;
    }
    return null;
  }

  Account? _mainAccount(Asset base) {
    for (final Account a in accounts) {
      if (a.spendable && a.asset == base) return a;
    }
    for (final Account a in accounts) {
      if (a.spendable) return a;
    }
    return accounts.firstOrNull;
  }

  /// A message the person pasted or shared.
  Future<IngestReport> ingestText(String text) => capture.ingest(<CaptureEvent>[
    CaptureEvent(source: CaptureSource.paste, at: _now(), text: text),
  ]);

  void _schedule() {
    _pending?.cancel();
    _pending = Timer(Duration.zero, () => unawaited(_reload()));
  }

  Future<void> _reload() async {
    final StoreSnapshot? s = await store.snapshot();
    if (_disposed) return;
    _snapshot = s;
    _ratesFetchedAt = await store.ratesFetchedAt();
    // Read with everything else on each change, rather than through
    // streams of their own: one source of change, one rebuild.
    _inbox = await store.inbox(
      statuses: <InboxStatus>{InboxStatus.pending, InboxStatus.duplicate},
    );
    _automatic = <InboxItem>[
      for (final InboxItem i in await store.inbox(
        statuses: <InboxStatus>{InboxStatus.accepted},
        since: _now().subtract(const Duration(days: 14)),
      ))
        if (i.automatic) i,
    ];
    _captureSettings = await store.captureSettings();
    _plan = EnvelopePlan.fromJson(_json(await store.setting(_planKey)));
    _wishes = <Wish>[
      for (final Object? w in _list(await store.setting(_wishesKey)))
        ?Wish.fromJson(w),
    ];
    _scenarios = <Scenario>[
      for (final Object? x in _list(await store.setting(_scenariosKey)))
        ?Scenario.fromJson(x),
    ];

    _cushion = CushionSettings.fromJson(
      _json(await store.setting(_cushionKey)),
    );
    _reminder = switch (_json(await store.setting(_reminderKey))) {
      final Map<Object?, Object?> m => <String, String>{
        for (final MapEntry<Object?, Object?> e in m.entries)
          '${e.key}': '${e.value}',
      },
      _ => null,
    };
    if (_disposed) return;
    _configureListener();
    unawaited(_remind());
    if (s != null) {
      final DateTime day = today;
      appToday = day;
      format.baseCurrency = s.profile.base;
      final DateTime started = s.profile.schedule.lastOnOrBefore(day);
      final EnvelopePlan? plan = _plan;
      _build = buildLedger(
        s,
        today: day,
        setAside:
            plan != null &&
                plan.period ==
                    DateTime(started.year, started.month, started.day)
            ? plan.setAside
            : 0,
      );
      _balances = balancesOf(s.accounts, s.entries, day);
    } else {
      _build = null;
      _balances = const <String, Money>{};
    }
    _notify();
  }

  /// Hands the notification listener what it needs to know, when it
  /// changed.
  void _configureListener() {
    if (!readNative) return;
    final CaptureSettings s = _captureSettings;
    final String now = '${s.useLocation} ${(s.mutedApps.toList()..sort())}';
    if (now == _configured) return;
    _configured = now;
    unawaited(CaptureChannel.configure(s));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _portfolio?.dispose();
    _binance?.dispose();
    _wallets?.dispose();
    CaptureChannel.stop(this);
    _pending?.cancel();
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
