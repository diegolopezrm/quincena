// The theme and the language a person picks are still there the next time
// the app opens, and stay on the device.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

void main() {
  late QuincenaStore store;

  setUp(() {
    store = QuincenaStore(QuincenaDatabase(NativeDatabase.memory()));
  });

  tearDown(() => store.close());

  /// The settings as the app opens them again.
  Future<AppSettings> reopen() async {
    // What was chosen is written without waiting for it.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final AppSettings settings = AppSettings();
    await settings.keepIn(store);
    return settings;
  }

  test(
    'the theme and the language chosen come back on the next launch',
    () async {
      final AppSettings chosen = AppSettings();
      await chosen.keepIn(store);
      chosen
        ..themeMode = ThemeMode.dark
        ..locale = const Locale('en');

      final AppSettings again = await reopen();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(again.themeMode, ThemeMode.dark);
      expect(again.locale, const Locale('en'));

      // Back to following the phone.
      again
        ..themeMode = ThemeMode.system
        ..locale = null;
      final AppSettings third = await reopen();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(third.themeMode, ThemeMode.system);
      expect(third.locale, isNull);
    },
  );

  test(
    'a first launch follows the phone, and an export leaves them out',
    () async {
      final AppSettings first = AppSettings();
      await first.keepIn(store);
      expect(first.themeMode, ThemeMode.system);
      expect(first.locale, isNull);

      first.themeMode = ThemeMode.light;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final Map<String, Object?> export = await store.exportJson();
      expect(
        (export['settings']! as Map<String, Object?>).keys,
        isNot(contains('app.theme')),
      );
    },
  );
}
