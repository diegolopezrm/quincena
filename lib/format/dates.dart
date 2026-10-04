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

/// `1–5 sept 2026` or `Sep 1–5, 2026`: the days from [from] to [to], with
/// the month and the year said once when both ends share them.
String dayRange(DateTime from, DateTime to) {
  if (from.year != to.year) return '${shortDate(from)} – ${shortDate(to)}';
  if (from.month != to.month) {
    return englishFormatting
        ? '${dayShortMonth(from)} – ${dayShortMonth(to)}, ${to.year}'
        : '${dayShortMonth(from)} – ${dayShortMonth(to)} ${to.year}';
  }
  if (from.day == to.day) return shortDate(from);
  return englishFormatting
      ? '${monthShort(to)} ${from.day}–${to.day}, ${to.year}'
      : '${from.day}–${to.day} ${monthShort(to)} ${to.year}';
}

/// `viernes` or `Friday`, for [weekday] from 1 (Monday) to 7 (Sunday).
String weekdayName(int weekday) =>
    _format('EEEE', 'EEEE').format(DateTime(2026, 9, 28 + weekday - 1));

/// `1 oct · 9:30 a. m.` or `Oct 1 · 9:30 AM`: when something happened or
/// was last done.
String dayAndTime(DateTime moment) =>
    '${dayShortMonth(moment)} · ${timeOfDay(moment)}';

/// `2:05 p. m.` or `2:05 PM`: the time of something that happened today,
/// on the twelve-hour clock people in Colombia read. The hour and the
/// `p. m.` after it never go to different lines.
String timeOfDay(DateTime moment) =>
    _format('h:mm\u00a0a', 'h:mm\u00a0a').format(moment);

/// `16 de mayo de 2027` or `May 16, 2027`.
String dayMonthYear(DateTime date) =>
    _format("d 'de' MMMM 'de' y", 'MMMM d, y').format(date);

/// A day ahead as [dayMonth] writes it, with its year when that is not
/// this one: `16 de octubre`, but `16 de mayo de 2027`.
String dayMonthAhead(DateTime date) =>
    date.year == appToday.year ? dayMonth(date) : dayMonthYear(date);

/// [day] of a month as English writes it: `1st`, `2nd`, `15th`, `23rd`.
/// For what the model is told and for English text; a screen in either
/// language goes through [dayOfMonth].
String ordinal(int day) {
  if (day % 100 >= 11 && day % 100 <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

/// [day] of a month as the interface language writes it after "the" or
/// "el": `15th` in English, `15` in Spanish.
String dayOfMonth(int day) => englishFormatting ? ordinal(day) : '$day';

/// Items in a sentence: `a, b y c` or `a, b and c`.
String listed(List<String> items) {
  if (items.length < 2) return items.join();
  final String and = englishFormatting ? 'and' : 'y';
  return '${items.sublist(0, items.length - 1).join(', ')} $and ${items.last}';
}
