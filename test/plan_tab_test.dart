import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/plan.dart';
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
import 'page_harness.dart';

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

  testWidgets('four groups by what one wants: organize, achieve, pay off '
      'and weigh', (tester) async {
    await open(tester, tab);
    // Each row under its group, top to bottom.
    final List<String> order = <String>[
      'ORGANIZAR MI PLATA',
      'Hasta el 15 de octubre',
      'Repartir en sobres',
      'Ingresos variables',
      'Pagos fijos',
      'LO QUE QUIERO LOGRAR',
      'Cartagena',
      'Viajes',
      'Lo quiero, pero después',
      'LO QUE ESTOY PAGANDO',
      'Compras a cuotas',
      'Gastos compartidos',
      'HERRAMIENTAS',
      'Próximos 30 días',
      '¿Y si…?',
      'Fondo de emergencia en días',
      'Cargos para revisar',
    ];
    final List<double> tops = <double>[
      for (final String text in order) tester.getTopLeft(find.text(text)).dy,
    ];
    for (var i = 1; i < order.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: order[i]);
    }
    for (final String gone in <String>[
      'SI TE SIRVE',
      'PARA DECIDIR',
      'METAS',
      'PAGOS',
    ]) {
      expect(find.text(gone), findsNothing);
    }

    // The way to a new goal sits in the goals' own header.
    final Finder add = find.text('Agregar meta');
    expect(
      tester.getCenter(add).dy,
      closeTo(tester.getCenter(find.text('LO QUE QUIERO LOGRAR')).dy, 4),
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

    // Deleting it asks nothing: it says so, with a way back.
    await tester.tap(find.text('Moto'));
    await settle(tester);
    await tester.tap(find.text('Borrar meta').last);
    await settle(tester);
    expect(find.text('Moto'), findsNothing);
    expect(find.text('Se borró «Moto».'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
    expect((await tester.runAsync(own.store.snapshot))!.goals, hasLength(1));
  });

  testWidgets('what a form misses is said until something is typed', (
    tester,
  ) async {
    await open(tester, tab);
    await tester.tap(find.text('Agregar meta'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await settle(tester);
    final Finder missing = find.text(
      'Ponle un nombre y cuánto quieres juntar.',
    );
    expect(missing, findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Para qué es?'),
      'Moto',
    );
    await settle(tester);
    expect(missing, findsNothing);
  });

  testWidgets('a goal reached says so, not the month it would arrive', (
    tester,
  ) async {
    final OwnController own = await open(tester, tab);
    await tester.runAsync(
      () => own.store.addGoal(
        name: 'Bicicleta',
        target: Money(d('800000'), Asset.cop),
        saved: Money(d('800000'), Asset.cop),
        monthly: Money(d('100000'), Asset.cop),
      ),
    );
    await settle(tester);
    final Finder row = find.textContaining('Meta cumplida');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: row, matching: find.byType(InkWell)).first,
        matching: find.textContaining('llega en'),
      ),
      findsNothing,
    );
  });

  testWidgets('a goal deleted takes its envelope, and what it set aside '
      'is free again', (tester) async {
    final OwnController own = await open(tester, tab);
    await tester.tap(find.text('Repartir en sobres'));
    await settle(tester);
    await tester.tap(find.text('Guardar el reparto'));
    await settle(tester);
    expect(own.ledger!.setAside, 150000);
    expect(own.ledger!.freeUntilPayday, 1750000);

    final SavingsGoal goal = own.snapshot!.goals.single;
    final List<String> envelopes = <String>[
      for (final Envelope e in own.plan!.envelopes) e.id,
    ];
    await tester.tap(find.text('Cartagena').last);
    await settle(tester);
    await tester.tap(find.text('Borrar meta').last);
    await settle(tester);
    expect(own.snapshot!.goals, isEmpty);
    // Only the day to day stays, and nothing is set aside.
    expect(own.plan!.envelopes.map((e) => e.name), <String>['']);
    expect(own.ledger!.setAside, 0);
    expect(own.ledger!.freeUntilPayday, 1900000);
    expect(find.text('Cartagena'), findsNothing);

    // «Deshacer» brings the goal back with its envelope, where it was.
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(own.snapshot!.goals.single.id, goal.id);
    expect(own.snapshot!.goals.single.saved, goal.saved);
    expect(<String>[
      for (final Envelope e in own.plan!.envelopes) e.id,
    ], envelopes);
    expect(own.ledger!.setAside, 150000);
    expect(own.ledger!.freeUntilPayday, 1750000);
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

  testWidgets('the emergency fund is offered money, not a card or coins', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => CushionPage(own: own),
    );
    await tester.runAsync(() async {
      await own.store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: d('-300000'),
      );
      await own.store.addAccount(
        name: 'Binance',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: d('100'),
        spendable: false,
      );
    });
    await settle(tester);
    expect(find.widgetWithText(CheckboxListTile, 'Ahorro'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Bancolombia'),
      findsOneWidget,
    );
    expect(find.widgetWithText(CheckboxListTile, 'Visa'), findsNothing);
    expect(find.widgetWithText(CheckboxListTile, 'Binance'), findsNothing);
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

  testWidgets('a wish opens with what it has, and changes in its place', (
    tester,
  ) async {
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
    final Wish first = own.wishes.single;

    await tester.tap(find.text('Audífonos'));
    await settle(tester);
    expect(find.text('Editar deseo'), findsOneWidget);
    expect(find.widgetWithText(TextField, '600.000'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '550.000',
    );
    await tester.tap(find.text('Muy deseado'));
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    final Wish changed = own.wishes.single;
    expect(changed.id, first.id);
    expect(changed.price, 550000);
    expect(changed.priority, 1);
    // The wait already under way keeps its day.
    expect(changed.waitUntil, first.waitUntil);
  });

  testWidgets('a wish bought opens as the expense, and goes once saved', (
    tester,
  ) async {
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
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    final int before = own.ledger!.balance;

    await tester.tap(find.text('Lo compré'));
    await settle(tester);
    expect(find.widgetWithText(TextField, '600.000'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Audífonos'), findsOneWidget);
    // Closed without saving, the wish stays.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.widgetWithText(TextField, '600.000'), findsNothing);
    expect(own.wishes, hasLength(1));

    await tester.tap(find.text('Lo compré'));
    await settle(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await settle(tester);
    expect(own.wishes, isEmpty);
    expect(own.ledger!.balance, before - 600000);
    expect(find.text('Audífonos'), findsNothing);
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
    // No whole fortnight recorded: the day to day is left out, and said.
    expect(find.text('Contar el gasto del día a día'), findsNothing);
    expect(
      find.textContaining('No incluye el gasto del día a día'),
      findsOneWidget,
    );

    await tester.tap(find.text('Guardar el escenario'));
    await settle(tester);
    expect(own.scenarios, hasLength(1));
    // Saving it changed nothing.
    expect(
      (await tester.runAsync(own.store.recurring))!.single.amount.amount,
      d('100000'),
    );

    await tester.ensureVisible(find.text('Aplicar'));
    await settle(tester);
    await tester.tap(find.text('Aplicar'));
    await settle(tester);
    await tester.tap(find.text('Aplicar').last);
    await settle(tester);
    expect(
      (await tester.runAsync(own.store.recurring))!.single.amount.amount,
      d('150000'),
    );
    // Applied, it is not kept to be weighed again over the new price.
    expect(own.scenarios, isEmpty);
  });

  testWidgets('saving more each payday is applied to a goal, said first', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => WhatIfPage(own: own),
    );
    await tester.enterText(find.byType(TextField), '100.000');
    await settle(tester);
    await centered(tester, find.text('Aplicar'));
    await tester.tap(find.text('Aplicar'));
    await settle(tester);
    // Two paydays a month: 200.000 more a month.
    expect(
      find.text(
        'Lo que apartas al mes para Cartagena pasará de ${pesos(300000)} a '
        '${pesos(500000)}.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Aplicar').last);
    await settle(tester);
    expect(own.snapshot!.goals.single.monthly.amount, d('500000'));
  });

  testWidgets('what if counts what the day to day usually takes, or says it '
      'leaves it out', (tester) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => WhatIfPage(own: own),
    );
    await tester.runAsync(() async {
      final String bank = own.accounts
          .firstWhere((Account a) => a.name == 'Bancolombia')
          .id;
      // The fortnight from the 15th is whole: 450.000 in 15 days.
      for (final (String amount, DateTime on) in <(String, DateTime)>[
        ('20000', DateTime(2026, 9, 14, 12)),
        ('450000', DateTime(2026, 9, 20, 12)),
      ]) {
        await own.store.addEntry(
          accountId: bank,
          amount: d(amount),
          kind: EntryKind.expense,
          date: on,
          category: 'groceries',
          payee: 'Éxito',
        );
      }
    });
    await settle(tester);
    await tester.enterText(find.byType(TextField), '100.000');
    await settle(tester);
    expect(
      find.text(
        'Lo que sueles gastar: unos ${pesos(30000)} al día, sin tus pagos '
        'fijos.',
      ),
      findsOneWidget,
    );
    final Finder counted = find.text(
      'Cuenta tu pago esperado, lo programado y unos ${pesos(30000)} al día '
      'de gasto del día a día. Nada de esto cambia tus cuentas.',
    );
    await tester.ensureVisible(counted);
    await settle(tester);
    expect(counted, findsOneWidget);
    final String lowest = find
        .textContaining(' · ')
        .evaluate()
        .map((Element e) => (e.widget as Text).data!)
        .first;

    await centered(tester, find.text('Contar el gasto del día a día'));
    await tester.tap(find.text('Contar el gasto del día a día'));
    await settle(tester);
    expect(counted, findsNothing);
    expect(
      find.textContaining(
        'sin el gasto del día a día: tu saldo real será menor',
      ),
      findsOneWidget,
    );
    // Without the day to day, the lowest balance comes out higher.
    expect(
      find
          .textContaining(' · ')
          .evaluate()
          .map((Element e) => (e.widget as Text).data!)
          .first,
      isNot(lowest),
    );
  });

  /// The amount on the line of the sum that says [label].
  String lineOf(WidgetTester tester, String label) {
    final Finder row = find.ancestor(
      of: find.text(label),
      matching: find.byType(Row),
    );
    return tester
        .widgetList<Text>(
          find.descendant(of: row.first, matching: find.byType(Text)),
        )
        .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .firstWhere((String t) => t != label);
  }

  testWidgets('what there is to split is a sum that adds up, line by line', (
    tester,
  ) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => EnvelopesPage(own: own),
      data: (QuincenaStore store, Account bank, Account card) async {
        await store.saveProfile(
          Profile(
            name: 'Ana',
            base: Asset.cop,
            schedule: const TwiceMonthly(),
            cushion: d('200000'),
          ),
        );
        await store.addEntry(
          accountId: bank.id,
          amount: d('1000000'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 2, 9),
          category: 'freelance',
          payee: 'Estudio Sur',
        );
        await store.addEntry(
          accountId: card.id,
          amount: d('300000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2, 20),
          category: 'shopping',
          payee: 'Falabella',
        );
        await store.addRecurring(
          name: 'Internet',
          amount: Money(d('100000'), Asset.cop),
          cadence: Cadence.monthly,
          nextDate: DateTime(2026, 10, 10),
          accountId: bank.id,
          category: 'utilities',
        );
        await store.setSetting(
          'freelance',
          jsonEncode(
            FreelancePlan(
              reservePercent: 15,
              reserveSince: DateTime(2026, 10, 1),
            ).toJson(),
          ),
        );
      },
    );
    // 3.000.000 in the bank and 300.000 owed on the Visa; internet, the
    // cushion and 15 % of the client's 1.000.000 left out.
    expect(lineOf(tester, 'En tus cuentas de uso diario'), pesos(3000000));
    expect(lineOf(tester, 'Lo que debes en tarjetas'), pesos(-300000));
    expect(lineOf(tester, 'Pagos hasta el 15 oct'), pesos(-100000));
    expect(lineOf(tester, 'Colchón'), pesos(-200000));
    expect(lineOf(tester, 'Reserva de ingresos variables'), pesos(-150000));
    expect(
      3000000 - 300000 - 100000 - 200000 - 150000,
      own.ledger!.freeUntilPayday,
    );
    expect(find.text(pesos(2250000)), findsWidgets);
  });

  testWidgets('with nothing committed, no cushion and no reserve, the sum '
      'names none of them', (tester) async {
    await openPage(tester, (OwnController own) => EnvelopesPage(own: own));
    expect(lineOf(tester, 'En tus cuentas de uso diario'), pesos(2000000));
    for (final String gone in <String>[
      'Lo que debes en tarjetas',
      'Colchón',
      'Reserva de ingresos variables',
    ]) {
      expect(find.text(gone), findsNothing);
    }
    expect(find.textContaining('Pagos hasta'), findsNothing);
    expect(find.textContaining('colchón'), findsNothing);
  });

  testWidgets('just split, the day to day has spent nothing; a lunch after '
      'comes out of it and not of what is left', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              SingleChildScrollView(child: PlanTab(own: own)),
        ),
      ),
      // Spent before the split.
      data: (QuincenaStore store, Account bank, Account card) => store.addEntry(
        accountId: bank.id,
        amount: d('398200'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 1, 12),
        category: 'groceries',
        payee: 'Éxito',
      ),
    );
    await tester.tap(find.text('Repartir en sobres'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Día a día'),
      '200.000',
    );
    await settle(tester);
    await tester.tap(find.text('Guardar el reparto'));
    await settle(tester);
    expect(find.text('Llevas ${pesos(0)} de ${pesos(200000)}'), findsOneWidget);
    expect(find.textContaining('Te pasaste por'), findsNothing);
    // 2.000.000 less what went before the split and the day to day.
    expect(lineOf(tester, 'Sin asignar'), pesos(1401800));

    await tester.runAsync(
      () => own.store.addEntry(
        accountId: own.accounts.first.id,
        amount: d('50000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3, 13),
        category: 'restaurants',
        payee: 'Almuerzo',
      ),
    );
    await settle(tester);
    expect(
      find.text('Llevas ${pesos(50000)} de ${pesos(200000)}'),
      findsOneWidget,
    );
    expect(lineOf(tester, 'Sin asignar'), pesos(1401800));
    // What can be spent is what the day to day has left and what is not
    // assigned.
    expect(own.ledger!.freeUntilPayday, 1401800 + 150000);

    // Opened again, the split counts the lunch as the day to day's.
    await tester.tap(find.text('Ajustar el reparto'));
    await settle(tester);
    expect(lineOf(tester, 'Gastado del día a día'), pesos(50000, signed: true));
    expect(lineOf(tester, 'Sin asignar'), pesos(1401800));
  });

  testWidgets('a goal whose date went by opens its calendar, to move it', (
    tester,
  ) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              SingleChildScrollView(child: PlanTab(own: own)),
        ),
      ),
      data: (QuincenaStore store, Account bank, Account card) => store.addGoal(
        name: 'Moto',
        target: Money(d('6000000'), Asset.cop),
        saved: Money(d('1500000'), Asset.cop),
        monthly: Money(d('500000'), Asset.cop),
        deadline: DateTime(2026, 9, 20),
      ),
    );
    // The row says the date went by, with its year.
    expect(
      find.text(
        'La fecha, el 20 de septiembre de 2026, ya pasó: cámbiala en la meta.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Moto');
    await tapText(tester, 'Para el 20 de septiembre de 2026');
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    // From September, on to December.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Mes siguiente'));
      await settle(tester);
    }
    await tester.tap(find.text('20').last);
    await tester.tap(find.text('ACEPTAR'));
    await settle(tester);
    expect(find.text('Para el 20 de diciembre de 2026'), findsOneWidget);
    await tapText(tester, 'Guardar');
    expect(own.snapshot!.goals.single.deadline, DateTime(2026, 12, 20));
  });
}

/// Scrolls the page's list until [finder] is built, then puts it in the
/// middle of the screen, clear of the bar at the top.
Future<void> centered(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await settle(tester);
}
