// Flows of Plan (06).
import 'dart:convert';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/merchants.dart' show merchantKey;
import 'package:quincena/data/category.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/decisions.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/plan.dart';
import 'package:quincena/domain/projection.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/coming_chart.dart' show ComingChart;
import 'package:quincena/ui/own/cushion_page.dart' show reserveOf;
import 'package:quincena/ui/own/look.dart' show moneyText;

import '../../test/real_life_data.dart' show guatape, newYork;
import '../../test_screens/accounts.dart';
import '../tour.dart';
import 'flow.dart';

final List<AppFlow> planFlows = <AppFlow>[
  AppFlow(
    '06-01-ver-el-plan-por-primera-vez',
    'Ver el plan por primera vez',
    area: 'Plan',
    goal:
        'Quiero ver qué me ofrece Plan antes de llenar nada, y que cada '
        'parte me diga para qué sirve.',
    data: seeded,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      await _openPlan(f);
      await f.page(
        'Plan sin nada guardado: arriba «Reparte esta quincena» con lo que '
        'hay para repartir, y cada parte con una línea de para qué sirve.',
      );
      await f.check(
        'Lo que dice «Reparte esta quincena» es lo que hay para repartir: '
        '${_pesos(l, allocatable(l))}',
        () => expect(_says(f, _pesos(l, allocatable(l))), isTrue),
      );
      await f.check('No hay metas, deseos, viajes, cobros ni grupos', () {
        expect(own.snapshot!.goals, isEmpty);
        expect(own.wishes, isEmpty);
        expect(own.trips, isEmpty);
        expect(own.freelance.isEmpty, isTrue);
        expect(own.groups, isEmpty);
        expect(own.instalments, isEmpty);
      });
      await f.tap('Ingresos variables');
      await f.step(
        '«Ingresos variables» vacío: todo en $_zero, sin reserva, y «Lo '
        'facturado» elegido para los próximos días.',
      );
      await f.back();
      await f.tap('Viajes');
      await f.step(
        '«Viajes» vacío: «Aún no tienes viajes.» y el botón «Nuevo '
        'viaje».',
      );
      await f.back();
      await f.tap('Lo quiero, pero después');
      await f.step(
        '«Lo quiero, pero después» vacío: explica que nada se compra ni se '
        'sigue en una tienda, y ofrece «Agregar deseo».',
      );
      await f.back();
      await f.tap('Compras a cuotas');
      await f.step(
        '«Compras a cuotas» vacío, con la nota de que comprar con una '
        'tarjeta de Quincena no cuenta dos veces.',
      );
      await f.back();
      await f.tap('Gastos compartidos');
      await f.step(
        '«Gastos compartidos» vacío: «Le presté», «Me prestaron» y la pista '
        'de dividir un gasto desde Movimientos.',
      );
      await f.back();
      await f.tap('Cargos para revisar');
      await f.step(
        '«Cargos para revisar» sin nada raro, con los tres tipos de alerta '
        'encendidos y la regla de cada uno.',
      );
      await f.check('El detective no encontró nada en esta cuenta', () {
        expect(own.alerts, isEmpty);
      });
      await f.back();
      await f.tap('Pagos fijos');
      await f.step(
        '«Pagos fijos» con Netflix: arriba lo que se cobra en 30 días y lo '
        'que suman las suscripciones en un año.',
      );
      await f.check('Las suscripciones al año son Netflix por 12: '
          '${pesos(26900 * 12)}', () {
        expect(_says(f, pesos(26900 * 12)), isTrue);
      });
      await f.back();
    },
  ),
  AppFlow(
    '06-02-leer-el-plan-de-un-vistazo',
    'Leer el plan de un vistazo',
    area: 'Plan',
    goal:
        'Quiero ver en una sola pantalla lo que me deben, lo que debo, lo que '
        'viene y si algo raro pasó, sin abrir cada parte.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      await _openPlan(f);
      await f.page(
        'Plan con la cuenta llena: cada fila resume su parte en una línea, '
        'con la cifra que importa.',
      );
      await f.check(
        '«Reparte esta quincena» dice ${_pesos(l, allocatable(l))}, lo que '
        'hay para repartir',
        () => expect(_says(f, _pesos(l, allocatable(l))), isTrue),
      );
      await f.check('Ingresos variables avisa «Un cobro vencido»', () {
        final int late = own.freelance
            .by(IncomeStatus.pending)
            .where((ExpectedIncome i) => i.overdue(own.today))
            .length;
        expect(late, 1);
        expect(f.shows('Un cobro vencido'), isTrue);
      });
      final Trip ny = own.trip(newYork)!;
      final String tripLeft = moneyText(
        Money(own.tripSummary(ny).left!, ny.asset),
        base: own.profile?.base,
      );
      await f.check(
        'Viajes dice lo que le queda a Nueva York: $tripLeft',
        () => expect(_says(f, 'Nueva York: te quedan $tripLeft'), isTrue),
      );
      final GoalShare goal = own.goalShares.single;
      final DateTime arrives = arrival(goal, from: own.today)!;
      await f.check('La meta dice ${percent(27)}, lo ahorrado y que llega en '
          '${monthYear(arrives)}', () {
        expect(f.shows(percent(27)), isTrue);
        expect(
          _says(
            f,
            'Llevas ${pesos(650000)} de ${pesos(2400000)} · llega en '
            '${monthYear(arrives)}',
          ),
          isTrue,
        );
      });
      final int fixed = l.upcoming
          .where(
            (Movement m) =>
                !m.id.startsWith('instalment:') &&
                !m.date.isAfter(l.today.add(const Duration(days: 30))),
          )
          .fold(0, (int s, Movement m) => s + m.amount);
      await f.check(
        'Pagos fijos suma ${_pesos(l, fixed)} en los próximos 30 días',
        () => expect(
          _says(f, '${_pesos(l, fixed)} en los próximos 30 días'),
          isTrue,
        ),
      );
      final int owed = own.instalments.fold(
        0,
        (int s, Instalments p) => s + (p.remaining ?? 0),
      );
      await f.check(
        'Compras a cuotas dice «unos» ${_pesos(l, owed)}: el Celular no '
        'tiene todos los datos',
        () =>
            expect(_says(f, 'Te falta pagar unos ${_pesos(l, owed)}'), isTrue),
      );
      final (int owedToYou, int youOwe) = own.sharedBalance;
      await f.check(
        'Gastos compartidos: te deben ${_pesos(l, owedToYou)} y debes '
        '${_pesos(l, youOwe)}',
        () => expect(
          _says(
            f,
            'Te deben ${_pesos(l, owedToYou)} · debes ${_pesos(l, youOwe)}',
          ),
          isTrue,
        ),
      );
      await f.check(
        'Cargos para revisar cuenta las ${own.alerts.length} alertas abiertas',
        () =>
            expect(f.shows('${own.alerts.length} cargos para revisar'), isTrue),
      );
      await f.check(
        'Fondo de emergencia en días pide elegir dónde está el fondo',
        () =>
            expect(f.shows('Elige dónde está tu fondo de emergencia'), isTrue),
      );
      await f.tap('Compras a cuotas');
      await f.step(
        '«Compras a cuotas» repite la cifra de Plan y aclara que es un '
        'estimado porque falta algún dato del banco.',
      );
      await f.check(
        'La página dice lo mismo que la fila: ${_pesos(l, owed)}',
        () => expect(f.shows(_pesos(l, owed)), isTrue),
      );
      await f.back();
      await f.tap('Gastos compartidos');
      await f.step(
        '«Gastos compartidos»: «Te deben» y «Debes» son los mismos de la fila '
        'de Plan; abajo, cada grupo con lo suyo.',
      );
      await f.check(
        'La página dice que debes ${_pesos(l, youOwe)}, como la fila',
        () => expect(f.shows(_pesos(l, youOwe)), isTrue),
      );
      await f.back();
      await f.tap('Cargos para revisar');
      await f.page(
        '«Cargos para revisar» con las alertas que cuenta la fila, cada una '
        'con sus movimientos y qué hacer.',
        most: 4,
      );
      await f.check(
        'Hay tantas alertas como dice la fila: ${own.alerts.length}',
        () => expect(
          find.text('Es esperado').evaluate().length,
          own.alerts.length,
        ),
      );
      await f.back();
    },
  ),
  AppFlow(
    '06-03-repartir-la-quincena-en-sobres',
    'Repartir la quincena en sobres',
    area: 'Plan',
    goal:
        'Quiero decidir qué parte de la quincena es para el día a día, qué '
        'va a mi meta y qué aparto para un regalo.',
    data: _withGoal,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Ledger l = own.ledger!;
      final int money = allocatable(l);
      await f.step(
        'Inicio: lo que puedes gastar hasta el pago, antes de repartir '
        'nada.',
      );
      await _openPlan(f);
      await f.tap('Repartir en sobres');
      await f.page(
        '«Reparte tu quincena»: «Para repartir» con la suma que lo explica, '
        'la propuesta para el día a día y la meta y, abajo, «Sin asignar», '
        'lo que no queda en ningún sobre.',
      );
      final List<Envelope> proposal = proposeEnvelopes(
        l,
        goals: own.goalShares,
        dailyName: '',
      );
      final int proposed = proposal.fold(
        0,
        (int s, Envelope e) => s + e.amount,
      );
      await f.check(
        'Los campos traen la propuesta de la app, que no reparte más de lo '
        'que hay: «Sin asignar» ${_pesos(l, money - proposed)}',
        () {
          expect(proposed, lessThanOrEqualTo(money));
          expect(_fieldText(f, 'Día a día'), _typed(l, proposal.first.amount));
          expect(
            _fieldText(f, 'Viaje a Cartagena'),
            _typed(l, proposal[1].amount),
          );
          expect(
            _says(f, 'Sin asignar | ${_pesos(l, money - proposed)}'),
            isTrue,
          );
        },
      );
      await f.type('Día a día', '200000');
      await f.type('Viaje a Cartagena', '100000');
      await f.step(
        'Día a día en 200.000 y 100.000 para el viaje: «Sin asignar» baja a '
        '${_pesos(l, money - l.minor(300000))} mientras escribes.',
      );
      await f.check(
        '«Sin asignar» es lo que hay menos lo escrito: '
        '${_pesos(l, money - l.minor(300000))}',
        () => expect(
          _says(f, 'Sin asignar | ${_pesos(l, money - l.minor(300000))}'),
          isTrue,
        ),
      );
      await f.tap('Apartar para algo');
      await f.step('«Apartar para algo» pide un nombre para el sobre.');
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no aparece ningún sobre nuevo', () {
        expect(find.byTooltip('Quitar sobre'), findsNothing);
      });
      await f.tap('Apartar para algo');
      await f.tap('Guardar');
      await f.check('Sin nombre, «Guardar» tampoco crea un sobre', () {
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byTooltip('Quitar sobre'), findsNothing);
      });
      await f.tap('Apartar para algo');
      await _typeInDialog(f, 'Regalo de mamá');
      await f.tap('Guardar');
      await f.tap('Apartar para algo');
      await _typeInDialog(f, 'Taxi');
      await f.tap('Guardar');
      await f.type('Regalo de mamá', '40000');
      await f.step(
        'Dos sobres nuevos, «Regalo de mamá» con 40.000 y «Taxi» vacío, cada '
        'uno con su caneca para quitarlo.',
      );
      await f.tapTip('Quitar sobre');
      final int left = money - 340000;
      await f.step(
        'Sin el de Taxi. «Sin asignar» queda en ${_pesos(l, left)}: lo que '
        'hay menos lo repartido.',
      );
      await f.check('«Sin asignar» muestra ${_pesos(l, left)}', () {
        expect(_says(f, _pesos(l, left)), isTrue);
      });
      await f.tap('Guardar el reparto');
      await f.top();
      final int spent = spentThisPeriod(own.ledger!);
      await f.step(
        'De vuelta en Plan, recién repartido, la tarjeta dice «Llevas \$0 de '
        '\$200.000»: los ${_pesos(l, spent)} gastados desde el 30 de '
        'septiembre se fueron antes de repartir, no del sobre.',
      );
      await f.check(
        'Recién repartido, el día a día no dice que ya te pasaste (no cuenta '
        'los ${_pesos(l, spent)} gastados antes de repartir)',
        () {
          expect(f.shows('Te pasaste por'), isFalse);
          expect(dailySpent(own.ledger!, own.plan!), 0);
          expect(
            f.shows('Llevas ${_pesos(l, 0)} de ${_pesos(l, l.minor(200000))}'),
            isTrue,
          );
        },
      );
      await f.check('«Sin asignar» sigue en ${_pesos(l, left)} al guardar', () {
        expect(_says(f, 'Sin asignar | ${_pesos(l, left)}'), isTrue);
      });
      await f.check('Quedan guardados tres sobres de este periodo', () {
        final EnvelopePlan plan = own.plan!;
        expect(plan.envelopes.map((Envelope e) => e.amount), <int>[
          l.minor(200000),
          l.minor(100000),
          l.minor(40000),
        ]);
        expect(plan.envelopes.last.name, 'Regalo de mamá');
      });
      await f.check('Lo apartado son 140.000: la meta y el regalo', () {
        expect(own.plan!.setAside, l.minor(140000));
      });
      final String before = _pesos(l, free);
      final String after = _pesos(l, free - l.minor(140000));
      await f.check('Lo que puedes gastar pasó de $before a $after', () {
        expect(own.ledger!.freeUntilPayday, free - l.minor(140000));
      });
      await f.tap('Inicio');
      await f.step(
        'En Inicio, «Puedes gastar» bajó en los 140.000 apartados; el día a '
        'día no baja nada, porque es para gastar.',
      );
      // A lunch out of the day to day, after the split.
      await f.tapTip('Agregar movimiento');
      await f.type('Monto', '50000');
      await f.tap('Restaurantes');
      await f.type('¿Dónde o a quién?', 'Almuerzo');
      await f.tap('Guardar');
      await _openPlan(f);
      await f.top();
      await f.step(
        'Tras un almuerzo de 50.000 la tarjeta dice «Llevas \$50.000 de '
        '\$200.000» y «Sin asignar» sigue en ${_pesos(l, left)}: el gasto '
        'sale del día a día una sola vez.',
      );
      await f.check(
        'El almuerzo cuenta en el día a día: lleva 50.000 de 200.000',
        () {
          expect(dailySpent(own.ledger!, own.plan!), l.minor(50000));
          expect(
            f.shows(
              'Llevas ${_pesos(l, l.minor(50000))} de '
              '${_pesos(l, l.minor(200000))}',
            ),
            isTrue,
          );
        },
      );
      await f.check(
        'Un gasto del día a día no baja «Sin asignar», que sigue en '
        '${_pesos(l, left)}',
        () => expect(_says(f, 'Sin asignar | ${_pesos(l, left)}'), isTrue),
      );
      await f.check(
        '«Puedes gastar» es lo que no tiene sobre más lo que le queda al día '
        'a día: ${_pesos(l, left)} y ${_pesos(l, l.minor(150000))}',
        () => expect(own.ledger!.freeUntilPayday, left + l.minor(150000)),
      );
    },
  ),
  AppFlow(
    '06-04-repartir-mas-de-lo-que-hay',
    'Repartir más de lo que hay',
    area: 'Plan',
    goal:
        'Quiero ponerle al día a día más de lo que tengo y que la app me '
        'avise antes de guardar.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int money = allocatable(l);
      await _openPlan(f);
      await f.step(
        'Esta cuenta tiene poco para repartir: «Reparte esta quincena» dice '
        'que hay ${_pesos(l, money)}.',
      );
      // The split the page proposes, as it proposes it.
      final List<Envelope> proposal = proposeEnvelopes(
        l,
        goals: own.goalShares,
        last: own.lastPlan,
        dailyName: '',
      );
      final int daily = proposal
          .firstWhere((Envelope e) => e.kind == EnvelopeKind.daily)
          .amount;
      final int toGoal = proposal
          .firstWhere((Envelope e) => e.kind == EnvelopeKind.goal)
          .amount;
      await f.tap('Repartir en sobres');
      await f.step(
        'La suma de arriba dice de dónde salen los ${_pesos(l, money)}: lo de '
        'tus cuentas, menos la tarjeta, los pagos y la reserva. La propuesta '
        'no pasa de eso y pone primero el día a día, porque faltan 12 días '
        'para el pago; arriba avisa que la meta recibe menos y puede esperar.',
      );
      final int debt = own.spendableCardDebt;
      await f.check(
        '«Para repartir» se explica con una suma que da '
        '${_pesos(l, money)}, la reserva de ${_pesos(l, l.reserved)} incluida',
        () {
          expect(
            l.balance + debt - debt - l.committedUntilPayday - l.reserved,
            money,
          );
          expect(l.cushion, 0);
          for (final String line in <String>[
            'En tus cuentas de uso diario | ${_pesos(l, l.balance + debt)}',
            'Lo que debes en tarjetas | ${_pesos(l, -debt)}',
            'Pagos hasta el ${dayShortMonth(l.nextPayday)} | '
                '${_pesos(l, -l.committedUntilPayday)}',
            'Reserva de ingresos variables | ${_pesos(l, -l.reserved)}',
          ]) {
            expect(_says(f, line), isTrue, reason: line);
          }
          // No cushion: no line for it.
          expect(f.shows('Colchón'), isFalse);
        },
      );
      await f.check(
        'La propuesta no deja «Te pasas por»: el día a día va primero con '
        '${_pesos(l, daily)} y la meta recibe ${_pesos(l, toGoal)}',
        () {
          expect(f.shows('Te pasas por'), isFalse);
          expect(daily, greaterThan(0));
          expect(daily + toGoal, lessThanOrEqualTo(money));
          expect(_fieldText(f, 'Día a día'), _typed(l, daily));
          expect(
            _fieldText(f, 'Viaje a Cartagena'),
            toGoal == 0 ? isEmpty : _typed(l, toGoal),
          );
        },
      );
      await f.check('Arriba dice qué recibe menos de lo que pide', () {
        expect(
          f.screenText,
          contains(
            'Esta quincena no alcanza para todo: el día a día va '
            'primero.',
          ),
        );
        expect(f.screenText, contains('Viaje a Cartagena recibe'));
      });
      await f.type('Día a día', '300000');
      final int goals = proposal
          .where((Envelope e) => e.kind != EnvelopeKind.daily)
          .fold(0, (int s, Envelope e) => s + e.amount);
      final int over = l.minor(300000) + goals - money;
      await f.step(
        'Con 300.000 en el día a día el recuadro de abajo cambia a «Te '
        'pasas por» en color de alerta.',
      );
      await f.check('«Te pasas por» aparece en lugar de «Sin asignar»', () {
        expect(f.shows('Te pasas por'), isTrue);
        expect(f.shows('Sin asignar'), isFalse);
      });
      await f.tap('Guardar el reparto');
      await f.step(
        '«Asignas más de lo que hay» explica por cuánto te pasas y ofrece '
        '«Ajustar» o «Guardar así».',
      );
      await f.check('El aviso dice que te pasas por ${_pesos(l, over)}', () {
        expect(_says(f, _pesos(l, over)), isTrue);
      });
      await f.tap('Ajustar');
      await f.check('Con «Ajustar» no se guarda nada', () {
        expect(own.plan, isNull);
        expect(find.text('Reparte tu quincena'), findsOneWidget);
      });
      await f.tap('Guardar el reparto');
      await f.tap('Guardar así');
      await f.top();
      await f.step(
        'Con «Guardar así» vuelves a Plan: el reparto queda y la tarjeta '
        'dice por cuánto te pasas, sin signo menos.',
      );
      await f.check('«Te pasas por» dice ${_pesos(l, over)}, sin menos', () {
        expect(_says(f, 'Te pasas por'), isTrue);
        expect(_says(f, _pesos(l, -over)), isFalse);
        expect(_says(f, _pesos(l, over)), isTrue);
      });
      await f.check('El reparto quedó guardado con 300.000 de día a día', () {
        expect(own.plan!.daily, l.minor(300000));
        expect(own.plan!.assigned, greaterThan(money));
      });
      await f.tap('Ajustar el reparto');
      await f.step(
        '«Ajustar el reparto» abre los sobres con lo guardado, no con una '
        'propuesta nueva.',
      );
      await f.check('Al volver, el día a día dice 300.000', () {
        expect(_fieldText(f, 'Día a día'), '300.000');
      });
      await f.type('Día a día', '100000');
      await f.tap('Guardar el reparto');
      // Still over: what is left is 0 and the goal took it.
      await f.tap('Guardar así');
      await f.top();
      final int spent = spentThisPeriod(own.ledger!);
      final int stillOver = l.minor(100000) + goals - money;
      await f.step(
        'Con 100.000 de día a día «Te pasas por» baja a '
        '${_pesos(l, stillOver)}. Arriba, «Llevas \$0 de \$100.000»: los '
        '${_pesos(l, spent)} gastados desde el 30 de septiembre se fueron '
        'antes de repartir.',
      );
      await f.check(
        'El día a día no cuenta los ${_pesos(l, spent)} gastados antes de '
        'repartir',
        () {
          expect(dailySpent(own.ledger!, own.plan!), 0);
          expect(f.shows('Te pasaste por'), isFalse);
          expect(
            f.shows('Llevas ${_pesos(l, 0)} de ${_pesos(l, l.minor(100000))}'),
            isTrue,
          );
        },
      );
      await f.check(
        'El reparto ajustado quedó con 100.000 de día a día y «Te pasas por» '
        '${_pesos(l, stillOver)}',
        () {
          expect(own.plan!.daily, l.minor(100000));
          expect(own.plan!.assigned - money, stillOver);
          expect(_says(f, 'Te pasas por | ${_pesos(l, stillOver)}'), isTrue);
        },
      );
    },
  ),
  AppFlow(
    '06-05-anotar-cobros-de-ingresos-variables',
    'Anotar lo que me deben mis clientes',
    area: 'Plan',
    goal:
        'Trabajo por mi cuenta: quiero anotar lo que facturé, marcar lo que '
        'ya me pagaron y borrar lo que no va a llegar.',
    data: _planAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int incomes = own.freelance.incomes.length;
      final int pending = _pendingTotal(own);
      final int estimated = own.freelance
          .by(IncomeStatus.estimated)
          .fold(0, (int s, ExpectedIncome i) => s + i.amount);
      // The phone's share sheet, as if it opened.
      final List<String> shared = _shares(f, sheet: true);
      await _openPlan(f);
      await f.tap('Ingresos variables');
      await f.page(
        '«Ingresos variables»: lo por cobrar, lo estimado y la reserva arriba; '
        'Agencia Uno sale vencida, en color de alerta.',
        most: 2,
      );
      await f.tap('Agregar cobro');
      await f.tap('Guardar');
      await f.step(
        '«Agregar cobro» abre en «Facturado». Guardar sin nada muestra «Falta '
        'quién te paga o el valor.»',
      );
      await f.check('Sin datos no se guarda ningún cobro', () {
        expect(own.freelance.incomes.length, incomes);
      });
      await f.type('¿Quién te paga?', 'Café Origen');
      await f.type('Valor', '1200000');
      await f.tap('Estimado');
      await f.step(
        'Al tocar «Estimado» la ayuda cambia a «Crees que vendrá, pero aún no '
        'lo facturas.»',
      );
      await f.tap('Facturado');
      await f.tapFound(find.textContaining('Esperado el').last);
      await f.step('«Esperado el…» abre el calendario para elegir el día.');
      await _pickDay(f, '25');
      await f.type('Nota', 'Logo y papelería');
      await f.step(
        'Café Origen, 1.200.000, facturado y esperado el 25 de octubre, con '
        'una nota.',
      );
      await f.tap('Guardar');
      await f.step(
        'Café Origen queda en «Pendientes» y «Por cobrar» sube en 1.200.000.',
      );
      await f.check(
        'Queda un cobro más, facturado y para el 25 de octubre',
        () {
          expect(own.freelance.incomes.length, incomes + 1);
          final ExpectedIncome i = own.freelance.incomes.firstWhere(
            (ExpectedIncome i) => i.client == 'Café Origen',
          );
          expect(i.status, IncomeStatus.pending);
          expect(i.amount, l.minor(1200000));
          expect(i.expected, DateTime(2026, 10, 25));
          expect(i.note, 'Logo y papelería');
        },
      );
      await f.check(
        '«Por cobrar» muestra ${_pesos(l, pending + l.minor(1200000))}',
        () => expect(_says(f, _pesos(l, pending + l.minor(1200000))), isTrue),
      );
      await f.check('Un cobro facturado no cambia lo que puedes gastar', () {
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.tap('Agencia Uno');
      await f.step(
        'El cobro de Agencia Uno abre con «Recordar al cliente» y «Borrar '
        'cobro», porque está pendiente.',
      );
      await f.tap('Recordar al cliente');
      await f.step(
        '«Recordar al cliente» le pasa a la hoja de compartir del teléfono, '
        'que no sale en la imagen, un mensaje con el valor y la fecha.',
      );
      await f.check(
        'El mensaje nombra a Agencia Uno, los ${pesos(700000)} y el 28 de '
        'septiembre',
        () {
          expect(shared.single, startsWith('Hola, Agencia Uno.'));
          expect(shared.single, contains(pesos(700000)));
          expect(shared.single, contains('28 de septiembre'));
        },
      );
      await f.tap('Cobrado');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.step(
        'Con «Cobrado» aparece «¿Con qué movimiento llegó?»: se elige entre '
        'los ingresos de los últimos 90 días.',
      );
      await f.tapFound(find.textContaining('Agencia Uno ·').last);
      await f.tapFound(find.textContaining('Cobrado el').last);
      await _pickDay(f, '1');
      await f.tap('Guardar');
      final int reserve = own.ledger!.reserved;
      await f.page(
        'Agencia Uno ya no está vencida: pasó a «Cobrados» y la reserva subió '
        'con su 15 %.',
        most: 3,
      );
      await f.check('Agencia Uno quedó cobrada y ligada a su movimiento', () {
        final ExpectedIncome i = own.freelance.incomes.firstWhere(
          (ExpectedIncome i) => i.client == 'Agencia Uno',
        );
        expect(i.status, IncomeStatus.collected);
        expect(i.entryId, isNotNull);
        expect(i.collectedOn, DateTime(2026, 10, 1));
      });
      await f.check(
        'La reserva pasó de ${_pesos(l, l.reserved)} a ${_pesos(l, reserve)}: '
        'el 15 % de los 700.000',
        () => expect(reserve, l.reserved + l.minor(105000)),
      );
      await f.check(
        'Lo que puedes gastar bajó en esos 105.000 de reserva',
        () => expect(own.ledger!.freeUntilPayday, free - l.minor(105000)),
      );
      await f.tap('Taller de marca');
      await f.tap('Borrar cobro');
      await f.top();
      await f.step(
        '«Borrar cobro» quita Taller de marca de una vez, sin preguntar ni '
        'dejar deshacer: «Estimado» queda en $_zero.',
      );
      await f.check('Taller de marca ya no está y lo estimado pasó de '
          '${_pesos(l, estimated)} a $_zero', () {
        expect(
          own.freelance.incomes.any(
            (ExpectedIncome i) => i.client == 'Taller de marca',
          ),
          isFalse,
        );
        expect(own.freelance.by(IncomeStatus.estimated), isEmpty);
        expect(_says(f, 'Estimado | $_zero'), isTrue);
      });
    },
    manual: <String>[
      '«Recordar al cliente» abre la hoja de compartir del teléfono con el '
          'mensaje listo para WhatsApp o correo.',
      'Si la hoja de compartir no abre, el mensaje se copia: mirar si el '
          'aviso «Mensaje copiado» queda tapado por el formulario.',
    ],
  ),
  AppFlow(
    '06-06-reservar-de-cada-cobro',
    'Reservar una parte de cada cobro',
    area: 'Plan',
    goal:
        'Quiero apartar un porcentaje de lo que cobro para impuestos y que '
        'no me deje gastarlo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int reserve = l.reserved;
      final int entries = own.snapshot!.entries.length;
      await f.step(
        'Inicio: «Puedes gastar» ya deja fuera ${_pesos(l, reserve)} de '
        'reserva, el 15 % de lo cobrado desde el 1 de octubre.',
      );
      await _openPlan(f);
      await f.tap('Ingresos variables');
      await f.reveal(find.text('Usé de la reserva'));
      await f.step(
        '«Reserva»: aparta el 15 % de cada cobro; hoy son '
        '${_pesos(l, reserve)}, que siguen en tus cuentas.',
      );
      await f.tapFound(find.byType(DropdownButtonFormField<int>));
      await f.step('El porcentaje se elige de una lista: de «Nada» a 40 %.');
      await f.tapFound(find.text(percent(30)).last);
      await f.step(
        'Con 30 % la reserva pasa a ${_pesos(l, reserve * 2)}: el porcentaje '
        'nuevo cuenta también para lo cobrado desde el 1 de octubre.',
      );
      await f.check(
        'La reserva pasó a ${_pesos(l, reserve * 2)} y lo que puedes gastar '
        'bajó lo mismo',
        () {
          expect(own.freelance.reservePercent, 30);
          expect(own.ledger!.reserved, reserve * 2);
          expect(own.ledger!.freeUntilPayday, free - reserve);
        },
      );
      await f.tap('Usé de la reserva');
      await f.step(
        '«Usé de la reserva» pregunta cuánto usaste, por ejemplo en '
        'impuestos o seguridad social.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no se anota ningún uso', () {
        expect(own.freelance.used, isEmpty);
      });
      await f.tap('Usé de la reserva');
      await _typeInDialog(f, '50000');
      await f.tap('Guardar');
      await f.step(
        'Usaste 50.000: la reserva baja a '
        '${_pesos(l, reserve * 2 - l.minor(50000))}. No se anota ningún gasto: '
        'el pago de los impuestos hay que registrarlo aparte.',
      );
      await f.check('«Usé de la reserva» no crea ningún movimiento', () {
        expect(own.snapshot!.entries.length, entries);
        expect(own.freelance.used.single.$2, l.minor(50000));
      });
      await f.check(
        'La reserva quedó en ${_pesos(l, reserve * 2 - l.minor(50000))} y lo '
        'que puedes gastar subió 50.000',
        () {
          expect(own.ledger!.reserved, reserve * 2 - l.minor(50000));
          expect(own.ledger!.freeUntilPayday, free - reserve + l.minor(50000));
        },
      );
      await f.reveal(find.text('Lo cobrado'));
      await f.tap('Lo cobrado');
      await f.step(
        '«Lo cobrado»: los próximos días solo cuentan la plata que ya '
        'tienes, lo más prudente.',
      );
      await f.check('Con «Lo cobrado» no se espera ningún cobro', () {
        expect(own.freelance.scenario, IncomeScenario.collected);
        expect(own.ledger!.expected, isEmpty);
      });
      await f.tap('Todo');
      await f.step(
        '«Todo» cuenta también lo estimado, como Taller de marca: lo menos '
        'prudente.',
      );
      await f.check('Con «Todo» se esperan los tres cobros, el estimado '
          'también', () {
        expect(
          own.ledger!.expected.map((Movement m) => m.merchant),
          containsAll(<String>[
            'Estudio Norte',
            'Agencia Uno',
            'Taller de marca',
          ]),
        );
      });
      await f.check('Ningún cobro esperado cambia lo que puedes gastar', () {
        expect(own.ledger!.freeUntilPayday, free - reserve + l.minor(50000));
      });
      await f.tap('Lo facturado');
      await f.check(
        '«Lo facturado» deja fuera el estimado de Taller de marca',
        () {
          expect(own.freelance.scenario, IncomeScenario.pending);
          expect(
            own.ledger!.expected.map((Movement m) => m.merchant),
            isNot(contains('Taller de marca')),
          );
        },
      );
      await f.tapFound(find.byType(DropdownButtonFormField<int>));
      await f.tapFound(find.text('Nada').last);
      await f.step(
        'Con «Nada» no hay reserva: «Sin reserva: todo lo que cobras cuenta '
        'en lo que puedes gastar.»',
      );
      await f.check('Sin reserva, lo que puedes gastar sube en '
          '${_pesos(l, reserve)}', () {
        expect(own.ledger!.reserved, 0);
        expect(own.ledger!.freeUntilPayday, free + reserve);
      });
      await f.back();
      await f.tap('Inicio');
      await f.top();
      await f.step(
        'En Inicio, «Puedes gastar» quedó ${_pesos(l, reserve)} más alto que '
        'al empezar.',
      );
    },
  ),
  AppFlow(
    '06-07-crear-un-viaje-con-presupuesto',
    'Crear un viaje con presupuesto',
    area: 'Plan',
    goal:
        'Me voy a Ciudad de México: quiero un presupuesto en pesos mexicanos '
        'y anotar lo que gasto allá con la Visa.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int trips = own.trips.length;
      await _openPlan(f);
      await f.tap('Viajes');
      await f.step('«Viajes» con el de Nueva York y lo que le queda.');
      await f.tap('Nuevo viaje');
      await f.tap('Guardar');
      await f.step(
        '«Nuevo viaje» propone una semana desde hoy y la moneda de tus '
        'cuentas. Sin destino avisa «Falta a dónde vas.»',
      );
      await f.check('Sin destino no se crea ningún viaje', () {
        expect(own.trips.length, trips);
      });
      await f.type('¿A dónde vas?', 'Ciudad de México');
      await f.tapFound(find.textContaining(' – ').last);
      await f.step(
        'Las fechas se eligen en un calendario: primero el día de salida y '
        'luego el de regreso.',
      );
      await _tapInDialog(f, '20');
      await _tapInDialog(f, '26');
      await f.step('Del 20 al 26 de octubre, marcado en el calendario.');
      await f.tap('Guardar');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('MXN').last);
      await f.type('Presupuesto', '8000');
      await f.type('Comisión de tu tarjeta en el exterior', '3');
      await f.step(
        'Ciudad de México en MXN, del 20 al 26 de octubre, 8.000 de '
        'presupuesto y 3 % de comisión. El aviso rojo de antes sigue ahí.',
      );
      await f.tap('Guardar');
      await f.step(
        'El viaje nuevo aparece arriba de Nueva York, con lo que '
        'le queda.',
      );
      await f.check('Quedó el viaje en MXN con 8.000 y 3 % de comisión', () {
        final Trip t = own.trips.firstWhere(
          (Trip t) => t.name == 'Ciudad de México',
        );
        expect(t.currency, 'MXN');
        expect(t.budget, Decimal.fromInt(8000));
        expect(t.fee, 3);
        expect(t.from, DateTime(2026, 10, 20));
        expect(t.to, DateTime(2026, 10, 26));
      });
      await f.tap('Ciudad de México');
      await f.page(
        'El viaje: «Te quedan» todo el presupuesto, lo que puedes gastar al '
        'día y aún sin gastos.',
      );
      await f.tap('Agregar gasto del viaje');
      await f.tap('Guardar');
      await f.step(
        '«Agregar gasto del viaje» abre con la Visa. Sin valor avisa «Falta '
        'el valor o la tasa.»',
      );
      await f.type('¿En qué?', 'Taxi al hotel');
      await f.type('Valor', '350');
      await f.step(
        'No hay tasa guardada de MXN a COP: el campo pide escribir la que '
        'viste.',
      );
      await f.type('1 MXN en COP', '230');
      await f.tap('Transporte');
      // The fee comes from the trip, and each expense can change it.
      await f.type('Comisión', '0');
      await f.check(
        'Sin comisión se registrarían ${pesos(80500)}: 350 por 230',
        () => expect(_says(f, 'Se registran ${pesos(80500)} en Visa'), isTrue),
      );
      await f.type('Comisión', '3');
      await f.step(
        'Con la tasa de 230 y la comisión de 3 % dice cuánto se registra en '
        'la Visa, estimado hasta el cargo real.',
      );
      await f.check(
        'El aviso dice que se registran ${pesos(82915)} en Visa',
        () => expect(_says(f, pesos(82915)), isTrue),
      );
      await f.tap('Guardar');
      await f.page(
        'El taxi queda en «Gastos del viaje» con cómo se convirtió; «Te '
        'quedan» baja a 7.650 MXN.',
      );
      final Trip trip = own.trips.firstWhere(
        (Trip t) => t.name == 'Ciudad de México',
      );
      await f.check('Te quedan 7.650 MXN del viaje', () {
        expect(own.tripSummary(trip).left, Decimal.fromInt(7650));
      });
      await f.check('En la Visa quedó un gasto de ${pesos(82915)} en '
          'Transporte', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.payee == 'Taxi al hotel',
        );
        expect(own.snapshot!.account(e.accountId)!.name, 'Visa');
        expect(e.amount, Decimal.fromInt(-82915));
        expect(e.category, 'transport');
        expect(trip.foreign[e.id]!.rateSource, 'manual');
      });
    },
  ),
  AppFlow(
    '06-08-cuadrar-el-viaje-a-nueva-york',
    'Cuadrar los gastos de un viaje',
    area: 'Plan',
    goal:
        'Volví de Nueva York: quiero poner lo que el banco cobró de verdad, '
        'sacar lo que no fue del viaje y sumar el tiquete que pagué antes.',
    data: _planAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      Trip ny() => own.trip(newYork)!;
      final Decimal left = own.tripSummary(ny()).left!;
      await _openPlan(f);
      await f.tap('Viajes');
      await f.tap('Nueva York');
      await f.page(
        'Nueva York: lo que queda en dólares y cada gasto de esas fechas, '
        'también los de Medellín como el Metro y el Éxito, con su conversión.',
        most: 3,
      );
      await f.reveal(find.text('Ajustar al cargo real'));
      await f.tap('Ajustar al cargo real');
      await f.step(
        '«Ajustar al cargo real» en el MoMA trae el estimado; se cambia por '
        'lo que dice el extracto.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el MoMA sigue en ${pesos(107000)}', () {
        expect(_entry(own, 'MoMA').amount, Decimal.fromInt(-107000));
      });
      await f.tap('Ajustar al cargo real');
      await _typeInDialog(f, '');
      await f.tap('Guardar');
      await f.check('Sin valor el diálogo pide uno y no cambia el MoMA', () {
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(f.shows('Escribe cuánto pagaste.'), isTrue);
        expect(_entry(own, 'MoMA').amount, Decimal.fromInt(-107000));
      });
      await _typeInDialog(f, '108500');
      await f.tap('Guardar');
      await f.reveal(find.text('MoMA'));
      await f.step(
        'El MoMA ahora dice «El banco cobró ${pesos(108500)}» y cuánto más que el '
        'estimado.',
      );
      await f.check('El movimiento del MoMA quedó en ${pesos(108500)}', () {
        expect(_entry(own, 'MoMA').amount, Decimal.fromInt(-108500));
      });
      await f.check('Ajustar el cobro en pesos no cambia lo que queda en '
          'dólares', () {
        expect(own.tripSummary(ny()).left, left);
      });
      final List<TripLine> gyms = <TripLine>[
        for (final TripLine t in own.tripSummary(ny()).lines)
          if (t.entry.payee.startsWith('Fit24')) t,
      ];
      final Decimal gym = gyms.fold(
        Decimal.zero,
        (Decimal s, TripLine t) => s + t.local!,
      );
      await _tapTipBy(f, 'Fit24 gimnasio', 'No es del viaje');
      await _tapTipBy(f, 'Fit24', 'No es del viaje');
      await f.step(
        'Los dos cobros de Fit24 son del gimnasio en Medellín: con «No es del '
        'viaje» salen de la lista.',
      );
      await f.check('Sin el gimnasio, al viaje le quedan '
          '${left + gym} dólares', () {
        expect(
          ny().excluded,
          containsAll(gyms.map((TripLine t) => t.entry.id)),
        );
        final Decimal moved = own.tripSummary(ny()).left! - (left + gym);
        expect(moved.abs(), lessThanOrEqualTo(Decimal.parse('0.01')));
      });
      await f.tap('Incluir un gasto de antes');
      await f.step(
        '«Incluir un gasto de antes» lista todos los gastos de los 120 días '
        'antes del viaje, también el arriendo: el tiquete de Avianca es el '
        'segundo.',
      );
      await f.tapFound(
        find.ancestor(
          of: find.text('Avianca'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      await f.step('Tiquete marcado: desde ya cuenta en el viaje.');
      final Entry flight = _entry(own, 'Avianca');
      await f.check('El tiquete quedó incluido en el viaje', () {
        expect(ny().included, contains(flight.id));
      });
      await f.back();
      await f.top();
      await f.step(
        '«Te quedan» bajó por el tiquete, convertido a dólares con la TRM.',
      );
      await f.check(
        'Lo que queda bajó en lo que vale el tiquete en dólares',
        () {
          final TripLine line = own
              .tripSummary(ny())
              .lines
              .firstWhere((TripLine t) => t.entry.id == flight.id);
          // Each line rounds to the cent; the total does not.
          final Decimal moved =
              own.tripSummary(ny()).left! - (left + gym - line.local!);
          expect(moved.abs(), lessThanOrEqualTo(Decimal.parse('0.01')));
        },
      );
      await f.tap('Dividir gastos del viaje con alguien');
      await f.type('Nombre del grupo', 'Nueva York');
      await f.type('Agregar personas', 'Laura');
      await f.step(
        '«Dividir gastos del viaje con alguien» crea un grupo: nombre y las '
        'personas separadas por comas.',
      );
      await f.tap('Guardar');
      await f.reveal(find.text('Gastos compartidos del viaje'));
      await f.step(
        'El viaje queda ligado al grupo: «Gastos compartidos del viaje» con '
        'Tú y Laura.',
      );
      await f.check('El viaje quedó ligado a un grupo con Laura', () {
        final Group g = own.group(ny().groupId!)!;
        expect(g.members.map((Member m) => m.name), contains('Laura'));
      });
      await f.tap('Gastos compartidos del viaje');
      await f.step('Desde el viaje se abre el grupo, todavía sin gastos.');
      await f.check('La página del grupo lleva su nombre arriba', () {
        expect(
          find.descendant(
            of: find.byType(AppBar).last,
            matching: find.text('Nueva York'),
          ),
          findsOneWidget,
        );
      });
    },
  ),
  AppFlow(
    '06-09-cambiar-y-borrar-un-viaje',
    'Cambiar y borrar un viaje',
    area: 'Plan',
    goal:
        'Quiero anotar un gasto que pagué en dólares, subirle el presupuesto '
        'al viaje y, cuando ya no me sirva, borrarlo sin perder mis '
        'movimientos.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Decimal start = own.tripSummary(own.trip(newYork)!).left!;
      await _openPlan(f);
      await f.tap('Viajes');
      await f.tap('Nueva York');
      await f.tap('Agregar gasto del viaje');
      await f.type('¿En qué?', 'Metro de NY');
      await f.type('Valor', '34');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Cuenta en dólares · USD').last);
      await f.tapFound(find.textContaining(' de octubre').last);
      await _pickDay(f, '8');
      await f.tap('Transporte');
      await f.step(
        'Pagado con la cuenta en dólares no hay nada que convertir: el campo '
        'de la tasa desaparece. Fecha: 8 de octubre.',
      );
      await f.tap('Guardar');
      await f.check(
        'En la cuenta en dólares quedó el metro: 34 dólares el 8 de octubre',
        () {
          final Entry e = _entry(own, 'Metro de NY');
          expect(own.snapshot!.account(e.accountId)!.name, 'Cuenta en dólares');
          expect(e.amount, Decimal.fromInt(-34));
          expect(e.date.day, 8);
          expect(e.category, 'transport');
        },
      );
      await f.check('Al viaje le quedan 34 dólares menos, sin conversión', () {
        expect(
          own.tripSummary(own.trip(newYork)!).left,
          start - Decimal.fromInt(34),
        );
      });
      await f.tap('Metro de NY');
      await f.step(
        'Cada gasto del viaje abre su movimiento, para corregirlo o borrarlo '
        'como en Movimientos.',
      );
      await f.back();
      final Decimal left = own.tripSummary(own.trip(newYork)!).left!;
      final int entries = own.snapshot!.entries.length;
      await f.tapTip('Editar viaje');
      await f.step(
        '«Editar viaje» trae todo lo guardado: destino, fechas, '
        'moneda, presupuesto y comisión.',
      );
      await f.check('El formulario trae Nueva York, 1.500 dólares y 3 %', () {
        expect(_fieldText(f, '¿A dónde vas?'), 'Nueva York');
        expect(_fieldText(f, 'Presupuesto'), '1.500');
        expect(_fieldText(f, 'Comisión de tu tarjeta en el exterior'), '3');
        expect(f.shows('1 de octubre – 9 de octubre'), isTrue);
      });
      await f.type('Presupuesto', '2000');
      await f.tap('Guardar');
      await f.top();
      await f.step('Con 2.000 de presupuesto «Te quedan» sube 500 dólares.');
      await f.check('Al viaje le quedan 500 dólares más', () {
        expect(
          own.tripSummary(own.trip(newYork)!).left,
          left + Decimal.fromInt(500),
        );
      });
      await f.tapTip('Borrar viaje');
      await f.step(
        '«¿Borrar Nueva York?» aclara que sus gastos siguen en tus cuentas.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el viaje sigue', () {
        expect(own.trip(newYork), isNotNull);
      });
      await f.tapTip('Borrar viaje');
      await f.tap('Borrar viaje');
      await f.step('Borrado: de vuelta en «Viajes», que queda vacío.');
      await f.check('El viaje no está y los movimientos siguen todos', () {
        expect(own.trips, isEmpty);
        expect(own.snapshot!.entries.length, entries);
      });
    },
  ),
  AppFlow(
    '06-10-crear-una-meta-con-fecha',
    'Crear una meta con fecha',
    area: 'Plan',
    goal:
        'Quiero juntar para una moto antes de mayo y saber, con lo que pongo '
        'cada mes, cuándo la tengo.',
    data: seeded,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      await _openPlan(f);
      await f.reveal(find.text('Agregar meta'));
      await f.step(
        'En «Metas» todavía no hay ninguna: la línea explica que con un aporte '
        'al mes la app te dice cuándo llegas.',
      );
      await f.tap('Agregar meta');
      await f.tap('Guardar');
      await f.step(
        '«Agregar meta» sin datos: al guardar avisa «Ponle un nombre y cuánto '
        'quieres juntar.»',
      );
      await f.check('Sin nombre ni valor no se guarda ninguna meta', () {
        expect(own.snapshot!.goals, isEmpty);
      });
      await f.type('¿Para qué es?', 'Moto');
      await f.type('¿Cuánto quieres juntar?', '6000000');
      await f.type('¿Cuánto llevas?', '1500000');
      await f.type('¿Cuánto pones al mes?', '500000');
      await f.tap('Sin fecha límite');
      await f.step(
        '«Sin fecha límite» abre el calendario seis meses adelante, en abril '
        'de 2027.',
      );
      await _pickDay(f, '30');
      await f.step(
        'Moto: 6.000.000 en total, 1.500.000 ya ahorrados, 500.000 al mes y '
        '«Para el 30 de abril de 2027», con el año.',
      );
      await f.check('La fecha dice el año', () {
        expect(f.shows('Para el 30 de abril de 2027'), isTrue);
      });
      await f.tap('Guardar');
      final GoalShare moto = own.goalShares.single;
      final DateTime arrives = arrival(moto, from: own.today)!;
      final int needed = monthlyToReach(
        moto,
        DateTime(2027, 4, 30),
        from: own.today,
        step: 10000,
      )!;
      await f.reveal(find.text('Moto'));
      await f.step(
        'La meta queda en «Metas» con 25 % y «llega en ${monthYear(arrives)}»'
        ', después del 30 de abril, y lo dice: para llegar a tiempo hacen '
        'falta ${_pesos(own.ledger!, needed)} al mes, con un botón para '
        'usarlos.',
      );
      await f.check('La meta quedó guardada con todo lo escrito', () {
        final SavingsGoal g = own.snapshot!.goals.single;
        expect(g.name, 'Moto');
        expect(g.target.amount, Decimal.fromInt(6000000));
        expect(g.saved.amount, Decimal.fromInt(1500000));
        expect(g.monthly.amount, Decimal.fromInt(500000));
        expect(g.deadline, DateTime(2027, 4, 30));
      });
      await f.check(
        'La fila dice 25 % y que llega en ${monthYear(arrives)}: 4.500.000 '
        'que faltan, de a 500.000 al mes',
        () {
          expect(arrives, DateTime(2027, 7, 3));
          expect(f.shows(percent(25)), isTrue);
          expect(_says(f, 'llega en ${monthYear(arrives)}'), isTrue);
        },
      );
      await f.check('Avisa que no llega a tiempo y que hacen falta '
          '${_pesos(own.ledger!, needed)} al mes', () {
        expect(needed, own.ledger!.minor(750000));
        expect(
          _says(
            f,
            'Tu fecha es el 30 de abril de 2027: para llegar a tiempo '
            'necesitas ${_pesos(own.ledger!, needed)} al mes.',
          ),
          isTrue,
        );
      });
      await f.check('Crear la meta no cambia lo que puedes gastar', () {
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.tap('Usar ${_pesos(own.ledger!, needed)} al mes');
      await f.step(
        'Con «Usar ${_pesos(own.ledger!, needed)} al mes» el aporte cambia y '
        'la fila dice que llega a tiempo para el 30 de abril de 2027.',
      );
      await f.check('Ahora pone 750.000 al mes y llega a tiempo', () {
        expect(
          own.snapshot!.goals.single.monthly.amount,
          Decimal.fromInt(750000),
        );
        expect(_says(f, 'a tiempo para el 30 de abril de 2027'), isTrue);
      });
      await f.top();
      await f.tap('Repartir en sobres');
      final int share = proposeEnvelopes(
        own.ledger!,
        goals: own.goalShares,
        last: own.lastPlan,
        dailyName: '',
      ).firstWhere((Envelope e) => e.kind == EnvelopeKind.goal).amount;
      final int asks = goalShareFor(own.ledger!, own.goalShares.single);
      await f.step(
        'Al repartir la quincena aparece un sobre para la Moto. Pide la mitad '
        'del aporte del mes, porque te pagan dos veces al mes, pero el día a '
        'día va primero: la Moto recibe lo que queda, y arriba lo dice.',
      );
      await f.check(
        'La Moto pide ${_pesos(own.ledger!, asks)}, la mitad de 750.000, y '
        'recibe ${_pesos(own.ledger!, share)}, lo que deja el día a día',
        () {
          expect(asks, own.ledger!.minor(375000));
          expect(share, lessThanOrEqualTo(asks));
          expect(_fieldText(f, 'Moto'), _typed(own.ledger!, share));
          expect(
            f.screenText,
            contains(
              'Moto recibe ${_pesos(own.ledger!, share)} de '
              '${_pesos(own.ledger!, asks)}',
            ),
          );
        },
      );
      await f.back();
    },
  ),
  AppFlow(
    '06-11-abonar-cambiar-y-borrar-una-meta',
    'Abonar, cambiar y borrar una meta',
    area: 'Plan',
    goal:
        'Ya junté más para el viaje a Cartagena: quiero anotarlo, ver si '
        'llego antes y, si cambio de idea, borrar la meta.',
    data: _withGoal,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int entries = own.snapshot!.entries.length;
      final int before = own.ledger!.freeUntilPayday;
      final Money worth = own.netWorth().total;
      final Account from = own.likelyPaymentAccount!;
      await _openPlan(f);
      await f.reveal(find.text('Viaje a Cartagena'));
      await f.step(
        'La meta del viaje va en 27 %: llevas 650.000 de 2.400.000 y llega '
        'en abril de 2027, después del 20 de diciembre que le pusiste; la '
        'fila lo avisa y tiene «Abonar».',
      );
      await f.tap('Abonar');
      await f.step(
        '«Abonar a Viaje a Cartagena» pregunta a dónde va la plata. No hay '
        'cuenta de ahorros en pesos: dice que la guardes en una para que '
        'salga de lo que puedes gastar, y ofrece agregarla aquí mismo.',
      );
      await f.tap('Agregar cuenta de ahorros');
      await f.step(
        'La cuenta nueva viene llena: «Ahorro para Viaje a Cartagena», de '
        'tipo «Ahorro o inversión», fuera del uso diario.',
      );
      await f.tap('Guardar');
      await f.type('Monto', '300000');
      await f.step(
        'De vuelta en «Abonar», la cuenta nueva quedó elegida y viene «Desde» '
        '${from.name}. Abajo dice qué va a pasar antes de guardar.',
      );
      await f.check(
        'Antes de guardar dice cómo queda la meta y qué cuentas cambian',
        () => expect(
          f.screenText,
          contains(
            'La meta quedará en ${pesos(950000)} de ${pesos(2400000)}. '
            '${from.name} baja ${pesos(300000)} y Ahorro para Viaje a '
            'Cartagena sube lo mismo',
          ),
        ),
      );
      await f.tap('Abonar');
      await f.reveal(find.text('Viaje a Cartagena'));
      final GoalShare after = own.goalShares.single;
      await f.step(
        'Con 300.000 más ahorrados la meta sube a 40 % y llega en '
        '${monthYear(arrival(after, from: own.today)!)}.',
      );
      await f.check(
        'Los 300.000 pasaron de ${from.name} a la cuenta de ahorros: salen de '
        'lo que puedes gastar y el patrimonio no cambia',
        () {
          final Account savings = own.accounts.firstWhere(
            (Account a) => a.name == 'Ahorro para Viaje a Cartagena',
          );
          expect(savings.spendable, isFalse);
          expect(own.balances[savings.id]!.amount, Decimal.fromInt(300000));
          expect(own.ledger!.freeUntilPayday, before - 300000);
          expect(own.netWorth().total, worth);
        },
      );
      await f.check('Lo ahorrado quedó en 950.000', () {
        expect(
          own.snapshot!.goals.single.saved.amount,
          Decimal.fromInt(950000),
        );
      });
      await f.check(
        'Llega un mes antes: ${monthYear(arrival(after, from: own.today)!)}',
        () {
          expect(arrival(after, from: own.today), DateTime(2027, 3, 3));
          expect(f.shows(percent(40)), isTrue);
        },
      );
      await f.tap('Viaje a Cartagena');
      await f.type('¿Cuánto pones al mes?', '500000');
      await f.tap('Guardar');
      await f.reveal(find.text('Viaje a Cartagena'));
      final int needed = monthlyToReach(
        own.goalShares.single,
        DateTime(2026, 12, 20),
        from: own.today,
        step: 10000,
      )!;
      await f.step(
        'Con 500.000 al mes llega en enero de 2027, todavía después del 20 de '
        'diciembre, y la fila lo advierte: para llegar a tiempo hacen falta '
        '${_pesos(own.ledger!, needed)} al mes.',
      );
      await f.check(
        'Con 500.000 al mes llega en enero de 2027, y lo avisa',
        () {
          expect(
            arrival(own.goalShares.single, from: own.today),
            DateTime(2027, 1, 3),
          );
          expect(
            _says(f, 'llega en ${monthYear(DateTime(2027, 1, 3))}'),
            isTrue,
          );
          expect(
            _says(
              f,
              'Tu fecha es el 20 de diciembre de 2026: para llegar a tiempo '
              'necesitas ${_pesos(own.ledger!, needed)} al mes.',
            ),
            isTrue,
          );
        },
      );
      await f.top();
      await f.tap('Repartir en sobres');
      await f.tap('Guardar el reparto');
      final int free = own.ledger!.freeUntilPayday;
      final int aside = own.plan!.setAside;
      await f.step(
        'Con el reparto guardado, la tarjeta de arriba aparta '
        '${_pesos(own.ledger!, aside)} para el viaje este periodo.',
      );
      await f.reveal(find.text('Viaje a Cartagena').last);
      await f.tap('Viaje a Cartagena');
      await f.tap('Borrar meta');
      await f.step(
        '«¿Borrar «Viaje a Cartagena»?» aclara que tus cuentas y movimientos '
        'no cambian.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» la meta sigue', () {
        expect(own.snapshot!.goals, hasLength(1));
      });
      await f.tap('Borrar meta');
      await f.tap('Borrar meta');
      await f.step(
        'Borrada: «Metas» vuelve a decir que todavía no tienes metas.',
      );
      await f.check('La meta ya no está y los movimientos siguen todos', () {
        expect(own.snapshot!.goals, isEmpty);
        // The contribution's two legs stay: the money is still saved.
        expect(own.snapshot!.entries.length, entries + 2);
      });
      await f.top();
      await f.step(
        'Arriba, el reparto ya no tiene el sobre del viaje: los 250.000 que '
        'apartaba vuelven a «Sin asignar».',
      );
      await f.check('El sobre de la meta borrada ya no aparta '
          '${_pesos(own.ledger!, aside)}: vuelven a lo que puedes gastar', () {
        expect(
          own.plan!.envelopes.where(
            (Envelope e) => e.kind == EnvelopeKind.goal,
          ),
          isEmpty,
        );
        expect(own.ledger!.freeUntilPayday, free + aside);
      });
    },
  ),
  AppFlow(
    '06-12-guardar-un-deseo-para-despues',
    'Guardar un deseo para después',
    area: 'Plan',
    goal:
        'Quiero anotar unos audífonos y una chaqueta que me gustan, ver qué le '
        'hacen a mi meta y, cuando decida, comprar uno o descartarlo.',
    data: _withGoal,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final GoalShare trip = own.goalShares.single;
      await _openPlan(f);
      await f.tap('Lo quiero, pero después');
      await f.step(
        '«Lo quiero, pero después» vacío: explica que el precio lo pones tú '
        'y que nada se compra ni se sigue en una tienda.',
      );
      await f.tap('Agregar deseo');
      await f.tap('Guardar');
      await f.step('Sin datos, «Guardar» avisa «Ponle un nombre y un precio.»');
      await f.check('Sin nombre ni precio no se guarda ningún deseo', () {
        expect(own.wishes, isEmpty);
      });
      await f.type('¿Qué quieres?', 'Audífonos');
      await f.type('¿Cuánto cuesta?', '600000');
      await f.tap('Muy deseado');
      await f.tap('Esperar 30 días antes de decidir');
      await f.step(
        'Audífonos de 600.000, «Muy deseado» y con el interruptor de esperar '
        '30 días antes de decidir encendido.',
      );
      await f.tap('Guardar');
      final DateTime before = arrival(trip, from: own.today)!;
      final DateTime later = arrival(
        trip,
        from: own.today,
        extra: -l.minor(600000),
      )!;
      await f.step(
        'El deseo dice hasta cuándo esperas y que, si lo compras, el viaje a '
        'Cartagena llegaría en ${monthYear(later)} en vez de '
        '${monthYear(before)}.',
      );
      await f.check('Quedó el deseo, muy deseado y esperando 30 días', () {
        final Wish w = own.wishes.single;
        expect(w.name, 'Audífonos');
        expect(w.price, l.minor(600000));
        expect(w.priority, 1);
        expect(w.waitUntil, DateTime(2026, 11, 2));
        expect(
          f.shows('Esperas hasta el 2 de noviembre para decidir.'),
          isTrue,
        );
      });
      await f.check(
        'Comprarlo atrasa la meta de ${monthYear(before)} a '
        '${monthYear(later)}',
        () => expect(
          f.shows(
            'Si lo compras, Viaje a Cartagena llegaría en ${monthYear(later)} '
            'en vez de ${monthYear(before)}.',
          ),
          isTrue,
        ),
      );
      await f.tap('Agregar deseo');
      await f.type('¿Qué quieres?', 'Chaqueta');
      await f.type('¿Cuánto cuesta?', '180000');
      await f.tap('Si sobra');
      await f.tap('Guardar');
      await f.step(
        'Con la chaqueta «Si sobra», la lista va de lo más deseado a lo '
        'menos: los audífonos primero.',
      );
      await f.check('Los deseos se ordenan por prioridad', () {
        expect(
          f.tester.getTopLeft(find.text('Audífonos')).dy,
          lessThan(f.tester.getTopLeft(find.text('Chaqueta')).dy),
        );
        expect(own.wishes.map((Wish w) => w.priority), <int>[1, 3]);
      });
      await f.tapFound(find.text('¿Me alcanza?').last);
      final PurchaseCheck fits = checkPurchase(
        own.ledger!,
        price: l.minor(180000),
        date: own.today,
        label: 'Chaqueta',
        atLeast: 30,
      );
      await f.step(
        '«¿Me alcanza?» abre con el precio y el nombre de la chaqueta: «Te '
        'alcanza» y el saldo más bajo hasta el pago.',
      );
      await f.check('El veredicto es el que calcula la app: te alcanza, con '
          '${_pesos(l, fits.lowest)} el día más bajo', () {
        expect(fits.verdict, PurchaseVerdict.fits);
        expect(_fieldText(f, '¿Cuánto cuesta?'), '180.000');
        expect(f.shows('Te alcanza, según lo que sabe la app'), isTrue);
        expect(_says(f, _pesos(l, fits.lowest)), isTrue);
      });
      await f.check('Mirar si alcanza no compra ni anota nada', () {
        expect(own.wishes, hasLength(2));
        expect(own.ledger!.freeUntilPayday, l.freeUntilPayday);
      });
      await f.back();
      final int beforeBuying = own.ledger!.freeUntilPayday;
      await _tapTextBy(f, 'Chaqueta', 'Lo compré');
      await f.step(
        '«Lo compré» abre el gasto ya escrito: «Chaqueta», \$180.000 y la '
        'fecha de hoy. Solo falta ver de dónde salió y guardar.',
      );
      await f.check('El gasto viene lleno con el deseo', () {
        expect(_fieldText(f, 'Monto'), '180.000');
        expect(_fieldText(f, '¿Dónde o a quién?'), 'Chaqueta');
      });
      await f.tap('Guardar');
      await f.step(
        'Guardado, la chaqueta sale de la lista: ya no es un deseo sino un '
        'gasto de \$180.000.',
      );
      await f.check(
        'Solo quedan los audífonos, y la chaqueta salió de lo que puedes '
        'gastar',
        () {
          expect(own.wishes.map((Wish w) => w.name), <String>['Audífonos']);
          final Entry e = own.snapshot!.entries.firstWhere(
            (Entry e) => e.payee == 'Chaqueta',
          );
          expect(e.amount, Decimal.fromInt(-180000));
          expect(own.ledger!.freeUntilPayday, beforeBuying - 180000);
        },
      );
      await f.back();
      await f.reveal(find.text('Lo quiero, pero después'));
      await f.step('En Plan, la fila de deseos dice «Un deseo».');
      await f.check('La fila de Plan cuenta un deseo', () {
        expect(f.shows('Un deseo'), isTrue);
      });
    },
  ),
  AppFlow(
    '06-13-agregar-un-pago-fijo-sugerido',
    'Agregar un pago fijo que la app sugiere',
    area: 'Plan',
    goal:
        'La app ve que Spotify y Claro me cobran cada mes: quiero agregar el '
        'que sí es fijo y decirle que el otro no lo es.',
    data: _withGuesses,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int fixed = own.recurring.length;
      await _openPlan(f);
      await f.tap('Pagos fijos');
      await f.step(
        '«Pagos fijos»: arriba lo que viene en 30 días; «Parecen pagos fijos» '
        'trae Claro y Spotify, con los cobros que los delatan.',
      );
      await f.check('La app sugiere Claro y Spotify', () {
        expect(
          own.recurringGuesses.map((RecurringGuess g) => g.name),
          containsAll(<String>['Claro', 'Spotify']),
        );
      });
      await _tapTextBy(f, 'Claro', 'No es fijo');
      await f.step(
        'Con «No es fijo» Claro sale de las sugerencias y no vuelve a '
        'aparecer.',
      );
      await f.check('Claro quedó como «no es fijo» y ya no se sugiere', () {
        expect(own.detective.notRecurring, <String>{merchantKey('Claro')});
        expect(
          own.recurringGuesses.map((RecurringGuess g) => g.name),
          isNot(contains('Claro')),
        );
        expect(own.recurring.length, fixed);
      });
      await _tapTextBy(f, 'Spotify', 'Agregar como pago fijo');
      await f.page(
        '«Agregar como pago fijo» abre el formulario lleno: Spotify, 16.900, '
        'cada mes, el 5 de octubre y en Suscripciones.',
        most: 2,
      );
      await f.check('El formulario trae el valor y el día que sugirió', () {
        expect(_fieldText(f, '¿Qué es?'), 'Spotify');
        expect(_fieldText(f, '¿Cuánto cobra?'), '16.900');
        expect(f.shows('Próximo cobro: 5 de octubre'), isTrue);
      });
      await f.tap('Guardar');
      await f.page(
        'Spotify pasa a «Suscripciones», con su próximo cobro el 5 de '
        'octubre, y ya no se sugiere.',
        most: 2,
      );
      await f.check('Quedó un pago fijo más: Spotify, 16.900 cada mes', () {
        final RecurringCharge r = own.recurring.firstWhere(
          (RecurringCharge r) => r.name == 'Spotify',
        );
        expect(r.amount.amount, Decimal.fromInt(16900));
        expect(r.cadence, Cadence.monthly);
        expect(r.nextDate, DateTime(2026, 10, 5));
        expect(r.category, 'subscriptions');
        expect(own.recurringGuesses, isEmpty);
      });
      await f.check(
        'Como cobra antes del pago, lo que puedes gastar baja 16.900: de '
        '${_pesos(l, free)} a ${_pesos(l, free - l.minor(16900))}',
        () => expect(own.ledger!.freeUntilPayday, free - l.minor(16900)),
      );
    },
  ),
  AppFlow(
    '06-14-agregar-una-suscripcion-con-prueba-gratis',
    'Agregar una suscripción en prueba gratis',
    area: 'Plan',
    goal:
        'Me suscribí a Disney+ con un mes gratis: quiero que la app me avise '
        'antes de que empiece a cobrar y cuánto me cuesta al año.',
    data: seeded,
    manual: <String>[
      'El permiso de notificaciones del teléfono: aceptarlo y negarlo al '
          'guardar un pago fijo con aviso.',
      'Que el aviso de la prueba gratis llegue a las 9 de la mañana del día '
          'antes, sin montos en la pantalla bloqueada.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      var allow = true;
      final List<MethodCall> calls = _reminders(f, allow: () => allow);
      await _openPlan(f);
      await f.tap('Pagos fijos');
      await f.tap('Agregar pago fijo');
      await f.tap('Guardar');
      await f.step(
        '«Agregar pago fijo» abre en Suscripciones; guardar sin datos avisa '
        '«Falta el nombre o el valor.»',
      );
      await f.type('¿Qué es?', 'Disney+');
      await f.type('¿Cuánto cobra?', '38900');
      await f.tapFound(find.byType(DropdownButtonFormField<Cadence>));
      await f.step(
        '«Cada cuánto» ofrece cada mes, cada dos semanas, cada semana o cada '
        'año.',
      );
      await f.tapFound(find.text('Cada mes').last);
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.tapFound(find.text('Visa').last);
      await f.tapFound(find.byType(DropdownButtonFormField<int?>));
      await f.step(
        '«Avisarme antes de cada cobro»: no avisar, el mismo día, un día, '
        'tres días o una semana antes.',
      );
      await f.tapFound(find.text('3 días antes').last);
      await f.check('Sin prueba, el primer cobro propuesto es en un mes', () {
        expect(f.shows('Próximo cobro: 3 de noviembre'), isTrue);
      });
      await f.tap('¿Está en prueba gratis?');
      await _pickDay(f, '17');
      await f.tap('Ya no la uso');
      await f.page(
        'Prueba hasta el 17 de octubre: el primer cobro pasa solo a ese día. '
        '«Ya no la uso» muestra lo que ahorras al año si la pausas.',
        most: 2,
      );
      await f.check('Al poner la prueba, el próximo cobro pasó al 17 de '
          'octubre, el día que termina', () {
        expect(f.shows('Próximo cobro: 17 de octubre'), isTrue);
      });
      await f.tapTip('Quitar la prueba gratis');
      await f.check('«Quitar la prueba gratis» la quita del formulario', () {
        expect(f.shows('¿Está en prueba gratis?'), isTrue);
      });
      await f.tap('¿Está en prueba gratis?');
      await _pickDay(f, '17');
      await f.tap('Sí, la uso');
      await f.page(
        'Listo: 38.900 cada mes desde la Visa, aviso tres días antes, prueba '
        'hasta el 17 de octubre y primer cobro ese día. Al año son 466.800.',
        most: 3,
      );
      await f.tap('Guardar');
      await f.step(
        'Disney+ queda en «Suscripciones» con «Prueba gratis hasta el 17 de '
        'octubre» y la campana de aviso.',
      );
      await f.check(
        'Quedó Disney+: 38.900 cada mes, desde la Visa, primer cobro el 17',
        () {
          final RecurringCharge r = own.recurring.firstWhere(
            (RecurringCharge r) => r.name == 'Disney+',
          );
          expect(r.amount.amount, Decimal.fromInt(38900));
          expect(r.cadence, Cadence.monthly);
          expect(r.nextDate, DateTime(2026, 10, 17));
          expect(own.snapshot!.account(r.accountId!)!.name, 'Visa');
          expect(r.category, 'subscriptions');
        },
      );
      await f.check('Se guardó la prueba, el aviso y que la usas', () {
        final RecurringCharge r = own.recurring.firstWhere(
          (RecurringCharge r) => r.name == 'Disney+',
        );
        final ChargeMemory m = own.memoryOf(r.id);
        expect(m.trialEnds, DateTime(2026, 10, 17));
        expect(m.remindDays, 3);
        expect(m.inUse, isTrue);
      });
      await f.check(
        'La app pidió permiso y programó el aviso de la prueba para el 16 '
        'de octubre a las 9',
        () {
          expect(calls.map((MethodCall c) => c.method), contains('ask'));
          final List<Object?> items =
              (calls
                          .lastWhere((MethodCall c) => c.method == 'schedule')
                          .arguments
                      as Map<Object?, Object?>)['items']!
                  as List<Object?>;
          final Map<Object?, Object?> trial = items
              .cast<Map<Object?, Object?>>()
              .firstWhere(
                (Map<Object?, Object?> i) =>
                    '${i['title']}'.contains('Disney+'),
              );
          expect(
            trial['title'],
            'La prueba gratis de Disney+ termina el 17 de octubre',
          );
          expect(trial['at'], DateTime(2026, 10, 16, 9).millisecondsSinceEpoch);
        },
      );
      await f.check(
        'Cobra después del pago del 15: lo que puedes gastar no cambia',
        () => expect(own.ledger!.freeUntilPayday, free),
      );
      // Now someone who said no to notifications.
      allow = false;
      await f.tap('Netflix');
      await f.tapFound(find.byType(DropdownButtonFormField<int?>));
      await f.tapFound(find.text('Un día antes').last);
      await f.tap('Guardar');
      await f.step(
        'Si el teléfono no da permiso, el aviso de Netflix se guarda igual y '
        'abajo explica cómo activar las notificaciones.',
      );
      await f.check('Sin permiso, el aviso de Netflix queda guardado', () {
        final RecurringCharge r = own.recurring.firstWhere(
          (RecurringCharge r) => r.name == 'Netflix',
        );
        expect(own.memoryOf(r.id).remindDays, 1);
        expect(
          find.textContaining('Sin permiso para avisarte'),
          findsOneWidget,
        );
      });
    },
  ),
  AppFlow(
    '06-15-cambiar-pausar-y-borrar-un-pago-fijo',
    'Cambiar, pausar y borrar un pago fijo',
    area: 'Plan',
    goal:
        'El gimnasio subió y Netflix ya no lo uso: quiero poner el precio '
        'nuevo, pausar Netflix y al final borrarlo.',
    data: _withGym,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int entries = own.snapshot!.entries.length;
      RecurringCharge charge(String name) =>
          own.recurring.firstWhere((RecurringCharge r) => r.name == name);
      final List<MethodCall> calls = _reminders(f, allow: () => true);
      await _openPlan(f);
      await f.tap('Pagos fijos');
      await f.page(
        'Netflix dice que ya no la usas y cuánto ahorras al año; Fit24 «Subió '
        'de \$99.000 a \$119.000» y ofrece actualizarlo.',
        most: 3,
      );
      await f.tap('Actualizar a ${pesos(119000)}, como el último cobro');
      await f.step(
        'Con un toque Fit24 queda en 119.000, como el último cobro, y el '
        'botón desaparece.',
      );
      await f.check('Fit24 quedó en 119.000', () {
        expect(charge('Fit24').amount.amount, Decimal.fromInt(119000));
      });
      await f.tap('Fit24');
      await f.type('¿Cuánto cobra?', '125000');
      await f.step(
        'Al escribir otro valor, el formulario ofrece volver al del último '
        'cobro: «El último cobro fue \$119.000, el 1 de octubre».',
      );
      await f.tapContaining('El último cobro fue');
      await f.check('El botón devuelve el valor a 119.000', () {
        expect(_fieldText(f, '¿Cuánto cobra?'), '119.000');
      });
      await f.tap('Salud');
      await f.tapFound(find.byType(DropdownButtonFormField<Cadence>));
      await f.tapFound(find.text('Cada dos semanas').last);
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.step(
        '«Se paga desde» ofrece cada cuenta, también Binance y Bitcoin, y '
        '«Ninguna cuenta en particular»; arriba ya dice «Cada dos semanas».',
      );
      await f.tapFound(find.text('Ninguna cuenta en particular').last);
      await f.back();
      await f.check('Cerrar el formulario sin guardar no cambia nada', () {
        final RecurringCharge gym = charge('Fit24');
        expect(gym.amount.amount, Decimal.fromInt(119000));
        expect(gym.category, 'leisure');
        expect(gym.cadence, Cadence.monthly);
        expect(own.snapshot!.account(gym.accountId!)!.name, 'Bancolombia');
      });
      await f.tap('Netflix');
      await f.reveal(find.text('Pausar'));
      await f.step(
        'Netflix abre con «Pausar», que aclara que solo deja de contarse: '
        'para que no cobre hay que cancelarlo con el servicio.',
      );
      await f.tap('Pausar');
      await f.page(
        'Netflix pasa a «En pausa» y deja de contarse en lo que viene.',
        most: 2,
      );
      await f.check(
        'En pausa, lo que puedes gastar sube 26.900: no cobra antes del pago',
        () {
          expect(charge('Netflix').active, isFalse);
          expect(own.ledger!.freeUntilPayday, free + l.minor(26900));
        },
      );
      await f.check(
        'En pausa ya no queda programado el aviso de Netflix, aunque la fila '
        'siga con su campana',
        () {
          expect(_remindsOf(calls, 'Netflix'), isFalse);
          expect(own.memoryOf(charge('Netflix').id).remindDays, 3);
        },
      );
      await f.tap('Netflix');
      await f.page(
        'En pausa, el formulario lo dice arriba: «En pausa: no se cuenta como '
        'comprometido.» Abajo, «Pausar» cambia a «Reanudar».',
        most: 2,
      );
      await f.tap('Reanudar');
      await f.check('Reanudado, vuelve a contarse como antes', () {
        expect(charge('Netflix').active, isTrue);
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.check('Reanudado, el aviso de Netflix vuelve a programarse', () {
        expect(_remindsOf(calls, 'Netflix'), isTrue);
      });
      await f.tap('Netflix');
      await f.tap('Borrar pago fijo');
      await f.step(
        '«¿Borrar Netflix?» aclara que los cobros que ya registraste se '
        'quedan.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» Netflix sigue', () {
        expect(
          own.recurring.any((RecurringCharge r) => r.name == 'Netflix'),
          isTrue,
        );
      });
      final String netflix = charge('Netflix').id;
      await f.tap('Borrar pago fijo');
      await f.tap('Borrar pago fijo');
      await f.page('Sin Netflix, solo queda Fit24 en la lista.', most: 2);
      await f.check(
        'Netflix ya no está, su aviso tampoco, y los movimientos siguen',
        () {
          expect(
            own.recurring.any((RecurringCharge r) => r.name == 'Netflix'),
            isFalse,
          );
          expect(own.memoryOf(netflix).remindDays, isNull);
          expect(own.snapshot!.entries.length, entries);
          expect(own.ledger!.freeUntilPayday, free + l.minor(26900));
        },
      );
    },
  ),
  AppFlow(
    '06-16-decir-que-no-tengo-pagos-fijos',
    'Decir que no tengo pagos fijos',
    area: 'Plan',
    goal:
        'Vivo con mis papás y no pago nada fijo: quiero que la app deje de '
        'decir que lo que puedo gastar es provisional.',
    data: _noFixed,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      await f.step(
        'Inicio: «Puedes gastar» dice «Provisional: faltan tus pagos fijos» y '
        'una tarea pide agregarlos.',
      );
      await f.check('Sin pagos fijos, la cifra es provisional', () {
        expect(own.provisional, isTrue);
        expect(f.shows('Provisional: faltan tus pagos fijos'), isTrue);
      });
      await _openPlan(f);
      await f.tap('Pagos fijos');
      await f.step(
        '«Pagos fijos» vacío: «Aún no tienes pagos fijos» y el botón «No tengo '
        'pagos fijos».',
      );
      await f.tap('No tengo pagos fijos');
      await f.step(
        'Con un toque el botón desaparece y abajo confirma: «Listo. Lo que '
        'puedes gastar ya no es provisional.»',
      );
      await f.check('La respuesta quedó guardada', () {
        expect(own.noFixedPayments, isTrue);
        expect(own.provisional, isFalse);
      });
      await f.back();
      await f.tap('Inicio');
      await f.top();
      await f.step('En Inicio ya no dice «Provisional» y la tarea se fue.');
      await f.check('Inicio ya no dice provisional y la cifra no cambia', () {
        expect(f.shows('Provisional: faltan tus pagos fijos'), isFalse);
        expect(own.ledger!.freeUntilPayday, free);
      });
    },
  ),
  AppFlow(
    '06-17-registrar-una-compra-a-cuotas-con-tasa',
    'Registrar una compra a cuotas con su tasa',
    area: 'Plan',
    goal:
        'Compré un portátil a 12 cuotas con la Visa: quiero ver cuánto pago en '
        'total, cuánto más que de contado y, si me equivoqué, corregirlo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int plans = own.instalments.length;
      Instalments laptop() =>
          own.instalments.firstWhere((Instalments p) => p.name == 'Portátil');
      await _openPlan(f);
      await f.tap('Compras a cuotas');
      await f.tap('Agregar compra a cuotas');
      await f.tap('Guardar');
      await f.step(
        '«Agregar compra a cuotas» sin datos: al guardar avisa «Falta el '
        'nombre, el valor financiado o el número de cuotas.»',
      );
      await f.check('Sin datos no se guarda ninguna compra', () {
        expect(own.instalments.length, plans);
      });
      await f.type('¿Qué compraste?', 'Portátil');
      await f.type('Valor financiado', '3600000');
      await f.type('Número de cuotas', '12');
      await f.type('Tasa de interés', '1,9');
      await f.tapFound(find.byType(DropdownButtonFormField<RateKind>));
      await f.step(
        '«Cómo la dicen» ofrece E.A., M.V. o mensual, como aparece en el '
        'extracto.',
      );
      await f.tapFound(find.text('mensual').last);
      await f.type('Cuota de manejo o seguro, por cuota', '0');
      await f.type('Precio de contado', '3400000');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.tapFound(find.text('Visa').last);
      await f.page(
        'Portátil: 3.600.000 a 12 cuotas, 1,9 % mensual, sin cuota de manejo, '
        '3.400.000 de contado y con la Visa, que ya tiene la compra.',
        most: 3,
      );
      await f.tap('Guardar');
      await f.step(
        'Como la Visa no tiene un gasto de ese valor, pregunta «¿La compra ya '
        'está en Visa?»: lo que debes en la tarjeta la incluye solo si está '
        'anotada.',
      );
      await f.check('Pregunta si la compra ya está en la Visa', () {
        expect(f.shows('¿La compra ya está en Visa?'), isTrue);
      });
      await f.tap('Ya está anotada');
      final int owed = own.instalments.fold(
        0,
        (int s, Instalments p) => s + (p.remaining ?? 0),
      );
      await f.step(
        'Con «Ya está anotada» el portátil queda en la lista con su primera '
        'cuota el 3 de noviembre y «Te falta pagar» sube a '
        '${_pesos(l, owed)}.',
      );
      await f.check('Quedó la compra con la tasa mensual y la Visa', () {
        final Instalments p = laptop();
        expect(p.principal, l.minor(3600000));
        expect(p.count, 12);
        expect(p.rate, 1.9);
        expect(p.rateKind, RateKind.monthly);
        expect(p.fee, 0);
        expect(p.cashPrice, l.minor(3400000));
        expect(own.snapshot!.account(p.accountId!)!.name, 'Visa');
        expect(p.firstDue, DateTime(2026, 11, 3));
      });
      await f.check(
        'Pagada con la Visa, la compra no se cuenta dos veces: lo que puedes '
        'gastar no cambia',
        () => expect(own.ledger!.freeUntilPayday, free),
      );
      await f.tap('Portátil');
      final Instalments p = laptop();
      await f.page(
        'El detalle: cuánto falta, el total con tus datos, cuánto más que de '
        'contado, lo que dijo el banco y el calendario con interés y capital.',
        most: 4,
      );
      await f.check('La cuota calculada es ${_pesos(l, p.payment!)} y el total '
          '${_pesos(l, p.total!)}, ${_pesos(l, p.total! - l.minor(3400000))} '
          'más que de contado', () {
        expect(p.totalKnown, isTrue);
        expect(
          f.shows(
            'En total pagarás ${_pesos(l, p.total!)}, con los datos que '
            'diste.',
          ),
          isTrue,
        );
        expect(
          f.shows(
            'De contado costaba ${pesos(3400000)}: a cuotas pagas '
            '${_pesos(l, p.total! - l.minor(3400000))} más.',
          ),
          isTrue,
        );
        expect(
          f.shows('${_pesos(l, p.payment!)}, calculada con la tasa'),
          isTrue,
        );
      });
      // A fixed instalment, worked out apart from the app: P·r / (1 − (1+r)^−n).
      final double rate = 0.019;
      final double annuity =
          3600000 * rate / (1 - 1 / math.pow(1 + rate, 12).toDouble());
      await f.reveal(find.textContaining('Cuota 1 ·'));
      await f.check('La cuota es la de una cuota fija al 1,9 % mensual: '
          '${pesos(annuity.round())}, y el primer interés ${pesos(68400)}', () {
        expect(l.major(p.payment!), closeTo(annuity, 1));
        expect(_says(f, 'Interés ${pesos(68400)}'), isTrue);
      });
      await f.tapTip('Editar compra a cuotas');
      await f.type('Tasa de interés', '25');
      await f.tapFound(find.byType(DropdownButtonFormField<RateKind>));
      await f.tapFound(find.text('E.A.').last);
      await f.tap('Guardar');
      await f.top();
      await f.step(
        'Corregida a 25 % E.A.: la cuota, el total y la diferencia con el '
        'precio de contado se recalculan.',
      );
      await f.check('La tasa quedó en 25 % E.A. y la cuota bajó', () {
        expect(laptop().rate, 25);
        expect(laptop().rateKind, RateKind.effectiveAnnual);
        expect(laptop().payment!, lessThan(p.payment!));
      });
      await f.tapTip('Borrar compra');
      await f.step(
        '«¿Borrar Portátil?» aclara que se borran sus datos y pagos, pero no '
        'tus movimientos.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» la compra sigue', () {
        expect(own.instalments.length, plans + 1);
      });
      await f.tapTip('Borrar compra');
      await f.tap('Borrar compra');
      await f.step(
        'Borrada: la lista vuelve a tener el Celular y el Televisor.',
      );
      await f.check('El portátil ya no está', () {
        expect(own.instalments.length, plans);
        expect(
          own.instalments.any((Instalments p) => p.name == 'Portátil'),
          isFalse,
        );
      });
    },
  ),
  AppFlow(
    '06-18-pagar-una-compra-a-cuotas-sin-tasa',
    'Pagar una compra a cuotas sin saber la tasa',
    area: 'Plan',
    goal:
        'Saqué una nevera a crédito en la tienda y solo sé el valor de la '
        'cuota: quiero que la app la cuente y anotar lo que voy pagando.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      Instalments fridge() =>
          own.instalments.firstWhere((Instalments p) => p.name == 'Nevera');
      await _openPlan(f);
      await f.tap('Compras a cuotas');
      await f.tap('Agregar compra a cuotas');
      await f.type('¿Qué compraste?', 'Nevera');
      await f.type('Valor financiado', '1800000');
      await f.type('Número de cuotas', '6');
      await f.tapContaining('Primera cuota:');
      await f.tapTip('Mes anterior');
      await _pickDay(f, '10');
      await f.type('Valor de la cuota, si te lo dieron', '320000');
      await f.reveal(find.text('Guardar'));
      await f.step(
        'Nevera: 1.800.000 a 6 cuotas de 320.000 desde el 10 de octubre, sin '
        'tasa ni cuota de manejo, pagada fuera de Quincena.',
      );
      await f.tap('Guardar');
      await f.step(
        'En la lista, la nevera dice «estimado»: sin la cuota de manejo el '
        'total no es seguro.',
      );
      await f.check('La nevera quedó con la cuota del banco y sin tasa', () {
        final Instalments p = fridge();
        expect(p.instalment, l.minor(320000));
        expect(p.rate, isNull);
        expect(p.fee, isNull);
        expect(p.accountId, isNull);
        expect(p.totalKnown, isFalse);
      });
      await f.check(
        'La cuota del 10 de octubre cuenta como comprometida: lo que puedes '
        'gastar baja 320.000',
        () => expect(own.ledger!.freeUntilPayday, free - l.minor(320000)),
      );
      await f.tap('Nevera');
      await f.page(
        'El detalle dice «unos» 1.920.000: es un estimado. La tasa y la cuota '
        'de manejo figuran como «No la sabes».',
        most: 4,
      );
      await f.check('El total es estimado: 6 cuotas de 320.000', () {
        expect(fridge().total, l.minor(1920000));
        expect(
          f.shows(
            'En total pagarás unos ${pesos(1920000)}: es un estimado, porque '
            'falta la cuota de manejo o el seguro.',
          ),
          isTrue,
        );
      });
      final Account from = own.likelyPaymentAccount!;
      await f.tap('Registrar un pago');
      await f.step(
        '«Registrar un pago» propone la cuota, 320.000, con la fecha de hoy, '
        'y pregunta de dónde salió: viene elegida ${from.name}, la última '
        'cuenta que usaste. Abajo dice qué va a pasar antes de guardar.',
      );
      await f.check(
        'Antes de guardar dice cuánto quedará por pagar y qué cuenta baja',
        () => expect(
          f.screenText,
          contains('${from.name} baja ${pesos(320000)}.'),
        ),
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no se anota ningún pago', () {
        expect(fridge().payments, isEmpty);
      });
      await f.tap('Registrar un pago');
      await _typeInDialog(f, '');
      await f.tap('Guardar');
      await f.step('Sin valor, el pago avisa «Escribe cuánto pagaste.»');
      await _typeInDialog(f, '200000');
      await f.tap('Guardar');
      await f.page(
        'Un abono de 200.000 desde ${from.name}: «A la cuota 1 le faltan '
        '\$120.000» y el pago queda en «Pagos» con su caneca.',
        most: 3,
      );
      await f.check('Quedó un pago de 200.000 y a la cuota 1 le faltan '
          '120.000', () {
        expect(fridge().payments.single.$2, l.minor(200000));
        expect(fridge().progress, (0, l.minor(120000)));
      });
      final String paidWith = fridge().entryOf(0)!;
      await f.check(
        'El abono sale de ${from.name}: un movimiento de −200.000 en '
        'Créditos, ligado al pago',
        () {
          final Entry e = own.entryById(paidWith)!;
          expect(e.accountId, from.id);
          expect(e.amount, Decimal.parse('-200000'));
          expect(e.category, 'debt');
          expect(e.source, OwnController.planSource);
        },
      );
      await f.check(
        'Lo que puedes gastar no sube: la plata sale de ${from.name}, y esa '
        'cuota ya estaba comprometida',
        () => expect(own.ledger!.freeUntilPayday, free - l.minor(320000)),
      );
      await _tapTipBy(f, pesos(200000), 'Quitar este pago');
      await f.step(
        'La caneca pregunta antes: «¿Quitar este pago?», y avisa que también '
        'se borra su movimiento de \$200.000 en ${from.name}.',
      );
      await f.check('Dice que el movimiento se va con el pago', () {
        expect(
          f.screenText,
          contains(
            'También se borra su movimiento de ${pesos(200000)} en '
            '${from.name}.',
          ),
        );
      });
      await f.tap('Quitar pago');
      await f.check('Quitar el abono también quita su movimiento', () {
        expect(fridge().payments, isEmpty);
        expect(own.entryById(paidWith), isNull);
        expect(own.ledger!.freeUntilPayday, free - l.minor(320000));
      });
      await f.top();
      await f.tap('Registrar un pago');
      await f.tapFound(find.text(dayMonth(own.today)).last);
      await _pickDay(f, '1');
      await f.tap('Guardar');
      await f.page(
        'Con la cuota completa, pagada el 1 de octubre desde ${from.name}: '
        '«Llevas 1 de 6 cuotas» y la primera queda marcada como pagada en el '
        'calendario.',
        most: 4,
      );
      await f.check('Una cuota cubierta el 1 de octubre, quedan 1.600.000', () {
        expect(fridge().payments.single.$1, DateTime(2026, 10, 1));
        expect(fridge().progress.$1, 1);
        expect(fridge().remaining, l.minor(1600000));
        expect(f.shows('Llevas 1 de 6 cuotas'), isTrue);
      });
      await f.check(
        'Pagada la del 10 de octubre, lo que puedes gastar no cambia: esa '
        'plata ya estaba comprometida, y ahora salió de ${from.name}',
        () {
          expect(own.ledger!.freeUntilPayday, free - l.minor(320000));
          expect(own.entryById(fridge().entryOf(0)!)!.accountId, from.id);
        },
      );
    },
  ),
  AppFlow(
    '06-19-dividir-gastos-en-un-grupo',
    'Dividir gastos en un grupo',
    area: 'Plan',
    goal:
        'Comparto apartamento con Ana y Juan: quiero anotar el mercado y el '
        'internet, cada uno con su parte, y saber quién le debe a quién.',
    data: seeded,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      Group flat() => own.groups.single;
      String idOf(String name) =>
          flat().members.firstWhere((Member m) => m.name == name).id;
      await _openPlan(f);
      await f.tap('Gastos compartidos');
      await f.tap('Nuevo grupo');
      await f.tap('Guardar');
      await f.step(
        '«Nuevo grupo» sin datos: avisa «Falta el nombre o alguien más en el '
        'grupo.» Tú ya estás en él.',
      );
      await f.check('Sin nombre ni personas no se crea ningún grupo', () {
        expect(own.groups, isEmpty);
      });
      await f.type('Nombre del grupo', 'Apartamento');
      await f.type('Agregar personas', 'Ana, Juan, ana');
      await f.tap('Guardar');
      await f.step(
        'El grupo queda en la lista con Tú, Ana y Juan, «A paz y salvo». Ana '
        'escrita dos veces queda una sola.',
      );
      await f.check('El grupo tiene tres personas, sin repetir a Ana', () {
        expect(flat().name, 'Apartamento');
        expect(flat().members.map((Member m) => m.name), <String>[
          '',
          'Ana',
          'Juan',
        ]);
      });
      await f.tap('Apartamento');
      await f.tap('Agregar gasto');
      await f.type('¿Qué fue?', 'Mercado');
      await f.type('Valor total', '100000');
      final Account from = own.likelyPaymentAccount!;
      await f.step(
        '«Agregar gasto» en partes iguales: 33.334 para ti y 33.333 para Ana y '
        'Juan; el peso del redondeo queda en tu parte. Como pagaste tú, '
        'pregunta de dónde salió: viene elegida ${from.name}.',
      );
      await f.check('Las tres partes suman los 100.000', () {
        expect(
          f.shows(
            'Para que el total cuadre, los ${pesos(1)} del redondeo quedan en '
            'tu parte.',
          ),
          isTrue,
        );
        expect(f.shows(pesos(33334)), isTrue);
      });
      await f.tap('Por montos');
      await f.type('Tu parte', '50000');
      await f.type('Parte de Ana', '30000');
      await f.step(
        '«Por montos» deja escribir cada parte; con 50.000 y 30.000 avisa '
        '«Faltan \$20.000 para el total».',
      );
      await f.type('Parte de Juan', '30000');
      await f.tap('Guardar');
      await f.step(
        'Con 30.000 para Juan sobran 10.000, y «Guardar» avisa «Las partes no '
        'suman el total.»',
      );
      await f.check('Si las partes no suman, no se guarda nada', () {
        expect(flat().expenses, isEmpty);
      });
      await f.type('Parte de Juan', '20000');
      await f.tap('Guardar');
      await f.page(
        '«En este grupo te deben \$50.000»: Ana te paga 30.000 y Juan 20.000, '
        'cada uno con «Recordar» y «Registrar pago».',
        most: 2,
      );
      await f.check('Ana te debe 30.000 y Juan 20.000', () {
        expect(flat().balances[meId], 50000);
        expect(flat().balances[idOf('Ana')], -30000);
        expect(flat().balances[idOf('Juan')], -20000);
        expect(own.sharedBalance, (50000, 0));
      });
      await f.check(
        'El mercado sale de ${from.name}: lo que puedes gastar baja los '
        '100.000 que pagaste, y de gasto solo cuentan tus 50.000',
        () {
          final String paid = flat().expenses.single.entryId!;
          final Entry e = own.entryById(paid)!;
          expect(e.accountId, from.id);
          expect(e.amount, Decimal.parse('-100000'));
          expect(own.ledger!.freeUntilPayday, free - 100000);
          // What Ana and Juan owe of it is set aside, not spent.
          final Iterable<Movement> mine = own.ledger!.movements.where(
            (Movement m) => m.id == paid || m.id == '$paid#shared',
          );
          expect(
            mine.map((Movement m) => (m.amount, m.flow)),
            unorderedEquals(<(int, Flow)>[
              (50000, Flow.expense),
              (50000, Flow.saving),
            ]),
          );
        },
      );
      await f.tap('Agregar gasto');
      await f.type('¿Qué fue?', 'Internet');
      await f.tap('Guardar');
      await f.check(
        'Sin valor avisa «Falta el valor o con quién dividirlo.»',
        () {
          expect(f.shows('Falta el valor o con quién dividirlo.'), isTrue);
          expect(flat().expenses, hasLength(1));
        },
      );
      await f.type('Valor total', '90000');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Ana').last);
      await f.tapFound(find.text(dayMonth(own.today)).last);
      await _pickDay(f, '1');
      await _tapNear(f, 'Juan', find.byType(Checkbox));
      await f.step(
        'El internet lo pagó Ana el 1 de octubre y es solo entre ella y tú: '
        'sin la marca de Juan, 45.000 cada uno.',
      );
      await f.tap('Guardar');
      await f.page(
        'Ahora te deben 5.000. La app simplifica las deudas: Juan le paga '
        '15.000 a Ana y 5.000 a ti.',
        most: 2,
      );
      await f.check('Tu saldo en el grupo queda en 5.000 a favor', () {
        expect(
          flat().expenses
              .firstWhere((SharedExpense e) => e.label == 'Internet')
              .date,
          DateTime(2026, 10, 1),
        );
        expect(flat().balances[meId], 5000);
        expect(flat().balances[idOf('Ana')], 15000);
        expect(flat().balances[idOf('Juan')], -20000);
      });
      await f.tap('Internet');
      await f.reveal(find.text('Quitar la división'));
      await f.step(
        'Al abrir el internet aparece «Quitar la división» para sacarlo del '
        'grupo.',
      );
      await f.tap('Quitar la división');
      await f.check('Sin el internet, te vuelven a deber 50.000', () {
        expect(flat().expenses.map((SharedExpense e) => e.label), <String>[
          'Mercado',
        ]);
        expect(flat().balances[meId], 50000);
      });
      await f.tapTip('Editar grupo');
      await f.type('Nombre del grupo', 'Apto 301');
      await f.type('Agregar personas', 'Pedro');
      await f.step(
        '«Editar grupo»: Ana y Juan tienen gastos, así que no se pueden '
        'quitar; se cambia el nombre y se agrega a Pedro.',
      );
      await f.tap('Guardar');
      await f.check('El grupo se llama Apto 301 y Pedro está en él', () {
        expect(flat().name, 'Apto 301');
        expect(flat().members.map((Member m) => m.name), contains('Pedro'));
      });
      await f.tapTip('Editar grupo');
      await f.step(
        'Pedro todavía no tiene gastos: su nombre trae al lado el botón para '
        'quitarlo; Tú, Ana y Juan no.',
      );
      await _tapTipBy(f, 'Pedro', 'Eliminar');
      await f.tap('Guardar');
      await f.check('Pedro ya no está en el grupo', () {
        expect(
          flat().members.map((Member m) => m.name),
          isNot(contains('Pedro')),
        );
      });
      await f.tapTip('Borrar grupo');
      await f.step(
        '«¿Borrar Apto 301?» aclara que se borran sus gastos y pagos aquí, no '
        'tus movimientos.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el grupo sigue', () {
        expect(own.groups, hasLength(1));
      });
      await f.tapTip('Borrar grupo');
      await f.tap('Borrar grupo');
      await f.step('Borrado: «Gastos compartidos» vuelve a estar vacío.');
      await f.check('Ya no hay grupos ni nada que te deban', () {
        expect(own.groups, isEmpty);
        expect(own.sharedBalance, (0, 0));
      });
    },
  ),
  AppFlow(
    '06-20-anotar-lo-que-preste-y-me-prestaron',
    'Anotar lo que presté y lo que me prestaron',
    area: 'Plan',
    goal:
        'Le presté a Pedro de mi Nequi y mi mamá me prestó: quiero que la app '
        'lo lleve sin contarlo como gasto ni como ingreso.',
    data: seeded,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int spent = spentThisPeriod(l);
      final int entries = own.snapshot!.entries.length;
      await _openPlan(f);
      await f.tap('Gastos compartidos');
      await f.tap('Le presté');
      await f.tap('Guardar');
      await f.step(
        '«Le presté plata a alguien» sin datos: avisa «Falta a quién o el '
        'monto.»',
      );
      await f.type('¿A quién?', 'Pedro');
      await f.type('Monto', '80000');
      await f.type('¿Para qué? (opcional)', 'Mercado');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.tapFound(find.text('Nequi').last);
      await f.tapFound(find.text(dayMonth(own.today)).last);
      await _pickDay(f, '2');
      await f.step(
        'Pedro, 80.000 para el mercado, salidos de Nequi el 2 de octubre. '
        'Abajo aclara que queda como plata que te deben, no como gasto.',
      );
      await f.tap('Guardar');
      await f.step(
        'Aparece el grupo «Pedro» con «Te deben \$80.000», y arriba «Te '
        'deben» suma lo mismo.',
      );
      await f.check(
        'En Nequi quedó la salida de 80.000, ligada al préstamo',
        () {
          final Entry e = own.snapshot!.entries.firstWhere(
            (Entry e) => e.payee == 'Pedro',
          );
          expect(own.snapshot!.account(e.accountId)!.name, 'Nequi');
          expect(e.amount, Decimal.fromInt(-80000));
          expect(e.note, 'Mercado');
          expect(e.date, DateTime(2026, 10, 2));
          expect(own.groups.single.expenses.single.entryId, e.id);
        },
      );
      await f.check(
        'Lo prestado sale de lo que puedes gastar, pero no cuenta como gasto',
        () {
          expect(own.ledger!.freeUntilPayday, free - l.minor(80000));
          expect(spentThisPeriod(own.ledger!), spent);
        },
      );
      final Account into = own.likelyPaymentAccount!;
      await f.tap('Me prestaron');
      await f.type('¿Quién te prestó?', 'Mamá');
      await f.type('Monto', '300000');
      await f.step(
        '«Alguien me prestó plata» pregunta a qué cuenta llegó: viene elegida '
        '${into.name}. Abajo dice que queda como plata que debes.',
      );
      await f.tap('Guardar');
      await f.step(
        'Ahora hay dos grupos: Pedro te debe 80.000 y a Mamá le debes '
        '300.000.',
      );
      await f.check('Te deben 80.000 y debes 300.000', () {
        expect(own.sharedBalance, (80000, 300000));
      });
      await f.check(
        'Lo que te prestaron llega a ${into.name} y no cuenta como ingreso',
        () {
          expect(own.snapshot!.entries.length, entries + 2);
          final Entry e = own.snapshot!.entries.firstWhere(
            (Entry e) => e.payee == 'Mamá',
          );
          expect(e.accountId, into.id);
          expect(e.amount, Decimal.fromInt(300000));
          expect(
            own.ledger!.movements
                .firstWhere((Movement m) => m.id == '${e.id}#shared')
                .flow,
            Flow.transferIn,
          );
          // The money is there to spend, and owed: Plan says so.
          expect(
            own.ledger!.freeUntilPayday,
            free - l.minor(80000) + l.minor(300000),
          );
        },
      );
      await f.tap('Le presté');
      await f.type('¿A quién?', 'pedro');
      await f.type('Monto', '20000');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.tapFound(find.text('No salió de mis cuentas').last);
      await f.tap('Guardar');
      await f.step(
        'Otros 20.000 a «pedro», en efectivo de fuera: van al mismo grupo, que '
        'ahora dice «Te deben \$100.000».',
      );
      await f.check('Siguen dos grupos y Pedro debe 100.000', () {
        expect(own.groups, hasLength(2));
        expect(own.sharedBalance, (100000, 300000));
        expect(own.snapshot!.entries.length, entries + 2);
      });
      await f.back();
      await f.reveal(find.text('Gastos compartidos'));
      await f.step(
        'En Plan, la fila dice «Te deben \$100.000 · debes \$300.000».',
      );
      await f.check('La fila de Plan dice lo mismo', () {
        expect(
          _says(f, 'Te deben ${pesos(100000)} · debes ${pesos(300000)}'),
          isTrue,
        );
      });
    },
  ),
  AppFlow(
    '06-21-quedar-a-paz-y-salvo',
    'Quedar a paz y salvo',
    area: 'Plan',
    goal:
        'Pedro ya me devolvió por Nequi y yo le debo a Camilo el hotel: '
        'quiero anotar los dos pagos y ver cómo quedan las cuentas.',
    data: _planAccount,
    manual: <String>[
      '«Recordar» abre la hoja de compartir del teléfono con el mensaje para '
          'Pedro.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Entry back = own.snapshot!.entries.firstWhere(
        (Entry e) => e.payee == 'Pedro te envió',
      );
      // A phone whose share sheet did not open: the message is copied.
      final List<String> shared = _shares(f, sheet: false);
      await _openPlan(f);
      await f.tap('Gastos compartidos');
      await f.step(
        'Dos grupos: en el paseo a Guatapé debes 170.000 y Pedro te debe '
        '50.000 de un préstamo.',
      );
      await f.tap('Pedro');
      await f.tap('Recordar');
      await f.step(
        'En el grupo de Pedro: «Pedro te paga \$50.000». «Recordar» prepara '
        'un mensaje; sin la hoja de compartir, lo copia.',
      );
      await f.check(
        'El mensaje para Pedro, con los ${pesos(50000)}, quedó copiado',
        () {
          expect(find.textContaining('Mensaje copiado'), findsOneWidget);
          expect(shared.single, startsWith('Hola, Pedro.'));
          expect(shared.single, contains(pesos(50000)));
        },
      );
      await f.tap('Registrar pago');
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no se anota ningún pago', () {
        expect(own.group('group-pedro')!.settlements, isEmpty);
      });
      await f.tap('Registrar pago');
      await f.step(
        '«Pedro te pagó» con 50.000 y hoy; en «¿Llegó a una de tus cuentas?» '
        'ya viene elegido lo que llegó a Nequi, «Pedro te envió», porque '
        'coinciden el nombre y el valor. Abajo: «Pedro queda a paz y salvo '
        'contigo.»',
      );
      await f.check('Antes de guardar dice que Pedro queda a paz y salvo', () {
        expect(f.screenText, contains('Pedro queda a paz y salvo contigo.'));
      });
      await f.tap('Guardar');
      await f.page(
        '«Todos están a paz y salvo»: el pago queda en «Pagos» con «llegó a '
        'Nequi».',
        most: 2,
      );
      await f.check('El grupo de Pedro quedó en cero y el pago ligado', () {
        final Group g = own.group('group-pedro')!;
        expect(g.balances[meId], 0);
        expect(g.settlements.single.entryId, back.id);
      });
      await f.check(
        'Lo que llegó a Nequi cuenta como plata que vuelve, no como ingreso',
        () {
          final Movement m = own.ledger!.movements.firstWhere(
            (Movement m) => m.id.startsWith(back.id),
          );
          expect(m.flow, Flow.transferIn);
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      await _tapTipBy(f, 'Pedro te pagó', 'Quitar este pago');
      await f.step('La caneca quita el pago: Pedro vuelve a deberte 50.000.');
      await f.check('Sin el pago, Pedro debe otra vez 50.000', () {
        expect(own.group('group-pedro')!.balances[meId], 50000);
      });
      await f.back();
      await f.tap('Paseo a Guatapé');
      await f.page(
        'En Guatapé debes 170.000: «Laura le paga a Camilo» y «Le pagas a '
        'Camilo», con los gastos y el pago de Laura abajo.',
        most: 3,
      );
      final int mine = own.group(guatape)!.balances[meId]!;
      await _tapTextBy(
        f,
        'Laura le paga a Camilo ${pesos(200000)}',
        'Registrar pago',
      );
      await f.tapFound(find.text(dayMonth(own.today)).last);
      await _pickDay(f, '1');
      await f.step(
        'Entre otros dos también se anota: «Laura le pagó a Camilo» '
        '200.000 el 1 de octubre. No pregunta por tus cuentas: no es tu plata.',
      );
      await f.tap('Guardar');
      await f.check(
        'Quedó el pago de Laura a Camilo y tu saldo en el grupo no cambia',
        () {
          final Group g = own.group(guatape)!;
          final Settlement s = g.settlements.last;
          expect(s.amount, 200000);
          expect(s.date, DateTime(2026, 10, 1));
          expect(s.entryId, isNull);
          expect(
            g.members.firstWhere((Member m) => m.id == s.from).name,
            'Laura',
          );
          expect(
            g.members.firstWhere((Member m) => m.id == s.to).name,
            'Camilo',
          );
          expect(g.balances[meId], mine);
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      final Account from = own.likelyPaymentAccount!;
      await f.tapFound(find.text('Registrar pago').last);
      await _typeInDialog(f, '100000');
      await f.step(
        '«Le pagaste a Camilo» propone los 170.000; se cambia a un abono de '
        '100.000 que sale de ${from.name}, la cuenta que viene elegida. Abajo '
        'dice que le seguirás debiendo \$70.000 a Camilo y que ${from.name} '
        'baja \$100.000.',
      );
      await f.check('Antes de guardar dice lo que queda y qué cuenta baja', () {
        expect(
          f.screenText,
          contains(
            'Le seguirás debiendo ${pesos(70000)} a Camilo. ${from.name} baja '
            '${pesos(100000)}.',
          ),
        );
      });
      await f.tap('Guardar');
      await f.top();
      await f.step(
        'Con el abono, «En este grupo debes \$70.000», y el pago dice «salió '
        'de ${from.name}».',
      );
      await f.check('Ahora le debes 70.000 a Camilo', () {
        expect(own.group(guatape)!.balances[meId], -70000);
        expect(own.sharedBalance, (50000, 70000));
      });
      await f.check(
        'Los 100.000 salen de ${from.name} y cuentan como gasto: son tu parte '
        'del paseo',
        () {
          final Entry e = own.entryById(
            own.group(guatape)!.settlements.last.entryId!,
          )!;
          expect(e.accountId, from.id);
          expect(e.amount, Decimal.fromInt(-100000));
          expect(
            own.ledger!.movements.firstWhere((Movement m) => m.id == e.id).flow,
            Flow.expense,
          );
          expect(own.ledger!.freeUntilPayday, free - 100000);
        },
      );
      await f.back();
      await f.back();
      await f.reveal(find.text('Gastos compartidos'));
      await f.step(
        'La fila de Plan lo resume: «Te deben \$50.000 · debes \$70.000».',
      );
      await f.check('La fila de Plan dice lo que queda en los dos grupos', () {
        expect(
          _says(f, 'Te deben ${pesos(50000)} · debes ${pesos(70000)}'),
          isTrue,
        );
      });
    },
  ),
  AppFlow(
    '06-22-revisar-cargos-raros',
    'Revisar los cargos raros',
    area: 'Plan',
    goal:
        'Quiero saber si me cobraron algo dos veces o de más, decidir qué '
        'hago con cada aviso y apagar los que no me sirven.',
    data: _withUnusual,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      ChargeAlert alert(AlertKind kind, String payee) =>
          own.allAlerts.firstWhere(
            (ChargeAlert a) => a.kind == kind && a.evidence.last.payee == payee,
          );
      await _openPlan(f);
      await f.reveal(find.text('Cargos para revisar'));
      await f.step(
        'En Plan, «Cargos para revisar» cuenta 3: los avisos que nadie ha '
        'mirado todavía.',
      );
      await f.check('La fila cuenta los 3 avisos abiertos', () {
        expect(f.shows('3 cargos para revisar'), isTrue);
      });
      await f.tap('Cargos para revisar');
      await f.page(
        'Tres avisos con su evidencia: el Éxito visto dos veces, Fit24 «cobra '
        'más que antes» y una comida de 420.000.',
        most: 6,
      );
      await f.check('Hay un aviso de cada tipo: repetido, subida y fuera de '
          'lo común', () {
        expect(
          own.alerts.map((ChargeAlert a) => a.kind).toList(),
          unorderedEquals(AlertKind.values),
        );
      });
      await f.check(
        'Tres compras en el Éxito el mismo día, una repetida, no son una '
        'subida de precio',
        () => expect(
          own.alerts.where(
            (ChargeAlert a) =>
                a.kind == AlertKind.priceUp &&
                a.evidence.last.payee == 'Éxito Laureles',
          ),
          isEmpty,
        ),
      );
      final String twice = own.alerts
          .firstWhere((ChargeAlert a) => a.kind == AlertKind.twice)
          .id;
      await _tapTextBy(
        f,
        'Puede ser el mismo pago visto dos veces',
        'Lo voy a revisar',
      );
      await f.reveal(find.text('LO VAS A REVISAR'));
      await f.step(
        '«Lo voy a revisar» pasa el pago repetido a «Lo vas a revisar», con '
        '«Es esperado» y «Descartar» todavía a mano.',
      );
      await f.check('El pago repetido quedó para revisar', () {
        expect(own.detective.answers[twice], AlertAnswer.review);
      });
      final String gym = alert(AlertKind.priceUp, 'Fit24').id;
      await _tapTextBy(f, 'Fit24 cobra más que antes', 'Es esperado');
      final String meal = alert(AlertKind.unusual, 'Andrés Carne de Res').id;
      await _tapTextBy(f, 'Mucho más de lo usual en Restaurantes', 'Descartar');
      await f.reveal(find.text('Ver las 2 que marcaste'));
      await f.step(
        'Fit24 «Es esperado» y la comida descartada se van de la lista; '
        'aparece «Ver las 2 que marcaste».',
      );
      await f.check('Fit24 quedó como esperado y la comida descartada', () {
        expect(own.detective.answers[gym], AlertAnswer.expected);
        expect(own.detective.answers[meal], AlertAnswer.dismissed);
        expect(own.alerts.map((ChargeAlert a) => a.id), isNot(contains(gym)));
      });
      await f.tap('Ver las 2 que marcaste');
      await f.reveal(find.text('Volver a mostrar'));
      await f.step(
        'Las que marcaste vuelven a verse, cada una con «Volver a mostrar».',
      );
      await _tapTextBy(f, 'Fit24 cobra más que antes', 'Volver a mostrar');
      await f.check('Con «Volver a mostrar» Fit24 vuelve a estar abierta', () {
        expect(own.detective.answers[gym], isNull);
      });
      await f.tap('Ocultar las que marcaste');
      await f.tap('Cargos fuera de lo común');
      await f.tap('Pagos repetidos');
      await f.reveal(find.text('Pagos repetidos'));
      await f.step(
        'Con «Pagos repetidos» y «Cargos fuera de lo común» apagados solo '
        'queda el aviso de Fit24; el del Éxito repetido se fue de la lista.',
      );
      await f.check('Apagados, esos dos tipos dejan de avisar', () {
        expect(own.detective.muted, <AlertKind>{
          AlertKind.twice,
          AlertKind.unusual,
        });
        expect(own.alerts.map((ChargeAlert a) => a.kind), <AlertKind>[
          AlertKind.priceUp,
        ]);
      });
      await f.tap('Cargos fuera de lo común');
      await f.tap('Pagos repetidos');
      await f.tap('Subidas de precio');
      await f.reveal(find.text('Subidas de precio'));
      await f.step(
        'Encendidos otra vez los dos, y con «Subidas de precio» apagado, Fit24 '
        'deja de avisar y vuelve el Éxito repetido.',
      );
      await f.check('Las subidas de precio quedaron en silencio', () {
        expect(own.detective.muted, <AlertKind>{AlertKind.priceUp});
        expect(
          own.alerts.where((ChargeAlert a) => a.kind == AlertKind.priceUp),
          isEmpty,
        );
        expect(own.alerts.map((ChargeAlert a) => a.id), contains(twice));
      });
      await f.top();
      await f.tapFound(find.text('EXITO LAURELES').first);
      await f.step(
        'Tocar «EXITO LAURELES», el del extracto, abre el movimiento: desde '
        'ahí se borra el que sobra.',
      );
      await f.tap('Eliminar');
      await f.tap('Eliminar');
      await f.step(
        'Borrado el repetido, el aviso desaparece: no queda nada abierto.',
      );
      await f.check('El aviso de pago repetido ya no está', () {
        expect(own.alerts.map((ChargeAlert a) => a.id), isNot(contains(twice)));
        expect(
          own.snapshot!.entries.any((Entry e) => e.payee == 'EXITO LAURELES'),
          isFalse,
        );
      });
      await f.check(
        'Sin el cobro repetido, lo que puedes gastar sube 63.200',
        () => expect(
          own.ledger!.freeUntilPayday,
          free + own.ledger!.minor(63200),
        ),
      );
      await f.back();
      await f.reveal(find.text('Cargos para revisar'));
      await f.step('En Plan, la fila dice «Nada raro por ahora».');
      await f.check('La fila de Plan ya no cuenta avisos', () {
        expect(f.shows('Nada raro por ahora'), isTrue);
      });
    },
  ),
  AppFlow(
    '06-23-ver-los-proximos-30-dias',
    'Ver los próximos 30 días',
    area: 'Plan',
    goal:
        'Quiero ver día por día cómo va a quedar mi plata hasta el pago y '
        'probar qué pasa si Netflix me cobra más tarde.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final DateTime netflix = own.recurring.single.nextDate;
      final Projection p = Projection.of(l, horizon: 30);
      final ProjectedDay low = p.lowestBeforePayday;
      await _openPlan(f);
      await f.tap('Próximos 30 días');
      await f.page(
        '«Próximos 30 días»: lo mínimo libre antes del pago y, aparte, lo que '
        'sigue guardado en la reserva; la gráfica con lo seguro, lo probable '
        'y la línea de lo apartado; y debajo cada día con sus cobros.',
        most: 3,
      );
      await f.check('Lo mínimo libre dice ${_pesos(l, p.free(low))} el '
          '${dayShortMonth(low.date)}, contado como «Puedes gastar»', () {
        expect(p.free(low), l.freeUntilPayday);
        expect(
          _says(
            f,
            'Lo mínimo libre antes del pago: ${_pesos(l, p.free(low))} el '
            '${dayShortMonth(low.date)}',
          ),
          isTrue,
        );
      });
      await f.tapFound(find.text(weekdayDayMonth(netflix)).last);
      await f.top();
      await f.step(
        'Al tocar el día de Netflix, ese día sube debajo de la gráfica, '
        'resaltado, con lo que queda después del cobro.',
      );
      await f.check('El día de Netflix quedó arriba de los demás', () {
        expect(
          f.tester.getTopLeft(find.text('Netflix')).dy,
          lessThan(f.tester.getTopLeft(find.text('Televisor')).dy),
        );
      });
      await _tapTipBy(f, 'Netflix', 'Mover en la simulación');
      await f.step(
        'El calendario de Netflix abre en su día, el 12; se elige el 20 para '
        'ver qué cambia.',
      );
      await _pickDay(f, '20');
      await f.top();
      await f.step(
        'Arriba avisa «Estás probando: nada de esto se guarda ni cambia tus '
        'pagos.» con «Quitar lo que pruebas».',
      );
      await f.check('Mover a Netflix en la simulación no cambia su cobro', () {
        expect(f.shows('Quitar lo que pruebas'), isTrue);
        expect(own.recurring.single.nextDate, netflix);
        expect(own.ledger!.freeUntilPayday, l.freeUntilPayday);
      });
      await f.tap('Quitar lo que pruebas');
      await f.check('«Quitar lo que pruebas» borra la simulación', () {
        expect(f.shows('Quitar lo que pruebas'), isFalse);
      });
      // The last day of the chart, at its right end.
      final Rect chart = f.tester.getRect(find.byType(ComingChart));
      await f.tester.tapAt(Offset(chart.right - 2, chart.center.dy));
      await f.tester.pumpAndSettle();
      final DateTime last = l.today.add(const Duration(days: 30));
      await f.step(
        'Tocar la gráfica también elige un día: en su punta derecha queda el '
        '${dayMonth(last)}, sin cobros, con lo que queda ese día.',
      );
      await f.check('El día elegido en la gráfica es el ${dayMonth(last)}', () {
        expect(f.shows(weekdayDayMonth(last)), isTrue);
      });
      await f.tapTip('Cierre de la quincena');
      await f.step(
        'El ícono de arriba abre «Cierre de la quincena», el resumen del '
        'periodo.',
      );
      await f.back();
    },
  ),
  AppFlow(
    '06-24-saber-si-me-alcanza',
    'Saber si me alcanza para algo',
    area: 'Plan',
    goal:
        'Quiero unos zapatos: saber si me alcanza hoy, si me quedo sin '
        'colchón, o si es mejor esperar al pago.',
    data: _withPay,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int entries = own.snapshot!.entries.length;
      PurchaseCheck check(int price, DateTime on) => checkPurchase(
        own.ledger!,
        price: l.minor(price),
        date: on,
        label: 'Zapatos',
        atLeast: 30,
      );
      await _openPlan(f);
      await f.tap('Próximos 30 días');
      await f.tap('¿Me alcanza?');
      await f.step(
        '«¿Me alcanza?» pide el precio, qué es y cuándo: hoy, después del '
        'pago u otra fecha. La gráfica sigue abajo.',
      );
      await f.type('¿Cuánto cuesta?', '100000');
      await f.type('¿Qué es? (opcional)', 'Zapatos');
      final PurchaseCheck small = check(100000, l.today);
      await f.step(
        'Zapatos de 100.000 hoy: «Te alcanza», con lo mínimo que te '
        'quedaría libre después del colchón, y la comparación con esperar.',
      );
      final int smallFree = small.lowest - small.projection.kept;
      await f.check(
        'Te alcanza: te quedarían mínimo ${_pesos(l, smallFree)} libres, '
        'contados como «Puedes gastar»',
        () {
          expect(small.verdict, PurchaseVerdict.fits);
          expect(f.shows('Te alcanza, según lo que sabe la app'), isTrue);
          expect(
            _says(f, 'Te quedarían mínimo ${_pesos(l, smallFree)} libres'),
            isTrue,
          );
        },
      );
      await f.type('¿Cuánto cuesta?', '250000');
      final PurchaseCheck mid = check(250000, l.today);
      await f.step(
        'Con 250.000 quedarías por debajo del colchón de 200.000: el aviso '
        'cambia a color de alerta.',
      );
      await f.check('Por debajo del colchón: el saldo más bajo sería '
          '${_pesos(l, mid.lowest)}', () {
        expect(mid.verdict, PurchaseVerdict.belowCushion);
        expect(f.shows('Quedarías por debajo de tu colchón'), isTrue);
      });
      await f.type('¿Cuánto cuesta?', '500000');
      final PurchaseCheck big = check(500000, l.today);
      await f.step(
        'Con 500.000 hoy «No alcanza antes del pago» y dice cuánto faltaría; '
        'la comparación muestra que esperando sí alcanza.',
      );
      await f.check('No alcanza: faltarían ${_pesos(l, -big.lowest)}', () {
        expect(big.verdict, PurchaseVerdict.short);
        expect(f.shows('No alcanza antes del pago'), isTrue);
        expect(_says(f, _pesos(l, -big.lowest)), isTrue);
      });
      await f.tap('Después del pago');
      final PurchaseCheck after = check(
        500000,
        l.nextPayday.add(const Duration(days: 1)),
      );
      await f.step(
        '«Después del pago» sí alcanza, y aclara que cuenta con tu pago de '
        '2.400.000 del 15, que todavía no llega.',
      );
      await f.check('Después del pago alcanza, contando con el pago', () {
        expect(after.verdict, PurchaseVerdict.fits);
        expect(after.reliesOnPay, isTrue);
        expect(
          f.shows(
            'Cuenta con tu pago de ${pesos(2400000)} del '
            '${dayShortMonth(l.nextPayday)}, que todavía no llega.',
          ),
          isTrue,
        );
      });
      await f.tap('Otra fecha');
      await _pickDay(f, '25');
      await f.step(
        '«Otra fecha» abre el calendario; con el 25 de octubre el botón dice '
        'la fecha y el veredicto se rehace.',
      );
      await f.check('La compra el 25 de octubre también alcanza', () {
        expect(
          check(500000, DateTime(2026, 10, 25)).verdict,
          PurchaseVerdict.fits,
        );
        expect(f.shows(dayShortMonth(DateTime(2026, 10, 25))), isTrue);
      });
      await f.tap('Después del pago');
      await f.tap('Otra fecha');
      await _pickDay(f, '${l.nextPayday.day}');
      final PurchaseCheck onPayday = check(500000, l.nextPayday);
      await f.step(
        'Con el ${dayShortMonth(l.nextPayday)}, el mismo día del pago, '
        'también alcanza: cuenta con el pago de ese día, como «Después del '
        'pago», en vez de mirar la quincena siguiente sin ningún pago.',
      );
      await f.check(
        'El mismo día del pago cuenta con ese pago: alcanza, y te quedarían '
        'mínimo ${_pesos(l, onPayday.lowest - onPayday.projection.kept)} '
        'libres',
        () {
          expect(onPayday.verdict, PurchaseVerdict.fits);
          expect(onPayday.reliesOnPay, isTrue);
          expect(onPayday.lowest, after.lowest);
          expect(f.shows(dayShortMonth(l.nextPayday)), isTrue);
          expect(f.shows('Te alcanza, según lo que sabe la app'), isTrue);
          expect(
            _says(
              f,
              'Te quedarían mínimo '
              '${_pesos(l, onPayday.lowest - onPayday.projection.kept)} '
              'libres',
            ),
            isTrue,
          );
          expect(
            f.shows(
              'Cuenta con tu pago de ${pesos(2400000)} del '
              '${dayShortMonth(l.nextPayday)}, que todavía no llega.',
            ),
            isTrue,
          );
        },
      );
      await f.back();
      await f.check('Probar una compra no anota nada', () {
        expect(own.snapshot!.entries.length, entries);
        expect(own.ledger!.freeUntilPayday, l.freeUntilPayday);
      });
    },
  ),
  AppFlow(
    '06-25-probar-escenarios-y-si',
    'Probar escenarios con «¿Y si…?»',
    area: 'Plan',
    goal:
        'Quiero ver qué pasa si ahorro más cada quincena, si Netflix sube o '
        'si el pago me llega tarde, sin cambiar nada todavía.',
    data: _withPayAndHistory,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final GoalShare trip = own.goalShares.single;
      await _openPlan(f);
      await f.tap('¿Y si…?');
      await f.step(
        '«¿Y si…?» abre en «Ahorro más»: pide cuánto más apartarías en cada '
        'pago.',
      );
      await f.type('¿Cuánto más en cada pago?', '100000');
      final Scenario saveMore = Scenario(
        id: 'save-${l.minor(100000)}',
        kind: ScenarioKind.saveMore,
        amount: l.minor(100000),
      );
      // What the day to day usually takes counts too, as the page says.
      final int daily = usualDailySpending(l) ?? 0;
      final ScenarioOutcome saving = weighScenario(l, saveMore, daily: daily);
      final DateTime sooner = arrival(
        trip,
        from: own.today,
        monthly: trip.monthly + (l.minor(100000) * paydaysPerMonth(l)).round(),
      )!;
      await f.page(
        'Con 100.000 más por pago compara el saldo mínimo, el primer día bajo '
        'el colchón y lo que tendrías al 17 de noviembre, contando lo que '
        'sueles gastar en el día a día; el viaje llega en '
        '${monthYear(sooner)}.',
        most: 2,
      );
      await f.check('El saldo mínimo en 45 días pasa de '
          '${_pesos(l, saving.lowestNow.likely)} a '
          '${_pesos(l, saving.lowestTried.likely)}', () {
        expect(
          _says(
            f,
            'Hoy: ${_pesos(l, saving.lowestNow.likely)} · '
            '${dayShortMonth(saving.lowestNow.date)}',
          ),
          isTrue,
        );
        expect(
          _says(
            f,
            'Con el cambio: ${_pesos(l, saving.lowestTried.likely)} · '
            '${dayShortMonth(saving.lowestTried.date)}',
          ),
          isTrue,
        );
      });
      await f.check(
        'La meta llega en ${monthYear(sooner)} en vez de '
        '${monthYear(arrival(trip, from: own.today)!)}',
        () => expect(_says(f, 'Con el cambio: ${monthYear(sooner)}'), isTrue),
      );
      await f.reveal(find.textContaining('gasto del día a día').last);
      await f.check(
        'Cuenta unos ${_pesos(l, daily)} al día de gasto del día a día, y lo '
        'dice',
        () {
          expect(daily, l.minor(15000));
          expect(
            _says(f, 'unos ${_pesos(l, daily)} al día de gasto del día a día'),
            isTrue,
          );
        },
      );
      await f.tap('Guardar el escenario');
      await f.check('El escenario quedó guardado y no cambió nada más', () {
        expect(own.scenarios.map((Scenario s) => s.id), <String>[saveMore.id]);
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.tap('Sube un gasto');
      await f.tap('Netflix');
      await f.type('¿Cuánto sube?', '5000');
      await f.step(
        '«Sube un gasto» ofrece los cobros que vienen; con Netflix y 5.000 '
        'más compara igual, y además ofrece «Aplicar».',
      );
      await f.tap('Guardar el escenario');
      await f.tap('Aplicar');
      await f.step(
        '«¿Aplicar el cambio?»: Netflix quedará en \$31.900 desde su próximo '
        'cobro; lo ya registrado no cambia.',
      );
      await f.tap('Cancelar');
      RecurringCharge netflix() => own.recurring.single;
      await f.check('Con «Cancelar» Netflix sigue en 26.900', () {
        expect(netflix().amount.amount, Decimal.fromInt(26900));
      });
      await f.tap('Aplicar');
      await f.tap('Aplicar');
      await f.check(
        'Al aplicar, Netflix queda en 31.900 y lo que puedes gastar baja '
        '5.000',
        () {
          expect(netflix().amount.amount, Decimal.fromInt(31900));
          expect(own.ledger!.freeUntilPayday, free - l.minor(5000));
        },
      );
      await f.tap('Pago tarde');
      await f.tapTip('Más días');
      await f.tapTip('Más días');
      await f.tapTip('Menos días');
      await f.step(
        '«Pago tarde» empieza en 5 días; con las flechas queda en 6 días '
        'tarde y compara el saldo mínimo y el primer día bajo el colchón.',
      );
      await f.check('Se prueba el pago 6 días tarde', () {
        expect(f.shows('6 días tarde'), isTrue);
      });
      await f.tap('Guardar el escenario');
      await f.reveal(find.text('ESCENARIOS GUARDADOS'));
      await f.step(
        '«Escenarios guardados» lista los tres, cada uno con su saldo mínimo '
        'y una caneca para quitarlo.',
      );
      await f.check('Hay tres escenarios guardados', () {
        expect(own.scenarios.map((Scenario s) => s.kind), <ScenarioKind>[
          ScenarioKind.saveMore,
          ScenarioKind.chargeUp,
          ScenarioKind.payLate,
        ]);
        expect(own.scenarios.last.days, 6);
      });
      await _tapTipBy(
        f,
        'Apartar ${pesos(100000)} más en cada pago',
        'Quitar escenario',
      );
      await f.step('Quitado el de ahorrar más, quedan dos escenarios.');
      await f.check('Quedan los escenarios de Netflix y del pago tarde', () {
        expect(own.scenarios.map((Scenario s) => s.kind), <ScenarioKind>[
          ScenarioKind.chargeUp,
          ScenarioKind.payLate,
        ]);
      });
    },
  ),
  AppFlow(
    '06-26-medir-el-colchon-en-dias',
    'Medir el fondo de emergencia en días',
    area: 'Plan',
    goal:
        'Quiero saber para cuántos días de gastos básicos me alcanza lo que '
        'tengo ahorrado, y guardar un colchón que no cuente como plata para '
        'gastar.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final Account dollars = own.accounts.firstWhere(
        (Account a) => a.name == 'Cuenta en dólares',
      );
      CushionDays days() => cushionDays(
        own.ledger!,
        reserve: reserveOf(own, own.cushionSettings),
        essentials: own.cushionSettings.essentials,
      );
      await _openPlan(f);
      await f.tap('Fondo de emergencia en días');
      await f.page(
        '«Fondo de emergencia en días» pide elegir las cuentas del fondo, qué '
        'es esencial para ti y cuántos días quieres cubrir.',
        most: 3,
      );
      await f.tap('Cuenta en dólares');
      final CushionDays first = days();
      await f.top();
      await f.step(
        'Con la cuenta en dólares, el fondo cubre unos ${first.days} días: '
        'lo que tiene, entre lo que gastas al día en lo esencial.',
      );
      await f.check(
        'Cubre ${first.days} días: ${_pesos(l, first.reserve)} entre '
        '${_pesos(l, first.dailyEssential)} al día',
        () {
          expect(own.cushionSettings.accounts, <String>{dollars.id});
          expect(first.gap, isNull);
          expect(
            f.shows('Cubre unos ${first.days} días de gastos esenciales'),
            isTrue,
          );
        },
      );
      await f.tap('Restaurantes');
      final CushionDays second = days();
      await f.top();
      await f.step(
        'Contar los restaurantes como esenciales sube el gasto diario: el '
        'fondo alcanza para menos días, ${second.days}.',
      );
      await f.check('Con restaurantes, alcanza para menos días', () {
        expect(own.cushionSettings.essentials, contains(Category.restaurants));
        expect(second.days, lessThan(first.days!));
      });
      await f.tap('180 días');
      await f.top();
      await f.step(
        'Con la meta de 180 días aparece la barra y cuántos días y cuánta '
        'plata te faltan.',
      );
      await f.check('La meta de 180 días quedó guardada', () {
        expect(own.cushionSettings.targetDays, 180);
        expect(f.shows('Llegaste a los 180 días que te propusiste.'), isFalse);
      });
      for (final int target in <int>[30, 60, 90]) {
        await f.tap('$target días');
        await f.top();
        await f.check(
          'La meta de $target días queda guardada y ya se cumple',
          () {
            expect(own.cushionSettings.targetDays, target);
            expect(
              f.shows('Llegaste a los $target días que te propusiste.'),
              isTrue,
            );
          },
        );
      }
      await f.top();
      await f.step(
        'Con 90 días la meta ya se cumple: la barra se llena y dice '
        '«Llegaste a los 90 días que te propusiste.»',
      );
      await f.tap('Sin meta');
      await f.check('«Sin meta» quita la meta', () {
        expect(own.cushionSettings.targetDays, isNull);
      });
      await f.check(
        'Nada de esto cambia lo que puedes gastar: la cuenta en dólares no es '
        'de uso diario',
        () => expect(own.ledger!.freeUntilPayday, free),
      );
      await f.back();
      await f.reveal(find.text('Fondo de emergencia en días'));
      await f.step(
        'En Plan, la fila dice «Cubre unos ${second.days} días de gastos '
        'esenciales».',
      );
      // The money kept apart is set in Ajustes, and that one does move it.
      await f.tapTip('Ajustes');
      await f.tap('Colchón');
      await _typeInDialog(f, '200000');
      await f.step(
        'En Ajustes, «Colchón» es otra cosa: plata que quieres guardar sin '
        'tocar, y sale de lo que puedes gastar. Se escriben 200.000.',
      );
      await f.tap('Guardar');
      await f.back();
      await f.tap('Inicio');
      await f.top();
      await f.step(
        'En Inicio el colchón sale de la cifra: «Puedes gastar» pasa a «Te '
        'faltan» y el desglose muestra «Colchón» con −200.000.',
      );
      await f.check('Lo que puedes gastar pasó de ${_pesos(l, free)} a '
          '${_pesos(l, free - l.minor(200000))}', () {
        expect(own.ledger!.cushion, l.minor(200000));
        expect(own.ledger!.freeUntilPayday, free - l.minor(200000));
      });
    },
  ),
  AppFlow(
    '06-27-dividir-un-gasto-que-ya-anote',
    'Dividir un gasto que ya anoté',
    area: 'Plan',
    goal:
        'Pagué la comida con Sofía y unas compras que eran de los dos: quiero '
        'que solo mi parte cuente como gasto y saber cuánto me debe.',
    data: seeded,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int spent = spentThisPeriod(l);
      final Entry crepes = _entry(own, 'Crepes & Waffles');
      final Entry falabella = _entry(own, 'Falabella');
      Group sofia() => own.groups.single;
      await f.tap('Movimientos');
      await f.tap('Crepes & Waffles');
      await f.reveal(find.text('Dividir este gasto'));
      await f.step(
        'Al abrir la comida de Crepes & Waffles, debajo de «Guardar» está '
        '«Dividir este gasto».',
      );
      await f.tap('Dividir este gasto');
      await f.tap('Guardar');
      await f.step(
        '«Dividir un gasto» trae el valor del movimiento, que no se cambia. '
        'Sin nadie más, «Guardar» avisa «Agrega al menos a una persona más.»',
      );
      await f.check('Sin con quién dividirlo no se crea ningún grupo', () {
        expect(f.shows('Agrega al menos a una persona más.'), isTrue);
        expect(own.groups, isEmpty);
      });
      await f.type('¿Con quién lo divides?', 'Sofía');
      await f.type('Nombre del grupo', 'Comidas con Sofía');
      await f.step(
        'Con Sofía en partes iguales: ${pesos(11750)} para cada uno. El '
        'grupo nuevo se llama «Comidas con Sofía».',
      );
      await f.tap('Guardar');
      await f.step(
        'De vuelta en Movimientos, la comida lleva aparte la etiqueta «Tu '
        'parte ${pesos(11750)}», entera, bajo «Restaurantes · Nequi».',
      );
      await f.check(
        'Quedó el grupo con Sofía y el gasto ligado al movimiento',
        () {
          expect(sofia().name, 'Comidas con Sofía');
          expect(sofia().members.map((Member m) => m.name), <String>[
            '',
            'Sofía',
          ]);
          final SharedExpense e = sofia().expenses.single;
          expect(e.entryId, crepes.id);
          expect(e.paidBy, meId);
          expect(e.shares.values, <int>[11750, 11750]);
          expect(_says(f, 'Tu parte ${pesos(11750)}'), isTrue);
        },
      );
      await f.check('Solo tu parte cuenta como gasto: lo gastado baja '
          '${pesos(11750)} y lo que puedes gastar no cambia', () {
        expect(spentThisPeriod(own.ledger!), spent - l.minor(11750));
        expect(own.ledger!.freeUntilPayday, free);
        expect(own.sharedBalance, (11750, 0));
      });
      await f.tap('Crepes & Waffles');
      await f.tap('Cambiar la división');
      await f.tap('Por montos');
      await f.type('Tu parte', '8500');
      await f.type('Parte de Sofía', '15000');
      await f.step(
        '«Cambiar la división» abre lo que había; «Por montos» deja poner '
        '8.500 para ti y 15.000 para Sofía, que suman los 23.500.',
      );
      await f.tap('Guardar');
      await f.check('Ahora Sofía debe 15.000 y lo gastado baja 15.000', () {
        expect(sofia().expenses.single.shares, <String, int>{
          meId: 8500,
          sofia().members.last.id: 15000,
        });
        expect(spentThisPeriod(own.ledger!), spent - l.minor(15000));
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.tap('Falabella');
      await f.tap('Dividir este gasto');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.step(
        '«Grupo» ofrece crear uno nuevo o usar uno que ya tienes, como '
        '«Comidas con Sofía».',
      );
      await f.tapFound(find.text('Comidas con Sofía').last);
      await f.step(
        'En el grupo de Sofía ya no hay que escribir nombres: Falabella queda '
        'en ${pesos(21450)} para cada uno.',
      );
      await f.tap('Guardar');
      await f.check('Las compras de Falabella fueron al mismo grupo', () {
        expect(own.groups, hasLength(1));
        expect(
          sofia().expenses.map((SharedExpense e) => e.entryId),
          unorderedEquals(<String>[crepes.id, falabella.id]),
        );
        expect(own.sharedBalance, (36450, 0));
      });
      await _openPlan(f);
      await f.tap('Gastos compartidos');
      await f.tap('Comidas con Sofía');
      await f.step(
        'En el grupo, «Sofía te paga ${pesos(36450)}»: 15.000 de la comida y '
        '21.450 de Falabella, cada gasto con tu parte.',
      );
      await f.check('El grupo dice lo que Sofía debe: ${pesos(36450)}', () {
        expect(f.shows('Sofía te paga ${pesos(36450)}'), isTrue);
      });
      await f.tap('Crepes & Waffles');
      await f.reveal(find.text('Quitar la división'));
      await f.tap('Quitar la división');
      await f.step(
        '«Quitar la división» saca la comida del grupo: Sofía queda debiendo '
        'solo lo de Falabella, ${pesos(21450)}.',
      );
      await f.check(
        'Sin la división, la comida vuelve a contar entera como gasto',
        () {
          expect(sofia().expenses.map((SharedExpense e) => e.entryId), <String>[
            falabella.id,
          ]);
          expect(spentThisPeriod(own.ledger!), spent - l.minor(21450));
          expect(own.sharedBalance, (21450, 0));
        },
      );
    },
  ),
  AppFlow(
    '06-28-saber-si-me-alcanza-sin-tocar-la-reserva',
    'Saber si me alcanza sin tocar la reserva',
    area: 'Plan',
    goal:
        'Aparto el 15 % de lo que cobro para impuestos: quiero saber si me '
        'alcanza para unos tenis sin gastarme esa plata.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int entries = own.snapshot!.entries.length;
      await f.step(
        'Inicio: «Puedes gastar» es ${_pesos(l, free)}, porque deja fuera '
        '${_pesos(l, l.reserved)} de la reserva de ingresos variables.',
      );
      await _openPlan(f);
      await f.tap('Próximos 30 días');
      await f.tap('¿Me alcanza?');
      await f.type('¿Cuánto cuesta?', '100000');
      await f.type('¿Qué es? (opcional)', 'Tenis');
      final PurchaseCheck shoes = checkPurchase(
        own.ledger!,
        price: l.minor(100000),
        date: own.today,
        label: 'Tenis',
        atLeast: 30,
      );
      final int fromReserve = l.minor(100000) - free;
      await f.step(
        'Unos tenis de 100.000: para gastar solo hay ${_pesos(l, free)}, así '
        'que dice «Te alcanza, pero tocando lo apartado» y que usarías '
        '${_pesos(l, fromReserve)} de la reserva; en tus cuentas quedarían '
        'mínimo ${_pesos(l, shoes.lowest)}.',
      );
      await f.check(
        'Lo que quedaría en las cuentas es lo que calcula la app: '
        '${_pesos(l, shoes.lowest)}',
        () => expect(
          _says(
            f,
            'En tus cuentas quedarían mínimo ${_pesos(l, shoes.lowest)}',
          ),
          isTrue,
        ),
      );
      await f.check(
        'Con ${_pesos(l, free)} para gastar y ${_pesos(l, l.reserved)} de '
        'reserva, una compra de ${pesos(100000)} no dice «Te alcanza»',
        () => expect(f.shows('Te alcanza, según lo que sabe la app'), isFalse),
      );
      await f.check(
        'Dice que tocaría la reserva: usarías ${_pesos(l, fromReserve)} de '
        'ella',
        () {
          expect(shoes.verdict, PurchaseVerdict.takesApart);
          expect(shoes.usesReserve, fromReserve);
          expect(f.shows('Te alcanza, pero tocando lo apartado'), isTrue);
          expect(
            _says(
              f,
              'usarías ${_pesos(l, fromReserve)} de tu reserva de ingresos '
              'variables',
            ),
            isTrue,
          );
        },
      );
      final PurchaseCheck later = checkPurchase(
        own.ledger!,
        price: l.minor(100000),
        date: l.nextPayday.add(const Duration(days: 1)),
        label: 'Tenis',
      );
      await f.check(
        'Esperar al ${dayShortMonth(later.date)} también toca la reserva: la '
        'app no sabe cuánto te pagan y no cuenta ningún pago',
        () {
          expect(later.verdict, PurchaseVerdict.takesApart);
          expect(later.payUnknown, isTrue);
          expect(
            find.text('Te alcanza, pero tocando lo apartado'),
            findsNWidgets(3),
          );
          expect(f.shows('sin contar tu pago'), isTrue);
        },
      );
      await f.type('¿Cuánto cuesta?', '7000');
      await f.step(
        'Con 7.000, menos de lo que puedes gastar, «Te alcanza» sí es cierto '
        'y lo dice: cabe en los ${_pesos(l, free)} que puedes gastar.',
      );
      await f.check('Una compra de 7.000 cabe en lo que puedes gastar', () {
        expect(l.minor(7000), lessThanOrEqualTo(free));
        expect(f.shows('Te alcanza, según lo que sabe la app'), isTrue);
        expect(
          _says(
            f,
            'Cabe en los ${_pesos(l, free)} que puedes gastar hasta el 15 de '
            'octubre.',
          ),
          isTrue,
        );
      });
      await f.check('Probar compras no anota nada', () {
        expect(own.snapshot!.entries.length, entries);
        expect(own.ledger!.freeUntilPayday, free);
      });
    },
  ),
  AppFlow(
    '06-29-poner-al-dia-una-meta-y-una-prueba-vencidas',
    'Poner al día una meta y una prueba gratis vencidas',
    area: 'Plan',
    goal:
        'Se me pasó la fecha de la moto y la prueba gratis de Max: quiero '
        'ponerles fechas nuevas sin borrar nada.',
    data: _overdue,
    manual: <String>[
      'Que el aviso de la prueba gratis de Max llegue el 16 de octubre a las '
          '9 de la mañana.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final List<MethodCall> calls = _reminders(f, allow: () => true);
      RecurringCharge max() =>
          own.recurring.firstWhere((RecurringCharge r) => r.name == 'Max');
      await _openPlan(f);
      await f.reveal(find.text('Moto'));
      await f.step(
        'La Moto tenía fecha del 20 de septiembre, que ya pasó, y la fila lo '
        'avisa: «La fecha, el 20 de septiembre de 2026, ya pasó: cámbiala en '
        'la meta.»',
      );
      await f.check('La fila avisa que la fecha ya pasó', () {
        expect(
          _says(
            f,
            'La fecha, el 20 de septiembre de 2026, ya pasó: cámbiala en la '
            'meta.',
          ),
          isTrue,
        );
      });
      await f.tap('Moto');
      await f.tap('Para el 20 de septiembre de 2026');
      await f.step(
        'La fecha vencida abre su calendario en septiembre, para moverla.',
      );
      await f.check('El calendario abre aunque la fecha ya pasó', () {
        expect(
          find.byWidgetPredicate((Widget w) => w is DatePickerDialog),
          findsOneWidget,
        );
      });
      for (var i = 0; i < 3; i++) {
        await f.tapTip('Mes siguiente');
      }
      await _pickDay(f, '20');
      await f.step('La meta queda «Para el 20 de diciembre de 2026».');
      await f.tap('Guardar');
      await f.check(
        'La Moto quedó para el 20 de diciembre, con lo ahorrado',
        () {
          final SavingsGoal g = own.snapshot!.goals.single;
          expect(g.deadline, DateTime(2026, 12, 20));
          expect(g.saved.amount, Decimal.fromInt(1500000));
        },
      );
      await f.top();
      await f.tap('Pagos fijos');
      await f.step(
        'En la lista, Max ya no muestra la prueba que terminó el 28 de '
        'septiembre, y su próximo cobro sigue en el 3 de noviembre.',
      );
      await f.tap('Max');
      await f.tap('Prueba gratis hasta el 28 de septiembre');
      await f.tapTip('Mes siguiente');
      await _pickDay(f, '17');
      await f.reveal(find.textContaining('Próximo cobro:'));
      await f.step(
        'Con la prueba hasta el 17 de octubre, el primer cobro pasa solo a '
        'ese día: «Próximo cobro: 17 de octubre».',
      );
      await f.check('El próximo cobro siguió a la prueba: 17 de octubre', () {
        expect(f.shows('Próximo cobro: 17 de octubre'), isTrue);
      });
      await f.tap('Guardar');
      await f.check('Max quedó con la prueba y el primer cobro el 17', () {
        expect(max().nextDate, DateTime(2026, 10, 17));
        expect(own.memoryOf(max().id).trialEnds, DateTime(2026, 10, 17));
      });
      await f.check(
        'El aviso de la prueba quedó para el 16 de octubre a las 9',
        () {
          final List<Object?> items =
              (calls
                          .lastWhere((MethodCall c) => c.method == 'schedule')
                          .arguments
                      as Map<Object?, Object?>)['items']!
                  as List<Object?>;
          final Map<Object?, Object?> trial = items
              .cast<Map<Object?, Object?>>()
              .firstWhere(
                (Map<Object?, Object?> i) => '${i['title']}'.contains('Max'),
              );
          expect(
            trial['title'],
            'La prueba gratis de Max termina el 17 de octubre',
          );
          expect(trial['at'], DateTime(2026, 10, 16, 9).millisecondsSinceEpoch);
        },
      );
      await f.check(
        'Cobra después del pago del 15: lo que puedes gastar no cambia',
        () => expect(own.ledger!.freeUntilPayday, free),
      );
      await f.step(
        'Max queda con «Prueba gratis hasta el 17 de octubre» y su próximo '
        'cobro ese mismo día.',
      );
    },
  ),
  AppFlow(
    '06-30-repartir-como-la-quincena-pasada',
    'Repartir como la quincena pasada',
    area: 'Plan',
    goal:
        'Me llegó la quincena: quiero repartirla como la anterior sin escribir '
        'todo otra vez, ajustando lo que ya no alcanza.',
    data: _lastPeriodSplit,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int money = allocatable(l);
      // The trip gets what the day to day leaves of it.
      final int trip = money - l.minor(300000);
      await _openPlan(f);
      await f.step(
        'La quincena del 30 de septiembre todavía no tiene reparto: arriba '
        'sale «Reparte esta quincena».',
      );
      await f.check(
        'Hay un reparto de la quincena pasada y ninguno de esta',
        () {
          expect(own.plan, isNull);
          expect(own.lastPlan!.period, DateTime(2026, 9, 15));
        },
      );
      await f.tap('Repartir en sobres');
      await f.step(
        'Los sobres vienen como la quincena pasada, ajustados a lo que hay: '
        'el día a día conserva sus 300.000, el viaje baja de 100.000 a '
        '${_pesos(l, trip)} y el regalo queda en cero. Arriba dice qué cambió '
        'y por qué.',
      );
      await f.check(
        'Trae los sobres de la quincena pasada, sin el de la meta que ya no '
        'existe, ajustados a lo que hay',
        () {
          expect(_fieldText(f, 'Día a día'), '300.000');
          expect(_fieldText(f, 'Viaje a Cartagena'), _typed(l, trip));
          expect(_fieldText(f, 'Regalo de mamá'), isEmpty);
          expect(find.widgetWithText(TextField, 'Moto'), findsNothing);
        },
      );
      await f.check(
        'Copiar el reparto ya no se pasa: dice qué ajustó para que quepa',
        () {
          expect(f.shows('Te pasas por'), isFalse);
          expect(
            f.screenText,
            contains(
              'Viaje a Cartagena pasa de ${_pesos(l, l.minor(100000))} a '
              '${_pesos(l, trip)} y Regalo de mamá pasa de '
              '${_pesos(l, l.minor(40000))} a ${_pesos(l, 0)}',
            ),
          );
        },
      );
      await f.type('Día a día', '200000');
      await f.type('Viaje a Cartagena', '100000');
      await f.type('Regalo de mamá', '40000');
      await f.step(
        'Con 200.000 de día a día caben el viaje y el regalo como antes: '
        '«Sin asignar» ${_pesos(l, money - l.minor(340000))}.',
      );
      await f.tap('Guardar el reparto');
      await f.check('El reparto quedó guardado para esta quincena', () {
        final EnvelopePlan plan = own.plan!;
        expect(plan.period, periodStart(own.ledger!));
        expect(plan.envelopes.map((Envelope e) => e.amount), <int>[
          l.minor(200000),
          l.minor(100000),
          l.minor(40000),
        ]);
        expect(own.ledger!.setAside, l.minor(140000));
      });
      await f.top();
      await f.step(
        'En Plan, la tarjeta muestra el reparto con el viaje y el regalo '
        'apartados; arriba, «Llevas \$0 de \$200.000»: lo gastado antes de '
        'repartir no sale del sobre.',
      );
      await f.check('Recién repartido, el día a día no lleva nada gastado', () {
        expect(dailySpent(own.ledger!, own.plan!), 0);
        expect(f.shows('Te pasaste por'), isFalse);
        expect(
          f.shows('Llevas ${_pesos(l, 0)} de ${_pesos(l, l.minor(200000))}'),
          isTrue,
        );
      });
    },
  ),
  AppFlow(
    '06-31-cobrar-en-la-cuenta-en-dolares',
    'Cobrar a un cliente en la cuenta en dólares',
    area: 'Plan',
    goal:
        'Un cliente me pagó en mi cuenta en dólares: no quiero que la reserva '
        'me quite de lo que puedo gastar una plata que nunca estuvo ahí.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger l = own.ledger!;
      final int free = l.freeUntilPayday;
      final int reserve = l.reserved;
      await f.step(
        'Inicio: «Puedes gastar» es ${_pesos(l, free)} y deja fuera '
        '${_pesos(l, reserve)} de reserva, el 15 % de lo que Estudio Sur '
        'pagó a Bancolombia.',
      );
      await f.tapTip('Agregar movimiento');
      await f.tap('Ingreso');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Cuenta en dólares').last);
      await f.type('Monto', '500');
      await f.tap('Trabajos independientes');
      await f.type('¿De dónde?', 'Upwork');
      await f.step(
        'Un ingreso de 500 dólares en «Cuenta en dólares», como «Trabajos '
        'independientes», de Upwork.',
      );
      await f.tap('Guardar');
      final int outside = l.minor(
        own.inBase(Money(Decimal.fromInt(500), Asset.usd))!.amount.toDouble(),
      );
      await f.step(
        'De vuelta en Inicio, «Puedes gastar» sigue en ${_pesos(l, free)}: '
        'ni el cobro ni su 15 % pasan por las cuentas de uso diario.',
      );
      await f.check(
        'El cobro quedó en la cuenta en dólares, como trabajo independiente',
        () {
          final Entry e = _entry(own, 'Upwork');
          expect(e.amount, Decimal.fromInt(500));
          expect(e.category, 'freelance');
          expect(own.snapshot!.account(e.accountId)!.name, 'Cuenta en dólares');
        },
      );
      await f.check(
        'La reserva sigue en ${_pesos(l, reserve)} y lo que puedes gastar en '
        '${_pesos(l, free)}: nada se aparta de ${_pesos(l, outside)} que '
        'nunca estuvieron ahí',
        () {
          expect(own.ledger!.reserved, reserve);
          expect(own.ledger!.freeUntilPayday, free);
          expect(own.collectedOutsideReserve, outside);
        },
      );
      await _openPlan(f);
      await f.tap('Ingresos variables');
      await f.reveal(find.textContaining('no se aparta'));
      await f.step(
        'En «Ingresos variables», la reserva sigue en ${_pesos(l, reserve)} y '
        'dice por qué: lo cobrado en cuentas que no son de uso diario no se '
        'aparta.',
      );
      await f.check('Explica que los ${_pesos(l, outside)} no se apartan', () {
        expect(
          _says(
            f,
            'Lo que cobraste en cuentas que no son de uso diario '
            '(${_pesos(l, outside)}) no se aparta: nunca contó en lo que '
            'puedes gastar.',
          ),
          isTrue,
        );
        expect(
          _says(
            f,
            'Tienes apartados ${_pesos(l, reserve)} desde el 1 de octubre.',
          ),
          isTrue,
        );
      });
    },
  ),
];

