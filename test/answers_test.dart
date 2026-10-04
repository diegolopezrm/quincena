import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface, UserActionEvent;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/catalog/goal_planner.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/ui/conversation.dart';
import 'package:quincena/ui/own/free_explained.dart';

import 'fonts.dart';

/// Opens the app on a phone-sized screen with an agent that answers at once,
/// or after [thinking].
Future<Session> open(
  WidgetTester tester, {
  Duration thinking = Duration.zero,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The test device speaks English unless told otherwise.
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final session = Session(thinking: thinking);
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

/// Every string on screen that is not inside a GoalPlanner.
List<String> outsideThePlanner(WidgetTester tester) {
  final Set<RichText> inside = tester
      .widgetList<RichText>(
        find.descendant(
          of: find.byType(GoalPlanner),
          matching: find.byType(RichText),
        ),
      )
      .toSet();
  return <String>[
    for (final RichText t in tester.widgetList<RichText>(find.byType(RichText)))
      if (!inside.contains(t)) t.text.toPlainText(),
  ];
}

/// Whether the top of what [finder] finds is within the screen.
bool onScreen(WidgetTester tester, Finder finder) {
  final double top = tester.getTopLeft(finder).dy;
  return top >= 0 && top < tester.view.physicalSize.height / 3;
}

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

  testWidgets('the sample card says where its figure comes from', (
    tester,
  ) async {
    final Session session = await open(tester);
    final Ledger ledger = session.ledger;
    await tester.tap(find.text('¿De dónde sale?'));
    await settle(tester);
    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(LedgerExplained), matching: f);
    expect(
      inSheet(find.text('Así se calcula lo que puedes gastar')),
      findsOneWidget,
    );
    // The same sum as the card, from the sample's ledger alone.
    expect(inSheet(find.text('En tus cuentas de uso diario')), findsOneWidget);
    expect(
      inSheet(find.text(pesos(ledger.major(ledger.balance)))),
      findsOneWidget,
    );
    expect(
      inSheet(find.text(pesos(ledger.major(ledger.freeUntilPayday)))),
      findsOneWidget,
    );
    expect(inSheet(find.text(r'$1.369.300')), findsOneWidget);
    // And what it assumes, further down.
    await tester.scrollUntilVisible(
      inSheet(find.textContaining('Es una estimación')),
      120,
      scrollable: find
          .descendant(
            of: find.byType(LedgerExplained),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(inSheet(find.textContaining('Es una estimación')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

    // The answer leads with what it takes, which no slider changes.
    String text = screen(tester);
    expect(
      text,
      contains(r'Para llegar el 20 de diciembre necesitas $600.000 al mes'),
    );
    expect(
      text,
      contains(
        r'Hoy apartas $250.000: te faltan $350.000 al mes. Cuento 3 aportes: '
        '16 de octubre, 16 de noviembre y 16 de diciembre.',
      ),
    );
    expect(text, contains('Llegas en mayo de 2027'));
    expect(text, contains('después del 20 de diciembre'));
    expect(text, contains(r'Son 8 aportes de $250.000'));
    // $600.000 is in the title, on the slider's mark and on the button that
    // uses it: no tile repeats it.
    expect(text, isNot(contains('Necesitas al mes')));
    expect(r'$600.000'.allMatches(text), hasLength(3));
    final int recorded = session.recorder.build().steps.length;

    // Drag to the right end: $800.000 a month.
    final Finder slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await settle(tester);
    final List<String> outside = outsideThePlanner(tester);
    await tester.drag(slider, const Offset(600, 0));
    await settle(tester);

    text = screen(tester);
    expect(text, contains('Llegas en diciembre de 2026'));
    expect(text, contains('antes del 20 de diciembre'));
    expect(
      text,
      contains(
        r'Son 3 aportes de $800.000, del 16 de octubre al 16 de diciembre.',
      ),
    );
    expect(text, contains(r'Simulación · hoy apartas $250.000'));
    expect(
      text,
      contains(
        r'Desde la quincena del 15 de octubre tendrías $550.000 menos al mes '
        'para gastar que hoy.',
      ),
    );
    // Nothing outside the planner says what depends on it, so nothing
    // outside it changed.
    expect(outsideThePlanner(tester), outside);
    expect(text, isNot(contains('No con lo que apartas hoy')));
    expect(text, isNot(contains('Mueve el control')));

    // What it takes, in one tap: the planner follows, the answer stays.
    await tester.tap(find.text(r'Usar $600.000 al mes'));
    await settle(tester);
    text = screen(tester);
    expect(
      text,
      contains(
        r'Desde la quincena del 15 de octubre tendrías $350.000 menos al mes '
        'para gastar que hoy.',
      ),
    );
    expect(
      text,
      contains(
        r'Hasta el 15 de octubre puedes gastar $1.369.300: el aporte sale el '
        '16 de octubre, así que no lo toca.',
      ),
    );
    expect(outsideThePlanner(tester), outside);
    // The data model changed, and nothing new came from the agent.
    final messages = session.recorder
        .build()
        .steps
        .skip(recorded)
        .where((step) => step.runtimeType.toString() == 'GenUiMessageStep');
    expect(messages, isEmpty);
  });

  testWidgets('a saved plan is where the next answer starts', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[1]);
    final Finder use = find.text(r'Usar $600.000 al mes');
    await tester.ensureVisible(use);
    await settle(tester);
    await tester.tap(use);
    await settle(tester);
    await tester.ensureVisible(find.text('Guardar este plan'));
    await settle(tester);
    await tester.tap(find.text('Guardar este plan'));
    await settle(tester);
    expect(
      screen(tester),
      contains(r'Tu plan: $600.000 al mes para Cartagena'),
    );

    await ask(tester, session, ScriptedAgent.starters[1]);
    final String text = screen(tester);
    expect(
      text,
      contains(r'Sí: con $600.000 al mes llegas antes del 20 de diciembre'),
    );
    // The title has the amount and the date: the body does not say them
    // again.
    expect(
      text,
      contains(
        'Es justo lo que hace falta. Cuento 3 aportes: 16 de octubre, 16 de '
        'noviembre y 16 de diciembre.',
      ),
    );
    expect(text, isNot(contains('bastan')));
    // On what it takes, there is no simulation and nothing to use.
    expect(find.text(r'Usar $600.000 al mes'), findsNothing);
  });

  testWidgets('switching a subscription off updates the savings', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[2]);

    // The two nobody has used in a month start switched off.
    expect(screen(tester), contains(r'$153.900 al mes'));

    // Switch off one more: the row after the two stale ones is Cineplus,
    // which costs $38.900.
    final Finder on = find.byWidgetPredicate(
      (Widget w) => w is Switch && w.value,
    );
    await tester.ensureVisible(on.first);
    await tester.tap(on.first);
    await settle(tester);

    expect(screen(tester), contains(r'$192.800 al mes'));
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
    // And the money it took is no longer free.
    expect(screen(tester), contains(r'$1.317.300 libres'));
  });

  testWidgets('against last month: bars and what moved', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[3]);

    expect(screen(tester), contains(r'Gastaste $480.500 más que en agosto'));
    expect(screen(tester), contains('Lo que más cambió'));
  });

  testWidgets('two taps save one expense, and Editar corrects it', (
    tester,
  ) async {
    final Session session = await open(tester);
    final List<Movement> before = List<Movement>.of(session.ledger.movements);
    List<Movement> added() => <Movement>[
      for (final Movement m in session.ledger.movements)
        if (!before.contains(m)) m,
    ];
    await ask(tester, session, ScriptedAgent.starters[4]);
    final String form = session.turns.single.surfaceIds.single;

    await tester.enterText(find.byType(TextField).first, '52000');
    await settle(tester);
    final Finder save = find.text('Guardar gasto');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.tap(save);
    await settle(tester);

    expect(added().single.amount, 52000);
    expect(session.ledger.freeUntilPayday, 1369300 - 52000);
    expect(screen(tester), contains(r'$1.317.300'));
    expect(find.textContaining('Gasto guardado · '), findsOneWidget);
    // The answer keeps a turn of its own, under what the person did.
    expect(find.text('Guardaste el gasto'), findsOneWidget);

    // The form takes nothing more: not a tap, not an action sent to it.
    await tester.tap(save, warnIfMissed: false);
    session.controller.handleUiEvent(
      UserActionEvent(
        surfaceId: form,
        name: 'save_expense',
        sourceComponentId: 'save',
        context: <String, Object?>{'amount': 52000, 'category': 'groceries'},
      ),
    );
    await settle(tester);
    expect(session.turns, hasLength(2));
    expect(added(), hasLength(1));
    expect(session.ledger.freeUntilPayday, 1369300 - 52000);

    // Editar opens the form again, and saving corrects the same expense.
    await tester.ensureVisible(find.text('Editar'));
    await settle(tester);
    await tester.tap(find.text('Editar'));
    await settle(tester);
    expect(find.textContaining('Gasto guardado · '), findsNothing);
    await tester.enterText(find.byType(TextField).first, '60000');
    await settle(tester);
    await tester.ensureVisible(save);
    await settle(tester);
    await tester.tap(save);
    await settle(tester);

    expect(session.turns, hasLength(3));
    expect(added().single.amount, 60000);
    expect(session.ledger.freeUntilPayday, 1369300 - 60000);
    expect(find.textContaining('Gasto guardado · '), findsOneWidget);

    // From the receipt, the answer it got is a tap away.
    final Finder corrected = find.byWidgetPredicate(
      (Widget w) =>
          w is Surface &&
          w.surfaceContext.surfaceId == session.turns.last.surfaceIds.single,
    );
    await tester.drag(find.byType(FollowedScroll), const Offset(0, 3000));
    await settle(tester);
    expect(onScreen(tester, corrected), isFalse);
    await tester.tap(find.text('Ver resultado'));
    await settle(tester);
    expect(onScreen(tester, corrected), isTrue);
  });

  testWidgets('a save nothing came of leaves the form open', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[4]);
    final String form = session.turns.single.surfaceIds.single;

    await tester.enterText(find.byType(TextField).first, '');
    await settle(tester);
    await tester.ensureVisible(find.text('Guardar gasto').first);
    await tester.tap(find.text('Guardar gasto').first);
    await settle(tester);

    expect(session.settledOf(form), isNull);
    expect(find.textContaining('Gasto guardado · '), findsNothing);
  });

  testWidgets('Nueva starts over, and the one before can come back', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.starters[4]);
    await tester.ensureVisible(find.text('Guardar gasto'));
    await tester.tap(find.text('Guardar gasto'));
    await settle(tester);
    expect(session.ledger.freeUntilPayday, 1369300 - 45000);

    await tester.tap(find.text('Nueva'));
    await settle(tester);
    // The welcome again, over the untouched account.
    expect(session.turns, isEmpty);
    expect(find.text(ScriptedAgent.starters[0]), findsOneWidget);
    expect(session.ledger.freeUntilPayday, 1369300);
    expect(find.text('Empezaste una conversación nueva.'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(session.turns, hasLength(2));
    expect(session.turns.first.question, ScriptedAgent.starters[4]);
    expect(find.textContaining('Gasto guardado · '), findsOneWidget);
    expect(session.ledger.freeUntilPayday, 1369300 - 45000);

    // A question in the new one ends the way back.
    await tester.tap(find.text('Nueva'));
    await settle(tester);
    await ask(tester, session, ScriptedAgent.starters[2]);
    expect(find.text('Deshacer'), findsNothing);
    expect(session.canRestore, isFalse);

    // And it lasts only a few seconds.
    await tester.tap(find.text('Nueva'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 7));
    await settle(tester);
    expect(find.text('Deshacer'), findsNothing);
    expect(session.canRestore, isFalse);
    expect(session.turns, isEmpty);
  });

  testWidgets('an answer that lands below the reader waits behind a bubble', (
    tester,
  ) async {
    final Session session = await open(
      tester,
      thinking: const Duration(milliseconds: 700),
    );
    await ask(tester, session, ScriptedAgent.starters[0]);
    // Nobody scrolled: the answer came into view on its own.
    expect(find.text('Ver resultado'), findsNothing);

    final Future<void> answered = session.ask(ScriptedAgent.starters[3]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final ScrollPosition position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(FollowedScroll),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    // Back up to read the first answer while the second is on its way.
    await tester.drag(find.byType(FollowedScroll), const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 50));
    final double reading = position.pixels;
    await settle(tester);
    await answered;

    expect(position.pixels, reading);
    expect(find.text('Ver resultado'), findsOneWidget);
    final Finder newest = find.byWidgetPredicate(
      (Widget w) =>
          w is Surface &&
          w.surfaceContext.surfaceId == session.turns.last.surfaceIds.single,
    );
    expect(onScreen(tester, newest), isFalse);

    await tester.tap(find.text('Ver resultado'));
    await settle(tester);
    expect(onScreen(tester, newest), isTrue);
    expect(find.text('Ver resultado'), findsNothing);
  });

  testWidgets('the name over an answer gives way to its surface', (
    tester,
  ) async {
    final Session session = await open(
      tester,
      thinking: const Duration(milliseconds: 700),
    );
    final Finder name = find.descendant(
      of: find.byType(Conversation),
      matching: find.text('Quincena'),
    );
    final Future<void> answered = session.ask(ScriptedAgent.starters[2]);
    await tester.pump();
    // While it thinks, the turn says who is answering.
    expect(name, findsOneWidget);

    await settle(tester);
    await answered;
    expect(name, findsNothing);
  });

  testWidgets('a question the demo does not know offers the ones it does', (
    tester,
  ) async {
    final Session session = await open(tester);
    await ask(tester, session, '¿Cuál es la capital de Francia?');

    expect(screen(tester), contains('En la demo respondo estas preguntas'));
  });
}
