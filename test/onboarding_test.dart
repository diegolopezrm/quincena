// Onboarding reads the day from the app's clock, as everything after it
// does: a payday counted from the device's own day would disagree with
// the home it leads to.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'own_flow_test.dart' show fakeRates, settle;

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  tearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });

  testWidgets('every two weeks counts from the app\'s today', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    // Far from any day the test may run on.
    final DateTime now = DateTime(2031, 2, 7, 10);
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    addTearDown(() => tester.runAsync(store.close));
    await tester.pumpWidget(
      QuincenaApp(
        store: store,
        startInDemo: false,
        fetcher: fakeRates(),
        now: () => now,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Con mis cuentas'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.tap(find.text('Siguiente'));
    await settle(tester);

    expect(
      find.text('Cada 14 días, contando desde el 7 feb 2031'),
      findsOneWidget,
    );
  });
}
