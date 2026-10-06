// The whole app on Valentina's example account: what only works with the
// person's own accounts says so and does nothing, nothing done in the
// example reaches the person's database, and its conversation tells the
// same figure as its Inicio.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/home_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
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

    // A statement of its own, not a file of the person's.
    await tapText(tester, 'Importar extracto');
    expect(find.byType(StatementPage), findsOneWidget);
    expect(screen(tester), contains('Estudio Lumen'));
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
}
