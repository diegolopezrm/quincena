import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/catalog/subscription_row.dart';
import 'package:quincena/session/session.dart';

import 'fonts.dart';

/// Opens the app on a phone-sized screen with an agent that answers at once.
Future<Session> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The test device speaks English unless told otherwise.
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final session = Session(thinking: Duration.zero);
  addTearDown(session.dispose);
  await tester.pumpWidget(QuincenaApp(session: session));
  await settle(tester);
  return session;
}

/// Lets every animation finish, and fails in seconds rather than minutes
/// when one never does.
Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 20),
);

/// Asks [question] as if it had been typed, and waits for the answer.
///
/// Not awaited: the agent's pause is a timer, and timers in a widget test
/// only run while the test pumps.
Future<void> ask(WidgetTester tester, Session session, String question) async {
  final Future<void> answered = session.ask(question);
  await settle(tester);
  await answered;
}

/// The subscriptions ticked to cancel, in every list on screen.
final Finder ticked = find.byWidgetPredicate(
  (Widget w) => w is Checkbox && w.value == true,
);

/// Names struck through, which only what the person cancelled is.
final Finder struck = find.byWidgetPredicate(
  (Widget w) => w is Text && w.style?.decoration == TextDecoration.lineThrough,
);

/// Ticks [name] to cancel it, in the latest list that has it.
Future<void> tick(WidgetTester tester, String name) => tapIn(
  tester,
  find.byWidgetPredicate(
    (Widget w) =>
        w is Checkbox && w.semanticLabel == 'Seleccionar $name para cancelar',
  ),
);

/// Presses the latest button labelled [label].
Future<void> press(WidgetTester tester, String label) =>
    tapIn(tester, find.text(label));

/// Scrolls the latest of [found] into view and taps it, once the scroll
/// has been laid out.
Future<void> tapIn(WidgetTester tester, Finder found) async {
  await tester.ensureVisible(found.last);
  await settle(tester);
  await tester.tap(found.last);
  await settle(tester);
}

