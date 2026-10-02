import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../data/category.dart';
import '../data/ledger.dart';
import 'projection.dart';

/// What a virtual envelope holds money for.
enum EnvelopeKind {
  /// The day to day until the next payday: still money to spend.
  daily,

  /// Money set aside for a savings goal.
  goal,

  /// Money set aside for something else the person names.
  aside,
}

/// A share of the money to spend, put aside on paper. No money moves: an
/// envelope is not a transfer, and the bank knows nothing of it.
@immutable
class Envelope {
  const Envelope({
    required this.id,
    required this.kind,
    required this.name,
    required this.amount,
    this.goalId,
  });

  final String id;
  final EnvelopeKind kind;
  final String name;

  /// In the ledger's smallest unit.
  final int amount;
  final String? goalId;

  /// Money in it is no longer free to spend.
  bool get setAside => kind != EnvelopeKind.daily;

  Envelope copyWith({String? name, int? amount}) => Envelope(
    id: id,
    kind: kind,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    goalId: goalId,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'name': name,
    'amount': amount,
    if (goalId != null) 'goalId': goalId,
  };

  static Envelope? fromJson(Object? json) {
    if (json is! Map) return null;
    final EnvelopeKind? kind = EnvelopeKind.values
        .where((EnvelopeKind k) => k.name == json['kind'])
        .firstOrNull;
    final Object? amount = json['amount'];
    if (kind == null || amount is! num) return null;
    return Envelope(
      id: '${json['id']}',
      kind: kind,
      name: '${json['name'] ?? ''}',
      amount: amount.round(),
      goalId: json['goalId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Envelope &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.amount == amount &&
      other.goalId == goalId;

  @override
  int get hashCode => Object.hash(id, kind, name, amount, goalId);
}

/// How the money of one pay period is split, from the payday that started
/// it until the next.
@immutable
class EnvelopePlan {
  const EnvelopePlan({required this.period, required this.envelopes});

  /// The payday the period started on.
  final DateTime period;
  final List<Envelope> envelopes;

  /// What the envelopes set aside: left out of the money free to spend.
  int get setAside => envelopes
      .where((Envelope e) => e.setAside)
      .fold(0, (int sum, Envelope e) => sum + e.amount);

  /// Everything the envelopes hold, the day to day included.
  int get assigned =>
      envelopes.fold(0, (int sum, Envelope e) => sum + e.amount);

  int get daily => envelopes
      .where((Envelope e) => e.kind == EnvelopeKind.daily)
      .fold(0, (int sum, Envelope e) => sum + e.amount);

  Map<String, Object?> toJson() => <String, Object?>{
    'period': _iso(period),
    'envelopes': <Object?>[for (final Envelope e in envelopes) e.toJson()],
  };

  static EnvelopePlan? fromJson(Object? json) {
    if (json is! Map) return null;
    final DateTime? period = DateTime.tryParse('${json['period']}');
    if (period == null) return null;
    return EnvelopePlan(
      period: period,
      envelopes: <Envelope>[
        for (final Object? e
            in json['envelopes'] as List<Object?>? ?? const <Object?>[])
          ?Envelope.fromJson(e),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EnvelopePlan &&
      other.period == period &&
      listEquals(other.envelopes, envelopes);

  @override
  int get hashCode => Object.hash(period, Object.hashAll(envelopes));
}

/// The payday that started the period [ledger.today] is in.
DateTime periodStart(Ledger ledger) =>
    _day(ledger.schedule.lastOnOrBefore(_day(ledger.today)));

/// The money a plan can split: what is there to spend, less what is
/// committed until payday and the cushion. Nothing set aside is taken out:
/// the envelopes are what set it aside.
int allocatable(Ledger ledger) =>
    ledger.balance - ledger.committedUntilPayday - ledger.cushion;

/// A goal, in the ledger's unit, for planning.
@immutable
class GoalShare {
  const GoalShare({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.monthly,
  });

  final String id;
  final String name;
  final int target;
  final int saved;
  final int monthly;
}

/// Paydays in an average month for [ledger]'s schedule: two for twice a
/// month, about 4.3 weekly.
double paydaysPerMonth(Ledger ledger) {
  final DateTime start = DateTime(2026, 1, 1);
  var count = 0;
  for (
    DateTime d = ledger.schedule.nextAfter(start);
    d.isBefore(DateTime(2027, 1, 1));
    d = ledger.schedule.nextAfter(d)
  ) {
    count++;
  }
  return count / 12;
}

/// A first split of the period's money: each goal its monthly share for one
/// period, the day to day what was spent in a period lately, and what is
/// left, free. With [last], the period before's envelopes are reused.
List<Envelope> proposeEnvelopes(
  Ledger ledger, {
  required List<GoalShare> goals,
  EnvelopePlan? last,
  required String dailyName,
}) {
  final int money = math.max(0, allocatable(ledger));
  if (last != null && last.envelopes.isNotEmpty) {
    return <Envelope>[
      for (final Envelope e in last.envelopes)
        if (e.kind != EnvelopeKind.goal ||
            goals.any((GoalShare g) => g.id == e.goalId))
          e,
    ];
  }
  final double perMonth = paydaysPerMonth(ledger);
  final List<Envelope> out = <Envelope>[
    for (final GoalShare g in goals)
      if (g.monthly > 0 && g.saved < g.target)
        Envelope(
          id: 'goal-${g.id}',
          kind: EnvelopeKind.goal,
          name: g.name,
          amount: math.min((g.monthly / perMonth).round(), g.target - g.saved),
          goalId: g.id,
        ),
  ];
  final int forGoals = out.fold(0, (int s, Envelope e) => s + e.amount);
  final int left = math.max(0, money - forGoals);
  final int? usual = usualPeriodSpending(ledger);
  out.insert(
    0,
    Envelope(
      id: 'daily',
      kind: EnvelopeKind.daily,
      name: dailyName,
      // What a period usually takes, or, without a period that spent
      // anything, six tenths of what is left.
      amount: usual == null || usual <= 0
          ? (left * 0.6).round()
          : math.min(usual, left),
    ),
  );
  return out;
}

/// What the last whole pay periods took on average, recurring charges
/// aside; null without a whole one recorded.
int? usualPeriodSpending(Ledger ledger, {int periods = 3}) {
  final List<Movement> spent = <Movement>[
    for (final Movement m in ledger.movements)
      if (m.flow == Flow.expense && ledger.settled(m)) m,
  ];
  if (spent.isEmpty) return null;
  final DateTime first = spent
      .map((Movement m) => _day(m.date))
      .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
  final List<int> totals = <int>[];
  DateTime end = periodStart(ledger);
  for (var i = 0; i < periods; i++) {
    final DateTime start = _day(
      ledger.schedule.lastOnOrBefore(end.subtract(const Duration(days: 1))),
    );
    if (first.isAfter(start)) break;
    totals.add(
      spent
          .where(
            (Movement m) =>
                !_day(m.date).isBefore(start) && _day(m.date).isBefore(end),
          )
          .fold(0, (int s, Movement m) => s + m.amount),
    );
    end = start;
  }
  if (totals.isEmpty) return null;
  return (totals.reduce((int a, int b) => a + b) / totals.length).round();
}

/// What the day to day has taken since the period started.
int spentThisPeriod(Ledger ledger) {
  final DateTime start = periodStart(ledger);
  return ledger.movements
      .where(
        (Movement m) =>
            m.flow == Flow.expense &&
            ledger.settled(m) &&
            !_day(m.date).isBefore(start),
      )
      .fold(0, (int s, Movement m) => s + m.amount);
}

/// When a goal is reached at [monthly] a month, from [from]; null when
/// nothing goes into it. Already reached, it is [from].
DateTime? arrival(
  GoalShare goal, {
  required DateTime from,
  int? monthly,
  int extra = 0,
}) {
  final int left = goal.target - goal.saved - extra;
  if (left <= 0) return _day(from);
  final int each = monthly ?? goal.monthly;
  if (each <= 0) return null;
  final int months = (left / each).ceil();
  return DateTime(from.year, from.month + months, from.day);
}

/// Why the cushion cannot be counted in days.
enum CushionGap {
  /// Less than a month of movements: no average to trust.
  shortHistory,

  /// Nothing spent on what the person calls essential.
  noEssentialSpending,

  /// No account chosen to hold it.
  noReserve,
}

/// An emergency fund as days of essential spending.
@immutable
class CushionDays {
  const CushionDays({
    required this.reserve,
    required this.dailyEssential,
    required this.from,
    required this.to,
    this.days,
    this.gap,
  });

  /// In the ledger's unit.
  final int reserve;

  /// The average a day spent on the essential categories, between [from]
  /// and [to].
  final int dailyEssential;
  final DateTime from;
  final DateTime to;

  /// Null when [gap] says why it cannot be counted.
  final int? days;
  final CushionGap? gap;
}

/// [reserve] as the days of [essentials] it would cover, at what they
/// averaged over the last [window] days, or since the first movement when
/// that is shorter, and never less than 30.
CushionDays cushionDays(
  Ledger ledger, {
  required int reserve,
  required Set<Category> essentials,
  int window = 90,
}) {
  final DateTime to = _day(ledger.today);
  final List<Movement> spent = <Movement>[
    for (final Movement m in ledger.movements)
      if (m.flow == Flow.expense && ledger.settled(m)) m,
  ];
  final DateTime? first = spent.isEmpty
      ? null
      : spent
            .map((Movement m) => _day(m.date))
            .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
  final DateTime windowStart = to.subtract(Duration(days: window));
  final DateTime from = first == null || first.isBefore(windowStart)
      ? windowStart
      : first;
  final int span = to.difference(from).inDays + 1;
  final int essential = spent
      .where(
        (Movement m) =>
            essentials.contains(m.category) && !_day(m.date).isBefore(from),
      )
      .fold(0, (int s, Movement m) => s + m.amount);
  final int daily = span <= 0 ? 0 : (essential / span).round();
  CushionGap? gap;
  if (reserve <= 0) {
    gap = CushionGap.noReserve;
  } else if (first == null || span < 30) {
    gap = CushionGap.shortHistory;
  } else if (daily <= 0) {
    gap = CushionGap.noEssentialSpending;
  }
  return CushionDays(
    reserve: reserve,
    dailyEssential: daily,
    from: from,
    to: to,
    days: gap == null ? reserve ~/ daily : null,
    gap: gap,
  );
}

/// Something wanted, for later. A price typed by hand: no shop is watched.
@immutable
class Wish {
  const Wish({
    required this.id,
    required this.name,
    required this.price,
    this.priority = 2,
    this.waitUntil,
  });

  final String id;
  final String name;

  /// In the ledger's unit.
  final int price;

  /// 1 is the most wanted.
  final int priority;

  /// The person chose to wait until then before deciding.
  final DateTime? waitUntil;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'price': price,
    'priority': priority,
    if (waitUntil != null) 'waitUntil': _iso(waitUntil!),
  };

  static Wish? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? price = json['price'];
    if (price is! num) return null;
    return Wish(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      price: price.round(),
      priority: (json['priority'] as num?)?.round().clamp(1, 3) ?? 2,
      waitUntil: DateTime.tryParse('${json['waitUntil']}'),
    );
  }
}

/// What a scenario changes.
enum ScenarioKind {
  /// Setting aside more on each payday.
  saveMore,

  /// A recurring charge going up.
  chargeUp,

  /// The pay arriving days late.
  payLate,
}

/// One change tried against the plan. Saving it applies nothing.
@immutable
class Scenario {
  const Scenario({
    required this.id,
    required this.kind,
    this.amount = 0,
    this.days = 0,
    this.chargeName,
  });

  final String id;
  final ScenarioKind kind;

  /// For [ScenarioKind.saveMore], what each payday sets aside; for
  /// [ScenarioKind.chargeUp], how much more the charge is. In the ledger's
  /// unit.
  final int amount;

  /// For [ScenarioKind.payLate].
  final int days;

  /// For [ScenarioKind.chargeUp], the charge, by its name.
  final String? chargeName;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    if (amount != 0) 'amount': amount,
    if (days != 0) 'days': days,
    if (chargeName != null) 'chargeName': chargeName,
  };

  static Scenario? fromJson(Object? json) {
    if (json is! Map) return null;
    final ScenarioKind? kind = ScenarioKind.values
        .where((ScenarioKind k) => k.name == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    return Scenario(
      id: '${json['id']}',
      kind: kind,
      amount: (json['amount'] as num?)?.round() ?? 0,
      days: (json['days'] as num?)?.round() ?? 0,
      chargeName: json['chargeName'] as String?,
    );
  }

  /// The scenario as things tried out against the projection.
  List<ProjectedEvent> events(Ledger ledger, {int horizon = 45}) {
    final DateTime today = _day(ledger.today);
    final DateTime end = today.add(Duration(days: horizon));
    switch (kind) {
      case ScenarioKind.saveMore:
        return <ProjectedEvent>[
          for (
            DateTime d = _day(ledger.schedule.nextAfter(today));
            !d.isAfter(end);
            d = _day(ledger.schedule.nextAfter(d))
          )
            ProjectedEvent(
              date: d,
              amount: -amount,
              certainty: Certainty.hypothetical,
              kind: ProjectedKind.tryOut,
            ),
        ];
      case ScenarioKind.chargeUp:
        return <ProjectedEvent>[
          for (final Movement m in ledger.upcoming)
            if (m.merchant == chargeName &&
                _day(m.date).isAfter(today) &&
                !_day(m.date).isAfter(end))
              ProjectedEvent(
                date: _day(m.date),
                amount: -amount,
                certainty: Certainty.hypothetical,
                kind: ProjectedKind.tryOut,
                label: m.merchant,
              ),
        ];
      case ScenarioKind.payLate:
        final int? pay = ledger.pay;
        if (pay == null) return const <ProjectedEvent>[];
        return <ProjectedEvent>[
          for (
            DateTime d = _day(ledger.schedule.nextAfter(today));
            !d.isAfter(end);
            d = _day(ledger.schedule.nextAfter(d))
          ) ...<ProjectedEvent>[
            ProjectedEvent(
              date: d,
              amount: -pay,
              certainty: Certainty.hypothetical,
              kind: ProjectedKind.tryOut,
            ),
            ProjectedEvent(
              date: d.add(Duration(days: days)),
              amount: pay,
              certainty: Certainty.hypothetical,
              kind: ProjectedKind.tryOut,
            ),
          ],
        ];
    }
  }
}

/// Today and with a scenario, side by side.
@immutable
class ScenarioOutcome {
  const ScenarioOutcome({
    required this.now,
    required this.tried,
    required this.lowestNow,
    required this.lowestTried,
    this.tightNow,
    this.tightTried,
  });

  final Projection now;
  final Projection tried;

  /// The lowest the likely balance gets in the window, today and with the
  /// scenario.
  final ProjectedDay lowestNow;
  final ProjectedDay lowestTried;

  /// The first day the likely balance goes under the cushion.
  final DateTime? tightNow;
  final DateTime? tightTried;

  /// Where the likely balance ends the window, today and with the scenario.
  int get endNow => now.days.last.likely;
  int get endTried => tried.days.last.likely;
}

/// Weighs [scenario] against things as they are over [horizon] days, on the
/// likely balance: the pay counts as expected in both.
ScenarioOutcome weighScenario(
  Ledger ledger,
  Scenario scenario, {
  int horizon = 45,
}) {
  final Projection now = Projection.of(ledger, horizon: horizon);
  final Projection tried = Projection.of(
    ledger,
    horizon: horizon,
    tryOut: scenario.events(ledger, horizon: horizon),
  );
  ProjectedDay lowest(Projection p) => p.days.reduce(
    (ProjectedDay a, ProjectedDay b) => b.likely < a.likely ? b : a,
  );
  DateTime? tight(Projection p) => p.days
      .where((ProjectedDay d) => d.likely < ledger.cushion)
      .map((ProjectedDay d) => d.date)
      .firstOrNull;
  return ScenarioOutcome(
    now: now,
    tried: tried,
    lowestNow: lowest(now),
    lowestTried: lowest(tried),
    tightNow: tight(now),
    tightTried: tight(tried),
  );
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Where the emergency fund is, what counts as essential, and how many
/// days the person wants it to cover. The app imposes none of it.
@immutable
class CushionSettings {
  const CushionSettings({
    this.accounts = const <String>{},
    this.essentials = defaultEssentials,
    this.targetDays,
  });

  /// The categories a month cannot go without, until the person says
  /// otherwise.
  static const Set<Category> defaultEssentials = <Category>{
    Category.housing,
    Category.groceries,
    Category.transport,
    Category.utilities,
    Category.health,
    Category.debt,
  };

  final Set<String> accounts;
  final Set<Category> essentials;
  final int? targetDays;

  Map<String, Object?> toJson() => <String, Object?>{
    'accounts': accounts.toList()..sort(),
    'essentials': <String>[for (final Category c in essentials) c.name]..sort(),
    if (targetDays != null) 'targetDays': targetDays,
  };

  static CushionSettings fromJson(Object? json) {
    if (json is! Map) return const CushionSettings();
    final List<Object?>? essentials = json['essentials'] as List<Object?>?;
    return CushionSettings(
      accounts: <String>{
        for (final Object? a
            in json['accounts'] as List<Object?>? ?? const <Object?>[])
          '$a',
      },
      essentials: essentials == null
          ? defaultEssentials
          : <Category>{
              for (final Object? e in essentials)
                ?Category.values.where((Category c) => c.name == e).firstOrNull,
            },
      targetDays: (json['targetDays'] as num?)?.round(),
    );
  }

  CushionSettings copyWith({
    Set<String>? accounts,
    Set<Category>? essentials,
    int? targetDays,
    bool clearTarget = false,
  }) => CushionSettings(
    accounts: accounts ?? this.accounts,
    essentials: essentials ?? this.essentials,
    targetDays: clearTarget ? null : targetDays ?? this.targetDays,
  );
}
