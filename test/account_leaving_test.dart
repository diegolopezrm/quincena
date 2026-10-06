// An account the person closed: archived, it keeps its history out of
// every total and list, and comes back when restored; deleted, what was
// paid from it goes where the person says, and the form says beforehand
// what goes with it and how the net worth changes.
import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/charge_sheet.dart';
import 'package:quincena/ui/own/entry_sheet.dart';
import 'package:quincena/ui/own/instalments_page.dart';
import 'package:quincena/ui/own/look.dart' show moneyText;

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// Nequi with two movements; on the Visa a purchase, paid off from the
  /// bank, Netflix every month and a phone in six instalments.
  Future<void> closing(QuincenaStore store, Account bank, Account card) async {
    final Account nequi = await store.addAccount(
      name: 'Nequi',
      kind: AccountKind.wallet,
      asset: Asset.cop,
      opening: d('35000'),
    );
    for (final String amount in <String>['23500', '9800']) {
      await store.addEntry(
        accountId: nequi.id,
        amount: d(amount),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 12),
        category: 'restaurants',
      );
    }
    await store.addEntry(
      accountId: card.id,
      amount: d('42900'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 2, 12),
      category: 'shopping',
      payee: 'Falabella',
    );
    await store.addTransfer(
      fromAccountId: bank.id,
      toAccountId: card.id,
      sent: d('42900'),
      date: DateTime(2026, 10, 3, 9),
    );
    await store.addRecurring(
      name: 'Netflix',
      amount: Money(d('26900'), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 12),
      accountId: card.id,
      category: 'subscriptions',
    );
    await store.setSetting(
      'commitments.instalments',
      jsonEncode(<Object?>[
        Instalments(
          id: 'instalments-phone',
          name: 'Celular',
          principal: 1200000,
          count: 6,
          firstDue: DateTime(2026, 10, 20),
          instalment: 215000,
          accountId: card.id,
        ).toJson(),
      ]),
    );
  }

  Future<OwnController> open(WidgetTester tester) => openPage(
    tester,
    (OwnController own) => Scaffold(
      body: ListenableBuilder(
        listenable: own,
        builder: (BuildContext context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AccountsTab(own: own),
        ),
      ),
    ),
    data: closing,
  );

  Account? named(OwnController own, String name) =>
      own.accounts.where((Account a) => a.name == name).firstOrNull;

  /// Everything on screen, as one string, with the spaces that do not break
  /// read as plain ones.
  String said(WidgetTester tester) => <String>[
    for (final RichText t in tester.widgetList<RichText>(find.byType(RichText)))
      t.text.toPlainText(),
  ].join(' | ').replaceAll(' ', ' ').replaceAll(signJoiner, '');

  String cop(Money m) => moneyText(m, base: Asset.cop).replaceAll(' ', ' ');

  Future<void> openForm(WidgetTester tester, String account) async {
    await tapText(tester, account);
    await tester.tap(find.byTooltip('Editar cuenta'));
    await settle(tester);
  }

  testWidgets('an account is archived from its form, keeps its history, and '
      'comes back from the archived ones', (tester) async {
    final OwnController own = await open(tester);
    final Account nequi = named(own, 'Nequi')!;
    final int entries = own.snapshot!.entries.length;
    final Money worth = own.netWorth().total;
    final Money held = own.partOfTotal(nequi)!;

    await openForm(tester, 'Nequi');
    await tapText(tester, 'Archivar');
    // It asks first, and says what archiving does.
    expect(find.text('¿Archivar Nequi?'), findsOneWidget);
    final String asked = said(tester);
    expect(asked, contains('Sus 2 movimientos se quedan en tu historial.'));
    expect(asked, contains('«Cuentas archivadas»'));
    expect(
      asked,
      contains('Lo que tiene, ${cop(held)}, deja de contar en tu patrimonio.'),
    );
    expect(
      asked,
      contains('Tu patrimonio pasa de ${cop(worth)} a ${cop(worth - held)}.'),
    );
    await tester.tap(find.text('Archivar').last);
    await settle(tester);

    // Back on Cuentas, without it, and nothing lost.
    expect(find.text('Nequi'), findsNothing);
    expect(named(own, 'Nequi'), isNull);
    expect(own.snapshot!.account(nequi.id)!.archived, isTrue);
    expect(own.snapshot!.entries.length, entries);
    expect(own.netWorth().total, worth - held);
    // Nor in the lists to choose an account from.
    unawaited(
      showEntrySheet(tester.element(find.byType(AccountsTab)), own: own),
    );
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await settle(tester);
    expect(find.text('Nequi'), findsNothing);
    Navigator.of(tester.element(find.text('Bancolombia').last)).pop();
    await settle(tester);
    Navigator.of(tester.element(find.byType(AccountsTab))).pop();
    await settle(tester);

    await tapText(tester, 'Cuentas archivadas');
    expect(find.text('Nequi'), findsOneWidget);
    await tapText(tester, 'Restaurar');
    expect(named(own, 'Nequi'), isNotNull);
    expect(own.netWorth().total, worth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting a card says what is paid from it, moves it where the '
      'person says, and says how the net worth changes', (tester) async {
    final OwnController own = await open(tester);
    final Account bank = named(own, 'Bancolombia')!;
    final Account visa = named(own, 'Visa')!;

    await openForm(tester, 'Visa');
    await tapText(tester, 'Eliminar');
    final String asked = said(tester);
    expect(asked, contains('Netflix y Celular se pagan desde aquí.'));
    // Archiving is offered before deleting.
    expect(find.text('Archivar'), findsWidgets);
    // What is left of the phone was in the card's debt: without the card
    // it comes off the net worth on its own.
    final Money worth = own.netWorth().total;
    final Money phone = Money(d('1290000'), Asset.cop);
    expect(
      asked,
      contains('Lo que falta de las cuotas, ${cop(phone)}, ya no queda'),
    );
    expect(
      asked,
      contains('Tu patrimonio pasa de ${cop(worth)} a ${cop(worth - phone)}.'),
    );

    // Paid from the bank from now on.
    await tester.tap(find.text('Sin cuenta'));
    await settle(tester);
    await tester.tap(find.text('Bancolombia').last);
    await settle(tester);
    await tester.tap(find.text('Eliminar').last);
    await settle(tester);

    expect(own.snapshot!.account(visa.id), isNull);
    expect(
      own.recurring
          .firstWhere((RecurringCharge r) => r.name == 'Netflix')
          .accountId,
      bank.id,
    );
    expect(own.instalments.single.accountId, bank.id);
    expect(own.netWorth().total, worth - phone);
    expect(tester.takeException(), isNull);
  });

  testWidgets('what was paid from a deleted account opens in its form, with '
      'no account', (tester) async {
    final OwnController own = await open(tester);
    await openForm(tester, 'Visa');
    await tapText(tester, 'Eliminar');
    await tester.tap(find.text('Eliminar').last);
    await settle(tester);

    final RecurringCharge netflix = own.recurring.firstWhere(
      (RecurringCharge r) => r.name == 'Netflix',
    );
    expect(netflix.accountId, isNull);
    expect(own.instalments.single.accountId, isNull);
    final BuildContext context = tester.element(find.byType(AccountsTab));
    unawaited(showChargeSheet(context, own: own, charge: netflix));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Ninguna cuenta en particular'), findsOneWidget);
    Navigator.of(tester.element(find.text('Netflix').last)).pop();
    await settle(tester);
    unawaited(
      showInstalmentSheet(context, own: own, plan: own.instalments.single),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('what a deleted account left behind before, and a movement of '
      'an archived one, open in their forms', (tester) async {
    final OwnController own = await open(tester);
    final Account visa = named(own, 'Visa')!;
    final Account nequi = named(own, 'Nequi')!;
    // As an older version left them: deleted with Netflix and the phone
    // still on it. And Nequi archived as Binance's accounts were.
    await tester.runAsync(() async {
      await own.store.deleteAccount(visa.id);
      await own.store.updateAccount(nequi.copyWith(archived: true));
    });
    await settle(tester);
    final BuildContext context = tester.element(find.byType(AccountsTab));
    final RecurringCharge netflix = own.recurring.firstWhere(
      (RecurringCharge r) => r.name == 'Netflix',
    );
    unawaited(showChargeSheet(context, own: own, charge: netflix));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Ninguna cuenta en particular'), findsOneWidget);
    Navigator.of(tester.element(find.text('Netflix').last)).pop();
    await settle(tester);
    unawaited(
      showInstalmentSheet(context, own: own, plan: own.instalments.single),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Celular').last)).pop();
    await settle(tester);

    final Entry inNequi = own.snapshot!.entries.firstWhere(
      (Entry e) => e.accountId == nequi.id,
    );
    unawaited(showEntrySheet(context, own: own, entry: inNequi));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Nequi'), findsOneWidget);
  });
}
