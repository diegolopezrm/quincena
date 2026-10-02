import 'dart:async';

import 'package:flutter/foundation.dart';

import '../capture/capture_service.dart';
import '../capture/event.dart';
import '../capture/inbox.dart';
import '../capture/native_channel.dart';
import '../capture/native_inbox.dart';
import '../capture/places.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../domain/ledger_builder.dart';
import '../domain/records.dart';
import '../format/money.dart' as format;
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rate_sources.dart';
import '../money/rates.dart';
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
  final DateTime Function() _now;

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
  CaptureSettings _captureSettings = const CaptureSettings();
  bool _pulling = false;
  bool _pullAgain = false;
  String? _configured;
  Timer? _pending;
  bool _disposed = false;

  StoreSnapshot? get snapshot => _snapshot;

  /// Captures waiting for the person, and the ones that may be repeats.
  List<InboxItem> get inbox => _inbox;
  List<InboxItem> get pendingInbox => <InboxItem>[
    for (final InboxItem i in _inbox)
      if (i.status == InboxStatus.pending) i,
  ];
  CaptureSettings get captureSettings => _captureSettings;
  Profile? get profile => _snapshot?.profile;
  Ledger? get ledger => _build?.ledger;

  /// Assets held somewhere that no known rate converts to the base.
  Set<Asset> get unconverted => _build?.unconverted ?? const <Asset>{};
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

  /// What the accounts hold together in the base currency: all of them, or
  /// only those whose money is to spend.
  Money total({bool spendableOnly = false}) {
    final Asset base = profile?.base ?? Asset.cop;
    var sum = Money.zero(base);
    for (final Account a in accounts) {
      if (spendableOnly && !a.spendable) continue;
      final Money? converted = inBase(_balances[a.id] ?? a.openingMoney);
      if (converted != null) sum += converted;
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
    } finally {
      _pulling = false;
    }
    return report;
  }

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
    _captureSettings = await store.captureSettings();
    if (_disposed) return;
    _configureListener();
    if (s != null) {
      final DateTime day = today;
      appToday = day;
      format.baseCurrency = s.profile.base;
      _build = buildLedger(s, today: day);
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
    CaptureChannel.stop(this);
    _pending?.cancel();
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
