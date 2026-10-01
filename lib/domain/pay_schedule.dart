import 'package:flutter/foundation.dart';

/// How a person gets paid, which is what "until payday" means.
@immutable
sealed class PaySchedule {
  const PaySchedule();

  /// The first payday strictly after [day].
  DateTime nextAfter(DateTime day);

  /// The last payday on or before [day].
  DateTime lastOnOrBefore(DateTime day);

  Map<String, Object?> toJson();

  static PaySchedule fromJson(Map<String, Object?> json) =>
      switch (json['kind']) {
        'monthly' => Monthly(json['day']! as int),
        'biweekly' => EveryTwoWeeks(DateTime.parse(json['anchor']! as String)),
        'weekly' => Weekly(json['weekday']! as int),
        _ => TwiceMonthly(
          first: (json['first'] as int?) ?? 15,
          second: (json['second'] as int?) ?? 30,
        ),
      };
}

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// [day] of [month], or the month's last day when it is shorter: the 30th
/// of February is the 28th.
DateTime _dayOf(int year, int month, int day) {
  final DateTime first = DateTime(year, month);
  return DateTime(
    first.year,
    first.month,
    day.clamp(1, _daysIn(first.year, first.month)),
  );
}

/// Paid twice a month, on two days of it: the quincena. The 15th and the
/// 30th by default, and the 30th is the last day in a shorter month.
class TwiceMonthly extends PaySchedule {
  const TwiceMonthly({this.first = 15, this.second = 30})
    : assert(first < second);

  final int first;
  final int second;

  List<DateTime> _around(DateTime day) => <DateTime>[
    for (var m = -1; m <= 1; m++) ...<DateTime>[
      _dayOf(day.year, day.month + m, first),
      _dayOf(day.year, day.month + m, second),
    ],
  ];

  @override
  DateTime nextAfter(DateTime day) =>
      _around(_date(day)).firstWhere((DateTime d) => d.isAfter(_date(day)));

  @override
  DateTime lastOnOrBefore(DateTime day) =>
      _around(_date(day)).lastWhere((DateTime d) => !d.isAfter(_date(day)));

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'twiceMonthly',
    'first': first,
    'second': second,
  };

  @override
  bool operator ==(Object other) =>
      other is TwiceMonthly && other.first == first && other.second == second;

  @override
  int get hashCode => Object.hash(first, second);
}

/// Paid once a month, on [day]: the last day when the month is shorter.
class Monthly extends PaySchedule {
  const Monthly(this.day);

  final int day;

  @override
  DateTime nextAfter(DateTime from) {
    final DateTime d = _date(from);
    final DateTime here = _dayOf(d.year, d.month, day);
    return here.isAfter(d) ? here : _dayOf(d.year, d.month + 1, day);
  }

  @override
  DateTime lastOnOrBefore(DateTime from) {
    final DateTime d = _date(from);
    final DateTime here = _dayOf(d.year, d.month, day);
    return here.isAfter(d) ? _dayOf(d.year, d.month - 1, day) : here;
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'monthly',
    'day': day,
  };

  @override
  bool operator ==(Object other) => other is Monthly && other.day == day;

  @override
  int get hashCode => day.hashCode;
}

/// Paid every fourteen days, counting from a payday the person knows.
class EveryTwoWeeks extends PaySchedule {
  EveryTwoWeeks(DateTime anchor) : anchor = _date(anchor);

  final DateTime anchor;

  @override
  DateTime nextAfter(DateTime from) {
    final DateTime d = _date(from);
    final int days = d.difference(anchor).inDays;
    final int steps = days < 0 ? 0 : days ~/ 14 + 1;
    final DateTime next = DateTime(
      anchor.year,
      anchor.month,
      anchor.day + steps * 14,
    );
    return next.isAfter(d)
        ? next
        : DateTime(next.year, next.month, next.day + 14);
  }

  @override
  DateTime lastOnOrBefore(DateTime from) {
    final DateTime next = nextAfter(from);
    return DateTime(next.year, next.month, next.day - 14);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'biweekly',
    'anchor': anchor.toIso8601String().substring(0, 10),
  };

  @override
  bool operator ==(Object other) =>
      other is EveryTwoWeeks && other.anchor == anchor;

  @override
  int get hashCode => anchor.hashCode;
}

/// Paid every week on [weekday] (1 is Monday, 7 is Sunday).
class Weekly extends PaySchedule {
  const Weekly(this.weekday) : assert(weekday >= 1 && weekday <= 7);

  final int weekday;

  @override
  DateTime nextAfter(DateTime from) {
    final DateTime d = _date(from);
    var ahead = (weekday - d.weekday) % 7;
    if (ahead == 0) ahead = 7;
    return DateTime(d.year, d.month, d.day + ahead);
  }

  @override
  DateTime lastOnOrBefore(DateTime from) {
    final DateTime d = _date(from);
    final int back = (d.weekday - weekday) % 7;
    return DateTime(d.year, d.month, d.day - back);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'weekly',
    'weekday': weekday,
  };

  @override
  bool operator ==(Object other) => other is Weekly && other.weekday == weekday;

  @override
  int get hashCode => weekday.hashCode;
}
