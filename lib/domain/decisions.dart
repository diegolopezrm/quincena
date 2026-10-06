import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../data/category.dart';
import '../data/ledger.dart';
import 'projection.dart';

/// Where buying something leaves the money to spend.
enum PurchaseVerdict {
  /// The lowest point stays at or above everything kept apart: the
  /// cushion, what envelopes set aside and the reserve kept from variable
  /// payments. Before payday, that is a price within what can be spent.
  fits,

  /// It stays at or above the cushion, but takes from what envelopes set
  /// aside or from the reserve: more than there is to spend.
  takesApart,

  /// It stays above zero, but goes under the cushion, after taking all of
  /// what envelopes set aside and the reserve.
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
    this.usesSetAside = 0,
    this.usesReserve = 0,
    this.usesCushion = 0,
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

  /// What the purchase would take from what is kept apart, in the ledger's
  /// unit: what envelopes set aside first, as they are only on paper and
  /// can be split again; then the reserve kept from variable payments; the
  /// cushion last, as it is what is kept untouched. Together, what the
  /// price goes over what can be spent by.
  final int usesSetAside;
  final int usesReserve;
  final int usesCushion;

  /// Bought after the next payday, when what can be spent until it is no
  /// longer the measure.
  bool get afterPay => reliesOnPay || payUnknown;
}

/// Weighs buying something for [price] on [date] against the money to
/// spend: the lowest it gets from that day to the payday after it, against
/// everything «Puedes gastar» leaves out besides what is committed.
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
  // What is kept apart stays in the accounts, so the projection still
  // holds it: the lowest point has to stay above all of it for the
  // purchase to fit, as «Puedes gastar» leaves all of it out. Below that,
  // it is taken from the top: the envelopes, the reserve, the cushion.
  final int cushion = math.max(0, ledger.cushion);
  final int reserve = math.max(0, ledger.reserved);
  final int envelopes = math.max(0, ledger.setAside);
  final int kept = cushion + reserve + envelopes;
  int over = math.min(kept, math.max(0, kept - low));
  int take(int from) {
    final int taken = math.min(over, from);
    over -= taken;
    return taken;
  }

  final int usesSetAside = take(envelopes);
  final int usesReserve = take(reserve);
  final int usesCushion = take(cushion);
  return PurchaseCheck(
    price: price,
    date: day,
    until: until,
    lowest: low,
    lowestOn: lowestOn,
    verdict: low < 0
        ? PurchaseVerdict.short
        : low < cushion
        ? PurchaseVerdict.belowCushion
        : usesSetAside + usesReserve > 0
        ? PurchaseVerdict.takesApart
        : PurchaseVerdict.fits,
    reliesOnPay: reliesOnPay,
    payUnknown: afterPay && ledger.pay == null,
    projection: p,
    usesSetAside: usesSetAside,
    usesReserve: usesReserve,
    usesCushion: usesCushion,
  );
}

/// What is only expected on [d]: the pay, or a client's payment.
int _payOn(ProjectedDay d) => d.events
    .where(
      (ProjectedEvent e) =>
          e.kind == ProjectedKind.pay ||
          e.kind == ProjectedKind.latePay ||
          e.kind == ProjectedKind.income,
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
    this.startBefore,
  });

  /// The period: from [start], a payday, to the day before [end], the
  /// payday that closed it.
  final DateTime start;
  final DateTime end;
  final int spent;
  final int income;

  /// The period before; null without a whole one recorded.
  final int? spentBefore;

  /// Where the period before starts; null without a whole one recorded.
  final DateTime? startBefore;

  /// Largest movement first.
  final List<CategoryChange> changes;

  /// What is committed until the next payday.
  final List<Movement> coming;
  final CloseAction? action;
  final DateTime? tightDay;
  final Category? actionCategory;

  /// The movements behind [category] in the period.
  List<Movement> movementsOf(Ledger ledger, Category category) =>
      _movements(ledger, category, start, end);

  /// The movements behind [category] in the period before, which is what a
  /// category that fell to nothing compares with. Empty without one.
  List<Movement> movementsBefore(Ledger ledger, Category category) =>
      switch (startBefore) {
        final DateTime from => _movements(ledger, category, from, start),
        null => const <Movement>[],
      };

  static List<Movement> _movements(
    Ledger ledger,
    Category category,
    DateTime from,
    DateTime to,
  ) => <Movement>[
    for (final Movement m in ledger.movements)
      if (m.flow == Flow.expense &&
          m.category == category &&
          !_day(m.date).isBefore(from) &&
          _day(m.date).isBefore(to))
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
    startBefore: comparable ? before : null,
  );
}

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
