import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/ledger_builder.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/projection.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  late QuincenaStore store;
  late Account bank;
  final DateTime today = DateTime(2026, 10, 3);

  setUp(() async {
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => today,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
    );
    bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('1000000'),
    );
  });

  tearDown(() => store.close());

  Future<Ledger> ledger({
    List<Group> groups = const <Group>[],
    FreelancePlan freelance = const FreelancePlan(),
    int reserved = 0,
  }) async => buildLedger(
    (await store.snapshot())!,
    today: today,
    shared: SharedLinks.of(groups),
    expected: freelance.ahead(today),
    reserved: reserved,
  ).ledger;

  group('splitting', () {
    test('parts always add up to the total, rounding included', () {
      expect(splitEvenly(100000, 3), <int>[33334, 33333, 33333]);
      expect(splitEvenly(1000, 6), <int>[170, 166, 166, 166, 166, 166]);
      for (final int total in <int>[1, 7, 99, 100001, 123457]) {
        for (var n = 1; n <= 7; n++) {
          expect(splitEvenly(total, n).fold(0, (int a, int b) => a + b), total);
        }
      }
    });

    test('a split movement put right keeps its split, at the new amount', () {
      SharedExpense of(Map<String, int> shares) => SharedExpense(
        id: 'x',
        label: 'Crepes',
        date: DateTime(2026, 10, 3),
        paidBy: meId,
        shares: shares,
        entryId: 'entry',
      );
      // Even stays even, the payer carrying the rounding.
      expect(
        of(<String, int>{meId: 11750, 'ana': 11750}).resizedTo(30001).shares,
        <String, int>{meId: 15001, 'ana': 15000},
      );
      expect(
        of(<String, int>{
          meId: 7834,
          'ana': 7833,
          'juan': 7833,
        }).resizedTo(30000).shares,
        <String, int>{meId: 10000, 'ana': 10000, 'juan': 10000},
      );
      // By amounts, what Ana owes stays and the person's part moves.
      final SharedExpense uneven = of(<String, int>{meId: 8000, 'ana': 15500});
      expect(uneven.resizedTo(30000).shares, <String, int>{
        meId: 14500,
        'ana': 15500,
      });
      expect(uneven.resizedTo(30000).othersPart, 15500);
      // Less than Ana owed: shared in the same proportions.
      expect(uneven.resizedTo(10000).shares, <String, int>{
        meId: 3405,
        'ana': 6595,
      });
      for (final int total in <int>[1, 999, 10000, 23500, 30000, 123457]) {
        expect(uneven.resizedTo(total).amount, total);
        expect(
          of(<String, int>{meId: 1, 'ana': 1}).resizedTo(total).amount,
          total,
        );
      }
      final SharedExpense same = uneven.resizedTo(23500);
      expect(identical(same, uneven), isTrue);
      expect(uneven.resizedTo(30000).entryId, 'entry');
    });

    test('a group settles with the fewest payments', () {
      const List<Member> people = <Member>[
        Member(id: meId, name: ''),
        Member(id: 'ana', name: 'Ana'),
        Member(id: 'juan', name: 'Juan'),
      ];
      final Group trip = Group(
        id: 'g',
        name: 'Guatapé',
        members: people,
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'hotel',
            label: 'Hotel',
            date: today,
            paidBy: 'juan',
            shares: const <String, int>{
              meId: 200000,
              'ana': 200000,
              'juan': 200000,
            },
          ),
          SharedExpense(
            id: 'food',
            label: 'Almuerzo',
            date: today,
            paidBy: meId,
            shares: const <String, int>{
              meId: 30000,
              'ana': 30000,
              'juan': 30000,
            },
          ),
        ],
      );
      expect(trip.balances, <String, int>{
        meId: -140000,
        'ana': -230000,
        'juan': 370000,
      });
      final List<Transfer> plan = trip.plan;
      expect(plan, hasLength(2));
      expect(
        plan.map((Transfer t) => '${t.from}>${t.to}:${t.amount}'),
        <String>['ana>juan:230000', 'me>juan:140000'],
      );
      Group settled = trip;
      for (final Transfer t in plan) {
        settled = settled.withSettlement(
          Settlement(
            id: t.from,
            from: t.from,
            to: t.to,
            amount: t.amount,
            date: today,
          ),
        );
      }
      expect(settled.settled, isTrue);
      expect(Group.fromJson(settled.toJson())!.settled, isTrue);
    });
  });

  group('what others owe', () {
    test('only the person\'s part is spending, and owed money is not '
        'money to spend', () async {
      final Entry dinner = await store.addEntry(
        accountId: bank.id,
        amount: d('120000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 21),
        category: 'restaurants',
        payee: 'Cena',
      );
      final Ledger alone = await ledger();
      final Group dinnerGroup = Group(
        id: 'g',
        name: 'Cena',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'ana', name: 'Ana'),
          Member(id: 'juan', name: 'Juan'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'e',
            label: 'Cena',
            date: dinner.date,
            paidBy: meId,
            shares: const <String, int>{
              meId: 40000,
              'ana': 40000,
              'juan': 40000,
            },
            entryId: dinner.id,
          ),
        ],
      );
      final Ledger split = await ledger(groups: <Group>[dinnerGroup]);
      expect(alone.spentIn(2026, 10), 120000);
      expect(split.spentIn(2026, 10), 40000);
      // The money left all the same: nothing owed is counted as there.
      expect(split.balance, alone.balance);
      expect(split.freeUntilPayday, alone.freeUntilPayday);
    });

    test('a repayment lowers what is owed without becoming income', () async {
      final Entry dinner = await store.addEntry(
        accountId: bank.id,
        amount: d('120000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 1, 21),
        category: 'restaurants',
        payee: 'Cena',
      );
      final Entry back = await store.addEntry(
        accountId: bank.id,
        amount: d('40000'),
        kind: EntryKind.income,
        date: DateTime(2026, 10, 2, 9),
        category: 'other_income',
        payee: 'Ana te envió',
      );
      Group g = Group(
        id: 'g',
        name: 'Cena',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'ana', name: 'Ana'),
          Member(id: 'juan', name: 'Juan'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'e',
            label: 'Cena',
            date: dinner.date,
            paidBy: meId,
            shares: const <String, int>{
              meId: 40000,
              'ana': 40000,
              'juan': 40000,
            },
            entryId: dinner.id,
          ),
        ],
      );
      final Ledger before = await ledger(groups: <Group>[g]);
      expect(before.incomeIn(2026, 10), 40000);
      g = g.withSettlement(
        Settlement(
          id: 's',
          from: 'ana',
          to: meId,
          amount: 40000,
          date: back.date,
          entryId: back.id,
        ),
      );
      final Ledger after = await ledger(groups: <Group>[g]);
      expect(after.incomeIn(2026, 10), 0);
      expect(after.spentIn(2026, 10), 40000);
      expect(after.balance, before.balance);
      expect(g.balances, <String, int>{meId: 40000, 'ana': 0, 'juan': -40000});
    });
  });

  group('variable income', () {
    ExpectedIncome invoice(
      DateTime on, {
      IncomeStatus status = IncomeStatus.pending,
    }) => ExpectedIncome(
      id: 'i',
      client: 'Estudio Norte',
      amount: 1500000,
      expected: on,
      status: status,
    );

    test(
      'a payment late to come moves the projection, not the balance',
      () async {
        final Ledger on10 = await ledger(
          freelance: FreelancePlan(
            incomes: <ExpectedIncome>[invoice(DateTime(2026, 10, 10))],
          ),
        );
        final Ledger on20 = await ledger(
          freelance: FreelancePlan(
            incomes: <ExpectedIncome>[invoice(DateTime(2026, 10, 20))],
          ),
        );
        expect(on10.balance, on20.balance);
        expect(on10.freeUntilPayday, on20.freeUntilPayday);
        int likelyOn(Ledger l, int day) => Projection.of(l, horizon: 30).days
            .firstWhere((ProjectedDay x) => x.date == DateTime(2026, 10, day))
            .likely;
        expect(likelyOn(on10, 12) - likelyOn(on20, 12), 1500000);
        expect(likelyOn(on10, 25), likelyOn(on20, 25));
        // Never in what is sure.
        final ProjectedDay day12 = Projection.of(
          on10,
          horizon: 30,
        ).days.firstWhere((ProjectedDay x) => x.date == DateTime(2026, 10, 12));
        expect(day12.sure, on10.balance);
      },
    );

    test('what counts ahead is the person\'s choice, and late is tomorrow', () {
      final FreelancePlan plan = FreelancePlan(
        incomes: <ExpectedIncome>[
          invoice(DateTime(2026, 9, 28)),
          ExpectedIncome(
            id: 'e',
            client: 'Quizás',
            amount: 800000,
            expected: DateTime(2026, 10, 25),
            status: IncomeStatus.estimated,
          ),
        ],
      );
      expect(plan.incomes.first.overdue(today), isTrue);
      expect(plan.incomes.first.daysLate(today), 5);
      expect(plan.ahead(today).single.date, DateTime(2026, 10, 4));
      expect(
        plan.copyWith(scenario: IncomeScenario.collected).ahead(today),
        isEmpty,
      );
      expect(
        plan.copyWith(scenario: IncomeScenario.estimated).ahead(today),
        hasLength(2),
      );
    });

    test(
      'the reserve is the person\'s share, and leaves the free money',
      () async {
        final FreelancePlan plan = FreelancePlan(
          reservePercent: 15,
          used: <(DateTime, int)>[(today, 50000)],
        );
        expect(plan.reserve(2000000), 250000);
        expect(plan.reserve(100000), 0);
        final Ledger without = await ledger();
        final Ledger kept = await ledger(reserved: plan.reserve(2000000));
        expect(kept.freeUntilPayday, without.freeUntilPayday - 250000);
        expect(kept.balance, without.balance);
        expect(FreelancePlan.fromJson(plan.toJson()).reserve(2000000), 250000);
      },
    );
  });

  group('a trip', () {
    test('counts the same movements, converted with dated rates', () async {
      final Account card = await store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: d('0'),
      );
      final Account dollars = await store.addAccount(
        name: 'Global66',
        kind: AccountKind.bank,
        asset: Asset.usd,
        opening: d('500'),
      );
      final Entry flight = await store.addEntry(
        accountId: card.id,
        amount: d('1200000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 9, 1),
        category: 'transport',
        payee: 'Avianca',
      );
      final Entry museum = await store.addEntry(
        accountId: dollars.id,
        amount: d('25'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2),
        category: 'leisure',
        payee: 'MoMA',
      );
      final Entry dinner = await store.addEntry(
        accountId: card.id,
        amount: d('213740'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2),
        category: 'restaurants',
        payee: 'Joe\'s',
      );
      final Entry rent = await store.addEntry(
        accountId: bank.id,
        amount: d('900000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 1),
        category: 'housing',
        payee: 'Arriendo',
      );
      final RateTable rates = RateTable(<Rate>[
        Rate(
          asset: 'USD',
          quote: 'COP',
          value: d('4000'),
          asOf: DateTime(2026, 10, 2),
          source: 'trm',
        ),
      ]);
      final ForeignCharge charge = ForeignCharge(
        amount: d('50'),
        rate: d('4150.30'),
        rateOn: DateTime(2026, 10, 2),
        rateSource: 'trm',
        fee: 3,
      );
      // 50 dollars at 4.150,30 and 3 % more: 213.740,45.
      expect(charge.estimate(0), d('213740'));
      Trip trip = Trip(
        id: 't',
        name: 'Nueva York',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 7),
        currency: 'USD',
        budget: d('1000'),
        included: <String>{flight.id},
        excluded: <String>{rent.id},
        foreign: <String, ForeignCharge>{dinner.id: charge},
      );
      final Map<String, Asset> assets = <String, Asset>{
        card.id: Asset.cop,
        dollars.id: Asset.usd,
        bank.id: Asset.cop,
      };
      TripSummary of(Trip t, List<Entry> entries) => TripSummary.of(
        t,
        entries: entries,
        assetOf: (String id) => assets[id]!,
        rates: rates,
        today: today,
      );
      final List<Entry> entries = await store.entries();
      final TripSummary s = of(trip, entries);
      expect(
        s.lines.map((TripLine l) => l.entry.id),
        unorderedEquals(<String>[flight.id, museum.id, dinner.id]),
      );
      // The flight at the TRM, the museum as it is, the dinner as paid.
      expect(s.spent, d('300') + d('25') + d('50'));
      expect(s.left, d('625'));
      expect(s.perDay, d('125'));
      final TripLine flightLine = s.lines.firstWhere(
        (TripLine l) => l.entry.id == flight.id,
      );
      expect(flightLine.rates.single.source, 'trm');
      expect(flightLine.rates.single.asOf, DateTime(2026, 10, 2));

      // The bank's real charge replaces the estimate, and the difference
      // stays to see.
      await store.updateEntry(dinner.copyWith(amount: d('-214900')));
      trip = trip.copyWith(
        adjusted: <String, Decimal>{dinner.id: charge.estimate(0)},
      );
      final TripLine adjusted = of(
        trip,
        await store.entries(),
      ).lines.firstWhere((TripLine l) => l.entry.id == dinner.id);
      expect(adjusted.difference, d('1160'));
      expect(adjusted.local, d('50'));
      expect(await store.entries(), hasLength(entries.length));
      expect(Trip.fromJson(trip.toJson())!.adjusted[dinner.id], d('213740'));
    });
  });

  test('modules not used change nothing', () async {
    await store.addEntry(
      accountId: bank.id,
      amount: d('50000'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 2),
      category: 'groceries',
    );
    final Ledger plain = buildLedger(
      (await store.snapshot())!,
      today: today,
    ).ledger;
    final Ledger empty = await ledger();
    expect(empty.freeUntilPayday, plain.freeUntilPayday);
    expect(empty.spentIn(2026, 10), plain.spentIn(2026, 10));
    expect(empty.movements.length, plain.movements.length);
  });
}
