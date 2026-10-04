import 'dart:convert';
import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/catalog.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/agent/prompt.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/agent/tools.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/session/session.dart';

import 'fonts.dart';

/// A model that answers with what the scripted agent would compose, written
/// out the way a model writes it: a sentence, then each A2UI message in its
/// own ```json block, all of it streamed in small pieces.
class ScriptedModel implements ModelClient {
  ScriptedModel({this.fail = false});

  final bool fail;
  final List<String> prompts = <String>[];
  final ScriptedAgent _script = ScriptedAgent(demoLedger());
  int _serial = 0;

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    prompts.add(prompt);
    if (fail) throw StateError('Gemini returned 500');
    final AgentTurn? turn = prompt.startsWith('{')
        ? _script.react(
            ((jsonDecode(prompt) as Map)['action'] as Map)['name']! as String,
            <String, Object?>{
              ...(((jsonDecode(prompt) as Map)['action'] as Map)['context']
                      as Map)
                  .cast<String, Object?>(),
            },
          )
        : _script.answer(prompt);
    if (turn == null) return;
    final reply = StringBuffer('Mira lo que encontré.\n');
    for (final message in turn.messages(
      'live-${++_serial}',
      quincenaCatalog.catalogId!,
    )) {
      reply.write('```json\n${jsonEncode(message.toJson())}\n```\n');
    }
    final String text = reply.toString();
    for (var i = 0; i < text.length; i += 40) {
      yield text.substring(i, math.min(i + 40, text.length));
    }
  }
}

/// A model that gets its first surface wrong, and fixes it when told.
class CorrectedModel implements ModelClient {
  final List<String> prompts = <String>[];

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    prompts.add(prompt);
    final String id = prompts.length == 1 ? 'wrong' : 'right';
    final String root = prompts.length == 1
        // A component the catalog does not have.
        ? '{"id": "root", "component": "PieChart", "slices": []}'
        : '{"id": "root", "component": "Answer", "children": ["head"]}, '
              '{"id": "head", "component": "Headline", "title": "Ya quedó"}';
    yield '```json\n{"version": "v0.9", "createSurface": '
        '{"surfaceId": "$id", "catalogId": "dev.dlsoft.quincena"}}\n```\n';
    yield '```json\n{"version": "v0.9", "updateComponents": '
        '{"surfaceId": "$id", "components": [$root]}}\n```\n';
  }
}

/// A model that leaves the version out of its first answer, which genui's
/// parser rejects, and gets it right when told.
class VersionlessModel implements ModelClient {
  final List<String> prompts = <String>[];

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    prompts.add(prompt);
    final String version = prompts.length == 1 ? '' : '"version": "v0.9", ';
    final String id = 'answer-${prompts.length}';
    yield 'Listo.\n';
    yield '```json\n{$version"createSurface": '
        '{"surfaceId": "$id", "catalogId": "dev.dlsoft.quincena"}}\n```\n';
    yield '```json\n{$version"updateComponents": {"surfaceId": "$id", '
        '"components": [{"id": "root", "component": "Answer", '
        '"children": ["head"]}, {"id": "head", "component": "Headline", '
        '"title": "Con versión"}]}}\n```\n';
  }
}

/// A model that writes the call to money into its sentence as text, the way
/// Gemini 3.5 Flash once did, and builds the sentence properly when told.
class WrittenOutCallModel implements ModelClient {
  final List<String> prompts = <String>[];

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    prompts.add(prompt);
    final String id = 'answer-${prompts.length}';
    final String title = prompts.length == 1
        ? '"Tienes un total de {call: money, args: {amount: 2283966}}"'
        : '{"call": "formatString", "args": {"value": '
              r'"Tienes un total de ${money(amount: 2283966)}"}}';
    yield '```json\n{"version": "v0.9", "createSurface": '
        '{"surfaceId": "$id", "catalogId": "dev.dlsoft.quincena"}}\n```\n';
    yield '```json\n{"version": "v0.9", "updateComponents": '
        '{"surfaceId": "$id", "components": [{"id": "root", '
        '"component": "Answer", "children": ["head"]}, {"id": "head", '
        '"component": "Headline", "title": $title}]}}\n```\n';
  }
}

