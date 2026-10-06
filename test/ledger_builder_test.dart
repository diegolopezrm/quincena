import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/ledger_builder.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  late QuincenaStore store;
  final DateTime today = DateTime(2026, 10, 3);

  setUp(() async {
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => today,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
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

  Future<Ledger> ledger() async =>
      buildLedger((await store.snapshot())!, today: today).ledger;

  test(
    'pesos and dollars to spend add up in pesos; tether on an exchange does not',
    () async {
      final Account pesos = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1000000'),
      );
      final Account dollars = await store.addAccount(
        name: 'Dólares',
        kind: AccountKind.bank,
        asset: Asset.usd,
        opening: d('250'),
      );
      await store.addAccount(
        name: 'Binance',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: d('1520.5'),
      );
      await store.addEntry(
        accountId: dollars.id,
        amount: d('10.50'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2),
        category: 'subscriptions',
        payee: 'Spotify',
      );

      final Ledger l = await ledger();
      // 1.000.000 + (250 - 10,50) × 4.000
      expect(l.balance, 1000000 + 958000);
      expect(l.spentIn(2026, 10), 42000);
      expect(l.currency, Asset.cop);
      expect(pesos.spendable && dollars.spendable, isTrue);
    },
  );

  test(
    'a transfer into savings leaves the money to spend without being spending',
    () async {
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('2000000'),
      );
      final Account savings = await store.addAccount(
        name: 'Ahorros',
        kind: AccountKind.investment,
        asset: Asset.cop,
      );
      final Account cash = await store.addAccount(
        name: 'Efectivo',
        kind: AccountKind.cash,
        asset: Asset.cop,
      );
      await store.addTransfer(
        fromAccountId: bank.id,
        toAccountId: savings.id,
        sent: d('300000'),
        date: DateTime(2026, 10, 1),
      );
      // Between two accounts to spend from: nothing changes.
      await store.addTransfer(
        fromAccountId: bank.id,
        toAccountId: cash.id,
        sent: d('100000'),
        date: DateTime(2026, 10, 2),
      );

      final Ledger l = await ledger();
      expect(l.balance, 1700000);
      expect(l.spentIn(2026, 10), 0);
      expect(l.incomeIn(2026, 10), 0);
      expect(l.movements.single.flow, Flow.saving);
    },
  );

  test(
    'what is already committed before payday counts scheduled movements and recurring charges',
    () async {
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('3000000'),
      );
      await store.addEntry(
        accountId: bank.id,
        amount: d('1650000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 5),
        category: 'housing',
        payee: 'Arriendo',
      );
      await store.addRecurring(
        name: 'Netflix',
        amount: Money(d('26900'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 12),
        accountId: bank.id,
        category: 'subscriptions',
      );
      // After payday: not committed yet.
      await store.addRecurring(
        name: 'Gimnasio',
        amount: Money(d('119000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 20),
        category: 'health',
      );

      final Ledger l = await ledger();
      expect(l.nextPayday, DateTime(2026, 10, 15));
      expect(l.committedUntilPayday, 1650000 + 26900);
      expect(l.freeUntilPayday, 3000000 - 1650000 - 26900);
      expect(l.subscriptions.single.name, 'Netflix');
      expect(l.subscriptions.single.lastUsed, isNull);
    },
  );

  test('a base currency with cents keeps them', () async {
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.usd, schedule: Monthly(30)),
    );
    await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('1000000'),
    );
    final Ledger l = await ledger();
    expect(l.currency, Asset.usd);
    expect(l.balance, 25000); // 250,00 dollars, in cents
    expect(l.major(l.balance), 250);
  });

  test('a movement later today is today\'s, not a scheduled one', () async {
    final Account bank = await store.addAccount(
      name: 'Nequi',
      kind: AccountKind.wallet,
      asset: Asset.cop,
      opening: d('100000'),
    );
    await store.addEntry(
      accountId: bank.id,
      amount: d('23500'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 3, 18, 30),
      category: 'restaurants',
    );
    final Ledger l = await ledger();
    expect(l.balance, 76500);
    expect(l.committedUntilPayday, 0);
    expect(l.spentIn(2026, 10), 23500);
  });

  test('an asset with no rate is counted as zero and named', () async {
    await store.addAccount(
      name: 'Billetera',
      kind: AccountKind.wallet,
      asset: Asset.eur,
      opening: d('100'),
    );
    final LedgerBuild built = buildLedger(
      (await store.snapshot())!,
      today: today,
    );
    expect(built.ledger.balance, 0);
    expect(built.unconverted, <Asset>{Asset.eur});
  });
  test('the free amount comes apart into parts that add up exactly', () async {
    final Account pesos = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('1000000'),
    );
    final Account dollars = await store.addAccount(
      name: 'Dólares',
      kind: AccountKind.bank,
      asset: Asset.usd,
      opening: d('250'),
    );
    final Account savings = await store.addAccount(
      name: 'Ahorro',
      kind: AccountKind.investment,
      asset: Asset.cop,
      opening: d('0'),
      spendable: false,
    );
    await store.addEntry(
      accountId: pesos.id,
      amount: d('2400000'),
      kind: EntryKind.income,
      date: DateTime(2026, 9, 30),
      category: 'salary',
      payee: 'Nómina',
    );
    await store.addEntry(
      accountId: dollars.id,
      amount: d('10.50'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 2),
      category: 'subscriptions',
      payee: 'Spotify',
    );
    await store.addTransfer(
      fromAccountId: pesos.id,
      toAccountId: savings.id,
      sent: d('200000'),
      date: DateTime(2026, 10, 1),
    );
    // Entered ahead of its day: committed, not spent yet.
    await store.addEntry(
      accountId: pesos.id,
      amount: d('1650000'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 10),
      category: 'housing',
      payee: 'Arriendo',
    );
    await store.addRecurring(
      name: 'Netflix',
      amount: Money(d('26900'), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 12),
      accountId: pesos.id,
      category: 'subscriptions',
    );
    await store.addRecurring(
      name: 'iCloud',
      amount: Money(d('5'), Asset.usd),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 8),
      accountId: dollars.id,
      category: 'subscriptions',
    );

    final LedgerBuild built = buildLedger(
      (await store.snapshot())!,
      today: today,
    );
    final Ledger l = built.ledger;
    // 1.000.000 + 2.400.000 - 200.000, and (250 - 10,50) × 4.000.
    expect(built.parts, <String, int>{pesos.id: 3200000, dollars.id: 958000});
    expect(built.parts.values.fold(0, (int sum, int v) => sum + v), l.balance);
    expect(
      <String>[for (final Movement m in l.committed) m.merchant],
      <String>['iCloud', 'Arriendo', 'Netflix'],
    );
    expect(l.committedUntilPayday, 20000 + 1650000 + 26900);
    expect(l.freeUntilPayday, 4158000 - 1696900);
  });

  test(
    'paying a card from the bank moves their parts, not the total',
    () async {
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1000000'),
      );
      final Account card = await store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: d('-300000'),
      );
      final Account nequi = await store.addAccount(
        name: 'Nequi',
        kind: AccountKind.wallet,
        asset: Asset.cop,
        opening: d('0'),
      );
      await store.addTransfer(
        fromAccountId: bank.id,
        toAccountId: card.id,
        sent: d('300000'),
        date: DateTime(2026, 10, 2),
      );
      // A top-up dated ahead has not moved anything yet.
      await store.addTransfer(
        fromAccountId: bank.id,
        toAccountId: nequi.id,
        sent: d('50000'),
        date: DateTime(2026, 10, 10),
      );

      final LedgerBuild built = buildLedger(
        (await store.snapshot())!,
        today: today,
      );
      expect(built.parts, <String, int>{
        bank.id: 700000,
        card.id: 0,
        nequi.id: 0,
      });
      expect(
        built.parts.values.fold(0, (int sum, int v) => sum + v),
        built.ledger.balance,
      );
    },
  );

  test('a charge whose card was deleted is still to be paid', () async {
    await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('1000000'),
    );
    final Account card = await store.addAccount(
      name: 'Visa',
      kind: AccountKind.card,
      asset: Asset.cop,
    );
    final Account kept = await store.addAccount(
      name: 'Ahorros',
      kind: AccountKind.bank,
      asset: Asset.cop,
      spendable: false,
    );
    await store.addRecurring(
      name: 'Netflix',
      amount: Money(d('26900'), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 12),
      accountId: card.id,
    );
    await store.addRecurring(
      name: 'Seguro',
      amount: Money(d('50000'), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 10),
      accountId: kept.id,
    );
    expect((await ledger()).committedUntilPayday, 26900);

    await store.deleteAccount(card.id);
    // Netflix still comes before payday; what is paid from savings, not.
    expect((await ledger()).committedUntilPayday, 26900);
    expect((await ledger()).freeUntilPayday, 1000000 - 26900);
  });

  test('a card paid in part from the bank keeps what is still owed', () async {
    final Account bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('1000000'),
    );
    final Account visa = await store.addAccount(
      name: 'Visa',
      kind: AccountKind.card,
      asset: Asset.cop,
      opening: d('-480000'),
    );
    await store.addTransfer(
      fromAccountId: bank.id,
      toAccountId: visa.id,
      sent: d('300000'),
      date: DateTime(2026, 10, 2),
    );
    // One still to come moves nothing yet.
    await store.addTransfer(
      fromAccountId: bank.id,
      toAccountId: visa.id,
      sent: d('100000'),
      date: DateTime(2026, 10, 9),
    );

    final LedgerBuild built = buildLedger(
      (await store.snapshot())!,
      today: today,
    );
    expect(built.parts, <String, int>{bank.id: 700000, visa.id: -180000});
    expect(
      built.parts.values.fold(0, (int sum, int v) => sum + v),
      built.ledger.balance,
    );
  });

  test('a subscription says when it is charged next, by its cadence', () async {
    await store.addRecurring(
      name: 'Dominio',
      amount: Money(d('60000'), Asset.cop),
      cadence: Cadence.yearly,
      nextDate: DateTime(2027, 3, 14),
      category: 'subscriptions',
    );
    await store.addRecurring(
      name: 'Prensa',
      amount: Money(d('9900'), Asset.cop),
      cadence: Cadence.weekly,
      nextDate: DateTime(2026, 9, 28),
      category: 'subscriptions',
    );

    final Map<String, DateTime> next = <String, DateTime>{
      for (final Subscription s in (await ledger()).subscriptions)
        s.name: s.nextCharge(today),
    };
    // Not the 14th of this month: a yearly charge comes once a year.
    expect(next['Dominio'], DateTime(2027, 3, 14));
    // A week after the last one, not a month.
    expect(next['Prensa'], DateTime(2026, 10, 5));
  });
}
