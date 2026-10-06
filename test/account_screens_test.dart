// An account's own screens: the form that adds or edits one, its page, and
// the wallets followed by address.
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/account_page.dart';
import 'package:quincena/ui/own/account_sheet.dart';
import 'package:quincena/ui/own/portfolio_page.dart';
import 'package:quincena/ui/own/wallets_page.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;
import 'portfolio_page_test.dart' show openCrypto;
import 'portfolio_test.dart' show FakeMarket;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// The crypto page with a bank and a card [inFavor] of its holder, or
  /// owing, on it.
  Future<OwnController> open(WidgetTester tester, {bool inFavor = false}) =>
      openCrypto(
        tester,
        FakeMarket(),
        data: (QuincenaStore store) async {
          await store.addAccount(
            name: 'Bancolombia',
            kind: AccountKind.bank,
            asset: Asset.cop,
            opening: Decimal.fromInt(1000000),
          );
          await store.addAccount(
            name: 'Visa',
            kind: AccountKind.card,
            asset: Asset.cop,
            opening: Decimal.fromInt(inFavor ? 55200 : -480000),
            creditLimit: Decimal.fromInt(2000000),
          );
        },
      );

  Account named(OwnController own, String name) =>
      own.accounts.firstWhere((Account a) => a.name == name);

  Money balance(OwnController own, Account a) =>
      own.balances[a.id] ?? a.openingMoney;

  Future<void> push(WidgetTester tester, Widget page) async {
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(MaterialPageRoute<void>(builder: (BuildContext _) => page)),
    );
    await settle(tester);
  }

  InputDecoration field(WidgetTester tester, String label) => tester
      .widget<TextField>(find.widgetWithText(TextField, label))
      .decoration!;

  testWidgets('a field said to be wrong stops saying it once typed again', (
    tester,
  ) async {
    final OwnController own = await open(tester);
    unawaited(
      showAccountSheet(tester.element(find.byType(PortfolioPage)), own: own),
    );
    await settle(tester);

    await tester.tap(find.text('Tarjeta de crédito'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Cupo total (opcional)'),
      '0',
    );
    await settle(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(
      field(tester, 'Nombre').errorText,
      'Por ejemplo, Bancolombia ahorros',
    );
    expect(
      field(tester, 'Cupo total (opcional)').errorText,
      'Escribe un monto',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Falabella',
    );
    await settle(tester);
    expect(field(tester, 'Nombre').errorText, isNull);
    await tester.enterText(
      find.widgetWithText(TextField, 'Cupo total (opcional)'),
      '1000000',
    );
    await settle(tester);
    expect(field(tester, 'Cupo total (opcional)').errorText, isNull);
  });

  testWidgets('a card in its holder\'s favor stays so when its limit changes', (
    tester,
  ) async {
    final OwnController own = await open(tester, inFavor: true);
    final Account visa = named(own, 'Visa');
    await push(tester, AccountPage(own: own, accountId: visa.id));
    expect(find.text('A favor'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar cuenta'));
    await settle(tester);
    // What is owed, below zero: nothing owed, and some in favor.
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, '¿Cuánto debes hoy?'),
          )
          .controller!
          .text,
      '-55.200',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Cupo total (opcional)'),
      '3000000',
    );
    await settle(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    final Account edited = named(own, 'Visa');
    expect(edited.creditLimit, Decimal.fromInt(3000000));
    expect(balance(own, edited), Money(Decimal.fromInt(55200), Asset.cop));
    expect(find.text('A favor'), findsOneWidget);
  });

  testWidgets('a balance typed again still moves the opening', (tester) async {
    final OwnController own = await open(tester);
    final Account bank = named(own, 'Bancolombia');
    await push(tester, AccountPage(own: own, accountId: bank.id));
    await tester.tap(find.byTooltip('Editar cuenta'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '1180000',
    );
    await settle(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(
      balance(own, named(own, 'Bancolombia')),
      Money(Decimal.fromInt(1180000), Asset.cop),
    );
  });

  testWidgets('deleting an account from its page goes back to where it was '
      'opened from', (tester) async {
    final OwnController own = await open(tester);
    final Account bank = named(own, 'Bancolombia');
    await push(tester, AccountPage(own: own, accountId: bank.id));

    await tester.tap(find.byTooltip('Editar cuenta'));
    await settle(tester);
    await tester.ensureVisible(find.text('Eliminar'));
    await tester.tap(find.text('Eliminar'));
    await settle(tester);
    await tester.tap(find.text('Eliminar').last);
    await settle(tester);

    expect(own.accounts.where((Account a) => a.id == bank.id), isEmpty);
    expect(find.byType(AccountPage), findsNothing);
    expect(find.byType(PortfolioPage), findsOneWidget);
  });

  testWidgets('the wallets page reads the wallets again, and says so', (
    tester,
  ) async {
    final OwnController own = await open(tester);
    await push(tester, WalletsPage(own: own));
    expect(find.byTooltip('Actualizar'), findsOneWidget);
    expect(find.byTooltip('Actualizar tasas'), findsNothing);
  });
}
