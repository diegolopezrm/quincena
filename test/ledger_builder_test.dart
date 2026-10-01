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
}
