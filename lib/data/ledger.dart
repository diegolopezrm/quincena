import 'dart:math' as math;

import '../domain/pay_schedule.dart';
import '../money/asset.dart';
import 'category.dart';

/// Which way money moved.
enum Flow {
  expense,
  income,

  /// Put aside: out of the money to spend, but not spent.
  saving,

  /// Back from savings or an investment: into the money to spend, but not
  /// earned.
  transferIn,
}

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

  /// Always positive, in the ledger's [Ledger.currency] and its smallest
  /// unit: whole pesos, or cents. [flow] says which way it went.
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
    required this.since,
    this.lastUsed,
  });

  final String id;
  final String name;
  final int price;
  final int chargeDay;

  /// The last day the person actually used it, when the app can tell. A
  /// charge read from a bank says nothing about use.
  final DateTime? lastUsed;
  final DateTime since;

  /// Days since it was last used, or null when that is not known.
  int? daysSinceUsed(DateTime today) =>
      lastUsed == null ? null : today.difference(lastUsed!).inDays;

  /// Charged for over a month without being used, as far as is known.
  bool unusedAsOf(DateTime today) => (daysSinceUsed(today) ?? 0) > 30;
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
    this.schedule = const TwiceMonthly(first: 15, second: 31),
    this.currency = Asset.cop,
    List<Movement> upcoming = const <Movement>[],
  }) : movements = List<Movement>.of(movements)
         ..sort((Movement a, Movement b) => a.date.compareTo(b.date)),
       upcoming = List<Movement>.unmodifiable(upcoming);

  final String owner;

  /// The date the app treats as today. Fixed, so the story holds whenever
  /// the demo is opened.
  final DateTime today;
  final int openingBalance;
  final List<Movement> movements;
  final List<Subscription> subscriptions;
  final List<Goal> goals;

  /// How the person gets paid.
  final PaySchedule schedule;

  /// The currency every amount here is in, converted from each account's own.
  final Asset currency;

  /// Charges expected before payday that are not movements yet: the next
  /// rent, a subscription about to renew.
  final List<Movement> upcoming;

  /// [amount] in whole units of [currency]: pesos stay as they are, cents
  /// become dollars. What the agent's tools and the catalog read.
  num major(int amount) => currency.decimals == 0
      ? amount
      : amount / math.pow(10, currency.decimals);

  int get balance {
    var total = openingBalance;
    for (final Movement m in movements) {
      if (_day(m.date).isAfter(today)) continue;
      total += m.flow == Flow.income || m.flow == Flow.transferIn
          ? m.amount
          : -m.amount;
    }
    return total;
  }

  /// The next payday after [today].
  DateTime get nextPayday => schedule.nextAfter(today);

  /// What is already committed between today and the next payday.
  int get committedUntilPayday {
    final DateTime payday = nextPayday;
    var total = 0;
    for (final Movement m in <Movement>[...movements, ...upcoming]) {
      if (m.flow == Flow.income || m.flow == Flow.transferIn) continue;
      final DateTime day = _day(m.date);
      if (!day.isAfter(today) || day.isAfter(payday)) continue;
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
        !_day(m.date).isAfter(today),
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

/// The calendar day of [moment]: a movement at noon today is today's, not
/// the future's.
DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
