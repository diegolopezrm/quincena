// «Pregúntale a tu plata» without punishment: only asking spends one of the
// day's questions. Saving, correcting or changing what an answer brought is
// part of that answer, and works with none left and with no connection. How
// many are left is said before asking, and none left is a state of the
// day, said quietly, not an error.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show ChatMessage, ChatMessageRole;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/catalog.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/ai/allowance.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/icons.dart';
import 'package:quincena/ui/own/ask_page.dart';
import 'package:quincena/ui/own/home_tab.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;

/// Answers each question as a model composes the script's answer to it, and
/// what is done on its surfaces the same way. While [offline], it cannot
/// be reached, as on a phone with no connection.
class _Model implements ModelClient {
  _Model(List<dartantic.Tool> _);

  final ScriptedAgent _script = ScriptedAgent(demoLedger());
  bool offline = false;

  /// What reached it, in order.
  final List<String> heard = <String>[];

  /// What it had read when the last message reached it.
  List<ChatMessage> read = const <ChatMessage>[];
  int _serial = 0;

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    if (offline) {
      throw const SocketException(
        'Failed host lookup: firebasevertexai.googleapis.com',
      );
    }
    heard.add(prompt);
    read = history;
    final AgentTurn? turn;
    if (prompt.startsWith('{')) {
      final Map<Object?, Object?> action =
          (jsonDecode(prompt) as Map<Object?, Object?>)['action']!
              as Map<Object?, Object?>;
      turn = _script.react(
        action['name']! as String,
        (action['context']! as Map<Object?, Object?>).cast<String, Object?>(),
      );
    } else {
      turn = _script.answer(prompt);
    }
    for (final message in turn!.messages(
      'answer-${++_serial}',
      quincenaCatalog.catalogId!,
    )) {
      yield '```json\n${jsonEncode(message.toJson())}\n```\n';
    }
  }
}

final DateTime _now = DateTime(2026, 10, 3, 10);

/// A bank with a million pesos, the day's 30 questions with [used] of them
/// asked, and the page that asks about it, answered by [_Model].
Future<(Session, OwnController, Allowance, _Model)> _openAsk(
  WidgetTester tester, {
  int used = 0,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final QuincenaStore store = (await tester.runAsync(() async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => _now,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
    await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: Decimal.parse('1000000'),
    );
    await store.setSetting(
      'gemini.usage',
      jsonEncode(<String, Object>{'day': '2026-10-3', 'used': used}),
    );
    return store;
  }))!;
  addTearDown(() => tester.runAsync(store.close));
  final OwnController own = OwnController(
    store,
    now: () => _now,
    readNative: false,
  );
  addTearDown(own.dispose);
  final Allowance allowance = Allowance(store, now: () => _now);
  await tester.runAsync(() async {
    await own.start();
    await allowance.load();
  });
  late _Model model;
  final Session session = Session(
    mode: AgentMode.gemini,
    clientFor: (List<dartantic.Tool> tools) => model = _Model(tools),
    errorWindow: Duration.zero,
    ledgerOf: () => own.ledger!,
    toolsFor: (_) => ownTools(own),
    own: true,
    allowance: allowance,
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: quincenaTheme(Brightness.light),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appLocales,
      home: AskPage(own: own, session: session, allowance: allowance),
    ),
  );
  await settle(tester);
  return (session, own, allowance, model);
}

/// Asks [question] and waits for its answer, on the phone and in the store.
Future<void> _ask(WidgetTester tester, Session session, String question) async {
  final Future<void> asked = session.ask(question);
  await _answered(tester);
  await tester.runAsync(() => asked);
  await _answered(tester);
}

