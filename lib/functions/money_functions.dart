import 'package:genui_gen/genui_gen.dart';

import '../catalog/shapes.dart';
import '../data/clock.dart';
import '../format/dates.dart';
import '../format/money.dart' as format;
import '../l10n/l10n.dart';

part 'money_functions.genui.dart';

/// The day of the month a goal's contribution lands: the 16th, the day
/// after the first payday, as every one in the sample account has.
const int contributionDay = 16;

/// How many contributions of [monthly] cover what is missing: 0 when
/// nothing is, -1 when [monthly] never does.
int contributionsToGo(double target, double saved, double monthly) {
  final double missing = target - saved;
  if (missing <= 0) return 0;
  if (monthly <= 0) return -1;
  return (missing / monthly).ceil();
}

/// The contribution [index] places from the next one, which is the first:
/// on [day] of each month, from the first such day that has not passed, or
/// on a shorter month's last day.
DateTime contributionOn(int index, {int day = contributionDay}) {
  DateTime on(int month) {
    final int last = DateTime(appToday.year, month + 1, 0).day;
    return DateTime(appToday.year, month, day > last ? last : day);
  }

  final DateTime today = DateTime(appToday.year, appToday.month, appToday.day);
  final int first = on(appToday.month).isBefore(today)
      ? appToday.month + 1
      : appToday.month;
  return on(first + index);
}

/// The days contributions land from now on, up to [until] or [count] of
/// them, whichever comes first. The functions below count the same ones,
/// so what a goal needs and when it arrives never disagree.
List<DateTime> contributionDays({
  DateTime? until,
  int? count,
  int day = contributionDay,
}) {
  final List<DateTime> days = <DateTime>[];
  if (until == null && count == null) return days;
  for (var i = 0; count == null || i < count; i++) {
    final DateTime next = contributionOn(i, day: day);
    if (until != null && next.isAfter(until)) break;
    days.add(next);
  }
  return days;
}

/// The day the goal is reached, or null when it never is.
DateTime? _arrival(double target, double saved, double monthly) {
  final int months = contributionsToGo(target, saved, monthly);
  if (months < 0) return null;
  if (months == 0) return appToday;
  return contributionOn(months - 1);
}

@GenUiFunction(
  description:
      'Formats an amount of pesos the way it is written in Colombia, such as '
      '"\$1.650.000", or in the short spoken form, such as "\$4,7 M", when '
      '`short` is true. Use it for any money shown as text, rather than '
      'writing the digits yourself.',
)
String money(double amount, {bool short = false}) =>
    short ? format.pesosShort(amount) : format.pesos(amount);

@GenUiFunction(
  description:
      'The change from `previous` to `current` as a signed percentage, such '
      'as "+67 %" or "−13 %".',
)
String percentChange(double current, double previous) =>
    format.signedPercent(current, previous);

@GenUiFunction(
  description:
      'The month a savings goal is reached when `monthly` is put aside every '
      'month from now, as text such as "mayo de 2027". Says "nunca", or '
      '"never" in English, when `monthly` is zero. Bind a GoalPlanner\'s '
      '`arrival` to it.',
)
String arrivalMonth(double target, double saved, double monthly) {
  final DateTime? when = _arrival(target, saved, monthly);
  if (when == null) return englishFormatting ? 'never' : 'nunca';
  return monthYear(when);
}

@GenUiFunction(
  description:
      'Whether a savings goal is reached on or before `deadline` (written '
      'YYYY-MM-DD) when `monthly` is put aside every month from now. Bind a '
      'GoalPlanner\'s `onTime` to it.',
)
bool arrivesBy(double target, double saved, double monthly, String deadline) {
  final DateTime? when = _arrival(target, saved, monthly);
  final DateTime? limit = parseDay(deadline);
  if (when == null || limit == null) return false;
  return !when.isAfter(limit);
}

@GenUiFunction(
  description:
      'How much has to be put aside each month, from now, to reach `target` '
      'by `deadline` (written YYYY-MM-DD), rounded up to the next ten '
      'thousand pesos.',
)
double monthlyNeeded(double target, double saved, String deadline) {
  final DateTime? limit = parseDay(deadline);
  final double missing = target - saved;
  if (limit == null || missing <= 0) return 0;
  // A month counts if its contribution lands in time.
  final int months = contributionDays(until: limit).length;
  if (months == 0) return missing;
  return ((missing / months) / 10000).ceil() * 10000;
}

@GenUiFunction(
  description:
      'What cancelling every subscription whose `keep` is false saves each '
      'month, in pesos. Pass it the same list a SubscriptionList repeats over, '
      'and wrap it in `money` to show it.',
)
double savingsIfCancelled(List<SubscriptionItem> items) => items
    .where((SubscriptionItem item) => !item.keep)
    .fold(0, (double sum, SubscriptionItem item) => sum + item.price);
