// Crypto bought or sold against one of the person's own accounts is a
// purchase or a sale, on both sides, wherever the movement shows: not a
// transfer, which carries the same money from one account to another.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/balance_explained.dart';
import 'package:quincena/ui/own/movement_list.dart';
import 'package:quincena/ui/own/movements_tab.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// Bancolombia and Visa, plus bitcoin, tether and dollars: bitcoin sold
  /// into the bank, bitcoin bought from it, bitcoin bought with tether, and
  /// pesos changed to dollars.
  Future<void> trades(QuincenaStore store, Account bank, Account _) async {
    final Account bitcoin = await store.addAccount(
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
      opening: d('0.0123'),
    );
    final Account tether = await store.addAccount(
      name: 'Tether',
      kind: AccountKind.exchange,
      asset: Asset.usdt,
      opening: d('500'),
    );
    final Account dollars = await store.addAccount(
      name: 'Dólares',
      kind: AccountKind.bank,
      asset: Asset.usd,
      opening: d('0'),
      spendable: false,
    );
    await store.addTransfer(
      fromAccountId: bitcoin.id,
      toAccountId: bank.id,
      sent: d('0.005'),
      received: d('1650000'),
      date: DateTime(2026, 10, 2, 9),
    );
    await store.addTransfer(
      fromAccountId: bank.id,
      toAccountId: bitcoin.id,
      sent: d('360000'),
      received: d('0.001'),
      date: DateTime(2026, 10, 2, 10),
    );
    await store.addTransfer(
      fromAccountId: tether.id,
      toAccountId: bitcoin.id,
      sent: d('100'),
      received: d('0.0011'),
      date: DateTime(2026, 10, 2, 11),
    );
    await store.addTransfer(
      fromAccountId: bank.id,
      toAccountId: dollars.id,
      sent: d('400000'),
      received: d('100'),
      date: DateTime(2026, 10, 2, 12),
    );
  }

  /// The detail line of the movement whose title is [title].
  String detailOf(WidgetTester tester, String title) {
    final Finder row = find.ancestor(
      of: find.text(title),
      matching: find.byType(MovementRow),
    );
    final List<String> texts = <String>[
      for (final Text t in tester.widgetList<Text>(
        find.descendant(of: row, matching: find.byType(Text)),
      ))
        ?t.data,
    ];
    return texts[1];
  }

  testWidgets('Movimientos calls a sale a sale and a purchase a purchase', (
    tester,
  ) async {
    await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
        ),
      ),
      data: trades,
    );
    expect(detailOf(tester, 'Bitcoin → Bancolombia'), 'Venta');
    expect(detailOf(tester, 'Bancolombia → Bitcoin'), 'Compra');
    expect(detailOf(tester, 'Tether → Bitcoin'), 'Compra');
    // Pesos to dollars is the person's money carried over, as before.
    expect(detailOf(tester, 'Bancolombia → Dólares'), 'Transferencia');
  });

  testWidgets('each account calls its side of the trade by what it was', (
    tester,
  ) async {
    late OwnController own;
    own = await openPage(
      tester,
      (OwnController own) => const Scaffold(body: SizedBox()),
      data: trades,
    );
    Account named(String name) =>
        own.accounts.firstWhere((Account a) => a.name == name);
    Future<String> explained(String name) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: quincenaTheme(Brightness.light),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountExplained(own: own, account: named(name)),
            ),
          ),
        ),
      );
      await settle(tester);
      return <String>[
        for (final Text t in tester.widgetList<Text>(find.byType(Text)))
          ?t.data,
      ].join(' | ');
    }

    // Bitcoin: one sold into the bank; one bought from it, one with tether.
    final String bitcoin = await explained('Bitcoin');
    expect(bitcoin, contains('Una venta'));
    expect(bitcoin, contains('2 compras'));
    expect(bitcoin, isNot(contains('transferencia')));
    // The bank: the pesos the sale brought, the pesos the purchase took;
    // the dollars it bought are still a transfer.
    final String bank = await explained('Bancolombia');
    expect(bank, contains('Una venta'));
    expect(bank, contains('Una compra'));
    expect(bank, contains('Una transferencia que salió'));
    expect(await explained('Tether'), contains('Una venta'));
    expect(await explained('Dólares'), contains('Una transferencia que entró'));
  });
}
