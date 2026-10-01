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

  testWidgets(
    'every recorded session still renders with the catalog of today',
    (tester) async {
      final List<Recording> recordings =
          await tester.runAsync(loadRecordings) ?? const <Recording>[];
      if (recordings.isEmpty) {
        markTestSkipped('No sessions recorded yet; see tool/record.');
        return;
      }
      for (final Recording recording in recordings) {
        final player = GenUiTracePlayer(
          recording.trace,
          catalog: quincenaCatalog,
        )..seekToEnd();
        final errors = <Object>[];
        final sub = player.controller.onSubmit.listen(errors.add);
        await tester.pumpWidget(
          host(
            Scaffold(
              body: SingleChildScrollView(
                child: GenUiTraceView(player: player),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: recording.asset);
        expect(errors, isEmpty, reason: recording.asset);
        await sub.cancel();
        player.dispose();
      }

      // What Gemini actually asked for, out of what the catalog offers.
      debugPrint(
        genUiCoverage(
          catalog: genUiCatalog,
          traces: <GenUiTrace>[for (final Recording r in recordings) r.trace],
        ).describe(),
      );
    },
  );

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
}
