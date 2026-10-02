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

String screen(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((RichText t) => t.text.toPlainText())
    .join('\n')
    .replaceAll(' ', ' ');

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

    // Step 1: who, and in which currency the totals go.
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Diego');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);

    // Step 2: twice a month, on the 15th and the 30th, by default.
    expect(find.text('¿Cómo te pagan?'), findsOneWidget);
    expect(find.text('Los días 15 y 30 de cada mes'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await settle(tester);

    // Step 3: a peso account and tether on Binance, from the suggestions.
    expect(find.text('Agrega tus cuentas'), findsOneWidget);
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
    expect(screen(tester), contains(r'$ 1.500.000'));
    expect(screen(tester), contains('100 USDT'));

    await tester.tap(find.text('Empezar'));
    await settle(tester);

    // Home: Binance is not money to spend, so only the pesos count here.
    expect(screen(tester), contains('Libre hasta el 15 de octubre'));
    expect(screen(tester), contains(r'$ 1.500.000'));
    expect(screen(tester), contains('Aún no hay movimientos.'));

    // A payment at the supermarket.
    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '45.900');
    await tester.tap(find.text('Mercado'));
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde o a quién?'),
      'Éxito',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(screen(tester), contains('Éxito'));
    expect(screen(tester), contains(r'−$ 45.900'));
    expect(screen(tester), contains(r'$ 1.454.100'));

    // Accounts: everything together, tether at 4.000 pesos a dollar.
    await tester.tap(find.text('Cuentas'));
    await settle(tester);
    expect(screen(tester), contains('Todo lo que tienes'));
    expect(screen(tester), contains(r'$ 1.854.100'));
    expect(screen(tester), contains(r'1 USDT = $ 4.000'));
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

      expect(screen(tester), contains('Un movimiento por revisar'));
      await tester.tap(find.text('Un movimiento por revisar'));
      await settle(tester);
      expect(screen(tester), contains('Exito Laureles'));
      expect(screen(tester), contains('Mercado · Bancolombia'));
      expect(screen(tester), contains(r'−$ 45.900'));

      await tester.tap(find.text('Confirmar'));
      await settle(tester);
      expect(screen(tester), contains('Nada por revisar.'));

      await tester.tap(find.byTooltip('Atrás'));
      await settle(tester);
      expect(screen(tester), isNot(contains('por revisar')));
      expect(screen(tester), contains(r'$ 954.100'));
    },
  );

  testWidgets(
    'the sample is one tap away, and the way back is in its settings',
    (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Con datos de ejemplo'));
      await settle(tester);
      expect(screen(tester), contains('Hola, Valentina'));

      await tester.tap(find.byTooltip('Ajustes'));
      await settle(tester);
      expect(find.text('Usar con mis cuentas'), findsOneWidget);
    },
  );
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
