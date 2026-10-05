// Flows of Inicio (02) and Movimientos (03).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/decisions.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/projection.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/movement_list.dart';

import '../../test/own_flow_test.dart' show settle;
import '../tour.dart';
import 'flow.dart';

Future<void> Function(FlowRun) _dbg(Future<void> Function(FlowRun) play) =>
    (FlowRun f) async {
      try {
        await play(f);
      } catch (e, s) {
        debugPrint('DBG $e\n$s');
        rethrow;
      }
    };

final List<AppFlow> inicioYMovimientosFlows = <AppFlow>[
  AppFlow(
    '02-01-entender-lo-que-puedo-gastar',
    'Entender lo que puedo gastar',
    area: 'Inicio',
    goal:
        'Quiero saber cuánta plata puedo gastar hasta que me paguen y de '
        'dónde sale esa cifra.',
    data: fullAccount,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final Ledger ledger = own.ledger!;
      await f.step(
        'Inicio abre con «Puedes gastar»: la cifra grande, hasta qué día '
        'alcanza y, debajo, la suma que la explica línea por línea.',
      );
      await f.check(
        'La cifra grande es ${_money(own, ledger.freeUntilPayday)}, la que '
        'calcula la app',
        () => expect(f.shows(_money(own, ledger.freeUntilPayday)), isTrue),
      );
      await f.check(
        'Las líneas de la tarjeta suman la cifra: lo que hay, menos pagos, '
        'colchón, sobres y reserva',
        () => expect(
          ledger.balance -
              ledger.committedUntilPayday -
              ledger.cushion -
              ledger.setAside -
              ledger.reserved,
          ledger.freeUntilPayday,
        ),
      );
      await f.check(
        '«En tus cuentas de uso diario» muestra '
        '${_money(own, ledger.balance + own.spendableCardDebt)}',
        () => expect(
          f.shows(_money(own, ledger.balance + own.spendableCardDebt)),
          isTrue,
        ),
      );
      await f.tap('¿De dónde sale?');
      await f.page(
        'Toca «¿De dónde sale?»: se abre la cuenta completa, con la suma '
        'arriba y, debajo, cuenta por cuenta, los pagos, lo que no cuenta y '
        'lo que supone.',
      );
      await f.check('La hoja dice lo que aporta cada cuenta de uso diario', () {
        for (final Account a in own.accounts) {
          if (!a.spendable) continue;
          final int part = own.spendableParts[a.id] ?? 0;
          expect(
            f.screenText,
            contains(_money(own, part)),
            reason: '${a.name} aporta ${_money(own, part)}',
          );
        }
      });
      await f.check(
        'Lo que aporta cada cuenta suma lo que hay en ellas, tarjetas '
        'incluidas',
        () {
          final int sum = own.spendableParts.values.fold(
            0,
            (int a, int b) => a + b,
          );
          expect(sum, ledger.balance);
        },
      );
      await f.check(
        '«No cuentan» nombra las cuentas de ahorro o inversión',
        () {
          for (final Account a in own.accounts) {
            if (a.spendable) continue;
            expect(f.screenText, contains(a.name));
          }
        },
      );
      await f.back();
      await f.step(
        'Al cerrar la hoja vuelves a Inicio con la misma cifra: mirar el '
        'detalle no cambia nada.',
      );
      await f.check('Cerrar la hoja no cambia la cifra', () {
        expect(own.ledger!.freeUntilPayday, ledger.freeUntilPayday);
      });
    }),
  ),
  AppFlow(
    '02-02-ver-los-proximos-dias',
    'Ver los próximos días',
    area: 'Inicio',
    goal:
        'Quiero ver qué pagos vienen antes de la quincena y probar qué pasa '
        'si muevo uno de fecha.',
    data: fullAccount,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final Projection projection = own.projection!;
      final ProjectedDay low = projection.lowestBeforePayday;
      await f.reveal(find.text('Próximos días'));
      await f.step(
        '«Próximos días» dice el saldo más bajo antes del pago y lista los '
        'cobros que vienen, con el día y el monto.',
      );
      await f.check(
        'El saldo mínimo dice ${_money(own, low.sure)} el ${dayMonth(low.date)}',
        () => expect(
          f.screenText,
          contains('${_money(own, low.sure)} el ${dayMonth(low.date)}'),
        ),
      );
      await f.tap('Ver 30 días');
      await f.page(
        'Toca «Ver 30 días»: la gráfica del saldo día por día durante un '
        'mes, con el día del pago marcado y, debajo, lo que pasa cada día.',
      );
      await f.check('Abre «Próximos 30 días»', () {
        expect(f.shows('Próximos 30 días'), isTrue);
      });
      // The chart picks the day under the finger.
      final Finder chart = find.byWidgetPredicate(
        (Widget w) => w is GestureDetector && w.onHorizontalDragUpdate != null,
      );
      await f.reveal(chart);
      final Rect box = f.tester.getRect(chart.first);
      await f.tester.tapAt(Offset(box.right - 2, box.center.dy));
      await settle(f.tester);
      final DateTime last = own.today.add(const Duration(days: 30));
      await f.top();
      await f.step(
        'Toca el final de la gráfica: ese día pasa arriba de la lista, con '
        'lo que quedaría en tus cuentas.',
      );
      await f.check('El día elegido es el ${weekdayDayMonth(last)}', () {
        expect(f.shows(weekdayDayMonth(last)), isTrue);
      });
      final List<String> fixed = _fixed(own);
      await f.tapFound(find.byTooltip('Mover en la simulación').first);
      await f.step(
        'El ícono de calendario junto a un cobro abre «Mover en la '
        'simulación»: un calendario para probar pagarlo otro día.',
      );
      await _pickDay(f, 14);
      await f.top();
      await f.step(
        'Con el Televisor movido al 14 aparece «Estás probando: nada de esto '
        'se guarda» y la línea punteada muestra el saldo con el cambio.',
      );
      await f.check('Aparece el aviso de que solo es una prueba', () {
        expect(f.shows('Quitar lo que pruebas'), isTrue);
      });
      await f.check('Probar otra fecha no cambia los pagos fijos', () {
        expect(_fixed(own), fixed);
      });
      await f.tap('Quitar lo que pruebas');
      await f.step(
        'Toca «Quitar lo que pruebas»: el aviso se va y la gráfica vuelve a '
        'lo que está programado.',
      );
      await f.check('Ya no hay nada en prueba', () {
        expect(f.shows('Quitar lo que pruebas'), isFalse);
      });
      await f.tapTip('Cierre de la quincena');
      await f.step(
        'El ícono de recibo, arriba a la derecha, abre «Cierre de la '
        'quincena»: lo que pasó en la quincena anterior.',
      );
      await f.check('Abre «Cierre de la quincena»', () {
        expect(f.shows('Qué cambió'), isTrue);
      });
    }),
  ),
  AppFlow(
    '02-03-saber-si-me-alcanza',
    'Saber si me alcanza para algo',
    area: 'Inicio',
    goal:
        'Vi unos tenis y quiero saber si me alcanza para comprarlos hoy o si '
        'mejor espero al pago.',
    data: fullAccount,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final Ledger ledger = own.ledger!;
      final int entries = own.snapshot!.entries.length;
      await f.type('Precio', '120000');
      await f.reveal(find.text('¿Me alcanza para…?'));
      await f.step(
        'En «¿Me alcanza para…?», en Inicio, escribe el precio: 120.000. El '
        'botón «Ver» hace la cuenta.',
      );
      await f.tap('Ver');
      final PurchaseCheck today = checkPurchase(
        ledger,
        price: 120000,
        date: ledger.today,
        atLeast: 30,
      );
      await f.page(
        'Toca «Ver»: abre «¿Me alcanza?» con el precio puesto, el veredicto '
        'para hoy, la comparación con esperar al pago y los días que vienen.',
      );
      await f.check(
        'Para hoy dice «${_verdict(today.verdict)}», como calcula la app',
        () => expect(f.shows(_verdict(today.verdict)), isTrue),
      );
      await f.check(
        'El saldo mínimo con la compra es ${_money(own, today.lowest)}',
        () => expect(f.screenText, contains(_money(own, today.lowest))),
      );
      await f.check(
        'Con 120.000, más de los ${_money(own, ledger.freeUntilPayday)} que '
        'puedes gastar, no dice que te alcanza',
        () => expect(today.verdict, isNot(PurchaseVerdict.fits)),
      );
      await f.type('¿Qué es? (opcional)', 'Tenis');
      await f.tap('Después del pago');
      final PurchaseCheck after = checkPurchase(
        ledger,
        price: 120000,
        date: ledger.nextPayday.add(const Duration(days: 1)),
        label: 'Tenis',
        atLeast: 30,
      );
      await f.step(
        'Con «Tenis» escrito y «Después del pago» elegido, el veredicto se '
        'calcula para el día siguiente al pago.',
      );
      await f.check(
        'Después del pago dice «${_verdict(after.verdict)}»',
        () => expect(f.shows(_verdict(after.verdict)), isTrue),
      );
      await f.tap('Otra fecha');
      await f.step(
        '«Otra fecha» abre un calendario: solo deja elegir desde hoy y hasta '
        'dos meses adelante.',
      );
      await _pickDay(f, 9);
      await f.step(
        'Elegido el 9, el botón dice «9 oct» y el veredicto es para ese día.',
      );
      await f.check('La fecha elegida queda en el botón', () {
        expect(f.shows(dayShortMonth(DateTime(2026, 10, 9))), isTrue);
      });
      await f.type('¿Cuánto cuesta?', '2000000');
      await f.tapFound(
        find.descendant(
          of: find.byWidgetPredicate((Widget w) => w is SegmentedButton),
          matching: find.text('Hoy'),
        ),
      );
      final PurchaseCheck big = checkPurchase(
        ledger,
        price: 2000000,
        date: ledger.today,
        label: 'Tenis',
        atLeast: 30,
      );
      await f.top();
      await f.step(
        'Con 2.000.000 y «Hoy», el veredicto cambia de color y dice cuánto '
        'te faltaría antes del pago.',
      );
      await f.check('Con 2.000.000 dice «${_verdict(big.verdict)}»', () {
        expect(big.verdict, PurchaseVerdict.short);
        expect(f.shows(_verdict(big.verdict)), isTrue);
      });
      await f.check(
        'Te faltarían ${_money(own, -big.lowest)}, lo que calcula la app',
        () => expect(f.screenText, contains(_money(own, -big.lowest))),
      );
      await f.back();
      await f.check('Probar una compra no registra nada', () {
        expect(own.snapshot!.entries.length, entries);
        expect(own.ledger!.freeUntilPayday, ledger.freeUntilPayday);
      });
      await f.tap('Ver');
      await f.step(
        'De vuelta en Inicio el precio se borró; «Ver» sin precio abre la '
        'misma página, esperando que lo escribas.',
      );
      await f.check('Sin precio no hay veredicto', () {
        expect(f.shows('¿Cuánto cuesta?'), isTrue);
        for (final PurchaseVerdict v in PurchaseVerdict.values) {
          expect(f.shows(_verdict(v)), isFalse);
        }
      });
    }),
  ),
  AppFlow(
    '02-04-ver-el-cierre-de-la-quincena',
    'Ver el cierre de la quincena',
    area: 'Inicio',
    goal:
        'Ya me pagaron y quiero ver cómo me fue en la quincena que terminó '
        'y qué viene.',
    data: fullAccount,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final Ledger ledger = own.ledger!;
      final PeriodClose close = closePeriod(
        ledger,
        hasGoals: own.snapshot!.goals.isNotEmpty,
      )!;
      await f.reveal(find.text('Cierre de la quincena'));
      await f.step(
        'En la semana después del pago, «Próximos días» suma el botón '
        '«Cierre de la quincena».',
      );
      await f.tap('Cierre de la quincena');
      await f.page(
        '«Cierre de la quincena»: cuánto gastaste y en qué, lo comprometido '
        'hasta el próximo pago y una acción posible.',
      );
      await f.check('Dice que gastaste ${_money(own, close.spent)}', () {
        expect(f.screenText, contains(_money(own, close.spent)));
      });
      final String category = close.changes.first.category.labelIn('es');
      await f.tap(category);
      await f.step(
        'Toca «$category»: una hoja lista los pagos de esa categoría en la '
        'quincena, con su día y monto.',
      );
      await f.check('La hoja muestra los pagos de $category con su monto', () {
        for (final Movement m in close.movementsOf(
          ledger,
          close.changes.first.category,
        )) {
          expect(f.screenText, contains(_money(own, m.amount)));
        }
      });
      await f.back();
      await f.tap('Ver los próximos 30 días');
      await f.step(
        '«Ver los próximos 30 días» lleva a la gráfica del saldo hasta un '
        'mes adelante.',
      );
      await f.check('Abre «Próximos 30 días»', () {
        expect(f.shows('Próximos 30 días'), isTrue);
      });
    }),
  ),
  AppFlow(
    '02-05-atender-lo-que-esta-por-hacer',
    'Atender lo que está por hacer',
    area: 'Inicio',
    goal:
        'Quiero saber qué me falta hacer para que la cifra sea cierta y '
        'hacerlo desde Inicio.',
    data: fullAccount,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final int pending = own.pendingInbox.length;
      final int free = own.ledger!.freeUntilPayday;
      await f.reveal(find.text('POR HACER'));
      await f.step(
        '«Por hacer» pone primero lo más urgente, con su botón: revisar lo '
        'que la app capturó. Lo demás queda en «Después».',
      );
      await f.check(
        'La tarea dice los $pending movimientos que esperan revisión',
        () => expect(
          f.shows('Revisa $pending movimientos para actualizar tu saldo'),
          isTrue,
        ),
      );
      await f.tap('Revisar');
      await f.step(
        '«Revisar» lleva a «Por revisar», donde están los movimientos que '
        'capturó la app esperando que los confirmes.',
      );
      await f.check('Abre «Por revisar»', () {
        expect(f.shows('Por revisar'), isTrue);
      });
      await f.back();
      await f.tap('Repartir');
      await f.page(
        'En «Después», «Repartir» abre «Reparte tu quincena»: la plata que '
        'llegó propuesta en sobres, para ajustarlos antes de gastar.',
      );
      await f.check('Abre «Reparte tu quincena»', () {
        expect(f.shows('Reparte tu quincena'), isTrue);
      });
      await f.tap('Guardar el reparto');
      await f.step(
        'La propuesta pone 150.000 para «Viaje a Cartagena», más de lo que '
        'hay para repartir: al guardar, la app avisa y deja «Ajustar» o '
        '«Guardar así».',
      );
      await f.check('Avisa que los sobres pasan lo que hay', () {
        expect(f.shows('Asignas más de lo que hay'), isTrue);
      });
      await f.tap('Ajustar');
      await f.type('Viaje a Cartagena', '7961');
      await f.page(
        '«Ajustar» vuelve a los sobres. Con 7.961 para el viaje, lo que hay '
        'para repartir queda asignado completo.',
        most: 2,
      );
      await f.tap('Guardar el reparto');
      await f.top();
      await f.step(
        'Guardado el reparto, Inicio ya no pide repartir y la tarjeta suma '
        'la línea «Apartado en sobres», que deja en cero lo que puedes '
        'gastar.',
      );
      await f.check('Ya no está la tarea de repartir la quincena', () {
        expect(own.paidWithoutPlan, isFalse);
        expect(f.shows('Repartir'), isFalse);
      });
      await f.check(
        'Los ${_money(own, free)} quedaron en el sobre y lo que puedes '
        'gastar quedó en cero',
        () {
          final Ledger now = own.ledger!;
          expect(now.setAside, free);
          expect(now.freeUntilPayday, 0);
        },
      );
    }),
  ),
  AppFlow(
    '02-06-registrar-el-pago-que-no-aparece',
    'Registrar el pago que no aparece',
    area: 'Inicio',
    goal:
        'Me pagaron el 30 pero la app no lo vio; quiero anotarlo para que '
        'cuente.',
    data: _newcomer,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final DateTime late = own.projection!.latePay!;
      await f.page(
        'Una cuenta nueva: la cifra dice «Provisional» y «Por hacer» pide '
        'registrar el pago del 30, agregar pagos fijos y una tasa.',
        most: 3,
      );
      await f.check('Pide registrar el pago del ${dayMonth(late)}', () {
        expect(f.shows('Registra tu pago del ${dayMonth(late)}'), isTrue);
      });
      await f.tap('Registrar');
      await f.step(
        '«Registrar» abre el formulario ya en «Ingreso», pero con el monto, '
        'la categoría y la fecha por llenar.',
      );
      await f.check('El formulario abre como ingreso', () {
        expect(f.shows('Agregar movimiento'), isTrue);
        expect(f.shows('Salario'), isTrue);
      });
      await f.type('Monto', '2400000');
      await f.tap('Salario');
      await f.type('¿De dónde?', 'Nómina');
      await _openDate(f);
      await f.tapTip('Mes anterior');
      await f.step(
        'Con 2.400.000, «Salario» y «Nómina», toca «Fecha» y vuelve a '
        'septiembre en el calendario para elegir el 30.',
      );
      await _pickDay(f, 30);
      await f.step(
        'La fecha queda en el 30 de septiembre; falta tocar «Guardar».',
      );
      await f.tap('Guardar');
      await f.page(
        'De vuelta en Inicio el pago cuenta: la cifra subió y la tarea '
        'cambió a «Te llegó la quincena», con «Repartir».',
        most: 2,
      );
      await f.check('Ya no pide registrar el pago', () {
        expect(own.projection!.latePay, isNull);
        expect(f.shows('Registra tu pago del ${dayMonth(late)}'), isFalse);
      });
      await f.check('El pago quedó como salario del 30 de septiembre', () {
        final Entry e = _entry(own, 'Nómina', on: DateTime(2026, 9, 30));
        expect(e.category, 'salary');
        expect(e.amount, Decimal.parse('2400000'));
      });
      final String before = _money(own, free);
      final String after = _money(own, free + 2400000);
      await f.check('Lo que puedes gastar pasó de $before a $after', () {
        expect(own.ledger!.freeUntilPayday, free + 2400000);
      });
      await f.check('Inicio ahora propone repartir la quincena que llegó', () {
        expect(f.shows('Te llegó la quincena: ${pesos(2400000)}'), isTrue);
      });
    }),
  ),
  AppFlow(
    '02-07-decir-mis-pagos-fijos',
    'Decirle a la app mis pagos fijos',
    area: 'Inicio',
    goal:
        'La cifra dice «Provisional»; quiero decirle a la app que no tengo '
        'pagos fijos para que deje de serlo.',
    data: _newcomer,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      await f.reveal(find.text('Agrega tus pagos fijos'));
      await f.step(
        '«Agrega tus pagos fijos» avisa que uno de tus gastos parece fijo y '
        'que revisarlo vuelve cierta la cifra.',
      );
      await f.check('Dice que un gasto parece pago fijo', () {
        expect(f.shows('Uno parece pago fijo: revísalo'), isTrue);
      });
      await f.tap('Agregar');
      await f.page(
        'Toca «Agregar»: abre «Pagos fijos», con Rappi propuesto porque se '
        'cobró parecido tres meses, y «No tengo pagos fijos».',
      );
      await f.tap('No es fijo');
      await f.step(
        'Toca «No es fijo» en Rappi: deja de proponerlo y queda «No tengo '
        'pagos fijos».',
      );
      await f.check('Rappi ya no se propone como pago fijo', () {
        expect(own.detective.notRecurring, contains('rappi'));
        expect(own.recurringGuesses, isEmpty);
      });
      await f.tap('No tengo pagos fijos');
      await f.step(
        'Toca «No tengo pagos fijos»: un aviso abajo confirma que lo que '
        'puedes gastar ya no es provisional.',
      );
      await f.check('Muestra el aviso de que ya no es provisional', () {
        expect(
          f.shows('Listo. Lo que puedes gastar ya no es provisional.'),
          isTrue,
        );
      });
      await f.back();
      await f.top();
      await f.step(
        'En Inicio ya no está «Provisional» bajo la cifra ni la tarea de '
        'pagos fijos.',
      );
      await f.check(
        'La respuesta quedó guardada y la cifra ya no es provisional',
        () {
          expect(own.noFixedPayments, isTrue);
          expect(own.provisional, isFalse);
          expect(f.shows('Provisional: faltan tus pagos fijos'), isFalse);
        },
      );
      await f.check('La cifra no cambia: no había pagos que restar', () {
        expect(own.ledger!.freeUntilPayday, free);
      });
    }),
  ),
  AppFlow(
    '02-08-poner-la-tasa-que-falta',
    'Poner la tasa que falta',
    area: 'Inicio',
    goal:
        'Tengo euros y la app los cuenta como cero; quiero decirle a cuánto '
        'están para que sumen.',
    data: _newcomer,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      await f.reveal(find.text('Falta la tasa de EUR'));
      await f.step(
        '«Falta la tasa de EUR»: mientras no haya tasa, los euros cuentan '
        'como cero en lo que puedes gastar.',
      );
      await f.check('La app sabe que el EUR no tiene tasa', () {
        expect(own.unconverted.map((Asset a) => a.code), contains('EUR'));
      });
      await f.tap('Ver tasas');
      await f.step(
        '«Ver tasas» abre «Tasas»: el EUR aparece en color de aviso, sin '
        'tasa y contando como cero.',
      );
      await f.tapContaining('Sin tasa para EUR');
      await f.step(
        'Toca la línea del EUR: «Escribir una tasa» pide cuánto vale 1 EUR '
        'en pesos.',
      );
      await f.tester.enterText(find.byType(TextField).last, '4500');
      await settle(f.tester);
      await f.tap('Guardar');
      await f.step(
        'Con 4.500 guardado, la línea dice «1 EUR = \$4.500» y lleva la '
        'marca de tasa escrita a mano.',
      );
      await f.check('La tasa quedó guardada: 1 EUR = 4.500 pesos', () {
        expect(own.rates.rate(Asset.eur, Asset.cop), Decimal.fromInt(4500));
      });
      await f.back();
      await f.top();
      await f.step(
        'En Inicio ya no falta la tasa y la cifra suma los 300 euros a '
        '4.500.',
      );
      await f.check('Ya no hay monedas sin tasa', () {
        expect(own.unconverted, isEmpty);
        expect(f.shows('Falta la tasa de EUR'), isFalse);
      });
      final String after = _money(own, free + 1350000);
      await f.check('Lo que puedes gastar subió 1.350.000, a $after', () {
        expect(own.ledger!.freeUntilPayday, free + 1350000);
      });
    }),
  ),
  AppFlow(
    '02-09-cuando-no-me-alcanza',
    'Ver qué pasa cuando me paso',
    area: 'Inicio',
    goal:
        'Compré algo caro y quiero ver cuánto me falta para llegar al pago, '
        'y deshacerlo si me equivoqué.',
    data: fullAccount,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      await f.tapTip('Agregar movimiento');
      await f.type('Monto', '300000');
      await f.tap('Compras');
      await f.type('¿Dónde o a quién?', 'Bicicleta');
      await f.step(
        'Un gasto de 300.000 en Compras, «Bicicleta», desde Bancolombia: '
        'más de lo que se podía gastar.',
      );
      await f.tap('Guardar');
      await f.step(
        'La tarjeta cambia a «Te faltan», en rojo: lo que hace falta para '
        'llegar al 15 de octubre sin tocar lo comprometido.',
      );
      final int short = free - 300000;
      await f.check(
        'Dice «Te faltan» ${_money(own, -short)}, lo que calcula la app',
        () {
          expect(own.ledger!.freeUntilPayday, short);
          expect(f.shows('Te faltan'), isTrue);
          expect(f.shows(_money(own, -short)), isTrue);
        },
      );
      await f.tap('Movimientos');
      await f.tap('Bicicleta');
      await f.tap('Eliminar');
      await f.step(
        'Para deshacerlo, en Movimientos abre «Bicicleta» y toca '
        '«Eliminar»: la app pregunta antes de borrar.',
      );
      await f.tap('Eliminar');
      await f.tap('Inicio');
      await f.step(
        'Borrado el gasto, Inicio vuelve a «Puedes gastar» con la cifra de '
        'antes.',
      );
      await f.check('Lo que puedes gastar volvió a ${_money(own, free)}', () {
        expect(own.ledger!.freeUntilPayday, free);
        expect(f.shows('Puedes gastar'), isTrue);
      });
    }),
  ),
  AppFlow(
    '02-10-preguntarle-a-mi-plata',
    'Preguntarle a mi plata',
    area: 'Inicio',
    goal:
        'Quiero hacerle una pregunta a la app sobre mi plata, con mis '
        'palabras.',
    data: fullAccount,
    manual: <String>[
      'Las respuestas de Gemini en vivo: tocar cada pregunta sugerida y '
          '«Otra pregunta» con conexión, y revisar que lo que responde '
          'cuadre con Inicio.',
      'El límite de preguntas del día: «Te quedan N preguntas hoy» baja al '
          'preguntar y al llegar a cero no deja seguir.',
    ],
    _dbg((FlowRun f) async {
      await f.reveal(find.text('PREGÚNTALE A TU PLATA'));
      await f.step(
        '«Pregúntale a tu plata» ofrece tres preguntas listas y «Otra '
        'pregunta», cada una con su flecha.',
      );
      await f.tap('Otra pregunta');
      await f.step(
        '«Otra pregunta» abre la conversación vacía: preguntas sugeridas, '
        'el campo para escribir y «Qué ve Gemini».',
      );
      await f.check('Abre «Pregúntale a tu plata» sin preguntar nada aún', () {
        expect(f.shows('Pregúntale a tu plata'), isTrue);
        expect(f.shows('Qué ve Gemini'), isTrue);
      });
      await f.tapTip('Qué ve Gemini');
      await f.page(
        'El ícono de información explica qué ve Gemini de tus cuentas y qué '
        'no.',
        most: 2,
      );
      await f.back();
      await f.back();
      // Asked at once, the question waits on Gemini: no settling until the
      // answer, or the word that there is none, arrives.
      final Finder question = find.text(
        '¿Cuánto puedo gastar antes de que me paguen?',
      );
      await f.reveal(question);
      await f.tester.tap(question.last);
      await f.waitFor(find.textContaining('No pude responder'));
      await f.step(
        'Una pregunta lista se hace de una vez. Aquí no hay conexión con '
        'Gemini, así que la conversación dice «No pude responder esta vez».',
      );
      await f.check('Sin Gemini, la app dice que no pudo responder', () {
        expect(f.shows('No pude responder esta vez. Prueba de nuevo.'), isTrue);
      });
    }),
  ),
  AppFlow(
    '02-11-moverme-desde-inicio',
    'Moverme desde Inicio',
    area: 'Inicio',
    goal:
        'Quiero llegar rápido desde Inicio a lo pendiente, a los ajustes, '
        'a una cuenta y a todos mis movimientos.',
    data: fullAccount,
    _dbg((FlowRun f) async {
      final OwnController own = f.own;
      final int pending = own.pendingInbox.length;
      await f.step(
        'Arriba, la bandeja lleva un número: cuántos movimientos esperan '
        'revisión. Al lado, el engranaje de ajustes.',
      );
      await f.check('La bandeja dice $pending, lo que espera revisión', () {
        expect(
          find.descendant(
            of: find.byTooltip('Por revisar'),
            matching: find.text('$pending'),
          ),
          findsOneWidget,
        );
      });
      await f.tapTip('Por revisar');
      await f.step('La bandeja abre «Por revisar».');
      await f.back();
      await f.tapTip('Ajustes');
      await f.step('El engranaje abre «Ajustes».');
      await f.check('Abre «Ajustes»', () => expect(f.shows('Ajustes'), isTrue));
      await f.back();
      await f.reveal(find.text('TUS CUENTAS'));
      await f.step(
        '«Tus cuentas» lista cada cuenta con su saldo; la tarjeta dice lo '
        'que debes y el cupo libre.',
      );
      await f.tap('Efectivo');
      await f.step('Tocar una cuenta abre su página: saldo y sus movimientos.');
      await f.back();
      await f.reveal(find.text('Ver todos'));
      await f.step(
        '«Últimos movimientos» muestra los cinco más recientes; «Ver todos» '
        'lleva a la lista completa.',
      );
      await f.check('Muestra los cinco movimientos más recientes', () {
        for (final Entry e in visibleEntries(own).take(5)) {
          if (e.payee.isEmpty) continue;
          expect(f.shows(e.payee), isTrue, reason: e.payee);
        }
      });
      await f.tap('Ver todos');
      await f.step(
        '«Ver todos» cambia a la pestaña Movimientos y la abre arriba: el '
        'buscador y lo de hoy primero.',
      );
      await f.check('Movimientos abre arriba, no donde iba Inicio', () {
        expect(f.shows('Buscar movimientos'), isTrue);
        expect(f.shows('HOY'), isTrue);
      });
    }),
  ),
];

