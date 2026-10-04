import 'package:flutter/foundation.dart' show immutable;

import '../money/money.dart';

/// What the person is worth: what the accounts hold, credit cards' debt
/// taken off, plus what others owe them, less what they owe others and
/// what is left to pay of purchases in instalments that no card holds.
///
/// Every part is in the base currency. [instalments] counts what is left
/// with interest included, as the schedule has it.
@immutable
class NetWorth {
  const NetWorth({
    required this.accounts,
    required this.owed,
    required this.owing,
    required this.instalments,
    this.estimated = false,
  });

  /// The accounts together, each one's debt taken off.
  final Money accounts;

  /// What others owe the person, from shared expenses and loans.
  final Money owed;

  /// What the person owes others, from shared expenses and loans.
  final Money owing;

  /// What is left to pay of purchases in instalments paid outside a
  /// credit card: a card's balance already holds its own.
  final Money instalments;

  /// Whether [instalments] is partly an estimate, a figure from the bank
  /// being missing.
  final bool estimated;

  Money get total => accounts + owed - owing - instalments;
}
