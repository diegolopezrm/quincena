import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../store/store.dart';

/// How many questions a person can ask Gemini through Quincena in a day.
///
/// The Firebase project also caps each person's requests per minute, where
/// no one can get around it. This is the limit the app says out loud: kept
/// on the device, counted per question, back to full every day.
class Allowance extends ChangeNotifier {
  Allowance(this.store, {this.perDay = 30, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final QuincenaStore store;
  final int perDay;
  final DateTime Function() _now;

  static const String _key = 'gemini.usage';

  String? _day;
  int _used = 0;

  String get _today {
    final DateTime d = _now();
    return '${d.year}-${d.month}-${d.day}';
  }

  int get _usedToday => _day == _today ? _used : 0;

  /// The questions left today.
  int get left => math.max(0, perDay - _usedToday);

  /// Whether so few are left today, though some are, that it helps to say
  /// how many before the next one; with plenty, saying it is only noise.
  bool get few => left > 0 && left <= 5;

  Future<void> load() async {
    final String? saved = await store.setting(_key);
    if (saved != null) {
      try {
        final Map<String, Object?> json = (jsonDecode(saved) as Map)
            .cast<String, Object?>();
        _day = json['day'] as String?;
        _used = (json['used'] as num?)?.toInt() ?? 0;
      } on FormatException {
        _day = null;
        _used = 0;
      }
    }
    notifyListeners();
  }

  /// Counts one question, or says there is none left today.
  Future<bool> take() async {
    if (left == 0) return false;
    final String today = _today;
    _used = _day == today ? _used + 1 : 1;
    _day = today;
    await store.setSetting(
      _key,
      jsonEncode(<String, Object>{'day': today, 'used': _used}),
    );
    notifyListeners();
    return true;
  }

  /// Gives back a question [take] counted that got no answer, as when the
  /// phone had no connection: every notice then asks to try again, and a
  /// try that brought nothing is not one of the day's.
  Future<void> giveBack() async {
    final String today = _today;
    if (_day != today || _used == 0) return;
    _used--;
    await store.setSetting(
      _key,
      jsonEncode(<String, Object>{'day': today, 'used': _used}),
    );
    notifyListeners();
  }
}
