import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

/// One movement as a bank statement lists it.
@immutable
class StatementLine {
  const StatementLine({
    required this.date,
    required this.description,
    required this.amount,
    this.balance,
  });

  final DateTime date;
  final String description;

  /// Signed: negative when money left the account.
  final Decimal amount;

  /// The balance after it, when the statement shows one.
  final Decimal? balance;

  @override
  bool operator ==(Object other) =>
      other is StatementLine &&
      other.date == date &&
      other.description == description &&
      other.amount == amount &&
      other.balance == balance;

  @override
  int get hashCode => Object.hash(date, description, amount, balance);

  @override
  String toString() => '$date $description $amount';
}

/// How a statement was read.
enum StatementSource { csv, xlsx, pdf, gemini }

/// Everything read from one statement.
@immutable
class StatementRead {
  const StatementRead({
    required this.lines,
    required this.source,
    this.institution,
  });

  final List<StatementLine> lines;
  final StatementSource source;

  /// The bank the statement names, when it names one the app knows.
  final String? institution;

  bool get isEmpty => lines.isEmpty;
}
