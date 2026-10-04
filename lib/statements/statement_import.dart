import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../capture/dedupe.dart';
import '../capture/inbox.dart';
import '../capture/merchants.dart';
import '../domain/records.dart';
import '../store/store.dart';
import 'statement.dart';

/// A statement line as it would be recorded, and whether it already is.
@immutable
class ImportCandidate {
  const ImportCandidate({
    required this.line,
    required this.ref,
    required this.payee,
    required this.category,
    required this.recorded,
    required this.importedBefore,
    required this.kind,
    this.otherAccountId,
    this.otherLeg,
    this.cardPayment = false,
  });

  /// The line, signed for the account: what the person changes on it
  /// changes its sign too.
  final StatementLine line;

  /// What marks it as this statement's line, so importing the same
  /// statement again finds it.
  final String ref;
  final String payee;
  final String? category;

  /// A movement already in the account matches it: entered by hand or
  /// caught from a notification.
  final bool recorded;

  /// This very line was imported from a statement before.
  final bool importedBefore;

  /// What it is recorded as: an expense or an income, as its sign says, a
  /// move between the person's own accounts, or what the person said.
  final EntryKind kind;

  /// The other of the person's accounts, for a move between them.
  final String? otherAccountId;

  /// The move's side already recorded in [otherAccountId], such as a card
  /// payment imported from the bank's statement as an expense: recording
  /// the line joins the two.
  final Entry? otherLeg;

  /// It reads like the payment of a credit card.
  final bool cardPayment;

  /// Whether it is checked to import when the review opens.
  bool get proposed => !recorded && !importedBefore;

  bool get income => line.amount > Decimal.zero;

  /// A copy with what is given; [clearOther] forgets the other account and
  /// its side before taking the ones given.
  ImportCandidate copyWith({
    Decimal? amount,
    EntryKind? kind,
    String? category,
    bool clearCategory = false,
    String? otherAccountId,
    Entry? otherLeg,
    bool clearOther = false,
    bool? cardPayment,
  }) => ImportCandidate(
    line: amount == null
        ? line
        : StatementLine(
            date: line.date,
            description: line.description,
            amount: amount,
            balance: line.balance,
          ),
    ref: ref,
    payee: payee,
    category: clearCategory ? null : (category ?? this.category),
    recorded: recorded,
    importedBefore: importedBefore,
    kind: kind ?? this.kind,
    otherAccountId: otherAccountId ?? (clearOther ? null : this.otherAccountId),
    otherLeg: otherLeg ?? (clearOther ? null : this.otherLeg),
    cardPayment: cardPayment ?? this.cardPayment,
  );
}

/// How a bank names the payment of a credit card, in its plain words.
final RegExp _cardPaymentWords = RegExp(
  r'\b(pago|abono)\s+(de\s+|a\s+)?(tarjeta|tarj|tc|tdc)\b'
  r'|\bpago (recibido|gracias)\b|\bsu pago\b',
);

/// What says money came back from a purchase, not that a card was paid.
final RegExp _refundWords = RegExp(
  r'\b(devolucion|reverso|reversion|reembolso|reintegro|anulacion)\b',
);

/// Words in an account's name that say nothing about which one it is.
const Set<String> _plainWords = <String>{
  'tarjeta',
  'tarj',
  'credito',
  'debito',
  'tc',
  'tdc',
  'cuenta',
  'ahorros',
  'corriente',
  'banco',
  'pago',
  'de',
  'del',
  'la',
  'el',
  'mi',
  'card',
  'credit',
  'debit',
  'account',
  'bank',
  'my',
  'the',
};

/// Prefixes banks put before a merchant's name.
final RegExp _prefix = RegExp(
  r'^(compra(s)?( en| pos| internacional| nacional)?|pago( pse| en| a| de| por)?|'
  r'transf(erencia)?( a| de| desde| hacia)?|abono( de)?|retiro( cajero| en)?|'
  r'cargo( de)?|debito( automatico)?|purchase( at)?|payment( to)?)\s+',
  caseSensitive: false,
);

