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
      final Entry? leg = card ? _mirror(l, elsewhere) : null;
      if (leg != null) elsewhere.remove(leg);
      final String? other = !card
          ? null
          : leg?.accountId ?? _otherSide(l, account, accounts);
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
      // A move's side here carries the other statement's words, not this
      // one's.
      final String name = e.isTransfer
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
    if (account.kind == AccountKind.card) {
      return l.amount > Decimal.zero &&
          (_cardPaymentWords.hasMatch(plain) ||
              RegExp(r'\babono\b').hasMatch(plain));
    }
    return l.amount < Decimal.zero && _cardPaymentWords.hasMatch(plain);
  }

  /// The one movement in another account that is the other side of [l]:
  /// the opposite amount within [window] days. Null when there is none or
  /// more than one.
  Entry? _mirror(StatementLine l, List<Entry> elsewhere) {
    final List<Entry> found = <Entry>[
      for (final Entry e in elsewhere)
        if (e.amount == -l.amount &&
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

  /// The other account of the card payment [l]: the card a bank account
  /// paid, or the account a card's payment came from. The one the
  /// description names best, or the only one there is; null when that
  /// leaves more than one.
  String? _otherSide(StatementLine l, Account account, List<Account> all) {
    final bool card = account.kind == AccountKind.card;
    final List<Account> fits = <Account>[
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

  /// Records [chosen] in [account], a move between accounts with both its
  /// sides. Returns how many lines were recorded.
  Future<int> record(Account account, List<ImportCandidate> chosen) async {
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
    return n;
  }
}
