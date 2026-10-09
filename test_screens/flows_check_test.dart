// Plays every flow of integration_test/flows/ without a phone, as iOS, and
// fails on a flow that breaks on the way or on any check that does not
// hold. One part of the app at a time:
//
//   flutter test test_screens/flows_check_test.dart --plain-name "flow 04-"
//
// Not part of `flutter test`, like the rest of this folder. With FLOWS_OUT
// set to a folder, it also leaves there what each flow found, as JSON. With
// FLOWS_SHOTS=1 and --update-goldens, it also draws every step to
// test_screens/flows_out/<step>.png, with its line in <step>.txt, to look at
// without a simulator:
//
//   FLOWS_SHOTS=1 flutter test test_screens/flows_check_test.dart \
//     --plain-name "flow 04-" --update-goldens
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../integration_test/flows/flow.dart';
import '../integration_test/flows/flows.dart';
import '../test/fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  final String? out = Platform.environment['FLOWS_OUT'];
  final bool shots = Platform.environment['FLOWS_SHOTS'] == '1';

  for (final AppFlow flow in flows) {
    testWidgets('flow ${flow.id}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // The keychain, as a map: sync and backups keep their keys there.
      useOwnKeychain(tester);
      late FlowRun run;
      try {
        run = await playFlow(
          tester,
          flow,
          (String name, String caption) async {
            if (!shots) return;
            Directory('test_screens/flows_out').createSync(recursive: true);
            File('test_screens/flows_out/$name.txt').writeAsStringSync(caption);
            await expectLater(
              find.byType(MaterialApp).first,
              matchesGoldenFile('flows_out/$name.png'),
            );
          },
          // An iPhone 17 Pro.
          size: const Size(402, 874),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      final List<Check> failed = <Check>[
        for (final Check c in run.checks)
          if (!c.ok) c,
      ];
      print(
        '${flow.id}: ${run.captions.length} steps, '
        '${run.checks.length - failed.length}/${run.checks.length} checks'
        '${run.error == null ? '' : ', BROKE'}',
      );
      for (final Check c in failed) {
        print('  FAILED ${c.what}: ${c.detail}');
      }
      if (run.error != null) print('  BROKE: ${run.error}');
      if (out != null) {
        Directory(out).createSync(recursive: true);
        File(
          '$out/${flow.id}.json',
        ).writeAsStringSync(jsonEncode(run.toJson()));
      }
      expect(run.error, isNull, reason: 'the flow broke on the way');
      expect(
        failed.map((Check c) => c.what).toList(),
        isEmpty,
        reason: 'checks that did not hold',
      );
    });
  }
}
