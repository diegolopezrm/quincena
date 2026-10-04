import 'dart:async';
import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
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
import 'package:quincena/ui/own/ask_page.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;

/// A model that writes the expense form, and on its save event records the
/// expense with the id the event carries, as the tool asks.
class ExpenseModel implements ModelClient {
  ExpenseModel(this.tools, {this.formId, this.passesId = true});

  final List<dartantic.Tool> tools;

  /// An id the model writes into every form's save event, the same each
  /// time, as a model might.
  final String? formId;

  /// Whether the model passes the event's id on to record_expense.
  final bool passesId;
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
            if (passesId) 'id': context['id'],
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
      for (final JsonMap c in turn.components) {
        if (formId != null && c['id'] == 'save') {
          final Map<String, Object?> event =
              (c['onPressed']! as Map<String, Object?>)['event']!
                  as Map<String, Object?>;
          event['context'] = <String, Object?>{
            ...event['context']! as Map<String, Object?>,
            'id': formId,
          };
        }
      }
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

    testWidgets('keeps its own id, whatever id the model wrote into it', (
      tester,
    ) async {
      late ExpenseModel model;
      final Session session = Session(
        mode: AgentMode.live,
        clientFor: (List<dartantic.Tool> tools) =>
            model = ExpenseModel(tools, formId: 'expense-1'),
        errorWindow: Duration.zero,
      );
      await open(tester, session);
      final int before = session.ledger.movements.length;
      for (var i = 0; i < 2; i++) {
        unawaited(session.ask(ScriptedAgent.starters[4]));
        await answer(tester);
        await tester.ensureVisible(find.text('Guardar gasto').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar gasto').last);
        await answer(tester);
      }

      // Two forms, two expenses: the second does not overwrite the first.
      expect(session.ledger.movements, hasLength(before + 2));
      expect(session.ledger.freeUntilPayday, 1369300 - 2 * 45000);
      final List<Object?> ids = <Object?>[
        for (final Map<Object?, Object?> save in model.saves) save['id'],
      ];
      expect(ids.toSet(), hasLength(2));
      expect(ids, isNot(contains('expense-1')));
    });

    testWidgets('its receipt holds at twice the text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final Session session = Session(thinking: Duration.zero);
      await open(tester, session);
      // Google Play's smallest screenshot phone.
      tester.view.physicalSize = const Size(1080, 2400);
      unawaited(session.ask(ScriptedAgent.starters[4]));
      await tester.pumpAndSettle();
      await tap(tester, 'Guardar gasto');
      await tester.pumpAndSettle();

      expect(find.textContaining('Gasto guardado · '), findsOneWidget);
      expect(find.text('Nueva'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // And so does the way back to it, once a new one starts.
      await tester.tap(find.text('Nueva'));
      await tester.pumpAndSettle();
      expect(find.text('Empezaste una conversación nueva.'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the questions page, over the person\'s own accounts', () {
    final DateTime now = DateTime(2026, 10, 3, 10);

    /// A bank with a million pesos, and the page that asks about it, opened
    /// from another on Google Play's smallest screenshot phone.
    Future<(Session, QuincenaStore)> openAsk(
      WidgetTester tester, {
      bool passesId = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final QuincenaStore store = (await tester.runAsync(() async {
        final QuincenaStore store = QuincenaStore(
          QuincenaDatabase(NativeDatabase.memory()),
          now: () => now,
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
          institution: 'Bancolombia',
        );
        return store;
      }))!;
      addTearDown(() => tester.runAsync(store.close));
      final OwnController own = OwnController(
        store,
        now: () => now,
        readNative: false,
      );
      addTearDown(own.dispose);
      await tester.runAsync(own.start);
      final Session session = Session(
        mode: AgentMode.gemini,
        clientFor: (List<dartantic.Tool> tools) =>
            ExpenseModel(tools, passesId: passesId),
        errorWindow: Duration.zero,
        ledgerOf: () => own.ledger!,
        toolsFor: (_) => ownTools(own),
        own: true,
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: quincenaTheme(Brightness.light),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          AskPage(own: own, session: session),
                    ),
                  ),
                  child: const Text('Preguntar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preguntar'));
      await settle(tester);
      unawaited(session.ask(ScriptedAgent.starters[4]));
      await settle(tester);
      return (session, store);
    }

    testWidgets('Editar corrects the entry, even with a model that '
        'leaves the id out', (tester) async {
      final (Session _, QuincenaStore store) = await openAsk(
        tester,
        passesId: false,
      );
      await tap(tester, 'Guardar gasto');
      await settle(tester);
      expect((await tester.runAsync(store.entries))!.single.amount, d(-45000));

      await tap(tester, 'Editar');
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '60000');
      await settle(tester);
      await tap(tester, 'Guardar gasto');
      await settle(tester);
      final List<Entry> entries = (await tester.runAsync(store.entries))!;
      expect(entries.single.amount, d(-60000));
    });

    testWidgets('Nueva holds at twice the text size, and its way back '
        'leaves with the page', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (Session session, QuincenaStore _) = await openAsk(tester);
      final Finder button = find.ancestor(
        of: find.text('Nueva'),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);

      await tester.tap(button);
      await settle(tester);
      expect(find.text('Empezaste una conversación nueva.'), findsOneWidget);
      expect(session.canRestore, isTrue);

      // Over the page it came from, the way back would lead nowhere.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text('Preguntar'), findsOneWidget);
      expect(find.text('Empezaste una conversación nueva.'), findsNothing);
      expect(session.canRestore, isFalse);
    });
  });
}

Decimal d(int amount) => Decimal.fromInt(amount);
