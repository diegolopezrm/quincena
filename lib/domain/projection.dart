import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../data/category.dart';
import '../data/ledger.dart';

/// How sure an amount in a projection is.
enum Certainty {
  /// Entered ahead by the person, or due by a recurring charge: it happens
  /// unless they change it.
  scheduled,

  /// The pay the person said they get, on the days their schedule says. It
  /// is not money until it arrives.
  expected,

  /// What the person is trying out. Never saved.
  hypothetical,
}

/// What an event in a projection is.
enum ProjectedKind {
  /// A movement entered with a date ahead.
  movement,

  /// A recurring charge.
  charge,

  /// A payday.
  pay,

  /// A payday that passed without the pay arriving.
  latePay,

  /// A payment a client is expected to make.
  income,

  /// Something the person is trying out.
  tryOut,
}

/// Something that changes the money to spend on a day ahead.
@immutable
class ProjectedEvent {
  const ProjectedEvent({
    required this.date,
    required this.amount,
    required this.certainty,
    required this.kind,
    this.label = '',
    this.category,
  });

  /// The day, at midnight.
  final DateTime date;

  /// In the ledger's smallest unit: money coming in is positive.
  final int amount;
  final Certainty certainty;
  final ProjectedKind kind;

  /// The merchant or charge it is, when it has one.
  final String label;
  final Category? category;
}

/// How many days ahead Inicio and «Próximos 30 días» look: what one of
/// them says about the days to come, the other says too.
const int comingDays = 30;

/// The days ahead those screens look at for [ledger]: [comingDays], or as
/// far as the next payday when a monthly pay puts it 31 days away, so the
/// lowest point before payday counts every charge «Puedes gastar» leaves
/// out.
int comingHorizon(Ledger ledger) => math.max(
  comingDays,
  _day(ledger.nextPayday).difference(_day(ledger.today)).inDays,
);

/// One day of a projection.
@immutable
class ProjectedDay {
  const ProjectedDay({
    required this.date,
    required this.sure,
    required this.likely,
    required this.events,
    this.expected = 0,
  });

  final DateTime date;

  /// The balance counting what is there and what is scheduled.
  final int sure;

  /// The balance also counting the expected pay and anything tried out.
  final int likely;

  /// What is only expected by this day, from today: the pay and what
  /// clients should pay. Part of [likely], never of [sure].
  final int expected;

  /// What happens that day.
  final List<ProjectedEvent> events;
}

/// The money to spend, day by day from today, with what is sure kept apart
/// from what is only expected.
///
/// It starts from the ledger's balance today and adds, on their days, the
/// movements entered ahead and the recurring charges, which are scheduled,
/// and the pay on each payday, which is expected, unless it already came
/// in the days before. A projection is never a balance:
/// [ProjectedDay.sure] is what happens if nothing else does.
@immutable
class Projection {
  const Projection._({
    required this.ledger,
    required this.days,
    required this.latePay,
  });

  /// [horizon] days from today, with [tryOut] added on their days.
  factory Projection.of(
    Ledger ledger, {
    int horizon = 45,
    List<ProjectedEvent> tryOut = const <ProjectedEvent>[],
  }) {
    final DateTime today = _day(ledger.today);
    final DateTime end = today.add(Duration(days: horizon));
    bool ahead(DateTime d) => d.isAfter(today) && !d.isAfter(end);

    final List<ProjectedEvent> events = <ProjectedEvent>[
      for (final Movement m in ledger.movements)
        if (ahead(_day(m.date)))
          ProjectedEvent(
            date: _day(m.date),
            amount: Ledger.effect(m),
            certainty: Certainty.scheduled,
            kind: ProjectedKind.movement,
            label: m.merchant,
            category: m.category,
          ),
      for (final Movement m in ledger.upcoming)
        if (ahead(_day(m.date)))
          ProjectedEvent(
            date: _day(m.date),
            amount: -m.amount,
            certainty: Certainty.scheduled,
            kind: ProjectedKind.charge,
            label: m.merchant,
            category: m.category,
          ),
      for (final ProjectedEvent e in tryOut)
        if (!e.date.isAfter(end))
          ProjectedEvent(
            date: e.date.isAfter(today) ? _day(e.date) : today,
            amount: e.amount,
            certainty: Certainty.hypothetical,
            kind: ProjectedKind.tryOut,
            label: e.label,
            category: e.category,
          ),
    ];

    for (final Movement m in ledger.expected) {
      if (!ahead(_day(m.date))) continue;
      events.add(
        ProjectedEvent(
          date: _day(m.date),
          amount: m.amount,
          certainty: Certainty.expected,
          kind: ProjectedKind.income,
          label: m.merchant,
        ),
      );
    }

    final DateTime? late = _latePay(ledger);
    final DateTime? early = _paidEarly(ledger);
    final int? pay = ledger.pay;
    if (pay != null) {
      if (late != null) {
        // When it will come is anyone's guess; tomorrow is the soonest.
        events.add(
          ProjectedEvent(
            date: today.add(const Duration(days: 1)),
            amount: pay,
            certainty: Certainty.expected,
            kind: ProjectedKind.latePay,
          ),
        );
      }
      for (
        DateTime d = ledger.schedule.nextAfter(today);
        !d.isAfter(end);
        d = ledger.schedule.nextAfter(d)
      ) {
        // Already in the balance: it is not expected a second time.
        if (_day(d) == early) continue;
        events.add(
          ProjectedEvent(
            date: _day(d),
            amount: pay,
            certainty: Certainty.expected,
            kind: ProjectedKind.pay,
          ),
        );
      }
    }

    final List<ProjectedDay> days = <ProjectedDay>[];
    int sure = ledger.balance;
    int likely = sure;
    int expected = 0;
    for (int i = 0; i <= horizon; i++) {
      final DateTime date = today.add(Duration(days: i));
      final List<ProjectedEvent> on = <ProjectedEvent>[
        for (final ProjectedEvent e in events)
          if (e.date == date) e,
      ];
      for (final ProjectedEvent e in on) {
        if (e.certainty == Certainty.scheduled) sure += e.amount;
        if (e.certainty == Certainty.expected) expected += e.amount;
        likely += e.amount;
      }
      days.add(
        ProjectedDay(
          date: date,
          sure: sure,
          likely: likely,
          events: on,
          expected: expected,
        ),
      );
    }
    return Projection._(ledger: ledger, days: days, latePay: late);
  }

