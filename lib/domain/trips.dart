import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../money/asset.dart';
import '../money/rates.dart';
import 'records.dart';

/// A purchase abroad charged to an account in another currency: what was
/// paid, and how the charge was estimated until the bank says.
@immutable
class ForeignCharge {
  const ForeignCharge({
    required this.amount,
    required this.rate,
    required this.rateOn,
    required this.rateSource,
    this.fee = 0,
  });

  /// What was paid, in the trip's currency.
  final Decimal amount;

  /// One unit of the trip's currency in the account's.
  final Decimal rate;
  final DateTime rateOn;
  final String rateSource;

  /// What the card adds abroad, in percent, when the person knows it.
  final double fee;

  /// What the account is charged by this estimate.
  Decimal estimate(int decimals) =>
      (amount * rate * Decimal.parse((1 + fee / 100).toStringAsFixed(6))).round(
        scale: decimals,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'amount': amount.toString(),
    'rate': rate.toString(),
    'rateOn': rateOn.toIso8601String(),
    'rateSource': rateSource,
    if (fee != 0) 'fee': fee,
  };

  static ForeignCharge? fromJson(Object? json) {
    if (json is! Map) return null;
    final Decimal? amount = Decimal.tryParse('${json['amount']}');
    final Decimal? rate = Decimal.tryParse('${json['rate']}');
    final DateTime? on = DateTime.tryParse('${json['rateOn']}');
    if (amount == null || rate == null || on == null) return null;
    return ForeignCharge(
      amount: amount,
      rate: rate,
      rateOn: on,
      rateSource: '${json['rateSource'] ?? ''}',
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A trip: a budget in the local currency over some days, counted from the
/// person's own movements. Nothing is copied: a trip only says which
/// movements are its own.
@immutable
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.from,
    required this.to,
    required this.currency,
    this.budget,
    this.fee = 0,
    this.groupId,
    this.included = const <String>{},
    this.excluded = const <String>{},
    this.foreign = const <String, ForeignCharge>{},
    this.adjusted = const <String, Decimal>{},
  });

  final String id;
  final String name;
  final DateTime from;
  final DateTime to;

  /// The local currency's code.
  final String currency;

  /// In the local currency.
  final Decimal? budget;

  /// What the person's card adds abroad, in percent, as a default.
  final double fee;

  /// The group its shared expenses go to.
  final String? groupId;

  /// Expenses outside its days that belong to it, a flight bought before.
  final Set<String> included;

  /// Expenses in its days that do not, the rent at home.
  final Set<String> excluded;

  /// Purchases charged in another currency, by movement.
  final Map<String, ForeignCharge> foreign;

  /// What each adjusted movement had been estimated at, before it was set
  /// to what the bank charged.
  final Map<String, Decimal> adjusted;

  Asset get asset => Asset.of(currency);

  int get days => _day(to).difference(_day(from)).inDays + 1;

  /// Days still to go, today among them.
  int daysLeft(DateTime today) {
    final DateTime t = _day(today);
    if (t.isBefore(_day(from))) return days;
    if (t.isAfter(_day(to))) return 0;
    return _day(to).difference(t).inDays + 1;
  }

  /// Days gone, today among them.
  int daysGone(DateTime today) => days - daysLeft(today);

  bool within(DateTime date) =>
      !_day(date).isBefore(_day(from)) && !_day(date).isAfter(_day(to));

  /// Whether [e] is one of its expenses.
  bool covers(Entry e) =>
      e.kind == EntryKind.expense &&
      !e.isTrade &&
      e.amount < Decimal.zero &&
      !excluded.contains(e.id) &&
      (included.contains(e.id) || within(e.date));

  Trip copyWith({
    String? name,
    DateTime? from,
    DateTime? to,
    String? currency,
    Decimal? budget,
    bool clearBudget = false,
    double? fee,
    String? groupId,
    Set<String>? included,
    Set<String>? excluded,
    Map<String, ForeignCharge>? foreign,
    Map<String, Decimal>? adjusted,
  }) => Trip(
    id: id,
    name: name ?? this.name,
    from: from ?? this.from,
    to: to ?? this.to,
    currency: currency ?? this.currency,
    budget: clearBudget ? null : (budget ?? this.budget),
    fee: fee ?? this.fee,
    groupId: groupId ?? this.groupId,
    included: included ?? this.included,
    excluded: excluded ?? this.excluded,
    foreign: foreign ?? this.foreign,
    adjusted: adjusted ?? this.adjusted,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'currency': currency,
    if (budget != null) 'budget': budget.toString(),
    if (fee != 0) 'fee': fee,
    if (groupId != null) 'groupId': groupId,
    'included': included.toList()..sort(),
    'excluded': excluded.toList()..sort(),
    'foreign': <String, Object?>{
      for (final MapEntry<String, ForeignCharge> f in foreign.entries)
        f.key: f.value.toJson(),
    },
    'adjusted': <String, String>{
      for (final MapEntry<String, Decimal> a in adjusted.entries)
        a.key: a.value.toString(),
    },
  };

