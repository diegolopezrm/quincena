import 'package:genui_gen/genui_gen.dart';

import '../data/category.dart';

part 'shapes.genui.dart';

/// One category of a month's spending.
@GenUiData(
  description:
      'How much went to one spending category in a period. A list of these is '
      'what a SpendingDonut draws.',
)
class CategorySlice {
  const CategorySlice({required this.category, required this.amount});

  /// The spending category.
  final Category category;

  /// Pesos spent on it in the period, as a positive whole number.
  final double amount;
}

/// One month of spending, for a chart over several months.
@GenUiData(
  description:
      'What was spent in one month. A list of these, oldest first, is what a '
      'MonthBars chart draws.',
)
class MonthTotal {
  const MonthTotal({
    required this.month,
    required this.amount,
    this.highlight = false,
  });

  /// The month, written as YYYY-MM.
  final String month;

  /// Pesos spent that month, as a positive whole number.
  final double amount;

  /// Whether this is the month the answer is about. At most one month in a
  /// chart should be highlighted.
  final bool highlight;
}

/// One payment from the statement.
@GenUiData(
  description: 'One payment from the account statement, as the bank lists it.',
)
class MovementItem {
  const MovementItem({
    required this.merchant,
    required this.category,
    required this.amount,
    required this.date,
  });

  /// Who was paid, exactly as the statement names them.
  final String merchant;

  /// The spending category the payment belongs to.
  final Category category;

  /// Pesos paid, as a positive whole number.
  final double amount;

  /// The day it was charged, written as YYYY-MM-DD.
  final String date;
}

/// A subscription, as the savings calculation sees it.
@GenUiData(
  description:
      'A subscription charged every month, whether the person wants to keep '
      'it, and whether they already cancelled it.',
)
class SubscriptionItem {
  const SubscriptionItem({
    required this.name,
    required this.price,
    required this.keep,
    this.cancelled = false,
  });

  /// The service, as the statement names it.
  final String name;

  /// What it costs every month, in pesos.
  final double price;

  /// Whether the person wants to keep paying for it.
  final bool keep;

  /// Whether the person says they already cancelled it with the service.
  final bool cancelled;
}
