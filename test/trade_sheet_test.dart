// Recording a purchase or a sale of a coin: what the form says while it is
// filled in.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/ui/own/portfolio_page.dart';
import 'package:quincena/ui/own/trade_sheet.dart';

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

  testWidgets('a field said to be wrong stops saying it once typed again, '
      'and the price per unit shows', (tester) async {
    final OwnController own = await openCrypto(tester, FakeMarket());
    final Account bitcoin = own.accounts.firstWhere(
      (Account a) => a.asset == Asset.btc,
    );
    unawaited(
      showTradeSheet(
        tester.element(find.byType(PortfolioPage)),
        own: own,
        account: bitcoin,
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(find.text('Escribe un monto'), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextField, 'Cantidad de BTC'),
      '0,001',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Total pagado'),
      '360000',
    );
    await settle(tester);
    expect(find.text('Escribe un monto'), findsNothing);
    expect(find.text('Precio por unidad: \$360.000.000'), findsOneWidget);
  });

  testWidgets('selling more than is held says so, until the quantity changes', (
    tester,
  ) async {
    final OwnController own = await openCrypto(tester, FakeMarket());
    final Account bitcoin = own.accounts.firstWhere(
      (Account a) => a.asset == Asset.btc,
    );
    unawaited(
      showTradeSheet(
        tester.element(find.byType(PortfolioPage)),
        own: own,
        account: bitcoin,
        sell: true,
      ),
    );
    await settle(tester);
    final Finder quantity = find.widgetWithText(TextField, 'Cantidad de BTC');

    await tester.enterText(quantity, '1');
    await tester.enterText(
      find.widgetWithText(TextField, 'Total recibido'),
      '400000000',
    );
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    InputDecoration decoration() =>
        tester.widget<TextField>(quantity).decoration!;
    expect(decoration().errorText, 'Esa cuenta tiene 0,01\u00a0BTC.');

    await tester.enterText(quantity, '0,005');
    await settle(tester);
    expect(decoration().errorText, isNull);
    // Nothing was recorded on the way.
    expect(
      own.snapshot!.entries.where((Entry e) => e.accountId == bitcoin.id),
      isEmpty,
    );
  });
}