/// [minor] in the ledger's unit, as the app writes it.
String _money(OwnController own, int minor) => pesos(own.ledger!.major(minor));

/// What the purchase check says, as its title.
String _verdict(PurchaseVerdict v) => switch (v) {
  PurchaseVerdict.fits => 'Te alcanza, según lo que sabe la app',
  PurchaseVerdict.belowCushion => 'Quedarías por debajo de tu colchón',
  PurchaseVerdict.short => 'No alcanza antes del pago',
};

/// Every fixed payment with its next date, to tell whether one moved.
List<String> _fixed(OwnController own) => <String>[
  for (final RecurringCharge r in own.recurring) '${r.name} ${r.nextDate}',
];

/// The movement paid to or received from [payee], on [on] when given.
Entry _entry(OwnController own, String payee, {DateTime? on}) =>
    own.snapshot!.entries.firstWhere(
      (Entry e) =>
          e.payee == payee &&
          (on == null ||
              (e.date.year == on.year &&
                  e.date.month == on.month &&
                  e.date.day == on.day)),
    );

/// Someone two weeks into the app, on the 3rd of October: the pay of the
/// 30th has not shown up, no fixed payment is told yet though Rappi is
/// charged about the same each month, and 300 euros have no rate.
Future<QuincenaStore> _newcomer() async {
  final QuincenaStore store = await emptyStore();
  await store.ensureCategories();
  await store.saveProfile(
    Profile(
      name: 'Diego',
      base: Asset.cop,
      schedule: const TwiceMonthly(),
      pay: Decimal.parse('2400000'),
    ),
  );
  await store.setSetting('app.mode', 'own');
  final Account bank = await store.addAccount(
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: Decimal.parse('200000'),
    institution: 'Bancolombia',
  );
  await store.addAccount(
    name: 'Efectivo',
    kind: AccountKind.cash,
    asset: Asset.cop,
    opening: Decimal.parse('50000'),
  );
  await store.addAccount(
    name: 'Cuenta en euros',
    kind: AccountKind.bank,
    asset: Asset.eur,
    opening: Decimal.parse('300'),
    institution: 'Wise',
    spendable: true,
  );
  Future<void> add(
    String amount,
    DateTime on,
    String payee,
    String category, {
    EntryKind kind = EntryKind.expense,
  }) => store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse(amount),
    kind: kind,
    date: on,
    category: category,
    payee: payee,
  );
  await add(
    '2400000',
    DateTime(2026, 9, 15, 8),
    'Nómina',
    'salary',
    kind: EntryKind.income,
  );
  for (final int month in <int>[7, 8, 9]) {
    await add('45000', DateTime(2026, month, 8, 20), 'Rappi', 'restaurants');
  }
  await add('1200000', DateTime(2026, 9, 16, 9), 'Arriendo', 'housing');
  await add('86000', DateTime(2026, 10, 1, 18), 'D1', 'groceries');
  await add('18000', DateTime(2026, 10, 2, 7), 'Uber', 'transport');
  return store;
}

/// Opens the calendar of the movement's «Fecha».
Future<void> _openDate(FlowRun f) => f.tapFound(
  find.ancestor(of: find.text('Fecha'), matching: find.byType(InkWell)).first,
);

/// Picks [day] of the month the open date picker shows, and accepts it.
Future<void> _pickDay(FlowRun f, int day) async {
  await f.tester.tap(find.text('$day').last);
  await settle(f.tester);
  await f.tester.tap(
    find.byWidgetPredicate(
      (Widget w) => w is Text && (w.data == 'ACEPTAR' || w.data == 'Aceptar'),
    ),
  );
  await settle(f.tester);
}
