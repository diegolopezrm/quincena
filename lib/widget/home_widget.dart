import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/ledger.dart';
import '../domain/pay_schedule.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../l10n/l10n.dart';
import '../own/own_controller.dart';
import '../ui/standing.dart' show sentence;

/// The widget on the phone's home screen. The phone draws it; the app only
/// says what it shows, since the figure is worked out here.
abstract final class HomeWidget {
  static const MethodChannel _channel = MethodChannel(
    'dev.dlsoft.quincena/widget',
  );

  /// Phones only: the web and the desktop have no widget.
  static bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Shows [figure], or with null forgets what was shown: the widget then
  /// asks the person to open Quincena, as before the first figure.
  static Future<void> show(Map<String, Object?>? figure) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>(
        figure == null ? 'clear' : 'show',
        figure,
      );
    } on Object {
      // No widget here, as in a test or a build without one.
    }
  }
}

/// Where the app can ask the launcher to add the widget: Android's. On iOS
/// the person adds it from the home screen.
bool get canPinWidget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Asks the launcher to add the widget. False where it cannot, and the
/// person adds it by hand.
Future<bool> pinWidget() async {
  if (!canPinWidget) return false;
  try {
    return await const MethodChannel(
          'dev.dlsoft.quincena/widget',
        ).invokeMethod<bool>('pin') ??
        false;
  } on Object {
    return false;
  }
}

/// What the widget shows for [ledger]: the home's own words and figure,
/// the day they are for, and from when they are. [hidden] leaves the
/// amount out of what is sent at all.
///
/// The same keys as `Figure` in ios/QuincenaWidget and `SpendWidget` on
/// Android.
Map<String, Object?> widgetFigure(
  AppLocalizations l,
  Ledger ledger, {
  required DateTime now,
  required bool hidden,
}) {
  final int free = ledger.freeUntilPayday;
  final bool short = free < 0;
  final DateTime payday = ledger.nextPayday;
  final int days = payday.difference(ledger.today).inDays;
  final DateTime day = ledger.today;
  String two(int n) => n.toString().padLeft(2, '0');
  return <String, Object?>{
    'label': short ? l.standingShort : l.standingCanSpend,
    'amount': hidden ? '••••••' : pesos(ledger.major(free.abs())),
    'short': short && !hidden,
    'until': short
        ? l.standingShortUntil(dayMonth(payday))
        : l.standingUntil(dayMonth(payday)),
    'when': sentence(
      ledger.schedule is TwiceMonthly
          ? l.standingNextFortnight(days)
          : l.standingNextPay(days),
    ),
    'day': '${day.year}-${two(day.month)}-${two(day.day)}',
    // Only the time: a figure of another day says so instead.
    'updated': l.widgetUpdated(timeOfDay(now)),
    'stale': l.widgetStale,
  };
}

/// Keeps the widget saying what the home says. The figure goes out when it
/// differs from the last one sent, or the day changed; the time it was
/// worked out alone does not send it again.
class WidgetFeed {
  WidgetFeed({Future<void> Function(Map<String, Object?>? figure)? send})
    : _send = send ?? HomeWidget.show;

  final Future<void> Function(Map<String, Object?>? figure) _send;
  String? _last;

  void update(AppLocalizations l, OwnController own) {
    final Ledger? ledger = own.ledger;
    if (ledger == null) return;
    final Map<String, Object?> figure = widgetFigure(
      l,
      ledger,
      now: own.now(),
      hidden: own.widgetHidesAmounts,
    );
    final String same = jsonEncode(
      Map<String, Object?>.of(figure)..remove('updated'),
    );
    if (same == _last) return;
    _last = same;
    unawaited(_send(figure));
  }
}