/// Opens the Plan tab.
Future<void> _openPlan(FlowRun f) async {
  await f.tap('Plan');
}

/// [minor] as the app shows money of [ledger].
String _pesos(Ledger ledger, int minor) => pesos(ledger.major(minor));

String get _zero => pesos(0);

/// Whether the screen says [text], spaces that never break read as plain
/// ones.
bool _says(FlowRun f, String text) => f.screenText
    .replaceAll(' ', ' ')
    .replaceAll(signJoiner, '')
    .contains(text.replaceAll(' ', ' ').replaceAll(signJoiner, ''));

/// What the field labelled [label] holds.
String _fieldText(FlowRun f, String label) => f.tester
    .widget<TextField>(find.widgetWithText(TextField, label).first)
    .controller!
    .text;

/// Types [text] in the only field of the dialog on top.
Future<void> _typeInDialog(FlowRun f, String text) async {
  await enterTextIn(
    f.tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    text,
  );
  await f.tester.pump();
}

/// The seeded account with a goal that gets 300.000 a month.
Future<QuincenaStore> _withGoal() async {
  final QuincenaStore store = await seeded();
  await store.addGoal(
    name: 'Viaje a Cartagena',
    target: Money.parse('2400000', Asset.cop),
    saved: Money.parse('650000', Asset.cop),
    monthly: Money.parse('300000', Asset.cop),
    deadline: DateTime(2026, 12, 20),
  );
  return store;
}

