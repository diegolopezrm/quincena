import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/ledger_builder.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/projection.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  late QuincenaStore store;
  // Paid on the 15th and the 30th; today is the 3rd.
  final DateTime today = DateTime(2026, 10, 3);
  // When the store writes things down: today unless a test says.
  late DateTime clock;

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
    clock = today;
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => clock,
    );
    await store.ensureCategories();
    await profile();
    await store.saveRates(<Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: d('4000'),
        asOf: today,
        source: 'trm',
      ),
    ]);
  });

  tearDown(() => store.close());

  Future<LedgerBuild> build({DateTime? on}) async =>
      buildLedger((await store.snapshot())!, today: on ?? today);

  Future<Account> bank(String opening) => store.addAccount(
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: d(opening),
  );

  test('with no history the projection is flat at zero', () async {
    final Projection p = Projection.of((await build()).ledger);
    expect(p.start, 0);
    expect(p.days, hasLength(46));
    expect(
      p.days.every((ProjectedDay d) => d.sure == 0 && d.likely == 0),
      isTrue,
    );
    expect(p.firstTight, isNull);
    expect(p.latePay, isNull);
  });

  test('scheduled charges count as sure; the pay only as expected', () async {
    final Account b = await bank('500000');
    await profile(pay: '2400000');
    // September's last pay arrived, and went to the card.
    await store.addEntry(
      accountId: b.id,
      amount: d('2400000'),
      kind: EntryKind.income,
      date: DateTime(2026, 9, 30, 8),
      category: 'salary',
      payee: 'Nómina',
    );
    await store.addEntry(
      accountId: b.id,
      amount: d('2400000'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 1, 9),
      category: 'debt',
      payee: 'Tarjeta',
    );
    await store.addRecurring(
      name: 'Arriendo',
      amount: Money(d('1650000'), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 20),
      accountId: b.id,
      category: 'housing',
    );
    final Projection p = Projection.of((await build()).ledger);
    expect(p.latePay, isNull);

    ProjectedDay on(int month, int day) => p.days.firstWhere(
      (ProjectedDay x) => x.date == DateTime(2026, month, day),
    );
    // The 15th: the pay is expected, nothing sure changes.
    expect(on(10, 15).sure, 500000);
    expect(on(10, 15).likely, 2900000);
    // The 20th: the rent, past payday, is in the projection but not committed.
    expect(on(10, 20).sure, 500000 - 1650000);
    expect(on(10, 20).likely, 2900000 - 1650000);
    expect(p.ledger.committedUntilPayday, 0);
    // Without the pay, the money runs out on the 20th.
    expect(p.firstTight!.date, DateTime(2026, 10, 20));
    // November's rent and pays are there too, within 45 days.
    expect(on(11, 15).likely, 2900000 - 1650000 + 2400000 + 2400000);
    expect(on(11, 15).sure, 500000 - 1650000);
  });

  test(
    'dollar charges convert at the rate; a missing rate counts as zero',
    () async {
      final Account b = await bank('100000');
      final Account usd = await store.addAccount(
        name: 'Dólares',
        kind: AccountKind.bank,
        asset: Asset.usd,
        opening: d('100'),
      );
      await store.addAccount(
        name: 'Euros',
        kind: AccountKind.bank,
        asset: Asset.eur,
        opening: d('50'),
      );
      await store.addRecurring(
        name: 'iCloud',
        amount: Money(d('2.99'), Asset.usd),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 8),
        accountId: usd.id,
        category: 'subscriptions',
      );
      final LedgerBuild built = await build();
      final Projection p = Projection.of(built.ledger);
      // 100.000 pesos and 100 dollars at 4.000; the euros have no rate.
      expect(p.start, 100000 + 400000);
      expect(built.unconverted, <Asset>{Asset.eur});
      // 2,99 × 4.000 = 11.960, rounded to the peso.
      final ProjectedDay eighth = p.days.firstWhere(
        (ProjectedDay x) => x.date == DateTime(2026, 10, 8),
      );
      expect(eighth.sure, 500000 - 11960);
      expect(eighth.events.single.label, 'iCloud');
      expect(b.asset, Asset.cop);
    },
  );

  test(
    'a transfer to savings entered ahead leaves the money to spend',
    () async {
      final Account b = await bank('900000');
      final Account savings = await store.addAccount(
        name: 'Ahorro',
        kind: AccountKind.investment,
        asset: Asset.cop,
        opening: d('0'),
        spendable: false,
      );
      await store.addTransfer(
        fromAccountId: b.id,
        toAccountId: savings.id,
        sent: d('300000'),
        date: DateTime(2026, 10, 10),
      );
      final Projection p = Projection.of((await build()).ledger);
      expect(p.start, 900000);
      expect(
        p.days
            .firstWhere((ProjectedDay x) => x.date == DateTime(2026, 10, 10))
            .sure,
        600000,
      );
      // Committed before payday, so it is not free either.
      expect(p.ledger.freeUntilPayday, 600000);
    },
  );

  test('a pay that did not arrive is late, and expected tomorrow', () async {
    // Written down on the 20th, before the payday.
    clock = DateTime(2026, 9, 20);
    await bank('50000');
    clock = today;
    await profile(pay: '2400000');
    // Paid on the 30th of September; it is the 3rd and nothing came in.
    final Projection late = Projection.of((await build()).ledger);
    expect(late.latePay, DateTime(2026, 9, 30));
    final ProjectedDay tomorrow = late.days[1];
    expect(tomorrow.events.single.kind, ProjectedKind.latePay);
    expect(tomorrow.likely, 50000 + 2400000);
    expect(tomorrow.sure, 50000);

    // Once it arrives, it is not late any more.
    final Account b = (await store.accounts()).single;
    await store.addEntry(
      accountId: b.id,
      amount: d('2350000'),
      kind: EntryKind.income,
      date: DateTime(2026, 10, 1, 9),
      category: 'salary',
      payee: 'Nómina',
    );
    final Projection paid = Projection.of((await build()).ledger);
    expect(paid.latePay, isNull);
  });

  test('a payday before the balances were written down is not late: the '
      'pay was already in them', () async {
    // Set up on the 3rd, three days after the 30th, with no income since.
    await bank('2450000');
    await profile(pay: '2400000');
    final Projection p = Projection.of((await build()).ledger);
    expect(p.latePay, isNull);
    expect(
      p.days.expand((ProjectedDay d) => d.events).map((e) => e.kind),
      isNot(contains(ProjectedKind.latePay)),
    );

    // The next payday is counted as ever, and it can be late in its turn.
    final Projection later = Projection.of(
      (await build(on: DateTime(2026, 10, 17))).ledger,
    );
    expect(later.latePay, DateTime(2026, 10, 15));
  });
  test(
    'the cushion is left out of the free amount and marks tight days',
    () async {
      final Account b = await bank('400000');
      await profile(cushion: '150000');
      await store.addRecurring(
        name: 'Internet',
        amount: Money(d('120000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 9),
        accountId: b.id,
        category: 'utilities',
      );
      await store.addRecurring(
        name: 'Gimnasio',
        amount: Money(d('150000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 11),
        accountId: b.id,
        category: 'health',
      );
      final Ledger l = (await build()).ledger;
      // 400.000 - (120.000 + 150.000) - 150.000 of cushion.
      expect(l.cushion, 150000);
      expect(l.freeUntilPayday, -20000);
      final Projection p = Projection.of(l);
      expect(p.firstTight!.date, DateTime(2026, 10, 11));
      expect(p.lowestBeforePayday.sure, 130000);
    },
  );

  test(
    'something tried out moves the likely balance, never the sure one',
    () async {
      await bank('300000');
      final Projection p = Projection.of(
        (await build()).ledger,
        tryOut: <ProjectedEvent>[
          ProjectedEvent(
            date: DateTime(2026, 10, 5),
            amount: -250000,
            certainty: Certainty.hypothetical,
            kind: ProjectedKind.tryOut,
            label: 'Audífonos',
          ),
        ],
      );
      final ProjectedDay fifth = p.days.firstWhere(
        (ProjectedDay x) => x.date == DateTime(2026, 10, 5),
      );
      expect(fifth.likely, 50000);
      expect(fifth.sure, 300000);
    },
  );
}
