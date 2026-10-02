import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../data/category.dart';
import '../data/ledger.dart';
import 'projection.dart';

/// Where buying something leaves the money to spend.
enum PurchaseVerdict {
  /// The lowest point stays at or above the cushion.
  fits,

  /// It stays above zero, but goes under the cushion.
  belowCushion,

  /// The money runs out before the pay that would cover it.
  short,
}

/// A purchase tried out against the projection: how low the money gets
/// between buying it and the payday after, and what that means. It is an
/// estimate from what is known, never a promise that the purchase is safe.
@immutable
class PurchaseCheck {
  const PurchaseCheck({
    required this.price,
    required this.date,
    required this.until,
    required this.lowest,
    required this.lowestOn,
    required this.verdict,
    required this.reliesOnPay,
    required this.payUnknown,
    required this.projection,
  });

  /// In the ledger's smallest unit.
  final int price;

  /// The day it would be bought.
  final DateTime date;

  /// The payday that closes the window it was weighed in.
  final DateTime until;

  /// The lowest the money gets in that window, with the purchase in it,
  /// and on which day.
  final int lowest;
  final DateTime lowestOn;
  final PurchaseVerdict verdict;

  /// Bought after the next payday, it counts on the pay the person said
  /// they get, which has not arrived yet.
  final bool reliesOnPay;

  /// Bought after the next payday, but the app does not know what the pay
  /// is: the check counts no pay at all.
  final bool payUnknown;

  /// The projection with the purchase in it, as something tried out.
  final Projection projection;
}

/// Weighs buying something for [price] on [date] against the money to
/// spend: the lowest it gets from that day to the payday after it.
///
/// [tryOut] adds what else the person is trying, such as a charge moved to
/// another day; the check counts it with the purchase.
PurchaseCheck checkPurchase(
  Ledger ledger, {
  required int price,
  required DateTime date,
  String label = '',
  List<ProjectedEvent> tryOut = const <ProjectedEvent>[],
  int atLeast = 0,
}) {
  final DateTime today = _day(ledger.today);
  final DateTime day = _day(date).isBefore(today) ? today : _day(date);
  final DateTime until = _day(ledger.schedule.nextAfter(day));
  final bool afterPay = day.isAfter(_day(ledger.nextPayday));
  final bool reliesOnPay = afterPay && ledger.pay != null;
  final Projection p = Projection.of(
    ledger,
    horizon: math.max(until.difference(today).inDays, atLeast),
    tryOut: <ProjectedEvent>[
      ProjectedEvent(
        date: day,
        amount: -price,
        certainty: Certainty.hypothetical,
        kind: ProjectedKind.tryOut,
        label: label,
      ),
      ...tryOut,
    ],
  );
  // The likely balance has everything tried out. Before payday the pay it
  // expects does not count; after it, it does, except the pay of the
  // closing day: what matters is getting there.
  int expected = 0;
  int? lowest;
  DateTime lowestOn = day;
  for (final ProjectedDay d in p.days) {
    expected += _payOn(d);
    if (d.date.isBefore(day) || d.date.isAfter(until)) continue;
    final int b = !reliesOnPay
        ? d.likely - expected
        : d.date == until
        ? d.likely - _payOn(d)
        : d.likely;
    if (lowest == null || b < lowest) {
      lowest = b;
      lowestOn = d.date;
    }
  }
  final int low = lowest ?? ledger.balance - price;
  return PurchaseCheck(
    price: price,
    date: day,
    until: until,
    lowest: low,
    lowestOn: lowestOn,
    verdict: low < 0
        ? PurchaseVerdict.short
        : low < ledger.cushion
        ? PurchaseVerdict.belowCushion
        : PurchaseVerdict.fits,
    reliesOnPay: reliesOnPay,
    payUnknown: afterPay && ledger.pay == null,
    projection: p,
  );
}

int _payOn(ProjectedDay d) => d.events
    .where(
      (ProjectedEvent e) =>
          e.kind == ProjectedKind.pay || e.kind == ProjectedKind.latePay,
    )
    .fold(0, (int sum, ProjectedEvent e) => sum + e.amount);

/// How one category moved from one pay period to the one before.
@immutable
class CategoryChange {
  const CategoryChange(this.category, this.now, this.before);

  final Category category;
  final int now;

  /// Null when there is no period before to compare with.
  final int? before;

  int get difference => now - (before ?? 0);
}

/// The one thing the close suggests, if any.
enum CloseAction {
  /// A day ahead goes under the cushion.
  tightDay,

  /// A category grew a lot against the period before.
  lookAtCategory,

  /// Money is left free and there is a goal to take it to.
  moveToGoal,
}

