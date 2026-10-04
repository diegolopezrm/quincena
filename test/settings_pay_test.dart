import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/reminders/reminders.dart';
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
      find.textContaining('No cuenta en lo que puedes gastar hasta el pago'),
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
  test('reminders fall on the next six paydays, at nine', () {
    expect(
      Reminders.days(const TwiceMonthly(), DateTime(2026, 10, 3, 10)),
      <DateTime>[
        DateTime(2026, 10, 15, 9),
        DateTime(2026, 10, 30, 9),
        DateTime(2026, 11, 15, 9),
        DateTime(2026, 11, 30, 9),
        DateTime(2026, 12, 15, 9),
        DateTime(2026, 12, 30, 9),
      ],
    );
  });

  for (final bool allowed in <bool>[true, false]) {
    testWidgets('the payday reminder, ${allowed ? 'allowed' : 'turned down'}', (
      tester,
    ) async {
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.dlsoft.quincena/reminders'),
        (MethodCall call) async {
          calls.add(call);
          return call.method == 'ask' ? allowed : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.dlsoft.quincena/reminders'),
          null,
        ),
      );
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
      await tester.ensureVisible(find.text('Avisarme el día de pago'));
      await tester.tap(find.text('Avisarme el día de pago'));
      await settle(tester);

      expect(calls.first.method, 'ask');
      if (!allowed) {
        expect(
          find.textContaining('permite las notificaciones de Quincena'),
          findsOneWidget,
        );
        expect(calls.where((MethodCall c) => c.method == 'schedule'), isEmpty);
        return;
      }
      final MethodCall set = calls.lastWhere(
        (MethodCall c) => c.method == 'schedule',
      );
      final List<Object?> items =
          (set.arguments as Map<Object?, Object?>)['items']! as List<Object?>;
      expect(items, hasLength(6));
      for (final Object? item in items) {
        final Map<Object?, Object?> i = item! as Map<Object?, Object?>;
        expect(i['title'], 'Tu cierre de quincena está listo');
        // Nothing about the money: no amount, not even a digit.
        expect('${i['title']} ${i['body']}', isNot(contains(RegExp(r'[\d$]'))));
      }
      expect(
        (items.first! as Map<Object?, Object?>)['at'],
        DateTime(2026, 10, 15, 9).millisecondsSinceEpoch,
      );

      await tester.tap(find.text('Avisarme el día de pago'));
      await settle(tester);
      expect(calls.last.method, 'cancel');
    });
  }
}