  static Trip? fromJson(Object? json) {
    if (json is! Map) return null;
    final DateTime? from = DateTime.tryParse('${json['from']}');
    final DateTime? to = DateTime.tryParse('${json['to']}');
    if (from == null || to == null || json['currency'] is! String) return null;
    Set<String> ids(String key) => <String>{
      if (json[key] case final List<Object?> list)
        for (final Object? id in list)
          if (id is String) id,
    };
    return Trip(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      from: from,
      to: to,
      currency: json['currency']! as String,
      budget: Decimal.tryParse('${json['budget']}'),
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      groupId: json['groupId'] as String?,
      included: ids('included'),
      excluded: ids('excluded'),
      foreign: <String, ForeignCharge>{
        if (json['foreign'] case final Map<Object?, Object?> foreign)
          for (final MapEntry<Object?, Object?> f in foreign.entries)
            if (ForeignCharge.fromJson(f.value) case final ForeignCharge c)
              '${f.key}': c,
      },
      adjusted: <String, Decimal>{
        if (json['adjusted'] case final Map<Object?, Object?> adjusted)
          for (final MapEntry<Object?, Object?> a in adjusted.entries)
            if (Decimal.tryParse('${a.value}') case final Decimal d)
              '${a.key}': d,
      },
    );
  }
}

/// One expense of a trip, in the trip's currency, with how it got there.
@immutable
class TripLine {
  const TripLine({
    required this.entry,
    required this.account,
    required this.local,
    this.foreign,
    this.rates = const <Rate>[],
    this.estimate,
    this.adjustedFrom,
  });

  final Entry entry;

  /// The currency the account keeps.
  final Asset account;

  /// What it was in the trip's currency; null when no rate converts it.
  final Decimal? local;

  /// How it was paid abroad, when it was.
  final ForeignCharge? foreign;

  /// The rates that converted it, when it was converted.
  final List<Rate> rates;

  /// What the account was to be charged by the estimate.
  final Decimal? estimate;

  /// The estimate it had before being set to the bank's charge.
  final Decimal? adjustedFrom;

  /// What the bank charged over the estimate, once known.
  Decimal? get difference => switch (adjustedFrom) {
    final Decimal before => -entry.amount - before,
    null => null,
  };
}

/// Where a trip stands on [today].
@immutable
class TripSummary {
  const TripSummary({
    required this.trip,
    required this.lines,
    required this.spent,
    required this.today,
  });

  final Trip trip;

  /// Newest first.
  final List<TripLine> lines;

  /// In the trip's currency, of the lines a rate could convert.
  final Decimal spent;
  final DateTime today;

  /// What is left of the budget; null without one.
  Decimal? get left => switch (trip.budget) {
    final Decimal b => b - spent,
    null => null,
  };

  /// What the days still to go can each take.
  Decimal? get perDay {
    final Decimal? l = left;
    final int days = trip.daysLeft(today);
    if (l == null || days <= 0) return null;
    return (l / Decimal.fromInt(days)).toDecimal(
      scaleOnInfinitePrecision: trip.asset.decimals,
    );
  }

  /// What each day gone took, on average.
  Decimal? get average {
    final int days = trip.daysGone(today);
    if (days <= 0) return null;
    return (spent / Decimal.fromInt(days)).toDecimal(
      scaleOnInfinitePrecision: trip.asset.decimals,
    );
  }

  /// Lines no rate could convert to the trip's currency.
  Iterable<TripLine> get unconverted =>
      lines.where((TripLine l) => l.local == null);

  static TripSummary of(
    Trip trip, {
    required List<Entry> entries,
    required Asset Function(String accountId) assetOf,
    required RateTable rates,
    required DateTime today,
  }) {
    final Asset local = trip.asset;
    final List<TripLine> lines = <TripLine>[];
    var spent = Decimal.zero;
    for (final Entry e in entries) {
      if (!trip.covers(e)) continue;
      final Asset account = assetOf(e.accountId);
      final Decimal paid = -e.amount;
      final ForeignCharge? foreign = trip.foreign[e.id];
      final Decimal? amount;
      if (foreign != null) {
        amount = foreign.amount;
      } else if (account == local) {
        amount = paid;
      } else {
        final Decimal? rate = rates.rate(account, local);
        amount = rate == null ? null : paid * rate;
      }
      lines.add(
        TripLine(
          entry: e,
          account: account,
          local: amount?.round(scale: local.decimals),
          foreign: foreign,
          rates: foreign == null && account != local
              ? rates.used(account, local)
              : const <Rate>[],
          estimate: foreign?.estimate(account.decimals),
          adjustedFrom: trip.adjusted[e.id],
        ),
      );
      if (amount != null) spent += amount;
    }
    lines.sort(
      (TripLine a, TripLine b) => b.entry.date.compareTo(a.entry.date),
    );
    return TripSummary(
      trip: trip,
      lines: lines,
      spent: spent.round(scale: local.decimals),
      today: today,
    );
  }
}

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
