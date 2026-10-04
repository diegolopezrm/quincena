import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/inbox.dart';
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
  final DateTime today = DateTime(2026, 10, 1, 9);

  setUp(() async {
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => today,
    );
    await store.ensureCategories();
  });

  tearDown(() => store.close());

  test('the profile is absent until saved, and comes back as saved', () async {
    expect(await store.profile(), isNull);
    expect(await store.snapshot(), isNull);
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
    final Profile? p = await store.profile();
    expect(p!.name, 'Diego');
    expect(p.base, Asset.cop);
    expect(p.schedule, const TwiceMonthly());
  });

  test(
    'built-in categories are added once, and the person can add more',
    () async {
      await store.ensureCategories();
      final List<CategoryItem> all = await store.categories();
      expect(all.where((CategoryItem c) => c.key == 'groceries'), hasLength(1));
      expect(
        all.firstWhere((CategoryItem c) => c.key == 'salary').income,
        isTrue,
      );
      final CategoryItem pets = await store.addCategory('Mascotas');
      expect(pets.custom, isTrue);
      expect((await store.categories()).last.name, 'Mascotas');
    },
  );

  group('accounts and movements', () {
    test('a balance is the opening plus what moved up to today', () async {
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1000000'),
      );
      await store.addEntry(
        accountId: bank.id,
        amount: d('45900'),
        kind: EntryKind.expense,
        date: DateTime(2026, 9, 30),
        category: 'groceries',
        payee: 'Éxito',
      );
      await store.addEntry(
        accountId: bank.id,
        amount: d('2400000'),
        kind: EntryKind.income,
        date: DateTime(2026, 9, 30),
        category: 'salary',
      );
      // Scheduled for later: not in today's balance.
      await store.addEntry(
        accountId: bank.id,
        amount: d('1650000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 5),
        category: 'housing',
      );
      final Map<String, Money> balances = await store.watchBalances().first;
      expect(balances[bank.id], Money(d('3354100'), Asset.cop));
      final List<Entry> entries = await store.entries();
      expect(entries.first.date, DateTime(2026, 10, 5));
      expect(
        entries.firstWhere((Entry e) => e.payee == 'Éxito').amount,
        d('-45900'),
      );
    });

    test('an exchange account is not money to spend by default', () async {
      final Account binance = await store.addAccount(
        name: 'Binance',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: d('1520.50'),
      );
      expect(binance.spendable, isFalse);
      expect((await store.accounts()).single.opening, d('1520.50'));
    });

    test(
      'a transfer between currencies keeps what was sent and what arrived',
      () async {
        final Account dollars = await store.addAccount(
          name: 'Cuenta en dólares',
          kind: AccountKind.bank,
          asset: Asset.usd,
          opening: d('500'),
        );
        final Account pesos = await store.addAccount(
          name: 'Nequi',
          kind: AccountKind.wallet,
          asset: Asset.cop,
        );
        await store.addTransfer(
          fromAccountId: dollars.id,
          toAccountId: pesos.id,
          sent: d('100'),
          received: d('325000'),
          date: DateTime(2026, 9, 28),
        );
        final Map<String, Money> balances = await store.watchBalances().first;
        expect(balances[dollars.id], Money(d('400'), Asset.usd));
        expect(balances[pesos.id], Money(d('325000'), Asset.cop));

        // Deleting one leg deletes the transfer.
        final Entry leg = (await store.entries(accountId: pesos.id)).single;
        await store.deleteEntry(leg);
        expect(await store.entries(), isEmpty);
      },
    );

    test(
      'deleting an account leaves the other leg of its transfers as a movement',
      () async {
        final Account a = await store.addAccount(
          name: 'A',
          kind: AccountKind.cash,
          asset: Asset.cop,
        );
        final Account b = await store.addAccount(
          name: 'B',
          kind: AccountKind.cash,
          asset: Asset.cop,
        );
        await store.addTransfer(
          fromAccountId: a.id,
          toAccountId: b.id,
          sent: d('50000'),
          date: DateTime(2026, 9, 20),
        );
        await store.deleteAccount(a.id);
        final Entry left = (await store.entries()).single;
        expect(left.accountId, b.id);
        expect(left.kind, EntryKind.income);
        expect(left.transferId, isNull);
      },
    );
  });

  group('rates', () {
    final List<Rate> fetched = <Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: d('3312.84'),
        asOf: DateTime(2026, 10, 1),
        source: 'trm',
      ),
      Rate(
        asset: 'BTC',
        quote: 'USDT',
        value: d('84616.92'),
        asOf: DateTime(2026, 10, 1),
        source: 'binance',
      ),
    ];

    test('a fetched rate never replaces one the person typed', () async {
      await store.setManualRate('USD', 'COP', d('3400'));
      await store.saveRates(fetched);
      final RateTable table = RateTable(await store.rates());
      expect(table.rate(Asset.usd, Asset.cop), d('3400'));
      expect(table.rate(Asset.btc, Asset.usdt), d('84616.92'));

      await store.setManualRate('USD', 'COP', null);
      await store.saveRates(fetched);
      expect(
        RateTable(await store.rates()).rate(Asset.usd, Asset.cop),
        d('3312.84'),
      );
      expect(await store.ratesFetchedAt(), today);
    });

    test('restoring a typed rate puts the fetched one in its place', () async {
      await store.setManualRate('USD', 'COP', d('3400'));
      await store.restoreRate('USD', 'COP', fetched);
      final Rate usd = (await store.rates()).firstWhere(
        (Rate r) => r.pair == 'USD/COP',
      );
      expect(usd.manual, isFalse);
      expect(usd.source, 'trm');
      expect(usd.value, d('3312.84'));
      expect(
        RateTable(await store.rates()).rate(Asset.btc, Asset.usdt),
        d('84616.92'),
      );
    });
  });

  group('export, import, delete', () {
    Future<void> fill() async {
      await store.saveProfile(
        const Profile(name: 'Diego', base: Asset.cop, schedule: Monthly(30)),
      );
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('800000'),
      );
      final Account btc = await store.addAccount(
        name: 'Binance BTC',
        kind: AccountKind.exchange,
        asset: Asset.btc,
        opening: d('0.00123456'),
      );
      await store.addEntry(
        accountId: bank.id,
        amount: d('120000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 9, 15),
        category: 'restaurants',
      );
      await store.addEntry(
        accountId: btc.id,
        amount: d('0.0001'),
        kind: EntryKind.income,
        date: DateTime(2026, 9, 16),
        category: 'interest',
      );
      await store.addCategory('Mascotas');
      await store.setManualRate('USD', 'COP', d('3400'));
    }

    test(
      'what is exported comes back exactly, crypto decimals included',
      () async {
        await fill();
        final Map<String, Object?> file = await store.exportJson();
        final Map<String, Money> before = await store.watchBalances().first;

        await store.wipe();
        expect(await store.profile(), isNull);
        expect(await store.accounts(), isEmpty);

        await store.importJson(file);
        expect((await store.profile())!.schedule, const Monthly(30));
        expect(await store.watchBalances().first, before);
        final Account btc = (await store.accounts()).firstWhere(
          (Account a) => a.asset == Asset.btc,
        );
        expect(before[btc.id], Money(d('0.00133456'), Asset.btc));
        expect(
          (await store.categories())
              .where((CategoryItem c) => c.custom)
              .single
              .name,
          'Mascotas',
        );
        expect((await store.rates()).single.manual, isTrue);
      },
    );

    test('costs, learned rules and wallets travel in the file', () async {
      await fill();
      final Account btc = (await store.accounts()).firstWhere(
        (Account a) => a.asset == Asset.btc,
      );
      await store.updateAccount(
        btc.copyWith(openingCost: Money(d('300000'), Asset.cop)),
      );
      await store.addEntry(
        accountId: btc.id,
        amount: d('0.001'),
        kind: EntryKind.income,
        date: today,
        cost: Money(d('250'), Asset.usdt),
      );
      await store.saveCaptureSettings(
        const CaptureSettings(
          merchantCategories: <String, String>{'exito': 'groceries'},
        ),
      );
      await store.setSetting('wallets', '{"wallets":[]}');
      final Map<String, Object?> file =
          jsonDecode(jsonEncode(await store.exportJson()))
              as Map<String, Object?>;

      await store.wipe();
      await store.importJson(file);
      final Account back = (await store.accounts()).firstWhere(
        (Account a) => a.asset == Asset.btc,
      );
      expect(back.openingCost, Money(d('300000'), Asset.cop));
      expect(
        (await store.entries()).firstWhere((Entry e) => e.cost != null).cost,
        Money(d('250'), Asset.usdt),
      );
      expect(
        (await store.captureSettings()).merchantCategories['exito'],
        'groceries',
      );
      expect(await store.setting('wallets'), '{"wallets":[]}');
    });

    test('a card\'s limit travels in the file, and a file from before '
        'limits imports with none', () async {
      await fill();
      final Account visa = await store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: d('-300000'),
        creditLimit: d('2000000'),
      );
      expect(visa.creditLimit, d('2000000'));
      final Map<String, Object?> file =
          jsonDecode(jsonEncode(await store.exportJson()))
              as Map<String, Object?>;
      expect(file['version'], 3);

      await store.wipe();
      await store.importJson(file);
      Account back = (await store.accounts()).firstWhere(
        (Account a) => a.kind == AccountKind.card,
      );
      expect(back.creditLimit, d('2000000'));
      expect(back.opening, d('-300000'));

      // Taken away, it stays away.
      await store.updateAccount(back.copyWith(clearCreditLimit: true));
      expect(
        (await store.accounts())
            .firstWhere((Account a) => a.kind == AccountKind.card)
            .creditLimit,
        isNull,
      );

      // Version 2 had no limits.
      file['version'] = 2;
      for (final Object? a in file['accounts']! as List<Object?>) {
        (a! as Map<String, Object?>).remove('creditLimit');
      }
      await store.wipe();
      await store.importJson(file);
      back = (await store.accounts()).firstWhere(
        (Account a) => a.kind == AccountKind.card,
      );
      expect(back.creditLimit, isNull);
      expect(back.opening, d('-300000'));
    });

    test('a file written by version 1 still imports', () async {
      await fill();
      final Map<String, Object?> file =
          jsonDecode(jsonEncode(await store.exportJson()))
              as Map<String, Object?>;
      // Version 1 had no costs, no synced accounts and no settings.
      file['version'] = 1;
      file.remove('settings');
      for (final Object? a in file['accounts']! as List<Object?>) {
        (a! as Map<String, Object?>)
          ..remove('openingCost')
          ..remove('openingCostAsset')
          ..remove('syncRef');
      }
      for (final Object? e in file['entries']! as List<Object?>) {
        (e! as Map<String, Object?>)
          ..remove('cost')
          ..remove('costAsset');
      }
      await store.wipe();
      await store.importJson(file);
      expect(await store.accounts(), hasLength(2));
    });

    test('a file from somewhere else is refused and nothing changes', () async {
      await fill();
      Matcher refused(ImportProblem problem) => throwsA(
        isA<ImportException>().having(
          (ImportException e) => e.problem,
          'problem',
          problem,
        ),
      );
      await expectLater(
        store.importJson(<String, Object?>{'app': 'other', 'version': 1}),
        refused(ImportProblem.notQuincena),
      );
      await expectLater(
        store.importJson(<String, Object?>{'app': 'quincena', 'version': 99}),
        refused(ImportProblem.newer),
      );
      await expectLater(
        store.importJson(<String, Object?>{'app': 'quincena'}),
        refused(ImportProblem.damaged),
      );
      expect(await store.accounts(), hasLength(2));
    });

    test('a file that breaks halfway leaves everything as it was', () async {
      await fill();
      final Map<String, Money> before = await store.watchBalances().first;
      final Map<String, Object?> file = await store.exportJson();
      // The accounts read fine; a movement further down does not.
      (file['entries']! as List<Object?>).add(<String, Object?>{
        'id': 'broken',
        'amount': 'not a number',
      });

      await expectLater(
        store.importJson(file),
        throwsA(
          isA<ImportException>().having(
            (ImportException e) => e.problem,
            'problem',
            ImportProblem.damaged,
          ),
        ),
      );
      expect(await store.profile(), isNotNull);
      expect(await store.accounts(), hasLength(2));
      expect(await store.watchBalances().first, before);
    });
  });
}
