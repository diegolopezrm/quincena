// "Borrar todo" leaves nothing of the person on the phone: not the data,
// not the reminders the phone keeps, which name their payments, not the
// keys in the keychain, and not the look they chose, which went with the
// rest.
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
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'own_flow_test.dart' show fakeRates, settle;

const MethodChannel _reminders = MethodChannel('dev.dlsoft.quincena/reminders');
const MethodChannel _keychain = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

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

  testWidgets('it cancels the reminders, forgets the Binance key and goes '
      'back to the phone\'s look', (tester) async {
    final List<String> reminders = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_reminders, (
      MethodCall call,
    ) async {
      reminders.add(call.method);
      return call.method == 'ask' ? true : null;
    });
    final Map<String, String> keychain = <String, String>{
      'binance.key': 'llave',
      'binance.secret': 'secreto',
    };
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_keychain, (
      MethodCall call,
    ) async {
      final Map<Object?, Object?> args =
          (call.arguments as Map<Object?, Object?>?) ?? const {};
      final String? key = args['key'] as String?;
      return switch (call.method) {
        'read' => keychain[key],
        'write' => keychain[key!] = args['value']! as String,
        'delete' => keychain.remove(key),
        'containsKey' => keychain.containsKey(key),
        _ => null,
      };
    });
    addTearDown(() {
      for (final MethodChannel c in <MethodChannel>[_reminders, _keychain]) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(c, null);
      }
    });
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
      await store.setSetting('app.theme', 'dark');
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
    ThemeMode theme() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(theme(), ThemeMode.dark);

    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    // The payday reminder on: the phone keeps reminders that name nothing
    // but are the person's.
    await tester.ensureVisible(find.text('Avisarme el día de pago'));
    await tester.tap(find.text('Avisarme el día de pago'));
    await settle(tester);
    expect(reminders.last, 'schedule');

    await tester.scrollUntilVisible(
      find.text('Borrar todo'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Borrar todo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar todo'));
    await settle(tester);
    await tester.tap(find.text('Borrar todo').last);
    await settle(tester);

    expect(find.text('¿Cómo quieres empezar?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(reminders.last, 'cancel');
    expect(keychain.keys, isNot(contains('binance.key')));
    expect(keychain.keys, isNot(contains('binance.secret')));
    expect(theme(), ThemeMode.system);
    expect(await tester.runAsync(() => store.setting('app.theme')), isNull);
  });
}
