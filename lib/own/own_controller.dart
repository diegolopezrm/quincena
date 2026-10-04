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
import '../domain/commitments.dart';
import '../domain/freelance.dart';
import '../domain/ledger_builder.dart';
import '../domain/plan.dart';
import '../domain/projection.dart';
import '../domain/records.dart';
import '../domain/shared.dart';
import '../domain/trips.dart';
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

  /// The rates the last fetch brought, kept to show the automatic value
  /// next to one the person typed.
  List<Rate> _lastFetched = const <Rate>[];
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

  /// What the reminders were last set to, to set them again only when it
  /// changes.
  String? _remindedFor;

  /// What the person told about each recurring charge, by its id.
  Map<String, ChargeMemory> _memories = const <String, ChargeMemory>{};
  List<Instalments> _instalments = const <Instalments>[];
  DetectiveState _detective = const DetectiveState();
  List<ChargeAlert>? _alerts;
  List<Group> _groups = const <Group>[];
  FreelancePlan _freelance = const FreelancePlan();
  List<Trip> _trips = const <Trip>[];
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

  /// The recurring charges, those paused included.
  List<RecurringCharge> get recurring =>
      _snapshot?.recurring ?? const <RecurringCharge>[];

  /// What the person told about the recurring charge [id].
  ChargeMemory memoryOf(String id) => _memories[id] ?? const ChargeMemory();

  /// The purchases in instalments, as the person typed them.
  List<Instalments> get instalments => _instalments;

  DetectiveState get detective => _detective;

  /// Everything the charge detective finds, before the person's answers.
  List<ChargeAlert> get allAlerts {
    final StoreSnapshot? s = _snapshot;
    if (s == null) return const <ChargeAlert>[];
    return _alerts ??= detectCharges(s.entries, today: today);
  }

  /// The alerts to show: not silenced, not put away.
  List<ChargeAlert> get alerts => _detective.shown(allAlerts);

  /// Merchants charged about the same each month that are not a fixed
  /// payment yet, nor ones the person said are not.
  List<RecurringGuess> get recurringGuesses {
    final Ledger? l = ledger;
    if (l == null) return const <RecurringGuess>[];
    // Every change rebuilds the ledger, so one guess per ledger holds.
    if (!identical(_guessedFrom, l)) {
      _guessedFrom = l;
      _guesses = guessRecurring(
        l,
        known: <String>[
          for (final RecurringCharge r in recurring) r.name,
          ..._detective.notRecurring,
        ],
      );
    }
    return _guesses;
  }

  Ledger? _guessedFrom;
  List<RecurringGuess> _guesses = const <RecurringGuess>[];

  Future<void> saveMemory(String id, ChargeMemory memory) =>
      _saveMemories(<String, ChargeMemory>{..._memories, id: memory});

  Future<void> forgetMemory(String id) => _saveMemories(<String, ChargeMemory>{
    for (final MapEntry<String, ChargeMemory> e in _memories.entries)
      if (e.key != id) e.key: e.value,
  });

  Future<void> _saveMemories(Map<String, ChargeMemory> memories) =>
      store.setSetting(
        _memoriesKey,
        jsonEncode(<String, Object?>{
          for (final MapEntry<String, ChargeMemory> e in memories.entries)
            e.key: e.value.toJson(),
        }),
      );

  /// Adds [plan], or replaces the one with its id.
  Future<void> saveInstalments(Instalments plan) =>
      _saveInstalments(<Instalments>[
        for (final Instalments p in _instalments)
          if (p.id != plan.id) p,
        plan,
      ]);

  Future<void> deleteInstalments(String id) => _saveInstalments(<Instalments>[
    for (final Instalments p in _instalments)
      if (p.id != id) p,
  ]);

  Future<void> _saveInstalments(List<Instalments> plans) => store.setSetting(
    _instalmentsKey,
    jsonEncode(<Object?>[for (final Instalments p in plans) p.toJson()]),
  );

  /// Keeps what the person made of the alert [id]; null takes it back.
  Future<void> answerAlert(String id, AlertAnswer? answer) => _saveDetective(
    _detective.withAnswer(
      id,
      answer,
      current: <String>[for (final ChargeAlert a in allAlerts) a.id],
    ),
  );

  /// Silences every alert of [kind], or lets them show again.
  Future<void> muteAlerts(AlertKind kind, {required bool muted}) =>
      _saveDetective(_detective.withMuted(kind, muted: muted));

  /// Stops offering [name] as a fixed payment.
  Future<void> notRecurring(String name) =>
      _saveDetective(_detective.withNotRecurring(name));

  Future<void> _saveDetective(DetectiveState state) =>
      store.setSetting(_detectiveKey, jsonEncode(state.toJson()));

  /// Asks the system to let the app notify, for a renewal or trial
  /// reminder. False when the person said no.
  Future<bool> allowReminders() => Reminders.ask();

  static const String _memoriesKey = 'commitments.memories';
  static const String _instalmentsKey = 'commitments.instalments';
  static const String _detectiveKey = 'commitments.detective';

  /// The groups the person shares expenses with.
  List<Group> get groups => _groups;

  Group? group(String id) => _groups.where((Group g) => g.id == id).firstOrNull;

  /// What others owe the person across every group, and what they owe.
  (int owed, int owing) get sharedBalance {
    var owed = 0;
    var owing = 0;
    for (final Group g in _groups) {
      final int b = g.balances[meId] ?? 0;
      if (b > 0) owed += b;
      if (b < 0) owing -= b;
    }
    return (owed, owing);
  }

  /// The group and expense that split the movement [entryId], if any.
  (Group, SharedExpense)? splitOf(String entryId) {
    for (final Group g in _groups) {
      for (final SharedExpense e in g.expenses) {
        if (e.entryId == entryId) return (g, e);
      }
    }
    return null;
  }

  /// Adds [group], or replaces the one with its id.
  Future<void> saveGroup(Group group) => _saveGroups(<Group>[
    for (final Group g in _groups)
      if (g.id != group.id) g,
    group,
  ]);

  Future<void> deleteGroup(String id) => _saveGroups(<Group>[
    for (final Group g in _groups)
      if (g.id != id) g,
  ]);

  Future<void> _saveGroups(List<Group> groups) => store.setSetting(
    _groupsKey,
    jsonEncode(<Object?>[for (final Group g in groups) g.toJson()]),
  );

  /// The person's variable income: what clients owe and the reserve.
  FreelancePlan get freelance => _freelance;

  Future<void> saveFreelance(FreelancePlan plan) =>
      store.setSetting(_freelanceKey, jsonEncode(plan.toJson()));

  /// What arrived from clients since the reserve started, in the base
  /// currency's smallest unit: incomes filed as freelance work and those
  /// linked to a collected payment.
  int get collectedForReserve {
    final StoreSnapshot? s = _snapshot;
    return s == null ? 0 : _collected(s, today);
  }

  int _collected(StoreSnapshot s, DateTime day) {
    final Asset base = s.profile.base;
    final RateTable table = RateTable(s.rates);
    final Decimal unit = Decimal.ten.pow(base.decimals).toDecimal();
    final DateTime? since = _freelance.reserveSince;
    final Set<String> linked = <String>{
      for (final ExpectedIncome i in _freelance.incomes)
        if (i.status == IncomeStatus.collected) ?i.entryId,
    };
    var total = 0;
    for (final Entry e in s.entries) {
      if (e.kind != EntryKind.income || e.amount <= Decimal.zero) continue;
      if (e.category != 'freelance' && !linked.contains(e.id)) continue;
      if (since != null && e.date.isBefore(since)) continue;
      if (e.date.isAfter(endOfDay(day))) continue;
      final Account? a = s.account(e.accountId);
      if (a == null) continue;
      final Money? m = table.convert(Money(e.amount, a.asset), base);
      if (m != null) total += (m.amount * unit).round().toBigInt().toInt();
    }
    return total;
  }

  /// Money that came into the person's accounts in the last [days] days,
  /// newest first: what a repayment or a client's payment can be linked to.
  List<Entry> recentIncomes({int days = 45}) {
    final StoreSnapshot? s = _snapshot;
    if (s == null) return const <Entry>[];
    final DateTime since = today.subtract(Duration(days: days));
    return <Entry>[
      for (final Entry e in s.entries)
        if (e.kind == EntryKind.income &&
            e.amount > Decimal.zero &&
            !e.date.isBefore(since) &&
            !e.date.isAfter(endOfDay(today)))
          e,
    ]..sort((Entry a, Entry b) => b.date.compareTo(a.date));
  }

  /// The person's trips, the newest first.
  List<Trip> get trips =>
      <Trip>[..._trips]..sort((Trip a, Trip b) => b.from.compareTo(a.from));

  Trip? trip(String id) => _trips.where((Trip t) => t.id == id).firstOrNull;

  /// Adds [trip], or replaces the one with its id.
  Future<void> saveTrip(Trip trip) => _saveTrips(<Trip>[
    for (final Trip t in _trips)
      if (t.id != trip.id) t,
    trip,
  ]);

  Future<void> deleteTrip(String id) => _saveTrips(<Trip>[
    for (final Trip t in _trips)
      if (t.id != id) t,
  ]);

  Future<void> _saveTrips(List<Trip> trips) => store.setSetting(
    _tripsKey,
    jsonEncode(<Object?>[for (final Trip t in trips) t.toJson()]),
  );

  /// Where [trip] stands today, from the movements as they are.
  TripSummary tripSummary(Trip trip) => TripSummary.of(
    trip,
    entries: _snapshot?.entries ?? const <Entry>[],
    assetOf: (String id) =>
        _snapshot?.account(id)?.asset ?? profile?.base ?? Asset.cop,
    rates: rates,
    today: today,
  );

  static const String _groupsKey = 'shared.groups';
  static const String _freelanceKey = 'freelance';
  static const String _tripsKey = 'trips';

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
      // The renewals stay: the next reload sets them without the close.
      await store.setSetting(_reminderKey, '');
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

  /// Whether the widget on the home screen leaves the amount out. This
  /// device's choice alone: it travels in no export and no sync.
  bool get widgetHidesAmounts => _widgetHides;
  bool _widgetHides = false;

  Future<void> hideWidgetAmounts(bool hide) =>
      store.setSetting(_widgetHideKey, hide ? 'yes' : '');

  static const String _widgetHideKey = 'widget.hideAmounts';

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

  /// Sets the reminders again when what they would say, or when, changed:
  /// the close on each payday when it is on, and the renewals and trials
  /// the person asked about.
  Future<void> _remind() async {
    final Profile? p = profile;
    if (p == null) return;
    final DateTime now = _now();
    final List<Reminder> all = <Reminder>[
      if (_reminder case final Map<String, String> words)
        for (final DateTime day in Reminders.days(p.schedule, now))
          Reminder(
            at: day,
            title: words['title'] ?? '',
            body: words['body'] ?? '',
          ),
      ...renewalReminders(recurring, _memories, now: now),
    ];
    final String signature = jsonEncode(<Object?>[
      for (final Reminder r in all)
        <Object?>[r.at.millisecondsSinceEpoch, r.title, r.body],
    ]);
    final String? before = _remindedFor;
    if (signature == before) return;
    _remindedFor = signature;
    if (all.isNotEmpty) {
      await Reminders.schedule(all);
    } else if (before != null) {
      await Reminders.cancel();
    }
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
    if (fetched.isNotEmpty) {
      _lastFetched = fetched;
      await store.saveRates(fetched);
    }
    _refreshing = false;
    await _reload();
  }

  /// What the sources said one [asset] is worth in [quote] at the last
  /// fetch, even where the person typed their own rate; null when this
  /// session has not fetched it.
  Decimal? fetchedRate(Asset asset, Asset quote) =>
      _lastFetched.isEmpty ? null : RateTable(_lastFetched).rate(asset, quote);

  /// Goes back from the rate the person typed for [asset] in [quote] to the
  /// automatic one. The new rates are fetched before the typed one is
  /// dropped: when they cannot convert the pair, offline or with a source
  /// down, the typed rate stays and this returns false, so the totals are
  /// never left without a rate.
  Future<bool> restoreAutomaticRate(String asset, String quote) async {
    final Profile? p = profile;
    if (p == null) return false;
    _refreshing = true;
    _notify();
    try {
      final List<Rate> fetched = await _fetcher.fetch(<Asset>[
        for (final Account a in accounts) a.asset,
        Asset.of(asset),
      ], p.base);
      if (fetched.isNotEmpty) _lastFetched = fetched;
      if (RateTable(fetched).rate(Asset.of(asset), Asset.of(quote)) == null) {
        return false;
      }
      await store.restoreRate(asset, quote, fetched);
      _ratesFailed = false;
      return true;
    } finally {
      _refreshing = false;
      await _reload();
    }
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
    _memories = switch (_json(await store.setting(_memoriesKey))) {
      final Map<Object?, Object?> m => <String, ChargeMemory>{
        for (final MapEntry<Object?, Object?> e in m.entries)
          '${e.key}': ChargeMemory.fromJson(e.value),
      },
      _ => const <String, ChargeMemory>{},
    };
    _instalments = <Instalments>[
      for (final Object? p in _list(await store.setting(_instalmentsKey)))
        ?Instalments.fromJson(p),
    ];
    _detective = DetectiveState.fromJson(
      _json(await store.setting(_detectiveKey)),
    );
    _alerts = null;
    _groups = <Group>[
      for (final Object? g in _list(await store.setting(_groupsKey)))
        ?Group.fromJson(g),
    ];
    _freelance = FreelancePlan.fromJson(
      _json(await store.setting(_freelanceKey)),
    );
    _trips = <Trip>[
      for (final Object? t in _list(await store.setting(_tripsKey)))
        ?Trip.fromJson(t),
    ];
    _reminder = switch (_json(await store.setting(_reminderKey))) {
      final Map<Object?, Object?> m => <String, String>{
        for (final MapEntry<Object?, Object?> e in m.entries)
          '${e.key}': '${e.value}',
      },
      _ => null,
    };
    _widgetHides = await store.setting(_widgetHideKey) == 'yes';
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
        instalments: _instalments,
        shared: SharedLinks.of(_groups),
        expected: _freelance.ahead(day),
        reserved: _freelance.reservePercent > 0
            ? _freelance.reserve(_collected(s, day))
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
