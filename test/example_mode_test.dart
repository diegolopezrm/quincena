// The whole app on Valentina's example account: what only works with the
// person's own accounts says so and does nothing, nothing done in the
// example reaches the person's database, and its conversation tells the
// same figure as its Inicio.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/data/example_account.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/portfolio/portfolio.dart';
import 'package:quincena/portfolio/portfolio_controller.dart';
import 'package:quincena/showcase.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/home_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/statement_page.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show fakeRates, screen, settle;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  tearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });

  /// The app on a phone with nothing of the person's yet, opened on the
  /// example from the first screen. What reaches the phone's own channels
  /// goes to [calls].
  Future<QuincenaStore> openExample(
    WidgetTester tester,
    List<MethodCall> calls,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    for (final String channel in <String>[
      'dev.dlsoft.quincena/reminders',
      'dev.dlsoft.quincena/widget',
      'dev.dlsoft.quincena/capture',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(channel),
          null,
        ),
      );
    }
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
    );
    addTearDown(() => tester.runAsync(store.close));
    await tester.pumpWidget(
      QuincenaApp(store: store, startInDemo: false, fetcher: fakeRates()),
    );
    await settle(tester);
    await tester.tap(find.text('Con datos de ejemplo'));
    await settle(tester);
    return store;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final Finder f = find.text(text);
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        200,
        // The page's own list, not one sideways inside it.
        scrollable: find
            .byWidgetPredicate(
              (Widget w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    // To the top of the list, clear of the buttons that float at its foot.
    await tester.ensureVisible(f.last);
    await settle(tester);
    await tester.tap(f.last);
    await settle(tester);
  }

  testWidgets('what only works with one\'s own accounts says so in the '
      'example, and nothing reaches the phone or the person\'s database', (
    tester,
  ) async {
    final List<MethodCall> calls = <MethodCall>[];
    final QuincenaStore mine = await openExample(tester, calls);
    expect(find.text('Cuenta de ejemplo de Valentina'), findsOneWidget);
    final int entries = tester
        .widget<OwnShell>(find.byType(OwnShell))
        .own
        .snapshot!
        .entries
        .length;

    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    await tapText(tester, 'Avisarme el día de pago');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Seguir en el ejemplo'));
    await settle(tester);
    for (final String row in <String>[
      'Captura automática',
      'Binance',
      'Varios dispositivos',
      'Exportar mis datos',
      'Borrar todo',
    ]) {
      await tapText(tester, row);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text(row)),
        findsOneWidget,
        reason: row,
      );
      expect(screen(tester), contains('no le pide permisos a tu teléfono'));
      await tester.tap(find.text('Seguir en el ejemplo'));
      await settle(tester);
    }

    // Still the example, whole, after «Borrar todo».
    expect(
      tester
          .widget<OwnShell>(find.byType(OwnShell, skipOffstage: false))
          .own
          .snapshot!
          .entries,
      hasLength(entries),
    );
    // No reminder, no widget, no capture setting and no key: nothing.
    expect(calls, isEmpty);
    expect(await tester.runAsync(mine.profile), isNull);
    expect(await tester.runAsync(mine.entries), isEmpty);
    expect(await tester.runAsync(() => mine.setting('app.mode')), 'demo');

    // A statement of its own to try, and a file still to pick.
    await tapText(tester, 'Importar extracto');
    expect(find.byType(StatementPage), findsOneWidget);
    expect(find.text('Elegir archivo'), findsOneWidget);
    expect(screen(tester), contains('Usar el extracto de ejemplo'));
    expect(calls, isEmpty);
  });

  testWidgets('«Importar extracto» tries a statement of its own: a repeat, '
      'a card payment and a line older than the balance', (tester) async {
    await openExample(tester, <MethodCall>[]);
    OwnController own() =>
        tester.widget<OwnShell>(find.byType(OwnShell, skipOffstage: false)).own;
    final Account bank = own().accounts.firstWhere(
      (Account a) => a.name == exampleStatementAccount,
    );
    final Account card = own().accounts.firstWhere(
      (Account a) => a.kind == AccountKind.card,
    );
    final Money held = own().balances[bank.id]!;
    final Money owed = own().balances[card.id]!;
    final int free = own().ledger!.freeUntilPayday;

    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    await tapText(tester, 'Importar extracto');
    await tapText(tester, 'Usar el extracto de ejemplo');
    final String review = screen(tester);
    // September's last pay is already in the account, and left unchecked.
    expect(review, contains('Ya registrado'));
    expect(review, contains('Pago de tu tarjeta Tarjeta de crédito'));
    expect(review, contains('Importar 4 movimientos'));
    await tester.scrollUntilVisible(
      find.text('Mi saldo ya los incluye (recomendado)'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (Widget w) =>
                w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await settle(tester);
    expect(
      screen(tester),
      contains(
        'Un movimiento es de antes del 31 de marzo, cuando escribiste el '
        'saldo de Cuenta de nómina.',
      ),
    );

    await tapText(tester, 'Importar 4 movimientos');
    expect(screen(tester), contains('Se importaron 4 movimientos.'));
    // The card payment moved money to the card; the two charges and none
    // of March's, which the balance she wrote already had, left the bank.
    expect(
      own().balances[bank.id]!.amount,
      held.amount - Decimal.fromInt(300000 + 38700 + 14900),
    );
    expect(
      own().balances[card.id]!.amount,
      owed.amount + Decimal.fromInt(300000),
    );
    expect(own().ledger!.freeUntilPayday, free - 38700 - 14900);
  });

  testWidgets('«Leer un pago» brings a bank\'s message of its own, and the '
      'crypto says its prices are fixed and nothing connects', (tester) async {
    final List<MethodCall> calls = <MethodCall>[];
    await openExample(tester, calls);
    OwnController own() =>
        tester.widget<OwnShell>(find.byType(OwnShell, skipOffstage: false)).own;
    final int waiting = own().pendingInbox.length;
    await tester.tap(find.byTooltip('Por revisar'));
    await settle(tester);
    await tester.tap(find.text('Leer un pago').first);
    await settle(tester);
    await tester.tap(find.text('Un mensaje que copiaste'));
    await settle(tester);
    final TextField field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, exampleMessage);
    expect(screen(tester), contains('Un mensaje de ejemplo'));
    await tester.tap(find.text('Leer'));
    await settle(tester);
    expect(own().pendingInbox, hasLength(waiting + 1));
    // Ready to record, from the account its card digits name.
    expect(screen(tester), contains('Drogueria Laureles'));
    expect(screen(tester), contains('Salud · Cuenta de nómina'));
    Navigator.of(tester.element(find.byType(InboxPage))).pop();
    await settle(tester);

    await tester.tap(find.text('Cuentas').last);
    await settle(tester);
    await tapText(tester, 'Rendimiento y ganancia');
    // Real-looking figures from the fixed prices: none of them nil.
    final PortfolioController crypto = own().portfolio;
    expect(crypto.day!.change, isNot(0));
    expect(crypto.portfolio!.gainRatio, isNot(0));
    for (final Holding h in crypto.portfolio!.holdings) {
      if (h.asset == Asset.usdt) continue;
      expect(h.change24h, isNot(0), reason: h.asset.code);
      expect(h.gainRatio, isNot(0), reason: h.asset.code);
    }
    await tester.scrollUntilVisible(
      find.text('Billeteras propias'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (Widget w) =>
                w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await settle(tester);
    final String said = screen(tester);
    expect(said, isNot(matches(RegExp(r'(^|[^\d,])0(,0+)? %'))));
    expect(find.text('En el ejemplo no se conecta con nada'), findsNWidgets(2));
    expect(said, contains('En el ejemplo los precios son fijos'));
    expect(said, isNot(contains('Precios de mercado de Binance')));
    expect(calls, isEmpty);
  });

  testWidgets('its conversation opens from Inicio and tells the same figure', (
    tester,
  ) async {
    await openExample(tester, <MethodCall>[]);
    // The bar's two ways in are a finger's room, as every button is.
    for (final (String text, Type type) in <(String, Type)>[
      ('Cuenta de ejemplo de Valentina', InkWell),
      ('Usar mis cuentas', TextButton),
    ]) {
      expect(
        tester
            .getSize(
              find.ancestor(of: find.text(text), matching: find.byType(type)),
            )
            .height,
        greaterThanOrEqualTo(48),
        reason: text,
      );
    }
    final String free = format.pesos(
      demoLedger().major(demoLedger().freeUntilPayday),
    );
    expect(screen(tester), contains(free));
    await tapText(tester, 'Otra pregunta');
    expect(find.byType(HomePage), findsOneWidget);
    expect(screen(tester), contains(free));
    // The way back is on screen, and the bar stays over it.
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Cuenta de ejemplo de Valentina'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byType(HomePage), findsNothing);

    // Leaving the example for the first screen leaves nothing open.
    await tester.tap(find.text('Cuenta de ejemplo de Valentina'));
    await settle(tester);
    await tester.tap(find.text('Volver a la primera pantalla'));
    await settle(tester);
    expect(find.text('Con datos de ejemplo'), findsOneWidget);
    expect(find.text('Cuenta de ejemplo de Valentina'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  // The web demo is the showcase for developers; the phone apps are the
  // product, and show none of its options.
  for (final bool web in <bool>[false, true]) {
    testWidgets(
      web
          ? 'in the web demo, the conversation offers who answers, the '
                'inspector and the recorded sessions'
          : 'on a phone, the conversation is the script, with no key of '
                'one\'s own, no inspector and no recorded sessions',
      (WidgetTester tester) async {
        debugShowcaseOverride = web;
        addTearDown(() => debugShowcaseOverride = null);
        await openExample(tester, <MethodCall>[]);
        await tapText(tester, 'Otra pregunta');
        // The recorded sessions load from the app's own files.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await settle(tester);
        expect(find.text(web ? 'DEMO' : 'EJEMPLO'), findsOneWidget);
        expect(
          find.text(
            'Mira lo que respondió Gemini de verdad',
            skipOffstage: false,
          ),
          web ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byTooltip('Ajustes').last);
        await settle(tester);
        for (final String option in <String>[
          'Quién responde',
          'Gemini',
          'Modo desarrollador',
        ]) {
          expect(
            find.text(option),
            web ? findsWidgets : findsNothing,
            reason: option,
          );
        }
        expect(
          find.text(
            'La cuenta, la persona y los comercios del ejemplo son '
            'inventados.',
          ),
          web ? findsNothing : findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      },
    );
  }
}
