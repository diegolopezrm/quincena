import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../money/money.dart';
import '../store/store.dart';
import 'records.dart';

/// What kind of movement a part of a balance gathers.
enum TraceKind {
  income,
  expense,
  transferIn,
  transferOut,

  /// Buying what the account holds.
  bought,

  /// Selling it.
  sold,

  /// Corrections and synced differences.
  adjustment,
}

/// Every movement of one kind, added up.
@immutable
class TracePart {
  const TracePart(this.kind, this.count, this.sum);

  final TraceKind kind;
  final int count;

  /// Signed: what it did to the balance.
  final Money sum;
}

/// How an account got to its balance: what it started with, what came in
/// and went out by kind, and what is dated ahead and not in it yet. The
/// same arithmetic as [balancesOf], so the parts add up to the balance.
@immutable
class AccountTrace {
  const AccountTrace({
    required this.opening,
    required this.parts,
    required this.balance,
    required this.aheadCount,
    required this.ahead,
  });

  final Money opening;

  /// Only the kinds that have movements, in [TraceKind] order.
  final List<TracePart> parts;
  final Money balance;

  /// Movements dated after today, which the balance does not count yet.
  final int aheadCount;
  final Money ahead;
}

AccountTrace traceAccount(
  Account account,
  Iterable<Entry> entries,
  DateTime asOf,
) {
  final DateTime until = endOfDay(asOf);
  final Map<TraceKind, (int, Decimal)> by = <TraceKind, (int, Decimal)>{};
  var balance = account.opening;
  var aheadCount = 0;
  var ahead = Decimal.zero;
  for (final Entry e in entries) {
    if (e.accountId != account.id) continue;
    if (e.date.isAfter(until)) {
      aheadCount++;
      ahead += e.amount;
      continue;
    }
    balance += e.amount;
    final bool inflow = e.amount > Decimal.zero;
    final TraceKind kind = e.isTrade
        ? (inflow ? TraceKind.bought : TraceKind.sold)
        : switch (e.kind) {
            EntryKind.income => TraceKind.income,
            EntryKind.expense => TraceKind.expense,
            EntryKind.transfer =>
              inflow ? TraceKind.transferIn : TraceKind.transferOut,
            EntryKind.adjustment => TraceKind.adjustment,
          };
    final (int count, Decimal sum) = by[kind] ?? (0, Decimal.zero);
    by[kind] = (count + 1, sum + e.amount);
  }
  return AccountTrace(
    opening: account.openingMoney,
    parts: <TracePart>[
      for (final TraceKind k in TraceKind.values)
        if (by[k] case (final int count, final Decimal sum))
          TracePart(k, count, Money(sum, account.asset)),
    ],
    balance: Money(balance, account.asset),
    aheadCount: aheadCount,
    ahead: Money(ahead, account.asset),
  );
}
