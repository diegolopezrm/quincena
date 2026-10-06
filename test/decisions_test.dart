import 'dart:math' as math;

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

    test('what envelopes and the reserve keep apart is not there to buy '
        'with', () async {
      // 900.000, less internet's 300.000, the cushion's 100.000, 100.000
      // in envelopes and a reserve of 150.000: 250.000 to spend.
      final Ledger l = buildLedger(
        (await store.snapshot())!,
        today: today,
        setAside: 100000,
        reserved: 150000,
      ).ledger;
      expect(l.freeUntilPayday, 250000);
      PurchaseCheck buy(int price) =>
          checkPurchase(l, price: price, date: today);

      final PurchaseCheck fits = buy(250000);
      expect(fits.verdict, PurchaseVerdict.fits);
      expect(fits.usesSetAside + fits.usesReserve + fits.usesCushion, 0);

      // 50.000 over what there is to spend: from the envelopes first.
      final PurchaseCheck over = buy(300000);
      expect(over.lowest, 300000);
      expect(over.verdict, PurchaseVerdict.takesApart);
      expect(over.usesSetAside, 50000);
      expect(over.usesReserve, 0);
      expect(over.usesCushion, 0);

      // All of the envelopes and part of the reserve.
      final PurchaseCheck more = buy(400000);
      expect(more.verdict, PurchaseVerdict.takesApart);
      expect(more.usesSetAside, 100000);
      expect(more.usesReserve, 50000);

      // Under the cushion, it has taken everything above it.
      final PurchaseCheck under = buy(550000);
      expect(under.verdict, PurchaseVerdict.belowCushion);
      expect(under.usesSetAside, 100000);
      expect(under.usesReserve, 150000);
      expect(under.usesCushion, 50000);

      expect(buy(700000).verdict, PurchaseVerdict.short);
    });

    test('a purchase fits only within what there is to spend', () async {
      final Ledger l = buildLedger(
        (await store.snapshot())!,
        today: today,
        setAside: 40000,
        reserved: 150000,
      ).ledger;
      for (var price = 10000; price <= 800000; price += 10000) {
        final PurchaseCheck c = checkPurchase(l, price: price, date: today);
        expect(
          c.verdict == PurchaseVerdict.fits,
          price <= l.freeUntilPayday,
          reason: '$price against ${l.freeUntilPayday}',
        );
        // What it takes from what is kept apart is what it goes over by.
        expect(
          c.usesSetAside + c.usesReserve + c.usesCushion,
          math.min(
            math.max(0, price - l.freeUntilPayday),
            l.cushion + l.setAside + l.reserved,
          ),
          reason: '$price',
        );
      }
    });

    test('with nothing left to spend, a purchase takes from what is kept '
        'apart only its own price', () async {
      // 900.000, less internet's 300.000, the cushion's 100.000, 300.000 in
      // envelopes and a reserve of 550.000: 350.000 short of anything to
      // spend before buying a thing, and already into the reserve.
      final Ledger l = buildLedger(
        (await store.snapshot())!,
        today: today,
        setAside: 300000,
        reserved: 550000,
      ).ledger;
      expect(l.freeUntilPayday, -350000);

      // 10.000 takes 10.000 of the reserve, not the 360.000 it would then
      // be short of.
      final PurchaseCheck small = checkPurchase(l, price: 10000, date: today);
      expect(small.verdict, PurchaseVerdict.takesApart);
      expect(small.usesSetAside, 0);
      expect(small.usesReserve, 10000);
      expect(small.usesCushion, 0);

      // Down to zero: the rest of the reserve and the whole cushion.
      final PurchaseCheck big = checkPurchase(l, price: 600000, date: today);
      expect(big.verdict, PurchaseVerdict.belowCushion);
      expect(big.usesReserve, 500000);
      expect(big.usesCushion, 100000);

      // Past zero, what it takes is what there was; the rest is short.
      final PurchaseCheck short = checkPurchase(l, price: 700000, date: today);
      expect(short.verdict, PurchaseVerdict.short);
      expect(short.lowest, -100000);
      expect(
        short.usesSetAside + short.usesReserve + short.usesCushion,
        600000,
      );
    });

    test('bought on payday, it counts on the pay of that day, as the day '
        'after does', () async {
      await profile(pay: '1000000', cushion: '100000');
      await store.addRecurring(
        name: 'Arriendo',
        amount: Money(d('800000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 20),
        accountId: bank.id,
        category: 'housing',
      );
      final Ledger l = await ledger();
      final PurchaseCheck before = checkPurchase(
        l,
        price: 100000,
        date: DateTime(2026, 10, 14),
      );
      expect(before.verdict, PurchaseVerdict.fits);
      expect(before.reliesOnPay, isFalse);
      final PurchaseCheck on = checkPurchase(
        l,
        price: 100000,
        date: DateTime(2026, 10, 15),
      );
      final PurchaseCheck after = checkPurchase(
        l,
        price: 100000,
        date: DateTime(2026, 10, 16),
      );
      // 900.000 - 300.000 + 1.000.000 on the 15th - 100.000 - 800.000 on
      // the 20th: not the whole fortnight after without the pay.
      expect(on.until, DateTime(2026, 10, 30));
      expect(on.reliesOnPay, isTrue);
      expect(on.lowest, 700000);
      expect(on.lowestOn, DateTime(2026, 10, 20));
      expect(on.verdict, PurchaseVerdict.fits);
      expect(on.lowest, after.lowest);
    });

    test('after a pay that came early, it counts on no pay that is still to '
        'come', () async {
      await profile(pay: '1000000', cushion: '100000');
      // The 15th of November is a Sunday: the pay came on Friday the 13th.
      await store.addEntry(
        accountId: bank.id,
        amount: d('1000000'),
        kind: EntryKind.income,
        date: DateTime(2026, 11, 13, 8),
        category: 'salary',
      );
      final Ledger l = buildLedger(
        (await store.snapshot())!,
        today: DateTime(2026, 11, 13),
      ).ledger;
      final PurchaseCheck c = checkPurchase(
        l,
        price: 500000,
        date: DateTime(2026, 11, 16),
      );
      // 900.000 and the pay, less 500.000: the pay is not counted a second
      // time on the 15th.
      expect(l.balance, 1900000);
      // Still after payday: what can be spent until it is not the measure.
      expect(c.afterPay, isTrue);
      expect(c.reliesOnPay, isFalse);
      expect(c.payUnknown, isFalse);
      expect(c.lowest, 1400000);
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

    test('a category that fell to nothing keeps the payments it had', () async {
      await spend('300000', DateTime(2026, 8, 30, 12), 'groceries');
      await spend('900000', DateTime(2026, 9, 5, 12), 'housing');
      await spend('290000', DateTime(2026, 9, 16, 12), 'groceries');
      final Ledger l = await ledger();
      final PeriodClose close = (closePeriod(l))!;
      expect(close.startBefore, DateTime(2026, 8, 30));
      expect(close.changes.first.category, Category.housing);
      expect(close.changes.first.now, 0);
      expect(close.movementsOf(l, Category.housing), isEmpty);
      expect(
        <int>[
          for (final Movement m in close.movementsBefore(l, Category.housing))
            m.amount,
        ],
        <int>[900000],
      );
    });

    test('the first whole period has no period before to show', () async {
      await spend('80000', DateTime(2026, 9, 15, 12), 'groceries');
      final Ledger l = await ledger();
      final PeriodClose close = (closePeriod(l))!;
      expect(close.startBefore, isNull);
      expect(close.movementsBefore(l, Category.groceries), isEmpty);
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
