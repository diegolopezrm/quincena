import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';

/// An amount in the two currencies a portfolio is told in: the person's
/// base currency and dollars.
@immutable
class Pair {
  const Pair(this.base, this.usd);

  static final Pair zero = Pair(Decimal.zero, Decimal.zero);

  final Decimal base;
  final Decimal usd;

  Pair operator +(Pair other) => Pair(base + other.base, usd + other.usd);
  Pair operator -(Pair other) => Pair(base - other.base, usd - other.usd);

  /// This share of the pair: [part] of [whole].
  Pair share(Decimal part, Decimal whole) {
    if (whole == Decimal.zero) return Pair.zero;
    final Decimal f = _divide(part, whole);
    return Pair(base * f, usd * f);
  }

  @override
  bool operator ==(Object other) =>
      other is Pair && other.base == base && other.usd == usd;

  @override
  int get hashCode => Object.hash(base, usd);

  @override
  String toString() => '($base, US\$$usd)';
}

Decimal _divide(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 18);

/// What an account that holds an investment holds, and what it cost.
///
/// The cost is what the person put in, followed from one asset to the
/// next: bitcoin bought with tether that was bought with pesos cost those
/// pesos. So the gain is told against the money that went in, which is
/// what someone who earns in pesos wants to know. Holdings are averaged:
/// selling part of one takes out its share of the cost.
@immutable
class Position {
  const Position({
    required this.account,
    required this.quantity,
    required this.cost,
    required this.uncosted,
    required this.realized,
    required this.approximate,
  });

  final Account account;

  /// How much of the account's asset it holds.
  final Decimal quantity;

  /// What [quantity] cost.
  final Pair cost;

  /// Of [quantity], how much came in with no known cost, such as rewards or
  /// a deposit from a wallet the app does not know. It carries no cost, and
  /// the gain leaves it out rather than count its whole value.
  final Decimal uncosted;

  /// What sales and conversions out of it brought in, less what they had
  /// cost.
  final Pair realized;

  /// Whether a cost had to be converted with a rate from a day other than
  /// its own.
  final bool approximate;

  Asset get asset => account.asset;

  /// What one unit cost on average, or null with nothing held.
  Pair? get averageCost => quantity <= Decimal.zero
      ? null
      : Pair(_divide(cost.base, quantity), _divide(cost.usd, quantity));
}

/// The rate of one dollar in the base currency on a past day, or null when
/// the app has none for it.
typedef DollarRateOn = Decimal? Function(DateTime day);

/// Follows what every investment account holds, and what it cost, through
/// all of the person's movements.
///
/// An account holds an investment when its asset is crypto. A movement's
/// cost comes, in this order, from the other leg of a transfer, from the
/// cost the movement carries (a purchase or sale outside the person's
/// accounts), or from nowhere: what came in then has no known cost. A fee
/// takes out what it charged and leaves its cost behind.
///
/// Amounts in pesos or dollars become the other currency with [dollarOn],
/// the rate of their own day; failing that, with [today]'s rates, and the
/// position says it is approximate.
List<Position> positions({
  required List<Account> accounts,
  required List<Entry> entries,
  required Asset base,
  required RateTable today,
  required DollarRateOn dollarOn,
  DateTime? openedOn,
}) {
  final Map<String, Account> byId = <String, Account>{
    for (final Account a in accounts) a.id: a,
  };
  final Map<String, _Holding> held = <String, _Holding>{
    for (final Account a in accounts)
      if (a.asset.isCrypto) a.id: _Holding(a),
  };
  if (held.isEmpty) return const <Position>[];

  // Oldest first; at the same moment, in the order they were written. The
  // store gives them newest first, and a sort is not stable on its own.
  final List<Entry> written = entries.reversed.toList();
  final Map<Entry, int> order = <Entry, int>{
    for (var i = 0; i < written.length; i++) written[i]: i,
  };
  final List<Entry> ordered = written
    ..sort((Entry a, Entry b) {
      final int byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : order[a]!.compareTo(order[b]!);
    });
  final DateTime start =
      openedOn ?? (ordered.isEmpty ? DateTime.now() : ordered.first.date);

  final _Valuer value = _Valuer(base: base, today: today, dollarOn: dollarOn);

  for (final _Holding h in held.values) {
    final Account a = h.account;
    if (a.opening == Decimal.zero) continue;
    final Money? cost = a.openingCost;
    h.add(
      a.opening,
      cost == null ? null : value.of(cost, start, approximateDay: true),
    );
  }

  final Set<String> done = <String>{};
  final Map<String, List<Entry>> legs = <String, List<Entry>>{};
  for (final Entry e in ordered) {
    if (e.transferId != null) {
      legs.putIfAbsent(e.transferId!, () => <Entry>[]).add(e);
    }
  }

  for (final Entry e in ordered) {
    final String? transfer = e.transferId;
    if (transfer != null) {
      if (!done.add(transfer)) continue;
      final List<Entry> pair = legs[transfer]!;
      if (pair.length == 2) {
        final Entry out = pair[0].amount < Decimal.zero ? pair[0] : pair[1];
        final Entry into = identical(out, pair[0]) ? pair[1] : pair[0];
        _transfer(out, into, held, byId, value);
        continue;
      }
    }
    final _Holding? h = held[e.accountId];
    if (h == null) continue;
    final Money? cost = e.cost;
    if (e.amount > Decimal.zero) {
      h.add(e.amount, cost == null ? null : value.of(cost, e.date));
    } else if (e.amount < Decimal.zero) {
      if (cost == null && _isFee(e)) {
        h.charge(-e.amount);
        continue;
      }
      final _Taken taken = h.take(-e.amount);
      if (cost != null) {
        final _Valued proceeds = value.of(cost, e.date);
        h.realized += proceeds.pair - taken.cost;
        h.approximate |= proceeds.approximate;
      }
    }
  }

  return <Position>[
    for (final _Holding h in held.values)
      Position(
        account: h.account,
        quantity: h.quantity,
        cost: h.cost,
        uncosted: h.uncosted,
        realized: h.realized,
        approximate: h.approximate,
      ),
  ];
}

