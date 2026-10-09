import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:decimal/decimal.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rate_sources.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'fonts.dart';

/// Rates as the public sources would answer, without the network.
RateFetcher fakeRates() => RateFetcher(
  client: MockClient((http.Request request) async {
    switch (request.url.host) {
      case 'www.datos.gov.co':
        return http.Response(
          jsonEncode(<Object>[
            <String, String>{
              'valor': '4000',
              'vigenciadesde': '2026-10-03T00:00:00.000',
            },
          ]),
          200,
        );
      case 'data-api.binance.vision':
        return http.Response(
          jsonEncode(<String, String>{'price': '80000'}),
          200,
        );
    }
    return http.Response('{}', 404);
  }),
);

/// Every string on screen, with the space that never breaks read as a
/// plain one and without the invisible joiner that holds a sign to its `$`.
String screen(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((RichText t) => t.text.toPlainText())
    .join('\n')
    .replaceAll(' ', ' ')
    .replaceAll(signJoiner, '');

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

  Future<QuincenaStore> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => DateTime(2026, 10, 3, 10),
    );
    addTearDown(() => tester.runAsync(store.close));
    await tester.pumpWidget(
      QuincenaApp(
        store: store,
        startInDemo: false,
        fetcher: fakeRates(),
        now: () => DateTime(2026, 10, 3, 10),
      ),
    );
    await settle(tester);
    return store;
  }

  testWidgets('someone sets up their own accounts and records a payment', (
    tester,
  ) async {
    await openApp(tester);

    // The first screen offers both ways in.
    expect(find.text('Con mis cuentas'), findsOneWidget);
    expect(find.text('Con datos de ejemplo'), findsOneWidget);
    await tester.tap(find.text('Con mis cuentas'));
    await settle(tester);

    // Three questions. First, who: the totals stay in pesos unless
    // changed.
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    expect(find.text('COP · Peso colombiano'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Diego');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);

    // When: twice a month, on the 15th and the 30th, by default.
    expect(find.text('¿Cuándo te pagan?'), findsOneWidget);
    expect(find.text('Los días 15 y 30 de cada mes'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await settle(tester);

    // Where: a peso account and tether on Binance, from the suggestions.
    expect(find.text('¿Dónde tienes tu plata?'), findsOneWidget);
    await tester.tap(find.text('Bancolombia · COP'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '1.500.000',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    await tester.tap(find.text('Binance · USDT'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '100',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(screen(tester), contains(r'$1.500.000'));
    expect(screen(tester), contains('100 USDT'));
    // The last question: with an account there is a figure to show.
    await tester.tap(find.text('Empezar'));
    await settle(tester);

    // Home: Binance is not money to spend, so only the pesos count here.
    expect(screen(tester), contains('Puedes gastar'));
    expect(screen(tester), contains('hasta el 15 de octubre'));
    expect(screen(tester), contains(r'$1.500.000'));
    // Without fixed payments the figure is provisional, and says so; what
    // is left to set up waits under it. The greeting is the sample's, not
    // the person's own home.
    expect(screen(tester), contains('Provisional: faltan tus pagos fijos'));
    expect(screen(tester), contains('TERMINA DE PREPARAR QUINCENA'));
    expect(screen(tester), contains('Tus pagos fijos'));
    expect(screen(tester), isNot(contains('Agrega tus pagos fijos')));
    expect(screen(tester), isNot(contains('Hola, Diego')));
    expect(
      screen(tester),
      contains('Aquí aparecerá tu plata entrando y saliendo.'),
    );

    // A payment at the supermarket: what happened, how much and where; a
    // name the app knows brings its category.
    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    await tester.tap(find.text('Gasté plata'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '45.900');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde o a quién?'),
      'Éxito',
    );
    await settle(tester);
    expect(find.text('Mercado · Bancolombia · Hoy'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(screen(tester), contains('Éxito'));
    expect(screen(tester), contains(r'−$45.900'));
    expect(screen(tester), contains(r'$1.454.100'));

    // Accounts: everything together, tether at 4.000 pesos a dollar.
    await tester.tap(find.text('Cuentas'));
    await settle(tester);
    expect(screen(tester), contains('Patrimonio'));
    expect(screen(tester), contains(r'$1.854.100'));

    // The rates fold into one row; behind it, how tether became pesos.
    expect(screen(tester), isNot(contains(r'USDT $4.000')));
    await tester.ensureVisible(find.text('Ver tasas usadas'));
    await tester.tap(find.text('Ver tasas usadas'));
    await settle(tester);
    expect(screen(tester), contains(r'1 USDT = $4.000'));
    expect(screen(tester), contains(r'USDT se cuenta como 1 US$'));
    expect(
      screen(tester),
      contains(r'Conversión a COP: 1 US$ = $4.000 · TRM oficial del 3 oct'),
    );
  });

  testWidgets(
    'a payment the phone caught waits in the inbox and is confirmed in one tap',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final DateTime at = DateTime(2026, 10, 3, 10);
      final QuincenaStore store = (await tester.runAsync(() async {
        final s = QuincenaStore(
          QuincenaDatabase(NativeDatabase.memory()),
          now: () => at,
        );
        await s.ensureCategories();
        await s.saveProfile(
          const Profile(
            name: 'Diego',
            base: Asset.cop,
            schedule: TwiceMonthly(),
          ),
        );
        await s.setSetting('app.mode', 'own');
        await s.addAccount(
          name: 'Bancolombia',
          kind: AccountKind.bank,
          asset: Asset.cop,
          institution: 'Bancolombia',
          opening: Decimal.parse('1000000'),
        );
        await CaptureService(s, now: () => at).ingest(<CaptureEvent>[
          CaptureEvent(
            source: CaptureSource.notification,
            at: at,
            app: 'com.todo1.mobile',
            text:
                r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES con tu T.Deb *1234',
          ),
        ]);
        return s;
      }))!;
      addTearDown(() => tester.runAsync(store.close));
      await tester.pumpWidget(
        QuincenaApp(
          store: store,
          startInDemo: false,
          fetcher: fakeRates(),
          now: () => at,
        ),
      );
      await settle(tester);

      // The first thing to do, with what doing it changes.
      expect(
        screen(tester),
        contains('Revisa 1 movimiento para actualizar tu saldo'),
      );
      // Until it is confirmed, the figure leaves it out, and says so.
      expect(
        screen(tester),
        contains('Aún no cuenta en lo que puedes gastar.'),
      );
      expect(screen(tester), contains(r'$1.000.000'));
      await tester.tap(find.widgetWithText(FilledButton, 'Revisar'));
      await settle(tester);
      expect(screen(tester), contains('Exito Laureles'));
      expect(screen(tester), contains('Mercado · Bancolombia'));
      expect(screen(tester), contains(r'−$45.900'));

      await tester.tap(find.text('Registrar gasto'));
      await settle(tester);
      expect(screen(tester), contains('Todo al día.'));

      await tester.tap(find.byTooltip('Atrás'));
      await settle(tester);
      expect(screen(tester), isNot(contains('Revisa 1 movimiento')));
      expect(screen(tester), contains(r'$954.100'));
    },
  );

  testWidgets(
    'the sample is the whole app, one tap away, and its bar and settings '
    'lead out of it',
    (tester) async {
      final QuincenaStore store = await openApp(tester);
      await tester.tap(find.text('Con datos de ejemplo'));
      await settle(tester);
      // Valentina's whole account: the figure, the tabs and the inbox.
      expect(find.text('Cuenta de ejemplo de Valentina'), findsOneWidget);
      expect(find.text('Usar mis cuentas'), findsOneWidget);
      expect(screen(tester), contains('Puedes gastar'));
      expect(screen(tester), contains('hasta el 15 de octubre'));
      for (final String tab in <String>[
        'Inicio',
        'Movimientos',
        'Cuentas',
        'Plan',
      ]) {
        expect(find.text(tab), findsWidgets);
      }
      expect(find.byTooltip('Por revisar'), findsOneWidget);
      // None of it is in the person's own database.
      expect(await tester.runAsync(store.profile), isNull);

      await tester.tap(find.byTooltip('Ajustes'));
      await settle(tester);
      expect(find.text('CUENTA DE EJEMPLO'), findsOneWidget);
      expect(find.text('Ver los datos de ejemplo'), findsNothing);
      await tester.tap(find.text('Volver a la primera pantalla'));
      await settle(tester);
      expect(find.text('Con datos de ejemplo'), findsOneWidget);
      expect(find.text('Cuenta de ejemplo de Valentina'), findsNothing);
      expect(await tester.runAsync(() => store.setting('app.mode')), '');
    },
  );

  testWidgets(
    'where the app opens on the sample, its bar leads to onboarding and '
    'back',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => DateTime(2026, 10, 3, 10),
      );
      addTearDown(() => tester.runAsync(store.close));
      // As the web does: no first screen, straight to the sample.
      await tester.pumpWidget(
        QuincenaApp(
          store: store,
          startInDemo: true,
          fetcher: fakeRates(),
          now: () => DateTime(2026, 10, 3, 10),
        ),
      );
      await settle(tester);
      expect(find.text('Con mis cuentas'), findsNothing);
      expect(find.text('Cuenta de ejemplo de Valentina'), findsOneWidget);

      // Its bar says what it is; there is no first screen to go back to.
      await tester.tap(find.text('Cuenta de ejemplo de Valentina'));
      await settle(tester);
      expect(
        screen(tester),
        contains('Valentina es inventada, como todas sus cifras.'),
      );
      expect(find.text('Volver a la primera pantalla'), findsNothing);
      await tester.tap(find.text('Seguir en el ejemplo'));
      await settle(tester);

      await tester.tap(find.text('Usar mis cuentas'));
      await settle(tester);
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Cuenta de ejemplo de Valentina'), findsNothing);

      // Backing out returns to the sample, not to a first screen the web
      // never showed.
      await tester.tap(find.byTooltip('Atrás'));
      await settle(tester);
      expect(find.text('Con mis cuentas'), findsNothing);
      expect(find.text('Cuenta de ejemplo de Valentina'), findsOneWidget);
    },
  );

  testWidgets(
    'setting up asks the pay; the fixed payments wait on Inicio, and the rent '
    'comes out of the figure',
    (tester) async {
      final QuincenaStore store = await openApp(tester);
      await tester.tap(find.text('Con mis cuentas'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Diego');
      await tester.tap(find.text('Siguiente'));
      await settle(tester);

      // Step 2: how much arrives, which is optional.
      expect(find.text('¿Cuánto te llega cada quincena?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '2.400.000');
      await tester.tap(find.text('Siguiente'));
      await settle(tester);
      expect(
        (await tester.runAsync(store.profile))!.pay,
        Decimal.parse('2400000'),
      );

      // Step 3: no figure without an account; said above the button, where
      // nothing covers it, and gone with the first one.
      await tester.tap(find.text('Empezar'));
      await settle(tester);
      expect(find.text('Agrega al menos una cuenta para empezar.'), findsOne);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Paso 3 de 3'), findsOneWidget);
      await tester.tap(find.text('Bancolombia · COP'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
        '1.500.000',
      );
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await settle(tester);
      expect(
        find.text('Agrega al menos una cuenta para empezar.'),
        findsNothing,
      );
      await tester.tap(find.text('Empezar'));
      await settle(tester);

      // Inicio: the figure, and under it what is left, the fixed payments
      // first.
      expect(screen(tester), contains(r'$1.500.000'));
      expect(screen(tester), contains('TERMINA DE PREPARAR QUINCENA'));
      await tester.tap(find.text('Agregar').first);
      await settle(tester);

      // The rent, from the suggestions, due on the 10th.
      expect(find.text('¿Qué pagas fijo?'), findsOneWidget);
      expect(find.text('No tengo pagos fijos'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Arriendo'));
      await settle(tester);
      expect(find.text('Agregar pago fijo'), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextField, '¿Cuánto cobra?'),
        '800.000',
      );
      await tester.tap(find.textContaining('1 de noviembre'));
      await settle(tester);
      final MaterialLocalizations dates = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.tap(find.byTooltip(dates.previousMonthTooltip));
      await settle(tester);
      await tester.tap(find.text('10'));
      await tester.tap(find.text(dates.okButtonLabel));
      await settle(tester);
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await settle(tester);
      expect(screen(tester), contains('Arriendo'));
      expect(screen(tester), contains('próximo cobro el 10 oct'));
      // With one told, there are some.
      expect(find.text('No tengo pagos fijos'), findsNothing);
      await tester.tap(find.text('Listo'));
      await settle(tester);

      // Home: the rent comes out before payday, and nothing is provisional;
      // what was done is ticked, the rest still offered.
      expect(screen(tester), contains(r'$700.000'));
      expect(
        screen(tester),
        contains(r'El próximo: Arriendo, $800.000 el 10 oct'),
      );
      expect(screen(tester), isNot(contains('Provisional')));
      expect(screen(tester), isNot(contains('Agrega tus pagos fijos')));
      expect(screen(tester), contains('2 de 4 listos'));
    },
  );

  testWidgets('saying there are no fixed payments, from Inicio, takes the '
      'figure out of provisional', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Con mis cuentas'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Diego');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);
    await tester.tap(find.text('Siguiente'));
    await settle(tester);
    await tester.tap(find.text('Nequi · COP'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '300.000',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    await tester.tap(find.text('Empezar'));
    await settle(tester);
    expect(screen(tester), contains('Provisional'));

    await tester.tap(find.text('Agregar').first);
    await settle(tester);
    await tester.tap(find.text('No tengo pagos fijos'));
    await settle(tester);
    expect(screen(tester), contains(r'$300.000'));
    expect(screen(tester), isNot(contains('Provisional')));
    expect(screen(tester), isNot(contains('Agrega tus pagos fijos')));
  });
}

/// Pumps until the database, its streams and the animations are done.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}
