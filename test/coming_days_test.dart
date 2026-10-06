import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/close_page.dart';
import 'package:quincena/ui/own/coming_days_page.dart';
import 'package:quincena/ui/own/home_tab.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart' as harness;

Decimal d(String s) => Decimal.parse(s);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// 900.000 in the bank, a 100.000 cushion, internet on the 10th, and two
  /// whole fortnights of groceries and restaurants behind.
  Future<OwnController> open(
    WidgetTester tester,
    Widget Function(OwnController) page,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => now,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        Profile(
          name: 'Ana',
          base: Asset.cop,
          schedule: const TwiceMonthly(),
          cushion: d('100000'),
        ),
      );
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1790000'),
      );
      for (final (String amount, DateTime on, String category)
          in <(String, DateTime, String)>[
            ('300000', DateTime(2026, 8, 30, 12), 'groceries'),
            ('100000', DateTime(2026, 9, 5, 12), 'restaurants'),
            ('290000', DateTime(2026, 9, 16, 12), 'groceries'),
            ('200000', DateTime(2026, 9, 18, 12), 'restaurants'),
          ]) {
        await store.addEntry(
          accountId: bank.id,
          amount: d(amount),
          kind: EntryKind.expense,
          date: on,
          category: category,
          payee: category == 'groceries' ? 'Éxito' : 'Crepes',
        );
      }
      await store.addRecurring(
        name: 'Internet',
        amount: Money(d('300000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 10),
        accountId: bank.id,
        category: 'utilities',
      );
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: page(own),
      ),
    );
    await settle(tester);
    return own;
  }

  testWidgets('a price tried today and after payday, and nothing saved', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => ComingDaysPage(own: own, tryPurchase: true),
    );
    expect(own.ledger!.balance, 900000);
    expect(
      find.text(
        'Saldo mínimo estimado antes del pago: ${pesos(600000)} el 10 oct',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '550.000',
    );
    await settle(tester);
    // 900.000 - 550.000 - 300.000 on the 10th: 50.000, under the cushion.
    expect(find.text('Quedarías por debajo de tu colchón'), findsWidgets);
    expect(
      find.textContaining('El 10 oct quedarías con ${pesos(50000)}'),
      findsOneWidget,
    );
    expect(find.text('Si compras hoy'), findsOneWidget);
    expect(
      find.text(
        'Es una estimación con lo que está programado, no una garantía.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '700.000',
    );
    await settle(tester);
    expect(find.text('No alcanza antes del pago'), findsWidgets);
    expect(
      find.textContaining('te faltarían ${pesos(100000)}'),
      findsOneWidget,
    );

    // After payday, with no pay known: it says so instead of counting one.
    await tester.tap(find.text('Después del pago'));
    await settle(tester);
    expect(find.textContaining('No sé cuánto te pagan'), findsOneWidget);
    expect(await tester.runAsync(own.store.entries), hasLength(4));
  });

  testWidgets('a charge moved in the simulation moves only the dashed line', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => ComingDaysPage(own: own),
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Mover en la simulación').first,
      200,
    );
    await tester.tap(find.byTooltip('Mover en la simulación').first);
    await settle(tester);
    // The date picker: the 20th instead of the 10th.
    await tester.tap(find.text('20'));
    final String ok = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(ok));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Estás probando'),
      -200,
    );
    expect(find.textContaining('Estás probando'), findsOneWidget);
    expect(
      (await tester.runAsync(own.store.recurring))!.single.nextDate,
      DateTime(2026, 10, 10),
    );

    await tester.tap(find.text('Quitar lo que pruebas'));
    await settle(tester);
    expect(find.textContaining('Estás probando'), findsNothing);
  });

  testWidgets('the close tells what changed, what comes, and one thing to do', (
    tester,
  ) async {
    await open(tester, (OwnController own) => ClosePage(own: own));
    expect(
      find.text('Del 15 de septiembre al 29 de septiembre'),
      findsOneWidget,
    );
    // 490.000 against 400.000 the fortnight before.
    expect(
      find.text(
        'Gastaste ${pesos(490000)}, ${pesos(90000)} más que la quincena anterior.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Restaurantes pasó de ${pesos(100000)} a ${pesos(200000)}',
      ),
      findsOneWidget,
    );
    final Finder coming = find.textContaining(
      'Hasta el 15 de octubre hay ${pesos(300000)} comprometidos.',
    );
    await tester.scrollUntilVisible(coming, 200);
    expect(coming, findsOneWidget);

    await tester.ensureVisible(find.text('Ver los pagos'));
    await settle(tester);
    await tester.tap(find.text('Ver los pagos'));
    await settle(tester);
    expect(find.text('Crepes'), findsOneWidget);
  });

  testWidgets('the dashed keys under the chart show their dashes', (
    tester,
  ) async {
    await open(tester, (OwnController own) => ComingDaysPage(own: own));
    final Finder key = find
        .ancestor(
          of: find.text('Colchón de ${pesos(100000)}'),
          matching: find.byType(Row),
        )
        .first;
    final Finder dashes = find.descendant(
      of: key,
      matching: find.byType(ColoredBox),
    );
    expect(dashes, findsNWidgets(3));
    for (final Element dash in dashes.evaluate()) {
      expect((dash.renderObject! as RenderBox).size.height, 2);
    }
  });

  testWidgets('a category that fell to nothing shows the payments of the '
      'period before, not an empty sheet', (tester) async {
    await harness.openPage(
      tester,
      (OwnController own) => ClosePage(own: own),
      data: (QuincenaStore store, Account bank, _) async {
        for (final (String amount, DateTime on, String category, String payee)
            in <(String, DateTime, String, String)>[
              ('90000', DateTime(2026, 8, 30, 12), 'groceries', 'Éxito'),
              ('1200000', DateTime(2026, 9, 5, 12), 'housing', 'Arriendo'),
              ('80000', DateTime(2026, 9, 16, 12), 'groceries', 'D1'),
            ]) {
          await store.addEntry(
            accountId: bank.id,
            amount: d(amount),
            kind: EntryKind.expense,
            date: on,
            category: category,
            payee: payee,
          );
        }
      },
    );
    await harness.tapText(tester, 'Arriendo');
    expect(find.text('Arriendo del 15 sept al 29 sept'), findsOneWidget);
    expect(
      find.text(
        'En esta quincena no hubo pagos de Arriendo. Estos son los de la '
        'anterior:',
      ),
      findsOneWidget,
    );
    expect(find.text(pesos(-1200000)), findsWidgets);
    expect(find.text('5 sept'), findsOneWidget);
  });

  testWidgets('without a cushion, a day under it is a day out of money', (
    tester,
  ) async {
    // 2.000.000 after the pay, and rent of 2.300.000 on the 10th.
    final OwnController own = await harness.openPage(
      tester,
      (OwnController own) => Scaffold(
        body: SingleChildScrollView(
          child: OwnHomeTab(own: own, onSeeAll: () {}),
        ),
      ),
      data: (QuincenaStore store, Account bank, _) => store.addEntry(
        accountId: bank.id,
        amount: d('2300000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 10, 12),
        category: 'housing',
        payee: 'Arriendo',
      ),
    );
    expect(own.ledger!.cushion, 0);
    expect(find.text('El 10 oct te quedarías sin plata.'), findsOneWidget);
    expect(find.textContaining('colchón'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: ComingDaysPage(own: own),
      ),
    );
    await settle(tester);
    expect(find.text('El 10 oct te quedarías sin plata.'), findsOneWidget);
    await harness.reveal(tester, find.text('Sin plata'));
    expect(find.text('Sin plata'), findsWidgets);
    expect(find.text('Bajo tu colchón'), findsNothing);
  });

  testWidgets('the close says what is missing, not a negative to spend', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => ClosePage(own: own),
    );
    expect(
      find.text('Puedes gastar hasta el pago: ${pesos(500000)}'),
      findsOneWidget,
    );
    // 800.000 due on the 8th: 300.000 short of payday.
    await tester.runAsync(() async {
      await own.store.addEntry(
        accountId: own.accounts.single.id,
        amount: d('800000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 8, 9),
        category: 'other',
        payee: 'Matrícula',
      );
    });
    await settle(tester);
    expect(own.ledger!.freeUntilPayday, -300000);
    expect(
      find.text('Te faltan ${pesos(300000)} para llegar al pago'),
      findsOneWidget,
    );
    expect(find.textContaining('Puedes gastar hasta el pago'), findsNothing);
  });

  testWidgets('a day says what is expected apart from what is tried', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => ComingDaysPage(own: own),
    );
    // With the pay known, the 15th expects it.
    await tester.runAsync(
      () => own.store.saveProfile(
        Profile(
          name: 'Ana',
          base: Asset.cop,
          schedule: const TwiceMonthly(),
          cushion: d('100000'),
          pay: d('2000000'),
        ),
      ),
    );
    await settle(tester);
    // 900.000 less the internet of the 10th; 2.000.000 more if paid.
    final Finder expected = find.text(
      'Quedan ${pesos(600000)} · si llega lo que esperas, ${pesos(2600000)}',
    );
    await harness.reveal(tester, expected);
    expect(expected, findsOneWidget);
    expect(find.textContaining('con lo que pruebas'), findsNothing);

    await harness.tapText(tester, '¿Me alcanza?');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '50.000',
    );
    await settle(tester);
    final Finder tried = find.text(
      'Quedan ${pesos(600000)} · con lo que pruebas, ${pesos(2550000)}',
    );
    await harness.reveal(tester, tried);
    expect(tried, findsOneWidget);
  });
}
