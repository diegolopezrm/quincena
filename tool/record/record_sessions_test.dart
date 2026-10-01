// Records real Gemini sessions for the questions on the home screen.
//
//   GEMINI_API_KEY=... flutter test tool/record
//
// Each question gets a fresh account and conversation. What the model sent is
// written to assets/traces as a genui_gen trace, which the app replays in
// "Lo que respondió Gemini" and which test/recorded_test.dart replays against
// the current catalog on every run. A picture of each answer goes to
// tool/record/out, for looking at, not for committing.
//
// Not part of `flutter test`: it needs a key and the network, and its output
// changes every time the model answers differently.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/tracing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';

import '../../test/fonts.dart';

String slug(String question) => question
    .toLowerCase()
    .replaceAll(RegExp('[¿?]'), '')
    .replaceAll(RegExp('[áä]'), 'a')
    .replaceAll(RegExp('[éë]'), 'e')
    .replaceAll(RegExp('[íï]'), 'i')
    .replaceAll(RegExp('[óö]'), 'o')
    .replaceAll(RegExp('[úü]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

void main() {
  final String key = Platform.environment['GEMINI_API_KEY'] ?? '';

  setUpAll(() async {
    // Widget tests answer every HTTP request with a 400; this one talks to
    // Gemini.
    HttpOverrides.global = null;
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    autoUpdateGoldenFiles = true;
  });

  if (key.isEmpty) {
    test('needs a key', () {
      print('Set GEMINI_API_KEY to record. Nothing was recorded.');
    });
  }

  for (var i = 0; i < ScriptedAgent.starters.length; i++) {
    final String question = ScriptedAgent.starters[i];
    final String name =
        '${(i + 1).toString().padLeft(2, '0')}-${slug(question)}';

    testWidgets(
      'records "$question"',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final session = Session(mode: AgentMode.live, apiKey: key);
        addTearDown(session.dispose);
        await tester.pumpWidget(QuincenaApp(session: session));
        await tester.pumpAndSettle();

        final watch = Stopwatch()..start();
        await tester.runAsync(() => session.ask(question));
        watch.stop();
        await tester.pumpAndSettle();

        final GenUiTrace trace = session.recorder.build();
        final Map<String, Object?> json =
            jsonDecode(trace.encode()) as Map<String, Object?>;
        json['notes'] = <String, Object?>{
          ...?(json['notes'] as Map?)?.cast<String, Object?>(),
          'question': question,
          'model': GeminiClient.defaultModel,
          'seconds': watch.elapsedMilliseconds / 1000,
        };
        File('assets/traces/$name.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(json)}\n',
        );

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('out/$name.png'),
        );

        final List<GenUiMessageStep> messages = trace.steps
            .whereType<GenUiMessageStep>()
            .toList();
        final Map<String, int> components = <String, int>{};
        for (final GenUiMessageStep step in messages) {
          final Object? update = step.message['updateComponents'];
          if (update is! Map) continue;
          for (final Object? c in update['components'] as List? ?? const []) {
            if (c is Map && c['component'] is String) {
              components.update(
                c['component']! as String,
                (int n) => n + 1,
                ifAbsent: () => 1,
              );
            }
          }
        }
        final int errors = trace.steps
            .whereType<GenUiEventStep>()
            .where((GenUiEventStep e) => '${e.event}'.contains('"error"'))
            .length;
        final Turn turn = session.turns.single;
        print(
          '\n$name  ${watch.elapsed.inSeconds}s  '
          'surfaces ${turn.surfaceIds.length}  messages ${messages.length}  '
          'errors reported $errors${turn.error == null ? '' : '  FAILED: ${turn.error}'}\n'
          '  components ${components.entries.map((e) => '${e.key}×${e.value}').join(', ')}\n'
          '  text "${turn.text.toString().trim()}"',
        );
        expect(turn.error, isNull);
        expect(turn.surfaceIds, isNotEmpty);
      },
      skip: key.isEmpty,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