/// The pay period that just ended, in three parts: what changed against
/// the one before, what comes until the next payday, and one thing to do.
///
/// Periods are compared whole, payday to payday. Without a whole period
/// recorded there is no close; without the one before, nothing is compared
/// and no trend is drawn.
@immutable
class PeriodClose {
  const PeriodClose({
    required this.start,
    required this.end,
    required this.spent,
    required this.income,
    required this.spentBefore,
    required this.changes,
    required this.coming,
    required this.action,
    this.tightDay,
    this.actionCategory,
  });

  /// The period: from [start], a payday, to the day before [end], the
  /// payday that closed it.
  final DateTime start;
  final DateTime end;
  final int spent;
  final int income;

  /// The period before; null without a whole one recorded.
  final int? spentBefore;

  /// Largest movement first.
  final List<CategoryChange> changes;

  /// What is committed until the next payday.
  final List<Movement> coming;
  final CloseAction? action;
  final DateTime? tightDay;
  final Category? actionCategory;

  /// The movements behind [category] in the period.
  List<Movement> movementsOf(Ledger ledger, Category category) => <Movement>[
    for (final Movement m in ledger.movements)
      if (m.flow == Flow.expense &&
          m.category == category &&
          !_day(m.date).isBefore(start) &&
          _day(m.date).isBefore(end))
        m,
  ]..sort((Movement a, Movement b) => b.amount.compareTo(a.amount));
}

/// The close of the last whole pay period, or null when none is recorded.
PeriodClose? closePeriod(Ledger ledger, {bool hasGoals = false}) {
  final DateTime today = _day(ledger.today);
  final DateTime end = _day(ledger.schedule.lastOnOrBefore(today));
  final DateTime start = _day(
    ledger.schedule.lastOnOrBefore(end.subtract(const Duration(days: 1))),
  );
  final DateTime before = _day(
    ledger.schedule.lastOnOrBefore(start.subtract(const Duration(days: 1))),
  );
  final List<Movement> all = ledger.movements;
  if (all.isEmpty) return null;
  final DateTime first = all
      .map((Movement m) => _day(m.date))
      .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
  // The period has to have been recorded from its start.
  if (first.isAfter(start)) return null;
  final bool comparable = !first.isAfter(before);

  Map<Category, int> spentIn(DateTime from, DateTime to) {
    final Map<Category, int> by = <Category, int>{};
    for (final Movement m in all) {
      final DateTime d = _day(m.date);
      if (m.flow != Flow.expense || d.isBefore(from) || !d.isBefore(to)) {
        continue;
      }
      by[m.category] = (by[m.category] ?? 0) + m.amount;
    }
    return by;
  }

  final Map<Category, int> now = spentIn(start, end);
  final Map<Category, int>? then = comparable ? spentIn(before, start) : null;
  final int spent = now.values.fold(0, (int a, int b) => a + b);
  final int? spentBefore = then?.values.fold<int>(0, (int a, int b) => a + b);
  final int income = all
      .where(
        (Movement m) =>
            m.flow == Flow.income &&
            !_day(m.date).isBefore(start) &&
            _day(m.date).isBefore(end),
      )
      .fold(0, (int a, Movement m) => a + m.amount);
  final List<CategoryChange> changes =
      <CategoryChange>[
        for (final Category c in <Category>{...now.keys, ...?then?.keys})
          CategoryChange(c, now[c] ?? 0, then == null ? null : (then[c] ?? 0)),
      ]..sort(
        (CategoryChange a, CategoryChange b) => comparable
            ? b.difference.abs().compareTo(a.difference.abs())
            : b.now.compareTo(a.now),
      );

  // One thing to do, the first that applies.
  final Projection projection = Projection.of(
    ledger,
    horizon: _day(ledger.nextPayday).difference(today).inDays,
  );
  final ProjectedDay? tight = projection.firstTight;
  CloseAction? action;
  Category? actionCategory;
  if (tight != null) {
    action = CloseAction.tightDay;
  } else if (comparable) {
    for (final CategoryChange c in changes) {
      final int was = c.before ?? 0;
      // Up by a quarter or more, and big enough to matter in the period.
      if (was > 0 && c.now * 4 >= was * 5 && c.difference * 20 >= spent) {
        action = CloseAction.lookAtCategory;
        actionCategory = c.category;
        break;
      }
    }
  }
  if (action == null && hasGoals && ledger.freeUntilPayday > 0) {
    action = CloseAction.moveToGoal;
  }
  return PeriodClose(
    start: start,
    end: end,
    spent: spent,
    income: income,
    spentBefore: spentBefore,
    changes: changes,
    coming: ledger.committed,
    action: action,
    tightDay: tight?.date,
    actionCategory: actionCategory,
  );
}

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
