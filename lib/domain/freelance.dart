import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../data/category.dart';
import '../data/ledger.dart';

/// Where an income stands.
enum IncomeStatus {
  /// Expected but not billed: a guess.
  estimated,

  /// Billed, waiting for the money.
  pending,

  /// The money arrived.
  collected,
}

/// What counts ahead in the projection, as the person chose for months
/// whose income varies. The most careful counts nothing it does not have.
enum IncomeScenario {
  /// Only what was collected: nothing ahead.
  collected,

  /// What is billed, on the day it is expected.
  pending,

  /// What is billed and what is only estimated.
  estimated,
}

/// Money a client is expected to pay, from the person's own records. No
/// tax is worked out: what to keep for that is the person's choice.
@immutable
class ExpectedIncome {
  const ExpectedIncome({
    required this.id,
    required this.client,
    required this.amount,
    required this.expected,
    this.status = IncomeStatus.pending,
    this.collectedOn,
    this.entryId,
    this.note = '',
  });

  final String id;
  final String client;

  /// In the ledger's unit.
  final int amount;

  /// When it should arrive.
  final DateTime expected;
  final IncomeStatus status;
  final DateTime? collectedOn;

  /// The income in the person's accounts it arrived as, when linked.
  final String? entryId;
  final String note;

  /// Billed, its day gone, and the money not in.
  bool overdue(DateTime today) =>
      status == IncomeStatus.pending && _day(expected).isBefore(_day(today));

  /// How many days late it is.
  int daysLate(DateTime today) =>
      overdue(today) ? _day(today).difference(_day(expected)).inDays : 0;

  ExpectedIncome copyWith({
    String? client,
    int? amount,
    DateTime? expected,
    IncomeStatus? status,
    DateTime? collectedOn,
    String? entryId,
    bool clearEntry = false,
    String? note,
  }) => ExpectedIncome(
    id: id,
    client: client ?? this.client,
    amount: amount ?? this.amount,
    expected: expected ?? this.expected,
    status: status ?? this.status,
    collectedOn: status == null || status == IncomeStatus.collected
        ? (collectedOn ?? this.collectedOn)
        : null,
    entryId: clearEntry ? null : (entryId ?? this.entryId),
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'client': client,
    'amount': amount,
    'expected': expected.toIso8601String(),
    'status': status.name,
    if (collectedOn != null) 'collectedOn': collectedOn!.toIso8601String(),
    if (entryId != null) 'entryId': entryId,
    if (note.isNotEmpty) 'note': note,
  };

  static ExpectedIncome? fromJson(Object? json) {
    if (json is! Map) return null;
    final DateTime? expected = DateTime.tryParse('${json['expected']}');
    final Object? amount = json['amount'];
    if (expected == null || amount is! num) return null;
    return ExpectedIncome(
      id: '${json['id']}',
      client: '${json['client'] ?? ''}',
      amount: amount.round(),
      expected: expected,
      status:
          IncomeStatus.values
              .where((IncomeStatus s) => s.name == json['status'])
              .firstOrNull ??
          IncomeStatus.pending,
      collectedOn: DateTime.tryParse('${json['collectedOn']}'),
      entryId: json['entryId'] as String?,
      note: '${json['note'] ?? ''}',
    );
  }
}

/// The person's variable income: what clients owe, what is guessed, and
/// the share of each payment kept apart.
@immutable
class FreelancePlan {
  const FreelancePlan({
    this.incomes = const <ExpectedIncome>[],
    this.reservePercent = 0,
    this.reserveSince,
    this.used = const <(DateTime, int)>[],
    this.scenario = IncomeScenario.pending,
  });

  final List<ExpectedIncome> incomes;

  /// The share of each payment kept apart, in percent; the person's own.
  final double reservePercent;

  /// Since when payments feed the reserve.
  final DateTime? reserveSince;

  /// What was taken out of the reserve, and when.
  final List<(DateTime, int)> used;
  final IncomeScenario scenario;

  bool get isEmpty => incomes.isEmpty && reservePercent == 0;

  int get usedTotal => used.fold(0, (int s, (DateTime, int) u) => s + u.$2);

  /// What the reserve holds after [collected] arrived since it started.
  int reserve(int collected) =>
      math.max(0, (collected * reservePercent / 100).round() - usedTotal);

  Iterable<ExpectedIncome> by(IncomeStatus status) =>
      incomes.where((ExpectedIncome i) => i.status == status);

  /// The incomes the projection counts ahead, as the scenario says: billed
  /// ones on their day, or tomorrow when late, since when they arrive is
  /// anyone's guess; estimated ones only when the person counts them.
  List<Movement> ahead(DateTime today) {
    final DateTime tomorrow = _day(today).add(const Duration(days: 1));
    return <Movement>[
      for (final ExpectedIncome i in incomes)
        if ((i.status == IncomeStatus.pending &&
                scenario != IncomeScenario.collected) ||
            (i.status == IncomeStatus.estimated &&
                scenario == IncomeScenario.estimated))
          Movement(
            id: 'income:${i.id}',
            date: _day(i.expected).isAfter(_day(today))
                ? _day(i.expected)
                : tomorrow,
            merchant: i.client,
            amount: i.amount,
            category: Category.other,
            flow: Flow.income,
          ),
    ];
  }

  FreelancePlan copyWith({
    List<ExpectedIncome>? incomes,
    double? reservePercent,
    DateTime? reserveSince,
    List<(DateTime, int)>? used,
    IncomeScenario? scenario,
  }) => FreelancePlan(
    incomes: incomes ?? this.incomes,
    reservePercent: reservePercent ?? this.reservePercent,
    reserveSince: reserveSince ?? this.reserveSince,
    used: used ?? this.used,
    scenario: scenario ?? this.scenario,
  );

  /// With [income], or replacing the one with its id.
  FreelancePlan withIncome(ExpectedIncome income) => copyWith(
    incomes: <ExpectedIncome>[
      for (final ExpectedIncome i in incomes)
        if (i.id != income.id) i,
      income,
    ],
  );

  FreelancePlan withoutIncome(String id) => copyWith(
    incomes: <ExpectedIncome>[
      for (final ExpectedIncome i in incomes)
        if (i.id != id) i,
    ],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'incomes': <Object?>[for (final ExpectedIncome i in incomes) i.toJson()],
    'reservePercent': reservePercent,
    if (reserveSince != null) 'reserveSince': reserveSince!.toIso8601String(),
    'used': <Object?>[
      for (final (DateTime on, int amount) in used)
        <String, Object?>{'on': on.toIso8601String(), 'amount': amount},
    ],
    'scenario': scenario.name,
  };

  static FreelancePlan fromJson(Object? json) {
    if (json is! Map) return const FreelancePlan();
    return FreelancePlan(
      incomes: <ExpectedIncome>[
        if (json['incomes'] case final List<Object?> incomes)
          for (final Object? i in incomes) ?ExpectedIncome.fromJson(i),
      ],
      reservePercent: (json['reservePercent'] as num?)?.toDouble() ?? 0,
      reserveSince: DateTime.tryParse('${json['reserveSince']}'),
      used: <(DateTime, int)>[
        if (json['used'] case final List<Object?> used)
          for (final Object? u in used)
            if (u is Map &&
                DateTime.tryParse('${u['on']}') != null &&
                u['amount'] is num)
              (DateTime.parse('${u['on']}'), (u['amount']! as num).round()),
      ],
      scenario:
          IncomeScenario.values
              .where((IncomeScenario s) => s.name == json['scenario'])
              .firstOrNull ??
          IncomeScenario.pending,
    );
  }
}

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
