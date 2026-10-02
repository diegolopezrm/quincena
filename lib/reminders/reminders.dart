import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/pay_schedule.dart';

/// The reminder that the close of the fortnight is ready: one notification
/// on each payday at nine in the morning. It never carries an amount, since
/// the lock screen shows it.
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

  /// Replaces whatever was set with a reminder on each of the next paydays.
  static Future<void> schedule(
    PaySchedule schedule,
    DateTime from, {
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('schedule', <String, Object?>{
        'days': <int>[
          for (final DateTime d in days(schedule, from))
            d.millisecondsSinceEpoch,
        ],
        'title': title,
        'body': body,
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
