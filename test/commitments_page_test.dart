import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/icons.dart';
import 'package:quincena/ui/own/commitments_page.dart';
import 'package:quincena/ui/own/detective_page.dart';
import 'package:quincena/ui/own/instalments_page.dart';
import 'package:quincena/ui/own/plan_tab.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  group('fixed payments', () {
    testWidgets('one is added with a reminder, follows its last charge, '
        'pauses and goes', (tester) async {
      final List<MethodCall> calls = <MethodCall>[];
      final OwnController own = await openPage(
        tester,
        (OwnController own) => CommitmentsPage(own: own),
        calls: calls,
      );
      expect(find.textContaining('Aún no tienes pagos fijos'), findsOneWidget);

      await tapText(tester, 'Agregar pago fijo');
      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué es?'),
        'Netflix',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '¿Cuánto cobra?'),
        '26.900',
      );
      await settle(tester);
      // Its name says it is a subscription: what it costs in a year.
      expect(find.text('Al año son ${pesos(322800)}.'), findsOneWidget);
      await tapText(tester, 'No avisarme');
      await tapText(tester, '3 días antes');
      await tapText(tester, 'Guardar');

      final RecurringCharge netflix = (await tester.runAsync(
        own.store.recurring,
      ))!.single;
      expect(netflix.category, 'subscriptions');
      expect(netflix.amount, Money(d('26900'), Asset.cop));
      expect(own.memoryOf(netflix.id).remindDays, 3);
      expect(calls.map((MethodCall c) => c.method), contains('ask'));
      final List<Object?> items =
          (calls.lastWhere((MethodCall c) => c.method == 'schedule').arguments
                  as Map<Object?, Object?>)['items']!
              as List<Object?>;
      final Map<Object?, Object?> first = items.first! as Map<Object?, Object?>;
      expect(first['title'], 'Netflix se renueva el 3 de noviembre');
      expect(first['at'], DateTime(2026, 10, 31, 9).millisecondsSinceEpoch);
      expect(find.text('Netflix'), findsOneWidget);

      // The charge came in higher: the amount follows it when asked.
      await tester.runAsync(
        () => own.store.addEntry(
          accountId: own.accounts.first.id,
          amount: d('33900'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2),
          category: 'subscriptions',
          payee: 'NETFLIX.COM',
        ),
      );
      await settle(tester);
      await tapText(
        tester,
        'Actualizar a ${pesos(33900)}, como el último cobro',
      );
      expect(
        (await tester.runAsync(own.store.recurring))!.single.amount,
        Money(d('33900'), Asset.cop),
      );

      expect(find.byIcon(Glyph.bell), findsOneWidget);
      await tapText(tester, 'Netflix');
      await tapText(tester, 'Pausar');
      expect(find.text('EN PAUSA'), findsOneWidget);
      expect(own.ledger!.upcoming, isEmpty);
      // Paused, nothing reminds: no bell.
      expect(find.byIcon(Glyph.bell), findsNothing);

      // Deleting it asks nothing: it says what changed, with a way back
      // that brings it back with what the person told about it.
      await tapText(tester, 'Netflix');
      await tapText(tester, 'Borrar pago fijo');
      expect(await tester.runAsync(own.store.recurring), isEmpty);
      expect(
        find.text('Se borró Netflix: deja de contarse como comprometido.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Deshacer'));
      await settle(tester);
      final RecurringCharge back = (await tester.runAsync(
        own.store.recurring,
      ))!.single;
      expect(back.id, netflix.id);
      expect(back.active, isFalse);
      expect(own.memoryOf(netflix.id).remindDays, 3);

      await tapText(tester, 'Netflix');
      await tapText(tester, 'Borrar pago fijo');
      expect(await tester.runAsync(own.store.recurring), isEmpty);
      expect(own.memoryOf(netflix.id).remindDays, isNull);
      // Nothing left to remind: what was set is taken back.
      expect(calls.last.method, 'cancel');
    });

    testWidgets('a charge is paid from an account, never from crypto', (
      tester,
    ) async {
      await openPage(
        tester,
        (OwnController own) => CommitmentsPage(own: own),
        data: (QuincenaStore store, Account bank, Account card) =>
            store.addAccount(
              name: 'Binance',
              kind: AccountKind.exchange,
              asset: Asset.usdt,
              opening: d('120'),
              spendable: false,
            ),
      );
      await tapText(tester, 'Agregar pago fijo');
      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await settle(tester);
      expect(find.text('Visa').hitTestable(), findsWidgets);
      expect(find.text('Binance'), findsNothing);
    });

    testWidgets('a free trial moves the first charge to its end, and one '
        'that ended still opens its calendar', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => CommitmentsPage(own: own),
        data: (QuincenaStore store, Account bank, Account card) =>
            store.addRecurring(
              name: 'Max',
              amount: Money(d('19900'), Asset.cop),
              cadence: Cadence.monthly,
              nextDate: DateTime(2026, 11, 3),
              accountId: card.id,
              category: 'subscriptions',
            ),
      );
      final RecurringCharge max = own.recurring.single;
      await tester.runAsync(
        () => own.saveMemory(
          max.id,
          ChargeMemory(trialEnds: DateTime(2026, 9, 28)),
        ),
      );
      await settle(tester);
      await tapText(tester, 'Max');
      await tapText(tester, 'Prueba gratis hasta el 28 de septiembre');
      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await settle(tester);
      await tester.tap(find.text('17').last);
      await tester.tap(find.text('ACEPTAR'));
      await settle(tester);
      // It starts charging the day the trial ends.
      expect(find.text('Próximo cobro: 17 de octubre'), findsOneWidget);
      await tapText(tester, 'Guardar');
      expect(own.recurring.single.nextDate, DateTime(2026, 10, 17));
      expect(own.memoryOf(max.id).trialEnds, DateTime(2026, 10, 17));
    });

    testWidgets('one not in use says what pausing saves, and that the app '
        'cancels nothing', (tester) async {
      await openPage(tester, (OwnController own) => CommitmentsPage(own: own));
      await tapText(tester, 'Agregar pago fijo');
      // A new one is no subscription until said: no question about use.
      expect(find.text('Ya no la uso'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, '¿Cuánto cobra?'),
        '26.900',
      );
      await tapText(tester, 'Suscripciones');
      await tapText(tester, 'Ya no la uso');
      expect(
        find.textContaining(
          'Si la pausas, te ahorras ${pesos(322800)} al año. '
          'Quincena no la cancela',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Un cobro que se repite no dice si la usas: eso solo lo sabes tú.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new one takes its category from its name, and asks for '
        'one when the name says nothing', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => CommitmentsPage(own: own),
      );
      bool picked(String chip) => tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, chip))
          .selected;
      await tapText(tester, 'Agregar pago fijo');
      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué es?'),
        'Crédito del carro',
      );
      await settle(tester);
      expect(picked('Créditos'), isTrue);
      expect(find.text('¿Está en prueba gratis?'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué es?'),
        'Clases de inglés',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '¿Cuánto cobra?'),
        '180.000',
      );
      await settle(tester);
      expect(picked('Créditos'), isFalse);
      await tapText(tester, 'Guardar');
      expect(find.text('Elige la categoría del pago fijo.'), findsOneWidget);
      expect(await tester.runAsync(own.store.recurring), isEmpty);

      await tapText(tester, 'Otros');
      expect(find.text('Elige la categoría del pago fijo.'), findsNothing);
      await tapText(tester, 'Guardar');
      expect(
        (await tester.runAsync(own.store.recurring))!.single.category,
        'other',
      );
    });

    testWidgets('a charge that repeats each month is offered, never added '
        'alone', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => CommitmentsPage(own: own),
        data: (QuincenaStore store, Account bank, _) async {
          for (final int m in <int>[7, 8, 9]) {
            for (final String payee in <String>['Spotify', 'Smart Fit']) {
              await store.addEntry(
                accountId: bank.id,
                amount: d(payee == 'Spotify' ? '16900' : '89900'),
                kind: EntryKind.expense,
                date: DateTime(2026, m, 5),
                category: 'subscriptions',
                payee: payee,
              );
            }
          }
        },
      );
      expect(find.text('PARECEN PAGOS FIJOS'), findsOneWidget);
      expect(
        find.text(
          '3 cobros parecidos, el último de ${pesos(16900)}: '
          '5 jul, 5 ago, 5 sept',
        ),
        findsOneWidget,
      );
      expect(await tester.runAsync(own.store.recurring), isEmpty);

      // The larger one comes first.
      await tester.tap(find.text('No es fijo').first);
      await settle(tester);
      expect(find.text('Smart Fit'), findsNothing);
      expect(own.detective.notRecurring, <String>{'smart fit'});

      await tapText(tester, 'Agregar como pago fijo');
      expect(find.widgetWithText(TextField, 'Spotify'), findsOneWidget);
      await tapText(tester, 'Guardar');
      final RecurringCharge spotify = (await tester.runAsync(
        own.store.recurring,
      ))!.single;
      expect(spotify.name, 'Spotify');
      expect(spotify.nextDate, DateTime(2026, 10, 5));
      expect(find.text('PARECEN PAGOS FIJOS'), findsNothing);
    });
  });

  group('rent seen once', () {
    Future<OwnController> open(WidgetTester tester) => openPage(
      tester,
      (OwnController own) => CommitmentsPage(own: own),
      data: (QuincenaStore store, Account bank, _) async {
        await store.addEntry(
          accountId: bank.id,
          amount: d('1200000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 9, 16),
          category: 'housing',
          payee: 'Arriendo septiembre',
        );
      },
    );

    testWidgets('is offered as a fixed payment, by its name', (tester) async {
      await open(tester);
      expect(find.text('PARECEN PAGOS FIJOS'), findsOneWidget);
      expect(find.text('Arriendo'), findsOneWidget);
      expect(
        find.text(
          'Un pago de ${pesos(1200000)} el 16 de septiembre: suele '
          'repetirse cada mes.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('is asked about before saying there are none', (tester) async {
      final OwnController own = await open(tester);
      expect(own.provisional, isTrue);
      await tapText(tester, 'No tengo pagos fijos');
      expect(find.text('¿Y Arriendo?'), findsOneWidget);
      // «Agregarlo» opens it to add, already filled.
      await tapText(tester, 'Agregarlo');
      expect(find.widgetWithText(TextField, 'Arriendo'), findsOneWidget);
      Navigator.of(tester.element(find.text('Guardar'))).pop();
      await settle(tester);
      expect(own.provisional, isTrue);

      // Said again, and that it is not fixed: it goes, and so does the
      // provisional figure.
      await tapText(tester, 'No tengo pagos fijos');
      await tapText(tester, 'No es fijo');
      expect(own.provisional, isFalse);
      expect(own.detective.notRecurring, contains('arriendo'));
      expect(find.text('PARECEN PAGOS FIJOS'), findsNothing);
    });
  });

  group('instalments', () {
    Future<void> fill(
      WidgetTester tester, {
      required String name,
      String? rate,
      String? fee,
      String? cash,
      String? account,
    }) async {
      await tapText(tester, 'Agregar compra a cuotas');
      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué compraste?'),
        name,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Valor financiado'),
        '2.400.000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Número de cuotas'),
        '12',
      );
      if (rate != null) {
        await tester.enterText(
          find.widgetWithText(TextField, 'Tasa de interés'),
          rate,
        );
      }
      if (fee != null) {
        await tester.enterText(
          find.widgetWithText(TextField, 'Cuota de manejo o seguro, por cuota'),
          fee,
        );
      }
      if (cash != null) {
        await tester.enterText(
          find.widgetWithText(TextField, 'Precio de contado'),
          cash,
        );
      }
      if (account != null) {
        await tapText(tester, 'Fuera de Quincena: tienda o crédito');
        await tapText(tester, account);
      }
      await tapText(tester, 'Guardar');
    }

    testWidgets('with every figure the total is known, compared with paying '
        'at once, and the coming ones are committed', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => InstalmentsPage(own: own),
      );
      final int free = own.ledger!.freeUntilPayday;
      await fill(
        tester,
        name: 'Televisor',
        rate: '26,82',
        fee: '0',
        cash: '2.400.000',
      );
      final Instalments tv = own.instalments.single;
      expect(tv.firstDue, DateTime(2026, 11, 3));
      expect(tv.totalKnown, isTrue);
      expect(find.text('Televisor'), findsOneWidget);
      expect(find.text('Con los datos que diste.'), findsOneWidget);
      // The first one falls after this payday: free money stays.
      expect(own.ledger!.freeUntilPayday, free);
      expect(
        own.ledger!.upcoming.map((m) => m.id),
        contains('instalment:${tv.id}#1'),
      );

      await tapText(tester, 'Televisor');
      expect(
        find.text(
          'En total pagarás ${pesos(tv.total!)}, con los datos que diste.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'De contado costaba ${pesos(2400000)}: a cuotas pagas '
          '${pesos(tv.total! - 2400000)} más.',
        ),
        findsOneWidget,
      );
      expect(find.text('Llevas 0 de 12 cuotas'), findsOneWidget);

      // Part of the first one.
      await tapText(tester, 'Registrar un pago');
      await tester.enterText(
        find.widgetWithText(TextField, 'Valor pagado'),
        '100.000',
      );
      await tapText(tester, 'Guardar');
      expect(own.instalments.single.paid, 100000);
      expect(
        find.text(
          'A la cuota 1 le faltan ${pesos(tv.schedule.first.payment - 100000)}.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('without the fee it is only an estimate, and a card in the '
        'app keeps it from counting twice', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => InstalmentsPage(own: own),
      );
      await fill(
        tester,
        name: 'Nevera',
        rate: '1,8',
        cash: '2.200.000',
        account: 'Visa',
      );
      // Not on the card yet: nothing would count it, so it is offered.
      expect(find.text('¿La compra ya está en Visa?'), findsOneWidget);
      expect(
        find.textContaining(
          'No encontramos una compra de ${pesos(2400000)} en Visa.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Anotarla');
      expect(find.widgetWithText(TextField, '2.400.000'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Nevera'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await settle(tester);
      final Entry bought = own.snapshot!.entries.singleWhere(
        (Entry e) => e.payee == 'Nevera',
      );
      expect(bought.kind, EntryKind.expense);
      expect(bought.amount.abs(), Decimal.parse('2400000'));
      expect(own.snapshot!.account(bought.accountId)!.name, 'Visa');
      final Instalments fridge = own.instalments.single;
      expect(fridge.totalKnown, isFalse);
      expect(find.text('estimado'), findsOneWidget);
      expect(
        own.ledger!.upcoming.where((m) => m.merchant == 'Nevera'),
        isEmpty,
      );

      await tapText(tester, 'Nevera');
      expect(
        find.textContaining('es un estimado, porque falta la cuota de manejo'),
        findsOneWidget,
      );
      expect(find.textContaining('a cuotas pagas al menos'), findsOneWidget);
      final Finder once = find.text(
        'La compra ya está en esa cuenta: sus cuotas no se suman otra vez '
        'a lo comprometido.',
      );
      await reveal(tester, once);
      expect(once, findsOneWidget);

      await tester.tap(find.byTooltip('Borrar compra'));
      await settle(tester);
      await tapText(tester, 'Borrar compra');
      expect(own.instalments, isEmpty);
    });

    testWidgets('a purchase already on the card is not asked for', (
      tester,
    ) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => InstalmentsPage(own: own),
        data: (QuincenaStore store, Account bank, Account card) =>
            store.addEntry(
              accountId: card.id,
              amount: Decimal.parse('2400000'),
              kind: EntryKind.expense,
              date: DateTime(2026, 10, 1, 18),
              category: 'shopping',
              payee: 'Alkosto',
            ),
      );
      await fill(tester, name: 'Nevera', rate: '1,8', account: 'Visa');
      expect(own.instalments, hasLength(1));
      expect(find.text('¿La compra ya está en Visa?'), findsNothing);
    });

    testWidgets('without rate or instalment there is no total to invent', (
      tester,
    ) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => InstalmentsPage(own: own),
      );
      await fill(tester, name: 'Moto');
      expect(own.instalments.single.total, isNull);
      expect(find.text('Falta la tasa o el valor de la cuota'), findsOneWidget);
      await tapText(tester, 'Moto');
      expect(find.text('Sin datos'), findsOneWidget);
      expect(
        find.text(
          'Sin la tasa ni el valor de la cuota no se puede calcular el total.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the charge detective', () {
    Future<void> twice(QuincenaStore store, Account bank, Account card) async {
      await store.addEntry(
        accountId: bank.id,
        amount: d('63200'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 9),
        category: 'groceries',
        payee: 'Éxito',
        source: 'notification',
      );
      await store.addEntry(
        accountId: bank.id,
        amount: d('63200'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 18),
        category: 'groceries',
        payee: 'EXITO',
        source: 'statement',
      );
    }

    testWidgets('a payment seen twice loses its copy with «Borrar el '
        'repetido», and «Deshacer» brings it back', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => DetectivePage(own: own),
        data: twice,
      );
      final int entries = own.snapshot!.entries.length;
      await tapText(tester, 'Borrar el repetido');
      expect(own.snapshot!.entries, hasLength(entries - 1));
      // The one that came later, from the statement, is the copy.
      expect(
        own.snapshot!.entries.where((Entry e) => e.source == 'statement'),
        isEmpty,
      );
      expect(
        find.text('Puede ser el mismo pago visto dos veces'),
        findsNothing,
      );
      expect(find.text('Se borró el repetido de EXITO.'), findsOneWidget);

      await tapText(tester, 'Deshacer');
      expect(own.snapshot!.entries, hasLength(entries));
      expect(
        find.text('Puede ser el mismo pago visto dos veces'),
        findsOneWidget,
      );
    });

    testWidgets('a payment seen twice is shown with its evidence, put away '
        'and back, and nothing is deleted', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => DetectivePage(own: own),
        data: twice,
      );
      final int entries = own.snapshot!.entries.length;
      expect(
        find.text('Puede ser el mismo pago visto dos veces'),
        findsOneWidget,
      );
      expect(
        find.textContaining('por caminos distintos: Notificación y Extracto'),
        findsOneWidget,
      );
      expect(find.textContaining('Bancolombia · Extracto'), findsOneWidget);
      expect(find.textContaining('fraude'), findsOneWidget);

      await tapText(tester, 'Es esperado');
      expect(find.text('Nada para revisar por ahora.'), findsOneWidget);
      expect(own.snapshot!.entries, hasLength(entries));

      await tapText(tester, 'Ver la que marcaste');
      await tapText(tester, 'Volver a mostrar');
      expect(own.detective.answers, isEmpty);

      await tapText(tester, 'Lo voy a revisar');
      // Back at the top, where the sections start.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await settle(tester);
      expect(find.text('LO VAS A REVISAR'), findsOneWidget);
      expect(find.text('PARA REVISAR'), findsNothing);
      expect(own.detective.answers.values.single, AlertAnswer.review);
    });

    testWidgets('a kind of alert can be silenced, and comes back', (
      tester,
    ) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => DetectivePage(own: own),
        data: twice,
      );
      await tapText(tester, 'Pagos repetidos');
      expect(own.detective.muted, <AlertKind>{AlertKind.twice});
      expect(own.alerts, isEmpty);
      expect(find.text('Nada para revisar por ahora.'), findsOneWidget);
      await tapText(tester, 'Pagos repetidos');
      expect(own.alerts, hasLength(1));
    });
  });

  testWidgets('the Plan tab sums up what is committed', (tester) async {
    await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: SingleChildScrollView(child: PlanTab(own: own)),
      ),
      data: (QuincenaStore store, Account bank, Account card) async {
        await store.addRecurring(
          name: 'Internet',
          amount: Money(d('100000'), Asset.cop),
          cadence: Cadence.monthly,
          nextDate: DateTime(2026, 10, 10),
          accountId: bank.id,
          category: 'utilities',
        );
      },
    );
    expect(find.text('LO QUE ESTOY PAGANDO'), findsOneWidget);
    expect(
      find.text('${pesos(100000)} en los próximos 30 días'),
      findsOneWidget,
    );
    expect(find.text('Ninguna registrada'), findsOneWidget);
    expect(find.text('Nada raro por ahora'), findsOneWidget);
  });
}
