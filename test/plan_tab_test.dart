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
import 'package:quincena/ui/own/cushion_page.dart';
import 'package:quincena/ui/own/envelopes_page.dart';
import 'package:quincena/ui/own/plan_tab.dart';
import 'package:quincena/ui/own/what_if_page.dart';
import 'package:quincena/ui/own/wishes_page.dart';

import 'own_flow_test.dart' show settle;

Decimal d(String s) => Decimal.parse(s);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// 2.000.000 in the bank after September's pay, internet on the 10th, a
  /// trip to Cartagena with 300.000 a month going in, and savings apart.
  Future<OwnController> open(
    WidgetTester tester,
    Widget Function(OwnController own) page,
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
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('0'),
      );
      await store.addAccount(
        name: 'Ahorro',
        kind: AccountKind.investment,
        asset: Asset.cop,
        opening: d('1500000'),
        spendable: false,
      );
      await store.addEntry(
        accountId: bank.id,
        amount: d('2000000'),
        kind: EntryKind.income,
        date: DateTime(2026, 9, 30, 8),
        category: 'salary',
        payee: 'Nómina',
      );
      await store.addRecurring(
        name: 'Internet',
        amount: Money(d('100000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 10),
        accountId: bank.id,
        category: 'utilities',
      );
      await store.addGoal(
        name: 'Cartagena',
        target: Money(d('2000000'), Asset.cop),
        saved: Money(d('500000'), Asset.cop),
        monthly: Money(d('300000'), Asset.cop),
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

  // Rebuilt on every change, as the app's shell rebuilds its tabs.
  Widget tab(OwnController own) => Scaffold(
    body: ListenableBuilder(
      listenable: own,
      builder: (BuildContext context, _) =>
          SingleChildScrollView(child: PlanTab(own: own)),
    ),
  );

  testWidgets('four groups: the budget, goals, payments and tools', (
    tester,
  ) async {
    await open(tester, tab);
    // Each row under its group, top to bottom.
    final List<String> order = <String>[
      'PRESUPUESTO HASTA EL 15 DE OCTUBRE',
      'Repartir en sobres',
      'Ingresos variables',
      'Viajes',
      'METAS',
      'Cartagena',
      'Lo quiero, pero después',
      'PAGOS',
      'Pagos fijos',
      'Compras a cuotas',
      'Gastos compartidos',
      'Cargos para revisar',
      'HERRAMIENTAS',
      'Próximos 30 días',
      '¿Y si…?',
      'Colchón en días',
    ];
    final List<double> tops = <double>[
      for (final String text in order) tester.getTopLeft(find.text(text)).dy,
    ];
    for (var i = 1; i < order.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: order[i]);
    }
    for (final String gone in <String>['SI TE SIRVE', 'PARA DECIDIR']) {
      expect(find.text(gone), findsNothing);
    }

    // The way to a new goal sits in the goals' own header.
    final Finder add = find.text('Agregar meta');
    expect(
      tester.getCenter(add).dy,
      closeTo(tester.getCenter(find.text('METAS')).dy, 4),
    );
    expect(
      tester
          .getSize(find.ancestor(of: add, matching: find.byType(TextButton)))
          .height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(add);
    await settle(tester);
    expect(find.widgetWithText(TextField, '¿Para qué es?'), findsOneWidget);
  });

  testWidgets(
    'the fortnight split into envelopes, set aside and not free twice',
    (tester) async {
      final OwnController own = await open(tester, tab);
      expect(own.paidWithoutPlan, isTrue);
      expect(own.ledger!.freeUntilPayday, 1900000);
      expect(
        find.textContaining('Tienes ${pesos(1900000)} para repartir'),
        findsOneWidget,
      );

      await tester.tap(find.text('Repartir en sobres'));
      await settle(tester);
      // The goal gets half its month, the day to day six tenths of the rest.
      expect(find.widgetWithText(TextField, 'Cartagena'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Día a día'),
        '1.000.000',
      );
      await settle(tester);
      expect(find.text(pesos(750000)), findsOneWidget);

      await tester.tap(find.text('Guardar el reparto'));
      await settle(tester);
      expect(own.plan, isNotNull);
      expect(own.paidWithoutPlan, isFalse);
      // 150.000 set aside for the trip leaves the free amount.
      expect(own.ledger!.setAside, 150000);
      expect(own.ledger!.freeUntilPayday, 1750000);
      expect(
        find.text('Llevas ${pesos(0)} de ${pesos(1000000)}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('assigning more than there is asks first', (tester) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => EnvelopesPage(own: own),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Día a día'),
      '5.000.000',
    );
    await settle(tester);
    expect(find.text('Te pasas por'), findsOneWidget);
    // Over by the day to day and the trip's 150.000, less the 1.900.000
    // there is, said without a minus: «Te pasas por» says it is over.
    expect(find.text(pesos(3250000)), findsOneWidget);
    expect(find.text(pesos(-3250000)), findsNothing);
    await tester.tap(find.text('Guardar el reparto'));
    await settle(tester);
    expect(find.text('Asignas más de lo que hay'), findsOneWidget);
    await tester.tap(find.text('Ajustar'));
    await settle(tester);
    expect(own.plan, isNull);
  });

  testWidgets('a goal is added, arrives by its month, and goes', (
    tester,
  ) async {
    final OwnController own = await open(tester, tab);
    // 1.500.000 to go at 300.000 a month: five months.
    expect(find.textContaining('llega en marzo de 2027'), findsOneWidget);

    await tester.tap(find.text('Agregar meta'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Para qué es?'),
      'Moto',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto quieres juntar?'),
      '6.000.000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto pones al mes?'),
      '500.000',
    );
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(find.text('Moto'), findsOneWidget);
    expect(find.textContaining('llega en octubre de 2027'), findsOneWidget);

    await tester.tap(find.text('Moto'));
    await settle(tester);
    await tester.tap(find.text('Borrar meta').last);
    await settle(tester);
    await tester.tap(find.text('Borrar meta').last);
    await settle(tester);
    expect(find.text('Moto'), findsNothing);
    expect((await tester.runAsync(own.store.snapshot))!.goals, hasLength(1));
  });

  testWidgets('the cushion asks where it is, and says why it cannot count', (
    tester,
  ) async {
    await open(tester, (OwnController own) => CushionPage(own: own));
    expect(find.textContaining('Elige abajo las cuentas'), findsOneWidget);
    await tester.tap(find.text('Ahorro'));
    await settle(tester);
    // A few days of history: no average to trust yet.
    expect(
      find.textContaining('menos de un mes de movimientos'),
      findsOneWidget,
    );
    final Finder note = find.textContaining(
      'No hay una cifra correcta para todos',
    );
    await tester.scrollUntilVisible(note, 200);
    expect(note, findsOneWidget);
  });

  testWidgets('a wish shows what it would do to a goal', (tester) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => WishesPage(own: own),
    );
    await tester.tap(find.text('Agregar deseo'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Qué quieres?'),
      'Audífonos',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '600.000',
    );
    await tester.tap(find.text('Esperar 30 días antes de decidir'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(own.wishes.single.price, 600000);
    // Two months more at 300.000 a month.
    expect(
      find.text(
        'Si lo compras, Cartagena llegaría en mayo de 2027 en vez de marzo de 2027.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Esperas hasta el 2 de noviembre'),
      findsOneWidget,
    );
  });

  testWidgets('what if a charge goes up: compared, saved, applied when sure', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => WhatIfPage(own: own),
    );
    await tester.tap(find.text('Sube un gasto'));
    await settle(tester);
    await tester.tap(find.text('Internet'));
    await tester.enterText(find.byType(TextField), '50.000');
    await settle(tester);
    expect(find.text('Saldo mínimo en 45 días'), findsOneWidget);

    await tester.tap(find.text('Guardar el escenario'));
    await settle(tester);
    expect(own.scenarios, hasLength(1));
    // Saving it changed nothing.
    expect(
      (await tester.runAsync(own.store.recurring))!.single.amount.amount,
      d('100000'),
    );

    await tester.tap(find.text('Aplicar'));
    await settle(tester);
    await tester.tap(find.text('Aplicar').last);
    await settle(tester);
    expect(
      (await tester.runAsync(own.store.recurring))!.single.amount.amount,
      d('150000'),
    );
  });
}
