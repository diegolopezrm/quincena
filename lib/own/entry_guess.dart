import 'package:flutter/foundation.dart';

import '../capture/merchants.dart';
import '../domain/records.dart';

/// Who writes a movement down by hand: the person on the form, or in a
/// conversation, where Gemini or the example's script saves it. What they
/// write says how they pay; a bank's alert or a statement only says that
/// something was paid.
const Set<String> writtenByHand = <String>{'manual', 'gemini', 'script'};

/// How far back the account used most is counted: the habit of the last
/// two months, not of years of statements.
const Duration usualSpan = Duration(days: 60);

/// What a new movement most likely is, from what the person recorded
/// before: the account it comes from or goes to, its category, and the
/// earlier movement both repeat, when [payee] was seen before.
@immutable
class EntryGuess {
  const EntryGuess({this.accountId, this.category, this.like});

  /// Null when nothing says which account: the form keeps its own.
  final String? accountId;

  /// Null when nothing says which category: it goes in «Otros».
  final String? category;

  /// The last movement with the same name, which the account and the
  /// category repeat: the form says the guess comes from it.
  final Entry? like;
}

/// What a movement of [kind] paid to, or received from, [payee] most
/// likely is, among [entries], where nothing in [accounts] is archived.
///
/// The name says the most: the account and the category of the last
/// movement with that name. Without one, the account is the one the last
/// movement written by hand used, or else the one used most lately; the
/// category is one the app learned from a capture, or the one a well-known
/// name has. Transfers and trades say nothing of where a purchase is paid
/// from, and are left out.
EntryGuess guessEntry({
  required List<Entry> entries,
  required List<Account> accounts,
  required EntryKind kind,
  required String payee,
  required DateTime today,
  Map<String, String> learned = const <String, String>{},
}) {
  bool open(String id) =>
      accounts.any((Account a) => a.id == id && !a.archived);
  final List<Entry> alike = _alike(entries, kind);
  final String key = merchantKey(payee);
  final Entry? like = key.isEmpty
      ? null
      : alike.where((Entry e) => merchantKey(e.payee) == key).firstOrNull;
  final DateTime tomorrow = DateTime(today.year, today.month, today.day + 1);
  final String? last = alike
      .where(
        (Entry e) =>
            writtenByHand.contains(e.source) &&
            e.date.isBefore(tomorrow) &&
            open(e.accountId),
      )
      .firstOrNull
      ?.accountId;
  return EntryGuess(
    accountId: like != null && open(like.accountId)
        ? like.accountId
        : last ?? _usedMost(alike, today, open),
    category:
        like?.category ??
        (key.isEmpty ? null : learned[key]) ??
        switch (kind) {
          EntryKind.expense =>
            payee.trim().isEmpty ? null : knownCategory(payee),
          EntryKind.income => _incomeCategory(payee),
          _ => null,
        },
    like: like,
  );
}

/// The names [kind] of movement was most often paid to, or received from,
/// lately, as the person last wrote each: what the form offers before
/// anything is typed. With [typed], only those that contain it and are
/// not already it, as the field fills.
List<String> usualPayees({
  required List<Entry> entries,
  required EntryKind kind,
  required DateTime today,
  String typed = '',
  int most = 5,
}) {
  final DateTime since = today.subtract(const Duration(days: 120));
  final DateTime tomorrow = DateTime(today.year, today.month, today.day + 1);
  final Map<String, _Usual> usual = <String, _Usual>{};
  for (final Entry e in _alike(entries, kind)) {
    if (e.date.isBefore(since) || !e.date.isBefore(tomorrow)) continue;
    final String key = merchantKey(e.payee);
    if (key.isEmpty) continue;
    final _Usual u = usual[key] ??= _Usual(e, usual.length);
    u.count++;
    // The name as the person typed it reads better than a bank's.
    if (!writtenByHand.contains(u.named.source) &&
        writtenByHand.contains(e.source)) {
      u.named = e;
    }
  }
  final String wanted = normalize(typed);
  final String typedKey = merchantKey(typed);
  final List<_Usual> found =
      <_Usual>[
        for (final MapEntry<String, _Usual> u in usual.entries)
          if (wanted.isEmpty ||
              (u.key != typedKey && normalize(u.value.name).contains(wanted)))
            u.value,
      ]..sort(
        (_Usual a, _Usual b) => a.count != b.count
            ? b.count.compareTo(a.count)
            : a.order.compareTo(b.order),
      );
  return <String>[for (final _Usual u in found.take(most)) u.name];
}

class _Usual {
  _Usual(this.named, this.order);

  /// The movement whose name is shown: the newest written by hand.
  Entry named;

  /// Where it was first met, newest first: of two used as often, the one
  /// used last goes first.
  final int order;
  int count = 0;

  String get name => writtenByHand.contains(named.source)
      ? named.payee.trim()
      : prettyMerchant(named.payee);
}

/// The movements of [kind] that say where money went or came from, the
/// newest first; of two on the same day, in the order given, which the
/// store keeps the one written last first.
List<Entry> _alike(List<Entry> entries, EntryKind kind) {
  final List<(int, Entry)> alike =
      <(int, Entry)>[
        for (var i = 0; i < entries.length; i++)
          if (entries[i].kind == kind &&
              !entries[i].isTransfer &&
              !entries[i].isTrade)
            (i, entries[i]),
      ]..sort(((int, Entry) a, (int, Entry) b) {
        final int byDate = b.$2.date.compareTo(a.$2.date);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
  return <Entry>[for (final (int _, Entry e) in alike) e];
}

/// The account [alike] used most since [usualSpan] before [today], the
/// newest of those used as often; null when none was.
String? _usedMost(
  List<Entry> alike,
  DateTime today,
  bool Function(String id) open,
) {
  final DateTime since = today.subtract(usualSpan);
  final DateTime tomorrow = DateTime(today.year, today.month, today.day + 1);
  final Map<String, int> uses = <String, int>{};
  for (final Entry e in alike) {
    if (e.date.isBefore(since) || !e.date.isBefore(tomorrow)) continue;
    if (!open(e.accountId)) continue;
    uses[e.accountId] = (uses[e.accountId] ?? 0) + 1;
  }
  String? best;
  for (final MapEntry<String, int> u in uses.entries) {
    // Newest first: on a tie, the one met first was used last.
    if (best == null || u.value > uses[best]!) best = u.key;
  }
  return best;
}

/// The category money from [payer] usually is, by the words it says: the
/// pay, or something given back.
String? _incomeCategory(String payer) {
  final String plain = ' ${normalize(payer)} ';
  if (RegExp(r' (nomina|salario|sueldo|quincena|prima) ').hasMatch(plain)) {
    return 'salary';
  }
  if (RegExp(r' (reembolso|devolucion|reintegro) ').hasMatch(plain)) {
    return 'refund';
  }
  return null;
}
