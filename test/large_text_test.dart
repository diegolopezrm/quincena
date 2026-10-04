import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';

import 'fonts.dart';

/// A phone with the system text size at twice the default, which is as far
/// as the accessibility settings of both platforms go.
Future<Session> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

  testWidgets('the home screen holds at twice the text size', (tester) async {
    await open(tester);
    expect(tester.takeException(), isNull);
  });

  for (var i = 0; i < ScriptedAgent.starters.length; i++) {
    testWidgets('answer ${i + 1} holds at twice the text size', (tester) async {
      final Session session = await open(tester);
      final Future<void> answered = session.ask(ScriptedAgent.starters[i]);
      await tester.pumpAndSettle();
      await answered;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the goal planner holds at twice the text size as it moves', (
    tester,
  ) async {
    final Session session = await open(tester);
    final Future<void> answered = session.ask(ScriptedAgent.starters[1]);
    await tester.pumpAndSettle();
    await answered;
    await tester.pumpAndSettle();

    // Away from today's amount, with the simulation line and its way back.
    final Finder use = find.text(r'Usar $600.000 al mes');
    await tester.ensureVisible(use);
    await tester.pumpAndSettle();
    await tester.tap(use);
    await tester.pumpAndSettle();
    expect(find.text(r'Volver a $250.000'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // And the dialog that takes an exact amount.
    await tester.ensureVisible(find.byTooltip('Escribir monto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Escribir monto'));
    await tester.pumpAndSettle();
    expect(find.text('Usar este monto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