/// The movement paid to [payee].
Entry _entry(OwnController own, String payee) =>
    own.snapshot!.entries.firstWhere((Entry e) => e.payee == payee);

/// What every pending payment from clients adds up to, late ones too.
int _pendingTotal(OwnController own) => own.freelance
    .by(IncomeStatus.pending)
    .fold(0, (int s, ExpectedIncome i) => s + i.amount);

/// Taps [day] in the calendar on top, one day or a range.
Future<void> _tapInDialog(FlowRun f, String day) async {
  final Finder picker = find.byWidgetPredicate(
    (Widget w) => w is DatePickerDialog || w is DateRangePickerDialog,
  );
  await f.tester.tap(
    find.descendant(of: picker, matching: find.text(day)).first,
  );
  await f.tester.pumpAndSettle();
}

/// Picks [day] of the month the calendar shows, and accepts it.
Future<void> _pickDay(FlowRun f, String day) async {
  await _tapInDialog(f, day);
  await f.tap('ACEPTAR');
}

/// Taps the button with [tooltip] closest to [text]: the one in its row
/// or card.
Future<void> _tapTipBy(FlowRun f, String text, String tooltip) =>
    _tapNear(f, text, find.byTooltip(tooltip));

/// Taps the button that says [button] closest to [text].
Future<void> _tapTextBy(FlowRun f, String text, String button) =>
    _tapNear(f, text, find.text(button));

