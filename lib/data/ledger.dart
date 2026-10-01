import 'category.dart';

/// Which way money moved.
enum Flow { expense, income, saving }

/// One line of the account statement.
class Movement {
  const Movement({
    required this.id,
    required this.date,
    required this.merchant,
    required this.amount,
    required this.category,
    this.flow = Flow.expense,
  });

  final String id;
  final DateTime date;
  final String merchant;

  /// Always positive, in whole pesos. [flow] says which way it went.
  final int amount;
  final Category category;
  final Flow flow;
}

/// Something charged every month until someone cancels it.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.chargeDay,
    required this.lastUsed,
    required this.since,
  });

  final String id;
  final String name;
  final int price;
  final int chargeDay;

  /// The last day the person actually used it, as far as the app can tell.
  final DateTime lastUsed;
  final DateTime since;
}

/// Money being put aside for one thing.
class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.monthly,
    required this.deadline,
  });

  final String id;
  final String name;
  final int target;
  final int saved;

  /// What goes into it every month today.
  final int monthly;
  final DateTime deadline;

  int get missing => target - saved;
}

/// The whole account, and the questions the agent can ask it.
///
/// Everything an answer shows is computed here from the movements, never
/// typed into a surface by hand, so the numbers in a scripted answer and in a
/// live one agree with each other and with the statement.
class Ledger {
  Ledger({
    required this.owner,
    required this.today,
    required this.openingBalance,
    required List<Movement> movements,
    required this.subscriptions,
    required this.goals,
  }) : movements = List<Movement>.of(movements)
         ..sort((Movement a, Movement b) => a.date.compareTo(b.date));

  final String owner;

  /// The date the app treats as today. Fixed, so the story holds whenever
  /// the demo is opened.
  final DateTime today;
  final int openingBalance;
  final List<Movement> movements;
  final List<Subscription> subscriptions;
  final List<Goal> goals;

  int get balance {
    var total = openingBalance;
    for (final Movement m in movements) {
      if (m.date.isAfter(today)) continue;
      total += m.flow == Flow.income ? m.amount : -m.amount;
    }
    return total;
  }

  /// The next payday after [today]: the 15th, or the last day of the month.
  DateTime get nextPayday {
    if (today.day < 15) return DateTime(today.year, today.month, 15);
    final DateTime last = DateTime(today.year, today.month + 1, 0);
    if (today.day < last.day) return last;
    return DateTime(today.year, today.month + 1, 15);
  }

  /// What is already committed between today and the next payday.
  int get committedUntilPayday {
    final DateTime payday = nextPayday;
    var total = 0;
    for (final Movement m in movements) {
      if (m.flow == Flow.income) continue;
      if (!m.date.isAfter(today) || m.date.isAfter(payday)) continue;
      total += m.amount;
    }
    return total;
  }

  /// What can be spent until the next payday without touching what is
  /// already committed.
  int get freeUntilPayday => balance - committedUntilPayday;

  Iterable<Movement> expensesIn(int year, int month) => movements.where(
    (Movement m) =>
        m.flow == Flow.expense &&
        m.date.year == year &&
        m.date.month == month &&
        !m.date.isAfter(today),
  );

  int spentIn(int year, int month) =>
      expensesIn(year, month).fold(0, (int sum, Movement m) => sum + m.amount);

  int incomeIn(int year, int month) => movements
      .where(
        (Movement m) =>
            m.flow == Flow.income &&
            m.date.year == year &&
            m.date.month == month,
      )
      .fold(0, (int sum, Movement m) => sum + m.amount);

  /// Spending per category in a month, largest first.
  List<MapEntry<Category, int>> byCategory(int year, int month) {
    final totals = <Category, int>{};
    for (final Movement m in expensesIn(year, month)) {
      totals[m.category] = (totals[m.category] ?? 0) + m.amount;
    }
    return totals.entries.toList()..sort(
      (MapEntry<Category, int> a, MapEntry<Category, int> b) =>
          b.value.compareTo(a.value),
    );
  }

  int spentOn(Category category, int year, int month) => expensesIn(year, month)
      .where((Movement m) => m.category == category)
      .fold(0, (int sum, Movement m) => sum + m.amount);

  List<Movement> largestIn(int year, int month, {int count = 5}) =>
      (expensesIn(year, month).toList()
            ..sort((Movement a, Movement b) => b.amount.compareTo(a.amount)))
          .take(count)
          .toList();

  List<Movement> inCategory(Category category, int year, int month) =>
      expensesIn(
          year,
          month,
        ).where((Movement m) => m.category == category).toList()
        ..sort((Movement a, Movement b) => b.date.compareTo(a.date));

  /// How many times something was bought in a category in a month.
  int countIn(Category category, int year, int month) =>
      inCategory(category, year, month).length;

  Goal goal(String id) => goals.firstWhere((Goal g) => g.id == id);

  int get subscriptionsMonthly =>
      subscriptions.fold(0, (int sum, Subscription s) => sum + s.price);

  /// Adds a movement the person registered by hand.
  void record(Movement movement) {
    movements
      ..add(movement)
      ..sort((Movement a, Movement b) => a.date.compareTo(b.date));
  }
}
