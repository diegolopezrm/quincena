import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/decisions.dart';
import 'package:quincena/domain/ledger_builder.dart';
import 'package:quincena/domain/pay_schedule.dart';
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
      opening: d('900000'),
    );
  });

  tearDown(() => store.close());

  Future<Ledger> ledger() async =>
      buildLedger((await store.snapshot())!, today: today).ledger;

  Future<void> spend(String amount, DateTime on, String category) =>
      store.addEntry(
        accountId: bank.id,
        amount: d(amount),
        kind: EntryKind.expense,
        date: on,
        category: category,
        payee: category,
      );

  group('can I buy it', () {
    setUp(() async {
      await profile(cushion: '100000');
      await store.addRecurring(
        name: 'Internet',
        amount: Money(d('300000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 10),
        accountId: bank.id,
        category: 'utilities',
      );
    });

    test('today, the lowest point before payday decides', () async {
      final Ledger l = await ledger();
      PurchaseCheck today_(int price) =>
          checkPurchase(l, price: price, date: today);
      // 900.000 - 350.000 today - 300.000 on the 10th.
      final PurchaseCheck fits = today_(350000);
      expect(fits.lowest, 250000);
      expect(fits.lowestOn, DateTime(2026, 10, 10));
      expect(fits.until, DateTime(2026, 10, 15));
      expect(fits.verdict, PurchaseVerdict.fits);
      expect(today_(550000).verdict, PurchaseVerdict.belowCushion);
      expect(today_(700000).verdict, PurchaseVerdict.short);
      expect(today_(700000).lowest, -100000);
    });

    test('after payday it counts on the pay, said as such', () async {
      await profile(pay: '1000000', cushion: '100000');
      // The pay on the 30th of September arrived.
      await store.addEntry(
        accountId: bank.id,
        amount: d('1000000'),
        kind: EntryKind.income,
        date: DateTime(2026, 9, 30, 8),
        category: 'salary',
      );
      await spend('1000000', DateTime(2026, 10, 1, 9), 'debt');
      final PurchaseCheck after = checkPurchase(
        await ledger(),
        price: 700000,
        date: DateTime(2026, 10, 16),
      );
      expect(after.reliesOnPay, isTrue);
      expect(after.payUnknown, isFalse);
      // 900.000 - 300.000 + 1.000.000 on the 15th - 700.000 on the 16th.
      expect(after.lowest, 900000);
      expect(after.verdict, PurchaseVerdict.fits);
      // The same purchase today does not fit.
      expect(
        checkPurchase(await ledger(), price: 700000, date: today).verdict,
        PurchaseVerdict.short,
      );
    });

    test('after payday, without the pay known, counts none', () async {
      final PurchaseCheck after = checkPurchase(
        await ledger(),
        price: 700000,
        date: DateTime(2026, 10, 16),
      );
      expect(after.payUnknown, isTrue);
      expect(after.reliesOnPay, isFalse);
      expect(after.verdict, PurchaseVerdict.short);
    });

    test('the calendar sees the purchase the check weighed', () async {
      final PurchaseCheck check = checkPurchase(
        await ledger(),
        price: 200000,
        date: DateTime(2026, 10, 5),
        label: 'Audífonos',
      );
      final ProjectedDay fifth = check.projection.days.firstWhere(
        (ProjectedDay x) => x.date == DateTime(2026, 10, 5),
      );
      expect(fifth.events.single.label, 'Audífonos');
      expect(fifth.likely, 700000);
      expect(fifth.sure, 900000);
    });
  });

  group('the close of the fortnight', () {
    test('without a whole period recorded there is none', () async {
      expect(closePeriod(await ledger()), isNull);
      // Recorded from the 20th of September: the 15-30 period is not whole.
      await spend('50000', DateTime(2026, 9, 20, 12), 'groceries');
      expect(closePeriod(await ledger()), isNull);
    });

    test('the first whole period is told without comparing', () async {
      await spend('80000', DateTime(2026, 9, 15, 12), 'groceries');
      await spend('120000', DateTime(2026, 9, 20, 12), 'restaurants');
      final PeriodClose close = (closePeriod(await ledger()))!;
      expect(close.start, DateTime(2026, 9, 15));
      expect(close.end, DateTime(2026, 9, 30));
      expect(close.spent, 200000);
      expect(close.spentBefore, isNull);
      expect(close.changes.first.category, Category.restaurants);
      expect(close.changes.first.before, isNull);
      expect(close.action, isNot(CloseAction.lookAtCategory));
    });

    test('a category that grew is pointed at, with its payments', () async {
      // August 30 to September 14, then September 15 to 29.
      await spend('300000', DateTime(2026, 8, 30, 12), 'groceries');
      await spend('100000', DateTime(2026, 9, 5, 12), 'restaurants');
      await spend('290000', DateTime(2026, 9, 16, 12), 'groceries');
      await spend('110000', DateTime(2026, 9, 18, 12), 'restaurants');
      await spend('90000', DateTime(2026, 9, 25, 12), 'restaurants');
      final Ledger l = await ledger();
      final PeriodClose close = (closePeriod(l))!;
      expect(close.spent, 490000);
      expect(close.spentBefore, 400000);
      expect(close.changes.first.category, Category.restaurants);
      expect(close.changes.first.difference, 100000);
      expect(close.action, CloseAction.lookAtCategory);
      expect(close.actionCategory, Category.restaurants);
      expect(
        <int>[
          for (final Movement m in close.movementsOf(l, Category.restaurants))
            m.amount,
        ],
        <int>[110000, 90000],
      );
    });

    test('a tight day ahead comes before anything else', () async {
      await profile(cushion: '600000');
      await spend('80000', DateTime(2026, 9, 15, 12), 'groceries');
      await store.addRecurring(
        name: 'Arriendo',
        amount: Money(d('400000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 8),
        accountId: bank.id,
        category: 'housing',
      );
      final PeriodClose close = (closePeriod(await ledger()))!;
      expect(close.action, CloseAction.tightDay);
      expect(close.tightDay, DateTime(2026, 10, 8));
      expect(close.coming.single.merchant, 'Arriendo');
    });
  });
}