/// Taps the first [target] in the smallest part of the screen that holds
/// both [text] and it.
Future<void> _tapNear(FlowRun f, String text, Finder target) async {
  await f.reveal(find.text(text));
  Finder? found;
  find.text(text).evaluate().first.visitAncestorElements((Element e) {
    final Finder inside = find.descendant(
      of: find.byElementPredicate((Element x) => x == e),
      matching: target,
    );
    if (inside.evaluate().isEmpty) return true;
    found = inside.first;
    return false;
  });
  await f.reveal(found!);
  await f.tester.tap(found!);
  await f.tester.pumpAndSettle();
}

/// Answers the app's reminders as the phone would, allowing them or not
/// as [allow] says, and keeps what the app asked for.
List<MethodCall> _reminders(FlowRun f, {required bool Function() allow}) {
  const MethodChannel channel = MethodChannel('dev.dlsoft.quincena/reminders');
  final List<MethodCall> calls = <MethodCall>[];
  final TestDefaultBinaryMessenger messenger =
      f.tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
    calls.add(call);
    return call.method == 'ask' ? allow() : null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

/// The whole account, with Claro's internet charged the 8th of each of the
/// last three months, so it looks like a fixed payment besides Spotify.
Future<QuincenaStore> _withGuesses() async {
  final QuincenaStore store = await fullAccount();
  final Account bank = (await store.accounts()).firstWhere(
    (Account a) => a.name == 'Bancolombia',
  );
  for (final int month in <int>[7, 8, 9]) {
    await store.addEntry(
      accountId: bank.id,
      amount: Decimal.parse('89900'),
      kind: EntryKind.expense,
      date: DateTime(2026, month, 8, 7),
      category: 'utilities',
      payee: 'Claro',
    );
  }
  return store;
}

/// The whole account, with the gym as a fixed payment still at its old
/// price of 99.000.
Future<QuincenaStore> _withGym() async {
  final QuincenaStore store = await fullAccount();
  final Account bank = (await store.accounts()).firstWhere(
    (Account a) => a.name == 'Bancolombia',
  );
  await store.addRecurring(
    name: 'Fit24',
    amount: Money.parse('99000', Asset.cop),
    cadence: Cadence.monthly,
    nextDate: DateTime(2026, 11, 1),
    accountId: bank.id,
    category: 'leisure',
  );
  return store;
}

/// The whole account, with five meals out from Bancolombia over the
/// summer and one of 420.000 this month, twelve times the usual.
Future<QuincenaStore> _withUnusual() async {
  final QuincenaStore store = await fullAccount();
  final Account bank = (await store.accounts()).firstWhere(
    (Account a) => a.name == 'Bancolombia',
  );
  Future<void> meal(String payee, DateTime on, String amount) => store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse(amount),
    kind: EntryKind.expense,
    date: on,
    category: 'restaurants',
    payee: payee,
  );
  await meal('El Corral', DateTime(2026, 6, 10, 13), '35000');
  await meal('Hornitos', DateTime(2026, 7, 10, 13), '35000');
  await meal('Sushi Light', DateTime(2026, 7, 25, 13), '35000');
  await meal('Frisby', DateTime(2026, 8, 10, 13), '35000');
  await meal('La Toscana', DateTime(2026, 8, 25, 13), '35000');
  await meal('Andrés Carne de Res', DateTime(2026, 10, 2, 22), '420000');
  return store;
}

