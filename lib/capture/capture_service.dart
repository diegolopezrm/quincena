import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
import '../store/store.dart';
import 'dedupe.dart';
import 'event.dart';
import 'inbox.dart';
import 'merchants.dart';
import 'parser.dart';
import 'places.dart';

/// What one round of ingestion did.
@immutable
class IngestReport {
  const IngestReport({
    this.added = 0,
    this.recorded = 0,
    this.duplicates = 0,
    this.ignored = 0,
  });

  /// Waiting in the inbox for the person.
  final int added;

  /// Recorded straight away, because everything about them was clear.
  final int recorded;
  final int duplicates;

  /// Not movements: security codes, ads, muted apps, text with no amount.
  final int ignored;

  IngestReport operator +(IngestReport o) => IngestReport(
    added: added + o.added,
    recorded: recorded + o.recorded,
    duplicates: duplicates + o.duplicates,
    ignored: ignored + o.ignored,
  );
}

/// Turns what the sources captured into movements, through the inbox.
class CaptureService {
  CaptureService(this.store, {this.places, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final QuincenaStore store;

  /// Looks up shops near where a payment happened; null leaves it out.
  final PlaceFinder? places;
  final DateTime Function() _now;

  /// How far back a new capture is compared with what is known.
  static const Duration lookBack = Duration(days: 3);

  Future<IngestReport> ingest(Iterable<CaptureEvent> events) async {
    if (events.isEmpty) return const IngestReport();
    final CaptureSettings settings = await store.captureSettings();
    final List<Account> accounts = await store.accounts();
    final DateTime since = _now().subtract(lookBack);
    final List<Sighting> known = <Sighting>[
      for (final InboxItem i in await store.inbox(since: since))
        if (i.status != InboxStatus.dismissed) ?_sighting(i),
      for (final Entry e in await store.entries())
        if (!e.date.isBefore(since) &&
            e.transferId == null &&
            e.amount != Decimal.zero)
          Sighting(
            id: e.id,
            amount: e.amount.abs(),
            asset: _asset(accounts, e.accountId),
            kind: e.amount < Decimal.zero
                ? EntryKind.expense
                : EntryKind.income,
            when: e.date,
            merchant: e.payee,
          ),
    ];

    var report = const IngestReport();
    for (final CaptureEvent event in events) {
      if (event.app != null && settings.mutedApps.contains(event.app)) {
        report += const IngestReport(ignored: 1);
        continue;
      }
      final ParsedCapture parsed = parseCapture(event);
      // A security code is never kept, not even as a dismissed item.
      if (parsed.ignored != null || parsed.amount == null) {
        report += const IngestReport(ignored: 1);
        continue;
      }
      final Suggestion suggestion = await _suggest(
        event,
        parsed,
        settings,
        accounts,
      );
      var item = InboxItem(
        id: store.newInboxId(),
        event: event,
        parsed: parsed,
        suggestion: suggestion,
        status: InboxStatus.pending,
      );
      final Sighting? seen = _sighting(item, accounts: accounts);
      final Sighting? twin = seen == null ? null : duplicateOf(seen, known);
      if (twin != null) {
        item = item.copyWith(
          status: InboxStatus.duplicate,
          duplicateOf: twin.id,
        );
        report += const IngestReport(duplicates: 1);
      } else if (settings.autoRecord && _clear(parsed, suggestion)) {
        final Entry entry = await _record(item, accounts);
        item = item.copyWith(
          status: InboxStatus.accepted,
          entryId: entry.id,
          automatic: true,
        );
        report += const IngestReport(recorded: 1);
      } else {
        report += const IngestReport(added: 1);
      }
      await store.saveInboxItem(item);
      if (seen != null) known.add(seen);
    }
    return report;
  }

  /// Records [item] as a movement, with whatever the person changed, and
  /// learns from it: the merchant's category, the card's account.
  Future<Entry> accept(
    InboxItem item, {
    required String accountId,
    String? category,
    String? payee,
    Decimal? amount,
    EntryKind? kind,
    DateTime? date,
  }) async {
    final List<Account> accounts = await store.accounts();
    final Entry entry = await _record(
      item,
      accounts,
      accountId: accountId,
      category: category,
      payee: payee,
      amount: amount,
      kind: kind,
      date: date,
    );
    await store.saveInboxItem(
      item.copyWith(status: InboxStatus.accepted, entryId: entry.id),
    );
    await _learn(
      item,
      accountId: accountId,
      category: category ?? entry.category,
      payee: entry.payee,
    );
    return entry;
  }

  /// Not a movement. With [muteApp], the app that posted it is not read
  /// again.
  Future<void> dismiss(InboxItem item, {bool muteApp = false}) async {
    await store.saveInboxItem(item.copyWith(status: InboxStatus.dismissed));
    final String? app = item.event.app;
    if (muteApp && app != null) {
      final CaptureSettings s = await store.captureSettings();
      await store.saveCaptureSettings(
        s.copyWith(mutedApps: <String>{...s.mutedApps, app}),
      );
    }
  }

  /// Takes back a movement recorded automatically: it goes back to the
  /// inbox.
  Future<void> undo(InboxItem item) async {
    final String? id = item.entryId;
    if (id != null) {
      for (final Entry e in await store.entries()) {
        if (e.id == id) await store.deleteEntry(e);
      }
    }
    await store.saveInboxItem(
      InboxItem(
        id: item.id,
        event: item.event,
        parsed: item.parsed,
        suggestion: item.suggestion,
        status: InboxStatus.pending,
      ),
    );
  }

  /// The person says it is not a repeat after all.
  Future<void> notDuplicate(InboxItem item) => store.saveInboxItem(
    InboxItem(
      id: item.id,
      event: item.event,
      parsed: item.parsed,
      suggestion: item.suggestion,
      status: InboxStatus.pending,
    ),
  );

  bool _clear(ParsedCapture p, Suggestion s) =>
      p.isMovement &&
      p.confidence >= 0.8 &&
      s.accountId != null &&
      s.category != null;

  Future<Suggestion> _suggest(
    CaptureEvent event,
    ParsedCapture parsed,
    CaptureSettings settings,
    List<Account> accounts,
  ) async {
    final List<String> why = <String>[];
    String? accountId;
    final String? card = parsed.card;
    if (card != null && settings.cardAccounts[card] != null) {
      accountId = settings.cardAccounts[card];
      why.add('card');
    }
    final String? institution = parsed.institution;
    if (accountId == null && institution != null) {
      accountId = settings.institutionAccounts[institution];
      if (accountId == null) {
        final List<Account> same = <Account>[
          for (final Account a in accounts)
            if (normalize(a.institution) == normalize(institution) ||
                normalize(a.name) == normalize(institution))
              a,
        ];
        if (same.length == 1) accountId = same.single.id;
      }
      if (accountId != null) why.add('institution');
    }
    if (accountId == null && parsed.asset != null) {
      final List<Account> same = <Account>[
        for (final Account a in accounts)
          if (a.asset == parsed.asset) a,
      ];
      if (same.length == 1) {
        accountId = same.single.id;
        why.add('currency');
      }
    }
    if (accountId != null && !accounts.any((Account a) => a.id == accountId)) {
      accountId = null;
    }

    String? payee = parsed.merchant;
    String? category;
    if (payee != null) {
      category = settings.merchantCategories[merchantKey(payee)];
      if (category != null) {
        why.add('learned');
      } else if (parsed.kind == EntryKind.expense) {
        category = knownCategory(payee);
        if (category != null) why.add('merchant');
      }
    }
    if (category == null && parsed.kind == EntryKind.income) {
      final String plain = normalize(event.text);
      category = plain.contains('nomina') || plain.contains('salario')
          ? 'salary'
          : plain.contains('reembolso') || plain.contains('devolucion')
          ? 'refund'
          : null;
      if (category != null) why.add('words');
    }

    NearbyPlace? place;
    final PlaceFinder? finder = places;
    if (settings.useLocation &&
        finder != null &&
        event.hasLocation &&
        parsed.kind == EntryKind.expense &&
        (payee == null || category == null)) {
      final List<NearbyPlace> near = await finder.near(
        event.latitude!,
        event.longitude!,
      );
      place =
          near.where((NearbyPlace p) => p.category != null).firstOrNull ??
          near.firstOrNull;
      if (place != null) {
        payee ??= place.name;
        category ??=
            settings.merchantCategories[merchantKey(place.name)] ??
            knownCategory(place.name) ??
            place.category;
        why.add('place');
      }
    }
    return Suggestion(
      accountId: accountId,
      category: category,
      payee: payee,
      place: place,
      why: why,
    );
  }

  Future<Entry> _record(
    InboxItem item,
    List<Account> accounts, {
    String? accountId,
    String? category,
    String? payee,
    Decimal? amount,
    EntryKind? kind,
    DateTime? date,
  }) async {
    final ParsedCapture p = item.parsed;
    final String account = accountId ?? item.suggestion.accountId!;
    final Asset target = _asset(accounts, account) ?? Asset.cop;
    Decimal value = amount ?? p.amount!;
    var note = '';
    // A dollar charge on a peso account: what the bank will take, roughly.
    if (amount == null && p.asset != null && p.asset != target) {
      final Money? converted = RateTable(
        await store.rates(),
      ).convert(Money(value, p.asset!), target);
      if (converted != null) {
        note = formatAmount(value, p.asset!, base: target);
        value = converted.amount.round(scale: target.decimals);
      }
    }
    final EntryKind k = kind ?? p.kind ?? EntryKind.expense;
    return store.addEntry(
      accountId: account,
      amount: value,
      kind: k,
      date: date ?? p.when ?? item.event.at,
      category:
          category ??
          item.suggestion.category ??
          (k == EntryKind.income ? 'other_income' : 'other'),
      payee: payee ?? item.suggestion.payee ?? '',
      note: note,
      source: item.event.source.name,
      sourceRef: item.id,
    );
  }

  Future<void> _learn(
    InboxItem item, {
    required String accountId,
    String? category,
    String? payee,
  }) async {
    final CaptureSettings s = await store.captureSettings();
    final String? key = payee == null || payee.isEmpty
        ? null
        : merchantKey(payee);
    final String? card = item.parsed.card;
    final String? institution = item.parsed.institution;
    await store.saveCaptureSettings(
      s.copyWith(
        merchantCategories: <String, String>{
          ...s.merchantCategories,
          if (key != null && key.isNotEmpty && category != null) key: category,
        },
        cardAccounts: <String, String>{...s.cardAccounts, ?card: accountId},
        institutionAccounts: <String, String>{
          ...s.institutionAccounts,
          if (institution != null && card == null) institution: accountId,
        },
      ),
    );
  }

  Sighting? _sighting(InboxItem i, {List<Account>? accounts}) {
    final ParsedCapture p = i.parsed;
    final Decimal? amount = p.amount;
    final EntryKind? kind = p.kind;
    if (amount == null || kind == null) return null;
    return Sighting(
      id: i.id,
      amount: amount,
      asset:
          p.asset ??
          (accounts == null || i.suggestion.accountId == null
              ? null
              : _asset(accounts, i.suggestion.accountId!)),
      kind: kind,
      when: p.when ?? i.event.at,
      merchant: p.merchant ?? i.suggestion.payee,
      source: i.event.source,
    );
  }

  Asset? _asset(List<Account> accounts, String accountId) {
    for (final Account a in accounts) {
      if (a.id == accountId) return a.asset;
    }
    return null;
  }
}
