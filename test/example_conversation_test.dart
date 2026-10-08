// «Pregúntale a tu plata» in the example: the script answers it offline,
// over the account the example's screens read, so every figure in an
// answer is the one the screens show. What it saves lands in that account
// and on its screens, and is gone once the example is left. No question of
// the day is spent and nothing goes out.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/ai/allowance.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/data/example_account.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/home_page.dart';
import 'package:quincena/ui/own/own_shell.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show fakeRates, screen, settle;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  setUp(() => Intl.defaultLocale = 'es_CO');

  tearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
    Intl.defaultLocale = 'es_CO';
  });

  group('over the example\'s account', () {
    late QuincenaStore store;
    late OwnController own;

    setUp(() async {
      store = await buildExample(NativeDatabase.memory());
      own = OwnController(
        store,
        example: true,
        now: () => exampleNow,
        readNative: false,
      );
      await own.start();
    });

    tearDown(() async {
      own.dispose();
      await store.close();
    });

    ScriptedAgent agent({String language = 'es'}) => ScriptedAgent.over(
      () => own.ledger!,
      language: language,
      keeper: scriptedKeeper(own),
    );

    test('each of the five answers is the story\'s, figure for figure, in '
        'both languages', () {
      for (final String language in <String>['es', 'en']) {
        Intl.defaultLocale = language == 'en' ? 'en_US' : 'es_CO';
        final ScriptedAgent story = ScriptedAgent(
          demoLedger(),
          language: language,
        );
        final ScriptedAgent example = agent(language: language);
        for (final String q in ScriptedAgent.startersFor(language)) {
          final AgentTurn told = story.answer(q);
          final AgentTurn shown = example.answer(q);
          expect(
            jsonEncode(shown.components),
            jsonEncode(told.components),
            reason: q,
          );
          expect(jsonEncode(shown.data), jsonEncode(told.data), reason: q);
        }
      }
    });

    test('every figure in the answers is the one OwnController gives the '
        'screens', () {
      final Ledger screens = own.ledger!;
      final ScriptedAgent script = agent();
      String said(AgentTurn turn) => jsonEncode(turn.components);

      // Where September went: what was spent, against August, and by
      // category, as Movimientos adds them up.
      final AgentTurn spending = script.answer(ScriptedAgent.starters[0]);
      expect(spending.data['spent'], screens.spentIn(2026, 9));
      expect(spending.data['previous'], screens.spentIn(2026, 8));
      expect(said(spending), contains(_pesos(screens.incomeIn(2026, 9))));
      expect(spending.data['byCategory'], <Object?>[
        for (final MapEntry<Category, int> e in screens.byCategory(2026, 9))
          <String, Object?>{'category': e.key.name, 'amount': e.value},
      ]);

      // Cartagena: the goal as Plan keeps it, and what Inicio says can be
      // spent until payday.
      final AgentTurn goal = script.answer(ScriptedAgent.starters[1]);
      final SavingsGoal kept = own.snapshot!.goals.single;
      final Map<Object?, Object?> planned =
          goal.data['goal']! as Map<Object?, Object?>;
      expect(planned['target'], kept.target.amount.toBigInt().toInt());
      expect(planned['saved'], kept.saved.amount.toBigInt().toInt());
      expect(planned['monthly'], kept.monthly.amount.toBigInt().toInt());
      expect(planned['deadline'], '2026-12-20');
      expect(goal.data['free'], screens.freeUntilPayday);
      expect(goal.data['payday'], '2026-10-15');

      // The subscriptions: what the fixed payments filed as subscriptions
      // cost a month.
      final int subscriptions = <int>[
        for (final RecurringCharge r in own.recurring)
          if (r.active && r.category == 'subscriptions')
            r.amount.amount.toBigInt().toInt(),
      ].fold(0, (int a, int b) => a + b);
      final AgentTurn subs = script.answer(ScriptedAgent.starters[2]);
      expect(said(subs), contains('Pagas ${_pesos(subscriptions)} al mes'));
      expect(
        <Object?>[
          for (final Object? row
              in subs.data['subscriptions']! as List<Object?>)
            (row! as Map<Object?, Object?>)['name'],
        ],
        <String>[for (final Subscription s in screens.subscriptions) s.name],
      );

      // September against August.
      final AgentTurn compare = script.answer(ScriptedAgent.starters[3]);
      final int more = screens.spentIn(2026, 9) - screens.spentIn(2026, 8);
      expect(
        said(compare),
        contains('Gastaste ${_pesos(more)} más que en agosto'),
      );

      // The form: no more than what the everyday accounts hold.
      final AgentTurn form = script.answer(ScriptedAgent.starters[4]);
      expect(said(form), contains('"max":${screens.balance}'));
    });

    test('an expense and a plan it saves land in the account the screens '
        'read, and saving the form again corrects the expense', () async {
      final ScriptedAgent script = agent();
      final int free = own.ledger!.freeUntilPayday;
      final AgentTurn receipt = (await script.respond(
        'save_expense',
        <String, Object?>{
          'amount': 45000,
          'category': 'groceries',
          'note': 'Fruver La 70',
          'id': 'form-1',
        },
      ))!;
      expect(own.ledger!.freeUntilPayday, free - 45000);
      expect(
        jsonEncode(receipt.components),
        contains('Ahora puedes gastar ${_pesos(free - 45000)} hasta el 15 de'),
      );
      List<Entry> scripted() => <Entry>[
        for (final Entry e in own.snapshot!.entries)
          if (e.source == 'script') e,
      ];
      final Entry saved = scripted().single;
      expect(saved.payee, 'Fruver La 70');
      expect(saved.category, 'groceries');
      expect(saved.sourceRef, 'form-1');
      expect(own.snapshot!.account(saved.accountId)!.name, 'Cuenta de nómina');

      await script.respond('save_expense', <String, Object?>{
        'amount': 50000,
        'category': 'groceries',
        'note': 'Fruver La 70',
        'id': 'form-1',
      });
      expect(scripted().single.amount.abs(), Decimal.fromInt(50000));
      expect(own.ledger!.freeUntilPayday, free - 50000);

      // An amount the form turns down saves nothing.
      expect(
        await script.respond('save_expense', <String, Object?>{
          'amount': 0,
          'category': 'groceries',
        }),
        isNull,
      );
      expect(scripted(), hasLength(1));

      final AgentTurn plan = (await script.respond(
        'save_goal_plan',
        <String, Object?>{'monthly': 600000},
      ))!;
      expect(
        own.snapshot!.goals.single.monthly.amount,
        Decimal.fromInt(600000),
      );
      expect(own.goalShares.single.monthly, 600000);
      expect(
        jsonEncode(plan.components),
        contains('Tu plan: ${_pesos(600000)} al mes para Cartagena'),
      );
      expect(
        jsonEncode(script.answer(ScriptedAgent.starters[1]).components),
        contains('Sí: con ${_pesos(600000)} al mes llegas antes del'),
      );
    });

    test('with no goal, the trip question says there is none', () async {
      await own.deleteGoal(own.snapshot!.goals.single.id);
      await pumpEventQueue();
      final AgentTurn answer = agent().answer(ScriptedAgent.starters[1]);
      expect(
        jsonEncode(answer.components),
        contains('Todavía no tienes una meta de ahorro'),
      );
    });

    test('what it does not know, it says it does not in the example', () {
      final String said = jsonEncode(
        agent().answer('¿Cuánto debo en la tarjeta?').components,
      );
      expect(said, contains('En el ejemplo respondo estas preguntas'));
      expect(said, isNot(contains('modelo conectado')));
    });
  });

  testWidgets('in the app, it answers offline from Inicio, spends no '
      'question, and what it saves shows on Inicio until the example is '
      'left', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final QuincenaStore mine = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
    );
    addTearDown(() => tester.runAsync(mine.close));
    await tester.pumpWidget(
      QuincenaApp(store: mine, startInDemo: false, fetcher: fakeRates()),
    );
    await settle(tester);
    await tester.tap(find.text('Con datos de ejemplo'));
    await settle(tester);
    OwnController own() =>
        tester.widget<OwnShell>(find.byType(OwnShell, skipOffstage: false)).own;
    final Allowance allowance = tester
        .widget<OwnShell>(find.byType(OwnShell))
        .modes
        .allowance!;
    final int left = allowance.left;
    final int free = own().ledger!.freeUntilPayday;
    expect(screen(tester), contains(_pesos(free)));

    // Inicio offers the questions the script answers.
    final Finder trip = find.text(ScriptedAgent.starters[1]);
    await tester.scrollUntilVisible(
      trip,
      300,
      scrollable: find
          .byWidgetPredicate(
            (Widget w) =>
                w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    // To the top of the list, clear of the button that floats at its foot.
    await tester.ensureVisible(trip);
    await settle(tester);
    await tester.tap(trip);
    await settle(tester);
    final Session session = tester
        .widget<HomePage>(find.byType(HomePage))
        .session;
    expect(session.mode, AgentMode.demo);
    expect(session.choosable, isFalse);
    expect(session.turns.single.question, ScriptedAgent.starters[1]);
    expect(screen(tester), contains('Para llegar el 20 de diciembre'));

    // The form, saved: the receipt says the figure Inicio says next.
    await tester.enterText(
      find.byType(TextField).last,
      ScriptedAgent.starters[4],
    );
    await tester.tap(find.byTooltip('Preguntar'));
    await settle(tester);
    final Finder save = find.text('Guardar gasto');
    await tester.ensureVisible(save);
    await settle(tester);
    await tester.tap(save);
    await settle(tester);
    final String after = _pesos(free - 45000);
    expect(screen(tester), contains('Ahora puedes gastar $after'));
    expect(own().ledger!.freeUntilPayday, free - 45000);

    // Who answers is not a choice here.
    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    expect(find.text('Quién responde'), findsNothing);
    expect(find.text('Gemini'), findsNothing);
    Navigator.of(tester.element(find.text('Empezar de nuevo'))).pop();
    await settle(tester);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byType(HomePage), findsNothing);
    expect(screen(tester), contains(after));
    expect(allowance.left, left);
    expect(await tester.runAsync(mine.entries), isEmpty);

    // Left and opened again, the example is as it was.
    await tester.tap(find.text('Cuenta de ejemplo de Valentina'));
    await settle(tester);
    await tester.tap(find.text('Volver a la primera pantalla'));
    await settle(tester);
    await tester.tap(find.text('Con datos de ejemplo'));
    await settle(tester);
    expect(own().ledger!.freeUntilPayday, free);
    expect(screen(tester), contains(_pesos(free)));
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}

/// [amount] of the example's pesos, as the answers write it.
String _pesos(int amount) => format.pesos(amount);