/// The seeded account, with a pay of 2.400.000, a cushion of 200.000 and
/// the trip to Cartagena as a goal.
Future<QuincenaStore> _withPay() async {
  final QuincenaStore store = await _withGoal();
  final Profile p = (await store.profile())!;
  await store.saveProfile(
    Profile(
      name: p.name,
      base: p.base,
      schedule: p.schedule,
      pay: Decimal.fromInt(2400000),
      cushion: Decimal.fromInt(200000),
    ),
  );
  return store;
}

/// [_withPay], with the fortnight before this one spent day to day: what
/// «¿Y si…?» counts as usual, 225.000 in 15 days.
Future<QuincenaStore> _withPayAndHistory() async {
  final QuincenaStore store = await _withPay();
  final Account bank = (await store.accounts()).firstWhere(
    (Account a) => a.name == 'Bancolombia',
  );
  for (final (String amount, int day, String category, String payee)
      in <(String, int, String, String)>[
        ('85000', 16, 'groceries', 'D1'),
        ('42000', 19, 'restaurants', 'Crepes & Waffles'),
        ('18000', 22, 'transport', 'Uber'),
        ('80000', 26, 'groceries', 'Éxito Laureles'),
      ]) {
    await store.addEntry(
      accountId: bank.id,
      amount: Decimal.parse(amount),
      kind: EntryKind.expense,
      date: DateTime(2026, 9, day, 12),
      category: category,
      payee: payee,
    );
  }
  return store;
}

