import 'package:decimal/decimal.dart';

import '../capture/amounts.dart';

/// Months as statements abbreviate them, in Spanish and in English.
const Map<String, int> _months = <String, int>{
  'ene': 1, 'jan': 1, //
  'feb': 2,
  'mar': 3,
  'abr': 4, 'apr': 4, //
  'may': 5,
  'jun': 6,
  'jul': 7,
  'ago': 8, 'aug': 8, //
  'sep': 9, 'set': 9, //
  'oct': 10,
  'nov': 11,
  'dic': 12, 'dec': 12, //
};

final RegExp _numeric = RegExp(
  r'^(\d{1,4})[/\-.](\d{1,2})(?:[/\-.](\d{2,4}))?(?:[ T].*)?$',
);
final RegExp _named = RegExp(
  r'^(\d{1,2})[\s/\-.]*([a-z]{3,})\.?[\s/\-.,]*(\d{2,4})?',
);
final RegExp _namedFirst = RegExp(
  r'^([a-z]{3,})\.?[\s/\-.]*(\d{1,2})(?:[\s,/\-.]+(\d{2,4}))?',
);

/// How a column writes its dates when both numbers could be the day.
enum DayOrder { dayFirst, monthFirst }

/// The day [raw] names, as statements write it: `30/09/2026`, `2026-09-30`,
/// `30-SEP-26`, `sep 30`, `30/09` (with [year]), or, in a workbook
/// ([serial]), an Excel day count such as `46295`. Null when it is not a
/// date.
DateTime? parseStatementDate(
  String raw, {
  DayOrder order = DayOrder.dayFirst,
  int? year,
  bool serial = false,
}) {
  final String s = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return null;

  // An Excel day count, from 1899-12-30. Elsewhere a bare number is an
  // amount, not a date.
  final double? count = double.tryParse(s);
  if (count != null) {
    if (!serial || count < 20000 || count > 80000) return null;
    final DateTime d = DateTime(
      1899,
      12,
      30,
    ).add(Duration(days: count.floor()));
    return DateTime(d.year, d.month, d.day);
  }

  final RegExpMatch? n = _numeric.firstMatch(s);
  if (n != null) {
    final int a = int.parse(n.group(1)!);
    final int b = int.parse(n.group(2)!);
    final String? c = n.group(3);
    if (n.group(1)!.length == 4) {
      return _day(a, b, c == null ? null : int.parse(c));
    }
    final int? y = c == null ? year : _year(int.parse(c));
    if (y == null) return null;
    final bool dayFirst = a > 12
        ? true
        : b > 12
        ? false
        : order == DayOrder.dayFirst;
    return dayFirst ? _day(y, b, a) : _day(y, a, b);
  }

  final RegExpMatch? named = _named.firstMatch(s);
  if (named != null) {
    final int? month = _month(named.group(2)!);
    if (month != null) {
      final String? y = named.group(3);
      final int? fullYear = y == null ? year : _year(int.parse(y));
      if (fullYear == null) return null;
      return _day(fullYear, month, int.parse(named.group(1)!));
    }
  }
  final RegExpMatch? first = _namedFirst.firstMatch(s);
  if (first != null) {
    final int? month = _month(first.group(1)!);
    if (month != null) {
      final String? y = first.group(3);
      final int? fullYear = y == null ? year : _year(int.parse(y));
      if (fullYear == null) return null;
      return _day(fullYear, month, int.parse(first.group(2)!));
    }
  }
  return null;
}

int? _month(String word) {
  if (word.length < 3) return null;
  return _months[word.substring(0, 3)];
}

int _year(int y) => y < 100 ? 2000 + y : y;

DateTime? _day(int year, int month, int? day) {
  if (day == null || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  if (year < 1990 || year > 2100) return null;
  final DateTime d = DateTime(year, month, day);
  // 31/02 rolls into March: not a date.
  return d.month == month ? d : null;
}

/// Whether a date column puts the month first: when some value's second
/// number is over twelve, and none's first is.
DayOrder dayOrderOf(Iterable<String> values) {
  var dayFirst = false;
  var monthFirst = false;
  for (final String v in values) {
    final RegExpMatch? n = _numeric.firstMatch(v.trim());
    if (n == null || n.group(1)!.length == 4) continue;
    final int a = int.parse(n.group(1)!);
    final int b = int.parse(n.group(2)!);
    if (a > 12) dayFirst = true;
    if (b > 12) monthFirst = true;
  }
  return monthFirst && !dayFirst ? DayOrder.monthFirst : DayOrder.dayFirst;
}

/// A statement's amount, signed: `-45.900`, `45.900-`, `(45.900)`,
/// `$ 45.900,00 DB` are money out; `45.900 CR` money in. Null when it is
/// not an amount.
Decimal? parseSignedAmount(String raw) {
  var s = raw
      .trim()
      .toLowerCase()
      .replaceAll(' ', ' ')
      .replaceAll('−', '-')
      .replaceAll('–', '-');
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  final RegExpMatch? marker = RegExp(r'\s*(cr|db|dr)\.?$').firstMatch(s);
  if (marker != null) {
    negative = marker.group(1) != 'cr';
    s = s.substring(0, marker.start);
  }
  s = s.replaceAll(RegExp(r'(cop|usd|us\$|col\$|\$)'), '').trim();
  if (s.startsWith('-')) {
    negative = !negative;
    s = s.substring(1).trim();
  } else if (s.endsWith('-')) {
    negative = !negative;
    s = s.substring(0, s.length - 1).trim();
  } else if (s.startsWith('+')) {
    s = s.substring(1).trim();
  }
  if (s.isEmpty || !RegExp(r'^[\d.,\s]+$').hasMatch(s)) return null;
  final Decimal? value = parseLooseNumber(s.replaceAll(' ', ''));
  if (value == null) return null;
  return negative ? -value : value;
}
