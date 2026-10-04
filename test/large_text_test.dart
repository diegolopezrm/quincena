import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('cancelling subscriptions holds at twice the text size', (
    tester,
  ) async {
    final Session session = await open(tester);
    final Future<void> answered = session.ask(ScriptedAgent.starters[2]);
    await tester.pumpAndSettle();
    await answered;

    // Ticked rows carry a tag next to the box; the summary and the receipt
    // come after.
    Future<void> tap(Finder found) async {
      await tester.ensureVisible(found.last);
      await tester.pumpAndSettle();
      await tester.tap(found.last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    for (final String name in <String>['Fit24 gimnasio', 'Lingo Pro']) {
      await tap(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Checkbox &&
              w.semanticLabel == 'Seleccionar $name para cancelar',
        ),
      );
    }
    expect(find.text('Para cancelar'), findsNWidgets(2));
    // The tag never squeezes the name: the person reads what they ticked.
    for (final String name in <String>['Fit24 gimnasio', 'Lingo Pro']) {
      expect(
        tester.renderObject<RenderParagraph>(find.text(name).last),
        isA<RenderParagraph>().having(
          (RenderParagraph p) => p.didExceedMaxLines,
          'cut short',
          isFalse,
        ),
      );
    }
    await tap(find.text('Revisar las marcadas'));
    await tap(find.text('Ya las cancelé'));
    expect(find.text('Cancelada'), findsNWidgets(2));
  });
}
