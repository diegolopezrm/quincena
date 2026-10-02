import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'own_flow_test.dart' show fakeRates, settle;

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  tearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });

  testWidgets('the pay and the cushion are set in Settings, and can go', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => now,
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await store.setSetting('app.mode', 'own');
      await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: Decimal.parse('900000'),
      );
      return store;
    }))!;
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
    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    expect(find.text('Sin definir'), findsNWidgets(2));

    await tester.tap(find.text('Colchón'));
    await settle(tester);
    expect(
      find.textContaining('Lo libre hasta el pago lo deja por fuera'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '150000');
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(
      (await tester.runAsync(store.profile))!.cushion,
      Decimal.parse('150000'),
    );
    expect(find.textContaining('150.000'), findsOneWidget);

    await tester.tap(find.text('Lo que te pagan'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '2.400.000');
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(
      (await tester.runAsync(store.profile))!.pay,
      Decimal.parse('2400000'),
    );

    // An amount set can be taken away again.
    await tester.tap(find.text('Colchón'));
    await settle(tester);
    await tester.tap(find.text('Quitar'));
    await settle(tester);
    expect((await tester.runAsync(store.profile))!.cushion, isNull);
    expect(find.text('Sin definir'), findsOneWidget);
  });
}
