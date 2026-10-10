import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show fakeRates, settle;

/// Opens the app on a phone whose language is English.
Future<Session> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final session = Session(thinking: Duration.zero);
  addTearDown(session.dispose);
  await tester.pumpWidget(QuincenaApp(session: session));
  // The app follows the device: the session switches language after the
  // first frame.
  await tester.pumpAndSettle();
  return session;
}

Future<void> ask(WidgetTester tester, Session session, String question) async {
  final Future<void> answered = session.ask(question);
  await tester.pumpAndSettle();
  await answered;
}

/// Scrolls the latest of [found] into view and taps it.
Future<void> tapIn(WidgetTester tester, Finder found) async {
  await tester.ensureVisible(found.last);
  await tester.pumpAndSettle();
  await tester.tap(found.last);
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
    await initializeDateFormatting('en');
    await initializeDateFormatting('es');
  });

  testWidgets('the home screen speaks English, in English amounts', (
    tester,
  ) async {
    final Session session = await open(tester);

    expect(session.language, 'en');
    expect(screen(tester), contains('You can spend'));
    expect(screen(tester), contains('until October 15'));
    expect(screen(tester), contains(r'$1,369,300'));
    for (final String question in ScriptedAgent.startersEn) {
      expect(find.text(question), findsOneWidget);
    }
  });

  testWidgets('where the money went, in English', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[0]);

    final String text = screen(tester);
    expect(text, contains('You spent almost everything that came in'));
    expect(text, contains('Eating out went up 75%'));
    expect(text, contains('Groceries went down 12%'));
    // Catalog functions format in the interface language too.
    expect(text, contains(r'$4,719,400'));
    expect(text, contains('+11%'));
  });

  testWidgets('a new conversation says so in English', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[2]);

    await tester.tap(find.byTooltip('New conversation'));
    await tester.pumpAndSettle();
    expect(find.text('You started a new conversation.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(session.turns.single.question, ScriptedAgent.startersEn[2]);
  });

  testWidgets('the goal planner reads in English', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[1]);

    final String text = screen(tester);
    expect(
      text,
      contains(r'To get there by December 20 you need $600,000 a month'),
    );
    expect(
      text,
      contains(
        r'You set aside $250,000 now, so you are $350,000 a month short. '
        'Three contributions fit: October 16, November 16 and December 16.',
      ),
    );
    expect(text, contains('You get there in May 2027'));
    expect(text, contains('after December 20'));
    expect(text, contains('If you set aside each month'));
    expect(text, contains(r'$600,000 needed'));
    expect(
      text,
      contains(
        r"That's 8 contributions of $250,000, from October 16 to May 16, "
        '2027.',
      ),
    );
    expect(
      text,
      contains(
        r'You can spend $1,369,300 until October 15: the contribution goes '
        "out on October 16, so it doesn't touch that.",
      ),
    );
    expect(text, contains(r'You could free up to $409,200 a month'));
    expect(text, contains('Save this plan'));
  });

  testWidgets('a saved plan says the person moves the money', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[1]);
    await tester.ensureVisible(find.text(r'Use $600,000 a month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Use $600,000 a month'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save this plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this plan'));
    await tester.pumpAndSettle();

    final String text = screen(tester);
    expect(text, contains(r'Your plan: $600,000 a month for Cartagena'));
    expect(
      text,
      contains(
        "Quincena doesn't move your money: move it to your Cartagena pocket "
        'yourself on the 16th of each month, starting October 16. With this '
        'plan you get there in December 2026, before December 20.',
      ),
    );
  });

  testWidgets('where the money went reads as plain English', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[0]);

    final String text = screen(tester);
    expect(text, contains(r'You spent $4,719,400 of the $4,800,000'));
    expect(text, contains('vs. August'));
    expect(text, contains(r'You spent $596,900, up from'));
    expect(text, contains('down from'));
    expect(text, isNot(contains('against')));
    expect(text, isNot(contains('It came to')));
  });

  testWidgets('cancelling subscriptions reads in English', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[2]);

    expect(screen(tester), contains('Fit24 gimnasio and Lingo Pro'));
    expect(screen(tester), contains('Check the ones you want to cancel'));
    await tapIn(
      tester,
      find.byWidgetPredicate(
        (Widget w) =>
            w is Checkbox &&
            w.semanticLabel == 'Select Fit24 gimnasio to cancel',
      ),
    );
    expect(
      screen(tester),
      contains('Cancel the ones you checked and you save'),
    );
    expect(screen(tester), contains(r'$119,000 a month'));
    expect(find.text('To cancel'), findsOneWidget);

    await tapIn(tester, find.text('Review the ones you checked'));
    expect(screen(tester), contains('BEFORE YOU CANCEL'));
    expect(
      screen(tester),
      contains(r"You're canceling one: you'll save $119,000 a month"),
    );
    expect(screen(tester), contains("Quincena can't cancel it for you"));

    await tapIn(tester, find.text('I canceled it'));
    expect(screen(tester), contains('DONE BY YOU'));
    expect(screen(tester), contains('Canceled: Fit24 gimnasio'));
    expect(
      screen(tester),
      contains(r"Starting with the next charge, you'll save $119,000 a month"),
    );
    expect(find.text('Canceled'), findsOneWidget);
  });

  test('every question the English demo offers is in English', () {
    final ScriptedAgent agent = ScriptedAgent(demoLedger(), language: 'en');
    Iterable<Object?> labels(AgentTurn? turn) => <Object?>[
      for (final Map<String, Object?> c in turn!.components)
        if (c['component'] == 'Suggestion') c['label'],
    ];
    final List<Object?> offered = <Object?>[
      for (final String question in ScriptedAgent.startersEn)
        ...labels(agent.answer(question)),
      ...labels(agent.answer('What is the capital of France?')),
      ...labels(
        agent.react('save_expense', <String, Object?>{
          'amount': 45000,
          'category': 'groceries',
        }),
      ),
      ...labels(
        agent.react('cancel_subscriptions', <String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'name': 'Lingo Pro',
              'price': 34900,
              'keep': false,
            },
          ],
        }),
      ),
    ];
    expect(offered, isNotEmpty);
    expect(offered, everyElement(isIn(ScriptedAgent.startersEn)));
  });

  testWidgets('someone\'s own accounts speak English, in its own words', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    DateTime now() => DateTime(2026, 10, 3, 10);
    // The demo's day and currency, for the tests after this one.
    addTearDown(() {
      appToday = DateTime(2026, 10, 1);
      format.baseCurrency = Asset.cop;
    });
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: now,
    );
    addTearDown(() => tester.runAsync(store.close));
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: Decimal.fromInt(2000000),
      );
      await store.addGoal(
        name: 'Cartagena',
        target: Money(Decimal.fromInt(1000000), Asset.cop),
        saved: Money(Decimal.fromInt(270000), Asset.cop),
      );
      // Past the first screen, as after onboarding.
      await store.setSetting('app.mode', 'own');
    });
    await tester.pumpWidget(
      QuincenaApp(
        store: store,
        startInDemo: false,
        fetcher: fakeRates(),
        now: now,
      ),
    );
    await settle(tester);

    expect(find.text('Transactions'), findsOneWidget);
    // Over the rows of Inicio the button keeps to its icon, named.
    expect(find.byTooltip('Add transaction'), findsOneWidget);
    expect(find.byTooltip('Needs review'), findsOneWidget);

    // A goal's share has no space before its sign in English.
    await tester.tap(find.text('Plan'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('27%'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('27%'), findsOneWidget);

    // Paydays are said as days of the month are.
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    expect(
      find.text('Twice a month: the 15th and 30th of each month'),
      findsOneWidget,
    );
  });

  testWidgets('the expense form checks in English', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[4]);

    expect(screen(tester), contains(r'Logging $45,000 under groceries'));
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '45000');
    await tester.pumpAndSettle();
    await tapIn(tester, find.text('Save expense'));
    expect(
      screen(tester),
      contains(r'Now you can spend $1,324,300 until October 15.'),
    );
    expect(screen(tester), isNot(contains('free until')));
  });
}