/// Every string on screen, rich text included, for asserting on content
/// that a single widget does not hold.
///
/// Amounts are written with a non-breaking space after the sign, so that
/// `$` never ends a line on its own; it reads as a plain space here.
String screen(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((RichText t) => t.text.toPlainText())
    .join('\n')
    .replaceAll('\u00a0', ' ');

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('es_CO');
  });

  testWidgets('the home screen shows what is free until payday', (
    tester,
  ) async {
    await open(tester);

    expect(screen(tester), contains('Puedes gastar'));
    expect(screen(tester), contains('hasta el 15 de octubre'));
    expect(screen(tester), contains(r'$1.369.300'));
    for (final String question in ScriptedAgent.starters) {
      expect(find.text(question), findsOneWidget);
    }
  });

  testWidgets('where the money went: a habit, not a purchase', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[0]);

    final String text = screen(tester);
    expect(text, contains('Gastaste casi todo lo que entró'));
    // The headphones moved Compras more, but they are one payment. The
    // finding is the category that moved on most of its payments.
    expect(text, contains('Restaurantes subió 75 %'));
    expect(text, contains('Mercado bajó 12 %'));
    expect(text, isNot(contains('Compras subió')));
    // The tiles are formatted on the device by catalog functions.
    expect(text, contains(r'$4.719.400'));
    expect(text, contains('+11 %'));
  });

  testWidgets('the goal recalculates on the device as the slider moves', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[1]);

    expect(screen(tester), contains('Llegas en mayo de 2027'));
    expect(screen(tester), contains('después del 20 de diciembre'));
    final int recorded = session.recorder.build().steps.length;

    // Drag to the right end: $800.000 a month.
    final Finder slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(600, 0));
    await settle(tester);

    expect(screen(tester), contains('Llegas en diciembre de 2026'));
    expect(screen(tester), contains('antes del 20 de diciembre'));
    // The data model changed, and nothing new came from the agent.
    final messages = session.recorder
        .build()
        .steps
        .skip(recorded)
        .where((step) => step.runtimeType.toString() == 'GenUiMessageStep');
    expect(messages, isEmpty);
  });

  testWidgets('cancelling subscriptions: tick, review, then say it is done', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[2]);

    // Nothing comes ticked: the answer only names the unused ones.
    expect(screen(tester), contains('Fit24 gimnasio y Lingo Pro'));
    expect(ticked, findsNothing);
    expect(
      screen(tester),
      contains('Marca las que quieras cancelar para ver cuánto ahorras'),
    );
    expect(screen(tester), isNot(contains('Si cancelas las que marcaste')));

    await tick(tester, 'Fit24 gimnasio');
    expect(screen(tester), contains('Si cancelas las que marcaste'));
    expect(screen(tester), contains(r'$119.000 al mes'));
    expect(find.text('Para cancelar'), findsOneWidget);
    await tick(tester, 'Lingo Pro');
    expect(screen(tester), contains(r'$153.900 al mes'));
    // A tick is a choice, not something done.
    expect(struck, findsNothing);

    await press(tester, 'Revisar las marcadas');

    String text = screen(tester);
    expect(text, contains('ANTES DE CANCELAR'));
    expect(text, contains(r'Vas a cancelar dos: te ahorras $153.900 al mes'));
    expect(text, contains('Quincena no las cancela por ti'));
    // When each one is charged next, soonest first: Lingo Pro on the 20th,
    // then Fit24 on the 1st, already past today.
    expect(text, contains('1 nov'));
    expect(text, contains('20 oct'));
    expect(text.indexOf('20 oct'), lessThan(text.indexOf('1 nov')));
    expect(struck, findsNothing);

    await press(tester, 'Ya las cancelé');

    text = screen(tester);
    expect(text, contains('HECHO POR TI'));
    expect(text, contains('Canceladas: Fit24 gimnasio y Lingo Pro'));
    expect(text, contains('En la demo esto no cambia tus datos.'));
    expect(text, isNot(contains('Cancelo')));
    expect(find.text('Cancelada'), findsNWidgets(2));
    expect(struck, findsNWidgets(2));
  });

  testWidgets('the choice can change before anything is cancelled', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[2]);

    // Reviewing with nothing ticked says so, and keeps them all.
    await press(tester, 'Revisar las marcadas');
    expect(screen(tester), contains('No marcaste ninguna'));

    await tick(tester, 'Lingo Pro');
    await press(tester, 'Revisar las marcadas');
    expect(screen(tester), contains(r'Vas a cancelar una: te ahorras $34.900'));
    expect(find.text('Ya la cancelé'), findsOneWidget);

    // Back to the list, with the one already ticked still ticked.
    await press(tester, 'Cambiar selección');
    final Finder last = find.byWidgetPredicate(
      (Widget w) => w is SubscriptionRow && w.name == 'Lingo Pro',
    );
    expect(tester.widget<SubscriptionRow>(last.last).keep, isFalse);
    expect(struck, findsNothing);
  });

  testWidgets('the expense form checks the amount before saving', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[4]);

    expect(screen(tester), contains(r'Anoto $45.000 en mercado'));
    expect(find.text('Escribe un monto mayor que cero.'), findsNothing);

    // Clear the amount: the agent's own rule says why that is wrong.
    final Finder amount = find.byType(TextField).first;
    await tester.enterText(amount, '');
    await settle(tester);
    expect(find.text('Escribe un monto mayor que cero.'), findsOneWidget);

    await tester.enterText(amount, '52000');
    await settle(tester);
    expect(find.text('Escribe un monto mayor que cero.'), findsNothing);

    await tester.ensureVisible(find.text('Guardar gasto'));
    await tester.tap(find.text('Guardar gasto'));
    await settle(tester);

    expect(screen(tester), contains(r'Listo: $52.000 en mercado'));
    // And the money it took is no longer there to spend.
    expect(
      screen(tester),
      contains(r'Ahora puedes gastar $1.317.300 hasta el 15 de octubre.'),
    );
  });

  testWidgets('against last month: bars and what moved', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[3]);

    expect(screen(tester), contains(r'Gastaste $480.500 más que en agosto'));
    expect(screen(tester), contains('Lo que más cambió'));
  });

  testWidgets('a question the demo does not know offers the ones it does', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, '¿Cuál es la capital de Francia?');

    expect(screen(tester), contains('En la demo respondo estas preguntas'));
  });
}
