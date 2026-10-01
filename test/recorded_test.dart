import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/testing.dart';
import 'package:genui_gen/tracing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/catalog.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/genui_catalog.g.dart';
import 'package:quincena/session/recordings.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/recorded_page.dart';

import 'fonts.dart';

Widget host(Widget child) =>
    MaterialApp(theme: quincenaTheme(Brightness.light), home: child);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  // One test per recording, read from disk when the suite is defined, so
  // each replays on a fresh tree and a failure names the session it was.
  final List<File> files =
      Directory('assets/traces')
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.json'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  for (final File file in files) {
    testWidgets('${file.uri.pathSegments.last} still renders today', (
      tester,
    ) async {
      final player = GenUiTracePlayer(
        GenUiTrace.decode(file.readAsStringSync()),
        catalog: quincenaCatalog,
      )..seekToEnd();
      addTearDown(player.dispose);
      final errors = <Object>[];
      player.controller.onSubmit.listen(errors.add);

      await tester.pumpWidget(
        host(
          Scaffold(
            body: SingleChildScrollView(child: GenUiTraceView(player: player)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(errors, isEmpty);
      expect(player.currentSurfaceId, isNotNull);
    });
  }

  if (files.isNotEmpty) {
    test('what the recorded sessions used of the catalog', () {
      // Informational: which components a real model asked for, out of what
      // the catalog offers, and what the unused ones cost every request.
      debugPrint(
        genUiCoverage(
          catalog: genUiCatalog,
          traces: <GenUiTrace>[
            for (final File f in files) GenUiTrace.decode(f.readAsStringSync()),
          ],
        ).describe(),
      );
    });
  }

  testWidgets('a recording replays step by step', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // A recording made here, from the script, stands in for a real one.
    final session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    final Future<void> answered = session.ask(ScriptedAgent.starters[0]);
    // The agent's pause is a timer; pumping is what lets it run.
    await tester.pumpAndSettle();
    await answered;
    final GenUiTrace trace = GenUiTrace(
      steps: session.recorder.build().steps,
      catalogId: quincenaCatalog.catalogId,
      notes: <String, Object?>{
        'question': ScriptedAgent.starters[0],
        'model': 'gemini-3-flash-preview',
      },
    );

    await tester.pumpWidget(
      host(
        ReplayPage(
          recording: Recording(trace: trace, asset: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gastaste casi todo lo que entró'), findsOneWidget);
    expect(
      find.text('${trace.steps.length} de ${trace.steps.length}'),
      findsOneWidget,
    );

    // Back to before the answer: nothing on screen yet.
    final Finder slider = find.byType(Slider);
    await tester.drag(slider, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(find.text('Antes de la respuesta'), findsOneWidget);
    expect(find.text('Gastaste casi todo lo que entró'), findsNothing);
  });

  testWidgets('the list gives each session its time the Spanish way', (
    tester,
  ) async {
    final trace = GenUiTrace(
      steps: const <GenUiTraceStep>[],
      notes: <String, Object?>{
        'question': '¿Qué suscripciones tengo?',
        'model': 'gemini-3-flash-preview',
        'seconds': 22.712,
      },
    );
    await tester.pumpWidget(
      host(
        RecordedPage(
          recordings: <Recording>[Recording(trace: trace, asset: 'test')],
        ),
      ),
    );

    // A decimal comma, and a number that never ends a line without its unit.
    expect(
      find.text('gemini-3-flash-preview · 0 pasos · 22,7 s'),
      findsOneWidget,
    );
  });
}
