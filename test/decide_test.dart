// Phase 17: deciding before spending. The home reads as a briefing of the
// days until payday, "Can I afford…?" is at hand, a goal's slider marks
// what it takes and stops there, the ask bar teaches what to ask, and a
// loan is recorded as one.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/catalog/goal_planner.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/functions/money_functions.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/ask_bar.dart';
import 'package:quincena/ui/own/coming_days_page.dart';
import 'package:quincena/ui/own/home_tab.dart';
import 'package:quincena/ui/own/shared_page.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show screen;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

Widget app(Widget child) => MaterialApp(
  theme: quincenaTheme(Brightness.light),
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: appLocales,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('the home lines up the days until payday, lowest point first', (
    tester,
  ) async {
    await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: SingleChildScrollView(
          child: OwnHomeTab(own: own, onSeeAll: () {}),
        ),
      ),
      data: (QuincenaStore store, Account bank, Account card) async {
        await store.saveProfile(
          Profile(
            name: 'Ana',
            base: Asset.cop,
            schedule: const TwiceMonthly(),
            pay: d('2500000'),
          ),
        );
        await store.addRecurring(
          name: 'Netflix',
          amount: Money(d('26900'), Asset.cop),
          cadence: Cadence.monthly,
          nextDate: DateTime(2026, 10, 12),
          accountId: bank.id,
          category: 'subscriptions',
        );
      },
    );
    await reveal(tester, find.text('Próximos días'));
    final String text = screen(tester);
    expect(text, contains('Tu punto más bajo será'));
    expect(text, contains('el 12 de octubre'));
    expect(text, contains('Hoy'));
    expect(text, contains('Netflix'));
    expect(text, contains(r'−$26.900'));
    // The pay is on the line, as expected money, not as money yet.
    expect(text, contains('Tu quincena'));
    expect(text, contains('esperado'));
    expect(text, contains(r'+$2.500.000'));
  });

  testWidgets('"Can I afford…?" opens the days ahead with the price tried', (
    tester,
  ) async {
    await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: SingleChildScrollView(
          child: OwnHomeTab(own: own, onSeeAll: () {}),
        ),
      ),
    );
    await reveal(tester, find.text('¿Me alcanza para…?'));
    await tester.enterText(find.widgetWithText(TextField, 'Precio'), '350000');
    await tapText(tester, 'Ver');
    expect(find.byType(ComingDaysPage), findsOneWidget);
    expect(find.widgetWithText(TextField, '350.000'), findsOneWidget);
  });

  group('the goal slider', () {
    setUp(() => appToday = DateTime(2026, 10, 1));
    tearDown(() => appToday = DateTime(2026, 10, 1));

    Future<List<double>> pump(
      WidgetTester tester, {
      double monthly = 250000,
      double? current,
      double needed = 600000,
      String? deadline,
      double? spendable,
      String? payday,
    }) async {
      final List<double> moved = <double>[];
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: GoalPlanner(
              name: 'Cartagena',
              target: 2800000,
              saved: 1000000,
              monthly: monthly,
              min: 100000,
              max: 800000,
              arrival: 'mayo de 2027',
              onTime: false,
              deadlineLabel: '20 de diciembre',
              needed: needed,
              current: current,
              deadline: deadline,
              spendable: spendable,
              payday: payday,
              onMonthlyChanged: moved.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return moved;
    }

    testWidgets('says what is missing and marks what it takes', (tester) async {
      await pump(tester);
      final String text = screen(tester);
      expect(text, contains(r'Llevas $1.000.000 · faltan $1.800.000'));
      expect(text, contains(r'Necesitas $600.000'));
    });

    testWidgets('stops on what it takes, with a tick as it is reached', (
      tester,
    ) async {
      final List<MethodCall> haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final List<double> moved = await pump(tester);
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      // A notch away from what it takes lands on it.
      slider.onChanged!(610000);
      expect(moved.last, 600000);
      expect(haptics, hasLength(1));
      // Far from it, the slider moves by notches and stays quiet.
      slider.onChanged!(700000);
      expect(moved.last, 700000);
    });

    testWidgets('takes an exact amount, typed', (tester) async {
      final List<double> moved = await pump(tester);
      await tester.tap(find.byTooltip('Escribir monto'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cuánto quieres apartar al mes?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Usar este monto'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un monto mayor que cero.'), findsOneWidget);
      expect(moved, isEmpty);

      // Off the slider's notches, and kept exact.
      await tester.enterText(find.byType(TextField), '437000');
      await tester.tap(find.text('Usar este monto'));
      await tester.pumpAndSettle();
      expect(moved.last, 437000);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('uses what it takes in one tap', (tester) async {
      final List<double> moved = await pump(tester);
      await tester.tap(find.text(r'Usar $600.000 al mes'));
      expect(moved.last, 600000);

      // On it already, there is nothing to offer.
      await pump(tester, monthly: 600000);
      expect(find.text(r'Usar $600.000 al mes'), findsNothing);
    });

    testWidgets('says it is a simulation, and goes back to today', (
      tester,
    ) async {
      await pump(tester, current: 250000);
      expect(screen(tester), isNot(contains('Simulación')));

      final List<double> moved = await pump(
        tester,
        monthly: 600000,
        current: 250000,
      );
      expect(screen(tester), contains(r'Simulación · hoy apartas $250.000'));
      await tester.tap(find.text(r'Volver a $250.000'));
      expect(moved.last, 250000);
    });

    testWidgets('counts the contributions as it moves', (tester) async {
      await pump(tester);
      expect(
        screen(tester),
        contains(
          r'Son 8 aportes de $250.000, del 16 de octubre al 16 de mayo de '
          '2027.',
        ),
      );
      await pump(tester, monthly: 600000);
      expect(
        screen(tester),
        contains(
          r'Son 3 aportes de $600.000, del 16 de octubre al 16 de diciembre.',
        ),
      );
      await pump(tester, monthly: 1800000);
      expect(screen(tester), contains('Es 1 aporte, el 16 de octubre.'));
    });

    testWidgets('says what it changes in what can be spent', (tester) async {
      Future<String> at(double monthly, {String payday = '2026-10-15'}) async {
        await pump(
          tester,
          monthly: monthly,
          current: 250000,
          spendable: 1369300,
          payday: payday,
        );
        return screen(tester);
      }

      String text = await at(250000);
      expect(text, contains('Qué cambia en lo que puedes gastar'));
      // The contribution lands the day after payday: until then, nothing.
      expect(
        text,
        contains(
          r'Hasta el 15 de octubre puedes gastar $1.369.300: el aporte sale '
          'el 16 de octubre, así que no lo toca.',
        ),
      );
      expect(
        text,
        contains('Es lo que ya apartas: lo que puedes gastar no cambia.'),
      );

      text = await at(600000);
      expect(
        text,
        contains(
          r'Desde la quincena del 15 de octubre tendrías $350.000 menos al '
          'mes para gastar que hoy.',
        ),
      );

      text = await at(200000);
      expect(
        text,
        contains(
          r'Desde la quincena del 15 de octubre tendrías $50.000 más al mes '
          'para gastar que hoy.',
        ),
      );

      // Paid at the end of the month, the contribution comes first.
      text = await at(600000, payday: '2026-10-31');
      expect(
        text,
        contains(
          r'El aporte del 16 de octubre sale antes de tu pago: hasta el 31 de '
          r'octubre podrías gastar $769.300.',
        ),
      );
    });

    testWidgets('never stops on an amount that arrives late', (tester) async {
      // After the 16th, the next contribution is November's: two fit
      // before the deadline, and $600.000 a month no longer gets there.
      appToday = DateTime(2026, 10, 20);
      final List<double> moved = await pump(
        tester,
        needed: 600000,
        deadline: '2026-12-20',
      );
      expect(screen(tester), isNot(contains(r'Necesitas $600.000')));
      expect(find.text(r'Usar $600.000 al mes'), findsNothing);
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(610000);
      expect(moved.last, 610000);

      // What the function says it takes now does get there, beyond the
      // slider's end.
      await pump(
        tester,
        needed: monthlyNeeded(2800000, 1000000, '2026-12-20'),
        deadline: '2026-12-20',
      );
      expect(find.text(r'Usar $900.000 al mes'), findsOneWidget);
    });
  });

  testWidgets('the ask bar turns to questions this account can answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        AskBar(
          onAsk: (_) {},
          enabled: true,
          examples: const <String>['¿Cuánto debo en la tarjeta?'],
        ),
      ),
    );
    expect(find.text('Pregúntale algo a tu plata'), findsOneWidget);
    await tester.pump(AskBar.turn);
    expect(
      find.text('Por ejemplo: ¿Cuánto debo en la tarjeta?'),
      findsOneWidget,
    );
    // Once the person is typing, it stays put.
    await tester.enterText(find.byType(TextField), '¿Cuánto');
    await tester.pump(AskBar.turn);
    expect(find.text('¿Cuánto'), findsOneWidget);
  });

  testWidgets('money lent is owed to the person, not spent', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => SharedPage(own: own),
    );
    final int spentBefore = own.ledger!.spentIn(2026, 10);
    await tapText(tester, 'Le presté');
    await tester.enterText(find.widgetWithText(TextField, '¿A quién?'), 'Juan');
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '100000');
    await tapText(tester, 'Guardar');

    expect(own.sharedBalance.$1, own.ledger!.minor(100000));
    // It left Bancolombia, linked, so the balance is right and it is not
    // spending.
    final List<Entry> entries = (await tester.runAsync(own.store.entries))!;
    expect(entries.where((Entry e) => e.payee == 'Juan'), hasLength(1));
    expect(own.ledger!.spentIn(2026, 10), spentBefore);
    expect(screen(tester), contains('Juan'));
    expect(tester.takeException(), isNull);
  });
}
