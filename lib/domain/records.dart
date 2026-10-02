import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../money/asset.dart';
import '../money/money.dart';
import 'pay_schedule.dart';

/// What kind of place an account is. It decides its icon and whether its
/// money counts as available to spend by default.
enum AccountKind {
  bank,
  card,
  cash,
  wallet,
  exchange,
  investment,
  other;

  /// Savings, investments and exchanges are not money for this fortnight.
  bool get spendableByDefault => switch (this) {
    AccountKind.exchange || AccountKind.investment => false,
    _ => true,
  };

  static AccountKind parse(String value) => AccountKind.values.firstWhere(
    (AccountKind k) => k.name == value,
    orElse: () => AccountKind.other,
  );
}

/// Where money is kept, in one asset.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.asset,
    required this.opening,
    this.institution = '',
    this.spendable = true,
    this.archived = false,
    this.sortOrder = 0,
    this.openingCost,
    this.syncRef,
  });

  final String id;
  final String name;
  final AccountKind kind;
  final Asset asset;
  final String institution;

  /// What the account held before the first movement the app knows.
  final Decimal opening;
  final bool spendable;
  final bool archived;
  final int sortOrder;

  /// What the opening balance cost, when the person said: the pesos paid
  /// for the bitcoin the account started with.
  final Money? openingCost;

  /// What keeps the account in sync, such as `binance:BTC`; null for one
  /// the person keeps by hand.
  final String? syncRef;

  Money get openingMoney => Money(opening, asset);

  Account copyWith({
    String? name,
    AccountKind? kind,
    String? institution,
    Decimal? opening,
    bool? spendable,
    bool? archived,
    int? sortOrder,
    Money? openingCost,
    bool clearOpeningCost = false,
  }) => Account(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    asset: asset,
    opening: opening ?? this.opening,
    institution: institution ?? this.institution,
    spendable: spendable ?? this.spendable,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    openingCost: clearOpeningCost ? null : (openingCost ?? this.openingCost),
    syncRef: syncRef,
  );
}

/// Which way a movement moved money.
enum EntryKind {
  expense,
  income,

  /// One leg of a move between the person's own accounts.
  transfer,

  /// A correction to make a balance match the bank's.
  adjustment;

  static EntryKind parse(String value) => EntryKind.values.firstWhere(
    (EntryKind k) => k.name == value,
    orElse: () => EntryKind.adjustment,
  );
}

/// One line of an account.
@immutable
class Entry {
  const Entry({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.kind,
    this.category,
    this.payee = '',
    this.note = '',
    this.transferId,
    this.source = 'manual',
    this.sourceRef,
    this.cost,
  });

  final String id;
  final String accountId;

  /// Signed, in the account's asset: negative when money left.
  final Decimal amount;
  final DateTime date;
  final EntryKind kind;
  final String? category;
  final String payee;
  final String note;
  final String? transferId;
  final String source;
  final String? sourceRef;

  /// What was paid for what came in, or received for what went out, when
  /// the other side is not one of the person's accounts: the pesos a
  /// bitcoin bought on Binance P2P cost. Null for a transfer, whose other
  /// leg says it, and for everyday money.
  final Money? cost;

  bool get isTransfer => transferId != null;

  /// A purchase or a sale of what the account holds, paid or collected
  /// outside the person's accounts.
  bool get isTrade => cost != null;

  Entry copyWith({
    String? accountId,
    Decimal? amount,
    DateTime? date,
    EntryKind? kind,
    String? category,
    bool clearCategory = false,
    String? payee,
    String? note,
    Money? cost,
    bool clearCost = false,
  }) => Entry(
    id: id,
    accountId: accountId ?? this.accountId,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    kind: kind ?? this.kind,
    category: clearCategory ? null : (category ?? this.category),
    payee: payee ?? this.payee,
    note: note ?? this.note,
    transferId: transferId,
    source: source,
    sourceRef: sourceRef,
    cost: clearCost ? null : (cost ?? this.cost),
  );
}

