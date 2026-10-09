import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/freelance_page.dart';
import 'package:quincena/ui/own/home_tab.dart';
import 'package:quincena/ui/own/plan_tab.dart';
import 'package:quincena/ui/own/shared_page.dart';
import 'package:quincena/ui/own/trips_page.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  Future<Entry> dinner(QuincenaStore store, Account bank) => store.addEntry(
    accountId: bank.id,
    amount: d('120000'),
    kind: EntryKind.expense,
    date: DateTime(2026, 10, 2, 21),
    category: 'restaurants',
    payee: 'Cena',
  );

  testWidgets('a movement is split by name: only the person\'s part is '
      'spending', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
        ),
      ),
      data: (QuincenaStore store, Account bank, _) => dinner(store, bank),
    );
    expect(own.ledger!.spentIn(2026, 10), 120000);
    await tapText(tester, 'Cena');
    await tapText(tester, 'Dividir este gasto');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Con quién lo divides?'),
      'Ana, Juan',
    );
    await settle(tester);
    expect(find.text(pesos(40000)), findsNWidgets(3));
    expect(
      find.text('Tu parte es ${pesos(40000)}; ${pesos(80000)} te los deben.'),
      findsOneWidget,
    );
    await tapText(tester, 'Guardar');

    final Group group = own.groups.single;
    expect(group.members.map((Member m) => m.name), <String>[
      '',
      'Ana',
      'Juan',
    ]);
    expect(group.balances[meId], 80000);
    expect(own.ledger!.spentIn(2026, 10), 40000);
    expect(own.sharedBalance, (80000, 0));
    expect(
      find.textContaining('Dividido: tu parte ${pesos(40000)}'),
      findsOneWidget,
    );
  });

  testWidgets('a split by amounts opens again with its amounts, and what '
      'saving said goes once something changes', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
        ),
      ),
      data: (QuincenaStore store, Account bank, _) => dinner(store, bank),
    );
    await tapText(tester, 'Cena');
    await tapText(tester, 'Dividir este gasto');
    await tapText(tester, 'Guardar');
    expect(find.text('Agrega al menos a una persona más.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Con quién lo divides?'),
      'Ana',
    );
    await settle(tester);
    expect(find.text('Agrega al menos a una persona más.'), findsNothing);

    await tapText(tester, 'Por montos');
    await tester.enterText(find.widgetWithText(TextField, 'Tu parte'), '50000');
    await tester.enterText(
      find.widgetWithText(TextField, 'Parte de Ana'),
      '70000',
    );
    await settle(tester);
    await tapText(tester, 'Guardar');
    final Entry dinnerEntry = own.snapshot!.entries.singleWhere(
      (Entry e) => e.payee == 'Cena',
    );
    expect(own.splitOf(dinnerEntry.id)!.$2.shares, <String, int>{
      meId: 50000,
      'p-ana': 70000,
    });

    await tapText(tester, 'Cena');
    await tapText(tester, 'Cambiar la división');
    expect(
      find.descendant(
        of: find.widgetWithText(TextField, 'Tu parte'),
        matching: find.text('50.000'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(TextField, 'Parte de Ana'),
        matching: find.text('70.000'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Faltan'), findsNothing);
    await tapText(tester, 'Guardar');
    expect(own.splitOf(dinnerEntry.id)!.$2.shares, <String, int>{
      meId: 50000,
      'p-ana': 70000,
    });
  });

  testWidgets('a split needs someone besides the person with a part', (
    tester,
  ) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
        ),
      ),
      data: (QuincenaStore store, Account bank, _) => dinner(store, bank),
    );
    await tapText(tester, 'Cena');
    await tapText(tester, 'Dividir este gasto');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Con quién lo divides?'),
      'Ana, Juan',
    );
    await settle(tester);
    // Ana and Juan unticked: the whole dinner would be the person's.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.tap(find.byType(Checkbox).at(2));
    await settle(tester);
    await tapText(tester, 'Guardar');
    final Entry dinnerEntry = own.snapshot!.entries.singleWhere(
      (Entry e) => e.payee == 'Cena',
    );
    expect(own.splitOf(dinnerEntry.id), isNull);
    expect(
      find.text('Marca al menos a otra persona con su parte.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(Checkbox).at(1));
    await settle(tester);
    expect(
      find.text('Marca al menos a otra persona con su parte.'),
      findsNothing,
    );
    await tapText(tester, 'Guardar');
    expect(own.splitOf(dinnerEntry.id)!.$2.shares, <String, int>{
      meId: 60000,
      'p-ana': 60000,
    });
  });

  testWidgets('a split follows its movement: deleted, put right or no '
      'longer an expense', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
        ),
      ),
      data: (QuincenaStore store, Account bank, _) async {
        await dinner(store, bank);
        await store.addEntry(
          accountId: bank.id,
          amount: d('60000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 1, 13),
          category: 'restaurants',
          payee: 'Almuerzo',
        );
      },
    );
    Future<Entry> splitWithAna(String payee) async {
      await tapText(tester, payee);
      await tapText(tester, 'Dividir este gasto');
      await tester.enterText(
        find.widgetWithText(TextField, '¿Con quién lo divides?'),
        'Ana',
      );
      await settle(tester);
      await tapText(tester, 'Guardar');
      final Entry entry = own.snapshot!.entries.singleWhere(
        (Entry e) => e.payee == payee,
      );
      expect(own.splitOf(entry.id), isNotNull);
      return entry;
    }

    int owed() => <int>[
      for (final Group g in own.groups) g.balances['p-ana'] ?? 0,
    ].fold(0, (int a, int b) => a + b);

    final Entry cena = await splitWithAna('Cena');
    expect(owed(), -60000);
    await tapText(tester, 'Cena');
    await tapText(tester, 'Eliminar');
    expect(
      find.text(
        'También se quita su división: lo que te deben por este gasto deja '
        'de contar.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Eliminar').last);
    await settle(tester);
    expect(own.snapshot!.entries.any((Entry e) => e.id == cena.id), isFalse);
    expect(own.splitOf(cena.id), isNull);
    expect(owed(), 0);

    // Put right at 70.000, the lunch is split again at the new amount.
    final Entry lunch = await splitWithAna('Almuerzo');
    expect(owed(), -30000);
    await tapText(tester, 'Almuerzo');
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '70000');
    await settle(tester);
    await tapText(tester, 'Guardar');
    expect(own.splitOf(lunch.id)!.$2.shares, <String, int>{
      meId: 35000,
      'p-ana': 35000,
    });
    expect(owed(), -35000);
    expect(
      find.textContaining('Dividido: tu parte ${pesos(35000)}'),
      findsOneWidget,
    );

    // Told it was money in, it is no longer something to split, and the
    // form stops offering to split it as soon as it says so.
    await tapText(tester, 'Almuerzo');
    await tapText(tester, 'Ingreso');
    expect(find.text('Cambiar la división'), findsNothing);
    await tapText(tester, 'Gasto');
    expect(find.text('Cambiar la división'), findsOneWidget);
    await tapText(tester, 'Ingreso');
    await tapText(tester, 'Guardar');
    expect(
      own.snapshot!.entries.singleWhere((Entry e) => e.id == lunch.id).kind,
      EntryKind.income,
    );
    expect(own.splitOf(lunch.id), isNull);
    expect(owed(), 0);
  });

  testWidgets('a repayment tied to its movement is money back, and a '
      'reminder goes only when shared', (tester) async {
    final List<MethodCall> calls = <MethodCall>[];
    final OwnController own = await openPage(
      tester,
      (OwnController own) => GroupPage(own: own, id: 'g'),
      calls: calls,
      data: (QuincenaStore store, Account bank, _) async {
        final Entry e = await dinner(store, bank);
        await store.addEntry(
          accountId: bank.id,
          amount: d('40000'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 3, 8),
          category: 'other_income',
          payee: 'Ana te envió',
        );
        await store.setSetting(
          'shared.groups',
          jsonEncode(<Object?>[
            Group(
              id: 'g',
              name: 'Cena del jueves',
              members: const <Member>[
                Member(id: meId, name: ''),
                Member(id: 'ana', name: 'Ana'),
                Member(id: 'juan', name: 'Juan'),
              ],
              expenses: <SharedExpense>[
                SharedExpense(
                  id: 'x',
                  label: 'Cena',
                  date: e.date,
                  paidBy: meId,
                  shares: const <String, int>{
                    meId: 40000,
                    'ana': 40000,
                    'juan': 40000,
                  },
                  entryId: e.id,
                ),
              ],
            ).toJson(),
          ]),
        );
      },
    );
    expect(find.text('Ana te paga ${pesos(40000)}'), findsOneWidget);
    expect(find.text('Juan te paga ${pesos(40000)}'), findsOneWidget);
    expect(own.ledger!.incomeIn(2026, 10), 40000);

    await tester.tap(find.text('Recordar').first);
    await settle(tester);
    final MethodCall shared = calls.lastWhere(
      (MethodCall c) => c.method == 'text',
    );
    expect(
      shared.arguments,
      'Hola, Ana. Te escribo por los ${pesos(40000)} de Cena del jueves. '
      'Cuando puedas me los pasas. ¡Gracias!',
    );

    await tester.tap(find.text('Registrar pago').first);
    await settle(tester);
    // Ana's 40.000 that came in matches by name and amount: it comes chosen.
    expect(find.text('Ana te envió · ${pesos(40000)} · 3 oct'), findsOneWidget);
    await tapText(tester, 'Guardar');
    expect(own.group('g')!.balances, <String, int>{
      meId: 40000,
      'ana': 0,
      'juan': -40000,
    });
    // Ana's money came back: no income was made up.
    expect(own.ledger!.incomeIn(2026, 10), 0);
    expect(find.text('Ana te paga ${pesos(40000)}'), findsNothing);
    expect(find.text('Ana te pagó'), findsOneWidget);
  });

  testWidgets('a client\'s payment counts ahead as chosen, late ones show, '
      'and the reserve leaves the free money', (tester) async {
    final List<MethodCall> calls = <MethodCall>[];
    final OwnController own = await openPage(
      tester,
      (OwnController own) => FreelancePage(own: own),
      calls: calls,
      data: (QuincenaStore store, Account bank, _) async {
        await store.addEntry(
          accountId: bank.id,
          amount: d('1000000'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 3, 9),
          category: 'freelance',
          payee: 'Estudio Sur',
        );
        await store.setSetting(
          'freelance',
          jsonEncode(
            FreelancePlan(
              incomes: <ExpectedIncome>[
                ExpectedIncome(
                  id: 'late',
                  client: 'Agencia Uno',
                  amount: 700000,
                  expected: DateTime(2026, 9, 28),
                ),
              ],
            ).toJson(),
          ),
        );
      },
    );
    expect(find.text('VENCIDOS'), findsOneWidget);
    expect(
      find.text('Vencido hace 5 días: era el 28 de septiembre'),
      findsOneWidget,
    );
    // Late: tomorrow at the soonest.
    expect(own.ledger!.expected.single.date, DateTime(2026, 10, 4));

    await tapText(tester, 'Agregar cobro');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Quién te paga?'),
      'Estudio Norte',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor'),
      '1.500.000',
    );
    await tapText(tester, 'Guardar');
    final ExpectedIncome norte = own.freelance.incomes.firstWhere(
      (ExpectedIncome i) => i.client == 'Estudio Norte',
    );
    expect(norte.status, IncomeStatus.pending);
    expect(norte.expected, DateTime(2026, 10, 18));
    expect(own.ledger!.expected, hasLength(2));

    final int free = own.ledger!.freeUntilPayday;
    await tapText(tester, 'Nada');
    await tapText(tester, '15\u00a0%');
    expect(own.freelance.reservePercent, 15);
    expect(own.ledger!.reserved, 150000);
    expect(own.ledger!.freeUntilPayday, free - 150000);
    expect(
      find.textContaining('Tienes apartados ${pesos(150000)}'),
      findsOneWidget,
    );

    await tapText(tester, 'Lo cobrado');
    expect(own.freelance.scenario, IncomeScenario.collected);
    expect(own.ledger!.expected, isEmpty);

    await tapText(tester, 'Agencia Uno');
    await tapText(tester, 'Recordar al cliente');
    expect(
      calls.lastWhere((MethodCall c) => c.method == 'text').arguments,
      contains('Hola, Agencia Uno. Te escribo por el pago de ${pesos(700000)}'),
    );
  });

  testWidgets('what was used from the reserve leaves it, and the dialog '
      'closes cleanly', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => FreelancePage(own: own),
      data: (QuincenaStore store, Account bank, _) async {
        await store.addEntry(
          accountId: bank.id,
          amount: d('1000000'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 2, 9),
          category: 'freelance',
          payee: 'Estudio Sur',
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
    expect(own.ledger!.reserved, 150000);
    final int free = own.ledger!.freeUntilPayday;

    // Cancelled, nothing is used.
    await tapText(tester, 'Usé de la reserva');
    await tapText(tester, 'Cancelar');
    expect(tester.takeException(), isNull);
    expect(own.freelance.used, isEmpty);

    await tapText(tester, 'Usé de la reserva');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto usaste?'),
      '50.000',
    );
    // The keyboard is up while typing, and goes down as the dialog closes:
    // the closing dialog is laid out again, its field still there.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    tester.view.resetViewInsets();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(own.ledger!.reserved, 100000);
    expect(own.ledger!.freeUntilPayday, free + 50000);
  });

  testWidgets('a client\'s payment into an account not for everyday use '
      'is kept apart from nothing', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => FreelancePage(own: own),
      data: (QuincenaStore store, Account bank, _) async {
        await store.saveRates(<Rate>[
          Rate(
            asset: 'USD',
            quote: 'COP',
            value: d('4000'),
            asOf: DateTime(2026, 10, 3),
            source: 'trm',
          ),
        ]);
        final Account dollars = await store.addAccount(
          name: 'Cuenta en dólares',
          kind: AccountKind.bank,
          asset: Asset.usd,
          opening: d('0'),
          spendable: false,
        );
        await store.addEntry(
          accountId: bank.id,
          amount: d('1000000'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 2, 9),
          category: 'freelance',
          payee: 'Estudio Sur',
        );
        // 500 dollars filed as freelance work, and 250 a client paid,
        // linked to it: 3.000.000 pesos that never were money to spend.
        await store.addEntry(
          accountId: dollars.id,
          amount: d('500'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 2, 10),
          category: 'freelance',
          payee: 'Upwork',
        );
        final Entry linked = await store.addEntry(
          accountId: dollars.id,
          amount: d('250'),
          kind: EntryKind.income,
          date: DateTime(2026, 10, 2, 11),
          category: 'other_income',
          payee: 'Acme',
        );
        await store.setSetting(
          'freelance',
          jsonEncode(
            FreelancePlan(
              incomes: <ExpectedIncome>[
                ExpectedIncome(
                  id: 'acme',
                  client: 'Acme',
                  amount: 1000000,
                  expected: DateTime(2026, 10, 2),
                  status: IncomeStatus.collected,
                  collectedOn: DateTime(2026, 10, 2),
                  entryId: linked.id,
                ),
              ],
              reservePercent: 15,
              reserveSince: DateTime(2026, 10, 1),
            ).toJson(),
          ),
        );
      },
    );
    // Only the 1.000.000 that came into Bancolombia feeds the reserve.
    expect(own.ledger!.reserved, 150000);
    expect(own.ledger!.freeUntilPayday, 3000000 - 150000);
    expect(
      find.text(
        'Lo que cobraste en cuentas que no son de uso diario '
        '(${pesos(3000000)}) no se aparta: nunca contó en lo que puedes '
        'gastar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a trip counts an expense abroad, estimated and then set to '
      'the bank\'s charge', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => TripsPage(own: own),
    );
    await tapText(tester, 'Nuevo viaje');
    await tester.enterText(
      find.widgetWithText(TextField, '¿A dónde vas?'),
      'Nueva York',
    );
    // The budget's field also says COP: open the currency by its field.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tapText(tester, 'USD');
    await tester.enterText(
      find.widgetWithText(TextField, 'Presupuesto'),
      '1.000',
    );
    await tapText(tester, 'Guardar');
    final Trip trip = own.trips.single;
    expect(trip.currency, 'USD');
    expect(trip.budget, d('1000'));

    await tapText(tester, 'Nueva York');
    await tapText(tester, 'Agregar gasto del viaje');
    await tester.enterText(find.widgetWithText(TextField, '¿En qué?'), 'Cena');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '50');
    await tester.enterText(
      find.widgetWithText(TextField, '1 USD en COP'),
      '4.150,30',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Comisión'), '3');
    await settle(tester);
    expect(
      find.text(
        'Se registran ${pesos(213740)} en Visa, estimado hasta que llegue el '
        'cargo real.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Guardar');
    final Entry entry = own.snapshot!.entries.firstWhere(
      (Entry e) => e.payee == 'Cena',
    );
    expect(entry.amount, d('-213740'));
    expect(own.trip(trip.id)!.foreign[entry.id]!.rateSource, 'manual');
    expect(own.tripSummary(own.trip(trip.id)!).left, d('950'));

    await tapText(tester, 'Ajustar al cargo real');
    await tester.enterText(find.byType(TextField).last, '214.900');
    await tapText(tester, 'Guardar');
    expect(
      own.snapshot!.entries.firstWhere((Entry e) => e.id == entry.id).amount,
      d('-214900'),
    );
    expect(
      find.text(
        'El banco cobró ${pesos(214900)}: ${pesos(1160)} más que el estimado',
      ),
      findsOneWidget,
    );
    // Still one movement, now with the real charge: never a copy.
    expect(
      own.snapshot!.entries.where((Entry e) => e.payee == 'Cena'),
      hasLength(1),
    );
  });

  testWidgets('the Plan tab offers each module without needing any', (
    tester,
  ) async {
    await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: SingleChildScrollView(child: PlanTab(own: own)),
      ),
    );
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    // Variable income and trips in the budget, ahead of the goals; what is
    // shared with the payments.
    expect(
      top('Cobros pendientes, estimados y una reserva'),
      lessThan(top('METAS')),
    );
    expect(
      top('Un presupuesto en la moneda del viaje'),
      lessThan(top('METAS')),
    );
    expect(
      top('Divide una cuenta y lleva lo que te deben'),
      greaterThan(top('PAGOS')),
    );
  });
}
