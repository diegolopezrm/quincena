import 'package:decimal/decimal.dart';

import '../capture/merchants.dart';
import 'statement.dart';
import 'tables.dart';
import 'values.dart';

/// A date at the start of a line: `30/09/2026`, `30/09`, `2026-09-30`,
/// `30 SEP 2026`, `30-sep`.
final RegExp _leadingDate = RegExp(
  r'^\s*(\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}'
  r'|\d{1,2}[/\-.]\d{1,2}(?:[/\-.]\d{2,4})?'
  r'|\d{1,2}[\s\-/.]?[A-Za-zÁÉÍÓÚáéíóú]{3,4}\.?(?:[\s\-/.]?\d{2,4})?)\b',
);

/// An amount as statements print it: with thousands grouped or cents,
/// maybe a `$`, a sign, parentheses or a CR/DB marker. A bare run of digits
/// is a reference number, not money.
final RegExp _money = RegExp(
  r'\(?[-−]?\s?\$?\s?(?:\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+[.,]\d{2})\)?-?(?:\s?(?:CR|DB|DR)\b)?',
  caseSensitive: false,
);

/// Words that say money came in, for a statement that prints no sign.
const List<String> _incomeWords = <String>[
  'abono',
  'consignacion',
  'deposito',
  'recibiste',
  'recibido',
  'transferencia de',
  'transferencia recibida',
  'pago nomina',
  'nomina',
  'salario',
  'intereses',
  'rendimientos',
  'reembolso',
  'devolucion',
  'reverso',
  'recarga desde',
  'pago recibido',
];

/// What also says money came in on a card's statement: there, a card
/// payment pays the debt down. On a bank's, it is money out.
const List<String> _cardIncomeWords = <String>['pago tarjeta'];

/// The years a statement names, to complete dates written without one.
int? _yearOf(String text) {
  final Map<int, int> seen = <int, int>{};
  for (final RegExpMatch m in RegExp(r'\b(20\d{2})\b').allMatches(text)) {
    final int y = int.parse(m.group(1)!);
    seen[y] = (seen[y] ?? 0) + 1;
  }
  if (seen.isEmpty) return null;
  return seen.entries
      .reduce(
        (MapEntry<int, int> a, MapEntry<int, int> b) =>
            b.value > a.value ? b : a,
      )
      .key;
}

/// The movements in the text of a statement, as read from its PDF.
///
/// A movement is a line that starts with a date and has an amount: what is
/// between them is the description, a second amount at the end is the
/// balance. Signs come from the statement when it prints them, from the
/// balance when it does not, and from words such as "abono" when neither
/// says.
StatementRead readStatementText(String text, {int? year}) {
  final int? namedYear = year ?? _yearOf(text);
  final List<_Raw> raws = <_Raw>[];
  for (final String line in text.split(RegExp(r'\r?\n'))) {
    final RegExpMatch? d = _leadingDate.firstMatch(line);
    if (d == null) continue;
    final DateTime? date = parseStatementDate(d.group(1)!, year: namedYear);
    if (date == null) continue;
    final String rest = line.substring(d.end);
    final List<RegExpMatch> amounts = _money.allMatches(rest).toList();
    if (amounts.isEmpty) continue;
    final String description = rest
        .substring(0, amounts.first.start)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final Decimal? amount = parseSignedAmount(amounts.first.group(0)!);
    if (amount == null || amount == Decimal.zero) continue;
    final Decimal? balance = amounts.length > 1
        ? parseSignedAmount(amounts.last.group(0)!)
        : null;
    raws.add(
      _Raw(
        date: date,
        description: description,
        amount: amount,
        balance: balance,
        signed:
            amount < Decimal.zero ||
            RegExp(
              r'(cr|db|dr)\b',
              caseSensitive: false,
            ).hasMatch(amounts.first.group(0)!),
      ),
    );
  }

  List<StatementLine> lines = <StatementLine>[
    for (final _Raw r in raws)
      StatementLine(
        date: r.date,
        description: r.description,
        amount: r.amount,
        balance: r.balance,
      ),
  ];
  final bool printedSigns = raws.any((_Raw r) => r.signed);
  final bool cardStatement = RegExp(
    r'tarjeta de credito|credit card',
  ).hasMatch(normalize(text));
  if (!printedSigns) {
    final List<StatementLine> byBalance = signFromBalance(lines);
    final bool balanceSaid = byBalance.any(
      (StatementLine l) => l.amount < Decimal.zero,
    );
    lines = balanceSaid
        ? byBalance
        : <StatementLine>[
            for (final StatementLine l in lines)
              StatementLine(
                date: l.date,
                description: l.description,
                amount: _soundsLikeIncome(l.description, card: cardStatement)
                    ? l.amount.abs()
                    : -l.amount.abs(),
                balance: l.balance,
              ),
          ];
  }
  return StatementRead(
    lines: lines,
    source: StatementSource.pdf,
    institution: firstInstitution(text),
  );
}

bool _soundsLikeIncome(String description, {required bool card}) {
  final String n = normalize(description);
  return _incomeWords.any((String w) => n.contains(w)) ||
      (card && _cardIncomeWords.any((String w) => n.contains(w)));
}

class _Raw {
  _Raw({
    required this.date,
    required this.description,
    required this.amount,
    required this.balance,
    required this.signed,
  });

  final DateTime date;
  final String description;
  final Decimal amount;
  final Decimal? balance;

  /// Whether the statement printed its sign.
  final bool signed;
}