/// The seeded account without its one fixed payment.
Future<QuincenaStore> _noFixed() async {
  final QuincenaStore store = await seeded();
  for (final RecurringCharge r in await store.recurring()) {
    await store.deleteRecurring(r.id);
  }
  return store;
}

/// The whole account, with what some flows need besides: a flight paid
/// before the trip to New York, the money Agencia Uno sent, and 50.000 lent
/// to Pedro that he paid back to Nequi.
Future<QuincenaStore> _planAccount() async {
  final QuincenaStore store = await fullAccount();
  final List<Account> accounts = await store.accounts();
  Account named(String name) =>
      accounts.firstWhere((Account a) => a.name == name);
  await store.addEntry(
    accountId: named('Visa').id,
    amount: Decimal.parse('1850000'),
    kind: EntryKind.expense,
    date: DateTime(2026, 9, 20, 19),
    category: 'transport',
    payee: 'Avianca',
  );
  await store.addEntry(
    accountId: named('Bancolombia').id,
    amount: Decimal.parse('700000'),
    kind: EntryKind.income,
    date: DateTime(2026, 10, 1, 11),
    category: 'other_income',
    payee: 'Agencia Uno',
  );
  await store.addEntry(
    accountId: named('Nequi').id,
    amount: Decimal.parse('50000'),
    kind: EntryKind.income,
    date: DateTime(2026, 10, 3, 9),
    category: 'other_income',
    payee: 'Pedro te envió',
  );
  final List<Object?> groups =
      jsonDecode((await store.setting('shared.groups'))!) as List<Object?>;
  await store.setSetting(
    'shared.groups',
    jsonEncode(<Object?>[
      ...groups,
      Group(
        id: 'group-pedro',
        name: 'Pedro',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'p-pedro', name: 'Pedro'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'loan-pedro',
            label: 'Préstamo',
            date: DateTime(2026, 9, 25),
            paidBy: meId,
            shares: const <String, int>{'p-pedro': 50000},
          ),
        ],
      ).toJson(),
    ]),
  );
  return store;
}

