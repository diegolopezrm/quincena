import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/account_trace.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/balance_explained.dart';
import 'package:quincena/ui/own/look.dart';

import 'own_flow_test.dart' show settle;

Decimal d(String s) => Decimal.parse(s);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);
  late QuincenaStore store;
  late Account bank;
  late Account dollars;
  late Account bitcoin;

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  Future<void> fill() async {
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
    );
    await store.saveRates(<Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: d('3312.84'),
        asOf: DateTime(2026, 10, 3),
        source: 'trm',
      ),
    ]);
    bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('820000'),
    );
    dollars = await store.addAccount(
      name: 'Dólares',
      kind: AccountKind.bank,
      asset: Asset.usd,
      opening: d('1250.75'),
      spendable: false,
    );
    // No BTC rate: it cannot be added to the total.
    bitcoin = await store.addAccount(
      name: 'Bitcoin',
      kind: AccountKind.wallet,
      asset: Asset.btc,
      opening: d('0.0042'),
      spendable: false,
    );
    await store.addEntry(
      accountId: bank.id,
      amount: d('2400000'),
      kind: EntryKind.income,
      date: DateTime(2026, 9, 30, 8),
      category: 'salary',
    );
    for (final (String amount, int day) in <(String, int)>[
      ('187400', 2),
      ('15600', 1),
    ]) {
      await store.addEntry(
        accountId: bank.id,
        amount: d(amount),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, day, 12),
        category: 'groceries',
      );
    }
    await store.addTransfer(
      fromAccountId: bank.id,
      toAccountId: dollars.id,
      sent: d('400000'),
      received: d('120.74'),
      date: DateTime(2026, 10, 1, 18),
    );
    // Rent entered ahead: not in the balance yet.
    await store.addEntry(
      accountId: bank.id,
      amount: d('1650000'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 5, 9),
      category: 'housing',
    );
  }

  test('an account comes apart into parts that make its balance', () async {
    await fill();
    addTearDown(store.close);
    final List<Entry> entries = await store.entries();
    final AccountTrace t = traceAccount(bank, entries, now);
    expect(t.opening.amount, d('820000'));
    expect(
      <TraceKind, (int, Decimal)>{
        for (final TracePart p in t.parts) p.kind: (p.count, p.sum.amount),
      },
      <TraceKind, (int, Decimal)>{
        TraceKind.income: (1, d('2400000')),
        TraceKind.expense: (2, d('-203000')),
        TraceKind.transferOut: (1, d('-400000')),
      },
    );
    final Money balance = balancesOf(
      await store.accounts(),
      entries,
      now,
    )[bank.id]!;
    expect(t.balance, balance);
    expect(
      t.parts.fold(
        t.opening.amount,
        (Decimal sum, TracePart p) => sum + p.sum.amount,
      ),
      balance.amount,
    );
    expect(t.aheadCount, 1);
    expect(t.ahead.amount, d('-1650000'));

    final AccountTrace usd = traceAccount(dollars, entries, now);
    expect(usd.parts.single.kind, TraceKind.transferIn);
    expect(usd.balance.amount, d('1371.49'));
  });

  testWidgets('the total shows each account converted, and what has no rate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(fill);
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => now,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(own.start);
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: AccountsTab(own: own)),
        ),
      ),
    );
    await settle(tester);

    // 2.617.000 in the bank, and 1.371,49 dollars at 3.312,84.
    final Money bankPart = own.partOfTotal(bank)!;
    final Money usdPart = own.partOfTotal(dollars)!;
    expect(bankPart.amount, d('2617000'));
    expect(usdPart.amount, d('4543527'));
    expect(own.partOfTotal(bitcoin), isNull);
    expect(own.total().amount, bankPart.amount + usdPart.amount);
    // Nobody owes anything and nothing is bought in instalments: the net
    // worth is the accounts.
    expect(own.netWorth().total, own.total());
    // Dollars on the same screen: the figure says which currency it is in.
    expect(
      find.descendant(of: find.byType(Headline), matching: find.text('COP')),
      findsOneWidget,
    );

    await tester.tap(find.text('¿De dónde sale?').first);
    await settle(tester);
    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(TotalExplained), matching: f);
    expect(inSheet(find.text('Así se calcula tu patrimonio')), findsOneWidget);
    expect(
      inSheet(find.text(moneyText(bankPart, base: Asset.cop))),
      findsOneWidget,
    );
    expect(
      inSheet(find.text(moneyText(usdPart, base: Asset.cop))),
      findsOneWidget,
    );
    expect(inSheet(find.textContaining('TRM oficial')), findsOneWidget);
    expect(
      inSheet(find.text(moneyText(own.netWorth().total, base: Asset.cop))),
      findsOneWidget,
    );
    expect(
      inSheet(find.text('Sin tasa todavía, no suman: Bitcoin.')),
      findsOneWidget,
    );
  });
}
