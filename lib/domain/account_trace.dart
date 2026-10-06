import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../money/asset.dart';
import '../money/money.dart';
import '../store/store.dart';
import 'records.dart';

/// What kind of movement a part of a balance gathers.
enum TraceKind {
  income,
  expense,
  transferIn,
  transferOut,

  /// Buying what the account holds, or crypto with it.
  bought,

  /// Selling it, or crypto into it.
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

/// Whether money moved between an account in [a] and one in [b] traded
/// one for the other: crypto against anything else, bought or sold.
/// Between two currencies it is the person's money carried over at a rate,
/// and within one asset it is the same money moved.
bool tradesAssets(Asset a, Asset b) => a != b && (a.isCrypto || b.isCrypto);

/// What [leg], one leg of a transfer, was for its account, which holds
/// [held], when the other leg's account holds [other]: a purchase or a
/// sale when the two traded crypto, money that came in or went out
/// otherwise. A crypto account buys what comes in and sells what goes out;
/// the account on the other side takes the trade's name: the pesos a sale
/// of bitcoin brought in are the sale, those that paid for bitcoin are
/// the purchase.
TraceKind transferKind(Entry leg, Asset held, Asset? other) {
  final bool inflow = leg.amount > Decimal.zero;
  if (other == null || !tradesAssets(held, other)) {
    return inflow ? TraceKind.transferIn : TraceKind.transferOut;
  }
  final bool bought = held.isCrypto ? inflow : !inflow;
  return bought ? TraceKind.bought : TraceKind.sold;
}

/// How [account] got to its balance by [asOf]. [entries] are everyone's,
/// so a transfer's other leg is found, and [accounts] tell what the
/// account on the other side holds: crypto bought or sold against another
/// of the person's accounts is a purchase or a sale, not a transfer.
AccountTrace traceAccount(
  Account account,
  Iterable<Entry> entries,
  DateTime asOf, {
  Iterable<Account> accounts = const <Account>[],
}) {
  final DateTime until = endOfDay(asOf);
  final Map<String, Asset> assets = <String, Asset>{
    for (final Account a in accounts) a.id: a.asset,
  };
  // Where the other leg of each of this account's transfers is.
  final Map<String, String> otherLeg = <String, String>{};
  for (final Entry e in entries) {
    if (e.transferId != null && e.accountId != account.id) {
      otherLeg[e.transferId!] = e.accountId;
    }
  }
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
            EntryKind.transfer => transferKind(
              e,
              account.asset,
              assets[otherLeg[e.transferId]],
            ),
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
