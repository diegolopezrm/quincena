import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/movement_list.dart';
import 'package:quincena/ui/own/movements_tab.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  Future<OwnController> open(WidgetTester tester) => openPage(
    tester,
    (OwnController own) => Scaffold(
      body: ListenableBuilder(
        listenable: own,
        builder: (BuildContext context, _) =>
            CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
      ),
    ),
    data: (QuincenaStore store, Account bank, _) async {
      final Account nequi = await store.addAccount(
        name: 'Nequi',
        kind: AccountKind.wallet,
        asset: Asset.cop,
        opening: Decimal.zero,
      );
      await store.addEntry(
        accountId: bank.id,
        amount: Decimal.parse('187400'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 12),
        category: 'groceries',
        payee: 'Éxito Laureles',
      );
      await store.addTransfer(
        fromAccountId: bank.id,
        toAccountId: nequi.id,
        sent: Decimal.parse('50000'),
        date: DateTime(2026, 10, 1, 18),
      );
    },
  );

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await settle(tester);
  }

  testWidgets('a search finds a name typed without its accents', (
    tester,
  ) async {
    await open(tester);
    for (final String typed in <String>['exito', 'ÉXITO', 'Éxito laur']) {
      await search(tester, typed);
      expect(find.text('Éxito Laureles'), findsOneWidget, reason: typed);
      expect(find.byType(MovementRow), findsOneWidget, reason: typed);
    }
    await search(tester, 'mercádo');
    expect(find.text('Éxito Laureles'), findsOneWidget);
  });

  testWidgets('a transfer is found by the account it went to', (tester) async {
    await open(tester);
    await search(tester, 'nequi');
    expect(find.text('Bancolombia → Nequi'), findsOneWidget);
    expect(find.byType(MovementRow), findsOneWidget);
    await search(tester, 'bancolombia');
    expect(find.text('Bancolombia → Nequi'), findsOneWidget);
    expect(find.text('Éxito Laureles'), findsOneWidget);
  });

  testWidgets('a search of only signs shows everything', (tester) async {
    await open(tester);
    await search(tester, r' $ ');
    expect(find.text('Nada coincide con la búsqueda.'), findsNothing);
    expect(find.text('Éxito Laureles'), findsOneWidget);
  });
}
