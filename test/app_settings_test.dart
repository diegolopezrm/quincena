import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'own_flow_test.dart' show fakeRates, settle;

QuincenaStore _memory() => QuincenaStore(
  QuincenaDatabase(NativeDatabase.memory()),
  now: () => DateTime(2026, 10, 3, 10),
);

void main() {
  test(
    'the appearance and the language come back on the next launch',
    () async {
      final QuincenaStore store = _memory();
      addTearDown(store.close);
      AppSettings(store: store)
        ..themeMode = ThemeMode.dark
        ..locale = const Locale('en');
      await pumpEventQueue();

      final AppSettings next = AppSettings(store: store);
      await next.load();
      expect(next.themeMode, ThemeMode.dark);
      expect(next.locale, const Locale('en'));

      // Back to following the phone is kept as well.
      next
        ..themeMode = ThemeMode.system
        ..locale = null;
      await pumpEventQueue();
      final AppSettings again = AppSettings(store: store);
      await again.load();
      expect(again.themeMode, ThemeMode.system);
      expect(again.locale, isNull);
    },
  );

  test('a choice made before the kept one is read wins', () async {
    final QuincenaStore store = _memory();
    addTearDown(store.close);
    await store.setSetting('app.theme', 'dark');
    await store.setSetting('app.locale', 'en');
    final AppSettings settings = AppSettings(store: store)
      ..themeMode = ThemeMode.light;
    await settings.load();
    expect(settings.themeMode, ThemeMode.light);
    expect(settings.locale, const Locale('en'));
  });

  testWidgets('the app opens dark and in English when that was chosen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final QuincenaStore store = _memory();
    addTearDown(() => tester.runAsync(store.close));
    Future<void> launch() async {
      await tester.pumpWidget(
        QuincenaApp(
          store: store,
          startInDemo: true,
          fetcher: fakeRates(),
          now: () => DateTime(2026, 10, 3, 10),
        ),
      );
      await settle(tester);
    }

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));

    await launch();
    expect(app().themeMode, ThemeMode.system);
    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    await tester.tap(find.text('Oscuro'));
    await tester.tap(find.text('English'));
    await settle(tester);

    // Closed and opened again: a new app over the same database.
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await launch();
    expect(app().themeMode, ThemeMode.dark);
    expect(app().locale, const Locale('en'));
    expect(find.byTooltip('Settings'), findsOneWidget);
  });
}
