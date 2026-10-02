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
  });

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

  /// Whether it is checked to import when the review opens.
  bool get proposed => !recorded && !importedBefore;

  bool get income => line.amount > Decimal.zero;

  ImportCandidate flipped() => ImportCandidate(
    line: StatementLine(
      date: line.date,
      description: line.description,
      amount: -line.amount,
      balance: line.balance,
    ),
    ref: ref,
    payee: payee,
    category: category,
    recorded: recorded,
    importedBefore: importedBefore,
  );
}

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
  /// it already is.
  Future<List<ImportCandidate>> prepare(
    Account account,
    StatementRead read,
  ) async {
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

    final List<Entry> kept = await store.entries(accountId: account.id);
    final Set<String> imported = <String>{
      for (final Entry e in kept)
        if (e.sourceRef?.startsWith('statement:') ?? false) e.sourceRef!,
    };
    // Movements in the account each match one line at most.
    final List<Entry> open = <Entry>[
      for (final Entry e in kept)
        if (!(e.sourceRef?.startsWith('statement:') ?? false)) e,
    ];
    final CaptureSettings settings = await store.captureSettings();

    final Map<String, int> seen = <String, int>{};
    final List<ImportCandidate> out = <ImportCandidate>[];
    for (final StatementLine l in lines) {
      final String key =
          '${l.date.toIso8601String().substring(0, 10)}|${l.amount}|${normalize(l.description)}';
      final int n = seen[key] = (seen[key] ?? 0) + 1;
      final String ref = 'statement:${account.id}:$key#$n';
      final String payee = payeeOf(l.description);
      final Entry? match = _match(l, payee, open);
      if (match != null) open.remove(match);
      out.add(
        ImportCandidate(
          line: l,
          ref: ref,
          payee: payee,
          category: _category(l, payee, settings),
          recorded: match != null,
          importedBefore: imported.contains(ref),
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
      final String name = e.payee.isNotEmpty ? e.payee : e.note;
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

  /// Records [chosen] in [account]. Returns how many were recorded.
  Future<int> record(Account account, List<ImportCandidate> chosen) async {
    var n = 0;
    for (final ImportCandidate c in chosen) {
      final bool income = c.line.amount > Decimal.zero;
      await store.addEntry(
        accountId: account.id,
        amount: c.line.amount.abs(),
        kind: income ? EntryKind.income : EntryKind.expense,
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
