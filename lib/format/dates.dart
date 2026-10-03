import 'package:intl/intl.dart';

import '../data/clock.dart';
import '../l10n/l10n.dart';

DateFormat _format(String es, String en) =>
    englishFormatting ? DateFormat(en, 'en_US') : DateFormat(es, 'es');

/// `15 de diciembre` or `December 15`.
String dayMonth(DateTime date) => _format("d 'de' MMMM", 'MMMM d').format(date);

/// `19 sept` or `Sep 19`, without the period intl puts on Spanish months.
String dayShortMonth(DateTime date) =>
    _format('d MMM', 'MMM d').format(date).replaceAll('.', '');

/// `mayo de 2027` or `May 2027`.
String monthYear(DateTime date) =>
    _format("MMMM 'de' y", 'MMMM y').format(date);

/// `septiembre` or `September`.
String monthName(DateTime date) => _format('MMMM', 'MMMM').format(date);

/// `sept` or `Sep`, for the axis of a chart.
String monthShort(DateTime date) =>
    _format('MMM', 'MMM').format(date).replaceAll('.', '');

/// Reads `2026-09-19` or `2026-09`, the forms the agent writes dates in.
DateTime? parseDay(String? value) {
  if (value == null || value.isEmpty) return null;
  final String padded = value.length == 7 ? '$value-01' : value;
  return DateTime.tryParse(padded);
}

/// How long ago [date] was, said the way a person would.
String ago(DateTime date) {
  final int days = appToday.difference(date).inDays;
  if (englishFormatting) {
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    if (days < 14) return 'a week ago';
    if (days < 30) return '${days ~/ 7} weeks ago';
    if (days < 60) return 'a month ago';
    return '${days ~/ 30} months ago';
  }
  if (days <= 0) return 'hoy';
  if (days == 1) return 'ayer';
  if (days < 7) return 'hace $days días';
  if (days < 14) return 'hace una semana';
  if (days < 30) return 'hace ${days ~/ 7} semanas';
  if (days < 60) return 'hace un mes';
  return 'hace ${days ~/ 30} meses';
}

/// `lunes 29 de septiembre` or `Monday, September 29`: a heading over the
/// movements of one day.
String weekdayDayMonth(DateTime date) =>
    _format("EEEE d 'de' MMMM", 'EEEE, MMMM d').format(date);

/// `29 sept 2026` or `Sep 29, 2026`.
String shortDate(DateTime date) =>
    _format('d MMM y', 'MMM d, y').format(date).replaceAll('.', '');

/// `viernes` or `Friday`, for [weekday] from 1 (Monday) to 7 (Sunday).
String weekdayName(int weekday) =>
    _format('EEEE', 'EEEE').format(DateTime(2026, 9, 28 + weekday - 1));

/// `1 oct · 9:30 a. m.` or `Oct 1 · 9:30 AM`: when something happened or
/// was last done.
String dayAndTime(DateTime moment) =>
    '${dayShortMonth(moment)} · ${timeOfDay(moment)}';

/// `2:05 p. m.` or `2:05 PM`: the time of something that happened today,
/// on the twelve-hour clock people in Colombia read.
String timeOfDay(DateTime moment) => _format('h:mm a', 'h:mm a').format(moment);
