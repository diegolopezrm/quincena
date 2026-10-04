import 'dart:async';
import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show ChatMessage, JsonMap;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/catalog.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/agent/tools.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/session/session.dart';

import 'fonts.dart';

/// A model that writes the expense form, and on its save event records the
/// expense with the id the event carries, as the tool asks.
class ExpenseModel implements ModelClient {
  ExpenseModel(this.tools);

  final List<dartantic.Tool> tools;
  final List<String> prompts = <String>[];
  final ScriptedAgent _script = ScriptedAgent(demoLedger());
  int _serial = 0;

  /// Makes the next save fail, as a model that cannot be reached would.
  bool failNext = false;

  /// The context of every save event, in order.
  List<Map<Object?, Object?>> get saves => <Map<Object?, Object?>>[
    for (final String p in prompts)
      if (p.startsWith('{'))
        ((jsonDecode(p) as Map<Object?, Object?>)['action']! as Map)['context']!
            as Map<Object?, Object?>,
  ];

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    prompts.add(prompt);
    final AgentTurn turn;
    if (prompt.startsWith('{')) {
      if (failNext) {
        failNext = false;
        throw StateError('Gemini returned 500');
      }
      final Map<Object?, Object?> context = saves.last;
      await tools
          .firstWhere((dartantic.Tool t) => t.name == 'record_expense')
          .call(<String, dynamic>{
            'amount': context['amount'],
            'category': context['category'],
            'id': context['id'],
          });
      turn = const AgentTurn(
        components: <JsonMap>[
          <String, Object?>{
            'id': 'root',
            'component': 'Answer',
            'children': <String>['head'],
          },
          <String, Object?>{
            'id': 'head',
            'component': 'Headline',
            'title': 'Listo',
          },
        ],
      );
    } else {
      turn = _script.answer(prompt);
    }
    for (final message in turn.messages(
      'model-${++_serial}',
      quincenaCatalog.catalogId!,
    )) {
      yield '```json\n${jsonEncode(message.toJson())}\n```\n';
    }
  }
}

Future<void> open(WidgetTester tester, Session session) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(session.dispose);
  await tester.pumpWidget(QuincenaApp(session: session));
  await tester.pumpAndSettle();
}

/// Moves the clock past the answer, and past the window in which genui
/// reports what was wrong with it.
Future<void> answer(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Taps [text], once it is in view.
Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  group('the account', () {
    Movement lunch(String id, int amount) => Movement(
      id: id,
      date: appToday,
      merchant: 'Almuerzo',
      amount: amount,
      category: Category.restaurants,
    );

    test('replaces a movement by its id, or adds it when it is new', () {
      final Ledger ledger = demoLedger();
      final int free = ledger.freeUntilPayday;
      ledger.replace(lunch('chat-1', 20000));
      expect(ledger.freeUntilPayday, free - 20000);
      ledger.replace(lunch('chat-1', 25000));
      expect(
        ledger.movements.where((Movement m) => m.id == 'chat-1'),
        hasLength(1),
      );
      expect(ledger.freeUntilPayday, free - 25000);
    });

    test('takes out the very movement it is given', () {
      final Ledger ledger = demoLedger();
      final int free = ledger.freeUntilPayday;
      final Movement first = lunch('same', 20000);
      final Movement second = lunch('same', 30000);
      ledger
        ..record(first)
        ..record(second);
      expect(ledger.remove(first), isTrue);
      expect(ledger.remove(first), isFalse);
      expect(ledger.movements, contains(second));
      expect(ledger.freeUntilPayday, free - 30000);
    });

    test('record_expense with the same id corrects the expense', () async {
      final Ledger ledger = demoLedger();
      final dartantic.Tool record = ledgerTools(
        ledger,
      ).firstWhere((dartantic.Tool t) => t.name == 'record_expense');
      await record.call(<String, dynamic>{
        'amount': 45000,
        'category': 'groceries',
        'id': 'chat-1',
      });
      final done =
          await record.call(<String, dynamic>{
                'amount': 60000,
                'category': 'restaurants',
                'id': 'chat-1',
              })
              as Map<String, Object?>;
      expect(done['freeUntilPayday'], 1369300 - 60000);
      final Movement saved = ledger.movements.singleWhere(
        (Movement m) => m.id == 'chat-1',
      );
      expect(saved.amount, 60000);
      expect(saved.category, Category.restaurants);
    });
  });

  group('a form that commits something', () {
    testWidgets('sends the model an id, and the same one when corrected', (
      tester,
    ) async {
      late ExpenseModel model;
      final Session session = Session(
        mode: AgentMode.live,
        clientFor: (List<dartantic.Tool> tools) => model = ExpenseModel(tools),
        errorWindow: Duration.zero,
      );
      await open(tester, session);
      final int before = session.ledger.movements.length;
      unawaited(session.ask(ScriptedAgent.starters[4]));
      await answer(tester);

      await tap(tester, 'Guardar gasto');
      await answer(tester);
      final Object? id = model.saves.single['id'];
      expect(id, isA<String>());
      expect(
        session.ledger.movements.singleWhere((Movement m) => m.id == id).amount,
        45000,
      );
      expect(find.textContaining('Gasto guardado · '), findsOneWidget);

      await tap(tester, 'Editar');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '60000');
      await tester.pumpAndSettle();
      await tap(tester, 'Guardar gasto');
      await answer(tester);

      expect(model.saves.last['id'], id);
      expect(session.ledger.movements, hasLength(before + 1));
      expect(
        session.ledger.movements.singleWhere((Movement m) => m.id == id).amount,
        60000,
      );
      expect(session.ledger.freeUntilPayday, 1369300 - 60000);
    });

    testWidgets('opens again when the answer does not arrive', (tester) async {
      late ExpenseModel model;
      final Session session = Session(
        mode: AgentMode.live,
        clientFor: (List<dartantic.Tool> tools) => model = ExpenseModel(tools),
        errorWindow: Duration.zero,
      );
      await open(tester, session);
      unawaited(session.ask(ScriptedAgent.starters[4]));
      await answer(tester);
      final String form = session.turns.single.surfaceIds.single;

      model.failNext = true;
      await tap(tester, 'Guardar gasto');
      await answer(tester);
      expect(session.settledOf(form), isNull);
      expect(session.ledger.freeUntilPayday, 1369300);

      // Saved, then corrected, and the correction fails: the first save
      // stands, and the form stays open to try again.
      await tap(tester, 'Guardar gasto');
      await answer(tester);
      expect(session.settledOf(form), isNotNull);
      await tap(tester, 'Editar');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '60000');
      await tester.pumpAndSettle();
      model.failNext = true;
      await tap(tester, 'Guardar gasto');
      await answer(tester);
      expect(session.settledOf(form), isNull);
      expect(session.ledger.freeUntilPayday, 1369300 - 45000);

      await tap(tester, 'Guardar gasto');
      await answer(tester);
      expect(session.settledOf(form), isNotNull);
      expect(session.ledger.freeUntilPayday, 1369300 - 60000);
    });

    testWidgets('its receipt holds at twice the text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final Session session = Session(thinking: Duration.zero);
      await open(tester, session);
      unawaited(session.ask(ScriptedAgent.starters[4]));
      await tester.pumpAndSettle();
      await tap(tester, 'Guardar gasto');
      await tester.pumpAndSettle();

      expect(find.textContaining('Gasto guardado · '), findsOneWidget);
      expect(find.text('Nueva'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
