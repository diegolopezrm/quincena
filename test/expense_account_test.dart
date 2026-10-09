// Where an expense written down in a conversation comes from: the form
// says it before saving, with the account the person most likely paid from
// already chosen, and the answer names it. Nothing goes silently into the
// first account.
import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/catalog.dart';
import 'package:quincena/agent/prompt.dart';
import 'package:quincena/agent/tools.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);
  late QuincenaStore store;
  late OwnController own;
  late Account bank;
  late Account nequi;
  late Account card;

  /// Waits for the controller to read what the store now holds.
  Future<void> reread(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  setUp(() async {
    Intl.defaultLocale = 'es_CO';
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
    bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('1000000'),
    );
    nequi = await store.addAccount(
      name: 'Nequi',
      kind: AccountKind.wallet,
      asset: Asset.cop,
      opening: d('200000'),
    );
    card = await store.addAccount(
      name: 'Visa',
      kind: AccountKind.card,
      asset: Asset.cop,
      opening: Decimal.zero,
    );
    await store.addAccount(
      name: 'Ahorros',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('500000'),
      spendable: false,
    );
    own = OwnController(store, now: () => now, readNative: false);
    await own.start();
  });

  tearDown(() async {
    own.dispose();
    await store.close();
    Intl.defaultLocale = 'es_CO';
  });

  test('the form offers the accounts to spend from, the first in pesos '
      'chosen while nothing was written down by hand', () {
    final ExpenseAccounts accounts = own.expenseAccounts;
    expect(accounts.names, <String>['Bancolombia', 'Nequi', 'Visa']);
    expect(accounts.likely, 'Bancolombia');
  });

  test('the account last paid from by hand comes chosen, not one a '
      'statement or a bank alert wrote down', () async {
    await store.addEntry(
      accountId: nequi.id,
      amount: d('8000'),
      kind: EntryKind.expense,
      date: now.subtract(const Duration(days: 1)),
      category: 'restaurants',
      payee: 'Tinto',
    );
    // Newer, but read from a statement: no habit of the person's.
    await store.addEntry(
      accountId: card.id,
      amount: d('90000'),
      kind: EntryKind.expense,
      date: now,
      category: 'shopping',
      payee: 'Éxito',
      source: 'statement',
    );
    await reread(() => own.snapshot!.entries.length == 2);
    expect(own.expenseAccounts.likely, 'Nequi');

    // Put away, it is no longer one to choose: the first in pesos is.
    await own.archiveAccounts(<String>{nequi.id});
    await reread(() => own.accounts.length == 3);
    expect(own.expenseAccounts.names, <String>['Bancolombia', 'Visa']);
    expect(own.expenseAccounts.likely, 'Bancolombia');
  });

  test('record_expense saves in the account chosen and says which, and '
      'left out it goes where the last one by hand went', () async {
    final List<dartantic.Tool> tools = ownTools(own);
    final dartantic.Tool record = tools.firstWhere(
      (dartantic.Tool t) => t.name == 'record_expense',
    );
    final Map<Object?, Object?> saved =
        await record.call(<String, dynamic>{
              'amount': 12000,
              'category': 'restaurants',
              'note': 'Almuerzo',
              'account': 'Nequi',
              'id': 'form-1',
            })
            as Map<Object?, Object?>;
    expect(saved['recorded'], isTrue);
    expect(saved['account'], 'Nequi');
    final Entry entry = (await store.entries()).single;
    expect(entry.accountId, nequi.id);

    final Map<Object?, Object?> again =
        await record.call(<String, dynamic>{
              'amount': 5000,
              'category': 'other',
              'id': 'form-2',
            })
            as Map<Object?, Object?>;
    expect(again['account'], 'Nequi');

    // The model is told the same before it composes the form.
    final Map<Object?, Object?> offered =
        await tools
                .firstWhere((dartantic.Tool t) => t.name == 'expense_accounts')
                .call(<String, dynamic>{})
            as Map<Object?, Object?>;
    expect(offered, <String, Object?>{
      'accounts': <String>['Bancolombia', 'Nequi', 'Visa'],
      'likely': 'Nequi',
    });
  });

  test('an account is found by its whole name before one that only '
      'contains it', () async {
    final Account kept = await store.addAccount(
      name: 'Nequi ahorro',
      kind: AccountKind.wallet,
      asset: Asset.cop,
      opening: d('50000'),
    );
    await reread(() => own.accounts.length == 5);
    final Map<Object?, Object?> saved =
        await ownTools(own)
                .firstWhere((dartantic.Tool t) => t.name == 'record_expense')
                .call(<String, dynamic>{
                  'amount': 3000,
                  'category': 'other',
                  'account': 'Nequi ahorro',
                })
            as Map<Object?, Object?>;
    expect(saved['account'], 'Nequi ahorro');
    expect((await store.entries()).single.accountId, kept.id);
    expect(bank.id, isNot(kept.id));
  });

  test('the model is told to put the account in the form', () {
    final String told = quincenaPrompt(
      quincenaCatalog,
      demoLedger(),
      own: true,
    ).replaceAll(RegExp(r'\s+'), ' ');
    expect(told, contains('an AccountChoice when you have expense_accounts'));
    expect(told, contains('call expense_accounts for the form'));
  });
}
