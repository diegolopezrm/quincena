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
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
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
    Future<List<double>> pump(
      WidgetTester tester, {
      double monthly = 250000,
    }) async {
      final List<double> moved = <double>[];
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          GoalPlanner(
            name: 'Cartagena',
            target: 2800000,
            saved: 1000000,
            monthly: monthly,
            min: 100000,
            max: 800000,
            arrival: 'mayo de 2027',
            onTime: false,
            deadlineLabel: '20 de diciembre',
            needed: 600000,
            onMonthlyChanged: moved.add,
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
