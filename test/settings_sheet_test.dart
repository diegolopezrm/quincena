// The web demo's settings sheet is where the theme is chosen, so it changes
// with it while it is open. On a phone the conversation has no sheet of its
// own: the language and the look are the app's.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/showcase.dart';
import 'package:quincena/theme/theme.dart';

import 'fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('picking dark in the open sheet turns the sheet dark too, not '
      'only what is on it', (tester) async {
    debugShowcaseOverride = true;
    addTearDown(() => debugShowcaseOverride = null);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final Session session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();

    Color sheet() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;
    final Color light = quincenaTheme(Brightness.light).colorScheme.surface;
    final Color dark = quincenaTheme(Brightness.dark).colorScheme.surface;
    expect(sheet(), light);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(sheet(), dark);
  });

  testWidgets('in the web demo, «Conectar» with no key says it is missing', (
    tester,
  ) async {
    debugShowcaseOverride = true;
    addTearDown(() => debugShowcaseOverride = null);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final Session session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tu key'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Conectar'));
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(find.text('Pega tu key de Gemini para conectar.'), findsOneWidget);
    // The sheet stays, waiting for it.
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'x');
    await tester.pumpAndSettle();
    expect(find.text('Pega tu key de Gemini para conectar.'), findsNothing);
  });

  testWidgets('in the web demo, picking another language keeps the '
      'conversation, and the next answer comes in it', (tester) async {
    debugShowcaseOverride = true;
    addTearDown(() => debugShowcaseOverride = null);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final Session session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    final Future<void> asked = session.ask(ScriptedAgent.starters[3]);
    await tester.pumpAndSettle();
    await asked;

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    // What was asked in Spanish is still there.
    expect(session.language, 'en');
    expect(session.turns.single.question, ScriptedAgent.starters[3]);
    expect(find.text(ScriptedAgent.starters[3]), findsOneWidget);

    final Future<void> again = session.ask(ScriptedAgent.startersEn[3]);
    await tester.pumpAndSettle();
    await again;
    expect(session.turns, hasLength(2));
    expect(
      find.textContaining('more than in August', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('on a phone, the conversation has no settings of its own', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final Session session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ajustes'), findsNothing);
  });
}
