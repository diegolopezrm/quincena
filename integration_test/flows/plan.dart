// Flows of Plan (06).
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/plan.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';

import '../../test/real_life_data.dart' show newYork;
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
    '06-02-repartir-la-quincena-en-sobres',
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
        '«Reparte tu quincena» propone el día a día y lo de la meta. Abajo, '
        '«Sin asignar» dice cuánto queda libre.',
      );
      await f.check('La propuesta no reparte más de lo que hay', () {
        final List<Envelope> proposal = proposeEnvelopes(
          l,
          goals: own.goalShares,
          dailyName: '',
        );
        final int sum = proposal.fold(0, (int s, Envelope e) => s + e.amount);
        expect(sum, lessThanOrEqualTo(money));
      });
      await f.type('Día a día', '200000');
      await f.type('Viaje a Cartagena', '100000');
      await f.step(
        'Día a día en 200.000 y 100.000 para el viaje: «Sin asignar» baja '
        'mientras escribes.',
      );
      await f.tap('Apartar para algo');
      await f.step('«Apartar para algo» pide un nombre para el sobre.');
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no aparece ningún sobre nuevo', () {
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
        'De vuelta en Plan, recién repartido, la tarjeta ya dice «Te pasaste '
        'por»: cuenta los ${_pesos(l, spent)} gastados desde el 30 de '
        'septiembre, antes de repartir.',
      );
      await f.check(
        'Recién repartido, el día a día no dice que ya te pasaste (cuenta '
        '${_pesos(l, spent)} gastados antes de repartir)',
        () => expect(
          f.shows('Te pasaste por ${_pesos(l, spent - l.minor(200000))}'),
          isFalse,
        ),
      );
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
    },
  ),
  AppFlow(
    '06-03-repartir-mas-de-lo-que-hay',
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
        'Esta cuenta tiene poco para repartir: casi todo está comprometido '
        'hasta el 15 o en la reserva de ingresos variables.',
      );
      await f.tap('Repartir en sobres');
      await f.step(
        'La propuesta no pasa de lo que hay: sin plata libre, el sobre de la '
        'meta no se lleva más de lo que queda.',
      );
      await f.check('La propuesta no deja «Te pasas por»', () {
        expect(f.shows('Te pasas por'), isFalse);
      });
      await f.type('Día a día', '300000');
      final int goals =
          proposeEnvelopes(l, goals: own.goalShares, dailyName: '')
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
      await f.step(
        'Con 100.000 de día a día y ${_pesos(l, spent)} gastados desde el 30 '
        'de septiembre, la barra se llena y avisa «Te pasaste por».',
      );
      await f.check(
        '«Te pasaste por» muestra lo gastado menos el día a día: '
        '${_pesos(l, spent - l.minor(100000))}',
        () => expect(
          _says(f, 'Te pasaste por ${_pesos(l, spent - l.minor(100000))}'),
          isTrue,
        ),
      );
    },
  ),
  AppFlow(
    '06-04-anotar-cobros-de-ingresos-variables',
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
        'En el teléfono «Recordar al cliente» abre la hoja de compartir con '
        'el mensaje. Sin esa hoja el mensaje se copia, pero el aviso queda '
        'tapado por el formulario.',
      );
      await f.tap('Cobrado');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.step(
        'Con «Cobrado» aparece «¿Con qué movimiento llegó?»: se elige entre '
        'los ingresos de los últimos 90 días.',
      );
      await f.tapFound(find.textContaining('Agencia Uno ·').last);
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
      await f.step(
        '«Borrar cobro» en Taller de marca lo quita de una vez, sin preguntar '
        'ni dejar deshacer.',
      );
      await f.check('Taller de marca ya no está', () {
        expect(
          own.freelance.incomes.any(
            (ExpectedIncome i) => i.client == 'Taller de marca',
          ),
          isFalse,
        );
      });
    },
    manual: <String>[
      '«Recordar al cliente» abre la hoja de compartir del teléfono con el '
          'mensaje listo para WhatsApp o correo.',
    ],
  ),
  AppFlow(
    '06-05-reservar-de-cada-cobro',
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
      await f.step('Con 30 % la reserva se duplica.');
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
        '${_pesos(l, reserve * 2 - l.minor(50000))}.',
      );
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
    '06-06-crear-un-viaje-con-presupuesto',
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
    '06-07-cuadrar-el-viaje-a-nueva-york',
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
      await _tapTipInRow(f, 'Fit24 gimnasio', 'No es del viaje');
      await _tapTipInRow(f, 'Fit24', 'No es del viaje');
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
        '«Incluir un gasto de antes» lista los gastos de los 120 días antes '
        'del viaje: el tiquete de Avianca está arriba.',
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
    '06-08-cambiar-y-borrar-un-viaje',
    'Cambiar y borrar un viaje',
    area: 'Plan',
    goal:
        'Quiero subirle el presupuesto al viaje y, cuando ya no me sirva, '
        'borrarlo sin perder mis movimientos.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Decimal left = own.tripSummary(own.trip(newYork)!).left!;
      final int entries = own.snapshot!.entries.length;
      await _openPlan(f);
      await f.tap('Viajes');
      await f.tap('Nueva York');
      await f.tapTip('Editar viaje');
      await f.step(
        '«Editar viaje» trae todo lo guardado: destino, fechas, '
        'moneda, presupuesto y comisión.',
      );
      await f.type('Presupuesto', '2000');
      await f.tap('Guardar');
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
  await f.tester.enterText(
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

/// Taps the button with [tooltip] in the row that says [text].
Future<void> _tapTipInRow(FlowRun f, String text, String tooltip) async {
  final Finder row = find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate(
      (Widget w) =>
          (w is InkWell || w is ListTile) &&
          find
              .descendant(
                of: find.byWidget(w),
                matching: find.byTooltip(tooltip),
              )
              .evaluate()
              .isNotEmpty,
    ),
  );
  await f.reveal(find.text(text));
  final Finder button = find.descendant(
    of: row.first,
    matching: find.byTooltip(tooltip),
  );
  await f.tester.tap(button.first);
  await f.tester.pumpAndSettle();
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
