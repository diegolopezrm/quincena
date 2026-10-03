// Walks the tour of integration_test/tour.dart without a phone, as iOS,
// to check every step still finds its way before the simulator plays it.
//
// Not part of `flutter test`, like the rest of this folder:
//
//   flutter test test_screens/tour_check_test.dart
// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../integration_test/tour.dart';
import '../test/fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  for (final Scene scene in scenes) {
    testWidgets(scene.name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // The keychain, as a map: sync and backups keep their keys there.
      final Map<String, String> keychain = <String, String>{};
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _keychain,
        (MethodCall call) async {
          final Map<Object?, Object?> args =
              (call.arguments as Map<Object?, Object?>?) ?? const {};
          final String? key = args['key'] as String?;
          return switch (call.method) {
            'read' => keychain[key],
            'write' => keychain[key!] = args['value']! as String,
            'delete' => keychain.remove(key),
            'containsKey' => keychain.containsKey(key),
            'readAll' => keychain,
            'deleteAll' => keychain.clear(),
            _ => null,
          };
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _keychain,
          null,
        ),
      );
      final List<String> taken = <String>[];
      try {
        await playScene(
          tester,
          scene,
          (String name) async => taken.add(name),
          // An iPhone 17 Pro.
          size: const Size(402, 874),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        print('${scene.name}: ${taken.length} pictures');
      }
    });
  }
}

const MethodChannel _keychain = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
