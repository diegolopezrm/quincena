import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';

import 'fonts.dart';

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

  testWidgets('the expense form checks in English', (tester) async {
    final Session session = await open(tester);
    await ask(tester, session, ScriptedAgent.startersEn[4]);

    expect(screen(tester), contains(r'Logging $45,000 under groceries'));
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);
  });
}
