// The goal in an answer, moved with the keyboard. Someone who tried the
// public example went from the Cartagena question to the planner's slider
// with the keyboard, pressed the right arrow, and saw the monthly amount and
// the month it arrives change in place; «Volver a $250.000» put both back.
// Kept as a test because any renderer of these answers has to keep doing
// it: the answer is still a tool once the reply is done, the keyboard
// reaches it, and moving it only simulates.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/catalog/goal_planner.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/own/own_controller.dart';
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
  });

  setUp(() => Intl.defaultLocale = 'es_CO');

  testWidgets('the right arrow moves the goal in the answer, and «Volver a» '
      'puts it back without saving anything', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final SemanticsHandle semantics = tester.ensureSemantics();
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
    List<int> plans() => <int>[for (final g in own().goalShares) g.monthly];
    final List<int> saved = plans();

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
    await tester.ensureVisible(trip);
    await settle(tester);
    await tester.tap(trip);
    await settle(tester);

    // The reply is done, and the planner in it still takes changes.
    expect(tester.widget<HomePage>(find.byType(HomePage)).session.busy, false);
    GoalPlanner planner() =>
        tester.widget<GoalPlanner>(find.byType(GoalPlanner));
    expect(planner().onMonthlyChanged, isNotNull);
    expect(planner().monthly, 250000);
    expect(planner().arrival, 'mayo de 2027');
    final Finder back = find.text('Volver a ${format.pesos(250000)}');
    expect(back, findsNothing);

    // The keyboard gets there with Tab alone.
    bool onSlider() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<Slider>() !=
        null;
    for (var i = 0; i < 30 && !onSlider(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(onSlider(), isTrue, reason: 'Tab never reached the slider');

    // One step to the right changes the answer where it is: the amount,
    // the month it arrives, and what a screen reader hears.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(planner().monthly, 260000);
    expect(planner().arrival, 'abril de 2027');
    expect(screen(tester), contains('Llegas en abril de 2027'));
    final SemanticsData slider = tester
        .getSemantics(find.byType(Slider))
        .getSemanticsData();
    expect(slider.label, contains('Apartar al mes para'));
    expect(slider.value, '${format.pesos(260000)} al mes');
    // It is a simulation: the plan keeps what it had.
    expect(plans(), saved);

    // «Volver a $250.000» puts both back, and goes once it has.
    await tester.tap(back);
    await settle(tester);
    expect(planner().monthly, 250000);
    expect(planner().arrival, 'mayo de 2027');
    expect(screen(tester), contains('Llegas en mayo de 2027'));
    expect(back, findsNothing);
    expect(plans(), saved);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