/// Lets the answer arrive, and what it saved reach the store and come back.
Future<void> _answered(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await settle(tester);
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await settle(tester);
  await tester.tap(find.text(text).last);
  await _answered(tester);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('es');
  });
  setUp(() => Intl.defaultLocale = 'es_CO');

  testWidgets('only asking spends a question: saving the form, correcting '
      'it and confirming a cancellation spend none', (tester) async {
    final (Session session, OwnController own, Allowance day, _Model model) =
        await _openAsk(tester);
    await _ask(tester, session, ScriptedAgent.starters[4]);
    expect(day.left, 29);

    await _tap(tester, 'Guardar gasto');
    expect(own.snapshot!.entries, hasLength(1));
    expect(
      find.text('Listo: \$45.000 en mercado, desde Bancolombia'),
      findsOneWidget,
    );
    expect(day.left, 29);

    await _tap(tester, 'Editar');
    await tester.enterText(find.byType(TextField).first, '50000');
    await settle(tester);
    await _tap(tester, 'Guardar gasto');
    expect(own.snapshot!.entries.single.amount, Decimal.fromInt(-50000));
    expect(day.left, 29);
    // The model heard the question, and nothing of the saves.
    expect(model.heard, <String>[ScriptedAgent.starters[4]]);

    await _ask(tester, session, ScriptedAgent.starters[2]);
    expect(day.left, 28);
    final Finder box = find.byWidgetPredicate(
      (Widget w) =>
          w is Checkbox &&
          w.semanticLabel == 'Seleccionar Fit24 gimnasio para cancelar',
    );
    await tester.ensureVisible(box);
    await settle(tester);
    await tester.tap(box);
    await settle(tester);
    // Changing the selection goes to the model, and still spends none.
    await _tap(tester, 'Revisar las marcadas');
    expect(model.heard.last, contains('review_cancellation'));
    expect(day.left, 28);
    await _tap(tester, 'Ya la cancelé');
    expect(find.text('Cancelada: Fit24 gimnasio'), findsOneWidget);
    expect(model.heard.last, isNot(contains('cancel_subscriptions')));
    expect(day.left, 28);
  });

  testWidgets('with no question left, the form on screen is saved anyway, '
      'with no connection, and the bar says when they come back', (
    tester,
  ) async {
    final (Session session, OwnController own, Allowance day, _Model model) =
        await _openAsk(tester, used: 29);
    await _ask(tester, session, ScriptedAgent.starters[4]);
    expect(day.left, 0);
    expect(
      find.text('Ya usaste las 30 preguntas de hoy. Vuelven mañana.'),
      findsOneWidget,
    );
    final TextField bar = tester.widget<TextField>(find.byType(TextField).last);
    expect(bar.enabled, isFalse);
    expect(bar.decoration!.hintText, 'Las preguntas vuelven mañana');

    model.offline = true;
    await _tap(tester, 'Guardar gasto');
    expect(session.turns.last.error, isNull);
    expect(own.snapshot!.entries, hasLength(1));
    expect(find.textContaining('Gasto guardado · '), findsOneWidget);
    expect(
      find.text('Ya usaste las preguntas de hoy. Vuelven mañana.'),
      findsNothing,
    );
    expect(day.left, 0);
  });

  testWidgets('a question whose answer did not arrive is asked again in its '
      'place, and counts once', (tester) async {
    final (Session session, OwnController _, Allowance day, _Model model) =
        await _openAsk(tester);
    model.offline = true;
    await _ask(tester, session, ScriptedAgent.starters[0]);
    expect(session.turns.single.error, AnswerProblem.offline);
    expect(day.left, 30);
    expect(find.text('Volver a preguntar'), findsOneWidget);

    model.offline = false;
    await _tap(tester, 'Volver a preguntar');
    expect(session.turns, hasLength(1));
    expect(session.turns.single.error, isNull);
    expect(session.turns.single.surfaceIds, isNotEmpty);
    expect(find.text('Volver a preguntar'), findsNothing);
    expect(day.left, 29);
    expect(model.heard, <String>[ScriptedAgent.starters[0]]);
  });

  testWidgets('with none left, nothing offers to ask, and the page says '
      'quietly when they come back', (tester) async {
    final (Session session, OwnController _, Allowance _, _Model _) =
        await _openAsk(tester, used: 30);
    expect(
      find.text('Ya usaste las 30 preguntas de hoy. Vuelven mañana.'),
      findsOneWidget,
    );
    await tester.tap(find.text('¿Cuánto puedo gastar antes de que me paguen?'));
    await settle(tester);
    expect(session.turns, isEmpty);
    expect(find.byIcon(Glyph.warningCircle), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('a suggestion in an answer, with none left, gets a quiet note '
      'and not an error', (tester) async {
    final (Session session, OwnController _, Allowance day, _Model _) =
        await _openAsk(tester, used: 29);
    await _ask(tester, session, ScriptedAgent.starters[3]);
    expect(day.left, 0);
    await _tap(tester, ScriptedAgent.starters[0]);
    expect(session.turns.last.error, AnswerProblem.limit);
    expect(
      find.text('Ya usaste las preguntas de hoy. Vuelven mañana.'),
      findsOneWidget,
    );
    expect(find.byIcon(Glyph.warningCircle), findsNothing);
    expect(find.text('Volver a preguntar'), findsNothing);
  });

  testWidgets('Nueva after questions that got no answer starts over with '
      'nothing to undo', (tester) async {
    final (Session session, OwnController _, Allowance _, _Model model) =
        await _openAsk(tester);
    model.offline = true;
    await _ask(tester, session, ScriptedAgent.starters[0]);
    await _ask(tester, session, ScriptedAgent.starters[3]);
    await tester.tap(find.text('Nueva'));
    await settle(tester);
    expect(session.turns, isEmpty);
    expect(session.canRestore, isFalse);
    expect(find.text('Deshacer'), findsNothing);
  });

  testWidgets('the model reads what the phone saved, as if it had '
      'answered it, and answers in the language the app speaks now', (
    tester,
  ) async {
    final (Session session, OwnController _, Allowance _, _Model model) =
        await _openAsk(tester);
    await _ask(tester, session, ScriptedAgent.starters[4]);
    await _tap(tester, 'Guardar gasto');
    session.language = 'en';
    await settle(tester);
    expect(session.turns, hasLength(2));
    await _ask(tester, session, ScriptedAgent.startersEn[0]);
    final List<String> read = <String>[
      for (final ChatMessage m in model.read) m.text,
    ];
    expect(read.first, contains('Speak English'));
    expect(read.any((String m) => m.contains('save_expense')), isTrue);
    expect(read.any((String m) => m.contains('desde Bancolombia')), isTrue);
    expect(model.read.first.role, ChatMessageRole.system);
  });

  group('Inicio\'s questions', () {
    Future<Allowance> open(
      WidgetTester tester, {
      required int used,
      bool conversing = false,
      List<String?>? asked,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final QuincenaStore store = (await tester.runAsync(() async {
        final QuincenaStore store = QuincenaStore(
          QuincenaDatabase(NativeDatabase.memory()),
          now: () => _now,
        );
        await store.ensureCategories();
        await store.saveProfile(
          const Profile(
            name: 'Diego',
            base: Asset.cop,
            schedule: TwiceMonthly(),
          ),
        );
        await store.addAccount(
          name: 'Bancolombia',
          kind: AccountKind.bank,
          asset: Asset.cop,
          opening: Decimal.parse('1000000'),
        );
        await store.setSetting(
          'gemini.usage',
          jsonEncode(<String, Object>{'day': '2026-10-3', 'used': used}),
        );
        return store;
      }))!;
      addTearDown(() => tester.runAsync(store.close));
      final OwnController own = OwnController(
        store,
        now: () => _now,
        readNative: false,
      );
      addTearDown(own.dispose);
      final Allowance allowance = Allowance(store, now: () => _now);
      await tester.runAsync(() async {
        await own.start();
        await allowance.load();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: quincenaTheme(Brightness.light),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: OwnHomeTab(
                own: own,
                onSeeAll: () {},
                onAsk: ([String? question]) => asked?.add(question),
                allowance: allowance,
                conversing: conversing,
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      return allowance;
    }

    testWidgets('say how many are left once they are few', (tester) async {
      await open(tester, used: 27);
      await tester.scrollUntilVisible(
        find.text('Te quedan 3 de 30 preguntas hoy'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Te quedan 3 de 30 preguntas hoy'), findsOneWidget);
      expect(find.text('Otra pregunta'), findsOneWidget);
    });

    testWidgets('with plenty left, say nothing of it', (tester) async {
      await open(tester, used: 2);
      await tester.scrollUntilVisible(
        find.text('Otra pregunta'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('preguntas hoy'), findsNothing);
    });

    testWidgets('with none left, are put away, with when they come back and '
        'the way back to the conversation', (tester) async {
      final List<String?> asked = <String?>[];
      await open(tester, used: 30, conversing: true, asked: asked);
      final Finder gone = find.text(
        'Ya usaste las 30 preguntas de hoy. Vuelven mañana.',
      );
      await tester.scrollUntilVisible(
        gone,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(gone, findsOneWidget);
      expect(find.text('Otra pregunta'), findsNothing);
      final Finder question = find.text(
        '¿Cuánto puedo gastar antes de que me paguen?',
      );
      await tester.ensureVisible(question);
      await settle(tester);
      await tester.tap(question);
      await settle(tester);
      expect(asked, isEmpty);
      await tester.ensureVisible(find.text('Ver la conversación'));
      await settle(tester);
      await tester.tap(find.text('Ver la conversación'));
      await settle(tester);
      expect(asked, <String?>[null]);
    });

    testWidgets('with none left and no conversation, offer nothing to '
        'open', (tester) async {
      await open(tester, used: 30);
      await tester.scrollUntilVisible(
        find.text('Ya usaste las 30 preguntas de hoy. Vuelven mañana.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ver la conversación'), findsNothing);
      expect(find.text('Otra pregunta'), findsNothing);
    });
  });
}
