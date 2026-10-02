import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/ledger_builder.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/plan.dart';
import 'package:quincena/domain/projection.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  late QuincenaStore store;
  late Account bank;
  // Paid on the 15th and the 30th; today is the 3rd of October.
  final DateTime today = DateTime(2026, 10, 3);

  Future<void> profile({String? pay, String? cushion}) => store.saveProfile(
    Profile(
      name: 'Ana',
      base: Asset.cop,
      schedule: const TwiceMonthly(),
      pay: pay == null ? null : d(pay),
      cushion: cushion == null ? null : d(cushion),
    ),
  );

  setUp(() async {
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => today,
    );
    await store.ensureCategories();
    await profile();
    bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('2000000'),
    );
  });

  tearDown(() => store.close());

  Future<Ledger> ledger({int setAside = 0}) async => buildLedger(
    (await store.snapshot())!,
    today: today,
    setAside: setAside,
  ).ledger;

  Future<void> spend(String amount, DateTime on, String category) =>
      store.addEntry(
        accountId: bank.id,
        amount: d(amount),
        kind: EntryKind.expense,
        date: on,
        category: category,
      );

  const GoalShare trip = GoalShare(
    id: 'g1',
    name: 'Cartagena',
    target: 2000000,
    saved: 500000,
    monthly: 300000,
  );

  group('envelopes', () {
    test(
      'the money to split leaves out what is committed and the cushion',
      () async {
        await profile(cushion: '200000');
        await store.addRecurring(
          name: 'Internet',
          amount: Money(d('100000'), Asset.cop),
          cadence: Cadence.monthly,
          nextDate: DateTime(2026, 10, 10),
          accountId: bank.id,
          category: 'utilities',
        );
        expect(allocatable(await ledger()), 2000000 - 100000 - 200000);
      },
    );

    test(
      'a first proposal: each goal its share, the day to day as usual',
      () async {
        // Paid on the 30th, and three whole fortnights behind, each
        // taking 600.000.
        await store.addEntry(
          accountId: bank.id,
          amount: d('2000000'),
          kind: EntryKind.income,
          date: DateTime(2026, 9, 30, 8),
          category: 'salary',
        );
        for (final DateTime on in <DateTime>[
          DateTime(2026, 8, 16),
          DateTime(2026, 8, 31),
          DateTime(2026, 9, 16),
        ]) {
          await spend('600000', on, 'groceries');
        }
        final Ledger l = await ledger();
        final List<Envelope> proposal = proposeEnvelopes(
          l,
          goals: const <GoalShare>[trip],
          dailyName: 'Día a día',
        );
        expect(proposal.first.kind, EnvelopeKind.daily);
        expect(proposal.first.amount, 600000);
        // 300.000 a month, paid twice a month.
        final Envelope goal = proposal.last;
        expect(goal.kind, EnvelopeKind.goal);
        expect(goal.amount, 150000);
        expect(goal.goalId, 'g1');
      },
    );

    test(
      'without history the day to day takes six tenths of what is left',
      () async {
        final Ledger l = await ledger();
        final List<Envelope> proposal = proposeEnvelopes(
          l,
          goals: const <GoalShare>[],
          dailyName: 'Día a día',
        );
        expect(proposal.single.amount, (2000000 * 0.6).round());
      },
    );

    test('what envelopes set aside is not free twice', () async {
      final EnvelopePlan plan = EnvelopePlan(
        period: DateTime(2026, 9, 30),
        envelopes: const <Envelope>[
          Envelope(
            id: 'daily',
            kind: EnvelopeKind.daily,
            name: 'Día a día',
            amount: 900000,
          ),
          Envelope(
            id: 'g',
            kind: EnvelopeKind.goal,
            name: 'Cartagena',
            amount: 150000,
            goalId: 'g1',
          ),
          Envelope(
            id: 'a',
            kind: EnvelopeKind.aside,
            name: 'Regalo',
            amount: 50000,
          ),
        ],
      );
      expect(plan.setAside, 200000);
      expect(plan.assigned, 1100000);
      final Ledger l = await ledger(setAside: plan.setAside);
      expect(l.freeUntilPayday, 2000000 - 200000);
      // The daily envelope is still money to spend.
      expect(EnvelopePlan.fromJson(plan.toJson()), plan);
    });

    test('the plan of a period belongs to it', () async {
      expect(periodStart(await ledger()), DateTime(2026, 9, 30));
    });
  });

  group('goals', () {
    test('arrive by what goes in each month, sooner with more', () {
      expect(arrival(trip, from: today), DateTime(2027, 3, 3));
      expect(arrival(trip, from: today, monthly: 500000), DateTime(2027, 1, 3));
      expect(arrival(trip, from: today, extra: 1500000), today);
      expect(
        arrival(
          const GoalShare(id: 'x', name: 'x', target: 10, saved: 0, monthly: 0),
          from: today,
        ),
        isNull,
      );
    });
  });

  group('the cushion in days', () {
    test('a month of history is the least it trusts', () async {
      await spend('300000', DateTime(2026, 9, 20), 'housing');
      final CushionDays c = cushionDays(
        await ledger(),
        reserve: 3000000,
        essentials: CushionSettings.defaultEssentials,
      );
      expect(c.gap, CushionGap.shortHistory);
      expect(c.days, isNull);
    });

    test('nothing essential spent is said, not counted as forever', () async {
      await spend('300000', DateTime(2026, 7, 1), 'leisure');
      final CushionDays c = cushionDays(
        await ledger(),
        reserve: 3000000,
        essentials: CushionSettings.defaultEssentials,
      );
      expect(c.gap, CushionGap.noEssentialSpending);
      expect(c.days, isNull);
    });

    test('a fund becomes days of what is essential', () async {
      // Recorded since June; the last 91 days took 1.820.000 on what is
      // essential: 20.000 a day.
      await spend('500000', DateTime(2026, 6, 1), 'leisure');
      await spend('1820000', DateTime(2026, 7, 10), 'housing');
      final CushionDays c = cushionDays(
        await ledger(),
        reserve: 3000000,
        essentials: CushionSettings.defaultEssentials,
      );
      expect(c.from, DateTime(2026, 7, 5));
      expect(c.dailyEssential, 20000);
      expect(c.days, 150);
      expect(
        cushionDays(
          await ledger(),
          reserve: 0,
          essentials: CushionSettings.defaultEssentials,
        ).gap,
        CushionGap.noReserve,
      );
    });
  });

  group('what if', () {
    test(
      'saving more each payday lowers the likely balance from then',
      () async {
        await profile(pay: '2400000');
        final Ledger l = await ledger();
        final ScenarioOutcome o = weighScenario(
          l,
          const Scenario(id: 's', kind: ScenarioKind.saveMore, amount: 300000),
        );
        ProjectedDay on(Projection p, int m, int day) => p.days.firstWhere(
          (ProjectedDay x) => x.date == DateTime(2026, m, day),
        );
        expect(on(o.now, 10, 15).likely - on(o.tried, 10, 15).likely, 300000);
        // Nothing sure changes.
        expect(on(o.tried, 10, 15).sure, on(o.now, 10, 15).sure);
      },
    );

    test('a charge going up, and a pay arriving late', () async {
      await profile(pay: '2400000', cushion: '100000');
      // September's last pay arrived, and went to the card.
      await store.addEntry(
        accountId: bank.id,
        amount: d('2400000'),
        kind: EntryKind.income,
        date: DateTime(2026, 9, 30, 8),
        category: 'salary',
      );
      await spend('2400000', DateTime(2026, 10, 1), 'debt');
      await store.addRecurring(
        name: 'Arriendo',
        amount: Money(d('1950000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 16),
        accountId: bank.id,
        category: 'housing',
      );
      final Ledger l = await ledger();
      final ScenarioOutcome up = weighScenario(
        l,
        const Scenario(
          id: 'u',
          kind: ScenarioKind.chargeUp,
          amount: 200000,
          chargeName: 'Arriendo',
        ),
      );
      // Two rents within the 45 days, each 200.000 more.
      expect(up.endNow - up.endTried, 400000);

      // A pay ten days late leaves the 16th's rent to the money there is.
      final ScenarioOutcome late = weighScenario(
        l,
        const Scenario(id: 'l', kind: ScenarioKind.payLate, days: 10),
      );
      expect(late.tightNow, isNull);
      expect(late.tightTried, DateTime(2026, 10, 16));
      expect(
        Scenario.fromJson(
          const Scenario(
            id: 'l',
            kind: ScenarioKind.payLate,
            days: 10,
          ).toJson(),
        )!.days,
        10,
      );
    });
  });

  test('a wish keeps its price, priority and wait', () {
    final Wish w = Wish(
      id: 'w',
      name: 'Audífonos',
      price: 350000,
      priority: 1,
      waitUntil: DateTime(2026, 11, 1),
    );
    final Wish back = Wish.fromJson(w.toJson())!;
    expect(back.price, 350000);
    expect(back.priority, 1);
    expect(back.waitUntil, DateTime(2026, 11, 1));
    expect(Category.values, contains(Category.housing));
  });
}
