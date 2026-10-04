import 'package:genui_gen/genui_gen.dart';

import '../catalog/shapes.dart';
import '../data/clock.dart';
import '../format/dates.dart';
import '../format/money.dart' as format;

part 'money_functions.genui.dart';

/// Months of saving [monthly] it takes to cover what is missing.
int _monthsToGo(double target, double saved, double monthly) {
  final double missing = target - saved;
  if (missing <= 0) return 0;
  if (monthly <= 0) return -1;
  return (missing / monthly).ceil();
}

/// The day the next contribution lands: the 16th, as every one has.
DateTime _firstContribution() => appToday.day <= 16
    ? DateTime(appToday.year, appToday.month, 16)
    : DateTime(appToday.year, appToday.month + 1, 16);

/// The day the goal is reached, or null when it never is.
DateTime? _arrival(double target, double saved, double monthly) {
  final int months = _monthsToGo(target, saved, monthly);
  if (months < 0) return null;
  if (months == 0) return appToday;
  final DateTime first = _firstContribution();
  return DateTime(first.year, first.month + months - 1, 16);
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
      'month from now, as text such as "mayo de 2027". Says "nunca" when '
      '`monthly` is zero. Bind a GoalPlanner\'s `arrival` to it.',
)
String arrivalMonth(double target, double saved, double monthly) {
  final DateTime? when = _arrival(target, saved, monthly);
  return when == null ? 'nunca' : monthYear(when);
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
  // Contributions land on the 16th, so a month counts if its 16th is in time.
  var months = 0;
  for (
    var d = DateTime(appToday.year, appToday.month, 16);
    !d.isAfter(limit);
    d = DateTime(d.year, d.month + 1, 16)
  ) {
    months++;
  }
  if (months == 0) return missing;
  return ((missing / months) / 10000).ceil() * 10000;
}

@GenUiFunction(
  description:
      'What cancelling every subscription whose `keep` is false, and that is '
      'not cancelled already, saves each month, in pesos. Pass it the same '
      'list a SubscriptionList repeats over, and wrap it in `money` to show it.',
)
double savingsIfCancelled(List<SubscriptionItem> items) => items
    .where((SubscriptionItem item) => !item.keep && !item.cancelled)
    .fold(0, (double sum, SubscriptionItem item) => sum + item.price);