/// The merchant or the other party in a statement's description: `COMPRA EN
/// EXITO LAURELES 1234` becomes `Exito Laureles`.
String payeeOf(String description) {
  var s = description.trim();
  for (var i = 0; i < 2; i++) {
    final String before = s;
    s = s.replaceFirst(_prefix, '').trim();
    if (s == before) break;
  }
  // Reference numbers and card digits at the end.
  s = s.replaceFirst(RegExp(r'(\s+[*#]?\d[\d\-*]{2,})+$'), '').trim();
  if (s.isEmpty) s = description.trim();
  // A transfer names a person: every word capitalized, short ones too.
  if (RegExp(
    r'^(transf|abono de)',
    caseSensitive: false,
  ).hasMatch(description.trim())) {
    return s
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(
          (String w) =>
              w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
  }
  return prettyMerchant(s);
}

/// What an import does with the balance the person wrote for an account.
enum BalanceRule {
  /// A line dated before [Account.balanceSince] was already in the balance
  /// the person wrote: it is saved to show where the money went, and
  /// today's balance stays.
  keep,

  /// Every line moves the balance, an older one too.
  add,

  /// The balance at the statement's last line is the one it prints.
  statement,
}

/// What a statement says an account held at the end of [day].
typedef ClosingBalance = ({DateTime day, Decimal amount});

/// Turns a statement into movements of one account.
class StatementImporter {
  StatementImporter(this.store);

  final QuincenaStore store;

  /// How many days a statement can list a movement after it was recorded:
  /// a purchase on Friday can post on Monday.
  static const int window = 3;

  /// Each line of [read] as it would be recorded in [account], and whether
  /// it already is. [flip] turns every sign around, for a statement whose
  /// money in and out came the wrong way.
  Future<List<ImportCandidate>> prepare(
    Account account,
    StatementRead read, {
    bool flip = false,
  }) async {
    List<StatementLine> lines = read.lines;
    // A card statement lists purchases as positive: on a card they are
    // debt, money out.
    if (account.kind == AccountKind.card &&
        lines.where((StatementLine l) => l.amount > Decimal.zero).length >
            lines.length / 2) {
      lines = <StatementLine>[
        for (final StatementLine l in lines)
          StatementLine(
            date: l.date,
            description: l.description,
            amount: -l.amount,
            balance: l.balance,
          ),
      ];
    }

    final List<Account> accounts = await store.accounts();
    final List<Entry> everywhere = await store.entries();
    // What this account's own statements brought is found by its mark;
    // the side of a move another statement brought here is matched like
    // anything else in the account.
    final String mine = 'statement:${account.id}:';
    final List<Entry> kept = <Entry>[
      for (final Entry e in everywhere)
        if (e.accountId == account.id) e,
    ];
    final Set<String> imported = <String>{
      for (final Entry e in kept)
        if (e.sourceRef?.startsWith(mine) ?? false) e.sourceRef!,
    };
    // Movements in the account each match one line at most.
    final List<Entry> open = <Entry>[
      for (final Entry e in kept)
        if (!(e.sourceRef?.startsWith(mine) ?? false)) e,
    ];
    // Expenses and incomes in the person's other accounts of the same
    // asset: one can be the other side of a card payment.
    final Set<String> sameAsset = <String>{
      for (final Account a in accounts)
        if (a.id != account.id && a.asset == account.asset) a.id,
    };
    final List<Entry> elsewhere = <Entry>[
      for (final Entry e in everywhere)
        if (sameAsset.contains(e.accountId) &&
            e.transferId == null &&
            !e.isTrade &&
            (e.kind == EntryKind.expense || e.kind == EntryKind.income))
          e,
    ];
    final CaptureSettings settings = await store.captureSettings();

    final Map<String, int> seen = <String, int>{};
    final List<ImportCandidate> out = <ImportCandidate>[];
    for (final StatementLine read in lines) {
      // The line keeps its mark however its sign is read.
      final String key =
          '${read.date.toIso8601String().substring(0, 10)}|${read.amount}|${normalize(read.description)}';
      final int n = seen[key] = (seen[key] ?? 0) + 1;
      final String ref = 'statement:${account.id}:$key#$n';
      final StatementLine l = flip
          ? StatementLine(
              date: read.date,
              description: read.description,
              amount: -read.amount,
              balance: read.balance,
            )
          : read;
      final String payee = payeeOf(l.description);
      final Entry? match = _match(l, payee, open);
      if (match != null) open.remove(match);
      final bool before = imported.contains(ref);
      // A card payment moves money between two of the person's accounts:
      // a move when its other side is clear, a question otherwise.
      final bool card = match == null && !before && _isCardPayment(l, account);
      final List<Account> sides = card
          ? _sides(account, accounts)
          : const <Account>[];
      final Entry? leg = card ? _mirror(l, elsewhere, sides) : null;
      if (leg != null) elsewhere.remove(leg);
      final String? other = !card ? null : leg?.accountId ?? _named(l, sides);
      out.add(
        ImportCandidate(
          line: l,
          ref: ref,
          payee: payee,
          category: _category(l, payee, settings),
          recorded: match != null,
          importedBefore: before,
          kind: other != null
              ? EntryKind.transfer
              : l.amount > Decimal.zero
              ? EntryKind.income
              : EntryKind.expense,
          otherAccountId: other,
          otherLeg: leg,
          cardPayment: card,
        ),
      );
    }
    return out;
  }

  /// The movement already in the account that is this line, if any: the
  /// same amount, the same direction, within [window] days, and when both
  /// name someone, names that share a word.
  Entry? _match(StatementLine l, String payee, List<Entry> entries) {
    Entry? best;
    var closest = window + 1;
    for (final Entry e in entries) {
      if (e.amount != l.amount) continue;
      final int days = DateTime(
        e.date.year,
        e.date.month,
        e.date.day,
      ).difference(l.date).inDays.abs();
      if (days > window || days >= closest) continue;
      // A move's side another statement brought here carries that
      // statement's words, not this one's.
      final String name = e.isTransfer && e.source == 'statement'
          ? ''
          : (e.payee.isNotEmpty ? e.payee : e.note);
      if (name.isNotEmpty &&
          payee.isNotEmpty &&
          !similarNames(name, payee) &&
          !similarNames(name, l.description)) {
        continue;
      }
      best = e;
      closest = days;
    }
    return best;
  }

  /// Whether [l] reads like a card payment: money out of an account to a
  /// card, or money into a card.
  bool _isCardPayment(StatementLine l, Account account) {
    final String plain = normalize(l.description);
    if (_refundWords.hasMatch(plain)) return false;
    if (account.kind == AccountKind.card) {
      return l.amount > Decimal.zero &&
          (_cardPaymentWords.hasMatch(plain) ||
              RegExp(r'\babono\b').hasMatch(plain));
    }
    return l.amount < Decimal.zero && _cardPaymentWords.hasMatch(plain);
  }

  /// The one movement in one of [sides] that is the other side of [l]:
  /// the opposite amount within [window] days. Null when there is none or
  /// more than one.
  Entry? _mirror(StatementLine l, List<Entry> elsewhere, List<Account> sides) {
    final Set<String> ids = <String>{for (final Account a in sides) a.id};
    final List<Entry> found = <Entry>[
      for (final Entry e in elsewhere)
        if (ids.contains(e.accountId) &&
            e.amount == -l.amount &&
            DateTime(
                  e.date.year,
                  e.date.month,
                  e.date.day,
                ).difference(l.date).inDays.abs() <=
                window)
          e,
    ];
    return found.length == 1 ? found.single : null;
  }

  /// The accounts that can be the other side of a card payment in
  /// [account]: the cards a bank account pays, or the accounts a card's
  /// payment comes from.
  List<Account> _sides(Account account, List<Account> all) {
    final bool card = account.kind == AccountKind.card;
    return <Account>[
      for (final Account a in all)
        if (a.id != account.id &&
            a.asset == account.asset &&
            (card
                ? a.spendable &&
                      (a.kind == AccountKind.bank ||
                          a.kind == AccountKind.wallet)
                : a.kind == AccountKind.card))
          a,
    ];
  }

  /// The one of [fits] the card payment [l] goes with: the one its
  /// description names best, or the only one there is; null when that
  /// leaves more than one.
  String? _named(StatementLine l, List<Account> fits) {
    final Set<String> words = normalize(l.description).split(' ').toSet();
    int named(Account a) => normalize('${a.name} ${a.institution}')
        .split(' ')
        .where(
          (String w) =>
              w.length >= 2 && !_plainWords.contains(w) && words.contains(w),
        )
        .toSet()
        .length;
    final List<int> scores = <int>[for (final Account a in fits) named(a)];
    final int best = scores.fold(0, (int a, int b) => a > b ? a : b);
    if (best == 0) return fits.length == 1 ? fits.single.id : null;
    final List<Account> top = <Account>[
      for (var i = 0; i < fits.length; i++)
        if (scores[i] == best) fits[i],
    ];
    return top.length == 1 ? top.single.id : null;
  }

  String? _category(StatementLine l, String payee, CaptureSettings settings) {
    final String? learned = settings.merchantCategories[merchantKey(payee)];
    if (learned != null) return learned;
    if (l.amount < Decimal.zero) return knownCategory(payee);
    final String plain = normalize(l.description);
    if (plain.contains('nomina') || plain.contains('salario')) return 'salary';
    if (plain.contains('reembolso') || plain.contains('devolucion')) {
      return 'refund';
    }
    return null;
  }

  /// Whether a line dated [date] is from before the balance the person
  /// wrote for [account].
  static bool older(Account account, DateTime date) {
    final DateTime? since = account.balanceSince;
    return since != null &&
        date.isBefore(DateTime(since.year, since.month, since.day));
  }

  /// The balance the statement [all] ends on: the one printed after its
  /// last line, when every line prints one and each follows from the one
  /// before it and the line's amount. Null otherwise; for a card, whose
  /// statement prints its debt its own way; and when it ends before the
  /// balance the person wrote, which is newer than it.
  static ClosingBalance? closing(Account account, List<ImportCandidate> all) {
    if (account.kind == AccountKind.card) return null;
    final List<StatementLine> lines = <StatementLine>[
      for (final ImportCandidate c in all) c.line,
    ];
    if (lines.length < 2 || lines.any((StatementLine l) => l.balance == null)) {
      return null;
    }
    // Oldest first or newest first: whichever the balances follow.
    bool follows(List<StatementLine> ordered) {
      for (var i = 1; i < ordered.length; i++) {
        if (ordered[i - 1].balance! + ordered[i].amount != ordered[i].balance) {
          return false;
        }
      }
      return true;
    }

    final List<StatementLine> newestFirst = lines.reversed.toList();
    final StatementLine? last = follows(lines)
        ? lines.last
        : follows(newestFirst)
        ? newestFirst.last
        : null;
    if (last == null || older(account, last.date)) return null;
    return (day: last.date, amount: last.balance!);
  }

  /// What [account] opens with once [chosen] are recorded under [rule].
  /// [entries] are the movements already in the account, and [closing]
  /// the statement's last balance, which [BalanceRule.statement] matches.
  static Decimal openingAfter(
    Account account,
    Iterable<ImportCandidate> chosen,
    BalanceRule rule, {
    Iterable<Entry> entries = const <Entry>[],
    ClosingBalance? closing,
  }) {
    switch (rule) {
      case BalanceRule.add:
        return account.opening;
      case BalanceRule.keep:
        var before = Decimal.zero;
        for (final ImportCandidate c in chosen) {
          if (older(account, c.line.date)) before += c.line.amount;
        }
        return account.opening - before;
      case BalanceRule.statement:
        if (closing == null) return account.opening;
        final DateTime until = endOfDay(closing.day);
        var held = Decimal.zero;
        for (final Entry e in entries) {
          if (e.accountId == account.id && !e.date.isAfter(until)) {
            held += e.amount;
          }
        }
        for (final ImportCandidate c in chosen) {
          if (!c.line.date.isAfter(until)) held += c.line.amount;
        }
        return closing.amount - held;
    }
  }

  /// Records [chosen] in [account], a move between accounts with both its
  /// sides, and keeps the balances the person wrote as [rule] says.
  /// Returns how many lines were recorded.
  Future<int> record(
    Account account,
    List<ImportCandidate> chosen, {
    BalanceRule rule = BalanceRule.add,
    ClosingBalance? closing,
  }) async {
    final List<Entry> before = rule == BalanceRule.statement
        ? await store.entries(accountId: account.id)
        : const <Entry>[];
    var n = 0;
    for (final ImportCandidate c in chosen) {
      final bool out = c.line.amount < Decimal.zero;
      final String? other = c.otherAccountId;
      final Entry? leg = c.otherLeg;
      if (c.kind == EntryKind.transfer && leg != null) {
        // Its other side is already there: the two become one move.
        final Entry entry = await store.addEntry(
          accountId: account.id,
          amount: c.line.amount.abs(),
          kind: out ? EntryKind.expense : EntryKind.income,
          date: c.line.date,
          payee: c.payee,
          note: c.line.description,
          source: 'statement',
          sourceRef: c.ref,
        );
        await store.linkAsTransfer(
          out: out ? entry : leg,
          into: out ? leg : entry,
        );
        n++;
        continue;
      }
      if (c.kind == EntryKind.transfer && other != null) {
        await store.addTransfer(
          fromAccountId: out ? account.id : other,
          toAccountId: out ? other : account.id,
          sent: c.line.amount.abs(),
          date: c.line.date,
          note: c.line.description,
          source: 'statement',
          sourceRef: c.ref,
        );
        n++;
        continue;
      }
      final EntryKind kind = c.kind == EntryKind.transfer
          ? (out ? EntryKind.expense : EntryKind.income)
          : c.kind;
      final bool income = kind == EntryKind.income;
      await store.addEntry(
        accountId: account.id,
        amount: c.line.amount.abs(),
        kind: kind,
        date: c.line.date,
        category: c.category ?? (income ? 'other_income' : 'other'),
        payee: c.payee,
        note: c.line.description,
        source: 'statement',
        sourceRef: c.ref,
      );
      n++;
    }
    await _keepBalances(account, chosen, rule, before, closing);
    return n;
  }

  /// Moves the openings [rule] asks for: this account's, and for a move to
  /// another account whose balance was also written after it, that one's.
  Future<void> _keepBalances(
    Account account,
    List<ImportCandidate> chosen,
    BalanceRule rule,
    List<Entry> before,
    ClosingBalance? closing,
  ) async {
    if (rule == BalanceRule.add) return;
    final List<Account> all = await store.accounts(archived: true);
    final Map<String, Decimal> shifts = <String, Decimal>{
      account.id:
          openingAfter(
            account,
            chosen,
            rule,
            entries: before,
            closing: closing,
          ) -
          account.opening,
    };
    for (final ImportCandidate c in chosen) {
      final String? other = c.otherAccountId;
      if (c.kind != EntryKind.transfer || c.otherLeg != null || other == null) {
        continue;
      }
      final Account? there = all
          .where((Account a) => a.id == other)
          .firstOrNull;
      // Its side there moved that account by the opposite amount.
      if (there != null && older(there, c.line.date)) {
        shifts[other] = (shifts[other] ?? Decimal.zero) + c.line.amount;
      }
    }
    for (final Account a in all) {
      final Decimal? shift = shifts[a.id];
      if (shift == null || shift == Decimal.zero) continue;
      await store.updateAccount(a.copyWith(opening: a.opening + shift));
    }
  }
}