/// [minor] as an amount field shows it: no sign, and empty for nothing.
String _typed(Ledger ledger, int minor) => minor == 0
    ? ''
    : formatDecimal(
        Decimal.parse('${ledger.major(minor)}'),
        decimals: ledger.currency.decimals,
        trim: true,
      );

/// Answers the share sheet as a phone would: it opens when [sheet], or it
/// is not there and the app copies the message. Keeps what was shared.
List<String> _shares(FlowRun f, {required bool sheet}) {
  const MethodChannel channel = MethodChannel('dev.dlsoft.quincena/share');
  final List<String> texts = <String>[];
  final TestDefaultBinaryMessenger messenger =
      f.tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
    if (call.method == 'text') texts.add('${call.arguments}');
    return sheet;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return texts;
}

/// Whether the reminders the app set last, of those [calls] saw, have one
/// about [name].
bool _remindsOf(List<MethodCall> calls, String name) {
  final MethodCall? last = calls
      .where((MethodCall c) => c.method == 'schedule' || c.method == 'cancel')
      .lastOrNull;
  if (last == null || last.method == 'cancel') return false;
  final List<Object?> items =
      (last.arguments as Map<Object?, Object?>)['items']! as List<Object?>;
  return items.any(
    (Object? i) => '${(i! as Map<Object?, Object?>)['title']}'.contains(name),
  );
}

