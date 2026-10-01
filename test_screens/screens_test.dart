// Renders the demo's screens to PNG, for review and for the README.
//
// Not part of `flutter test`: images drawn by the test engine differ slightly
// between operating systems, so comparing them in CI would fail for reasons
// that have nothing to do with the app. Regenerate with:
//
//   flutter test test_screens --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';

import '../test/fonts.dart';

const Map<String, Size> sizes = <String, Size>{
  'phone': Size(390, 844),
  'desktop': Size(1280, 900),
};

Future<Session> open(
  WidgetTester tester,
  Size size,
  Brightness brightness,
) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final session = Session(thinking: Duration.zero);
  addTearDown(session.dispose);
  await tester.pumpWidget(QuincenaApp(session: session));
  await tester.pumpAndSettle();
  return session;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  for (final MapEntry<String, Size> size in sizes.entries) {
    for (final Brightness brightness in Brightness.values) {
      final String tag = '${size.key}-${brightness.name}';

      testWidgets('home $tag', (tester) async {
        await open(tester, size.value, brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/home-$tag.png'),
        );
      });

      for (var i = 0; i < ScriptedAgent.starters.length; i++) {
        testWidgets('answer $i $tag', (tester) async {
          final Session session = await open(tester, size.value, brightness);
          final Future<void> answered = session.ask(ScriptedAgent.starters[i]);
          await tester.pumpAndSettle();
          await answered;
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/answer-$i-$tag.png'),
          );
        });
      }
    }
  }
}
