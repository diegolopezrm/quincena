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

/// One day of a projection.
@immutable
class ProjectedDay {
  const ProjectedDay({
    required this.date,
    required this.sure,
    required this.likely,
    required this.events,
  });

  final DateTime date;

  /// The balance counting what is there and what is scheduled.
  final int sure;

  /// The balance also counting the expected pay and anything tried out.
  final int likely;

  /// What happens that day.
  final List<ProjectedEvent> events;
}

/// The money to spend, day by day from today, with what is sure kept apart
/// from what is only expected.
///
/// It starts from the ledger's balance today and adds, on their days, the
/// movements entered ahead and the recurring charges, which are scheduled,
/// and the pay on each payday, which is expected. A projection is never a
/// balance: [ProjectedDay.sure] is what happens if nothing else does.
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

    final DateTime? late = _latePay(ledger);
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
    for (int i = 0; i <= horizon; i++) {
      final DateTime date = today.add(Duration(days: i));
      final List<ProjectedEvent> on = <ProjectedEvent>[
        for (final ProjectedEvent e in events)
          if (e.date == date) e,
      ];
      for (final ProjectedEvent e in on) {
        if (e.certainty == Certainty.scheduled) sure += e.amount;
        likely += e.amount;
      }
      days.add(
        ProjectedDay(date: date, sure: sure, likely: likely, events: on),
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

  /// The first day the sure balance falls under the cushion, or under zero
  /// without one.
  ProjectedDay? get firstTight {
    for (final ProjectedDay d in days) {
      if (d.sure < cushion) return d;
    }
    return null;
  }
}

/// The last payday, when it passed without income of at least half the
/// pay around it. Null when the pay arrived, when it is not known, or when
/// today is payday.
DateTime? _latePay(Ledger ledger) {
  final int? pay = ledger.pay;
  if (pay == null) return null;
  final DateTime today = _day(ledger.today);
  final DateTime last = _day(ledger.schedule.lastOnOrBefore(today));
  if (!last.isBefore(today)) return null;
  // A payday more than a pay period back is not late, it is history.
  if (today.difference(last).inDays > 10) return null;
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

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
