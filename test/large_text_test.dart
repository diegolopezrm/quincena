import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show fakeRates, settle;

/// A phone with the system text size at twice the default, the most
/// Android offers, speaking [language]. iOS's accessibility sizes go
/// further; own_accessibility_test holds the main screens there.
Future<Session> open(WidgetTester tester, [String language = 'es']) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = <Locale>[Locale(language)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(() => Intl.defaultLocale = 'es_CO');
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
    await initializeDateFormatting('en');
  });

  for (final String language in <String>['es', 'en']) {
    testWidgets('the home screen holds at twice the text size, in $language', (
      tester,
    ) async {
      final Session session = await open(tester, language);
      expect(session.language, language);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'the sample, with whose it is and the way to one\'s own, holds at twice '
    'the text size',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final QuincenaStore store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
      );
      addTearDown(() => tester.runAsync(store.close));
      // The app with somewhere to keep one's own accounts, opening on the
      // sample as the web does.
      await tester.pumpWidget(
        QuincenaApp(store: store, startInDemo: true, fetcher: fakeRates()),
      );
      await settle(tester);
      expect(find.text('Cuenta de ejemplo de Valentina'), findsOneWidget);
      expect(find.text('Usar mis cuentas'), findsOneWidget);
      expect(find.text('¿De dónde sale?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  for (final String language in <String>['es', 'en']) {
    for (var i = 0; i < ScriptedAgent.starters.length; i++) {
      testWidgets('answer ${i + 1} holds at twice the text size, in '
          '$language', (tester) async {
        final Session session = await open(tester, language);
        final Future<void> answered = session.ask(
          ScriptedAgent.startersFor(language)[i],
        );
        await tester.pumpAndSettle();
        await answered;
        await tester.pumpAndSettle();

        // Answered, in full, in that language.
        expect(session.language, language);
        expect(session.turns.single.error, isNull);
        expect(session.turns.single.surfaceIds, isNotEmpty);
        expect(tester.takeException(), isNull);
      });
    }
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
