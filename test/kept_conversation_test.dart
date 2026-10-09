// «Pregúntale a tu plata» with one's own accounts keeps its conversation
// while the app is open, as the example's does: going back to Inicio and
// returning finds it as it was, the questions it took already spent and
// its answers there to read. «Nueva» still starts over, and a change of
// language only changes the language of what comes next.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/ask_page.dart';
import 'package:quincena/ui/own/own_shell.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

/// Taps the question [text] on Inicio, which opens the conversation and
/// asks it, and waits for the notice that its answer did not arrive: with
/// no Firebase in a test, Gemini cannot be reached. Nothing settles while
/// it thinks: the dots keep moving.
Future<Session> _ask(WidgetTester tester, String text) async {
  await reveal(tester, find.text(text));
  await tester.tap(find.text(text).last);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final Session session = tester.widget<AskPage>(find.byType(AskPage)).session;
  for (var i = 0; i < 100 && session.busy; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  await settle(tester);
  return session;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  testWidgets('the conversation is there on coming back from Inicio, and '
      '«Nueva» still starts over', (tester) async {
    late AppModeController modes;
    await openPage(tester, (OwnController own) {
      modes = AppModeController(store: own.store, now: () => pageNow);
      return OwnShell(own: own, modes: modes, settings: AppSettings());
    });
    addTearDown(modes.dispose);

    final Session session = await _ask(
      tester,
      '¿Cuánto puedo gastar antes de que me paguen?',
    );
    expect(session.busy, isFalse);
    expect(
      session.turns.single.question,
      '¿Cuánto puedo gastar antes de que me paguen?',
    );

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byType(AskPage), findsNothing);

    await tapText(tester, 'Otra pregunta');
    expect(tester.widget<AskPage>(find.byType(AskPage)).session, same(session));
    expect(session.turns, hasLength(1));
    expect(
      find.text('¿Cuánto puedo gastar antes de que me paguen?'),
      findsOneWidget,
    );

    // A question picked on Inicio joins the same conversation.
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(
      await _ask(tester, '¿En qué se me fue la plata este mes?'),
      same(session),
    );
    expect(session.turns, hasLength(2));

    await tester.tap(find.byTooltip('Nueva conversación'));
    await settle(tester);
    expect(session.turns, isEmpty);
  });

  testWidgets('a change of language keeps the conversation, and the next '
      'answer comes in the new one', (tester) async {
    late OwnController own;
    await openPage(tester, (OwnController o) {
      own = o;
      return const SizedBox();
    });
    final Session session = Session(
      thinking: Duration.zero,
      ledgerOf: () => own.ledger!,
      own: true,
    );
    addTearDown(session.dispose);
    final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
      const Locale('es'),
    );
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (BuildContext context, Locale value, _) => MaterialApp(
          theme: quincenaTheme(Brightness.light),
          locale: value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
          home: AskPage(own: own, session: session),
        ),
      ),
    );
    await settle(tester);
    final Future<void> asked = session.ask(ScriptedAgent.starters[3]);
    await settle(tester);
    await asked;
    expect(session.turns, hasLength(1));

    locale.value = const Locale('en');
    await settle(tester);
    expect(session.language, 'en');
    expect(session.turns.single.question, ScriptedAgent.starters[3]);
    expect(find.text(ScriptedAgent.starters[3]), findsOneWidget);

    final Future<void> again = session.ask(ScriptedAgent.startersEn[0]);
    await settle(tester);
    await again;
    expect(session.turns, hasLength(2));
    expect(find.textContaining('You spent', findRichText: true), findsWidgets);
  });
}
