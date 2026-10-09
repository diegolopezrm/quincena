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
    final Asset base = (await store.profile())?.base ?? Asset.cop;
    final DateTime since = _now().subtract(lookBack);
    // Each side of a move between the person's accounts counts too: the
    // other bank's alert for the same money is that side seen again.
    final List<Sighting> known = <Sighting>[
      for (final InboxItem i in await store.inbox(since: since))
        if (i.status != InboxStatus.dismissed) ?_sighting(i),
      for (final Entry e in await store.entries())
        if (!e.date.isBefore(since) && e.amount != Decimal.zero)
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
        base,
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
  /// learns from it: the merchant's category, the card's account. What it
  /// learned comes back, for the person to see and undo.
  Future<Accepted> accept(
    InboxItem item, {
    required String accountId,
    String? category,
    String? payee,
    Decimal? amount,
    EntryKind? kind,
    DateTime? date,
    String note = '',
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
      note: note,
    );
    final InboxItem recorded = item.copyWith(
      status: InboxStatus.accepted,
      entryId: entry.id,
    );
    await store.saveInboxItem(recorded);
    final CaptureSettings before = await store.captureSettings();
    final List<RuleChange> learned = await _learn(
      item,
      accountId: accountId,
      category: category ?? entry.category,
      payee: entry.payee,
    );
    return Accepted(
      entry,
      learned,
      item: recorded,
      resolved: learned.isEmpty
          ? 0
          : await _resolved(before, await store.captureSettings(), accounts),
    );
  }

  /// How many captures still waiting were not ready under [before] and are
  /// under [after]: what a confirmation's rules settled for the person.
  Future<int> _resolved(
    CaptureSettings before,
    CaptureSettings after,
    List<Account> accounts,
  ) async {
    var n = 0;
    for (final InboxItem i in await store.inbox(
      statuses: <InboxStatus>{InboxStatus.pending},
    )) {
      if (!isReady(withRules(i, before, accounts), accounts) &&
          isReady(withRules(i, after, accounts), accounts)) {
        n++;
      }
    }
    return n;
  }

  /// Records each of [items] as the app proposes it, as [accept] would one
  /// at a time. One that stopped waiting meanwhile is left as it is.
  Future<List<Accepted>> acceptAll(Iterable<InboxItem> items) async {
    final Set<String> waiting = <String>{
      for (final InboxItem i in await store.inbox(
        statuses: <InboxStatus>{InboxStatus.pending},
      ))
        i.id,
    };
    return <Accepted>[
      for (final InboxItem i in items)
        if (waiting.contains(i.id) && i.suggestion.accountId != null)
          await accept(
            i,
            accountId: i.suggestion.accountId!,
            category: i.suggestion.category,
            payee: i.suggestion.payee,
          ),
    ];
  }

  /// Records [item] as money the person moved between their own accounts:
  /// a transfer, neither income nor spending, so nothing is learned from
  /// it.
  Future<Accepted> acceptTransfer(
    InboxItem item, {
    required String fromAccountId,
    required String toAccountId,
    required Decimal sent,
    Decimal? received,
    required DateTime date,
    String note = '',
  }) async {
    final String transferId = await store.addTransfer(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      sent: sent,
      received: received,
      date: date,
      note: note,
      source: item.event.source.name,
      sourceRef: item.id,
    );
    final Entry left = (await store.entries(
      accountId: fromAccountId,
    )).firstWhere((Entry e) => e.transferId == transferId);
    final InboxItem recorded = item.copyWith(
      status: InboxStatus.accepted,
      entryId: left.id,
    );
    await store.saveInboxItem(recorded);
    return Accepted(left, const <RuleChange>[], item: recorded);
  }

  /// Takes back what [accept], [acceptAll] or [acceptTransfer] did: each
  /// movement goes, its capture waits in the inbox again, and every rule
  /// they taught says what it said before, the last one first.
  Future<void> takeBack(List<Accepted> done) async {
    for (final Accepted a in done) {
      await undo(a.item);
    }
    final List<RuleChange> learned = <RuleChange>[
      for (final Accepted a in done.reversed) ...a.learned.reversed,
    ];
    if (learned.isNotEmpty) await forget(learned);
  }

  /// Takes back what a confirmation taught: each rule goes back to what it
  /// said before, or away when it was new.
  Future<void> forget(Iterable<RuleChange> changes) async {
    CaptureSettings s = await store.captureSettings();
    for (final RuleChange c in changes) {
      final String? previous = c.previous;
      s = previous == null
          ? s.withoutRule(c.rule)
          : s.withRule(c.rule.copyWith(target: previous));
    }
    await store.saveCaptureSettings(s);
  }

  /// Not a movement. With [muteApp], the app that posted it is not read
  /// again.
  Future<void> dismiss(InboxItem item, {bool muteApp = false}) async {
    await store.saveInboxItem(item.copyWith(status: InboxStatus.dismissed));
    final String? app = item.event.app;
    if (muteApp && app != null) {
      final CaptureSettings s = await store.captureSettings();
      final String? name = item.parsed.institution ?? item.event.appName;
      await store.saveCaptureSettings(
        s.copyWith(
          mutedApps: <String>{...s.mutedApps, app},
          appNames: <String, String>{...s.appNames, app: ?name},
        ),
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

  /// Whether confirming [p] teaches where its institution's alerts go:
  /// only an alert in the [base] currency, or with a bare `$`, does.
  static bool teachesInstitution(ParsedCapture p, Asset? base) =>
      p.asset == null || p.asset == (base ?? Asset.cop);

  /// Whether [p] can be recorded without asking. An account guessed only
  /// because it is the one in pesos is proposed, never assumed.
  static bool _clear(ParsedCapture p, Suggestion s) =>
      p.isMovement &&
      p.confidence >= 0.8 &&
      s.accountId != null &&
      !s.why.contains('only') &&
      s.category != null;

  /// Whether [item] can be recorded in one tap: it says how much and which
  /// way, and its account is one of [accounts], not only guessed. A missing
  /// category does not stop it: it goes to Otros, or Otros ingresos.
  static bool isReady(InboxItem item, Iterable<Account> accounts) =>
      item.parsed.isMovement &&
      !item.suggestion.why.contains('only') &&
      accounts.any((Account a) => a.id == item.suggestion.accountId);

  /// Whether [item] is as clear as what is recorded without asking, and is
  /// not a possible repeat: what can be recorded with others in one go.
  static bool isClear(InboxItem item, Iterable<Account> accounts) =>
      item.status == InboxStatus.pending &&
      _clear(item.parsed, item.suggestion) &&
      isReady(item, accounts);

  /// [item] as the rules stand now, as one arriving now would take them:
  /// a capture still waiting with no account, or one only guessed, takes
  /// the one its card's rule, its account's or else its bank's says; and
  /// its merchant takes the category the person taught. Turning a rule off
  /// or deleting it leaves the capture as it arrived.
  static InboxItem withRules(
    InboxItem item,
    CaptureSettings settings,
    Iterable<Account> accounts,
  ) {
    if (item.status != InboxStatus.pending) return item;
    final Suggestion s = item.suggestion;
    String? accountId = s.accountId;
    String? category = s.category;
    List<String> why = s.why;
    if (accountId == null || why.contains('only')) {
      final ({String accountId, String why})? ruled = _ruledAccount(
        item.parsed,
        settings,
      );
      if (ruled != null &&
          accounts.any((Account a) => a.id == ruled.accountId)) {
        accountId = ruled.accountId;
        why = <String>[
          ruled.why,
          for (final String w in why)
            if (w != 'only') w,
        ];
      }
    }
    final String? payee = s.payee ?? item.parsed.merchant;
    final String? learned = payee == null || payee.isEmpty
        ? null
        : settings.use(RuleKind.merchant, merchantKey(payee));
    if (learned != null && learned != category) {
      category = learned;
      why = <String>[
        for (final String w in why)
          if (w != 'merchant' && w != 'words' && w != 'learned') w,
        'learned',
      ];
    }
    // A rule can confirm the very account that was only guessed: the
    // account stays, and the guess is known now.
    if (accountId == s.accountId &&
        category == s.category &&
        listEquals(why, s.why)) {
      return item;
    }
    return item.copyWith(
      suggestion: Suggestion(
        accountId: accountId,
        category: category,
        payee: s.payee,
        place: s.place,
        why: why,
      ),
    );
  }

  /// The account the rules send [p] to, and which rule: its card's, its
  /// account's, or its bank's.
  static ({String accountId, String why})? _ruledAccount(
    ParsedCapture p,
    CaptureSettings settings,
  ) {
    final String? card = p.card;
    final String? byCard = card == null
        ? null
        : settings.use(RuleKind.card, card);
    if (byCard != null) return (accountId: byCard, why: 'card');
    final String? number = p.account;
    final String? byNumber = number == null
        ? null
        : _byNumber(settings, number);
    if (byNumber != null) return (accountId: byNumber, why: 'account');
    final String? institution = p.institution;
    final String? byBank = institution == null
        ? null
        : settings.use(RuleKind.institution, institution);
    if (byBank != null) return (accountId: byBank, why: 'institution');
    return null;
  }

  /// The account an account's last [digits] go to: its rule, or a card's
  /// with the same digits, which is how they were learned before the app
  /// told an account's digits from a card's.
  static String? _byNumber(CaptureSettings settings, String digits) =>
      settings.use(RuleKind.account, digits) ??
      settings.use(RuleKind.card, digits);

  Future<Suggestion> _suggest(
    CaptureEvent event,
    ParsedCapture parsed,
    CaptureSettings settings,
    List<Account> accounts,
    Asset base,
  ) async {
    final List<String> why = <String>[];
    String? accountId;
    final String? card = parsed.card;
    if (card != null && settings.use(RuleKind.card, card) != null) {
      accountId = settings.use(RuleKind.card, card);
      why.add('card');
    }
    final String? number = parsed.account;
    if (accountId == null && number != null) {
      accountId = _byNumber(settings, number);
      if (accountId != null) why.add('account');
    }
    final String? institution = parsed.institution;
    if (accountId == null && institution != null) {
      accountId = settings.use(RuleKind.institution, institution);
      if (accountId == null) {
        final List<Account> same = accountsAt(institution, accounts);
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
    // A bare `$` is pesos in Colombia, or whatever the base is: with a
    // single account in it, that is the likely one. Not when the alert
    // names a bank the person has no account in.
    if (accountId == null && parsed.asset == null && institution == null) {
      final List<Account> same = <Account>[
        for (final Account a in accounts)
          if (a.asset == base && a.spendable) a,
      ];
      if (same.length == 1) {
        accountId = same.single.id;
        why.add('only');
      }
    }
    if (accountId != null && !accounts.any((Account a) => a.id == accountId)) {
      accountId = null;
    }

    String? payee = parsed.merchant;
    String? category;
    if (payee != null) {
      category = settings.use(RuleKind.merchant, merchantKey(payee));
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
        (event.accuracy ?? 0) <= PlaceFinder.usefulAccuracy &&
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
    String note = '',
  }) async {
    final ParsedCapture p = item.parsed;
    final String account = accountId ?? item.suggestion.accountId!;
    final Asset target = _asset(accounts, account) ?? Asset.cop;
    Decimal value = amount ?? p.amount!;
    // What the person wrote, after the amount as charged when it was
    // converted.
    var said = note.trim();
    // A dollar charge on a peso account: what the bank will take, roughly.
    if (amount == null && p.asset != null && p.asset != target) {
      final Money? converted = RateTable(
        await store.rates(),
      ).convert(Money(value, p.asset!), target);
      if (converted != null) {
        said = <String>[
          formatAmount(value, p.asset!, base: target),
          if (said.isNotEmpty) said,
        ].join(' · ');
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
      note: said,
      source: item.event.source.name,
      sourceRef: item.id,
    );
  }

  /// Turns what the person confirmed into rules, and says which ones are
  /// new or changed. A rule the person turned off is left as it is.
  Future<List<RuleChange>> _learn(
    InboxItem item, {
    required String accountId,
    String? category,
    String? payee,
  }) async {
    CaptureSettings s = await store.captureSettings();
    final String? key = payee == null || payee.isEmpty
        ? null
        : merchantKey(payee);
    final String? card = item.parsed.card;
    final String? number = item.parsed.account;
    final String? institution = item.parsed.institution;
    final List<RuleChange> changes = <RuleChange>[];
    var named = false;
    void learn(RuleKind kind, String key, String target, {String? name}) {
      final CaptureRule rule = CaptureRule(
        kind: kind,
        key: key,
        target: target,
      );
      if (s.disabledRules.contains(rule.id)) return;
      final String? before = switch (kind) {
        RuleKind.merchant => s.merchantCategories[key],
        RuleKind.card => s.cardAccounts[key],
        RuleKind.account => s.accountNumbers[key],
        RuleKind.institution => s.institutionAccounts[key],
      };
      // The name as the card showed it, for the rule to say it that way.
      if (name != null && name.isNotEmpty && s.merchantNames[key] != name) {
        s = s.withMerchantName(key, name);
        named = true;
      }
      if (before == target) return;
      s = s.withRule(rule);
      changes.add(RuleChange(rule, previous: before, name: name));
    }

    if (key != null && key.isNotEmpty && category != null) {
      learn(RuleKind.merchant, key, category, name: payee?.trim());
    }
    // The most precise thing the alert names: the card, or else the
    // account's digits, or else the bank.
    if (card != null) learn(RuleKind.card, card, accountId);
    if (number != null && card == null) {
      learn(RuleKind.account, number, accountId);
    }
    // A charge in another currency went where that currency is kept: it
    // says nothing about where the bank's other alerts go.
    if (institution != null &&
        card == null &&
        number == null &&
        teachesInstitution(item.parsed, (await store.profile())?.base)) {
      learn(RuleKind.institution, institution, accountId);
    }
    if (changes.isNotEmpty || named) await store.saveCaptureSettings(s);
    return changes;
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

/// A capture recorded, and the rules recording it taught.
class Accepted {
  const Accepted(
    this.entry,
    this.learned, {
    required this.item,
    this.resolved = 0,
  });

  final Entry entry;
  final List<RuleChange> learned;

  /// The capture as it stands now: recorded, pointing at [entry].
  final InboxItem item;

  /// How many other captures [learned] left ready to record.
  final int resolved;
}

/// The person's accounts at [institution], by the bank they were set up
/// with or by their name: the ones an alert from it may be about.
List<Account> accountsAt(String institution, Iterable<Account> accounts) =>
    <Account>[
      for (final Account a in accounts)
        if (normalize(a.institution) == normalize(institution) ||
            normalize(a.name) == normalize(institution))
          a,
    ];