Future<Session> open(WidgetTester tester, ModelClient model) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The test device speaks English unless told otherwise.
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final session = Session(mode: AgentMode.live, client: model);
  addTearDown(session.dispose);
  await tester.pumpWidget(QuincenaApp(session: session));
  await tester.pumpAndSettle();
  return session;
}

/// Asks, and moves the test's clock past the window in which genui reports
/// what was wrong with an answer, and past any correction that follows.
Future<void> ask(WidgetTester tester, Session session, String question) async {
  final Future<void> answered = session.ask(question);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
  await answered;
  await tester.pumpAndSettle();
}

String screen(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((RichText t) => t.text.toPlainText())
    .join('\n')
    .replaceAll(' ', ' ');

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  group('a model behind the conversation', () {
    testWidgets('its JSON blocks become a surface, its words a line', (
      tester,
    ) async {
      final Session session = await open(tester, ScriptedModel());
      await ask(tester, session, ScriptedAgent.starters[0]);

      expect(session.turns.single.surfaceIds, <String>['live-1']);
      expect(screen(tester), contains('Mira lo que encontré.'));
      expect(screen(tester), contains('Gastaste casi todo lo que entró'));
      // Functions the model bound are evaluated on the device.
      expect(screen(tester), contains('+11 %'));
    });

    testWidgets('what the person does goes back to the model as JSON', (
      tester,
    ) async {
      final model = ScriptedModel();
      final Session session = await open(tester, model);
      await ask(tester, session, ScriptedAgent.starters[1]);

      // The screen scrolls to each new answer with an animation; let it
      // finish, or the tap lands where the button was.
      await tester.ensureVisible(find.text('Apartar esto cada mes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apartar esto cada mes'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      final Map<Object?, Object?> sent =
          jsonDecode(model.prompts.last) as Map<Object?, Object?>;
      final Map<Object?, Object?> action = sent['action']! as Map;
      expect(action['name'], 'save_goal_plan');
      // The context arrives resolved: the amount on the slider, not a path.
      expect((action['context']! as Map)['monthly'], 250000);
      expect(screen(tester), contains(r'Cada día 16 aparto $250.000'));
    });

    testWidgets('a surface the catalog rejects goes back to be fixed', (
      tester,
    ) async {
      final model = CorrectedModel();
      final Session session = await open(tester, model);
      await ask(tester, session, '¿En qué gasté?');

      // The model heard what was wrong, within the same turn.
      expect(model.prompts, hasLength(2));
      expect(model.prompts.last, contains('VALIDATION_FAILED'));
      // And the person sees the fixed surface, not the broken one.
      expect(session.turns, hasLength(1));
      expect(session.turns.single.surfaceIds, <String>['right']);
      expect(screen(tester), contains('Ya quedó'));
    });

    testWidgets('a message genui cannot parse is reported, not lost', (
      tester,
    ) async {
      final model = VersionlessModel();
      final Session session = await open(tester, model);
      await ask(tester, session, '¿En qué gasté?');

      // genui's own adapter drops this without a word; here the model is
      // told what was wrong, and answers again in the same turn.
      expect(model.prompts, hasLength(2));
      expect(model.prompts.last, contains('version'));
      expect(session.turns, hasLength(1));
      expect(session.turns.single.surfaceIds, <String>['answer-2']);
      expect(screen(tester), contains('Con versión'));
      expect(session.replies, hasLength(2));
    });

    testWidgets('a call written out as text goes back to be fixed', (
      tester,
    ) async {
      final model = WrittenOutCallModel();
      final Session session = await open(tester, model);
      await ask(tester, session, '¿Cuánto tengo en total?');

      // genui accepts the text, so the app is the one that notices.
      expect(model.prompts, hasLength(2));
      expect(model.prompts.last, contains('formatString'));
      expect(session.turns.single.surfaceIds, <String>['answer-2']);
      expect(screen(tester), contains('Tienes un total de \$'));
      expect(screen(tester), isNot(contains('call:')));
    });

    testWidgets('a model that fails says so instead of hanging', (
      tester,
    ) async {
      final Session session = await open(tester, ScriptedModel(fail: true));
      await ask(tester, session, ScriptedAgent.starters[0]);

      expect(session.busy, isFalse);
      expect(screen(tester), contains('No pude responder esta vez.'));
    });
  });

  group('what the model is told', () {
    final String prompt = quincenaPrompt(quincenaCatalog, demoLedger());

    test('it may write the data model the catalog binds to', () {
      expect(prompt, contains('updateDataModel'));
    });

    test('it is not told to do the arithmetic itself', () {
      expect(prompt, isNot(contains('do them yourself')));
      expect(prompt, contains('never add, subtract or divide'));
    });

    test('it is told the Spanish names of the categories', () {
      expect(prompt, contains('shopping = Compras'));
    });

    test('it is told Quincena never moves or cancels money', () {
      expect(
        prompt,
        contains('Quincena never moves, sets aside, pays or cancels money'),
      );
      // Nothing comes ticked, and nothing is struck through until the
      // person says they did it.
      expect(prompt, isNot(contains('set keep to false')));
      expect(prompt, contains('Leave keep true'));
      expect(prompt, contains('review_cancellation'));
      expect(prompt, contains('cancel_subscriptions'));
    });

    test('in English, the suggested questions are in English too', () {
      const String line = 'That includes the questions in Suggestion chips';
      expect(prompt, isNot(contains(line)));
      for (final bool own in <bool>[false, true]) {
        expect(
          quincenaPrompt(
            quincenaCatalog,
            demoLedger(),
            language: 'en',
            own: own,
          ),
          contains(line),
        );
      }
    });

    test('it is told to ask for its tools at once', () {
      // Each turn sends the whole prompt again: six turns cost three times
      // two, and the person waits for every one.
      expect(prompt, contains('Ask for every tool an answer needs at once'));
    });

    test('it is told how to put an amount inside a sentence', () {
      expect(prompt, contains(r'"value": "You have ${money(amount: 120000)}'));
    });

    test('it knows the catalog, today and the person', () {
      expect(prompt, contains('dev.dlsoft.quincena'));
      expect(prompt, contains('GoalPlanner'));
      expect(prompt, contains('savingsIfCancelled'));
      expect(prompt, contains('Today is 2026-10-01'));
      expect(prompt, contains('Valentina'));
    });

    test('its schemas are the same JSON, without the spaces', () {
      // Each round sends the whole prompt: 19,080 tokens as genui writes
      // it, 11,886 like this, counted by the model on 3 October 2026.
      final RegExp fenced = RegExp(
        r'-----([A-Z_]+_SCHEMA|COMMON_TYPES)_START-----\n(.*)\n-----\1_END-----',
      );
      final List<RegExpMatch> schemas = fenced.allMatches(prompt).toList();
      expect(schemas.map((RegExpMatch m) => m[1]), <String>[
        'COMMON_TYPES',
        'CATALOG_SCHEMA',
        'MESSAGE_SCHEMA',
      ]);
      for (final RegExpMatch m in schemas) {
        // One line each, and it reads back as JSON.
        expect(m[2], isNot(contains('\n')));
        expect(jsonDecode(m[2]!), isA<Map<String, Object?>>());
      }
      // The words around them are as they were.
      expect(prompt, contains('-----CONTROLLING_THE_UI_START-----\n'));
      expect(compactSchemas(prompt), prompt);
      final String pretty =
          '-----X_SCHEMA_START-----\n'
          '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            'a': <int>[1, 2],
            'b': 'ñandú',
          })}\n-----X_SCHEMA_END-----';
      expect(
        compactSchemas(pretty),
        '-----X_SCHEMA_START-----\n{"a":[1,2],"b":"ñandú"}\n-----X_SCHEMA_END-----',
      );
    });
  });

  group('a call written out as text', () {
    String? found(Object? title) => Session.writtenOutCall(
      core.UpdateComponentsMessage(
        surfaceId: 's',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'head',
            'component': 'Headline',
            'title': title,
          },
        ],
      ),
    );

    test('is found in plain text, however it is spelled', () {
      expect(found('Tienes {call: money, args: {amount: 5}}'), isNotNull);
      expect(
        found('Tienes {"call": "money", "args": {"amount": 5}}'),
        isNotNull,
      );
      expect(found(r'Tienes ${money(amount: 5)}'), isNotNull);
      expect(found('Tienes 5 pesos'), isNull);
    });

    test('is not confused with a call made the right way', () {
      expect(
        found(<String, Object?>{
          'call': 'money',
          'args': <String, Object?>{'amount': 5},
        }),
        isNull,
      );
      expect(
        found(<String, Object?>{
          'call': 'formatString',
          'args': <String, Object?>{'value': r'Tienes ${money(amount: 5)}'},
        }),
        isNull,
      );
      expect(found(<String, Object?>{'path': '/total'}), isNull);
    });

    test('is found inside formatString too', () {
      expect(
        found(<String, Object?>{
          'call': 'formatString',
          'args': <String, Object?>{'value': 'Tienes {call: money}'},
        }),
        contains('head.title'),
      );
    });
  });

  group('the tools a model asks the account with', () {
    Future<Map<String, Object?>> call(
      String name, [
      Map<String, dynamic>? args,
    ]) async {
      final dartantic.Tool tool = ledgerTools(
        demoLedger(),
      ).firstWhere((dartantic.Tool t) => t.name == name);
      // How dartantic invokes a tool the model called.
      return (await tool.call(args ?? <String, dynamic>{}))
          as Map<String, Object?>;
    }

    test('month_spending agrees with the statement', () async {
      final Map<String, Object?> sept = await call('month_spending', {
        'month': '2026-09',
      });
      expect(sept['spent'], 4719400);
      expect(sept['income'], 4800000);
      expect(
        ((sept['categories']! as Map)['restaurants']! as Map)['amount'],
        596900,
      );
      expect((sept['previousMonth']! as Map)['spent'], 4238900);
      expect((sept['largest']! as List).length, 5);
      // The derived figures come from the tool, so the model never has to
      // work one out.
      expect(sept['spentDifference'], 480500);
      expect(sept['spentChangePercent'], 11);
      expect(sept['spentShareOfIncomePercent'], 98);
      final Map<Object?, Object?> restaurants =
          (sept['categories']! as Map)['restaurants']! as Map;
      expect(restaurants['changePercent'], 75);
      expect(restaurants['payments'], 20);
      expect(restaurants['previousPayments'], 15);
    });

    test('a malformed month is an error, not a guess', () async {
      final Map<String, Object?> result = await call('month_spending', {
        'month': 'septiembre',
      });
      expect(result['error'], isNotNull);
    });

    test('each subscription says when it is charged next', () async {
      final Map<String, Object?> subs = await call('subscriptions');
      final Map<Object?, Object?> charges = <Object?, Object?>{
        for (final Map<Object?, Object?> s
            in (subs['subscriptions']! as List).cast<Map<Object?, Object?>>())
          s['name']: s['nextCharge'],
      };
      // Today is 1 October: Fit24's charge on the 1st is already behind.
      expect(charges['Fit24 gimnasio'], '2026-11-01');
      expect(charges['Lingo Pro'], '2026-10-20');
    });

    test(
      'subscriptions and the goal come with their totals worked out',
      () async {
        final Map<String, Object?> subs = await call('subscriptions');
        expect(subs['unusedMonthlyTotal'], 153900);
        final Map<String, Object?> goal = await call('savings_goal');
        expect(goal['missing'], 1800000);
        expect(goal['monthlyNeeded'], 600000);
        expect(goal['arrivalAtCurrentPace'], 'mayo de 2027');
      },
    );

    test('account_overview matches the home screen', () async {
      final Map<String, Object?> overview = await call('account_overview');
      expect(overview['freeUntilPayday'], 1369300);
      expect(overview['nextPayday'], '2026-10-15');
    });

    test('record_expense records, and refuses nonsense', () async {
      final dartantic.Tool record = ledgerTools(
        demoLedger(),
      ).firstWhere((dartantic.Tool t) => t.name == 'record_expense');
      final done =
          await record.call(<String, dynamic>{
                'amount': 45000,
                'category': 'groceries',
              })
              as Map<String, Object?>;
      expect(done['freeUntilPayday'], 1369300 - 45000);

      final refused =
          await record.call(<String, dynamic>{'amount': -5, 'category': 'x'})
              as Map<String, Object?>;
      expect(refused['error'], isNotNull);
    });
  });
}
