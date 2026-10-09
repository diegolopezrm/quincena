import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show immutable, listEquals, mapEquals, setEquals;

import '../capture/merchants.dart' show merchantKey;
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
  const EnvelopePlan({
    required this.period,
    required this.envelopes,
    this.counted,
    this.fixed = const <String, int>{},
  });

  /// The split of [envelopes] made now, of the money [ledger] has to split:
  /// it keeps what that money had already counted, so the day to day
  /// counts only what is spent from it after.
  factory EnvelopePlan.made(Ledger ledger, List<Envelope> envelopes) {
    final DateTime start = periodStart(ledger);
    final Set<String> recorded = <String>{
      for (final Movement m in ledger.movements) m.id,
    };
    final Map<String, int> fixed = <String, int>{};
    for (final Movement m in ledger.committed) {
      // A movement dated ahead is known by its id; a charge to come, by
      // the name it will be paid under.
      if (recorded.contains(m.id)) continue;
      final String key = merchantKey(m.merchant);
      if (key.isEmpty) continue;
      fixed[key] = (fixed[key] ?? 0) + m.amount;
    }
    return EnvelopePlan(
      period: start,
      envelopes: envelopes,
      counted: <String>{
        for (final Movement m in ledger.movements)
          if (m.flow == Flow.expense && !_day(m.date).isBefore(start)) m.id,
      },
      fixed: fixed,
    );
  }

  /// The payday the period started on.
  final DateTime period;
  final List<Envelope> envelopes;

  /// The expenses of the period the money to split had already counted
  /// when the plan was made, by id: what was spent before, and what was
  /// dated ahead and so committed. Null for a plan saved before plans kept
  /// it: nothing tells what came after.
  final Set<String>? counted;

  /// The charges committed until payday when the plan was made, by the
  /// merchant they are paid to, with what they take: paying them is not
  /// the day to day, as the money to split had already left them out.
  final Map<String, int> fixed;

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

  /// With other [envelopes], made when this one was.
  EnvelopePlan copyWith({List<Envelope>? envelopes}) => EnvelopePlan(
    period: period,
    envelopes: envelopes ?? this.envelopes,
    counted: counted,
    fixed: fixed,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'period': _iso(period),
    'envelopes': <Object?>[for (final Envelope e in envelopes) e.toJson()],
    if (counted case final Set<String> ids) 'counted': ids.toList()..sort(),
    if (fixed.isNotEmpty) 'fixed': fixed,
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
      counted: switch (json['counted']) {
        final List<Object?> ids => <String>{
          for (final Object? id in ids) '$id',
        },
        _ => null,
      },
      fixed: <String, int>{
        if (json['fixed'] case final Map<Object?, Object?> fixed)
          for (final MapEntry<Object?, Object?> f in fixed.entries)
            if (f.value case final num amount) '${f.key}': amount.round(),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EnvelopePlan &&
      other.period == period &&
      listEquals(other.envelopes, envelopes) &&
      setEquals(other.counted, counted) &&
      mapEquals(other.fixed, fixed);

  @override
  int get hashCode => Object.hash(
    period,
    Object.hashAll(envelopes),
    counted == null ? null : Object.hashAllUnordered(counted!),
    Object.hashAllUnordered(fixed.entries.map((e) => '${e.key}=${e.value}')),
  );
}

/// The payday that started the period [ledger.today] is in.
DateTime periodStart(Ledger ledger) =>
    _day(ledger.schedule.lastOnOrBefore(_day(ledger.today)));

/// The money a plan can split: what is there to spend, less what is
/// committed until payday, the cushion and the reserve kept from variable
/// payments. Nothing set aside is taken out: the envelopes are what set it
/// aside.
int allocatable(Ledger ledger) =>
    ledger.balance -
    ledger.committedUntilPayday -
    ledger.cushion -
    ledger.reserved;

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

/// What [goal] asks of one pay period: its monthly part over the paydays
/// of a month, never more than is missing.
int goalShareFor(Ledger ledger, GoalShare goal) {
  if (goal.monthly <= 0 || goal.saved >= goal.target) return 0;
  return math.min(
    (goal.monthly / paydaysPerMonth(ledger)).round(),
    goal.target - goal.saved,
  );
}

/// A first split of the period's money. The day to day comes first, as it
/// is what the person lives on until payday: what a period usually takes,
/// or, with no period recorded, six tenths of the money. Then each goal its
/// share for the period, as far as what is left goes, in order; the rest of
/// a share waits for the next period. What is left after that is free.
///
/// With [last], the period before's envelopes are kept, fitted to the
/// money there is now in the same order: the day to day first.
List<Envelope> proposeEnvelopes(
  Ledger ledger, {
  required List<GoalShare> goals,
  EnvelopePlan? last,
  required String dailyName,
}) {
  final int money = math.max(0, allocatable(ledger));
  var free = money;
  int take(int wanted) {
    final int given = math.min(math.max(0, wanted), free);
    free -= given;
    return given;
  }

  if (last != null && last.envelopes.isNotEmpty) {
    final List<Envelope> kept = <Envelope>[
      for (final Envelope e in last.envelopes)
        if (e.kind != EnvelopeKind.goal ||
            goals.any((GoalShare g) => g.id == e.goalId))
          e,
    ];
    // The day to day first, wherever it was in the list.
    final Map<String, int> fitted = <String, int>{
      for (final Envelope e in kept)
        if (e.kind == EnvelopeKind.daily) e.id: take(e.amount),
    };
    for (final Envelope e in kept) {
      if (e.kind != EnvelopeKind.daily) fitted[e.id] = take(e.amount);
    }
    return <Envelope>[
      for (final Envelope e in kept) e.copyWith(amount: fitted[e.id]),
    ];
  }
  final int? usual = usualPeriodSpending(ledger);
  final Envelope daily = Envelope(
    id: 'daily',
    kind: EnvelopeKind.daily,
    name: dailyName,
    amount: take(usual == null || usual <= 0 ? (money * 0.6).round() : usual),
  );
  return <Envelope>[
    daily,
    for (final GoalShare g in goals)
      if (goalShareFor(ledger, g) > 0)
        Envelope(
          id: 'goal-${g.id}',
          kind: EnvelopeKind.goal,
          name: g.name,
          amount: take(goalShareFor(ledger, g)),
          goalId: g.id,
        ),
  ];
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

/// What the day to day usually takes in a day: what the last whole pay
/// periods spent, less what went to the charges that come on their own,
/// over their days. Null without a whole period recorded.
int? usualDailySpending(Ledger ledger, {int periods = 3}) {
  if (ledger.movements.isEmpty) return null;
  // Those charges are in any projection already, on their days.
  final Set<String> fixed = <String>{
    for (final Movement m in ledger.upcoming) merchantKey(m.merchant),
  }..remove('');
  final DateTime first = ledger.movements
      .map((Movement m) => _day(m.date))
      .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
  final DateTime end = periodStart(ledger);
  DateTime start = end;
  for (var i = 0; i < periods; i++) {
    final DateTime before = _day(
      ledger.schedule.lastOnOrBefore(start.subtract(const Duration(days: 1))),
    );
    // The period has to have been recorded from its start.
    if (first.isAfter(before)) break;
    start = before;
  }
  final int days = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  if (days <= 0) return null;
  final int spent = ledger.movements
      .where(
        (Movement m) =>
            m.flow == Flow.expense &&
            !_day(m.date).isBefore(start) &&
            _day(m.date).isBefore(end) &&
            !fixed.contains(merchantKey(m.merchant)),
      )
      .fold(0, (int s, Movement m) => s + m.amount);
  return (spent / days).round();
}

/// What was spent since the period started, all of it.
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

/// What the day to day has taken since [plan] was made: the expenses of
/// the period that the money it split had not counted yet, less what pays
/// a charge it had already left out as committed. Money spent before the
/// split, or committed then, was never in the envelopes.
int dailySpent(Ledger ledger, EnvelopePlan plan) {
  final Set<String>? counted = plan.counted;
  final Map<String, int> fixed = Map<String, int>.of(plan.fixed);
  var spent = 0;
  for (final Movement m in ledger.movements) {
    if (m.flow != Flow.expense || !ledger.settled(m)) continue;
    if (_day(m.date).isBefore(plan.period)) continue;
    if (counted != null && counted.contains(m.id)) continue;
    // A committed charge, paid: up to what it was committed for.
    final String key = merchantKey(m.merchant);
    final int left = fixed[key] ?? 0;
    final int paid = math.min(left, m.amount);
    if (paid > 0) fixed[key] = left - paid;
    spent += m.amount - paid;
  }
  return spent;
}

/// What no envelope holds now: the money to split, less what the envelopes
/// set aside and what the day to day still has. Spending from the day to
/// day leaves it as it is; spending over it comes out of it. What can be
/// spent is always this and what the day to day still has.
int unassigned(Ledger ledger, EnvelopePlan plan, {int? spent}) {
  final int daily = plan.daily;
  final int left = math.max(0, daily - (spent ?? dailySpent(ledger, plan)));
  return allocatable(ledger) - plan.setAside - left;
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

/// What has to go into [goal] each month from [from] for [arrival] to fall
/// by [deadline], rounded up to [step], in the ledger's unit. Zero when
/// nothing is missing; null when no month is left before the deadline.
int? monthlyToReach(
  GoalShare goal,
  DateTime deadline, {
  required DateTime from,
  int step = 1,
}) {
  final int left = goal.target - goal.saved;
  if (left <= 0) return 0;
  final DateTime limit = _day(deadline);
  // The months whose contribution, as [arrival] counts them, lands in time.
  var months = 0;
  while (months < 1200 &&
      !DateTime(from.year, from.month + months + 1, from.day).isAfter(limit)) {
    months++;
  }
  if (months == 0) return null;
  final int each = (left / months).ceil();
  return ((each + step - 1) ~/ step) * step;
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
/// likely balance: the pay counts as expected in both, and so does
/// [daily], what the day to day takes each day from tomorrow, when given.
ScenarioOutcome weighScenario(
  Ledger ledger,
  Scenario scenario, {
  int horizon = 45,
  int daily = 0,
}) {
  final DateTime today = _day(ledger.today);
  final List<ProjectedEvent> dayToDay = <ProjectedEvent>[
    if (daily > 0)
      for (var i = 1; i <= horizon; i++)
        ProjectedEvent(
          date: DateTime(today.year, today.month, today.day + i),
          amount: -daily,
          certainty: Certainty.hypothetical,
          kind: ProjectedKind.tryOut,
        ),
  ];
  final Projection now = Projection.of(
    ledger,
    horizon: horizon,
    tryOut: dayToDay,
  );
  final Projection tried = Projection.of(
    ledger,
    horizon: horizon,
    tryOut: <ProjectedEvent>[
      ...dayToDay,
      ...scenario.events(ledger, horizon: horizon),
    ],
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