/// Whether [e] is what an exchange charged for a trade, as Binance's are
/// marked when they are read.
bool _isFee(Entry e) => e.sourceRef?.endsWith(':fee') ?? false;

/// One move between two of the person's accounts, when at least one of
/// them holds an investment.
void _transfer(
  Entry out,
  Entry into,
  Map<String, _Holding> held,
  Map<String, Account> accounts,
  _Valuer value,
) {
  final _Holding? from = held[out.accountId];
  final _Holding? to = held[into.accountId];
  if (from == null && to == null) return;
  final Decimal sent = -out.amount;
  final Decimal received = into.amount;

  if (from != null) {
    final _Taken taken = from.take(sent);
    if (to != null) {
      // Bitcoin bought with tether: it cost what that tether had cost.
      final Decimal unknown = sent == Decimal.zero
          ? Decimal.zero
          : received * _divide(taken.uncosted, sent);
      to.add(received, _Valued(taken.cost, from.approximate), unknown);
    } else {
      final Account? other = accounts[into.accountId];
      if (other == null) return;
      final _Valued proceeds = value.of(
        Money(received, other.asset),
        into.date,
      );
      from.realized += proceeds.pair - taken.cost;
      from.approximate |= proceeds.approximate;
    }
    return;
  }

  final Account? other = accounts[out.accountId];
  if (other == null) return;
  to!.add(received, value.of(Money(sent, other.asset), out.date));
}

class _Holding {
  _Holding(this.account);

  final Account account;
  Decimal quantity = Decimal.zero;
  Pair cost = Pair.zero;
  Decimal uncosted = Decimal.zero;
  Pair realized = Pair.zero;
  bool approximate = false;

  /// [amount] came in for [cost]; null when what it cost is not known.
  /// [unknown] is the part of it whose cost is not known when [cost] is.
  void add(Decimal amount, _Valued? cost, [Decimal? unknown]) {
    if (amount <= Decimal.zero) return;
    // What was held below zero, sold before its purchase was recorded,
    // comes back first and brings no cost with it.
    quantity += amount;
    if (cost == null) {
      uncosted += amount;
      return;
    }
    this.cost += cost.pair;
    uncosted += unknown ?? Decimal.zero;
    approximate |= cost.approximate;
  }

  /// Takes [amount] out, with its share of the cost.
  _Taken take(Decimal amount) {
    if (amount <= Decimal.zero) return _Taken(Pair.zero, Decimal.zero);
    final Decimal available = quantity > Decimal.zero ? quantity : Decimal.zero;
    final Decimal covered = amount < available ? amount : available;
    final Pair costOut = cost.share(covered, available);
    final Decimal unknownOut = available == Decimal.zero
        ? Decimal.zero
        : uncosted * _divide(covered, available);
    cost -= costOut;
    uncosted -= unknownOut;
    quantity -= amount;
    if (quantity <= Decimal.zero) {
      cost = Pair.zero;
      uncosted = Decimal.zero;
    }
    return _Taken(costOut, unknownOut);
  }

  /// [amount] went to pay a fee: it leaves, and what it had cost stays
  /// with what is left, so a fee lowers the gain instead of vanishing.
  void charge(Decimal amount) {
    final Pair kept = cost;
    take(amount);
    if (quantity > Decimal.zero) cost = kept;
  }
}

class _Taken {
  const _Taken(this.cost, this.uncosted);

  final Pair cost;
  final Decimal uncosted;
}

class _Valued {
  const _Valued(this.pair, this.approximate);

  final Pair pair;
  final bool approximate;
}

/// Tells an amount in the base currency and in dollars.
class _Valuer {
  _Valuer({required this.base, required this.today, required this.dollarOn});

  final Asset base;
  final RateTable today;
  final DollarRateOn dollarOn;

  static const Set<String> _dollars = <String>{'USD', 'USDT', 'USDC'};

  /// [money] in both currencies. [approximateDay] says the date is only a
  /// guess, as it is for what an account started with.
  _Valued of(Money money, DateTime day, {bool approximateDay = false}) {
    final Decimal amount = money.amount.abs();
    final bool baseIsDollar = base.code == 'USD';
    final Decimal? onDay = baseIsDollar ? Decimal.one : dollarOn(day);
    final Decimal? dollarNow = baseIsDollar
        ? Decimal.one
        : today.rate(Asset.usd, base);
    final Decimal? dollar = onDay ?? dollarNow;
    final bool guessed =
        !baseIsDollar && (onDay == null || approximateDay) && dollar != null;

    if (money.asset == base) {
      if (dollar == null) return _Valued(Pair(amount, Decimal.zero), true);
      return _Valued(Pair(amount, _divide(amount, dollar)), guessed);
    }
    if (_dollars.contains(money.asset.code)) {
      if (dollar == null) return _Valued(Pair(Decimal.zero, amount), true);
      return _Valued(Pair(amount * dollar, amount), guessed);
    }
    // Any other currency, at today's rates.
    final Decimal inBase =
        today.convert(Money(amount, money.asset), base)?.amount ?? Decimal.zero;
    final Decimal inUsd =
        today.convert(Money(amount, money.asset), Asset.usd)?.amount ??
        Decimal.zero;
    return _Valued(Pair(inBase, inUsd), true);
  }
}
