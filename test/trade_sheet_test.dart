// Recording a purchase or a sale of a coin: what the form says while it is
// filled in.
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
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

  testWidgets('a coin paid with another cannot spend more than it holds', (
    tester,
  ) async {
    final OwnController own = await openCrypto(tester, FakeMarket());
    final Account bitcoin = own.accounts.firstWhere(
      (Account a) => a.asset == Asset.btc,
    );
    final Account tether = own.accounts.firstWhere(
      (Account a) => a.asset == Asset.usdt,
    );
    unawaited(
      showTradeSheet(
        tester.element(find.byType(PortfolioPage)),
        own: own,
        account: bitcoin,
      ),
    );
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Cantidad de BTC'),
      '0,01',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await settle(tester);
    await tester.tap(find.text('Tether · USDT').last);
    await settle(tester);
    final Finder total = find.widgetWithText(TextField, 'Total pagado');
    await tester.enterText(total, '900');
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    InputDecoration decoration() => tester.widget<TextField>(total).decoration!;
    expect(decoration().errorText, 'Esa cuenta tiene 500\u00a0USDT.');
    expect(
      own.snapshot!.entries.where((Entry e) => e.accountId == tether.id),
      isEmpty,
    );

    await tester.enterText(total, '400');
    await settle(tester);
    expect(decoration().errorText, isNull);
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(
      own.balances[tether.id]!.amount,
      tether.opening - Decimal.fromInt(400),
    );
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

  testWidgets('«Todo» sells the whole balance, to its last digit', (
    tester,
  ) async {
    final OwnController own = await openCrypto(
      tester,
      FakeMarket(),
      data: (QuincenaStore store) async {
        final Account bitcoin = (await store.accounts()).firstWhere(
          (Account a) => a.asset == Asset.btc,
        );
        // A reward with more digits than the field writes.
        await store.addEntry(
          accountId: bitcoin.id,
          amount: Decimal.parse('0.0000000012'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 1),
        );
      },
    );
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

    // Said to a screen reader with what it sells.
    expect(
      tester.widget<Text>(find.text('Todo')).semanticsLabel,
      'Vender todo: 0,01\u00a0BTC',
    );
    await tester.tap(find.text('Todo'));
    await settle(tester);
    expect(tester.widget<TextField>(quantity).controller!.text, '0,01');
    await tester.enterText(
      find.widgetWithText(TextField, 'Total recibido'),
      '4000000',
    );
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(own.balances[bitcoin.id]!.isZero, isTrue);
  });

  testWidgets('one of the accounts says what it does to it, the total\'s '
      'currency, and the way back outside', (tester) async {
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
    expect(find.text('COP'), findsWidgets);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await settle(tester);
    await tester.tap(find.text('Tether · USDT').last);
    await settle(tester);
    expect(
      find.text(
        'El total sale de esa cuenta y su saldo baja. Si lo pagaste por '
        'fuera, elige «Fuera de Quincena».',
      ),
      findsOneWidget,
    );
    expect(
      find.text('El total va en la moneda de esa cuenta (USDT).'),
      findsOneWidget,
    );
    expect(find.byType(SegmentedButton<String>), findsNothing);

    // Back outside, the currency is picked again.
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await settle(tester);
    await tester.tap(find.text('Fuera de Quincena').last);
    await settle(tester);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.textContaining('El total va en la moneda'), findsNothing);
    expect(find.textContaining('En Binance P2P'), findsOneWidget);
  });
}