/// The seeded account with dates gone by: a motorbike meant for the 20th
/// of September, and Max, whose free trial ended on the 28th.
Future<QuincenaStore> _overdue() async {
  final QuincenaStore store = await seeded();
  await store.addGoal(
    name: 'Moto',
    target: Money.parse('6000000', Asset.cop),
    saved: Money.parse('1500000', Asset.cop),
    monthly: Money.parse('500000', Asset.cop),
    deadline: DateTime(2026, 9, 20),
  );
  final Account visa = (await store.accounts()).firstWhere(
    (Account a) => a.name == 'Visa',
  );
  final RecurringCharge max = await store.addRecurring(
    name: 'Max',
    amount: Money.parse('19900', Asset.cop),
    cadence: Cadence.monthly,
    nextDate: DateTime(2026, 11, 3),
    accountId: visa.id,
    category: 'subscriptions',
  );
  await store.setSetting(
    'commitments.memories',
    jsonEncode(<String, Object?>{
      max.id: ChargeMemory(trialEnds: DateTime(2026, 9, 28)).toJson(),
    }),
  );
  return store;
}

/// The seeded account with the trip to Cartagena as a goal, and the split
/// of the fortnight before: 300.000 for the day to day, 100.000 for the
/// trip, 40.000 for a present, and 80.000 for a goal since deleted.
Future<QuincenaStore> _lastPeriodSplit() async {
  final QuincenaStore store = await seeded();
  final SavingsGoal trip = await store.addGoal(
    name: 'Viaje a Cartagena',
    target: Money.parse('2400000', Asset.cop),
    saved: Money.parse('650000', Asset.cop),
    monthly: Money.parse('300000', Asset.cop),
    deadline: DateTime(2026, 12, 20),
  );
  await store.setSetting(
    'plan.envelopes',
    jsonEncode(
      EnvelopePlan(
        period: DateTime(2026, 9, 15),
        envelopes: <Envelope>[
          const Envelope(
            id: 'daily',
            kind: EnvelopeKind.daily,
            name: '',
            amount: 300000,
          ),
          Envelope(
            id: 'goal-${trip.id}',
            kind: EnvelopeKind.goal,
            name: trip.name,
            amount: 100000,
            goalId: trip.id,
          ),
          const Envelope(
            id: 'goal-old',
            kind: EnvelopeKind.goal,
            name: 'Moto',
            amount: 80000,
            goalId: 'old',
          ),
          const Envelope(
            id: 'aside-gift',
            kind: EnvelopeKind.aside,
            name: 'Regalo de mamá',
            amount: 40000,
          ),
        ],
      ).toJson(),
    ),
  );
  return store;
}
