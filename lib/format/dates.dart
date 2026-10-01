import 'package:intl/intl.dart';

import '../data/clock.dart';

final DateFormat _dayMonth = DateFormat("d 'de' MMMM", 'es');
final DateFormat _dayShortMonth = DateFormat('d MMM', 'es');
final DateFormat _monthYear = DateFormat("MMMM 'de' y", 'es');
final DateFormat _monthShort = DateFormat('MMM', 'es');

/// `15 de diciembre`.
String dayMonth(DateTime date) => _dayMonth.format(date);

/// `19 sept`, without the trailing period `intl` puts on Spanish months.
String dayShortMonth(DateTime date) =>
    _dayShortMonth.format(date).replaceAll('.', '');

/// `mayo de 2027`.
String monthYear(DateTime date) => _monthYear.format(date);

/// `sept`, for the axis of a chart.
String monthShort(DateTime date) =>
    _monthShort.format(date).replaceAll('.', '');

/// Reads `2026-09-19` or `2026-09`, the forms the agent writes dates in.
DateTime? parseDay(String? value) {
  if (value == null || value.isEmpty) return null;
  final String padded = value.length == 7 ? '$value-01' : value;
  return DateTime.tryParse(padded);
}

/// How long ago [date] was, said the way a person would.
String ago(DateTime date) {
  final int days = appToday.difference(date).inDays;
  if (days <= 0) return 'hoy';
  if (days == 1) return 'ayer';
  if (days < 7) return 'hace $days días';
  if (days < 14) return 'hace una semana';
  if (days < 30) return 'hace ${days ~/ 7} semanas';
  if (days < 60) return 'hace un mes';
  return 'hace ${days ~/ 30} meses';
}
