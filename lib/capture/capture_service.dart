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
    this.joined = 0,
  });

  /// Waiting in the inbox for the person.
  final int added;

  /// Recorded straight away, because everything about them was clear.
  final int recorded;
  final int duplicates;

  /// Not movements: security codes, ads, muted apps, text with no amount.
  final int ignored;

  /// The other side of a move between the person's accounts already
  /// recorded: the other bank's notice for the same money.
  final int joined;

  IngestReport operator +(IngestReport o) => IngestReport(
    added: added + o.added,
    recorded: recorded + o.recorded,
    duplicates: duplicates + o.duplicates,
    ignored: ignored + o.ignored,
    joined: joined + o.joined,
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
    final Profile? profile = await store.profile();
    final Asset base = profile?.base ?? Asset.cop;
    final String? person = profile?.name;
    final DateTime since = _now().subtract(lookBack);
    final List<InboxItem> recent = await store.inbox(since: since);
    final List<Entry> entries = await store.entries();
    // Each side of a move between the person's accounts counts too: the
    // other bank's alert for the same money is that side seen again.
    final Map<String, Entry> legs = <String, Entry>{
      for (final Entry e in entries)
        if (e.transferId != null) e.id: e,
    };
    // What the person shared lately, word for word: the same message read
    // again is the same payment, not one more to look at.
    final Set<String> shared = <String>{
      for (final InboxItem i in recent)
        if (i.status != InboxStatus.dismissed && _byHand(i.event.source))
          i.event.text.trim(),
    };
    final List<Sighting> known = <Sighting>[
      for (final InboxItem i in recent)
        if (i.status != InboxStatus.dismissed) ?_sighting(i),
      for (final Entry e in entries)
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
      if (_byHand(event.source) && shared.contains(event.text.trim())) {
        report += const IngestReport(duplicates: 1);
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
      final Entry? leg = twin == null ? null : legs[twin.id];
      if (leg != null && _isSideOf(item, leg, accounts)) {
        item = _joinedTo(item, leg);
        report += const IngestReport(joined: 1);
      } else if (twin != null) {
        item = item.copyWith(
          status: InboxStatus.duplicate,
          duplicateOf: twin.id,
        );
        report += const IngestReport(duplicates: 1);
      } else if (settings.autoRecord &&
          _clear(parsed, suggestion) &&
          ownMove(item, accounts, person: person) == null) {
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
      if (_byHand(event.source)) shared.add(event.text.trim());
    }
    return report;
  }

  /// Whether [source] is the person sharing a message or a picture, which
  /// they may do twice with the same one.
  static bool _byHand(CaptureSource source) =>
      source == CaptureSource.paste || source == CaptureSource.screenshot;

  /// What [Suggestion.why] holds for a notice found to be the other side
  /// of a move already recorded.
  static const String joined = 'joined';

  /// Whether [item]'s alert is about [leg]'s account: the one it was placed
  /// in, or one at the bank it came from.
  static bool _isSideOf(InboxItem item, Entry leg, Iterable<Account> accounts) {
    final String? here = item.suggestion.accountId;
    if (here != null) return here == leg.accountId;
    final String? bank = item.parsed.institution;
    return bank != null &&
        accountsAt(bank, accounts).any((Account a) => a.id == leg.accountId);
  }

  /// [item] recorded as [leg], the side of a move it is the notice of.
  static InboxItem _joinedTo(InboxItem item, Entry leg) => item.copyWith(
    status: InboxStatus.accepted,
    entryId: leg.id,
    automatic: true,
    suggestion: Suggestion(
      accountId: leg.accountId,
      category: item.suggestion.category,
      payee: item.suggestion.payee,
      place: item.suggestion.place,
      why: <String>[...item.suggestion.why, joined],
    ),
  );

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
      accounts,
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
    return Accepted(
      left,
      const <RuleChange>[],
      item: recorded,
      toAccountId: toAccountId,
      joined: await _joinWaiting(transferId, apart: item.id),
    );
  }

  /// Records with the move [transferId] the notices still waiting that are
  /// its other side, the other bank's alert for the same money, and gives
  /// them back as they were.
  Future<List<InboxItem>> _joinWaiting(
    String transferId, {
    required String apart,
  }) async {
    final List<Account> accounts = await store.accounts();
    final CaptureSettings settings = await store.captureSettings();
    final List<Entry> legs = <Entry>[
      for (final Entry e in await store.entries())
        if (e.transferId == transferId) e,
    ];
    final List<InboxItem> joined = <InboxItem>[];
    for (final InboxItem waiting in await store.inbox(
      statuses: <InboxStatus>{InboxStatus.pending},
    )) {
      if (waiting.id == apart) continue;
      final InboxItem i = withRules(waiting, settings, accounts);
      final Sighting? seen = _sighting(i, accounts: accounts);
      if (seen == null) continue;
      for (final Entry leg in legs) {
        final Sighting side = Sighting(
          id: leg.id,
          amount: leg.amount.abs(),
          asset: _asset(accounts, leg.accountId),
          kind: leg.amount < Decimal.zero
              ? EntryKind.expense
              : EntryKind.income,
          when: leg.date,
        );
        if (!samePayment(seen, side) || !_isSideOf(i, leg, accounts)) continue;
        await store.saveInboxItem(_joinedTo(i, leg));
        joined.add(waiting);
        break;
      }
    }
    return joined;
  }

  /// Learns from [item], recorded on its own, as the person corrected its
  /// movement: its category is the shop's from now on, and its account the
  /// card's or the bank's, as confirming it that way would have taught.
  /// The capture then says why it is filed as it is. What changed comes
  /// back, for the person to see and undo.
  Future<List<RuleChange>> corrected(InboxItem item) async {
    final String? id = item.entryId;
    if (id == null) return const <RuleChange>[];
    final Entry? now = (await store.entries())
        .where((Entry e) => e.id == id)
        .firstOrNull;
    if (now == null || now.transferId != null) return const <RuleChange>[];
    final List<RuleChange> learned = await _learn(
      item,
      await store.accounts(),
      accountId: now.accountId,
      category: now.category,
      payee: now.payee,
    );
    if (learned.isEmpty) return learned;
    final Set<RuleKind> kinds = <RuleKind>{
      for (final RuleChange c in learned) c.rule.kind,
    };
    const Set<String> place = <String>{
      'card',
      'account',
      'institution',
      'currency',
      'only',
    };
    List<String> why = item.suggestion.why;
    if (kinds.contains(RuleKind.merchant)) {
      why = <String>[
        for (final String w in why)
          if (w != 'merchant' && w != 'words' && w != 'learned') w,
        'learned',
      ];
    }
    for (final RuleKind k in <RuleKind>[
      RuleKind.card,
      RuleKind.account,
      RuleKind.institution,
    ]) {
      if (!kinds.contains(k)) continue;
      why = <String>[
        k.name,
        for (final String w in why)
          if (!place.contains(w)) w,
      ];
    }
    await store.saveInboxItem(
      item.copyWith(
        suggestion: Suggestion(
          accountId: now.accountId,
          category: now.category,
          payee: now.payee.isEmpty ? item.suggestion.payee : now.payee,
          place: item.suggestion.place,
          why: why,
        ),
      ),
    );
    return learned;
  }

  /// Takes back what [accept], [acceptAll] or [acceptTransfer] did: each
  /// movement goes, its capture waits in the inbox again, and every rule
  /// they taught says what it said before, the last one first.
  Future<void> takeBack(List<Accepted> done) async {
    for (final Accepted a in done) {
      await undo(a.item);
      for (final InboxItem j in a.joined) {
        await store.saveInboxItem(j);
      }
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
  /// inbox. A notice found to be the other side of a move recorded from
  /// another one leaves the move alone: it is a possible repeat of it again.
  Future<void> undo(InboxItem item) async {
    final String? id = item.entryId;
    if (id != null && item.suggestion.why.contains(joined)) {
      await store.saveInboxItem(
        InboxItem(
          id: item.id,
          event: item.event,
          parsed: item.parsed,
          suggestion: Suggestion(
            accountId: item.suggestion.accountId,
            category: item.suggestion.category,
            payee: item.suggestion.payee,
            place: item.suggestion.place,
            why: <String>[
              for (final String w in item.suggestion.why)
                if (w != joined) w,
            ],
          ),
          status: InboxStatus.duplicate,
          duplicateOf: id,
        ),
      );
      return;
    }
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

  /// The person says [item] is no move between their accounts: it waits as
  /// the income or the expense it reads as, and is not proposed again.
  Future<void> notOwnMove(InboxItem item) => store.saveInboxItem(
    item.copyWith(
      suggestion: Suggestion(
        accountId: item.suggestion.accountId,
        category: item.suggestion.category,
        payee: item.suggestion.payee,
        place: item.suggestion.place,
        why: <String>[...item.suggestion.why, notOwn],
      ),
    ),
  );

  /// What [Suggestion.why] holds once the person said a capture is not a
  /// move between their accounts.
  static const String notOwn = 'notOwn';

  /// The move between the person's own [accounts] that [item] most likely
  /// is, or null: money sent «a tu Nequi» or that came «desde tu
  /// Bancolombia», money from someone with the [person]'s own name or from
  /// a bank where they keep an account, cash taken out at an ATM, a credit
  /// card's payment. The side the alert is about is the capture's account;
  /// the other is the one the alert names, or the likeliest.
  static OwnMove? ownMove(
    InboxItem item,
    Iterable<Account> accounts, {
    String? person,
  }) {
    final ParsedCapture p = item.parsed;
    final String? here = item.suggestion.accountId;
    if (item.status != InboxStatus.pending ||
        !p.isMovement ||
        here == null ||
        item.suggestion.why.contains(notOwn)) {
      return null;
    }
    final Account? at = accounts.where((Account a) => a.id == here).firstOrNull;
    // What a card took or got back is a purchase or a refund.
    if (at == null || at.kind == AccountKind.card) return null;
    final MoveHint hint = moveOf(item);
    // The person's account at the bank the alert names as theirs: a bank
    // or a wallet, never a card.
    Account? theirs(String institution) => <Account>[
      for (final Account a in accountsAt(institution, accounts))
        if (a.id != here && a.kind != AccountKind.card) a,
    ].firstOrNull;
    if (p.kind == EntryKind.expense) {
      final (Account?, String) to = hint.own != null
          ? (theirs(hint.own!), 'own')
          : hint.withdrawal
          ? (_cashOf(accounts, at), 'cash')
          : hint.cardPayment
          ? (_cardPaid(item.event.text, accounts, at), 'card')
          : (null, '');
      final Account? there = to.$1;
      return there == null
          ? null
          : OwnMove(fromId: here, toId: there.id, why: to.$2);
    }
    final String sender = item.suggestion.payee ?? p.merchant ?? '';
    final String? bank = sender.isEmpty
        ? null
        : findInstitution(<String>[sender]);
    final (Account?, String) from = hint.own != null
        ? (theirs(hint.own!), 'own')
        : person != null && sender.isNotEmpty && sameName(person, sender)
        ? (_likelySource(accounts, at), 'self')
        : bank != null && bank != p.institution
        ? (theirs(bank), 'bank')
        : (null, '');
    final Account? there = from.$1;
    return there == null
        ? null
        : OwnMove(fromId: there.id, toId: here, why: from.$2);
  }

  /// Where cash taken out of [from] goes: the cash in its currency.
  static Account? _cashOf(Iterable<Account> accounts, Account from) => accounts
      .where(
        (Account a) =>
            a.kind == AccountKind.cash &&
            a.asset == from.asset &&
            a.id != from.id,
      )
      .firstOrNull;

  /// The card a payment out of [from] most likely paid: the only one in its
  /// currency, the one [text] names, or the only one at its bank.
  static Account? _cardPaid(
    String text,
    Iterable<Account> accounts,
    Account from,
  ) {
    final List<Account> cards = <Account>[
      for (final Account a in accounts)
        if (a.kind == AccountKind.card && a.asset == from.asset) a,
    ];
    if (cards.length < 2) return cards.firstOrNull;
    final String said = ' ${normalize(text)} ';
    final List<Account> named = <Account>[
      for (final Account c in cards)
        if (normalize(c.name)
            .split(' ')
            .any(
              (String w) =>
                  w.length > 2 &&
                  !_cardWords.contains(w) &&
                  said.contains(' $w '),
            ))
          c,
    ];
    if (named.length == 1) return named.single;
    if (from.institution.trim().isEmpty) return null;
    final List<Account> same = accountsAt(from.institution, cards);
    return same.length == 1 ? same.single : null;
  }

  /// Words in a card's name that every card's payment says.
  static const Set<String> _cardWords = <String>{
    'tarjeta',
    'credito',
    'debito',
    'card',
    'credit',
  };

  /// Where money the person sent themselves most likely came from: a bank
  /// or a wallet of theirs in the same currency, an everyday one first.
  static Account? _likelySource(Iterable<Account> accounts, Account to) {
    final List<Account> can = <Account>[
      for (final Account a in accounts)
        if (a.id != to.id &&
            a.asset == to.asset &&
            (a.kind == AccountKind.bank || a.kind == AccountKind.wallet))
          a,
    ];
    return can.where((Account a) => a.spendable).firstOrNull ?? can.firstOrNull;
  }

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
        moveOf(item),
        settings,
        accounts,
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
  /// account's, or its bank's; or else the bank's one account, which may
  /// have been added after the alert arrived.
  static ({String accountId, String why})? _ruledAccount(
    ParsedCapture p,
    MoveHint hint,
    CaptureSettings settings,
    Iterable<Account> accounts,
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
    if (institution == null) {
      final String? byNone = _unnamed(p)
          ? settings.use(RuleKind.institution, noBank)
          : null;
      return byNone == null ? null : (accountId: byNone, why: 'unnamed');
    }
    final String? byBank =
        (_bankSpeaksFor(p, institution, accounts)
            ? settings.use(RuleKind.institution, institution)
            : null) ??
        bankAccount(p, hint, institution, accounts)?.id;
    if (byBank != null) return (accountId: byBank, why: 'institution');
    return null;
  }

  /// Whether what the bank's alerts go to speaks for [p]: not for a card
  /// the app does not know yet when the bank has a credit card in the app,
  /// which that card may well be.
  static bool _bankSpeaksFor(
    ParsedCapture p,
    String institution,
    Iterable<Account> accounts,
  ) =>
      p.card == null ||
      !accountsAt(
        institution,
        accounts,
      ).any((Account a) => a.kind == AccountKind.card);

  /// The key of the rule for payments that name no bank, card or account,
  /// among the banks' rules.
  static const String noBank = '';

  /// Whether [p] names no bank, card or account, nor a currency of its
  /// own: nothing but the person's word says where it went.
  static bool _unnamed(ParsedCapture p) =>
      p.institution == null &&
      p.card == null &&
      p.account == null &&
      p.asset == null;

  /// What [item]'s alert says about money moving between the person's own
  /// accounts.
  static MoveHint moveOf(InboxItem item) => readMove(
    item.event.text,
    institution: item.parsed.institution,
    kind: item.parsed.kind,
  );

  /// The one account at [institution] that [p] can be about: the only one
  /// the person has there, or, for money that came in or that went to
  /// another of their accounts, as [hint] tells, the only one that is not
  /// a card, since a card takes purchases. Null when that leaves none or
  /// several.
  static Account? bankAccount(
    ParsedCapture p,
    MoveHint hint,
    String institution,
    Iterable<Account> accounts,
  ) {
    final List<Account> there = accountsAt(institution, accounts);
    if (there.length == 1) return there.single;
    final bool moves =
        p.kind == EntryKind.income ||
        hint.own != null ||
        hint.withdrawal ||
        hint.cardPayment;
    if (!moves) return null;
    final List<Account> banks = <Account>[
      for (final Account a in there)
        if (a.kind != AccountKind.card) a,
    ];
    return banks.length == 1 ? banks.single : null;
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
      accountId =
          (_bankSpeaksFor(parsed, institution, accounts)
              ? settings.use(RuleKind.institution, institution)
              : null) ??
          bankAccount(
            parsed,
            readMove(event.text, institution: institution, kind: parsed.kind),
            institution,
            accounts,
          )?.id;
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
    // What names no bank, card or account goes where the person said such
    // payments go.
    if (accountId == null && _unnamed(parsed)) {
      accountId = settings.use(RuleKind.institution, noBank);
      if (accountId != null) why.add('unnamed');
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
    InboxItem item,
    List<Account> accounts, {
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
    // A charge in another currency went where that currency is kept, and
    // an account at another bank is no account of this bank's: neither
    // says where the bank's other alerts go.
    if (institution != null &&
        card == null &&
        number == null &&
        teachesInstitution(item.parsed, (await store.profile())?.base) &&
        !elsewhere(institution, accounts, accountId)) {
      learn(RuleKind.institution, institution, accountId);
    }
    // A payment that named no bank, card or account, confirmed in the one
    // account it was guessed to be: the next ones go there, ready.
    if (_unnamed(item.parsed) &&
        item.suggestion.why.contains('only') &&
        item.suggestion.accountId == accountId) {
      learn(RuleKind.institution, noBank, accountId);
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
    this.toAccountId,
    this.joined = const <InboxItem>[],
  });

  final Entry entry;
  final List<RuleChange> learned;

  /// The capture as it stands now: recorded, pointing at [entry].
  final InboxItem item;

  /// How many other captures [learned] left ready to record.
  final int resolved;

  /// Where the money went, when it moved between the person's accounts:
  /// [entry] is the side it left.
  final String? toAccountId;

  /// The other bank's notices for the same move, recorded with it, as they
  /// were waiting.
  final List<InboxItem> joined;
}

/// Money moved between two of the person's accounts, as an alert proposes
/// it: where it left, where it arrived, and what gave it away.
@immutable
class OwnMove {
  const OwnMove({required this.fromId, required this.toId, required this.why});

  final String fromId;
  final String toId;

  /// `own`, the alert names the other account («a tu Nequi»); `self`, the
  /// person sent it to themselves; `bank`, it came from a bank where they
  /// keep an account; `cash`, an ATM withdrawal; `card`, a card's payment.
  final String why;
}

/// Whether [sender] is the [person]: every word of the person's name is in
/// it, the first one first, so «Diego» is «Diego Lopez» and «Diego López»
/// is «DIEGO LOPEZ G».
bool sameName(String person, String sender) {
  final List<String> mine = <String>[
    for (final String w in normalize(person).split(' '))
      if (w.length > 1) w,
  ];
  final List<String> theirs = normalize(sender).split(' ');
  return mine.isNotEmpty &&
      theirs.first == mine.first &&
      mine.every(theirs.contains);
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

/// Whether the account [id] is at a bank other than [institution]: it was
/// set up with another one. One set up with none may be anywhere.
bool elsewhere(String institution, Iterable<Account> accounts, String id) {
  final Account? account = accounts
      .where((Account a) => a.id == id)
      .firstOrNull;
  return account != null &&
      account.institution.trim().isNotEmpty &&
      !accountsAt(institution, <Account>[account]).contains(account);
}