  final Ledger ledger;

  /// Today first.
  final List<ProjectedDay> days;

  /// The payday that passed without the pay arriving, when there is one.
  final DateTime? latePay;

  int get start => ledger.balance;
  int get cushion => ledger.cushion;
  DateTime get nextPayday => _day(ledger.nextPayday);

  /// The lowest the sure balance gets until the next payday, and its day.
  ProjectedDay get lowestBeforePayday {
    ProjectedDay low = days.first;
    for (final ProjectedDay d in days) {
      if (d.date.isAfter(nextPayday)) break;
      if (d.sure < low.sure) low = d;
    }
    return low;
  }

  /// The balance [day] is judged by when saying whether money runs short:
  /// until the next payday, only what is sure, as what can be spent says;
  /// after it, also the pay and what clients should pay by then, as the
  /// person said they come. Without it every month would run out the day
  /// after payday. What is being tried out never counts.
  int judged(ProjectedDay day) =>
      day.date.isAfter(nextPayday) ? day.sure + day.expected : day.sure;

  /// Whether [day] falls under the cushion, or under zero without one, as
  /// [judged] says.
  bool tight(ProjectedDay day) => judged(day) < cushion;

  /// The first day that falls under the cushion, or under zero without
  /// one, as [judged] says.
  ProjectedDay? get firstTight {
    for (final ProjectedDay d in days) {
      if (tight(d)) return d;
    }
    return null;
  }

  /// What is kept apart from what can be spent: the cushion, what this
  /// period's envelopes set aside and the reserve kept from variable
  /// payments. It stays in the accounts, so every balance here holds it,
  /// and «Puedes gastar» leaves all of it out.
  int get kept =>
      math.max<int>(0, ledger.cushion) +
      math.max<int>(0, ledger.setAside) +
      math.max<int>(0, ledger.reserved);

  /// What will be free to spend on [day], counted the way «Puedes gastar»
  /// counts it: what is sure that day, less what is kept apart. Negative
  /// when that day would take from it.
  int free(ProjectedDay day) => day.sure - kept;

  /// Whether [day] reaches into what is kept apart, as [judged] says: the
  /// money the person put aside would have to pay for it.
  bool touchesKept(ProjectedDay day) => judged(day) < kept;

  /// The first day that reaches into what is kept apart, as [judged] says.
  ProjectedDay? get firstTouchingKept {
    for (final ProjectedDay d in days) {
      if (touchesKept(d)) return d;
    }
    return null;
  }
}

/// The last payday, when it passed without income of at least half the
/// pay around it. Null when the pay arrived, when it is not known, when
/// today is payday, or when the balances were written down after it: the
/// pay was already in them.
DateTime? _latePay(Ledger ledger) {
  final int? pay = ledger.pay;
  if (pay == null) return null;
  final DateTime today = _day(ledger.today);
  final DateTime last = _day(ledger.schedule.lastOnOrBefore(today));
  if (!last.isBefore(today)) return null;
  // A payday more than a pay period back is not late, it is history.
  if (today.difference(last).inDays > 10) return null;
  if (ledger.since case final DateTime since when last.isBefore(_day(since))) {
    return null;
  }
  final DateTime from = last.subtract(const Duration(days: 3));
  final bool arrived = ledger.movements.any(
    (Movement m) =>
        m.flow == Flow.income &&
        !_day(m.date).isBefore(from) &&
        !_day(m.date).isAfter(today) &&
        m.amount * 2 >= pay,
  );
  return arrived ? null : last;
}

/// The next payday, when its pay already came in the days before it, as
/// it does the working day before a payday on a weekend or a holiday: an
/// income of at least half the pay since three days before it, after the
/// last payday. Null when it has not, or when the pay is not known.
DateTime? _paidEarly(Ledger ledger) {
  final int? pay = ledger.pay;
  if (pay == null) return null;
  final DateTime today = _day(ledger.today);
  final DateTime next = _day(ledger.nextPayday);
  final DateTime last = _day(ledger.schedule.lastOnOrBefore(today));
  final DateTime from = next.subtract(const Duration(days: 3));
  final bool arrived = ledger.movements.any(
    (Movement m) =>
        m.flow == Flow.income &&
        !_day(m.date).isBefore(from) &&
        _day(m.date).isAfter(last) &&
        !_day(m.date).isAfter(today) &&
        m.amount * 2 >= pay,
  );
  return arrived ? next : null;
}

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
