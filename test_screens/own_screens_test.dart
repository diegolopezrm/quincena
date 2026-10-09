// Renders the screens for someone's own accounts to PNG, for review.
//
// Not part of `flutter test`, like the rest of this folder. Regenerate with:
//
//   flutter test test_screens/own_screens_test.dart --update-goldens

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import '../test/commitments_data.dart';
import '../test/fonts.dart';
import '../test/real_life_data.dart';
import '../test/own_flow_test.dart' show fakeRates, settle;
import 'accounts.dart';

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

  Future<void> open(
    WidgetTester tester,
    QuincenaStore store,
    Size size,
    Brightness brightness,
  ) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(() => tester.runAsync(store.close));
    await tester.pumpWidget(
      QuincenaApp(
        store: store,
        startInDemo: false,
        fetcher: fakeRates(),
        now: () => screensNow,
      ),
    );
    // Gone before its store closes, so nothing reads a closed database.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await settle(tester);
  }

  // Scrolls the page on top until [finder] is built and on screen: the
  // lists build lazily, so it may not exist yet.
  Future<void> reach(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      Finder? page;
      for (final Element e in find.byType(Scrollable).evaluate()) {
        final ScrollableState s =
            (e as StatefulElement).state as ScrollableState;
        final RenderBox? box = e.renderObject as RenderBox?;
        if (s.position.axis != Axis.vertical) continue;
        if (box == null || !box.hasSize || box.size.height < 240) continue;
        page = find.byWidget(s.widget);
      }
      await tester.scrollUntilVisible(finder, 240, scrollable: page);
    }
    await tester.ensureVisible(finder.last);
    await settle(tester);
  }

  const Size phone = Size(390, 844);
  const Size desktop = Size(1280, 860);

  Future<void> shoot(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/own-$name.png'),
  );

  testWidgets('start', (tester) async {
    final QuincenaStore store = (await tester.runAsync(
      () async => QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => screensNow,
      ),
    ))!;
    await open(tester, store, phone, Brightness.light);
    await shoot('start');
    await tester.tap(find.text('Con mis cuentas'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Diego');
    await settle(tester);
    await shoot('onboarding-1');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);
    await shoot('onboarding-2');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);
    await shoot('onboarding-3');
    await tester.tap(find.text('Bancolombia · COP'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '1.500.000',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    await tester.tap(find.text('Empezar'));
    await settle(tester);
    // What setting up left for later, on Inicio.
    await shoot('onboarding-done');
  });

  for (final Brightness b in Brightness.values) {
    testWidgets('tabs ${b.name}', (tester) async {
      final QuincenaStore store = (await tester.runAsync(seeded))!;
      await open(tester, store, phone, b);
      await shoot('home-${b.name}');
      await tester.tap(find.text('Movimientos'));
      await settle(tester);
      await shoot('movements-${b.name}');
      await tester.tap(find.text('Cuentas'));
      await settle(tester);
      await shoot('accounts-${b.name}');
    });
  }

  testWidgets('free explained', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('¿De dónde sale?'));
    await settle(tester);
    await shoot('free-explained');
  });

  testWidgets('sheets', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    await shoot('entry-question');
    await tester.tap(find.text('Gasté plata'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '45.900');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde o a quién?'),
      'Éxito',
    );
    await settle(tester);
    await shoot('entry-sheet');
    await tester.tap(find.byTooltip('Cambiar qué pasó'));
    await settle(tester);
    await tester.tap(find.text('Moví plata entre mis cuentas'));
    await settle(tester);
    await shoot('transfer-sheet');
  });

  testWidgets('account page', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Cuentas'));
    await settle(tester);
    await tester.ensureVisible(find.text('Binance').first);
    await settle(tester);
    await tester.tap(find.text('Binance').first);
    await settle(tester);
    await shoot('account-binance');
  });

  testWidgets('capture', (tester) async {
    final QuincenaStore store = (await tester.runAsync(withCaptures))!;
    await open(tester, store, phone, Brightness.light);
    await shoot('home-inbox');
    await tester.tap(find.byTooltip('Por revisar'));
    await settle(tester);
    await shoot('inbox');
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    await shoot('settings');
    await reach(tester, find.text('Captura automática'));
    await tester.tap(find.text('Captura automática'));
    await settle(tester);
    await shoot('capture');
    await reach(tester, find.text('Reglas aprendidas'));
    await tester.tap(find.text('Reglas aprendidas'));
    await settle(tester);
    await shoot('rules');
  });

  testWidgets('many to review', (tester) async {
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = await seeded();
      final Account nequi = (await store.accounts()).firstWhere(
        (Account a) => a.name == 'Nequi',
      );
      await store.saveCaptureSettings(
        (await store.captureSettings()).copyWith(
          cardAccounts: <String, String>{'9876': nequi.id},
        ),
      );
      // A week of Nequi's card, read in one go from screenshots' worth of
      // alerts: twenty waiting.
      const List<String> shops = <String>[
        'PANADERIA LA ESPIGA',
        'D1 LAURELES',
        'CREPES Y WAFFLES',
        'EXITO LAURELES',
        'JUAN VALDEZ',
      ];
      await CaptureService(store, now: () => screensNow).ingest(<CaptureEvent>[
        for (var k = 0; k < 20; k++)
          CaptureEvent(
            source: CaptureSource.notification,
            at: screensNow.subtract(Duration(hours: 3 * k + 1)),
            app: 'com.nequi.MobileApp',
            appName: 'Nequi',
            text:
                'Pagaste \$${4 + k}.${k % 10}00 en ${shops[k % shops.length]} '
                'con tu tarjeta *9876',
          ),
      ]);
      return store;
    }))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.byTooltip('Por revisar'));
    await settle(tester);
    await shoot('inbox-many');
  });

  testWidgets('coming days', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await shoot('home-coming');
    await tester.tap(find.text('Ver 30 días'));
    await settle(tester);
    await shoot('coming');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    // ¿Me alcanza? starts on Inicio, with the price at hand.
    await reach(tester, find.widgetWithText(TextField, 'Precio'));
    await tester.enterText(find.widgetWithText(TextField, 'Precio'), '350000');
    await tester.tap(find.text('Ver'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Qué es? (opcional)'),
      'Audífonos',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await shoot('buy');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await reach(tester, find.text('Cierre de la quincena'));
    await tester.tap(find.text('Cierre de la quincena'));
    await settle(tester);
    await shoot('close');
  });

  testWidgets('plan', (tester) async {
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = await seeded();
      await store.addGoal(
        name: 'Viaje a Cartagena',
        target: Money(Decimal.parse('2400000'), Asset.cop),
        saved: Money(Decimal.parse('650000'), Asset.cop),
        monthly: Money(Decimal.parse('300000'), Asset.cop),
      );
      return store;
    }))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Plan'));
    await settle(tester);
    await shoot('plan');
    await tester.tap(find.text('Repartir en sobres'));
    await settle(tester);
    await shoot('envelopes');
  });

  testWidgets('commitments', (tester) async {
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = await seeded();
      await addCommitments(store);
      return store;
    }))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Plan'));
    await settle(tester);
    Future<void> visit(String row, String name) async {
      await tester.scrollUntilVisible(
        find.text(row),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // A row above the screen too.
      await tester.ensureVisible(find.text(row));
      await settle(tester);
      await tester.tap(find.text(row));
      await settle(tester);
      await shoot(name);
    }

    await tester.scrollUntilVisible(
      find.text('LO QUE ESTOY PAGANDO'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await settle(tester);
    await shoot('plan-payments');
    await visit('Pagos fijos', 'fixed');
    await tester.tap(find.text('Netflix'));
    await settle(tester);
    await shoot('fixed-sheet');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await visit('Compras a cuotas', 'instalments');
    await tester.tap(find.text('Televisor'));
    await settle(tester);
    await shoot('instalment');
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await visit('Cargos para revisar', 'detective');
  });

  testWidgets('real life', (tester) async {
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = await seeded();
      await addRealLife(store);
      return store;
    }))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Plan'));
    await settle(tester);
    final Finder list = find.byType(Scrollable).first;
    Future<void> visit(String row, String name) async {
      await tester.scrollUntilVisible(find.text(row), 200, scrollable: list);
      // A row above the screen too.
      await tester.ensureVisible(find.text(row));
      await settle(tester);
      await tester.tap(find.text(row));
      await settle(tester);
      await shoot(name);
    }

    await tester.scrollUntilVisible(find.text('Viajes'), 200, scrollable: list);
    await settle(tester);
    await shoot('plan-budget');
    await visit('Ingresos variables', 'freelance');
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await visit('Viajes', 'trips');
    await tester.tap(find.text('Nueva York'));
    await settle(tester);
    await shoot('trip');
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    await visit('Gastos compartidos', 'shared');
    await tester.tap(find.text('Paseo a Guatapé'));
    await settle(tester);
    await shoot('group');
  });

  testWidgets('explained', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, phone, Brightness.light);
    await tester.tap(find.text('Cuentas'));
    await settle(tester);
    await tester.tap(find.text('¿De dónde sale?').first);
    await settle(tester);
    await shoot('total-explained');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.text('Bancolombia').first);
    await settle(tester);
    await tester.tap(find.text('¿De dónde sale?').first);
    await settle(tester);
    await shoot('account-explained');
  });

  testWidgets('desktop', (tester) async {
    final QuincenaStore store = (await tester.runAsync(seeded))!;
    await open(tester, store, desktop, Brightness.dark);
    await shoot('desktop-home');
  });
}