/// How often a recurring charge repeats.
enum Cadence {
  monthly,
  biweekly,
  weekly,
  yearly;

  static Cadence parse(String value) => Cadence.values.firstWhere(
    (Cadence c) => c.name == value,
    orElse: () => Cadence.monthly,
  );

  /// The charge after the one on [date].
  DateTime after(DateTime date) => switch (this) {
    Cadence.monthly => _sameDay(date.year, date.month + 1, date.day),
    Cadence.yearly => _sameDay(date.year + 1, date.month, date.day),
    Cadence.biweekly => DateTime(date.year, date.month, date.day + 14),
    Cadence.weekly => DateTime(date.year, date.month, date.day + 7),
  };

  static DateTime _sameDay(int year, int month, int day) {
    final DateTime first = DateTime(year, month);
    final int last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day > last ? last : day);
  }
}

/// A charge that repeats: rent, a subscription, an installment.
@immutable
class RecurringCharge {
  const RecurringCharge({
    required this.id,
    required this.name,
    required this.amount,
    required this.cadence,
    required this.nextDate,
    this.accountId,
    this.category,
    this.active = true,
    this.since,
  });

  final String id;
  final String name;

  /// Positive.
  final Money amount;
  final Cadence cadence;
  final DateTime nextDate;
  final String? accountId;
  final String? category;
  final bool active;
  final DateTime? since;

  /// Every charge from [nextDate] up to and including [until].
  Iterable<DateTime> datesUntil(DateTime until) sync* {
    for (var d = nextDate; !d.isAfter(until); d = cadence.after(d)) {
      yield d;
    }
  }
}

/// Money being put aside for one thing.
@immutable
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.monthly,
    this.deadline,
  });

  final String id;
  final String name;
  final Money target;
  final Money saved;
  final Money monthly;
  final DateTime? deadline;
}

/// Who the app is for and how they get paid.
@immutable
class Profile {
  const Profile({
    required this.name,
    required this.base,
    required this.schedule,
    this.pay,
    this.cushion,
  });

  final String name;

  /// The currency totals are shown in.
  final Asset base;
  final PaySchedule schedule;

  /// What arrives each payday, in [base], when the person said. A
  /// projection counts it as expected, never as money already there.
  final Decimal? pay;

  /// What the person wants to keep untouched, in [base]: the free amount
  /// leaves it out.
  final Decimal? cushion;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'base': base.code,
    'schedule': schedule.toJson(),
    if (pay != null) 'pay': pay.toString(),
    if (cushion != null) 'cushion': cushion.toString(),
  };

  static Profile fromJson(Map<String, Object?> json) => Profile(
    name: (json['name'] as String?) ?? '',
    base: Asset.of((json['base'] as String?) ?? 'COP'),
    schedule: PaySchedule.fromJson(
      (json['schedule'] as Map<String, Object?>?) ?? const <String, Object?>{},
    ),
    pay: Decimal.tryParse('${json['pay']}'),
    cushion: Decimal.tryParse('${json['cushion']}'),
  );

  /// A copy with what is given; [clearPay] and [clearCushion] forget them.
  Profile copyWith({
    String? name,
    Asset? base,
    PaySchedule? schedule,
    Decimal? pay,
    bool clearPay = false,
    Decimal? cushion,
    bool clearCushion = false,
  }) => Profile(
    name: name ?? this.name,
    base: base ?? this.base,
    schedule: schedule ?? this.schedule,
    pay: clearPay ? null : pay ?? this.pay,
    cushion: clearCushion ? null : cushion ?? this.cushion,
  );
}

/// A category as stored: built in (named by the app) or the person's own.
@immutable
class CategoryItem {
  const CategoryItem({
    required this.key,
    required this.income,
    this.name,
    this.archived = false,
    this.sortOrder = 0,
  });

  final String key;

  /// The person's name for it; null for a built-in category.
  final String? name;
  final bool income;
  final bool archived;
  final int sortOrder;

  bool get custom => name != null;
}
