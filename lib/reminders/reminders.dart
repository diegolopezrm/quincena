import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/commitments.dart';
import '../domain/pay_schedule.dart';
import '../domain/records.dart';
import '../format/dates.dart';
import '../l10n/l10n.dart';

/// The app's reminders: the close of the fortnight on each payday, a
/// renewal some days ahead, a free trial about to end. Each at nine in the
/// morning, and never with an amount, since the lock screen shows them.
abstract final class Reminders {
  static const MethodChannel _channel = MethodChannel(
    'dev.dlsoft.quincena/reminders',
  );

  /// Phones only: the web and the desktop have no reminder.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Asks the system to show notifications. False when the person says no.
  static Future<bool> ask() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('ask') ?? false;
    } on Object {
      return false;
    }
  }

  /// The next [count] paydays after [from], at nine in the morning.
  static List<DateTime> days(
    PaySchedule schedule,
    DateTime from, {
    int count = 6,
  }) {
    final List<DateTime> out = <DateTime>[];
    var day = DateTime(from.year, from.month, from.day);
    while (out.length < count) {
      day = schedule.nextAfter(day);
      out.add(DateTime(day.year, day.month, day.day, 9));
    }
    return out;
  }

  /// Replaces whatever was set with [reminders], the soonest first and at
  /// most [limit] of them.
  static Future<void> schedule(
    List<Reminder> reminders, {
    int limit = 24,
  }) async {
    if (!supported) return;
    final List<Reminder> soonest = <Reminder>[...reminders]
      ..sort((Reminder a, Reminder b) => a.at.compareTo(b.at));
    try {
      await _channel.invokeMethod<void>('schedule', <String, Object?>{
        'items': <Map<String, Object?>>[
          for (final Reminder r in soonest.take(limit))
            <String, Object?>{
              'at': r.at.millisecondsSinceEpoch,
              'title': r.title,
              'body': r.body,
            },
        ],
      });
    } on Object {
      // A reminder that cannot be set is not worth stopping the app for.
    }
  }

  static Future<void> cancel() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on Object {
      // Nothing set, nothing to take back.
    }
  }
}

/// One notification at one moment. Never an amount: the lock screen shows
/// it.
@immutable
class Reminder {
  const Reminder({required this.at, required this.title, required this.body});

  final DateTime at;
  final String title;
  final String body;
}

/// The reminders the person asked for about [charges]: [ChargeMemory.remindDays]
/// before each renewal in the next [days] days, and the day before a free
/// trial ends. Paused charges remind nothing.
List<Reminder> renewalReminders(
  List<RecurringCharge> charges,
  Map<String, ChargeMemory> memories, {
  required DateTime now,
  int days = 100,
}) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime until = today.add(Duration(days: days));
  DateTime nine(DateTime day) => DateTime(day.year, day.month, day.day, 9);
  final List<Reminder> out = <Reminder>[];
  for (final RecurringCharge c in charges) {
    final ChargeMemory? m = memories[c.id];
    if (m == null || !c.active) continue;
    final DateTime? trial = m.trialEnds;
    final bool inTrial = trial != null && !trial.isBefore(today);
    if (inTrial) {
      // The day before, or the day itself when that one is gone.
      final DateTime before = nine(trial.subtract(const Duration(days: 1)));
      final DateTime at = before.isAfter(now) ? before : nine(trial);
      if (at.isAfter(now)) {
        out.add(
          Reminder(
            at: at,
            title: ReminderWords.trialEnds(c.name, trial),
            body: ReminderWords.trialBody,
          ),
        );
      }
    }
    final int? ahead = m.remindDays;
    if (ahead == null) continue;
    for (
      var renewal = nextCharge(c, today.subtract(const Duration(days: 1)));
      !renewal.isAfter(until);
      renewal = c.cadence.after(renewal)
    ) {
      // The trial's reminder already speaks for its first charge.
      if (inTrial && !renewal.isAfter(trial)) continue;
      final DateTime at = nine(renewal.subtract(Duration(days: ahead)));
      if (!at.isAfter(now)) continue;
      final bool subscription = c.category == 'subscriptions';
      out.add(
        Reminder(
          at: at,
          title: subscription
              ? ReminderWords.renews(c.name, renewal)
              : ReminderWords.due(c.name, renewal),
          body: subscription ? ReminderWords.renewsBody : ReminderWords.dueBody,
        ),
      );
    }
  }
  return out;
}

/// What renewal and trial reminders say, in the app's language. Written
/// here because they are set from outside any screen.
abstract final class ReminderWords {
  static String renews(String name, DateTime on) => englishFormatting
      ? '$name renews on ${dayMonth(on)}'
      : '$name se renueva el ${dayMonth(on)}';

  static String get renewsBody => englishFormatting
      ? 'If you no longer use it, there is still time to pause it.'
      : 'Si ya no la usas, aún estás a tiempo de pausarla.';

  static String due(String name, DateTime on) => englishFormatting
      ? '$name is due on ${dayMonth(on)}'
      : '$name se cobra el ${dayMonth(on)}';

  static String get dueBody => englishFormatting
      ? 'So the money is ready when it comes.'
      : 'Para que la plata esté lista cuando llegue.';

  static String trialEnds(String name, DateTime on) => englishFormatting
      ? 'The $name free trial ends on ${dayMonth(on)}'
      : 'La prueba gratis de $name termina el ${dayMonth(on)}';

  static String get trialBody => englishFormatting
      ? 'From then on it charges, unless you cancel it first.'
      : 'Desde ese día empieza a cobrar, salvo que la canceles antes.';
}
