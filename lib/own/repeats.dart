import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../capture/dedupe.dart' show similarNames;
import '../domain/records.dart';

/// Two movements that may be one payment recorded twice: in the same
/// account, for the same amount, a day or two apart, and paid to names
/// alike, or to none. A notification and the statement that lists the same
/// purchase later look like this, and so does a payment typed by hand that
/// a capture already brought.
@immutable
class PossibleRepeat {
  const PossibleRepeat({required this.kept, required this.repeat});

  /// The one recorded first, which stays when the other goes.
  final Entry kept;

  /// The one recorded after it: what taking the repeat away deletes.
  final Entry repeat;

  /// How the pair is remembered once the person says it is not a repeat.
  String get key => repeatKey(kept.id, repeat.id);
}

/// The same for [a] and [b] in either order.
String repeatKey(String a, String b) => a.compareTo(b) < 0 ? '$a+$b' : '$b+$a';

/// How many days apart two records of one payment can be: a statement
/// often lists a purchase a day or two after the bank's notification.
const int repeatDays = 2;

/// For each movement in [entries] that may repeat another, the pair it is
/// in: the closest one in time, when there are several. Of two at the same
/// moment, the one from the later source is taken as recorded last, a
/// statement after a notification; with the same source, the one first in
/// [entries], as the store lists the newest first. Pairs whose
/// [repeatKey] is in [notRepeated] are left alone: the person said they
/// are two.
///
/// Moves between the person's own accounts and crypto trades are left
/// out: buying the same amount every week is a plan, not a repeat.
Map<String, PossibleRepeat> possibleRepeats(
  List<Entry> entries, {
  Set<String> notRepeated = const <String>{},
}) {
  // Only movements of one account and one amount can repeat each other.
  final Map<String, List<int>> alike = <String, List<int>>{};
  for (var i = 0; i < entries.length; i++) {
    final Entry e = entries[i];
    if (e.isTransfer || e.isTrade || e.amount == Decimal.zero) continue;
    if (e.kind != EntryKind.expense && e.kind != EntryKind.income) continue;
    (alike['${e.accountId}|${e.amount}'] ??= <int>[]).add(i);
  }
  final Map<String, PossibleRepeat> pairs = <String, PossibleRepeat>{};
  final Map<String, Duration> apart = <String, Duration>{};
  for (final List<int> group in alike.values) {
    if (group.length < 2) continue;
    // The newest first, so the ones close in time are next to each other.
    group.sort((int a, int b) {
      final int byDate = entries[b].date.compareTo(entries[a].date);
      if (byDate != 0) return byDate;
      final int bySource = _lateness(
        entries[b].source,
      ).compareTo(_lateness(entries[a].source));
      return bySource != 0 ? bySource : a.compareTo(b);
    });
    for (var x = 0; x < group.length; x++) {
      final Entry newer = entries[group[x]];
      for (var y = x + 1; y < group.length; y++) {
        final Entry older = entries[group[y]];
        if (_daysApart(newer.date, older.date) > repeatDays) break;
        if (!similarNames(newer.payee, older.payee)) continue;
        final PossibleRepeat pair = PossibleRepeat(kept: older, repeat: newer);
        if (notRepeated.contains(pair.key)) continue;
        final Duration gap = newer.date.difference(older.date);
        for (final Entry e in <Entry>[newer, older]) {
          if (apart[e.id] case final Duration closer when closer <= gap) {
            continue;
          }
          apart[e.id] = gap;
          pairs[e.id] = pair;
        }
      }
    }
  }
  return pairs;
}

/// How late [source] tells of a payment: the phone catches it as it
/// happens, a hand or a pasted message writes it after, and a statement
/// lists it days later.
int _lateness(String source) => switch (source.split(':').first) {
  'wallet' || 'notification' || 'sms' || 'email' => 0,
  'statement' => 2,
  _ => 1,
};

/// How many calendar days lie between [a] and [b], whatever their hours.
int _daysApart(DateTime a, DateTime b) => DateTime.utc(
  a.year,
  a.month,
  a.day,
).difference(DateTime.utc(b.year, b.month, b.day)).inDays.abs();
