// Flows of Inicio (02) and Movimientos (03).
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/categories.dart';
import 'package:quincena/domain/decisions.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/projection.dart';
import 'package:quincena/domain/plan.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/repeats.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/inbox_page.dart' show InboxCard;
import 'package:quincena/ui/own/look.dart';
import 'package:quincena/ui/own/movement_filters.dart' show ActiveFilters;
import 'package:quincena/ui/own/movement_list.dart';

import '../../test/own_flow_test.dart' show settle;
import '../../test_screens/accounts.dart' show screensNow;
import '../tour.dart';
import 'flow.dart';

final List<AppFlow> inicioYMovimientosFlows = <AppFlow>[
  AppFlow(
    '02-01-entender-lo-que-puedo-gastar',
    'Entender lo que puedo gastar',
    area: 'Inicio',
    goal:
        'Quiero saber cuánta plata puedo gastar hasta que me paguen y de '
        'dónde sale esa cifra.',
    data: fullAccount,
    (FlowRun f) async {
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
        'La tarjeta muestra cada línea de la suma: lo que hay, lo que debes en '
        'tarjetas, los pagos y la reserva',
        () {
          final int debt = own.spendableCardDebt;
          for (final int line in <int>[
            ledger.balance + debt,
            -debt,
            -ledger.committedUntilPayday,
            -ledger.reserved,
          ]) {
            expect(f.shows(_money(own, line)), isTrue, reason: '$line');
          }
          expect(
            ledger.balance +
                debt -
                debt -
                ledger.committedUntilPayday -
                ledger.cushion -
                ledger.setAside -
                ledger.reserved,
            ledger.freeUntilPayday,
          );
          // No cushion and nothing in envelopes: no line for them.
          expect(f.shows('Colchón'), isFalse);
          expect(f.shows('Apartado en sobres'), isFalse);
        },
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
        'Lo que dice cada cuenta en pesos es su saldo de hoy, el mismo de '
        'Cuentas',
        () {
          for (final Account a in own.accounts) {
            if (!a.spendable || a.asset != Asset.cop) continue;
            expect(
              own.spendableParts[a.id],
              ledger.minor(own.balances[a.id]!.amount.toDouble()),
              reason: a.name,
            );
          }
        },
      );
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
    },
  ),
  AppFlow(
    '02-02-ver-los-proximos-dias',
    'Ver los próximos días',
    area: 'Inicio',
    goal:
        'Quiero ver qué pagos vienen antes de la quincena y probar qué pasa '
        'si muevo uno de fecha.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Projection projection = own.projection!;
      final ProjectedDay low = projection.lowestBeforePayday;
      final int free = projection.free(low);
      final int reserve = own.ledger!.reserved;
      await f.reveal(find.text('Próximos días'));
      await f.step(
        '«Próximos días» dice lo mínimo que tendrás libre antes del pago, '
        'contado como «Puedes gastar»; aparte, lo que sigue guardado en la '
        'reserva; y los cobros que vienen, con el día y el monto.',
      );
      await f.check(
        'Lo mínimo libre es ${_money(own, free)} el ${dayMonth(low.date)}, '
        'la misma cifra que «Puedes gastar»',
        () {
          expect(free, own.ledger!.freeUntilPayday);
          expect(
            f.screenText,
            contains(
              'Lo mínimo que tendrás libre será ${_money(own, free)} el '
              '${dayMonth(low.date)}',
            ),
          );
        },
      );
      await f.check(
        'Dice aparte los ${_money(own, reserve)} de la reserva, que siguen '
        'en las cuentas',
        () => expect(
          f.screenText,
          contains(
            'Aparte siguen guardados ${_money(own, reserve)} en tu reserva.',
          ),
        ),
      );
      await f.check(
        'Inicio mira los mismos 30 días que «Ver 30 días»: ninguno toca lo '
        'apartado, así que no avisa nada, y sin colchón no habla de él',
        () {
          expect(own.ledger!.cushion, 0);
          expect(
            projection.days.last.date,
            own.today.add(const Duration(days: 30)),
          );
          expect(projection.firstTouchingKept, isNull);
          expect(f.screenText, isNot(contains('tocar lo apartado')));
          expect(f.screenText, isNot(contains('colchón')));
        },
      );
      await f.tap('Ver 30 días');
      await f.page(
        'Toca «Ver 30 días»: la gráfica del saldo día por día durante un '
        'mes, con el día del pago y la línea de lo apartado, «Ningún día '
        'tocas lo apartado en estos 30 días.», como calla Inicio, y debajo lo '
        'que pasa cada día.',
      );
      await f.check('Abre «Próximos 30 días»', () {
        expect(f.shows('Próximos 30 días'), isTrue);
      });
      await f.check(
        'Dice lo mismo que Inicio: lo mismo libre y ningún día que toque lo '
        'apartado',
        () {
          expect(
            f.screenText,
            contains(
              'Lo mínimo libre antes del pago: ${_money(own, free)} '
              'el ${dayShortMonth(low.date)}',
            ),
          );
          expect(
            f.shows('Ningún día tocas lo apartado en estos 30 días.'),
            isTrue,
          );
          expect(f.screenText, isNot(contains('colchón')));
        },
      );
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
      // Dragged from today to the payday's line, twelve days of thirty in.
      await f.reveal(chart);
      final Rect line = f.tester.getRect(chart.first);
      await f.tester.dragFrom(
        Offset(line.left + 2, line.center.dy),
        Offset(line.width * 12 / 30 - 2, 0),
      );
      await settle(f.tester);
      final DateTime payday = DateTime(2026, 10, 15);
      await f.top();
      await f.step(
        'Arrastra el dedo por la gráfica desde «Hoy» hasta la línea de «Tu '
        'pago»: arriba de la lista queda el jueves 15, el día del pago.',
      );
      await f.check(
        'Al soltar, el día elegido es el ${weekdayDayMonth(payday)}',
        () {
          final String text = f.screenText;
          expect(text, contains(weekdayDayMonth(payday)));
          expect(
            text.indexOf(weekdayDayMonth(payday)),
            lessThan(text.indexOf(weekdayDayMonth(DateTime(2026, 10, 4)))),
          );
        },
      );
      final DateTime day18 = DateTime(2026, 10, 18);
      await f.tap(weekdayDayMonth(day18));
      await f.top();
      await f.step(
        'Tocar un día de la lista también lo elige: el domingo 18, con el '
        'cobro esperado de Estudio Norte, pasa arriba.',
      );
      await f.check('El día tocado quedó arriba de la lista', () {
        final String text = f.screenText;
        expect(text, contains(weekdayDayMonth(DateTime(2026, 10, 4))));
        expect(
          text.indexOf(weekdayDayMonth(day18)),
          lessThan(text.indexOf(weekdayDayMonth(DateTime(2026, 10, 4)))),
        );
      });
      final List<String> fixed = _fixed(own);
      final int committed = own.ledger!.committedUntilPayday;
      await f.tapFound(find.byTooltip('Mover en la simulación').first);
      await f.step(
        'El ícono de calendario junto a un cobro abre «Mover en la '
        'simulación»: un calendario para probar pagarlo otro día.',
      );
      await _tapPicker(f, 'Cancelar');
      await f.check('«Cancelar» no prueba nada', () {
        expect(f.shows('Quitar lo que pruebas'), isFalse);
      });
      await f.tapFound(find.byTooltip('Mover en la simulación').first);
      await _pickDay(f, 14);
      await f.top();
      await f.step(
        'Con el Televisor movido al 14 aparece «Estás probando: nada de esto '
        'se guarda ni cambia tus pagos.» y la línea punteada cambia.',
      );
      await f.check('Aparece el aviso de que solo es una prueba', () {
        expect(f.shows('Quitar lo que pruebas'), isTrue);
      });
      // The 5th, the Televisor's day: what is sure stays, and what is tried
      // gets its instalment back.
      final ProjectedDay day5 = projection.days.firstWhere(
        (ProjectedDay d) => d.date == DateTime(2026, 10, 5),
      );
      final int tv = -day5.events
          .firstWhere((ProjectedEvent e) => e.label == 'Televisor')
          .amount;
      final String tried =
          'Quedan ${_money(own, day5.sure)} · '
          '${_money(own, projection.free(day5))} libres · con lo que pruebas, '
          '${_money(own, day5.likely + tv)}';
      // The 5th is further down the list: it is built once in view.
      await f.reveal(find.text(weekdayDayMonth(DateTime(2026, 10, 5))));
      await f.check('El 5 oct dice «$tried»: la cuota vuelve al saldo', () {
        expect(f.screenText, contains(tried));
      });
      await f.check('Probar otra fecha no cambia los pagos ni la cifra', () {
        expect(_fixed(own), fixed);
        expect(own.ledger!.committedUntilPayday, committed);
      });
      await f.tap('Quitar lo que pruebas');
      await f.step(
        'Toca «Quitar lo que pruebas»: el aviso se va y la gráfica vuelve a '
        'lo que está programado.',
      );
      await f.check('Ya no hay nada en prueba', () {
        expect(f.shows('Quitar lo que pruebas'), isFalse);
        expect(f.screenText, isNot(contains(tried)));
      });
      await f.check(
        'Sin nada en prueba, ningún día dice «con lo que pruebas»: lo de más '
        'es lo que esperas recibir',
        () => expect(f.screenText, isNot(contains('con lo que pruebas'))),
      );
      await f.tap('¿Me alcanza?');
      await f.step(
        'El botón «¿Me alcanza?» de arriba convierte la página en la prueba '
        'de una compra: pide el precio, qué es y cuándo.',
      );
      await f.check('La página pasa a probar una compra', () {
        expect(f.shows('¿Cuánto cuesta?'), isTrue);
        expect(f.shows('Después del pago'), isTrue);
      });
      await f.tapTip('Cierre de la quincena');
      await f.step(
        'El ícono de recibo, arriba a la derecha, abre «Cierre de la '
        'quincena»: lo que pasó en la quincena anterior.',
      );
      await f.check('Abre «Cierre de la quincena»', () {
        expect(f.shows('Qué cambió'), isTrue);
      });
    },
  ),
  AppFlow(
    '02-03-saber-si-me-alcanza',
    'Saber si me alcanza para algo',
    area: 'Inicio',
    goal:
        'Vi unos tenis y quiero saber si me alcanza para comprarlos hoy o si '
        'mejor espero al pago.',
    data: fullAccount,
    (FlowRun f) async {
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
        'Toca «Ver»: 120.000 es más de los '
        '${_money(own, ledger.freeUntilPayday)} que puedes gastar, así que '
        'dice «Te alcanza, pero tocando lo apartado» y cuánto sale de la '
        'reserva; debajo, la comparación con esperar al pago y los días que '
        'vienen.',
      );
      await f.check(
        'Para hoy dice «${_verdict(today.verdict)}», como calcula la app',
        () => expect(f.shows(_verdict(today.verdict)), isTrue),
      );
      await f.check(
        'Como toca lo apartado, no habla de lo libre sino de las cuentas: '
        '«En tus cuentas quedarían mínimo ${_money(own, today.lowest)}»',
        () => expect(
          f.screenText,
          contains(
            'En tus cuentas quedarían mínimo ${_money(own, today.lowest)}',
          ),
        ),
      );
      await f.check(
        'Con 120.000, más de los ${_money(own, ledger.freeUntilPayday)} que '
        'puedes gastar, no dice que te alcanza',
        () {
          expect(today.verdict, isNot(PurchaseVerdict.fits));
          expect(f.shows(_verdict(PurchaseVerdict.fits)), isFalse);
        },
      );
      final int fromReserve = 120000 - ledger.freeUntilPayday;
      await f.check(
        'Dice de dónde sale lo que falta: ${_money(own, fromReserve)} de los '
        '${_money(own, ledger.reserved)} de la reserva',
        () {
          expect(today.verdict, PurchaseVerdict.takesApart);
          expect(today.usesReserve, fromReserve);
          expect(
            f.screenText,
            contains(
              'Es más de los ${_money(own, ledger.freeUntilPayday)} que '
              'puedes gastar hasta el 15 de octubre: usarías '
              '${_money(own, fromReserve)} de tu reserva de ingresos '
              'variables.',
            ),
          );
        },
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
      await _tapPicker(f, 'Cancelar');
      await f.check('«Cancelar» deja elegido «Después del pago»', () {
        final SegmentedButton<Object?> when = f.tester.widget(
          find.byWidgetPredicate((Widget w) => w is SegmentedButton),
        );
        expect(when.selected.single.toString(), contains('afterPay'));
        expect(f.shows(_verdict(after.verdict)), isTrue);
      });
      await f.tap('Otra fecha');
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
      await f.back();
      // The keyboard's own key does what «Ver» does.
      await f.reveal(find.widgetWithText(TextField, 'Precio'));
      await enterTextIn(
        f.tester,
        find.widgetWithText(TextField, 'Precio'),
        '50000',
      );
      await pressKeyIn(
        f.tester,
        find.widgetWithText(TextField, 'Precio'),
        TextInputAction.go,
      );
      await settle(f.tester);
      await f.step(
        'La tecla «Ir» del teclado hace lo mismo que «Ver»: abre «¿Me '
        'alcanza?» con los 50.000.',
      );
      await f.check('La tecla del teclado abre la prueba con el precio', () {
        expect(_fieldShows('¿Cuánto cuesta?', '50.000'), findsOneWidget);
      });
    },
  ),
  AppFlow(
    '02-04-ver-el-cierre-de-la-quincena',
    'Ver el cierre de la quincena',
    area: 'Inicio',
    goal:
        'Ya me pagaron y quiero ver cómo me fue en la quincena que terminó '
        'y qué viene.',
    data: fullAccount,
    (FlowRun f) async {
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
      final CategoryChange first = close.changes.first;
      final String category = first.category.labelIn('es');
      await f.check(
        'Lo que más cambió es $category: '
        '${_money(own, first.before ?? 0)} antes, ${_money(own, first.now)} ahora',
        () {
          expect(f.screenText, contains(_money(own, first.now)));
          expect(f.screenText, contains(_money(own, first.difference)));
        },
      );
      await f.tap(category);
      await f.step(
        'Toca «$category», que bajó a \$0: la hoja dice que en esta quincena '
        'no hubo pagos de $category y muestra los de la anterior.',
      );
      await f.check('La hoja no queda vacía: trae los pagos de antes', () {
        expect(close.movementsOf(ledger, first.category), isEmpty);
        final List<Movement> before = close.movementsBefore(
          ledger,
          first.category,
        );
        expect(before, isNotEmpty);
        expect(
          f.shows(
            'En esta quincena no hubo pagos de $category. Estos son los de '
            'la anterior:',
          ),
          isTrue,
        );
        for (final Movement m in before) {
          expect(f.screenText, contains(_money(own, -m.amount)));
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
    },
  ),
  AppFlow(
    '02-05-atender-lo-que-esta-por-hacer',
    'Atender lo que está por hacer',
    area: 'Inicio',
    goal:
        'Quiero saber qué me falta hacer para que la cifra sea cierta y '
        'hacerlo desde Inicio.',
    data: fullAccount,
    (FlowRun f) async {
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
      // What the page proposes: the day to day first, the trip with what
      // is left, never past the money there is.
      final List<Envelope> proposed = proposeEnvelopes(
        own.ledger!,
        goals: own.goalShares,
        last: own.lastPlan,
        dailyName: '',
      );
      final int daily = proposed
          .where((Envelope e) => e.kind == EnvelopeKind.daily)
          .fold(0, (int sum, Envelope e) => sum + e.amount);
      final int apart = proposed
          .where((Envelope e) => e.setAside)
          .fold(0, (int sum, Envelope e) => sum + e.amount);
      await f.page(
        '«Repartir» abre «Reparte tu quincena»: hay ${_money(own, free)} '
        'para repartir, con la suma que lo explica. La propuesta pone primero '
        'el día a día y dice que esta quincena no alcanza para el viaje, que '
        'puede esperar a la próxima.',
      );
      await f.check('Abre «Reparte tu quincena»', () {
        expect(f.shows('Reparte tu quincena'), isTrue);
      });
      await f.check(
        'El día a día recibe ${_money(own, daily)} primero y nada se pasa de '
        'los ${_money(own, free)}',
        () {
          expect(daily, greaterThan(0));
          expect(daily + apart, lessThanOrEqualTo(free));
          expect(
            _fieldShows(
              'Día a día',
              formatDecimal(Decimal.fromInt(daily), decimals: 0, trim: true),
            ),
            findsOneWidget,
          );
          expect(f.shows('Te pasas por'), isFalse);
        },
      );
      await f.check('Dice que el viaje no alcanza y puede esperar', () {
        expect(
          f.screenText,
          contains(
            'Esta quincena no alcanza para todo: el día a día va '
            'primero.',
          ),
        );
      });
      await f.tap('Guardar el reparto');
      await f.check('Guarda sin avisar: no se pasa de lo que hay', () {
        expect(f.shows('Asignas más de lo que hay'), isFalse);
      });
      await f.top();
      await f.step(
        'Guardado el reparto, Inicio ya no pide repartir; lo que puedes '
        'gastar sigue siendo para el día a día.',
      );
      await f.check('Ya no está la tarea de repartir la quincena', () {
        expect(own.paidWithoutPlan, isFalse);
        expect(f.shows('Repartir'), isFalse);
      });
      await f.check('Solo lo de las metas sale de lo que puedes gastar: '
          '${_money(own, apart)}', () {
        final Ledger now = own.ledger!;
        expect(now.setAside, apart);
        expect(now.freeUntilPayday, free - apart);
      });
    },
  ),
  AppFlow(
    '02-06-registrar-el-pago-que-no-aparece',
    'Registrar el pago que no aparece',
    area: 'Inicio',
    goal:
        'Me pagaron el 30 pero la app no lo vio; quiero anotarlo para que '
        'cuente.',
    data: _newcomer,
    (FlowRun f) async {
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
        '«Registrar» abre el formulario ya en «Ingreso», pero sin monto ni '
        'categoría y con la fecha en «Hoy»: hay que llenarlos.',
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
    },
  ),
  AppFlow(
    '02-07-decir-mis-pagos-fijos',
    'Decirle a la app mis pagos fijos',
    area: 'Inicio',
    goal:
        'La cifra dice «Provisional»; quiero decirle a la app que no tengo '
        'pagos fijos para que deje de serlo.',
    data: _newcomer,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      await f.reveal(find.text('Agrega tus pagos fijos'));
      await f.step(
        'En «Después», «Agrega tus pagos fijos» dice «Uno parece pago fijo: '
        'revísalo», con «Agregar».',
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
    },
  ),
  AppFlow(
    '02-08-poner-la-tasa-que-falta',
    'Poner la tasa que falta',
    area: 'Inicio',
    goal:
        'Tengo euros y la app los cuenta como cero; quiero decirle a cuánto '
        'están para que sumen.',
    data: _newcomer,
    (FlowRun f) async {
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
      await enterTextIn(f.tester, find.byType(TextField).last, '4500');
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
    },
  ),
  AppFlow(
    '02-09-cuando-no-me-alcanza',
    'Ver qué pasa cuando me paso',
    area: 'Inicio',
    goal:
        'Compré algo caro y quiero ver cuánto me falta para llegar al pago, '
        'y deshacerlo si me equivoqué.',
    data: fullAccount,
    (FlowRun f) async {
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
        expect(f.shows(_money(own, free)), isTrue);
      });
      await f.check('La bicicleta ya no está entre los movimientos', () {
        expect(
          own.snapshot!.entries.where((Entry e) => e.payee == 'Bicicleta'),
          isEmpty,
        );
      });
    },
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
      'El límite de preguntas del día: «Te quedan N de 30 preguntas hoy» '
          'baja al preguntar y al llegar a cero no deja seguir.',
      'Con el teléfono en modo avión, tocar una pregunta lista: debe decir '
          '«Sin conexión a internet…» y no gastar una de las preguntas del '
          'día.',
    ],
    (FlowRun f) async {
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
        expect(f.shows('Te quedan 30 de 30 preguntas hoy'), isTrue);
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
      for (final String asked in <String>[
        '¿Cuánto puedo gastar antes de que me paguen?',
        '¿En qué se me fue la plata este mes?',
        '¿Cuánto tengo en total, con dólares y cripto?',
      ]) {
        final Finder question = find.text(asked);
        await f.reveal(question);
        await f.tester.tap(question.last);
        // The page opens on the conversation as it was, and asks on its
        // first frame: from the next one, only the newest question that got
        // no answer offers to ask it again, once it is done trying.
        await f.tester.pump();
        await f.tester.pump();
        await f.waitFor(find.text('Volver a preguntar'));
        await f.step(
          'Tocar «$asked» la hace de una vez, en la misma conversación. En '
          'esta prueba Gemini no contesta, así que dice «No pude responder '
          'esta vez» con «Volver a preguntar».',
        );
        await f.check('«$asked» queda preguntada, sin respuesta inventada', () {
          expect(f.shows(asked), isTrue);
          expect(
            f.shows('No pude responder esta vez. Prueba de nuevo.'),
            isTrue,
          );
        });
        await f.back();
      }
      await f.tap('Otra pregunta');
      await f.tap('Nueva');
      await f.step(
        'Después de tres preguntas sin respuesta, «Otra pregunta» vuelve a '
        'la misma conversación; «Nueva» la limpia y dice «Te quedan 30 de 30 '
        'preguntas hoy»: las que no se respondieron no se cuentan.',
      );
      await f.check(
        'Las preguntas que no se respondieron no gastan las del día: siguen '
        '30',
        () => expect(f.shows('Te quedan 30 de 30 preguntas hoy'), isTrue),
      );
    },
  ),
  AppFlow(
    '02-11-moverme-desde-inicio',
    'Moverme desde Inicio',
    area: 'Inicio',
    goal:
        'Quiero llegar rápido desde Inicio a lo pendiente, a los ajustes, '
        'a una cuenta y a todos mis movimientos.',
    manual: <String>[
      'Con la captura automática encendida, que el número de la bandeja suba '
          'cuando llega una notificación real del banco.',
    ],
    data: fullAccount,
    (FlowRun f) async {
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
      await f.tap('Nequi');
      await f.step(
        'Tocar Nequi abre su página: el saldo de hoy y sus movimientos, del '
        'más reciente.',
      );
      await f.check(
        'La página de Nequi muestra su saldo y sus movimientos',
        () {
          expect(f.shows(_money(own, 1700)), isTrue);
          expect(f.shows('Crepes & Waffles'), isTrue);
          expect(f.shows('Metro de Medellín'), isTrue);
        },
      );
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
      final Entry newest = visibleEntries(own).first;
      await _open(f, newest);
      await f.step(
        'Tocar uno de los últimos movimientos lo abre ahí mismo para '
        'editarlo, sin ir a Movimientos.',
      );
      await f.check('Abre «Editar movimiento» con ${newest.payee}', () {
        expect(f.shows('Editar movimiento'), isTrue);
        expect(_fieldShows('¿Dónde o a quién?', newest.payee), findsOneWidget);
      });
      await f.back();
      await f.tap('Ver todos');
      await f.step(
        '«Ver todos» cambia a la pestaña Movimientos y la abre arriba: el '
        'buscador y lo de hoy primero.',
      );
      await f.check('Movimientos abre arriba, no donde iba Inicio', () {
        expect(f.shows('Buscar movimientos'), isTrue);
        expect(f.shows('HOY'), isTrue);
      });
    },
  ),
  AppFlow(
    '02-12-mirar-inicio-recien-empezando',
    'Mirar Inicio recién empezando',
    area: 'Inicio',
    goal:
        'Acabo de instalar la app y quiero entender qué me dice Inicio antes '
        'de tener cuentas o historia.',
    data: _noAccounts,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('¿De dónde sale?');
      await f.page(
        '«¿De dónde sale?» sin cuentas: todo da \$0 y «Lo que supone» dice '
        'que no tiene pagos fijos ni sabe cuánto te pagan.',
        most: 2,
      );
      await f.check('Sin cuentas no hay nada que gastar', () {
        expect(own.ledger!.freeUntilPayday, 0);
        expect(own.provisional, isTrue);
      });
      await f.check('Dice lo que supone: sin pagos fijos y sin pago', () {
        expect(f.screenText, contains('No tiene pagos fijos'));
        expect(f.screenText, contains('No sabe cuánto te pagan'));
      });
      await f.back();
      await f.tap('Ver 30 días');
      await f.step(
        '«Próximos 30 días» sin nada programado: la línea plana y, abajo, '
        '«Nada programado en estos días.»',
      );
      await f.check('Dice que no hay nada programado', () {
        expect(f.shows('Nada programado en estos días.'), isTrue);
      });
      await f.tapTip('Cierre de la quincena');
      await f.step(
        'El cierre aún no tiene qué mostrar: explica que aparece cuando haya '
        'una quincena completa, de un pago al siguiente.',
      );
      await f.check('El cierre explica por qué está vacío', () {
        expect(
          f.shows(
            'Todavía no hay una quincena completa registrada. El cierre '
            'aparece cuando haya una, de un pago al siguiente.',
          ),
          isTrue,
        );
      });
    },
  ),
  AppFlow(
    '02-13-ver-en-que-gaste-mas',
    'Ver en qué gasté más esta quincena',
    area: 'Inicio',
    goal:
        'Siento que se me fue más plata en restaurantes y quiero ver cuáles '
        'pagos fueron.',
    data: _eatingOutMore,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger ledger = own.ledger!;
      final PeriodClose close = closePeriod(ledger)!;
      await f.reveal(find.text('Cierre de la quincena'));
      await f.step(
        'En la semana después del pago, «Próximos días» ofrece «Cierre de la '
        'quincena».',
      );
      await f.tap('Cierre de la quincena');
      await f.page(
        'El cierre compara con la quincena anterior: gastaste \$90.000 más y '
        'Restaurantes subió; «Una acción posible» invita a mirar esos pagos.',
        most: 2,
      );
      await f.check(
        'Propone mirar Restaurantes, que pasó de 100.000 a 200.000',
        () {
          expect(close.action, CloseAction.lookAtCategory);
          expect(close.actionCategory, Category.restaurants);
          expect(
            f.screenText,
            contains(
              'Restaurantes pasó de ${pesos(100000)} a ${pesos(200000)} frente '
              'a la quincena anterior.',
            ),
          );
        },
      );
      await f.tap('Ver los pagos');
      await f.step(
        '«Ver los pagos» abre la hoja de Restaurantes de la quincena: Crepes '
        'y Rappi, del más grande al más chico.',
      );
      await f.check('La hoja trae los dos pagos de restaurantes', () {
        expect(f.shows('Restaurantes del 15 sept al 29 sept'), isTrue);
        expect(f.shows(pesos(-110000)), isTrue);
        expect(f.shows(pesos(-90000)), isTrue);
      });
    },
  ),
  AppFlow(
    '02-14-ver-el-dia-que-me-quedo-sin-plata',
    'Ver el día que me quedo sin plata',
    area: 'Inicio',
    goal:
        'Ya me pagaron, pero la matrícula del 8 me deja en rojo; quiero ver '
        'qué día me quedo sin plata y probar pagarla después del pago.',
    data: _runsOutOnThe8th,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger ledger = own.ledger!;
      final DateTime day8 = DateTime(2026, 10, 8);
      final Entry fee = _entry(own, 'Matrícula');
      await f.reveal(find.text('Próximos días'));
      await f.step(
        '«Próximos días» avisa en naranja «El 8 oct te quedarías sin plata.» '
        'y lista la matrícula de \$2.000.000 de ese día.',
      );
      await f.check('El primer día sin plata es el 8 de octubre', () {
        expect(own.projection!.firstTight!.date, day8);
        expect(f.shows('El 8 oct te quedarías sin plata.'), isTrue);
      });
      await f.tap('Cierre de la quincena');
      await f.page(
        'En el cierre, «Qué viene» lista la matrícula y dice en rojo cuánto te '
        'falta; «Una acción posible» avisa del 8 y propone mover un cobro.',
        most: 2,
      );
      final PeriodClose close = closePeriod(ledger)!;
      await f.check(
        'La acción es el día sin plata, que va antes que comparar categorías',
        () {
          expect(close.action, CloseAction.tightDay);
          expect(close.tightDay, day8);
          expect(
            f.screenText,
            contains(
              'El 8 de octubre te quedarías sin plata. Mira qué cobro podrías '
              'mover de fecha.',
            ),
          );
          expect(f.screenText, contains('8 oct · Matrícula'));
        },
      );
      await f.check(
        '«Qué viene» dice «Te faltan ${_money(own, -ledger.freeUntilPayday)} '
        'para llegar al pago», como Inicio, y no un «Puedes gastar» negativo',
        () {
          expect(ledger.freeUntilPayday, lessThan(0));
          expect(
            f.shows(
              'Te faltan ${_money(own, -ledger.freeUntilPayday)} para llegar '
              'al pago',
            ),
            isTrue,
          );
          expect(f.screenText, isNot(contains('Puedes gastar hasta el pago')));
        },
      );
      // The second «Ver los próximos 30 días», under the action.
      await f.tap('Ver los próximos 30 días');
      await f.top();
      await f.step(
        '«Ver los próximos 30 días» de la acción abre la gráfica: el jueves 8 '
        'lleva la marca «Sin plata» y la matrícula, su ícono de calendario.',
      );
      await f.check('El 8 oct está marcado «Sin plata»', () {
        expect(f.shows('Próximos 30 días'), isTrue);
        expect(f.shows('Sin plata'), isTrue);
        expect(f.shows('El 8 oct te quedarías sin plata.'), isTrue);
      });
      await f.tapFound(find.byTooltip('Mover en la simulación').first);
      await _pickDay(f, 16);
      await f.top();
      final ProjectedDay on8 = own.projection!.days.firstWhere(
        (ProjectedDay d) => d.date == day8,
      );
      final String tried =
          'Quedan ${_money(own, on8.sure)} · con lo que pruebas, '
          '${_money(own, on8.sure + 2000000)}';
      await f.step(
        'Con la matrícula movida al 16, después del pago, el 8 dice «con lo '
        'que pruebas, \$1.740.000», pero arriba sigue «te quedarías sin '
        'plata».',
      );
      await f.check('El 8 oct dice «$tried»', () {
        expect(f.screenText, contains(tried));
      });
      await f.check('La prueba no cambia la fecha de la matrícula', () {
        expect(_entry(own, 'Matrícula').date, fee.date);
        expect(own.ledger!.freeUntilPayday, ledger.freeUntilPayday);
      });
    },
  ),
  AppFlow(
    '02-15-mirar-inicio-de-noche',
    'Mirar Inicio con el modo oscuro',
    area: 'Inicio',
    goal:
        'Tengo el teléfono en modo oscuro y quiero leer Inicio y mis '
        'movimientos sin que nada se pierda.',
    data: fullAccount,
    dark: true,
    (FlowRun f) async {
      final OwnController own = f.own;
      final String figure = _money(own, own.ledger!.freeUntilPayday);
      await f.page(
        'Con el teléfono en modo oscuro, Inicio pasa a fondo oscuro con letras '
        'claras; la cifra, la suma y las tareas siguen en su lugar.',
        most: 3,
      );
      await f.check('La app sigue el modo oscuro del teléfono', () {
        expect(_theme(f).brightness, Brightness.dark);
      });
      await f.check('La cifra $figure se lee clara sobre el fondo', () {
        expect(
          _contrast(_inkOf(f, figure), _theme(f).scaffoldBackgroundColor),
          greaterThan(7),
        );
      });
      await f.tap('Movimientos');
      await f.step(
        'Movimientos de noche: los gastos en letra clara, los ingresos en '
        'verde y las transferencias en gris.',
      );
      final String income = pesos(1000000, signed: true);
      await f.check('El ingreso $income se lee sobre el fondo oscuro', () {
        expect(
          _contrast(_inkOf(f, income), _theme(f).scaffoldBackgroundColor),
          greaterThan(4.5),
        );
      });
      await f.tap('Inicio');
      await f.tap('¿De dónde sale?');
      await f.step(
        'La hoja «¿De dónde sale?» también se abre oscura, con la suma y cada '
        'cuenta legibles.',
      );
      await f.check('La hoja dice la misma cifra que Inicio', () {
        expect(f.screenText, contains(figure));
      });
    },
  ),
  AppFlow(
    '03-01-registrar-un-gasto',
    'Registrar un gasto a mano',
    area: 'Movimientos',
    goal:
        'Pagué un almuerzo en efectivo y quiero anotarlo para que lo que '
        'puedo gastar baje.',
    manual: <String>[
      'Con el widget de Quincena en la pantalla de inicio, que después de '
          'guardar el gasto muestre la misma cifra que Inicio («Te faltan» '
          'incluido).',
    ],
    data: fullAccount,
    (FlowRun f) async {
      final int free = f.own.ledger!.freeUntilPayday;
      final int entries = f.own.snapshot!.entries.length;
      final Decimal cash = _held(f.own, 'Efectivo');
      await f.step('Inicio: cuánto puedes gastar antes de anotar el gasto.');
      await f.tapTip('Agregar movimiento');
      await f.step(
        'Toca «Movimiento»: el formulario abre en «Gasto», con Bancolombia, '
        'tu primera cuenta, ya elegida.',
      );
      await f.type('Monto', '32000');
      // The account is a menu: open it and pick Efectivo.
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.step(
        'Escribe 32.000 y abre «Cuenta»: aparecen tus cuentas para elegir de '
        'dónde salió la plata.',
      );
      await f.tapFound(find.text('Efectivo').last);
      await f.tap('Restaurantes');
      await f.type('¿Dónde o a quién?', 'Almuerzo');
      await f.step(
        'Con Efectivo, Restaurantes y «Almuerzo» escrito, el formulario '
        'queda listo para guardar.',
      );
      await f.tap('Guardar');
      await f.step(
        'De vuelta en Inicio la cifra bajó los 32.000 del almuerzo: como era '
        'más de lo que tenías, ahora dice «Te faltan».',
      );
      await f.check('Queda un movimiento más', () {
        expect(f.own.snapshot!.entries.length, entries + 1);
      });
      await f.check('El gasto quedó en Efectivo, en Restaurantes', () {
        final Entry e = f.own.snapshot!.entries.firstWhere(
          (Entry e) => e.payee == 'Almuerzo',
        );
        expect(e.category, 'restaurants');
        expect(e.amount.toString(), '-32000');
        expect(e.accountId, _account(f.own, 'Efectivo').id);
      });
      final String before = pesos(f.own.ledger!.major(free));
      final String after = pesos(f.own.ledger!.major(free - 32000));
      await f.check('Lo que puedes gastar pasó de $before a $after', () {
        expect(f.own.ledger!.freeUntilPayday, free - 32000);
      });
      await f.check(
        'La tarjeta dice «Te faltan» ${pesos(f.own.ledger!.major(32000 - free))}',
        () {
          expect(f.shows('Te faltan'), isTrue);
          expect(f.shows(pesos(f.own.ledger!.major(32000 - free))), isTrue);
        },
      );
      await f.check('El efectivo bajó 32.000', () {
        expect(_held(f.own, 'Efectivo'), cash - Decimal.fromInt(32000));
      });
      await f.tap('Movimientos');
      await f.step(
        'En Movimientos, el almuerzo encabeza «Hoy»: Restaurantes, Efectivo '
        'y −\$32.000.',
      );
      await f.check(
        'Movimientos lo muestra primero, con su categoría y cuenta',
        () {
          expect(visibleEntries(f.own).first.payee, 'Almuerzo');
          expect(f.shows('Restaurantes · Efectivo'), isTrue);
        },
      );
    },
  ),
  AppFlow(
    '03-02-buscar-un-movimiento',
    'Buscar un movimiento',
    area: 'Movimientos',
    goal:
        'Quiero encontrar rápido lo que pagué en el Éxito, lo que gasté en '
        'transporte, todo lo que salió de Nequi y un pago del que solo '
        'recuerdo el monto: \$187.400.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Movimientos');
      await f.page(
        'Movimientos: el buscador arriba, con el embudo de los filtros al '
        'lado, y los movimientos agrupados por día, del más reciente: «Hoy», '
        '«Ayer» y luego cada fecha, cada uno con lo que suman sus '
        'movimientos.',
        most: 3,
      );
      await f.check('Los días van del más reciente al más viejo', () {
        expect(f.shows('HOY'), isTrue);
        expect(f.shows('AYER'), isTrue);
        final List<Entry> shown = visibleEntries(own);
        for (var i = 1; i < shown.length; i++) {
          expect(shown[i].date.isAfter(shown[i - 1].date), isFalse);
        }
      });
      final int today = <Entry>[
        for (final Entry e in own.snapshot!.entries)
          if (!e.isTransfer && DateUtils.isSameDay(e.date, own.today)) e,
      ].fold(0, (int sum, Entry e) => sum + e.amount.toBigInt().toInt());
      await f.check(
        '«Hoy» dice lo que suman sus movimientos: ${_signed(own, today)}',
        () => expect(_dayTotal(f, 'HOY'), _signed(own, today)),
      );
      await f.tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -500),
      );
      await settle(f.tester);
      await f.step(
        'Al bajar por la lista, el botón «Movimiento» se esconde para no '
        'tapar los montos.',
      );
      await f.check('El botón flotante se escondió', () {
        expect(_fabShown(f), isFalse);
      });
      await f.tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 120),
      );
      await settle(f.tester);
      await f.step('Al subir un poco, el botón vuelve.');
      await f.check('El botón flotante volvió', () {
        expect(_fabShown(f), isTrue);
      });
      await f.top();
      for (final (String query, String caption) in <(String, String)>[
        (
          'uber',
          'Escribe «uber» en minúscula: queda solo el Uber del jueves 1 de '
              'octubre, y arriba dice «1 movimiento · −\$15.600».',
        ),
        (
          'exito',
          'Sin tilde, «exito» también encuentra el Éxito Laureles: así se '
              'escribe rápido en el teléfono.',
        ),
        (
          'transporte',
          '«transporte» busca por categoría: Uber y el Metro de Medellín.',
        ),
        (
          'nequi',
          '«nequi» busca por cuenta: los dos gastos pagados desde Nequi.',
        ),
        (
          'ahorro',
          '«ahorro» busca en las notas: la compra de USDT en Binance, que '
              'dice «Ahorro en USDT».',
        ),
        (
          '187400',
          'Sin puntos ni signo, «187400» encuentra el mercado de \$187.400 en '
              'el Éxito: el buscador también busca por monto.',
        ),
      ]) {
        await _search(f, query);
        await f.step(caption);
        final List<Entry> expected = _found(f, query);
        await f.check(
          '«$query» muestra ${expected.length} movimientos, los que coinciden',
          () {
            expect(expected, isNotEmpty);
            expect(_shownIds(f), <String>{
              for (final Entry e in expected) e.id,
            });
          },
        );
      }
      final Entry market = _entryOf(own, 'Éxito Laureles', '-187400');
      await f.check(
        'Arriba dice cuántos encontró y cuánto suman: «1 movimiento · '
        '${_signed(own, -187400)}»',
        () =>
            expect(f.shows('1 movimiento · ${_signed(own, -187400)}'), isTrue),
      );
      for (final String typed in <String>['187.400', r'$187.400']) {
        await _search(f, typed);
        await f.check(
          '«$typed», con puntos o con signo, encuentra lo mismo',
          () {
            expect(_shownIds(f), <String>{market.id});
          },
        );
      }
      await _search(f, 'zapatos rojos');
      await f.step(
        'Si nada coincide, la lista lo dice: «Nada coincide con la '
        'búsqueda.»',
      );
      await f.check('Sin coincidencias, avisa', () {
        expect(f.shows('Nada coincide con la búsqueda.'), isTrue);
        expect(find.byType(MovementRow), findsNothing);
      });
      await f.tapTip('Borrar la búsqueda');
      await f.step(
        'La «x» del buscador borra lo escrito de un toque y vuelven todos los '
        'movimientos.',
      );
      await f.check('Sin búsqueda vuelve la lista completa', () {
        expect(_searchText(f), isEmpty);
        expect(f.shows('HOY'), isTrue);
        expect(f.shows('Nada coincide con la búsqueda.'), isFalse);
      });
      await f.tapTip('Filtrar');
      await f.page(
        'El embudo abre «Filtrar movimientos»: tipo, fechas, cuentas, '
        'categorías y monto. Abajo, el botón dice cuántos movimientos hay.',
        most: 2,
      );
      await f.tapFound(find.widgetWithText(FilterChip, 'Nequi'));
      await f.tap('Ver 2 movimientos');
      await f.step(
        'Con la cuenta «Nequi» elegida, quedan sus dos gastos; bajo el '
        'buscador, la etiqueta «Nequi» dice qué filtra, y arriba, «2 '
        'movimientos · −\$33.300».',
      );
      await f.check('Quedan solo los dos gastos de Nequi', () {
        expect(_shownIds(f), <String>{
          for (final Entry e in visibleEntries(own))
            if (e.accountId == _account(own, 'Nequi').id) e.id,
        });
        expect(f.shows('2 movimientos · ${_signed(own, -33300)}'), isTrue);
        expect(find.widgetWithText(ActionChip, 'Nequi'), findsOneWidget);
      });
      await f.tapFound(find.widgetWithText(ActionChip, 'Nequi'));
      await f.step('Tocar la etiqueta quita el filtro y vuelven todos.');
      await f.check('Sin filtros vuelve la lista completa', () {
        expect(find.byType(ActiveFilters), findsNothing);
        expect(f.shows('HOY'), isTrue);
        expect(f.screenText, isNot(contains('movimientos ·')));
      });
    },
  ),
  AppFlow(
    '03-03-corregir-un-movimiento',
    'Corregir un movimiento',
    area: 'Movimientos',
    goal:
        'Anoté mal la compra del Éxito: fue con la Visa, en ropa, por menos '
        'y el día antes; quiero corregirla.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Entry old = _entryOf(own, 'Éxito Laureles', '-187400');
      final int free = own.ledger!.freeUntilPayday;
      final Decimal bank = _held(own, 'Bancolombia');
      final Decimal visa = _held(own, 'Visa');
      final int count = own.snapshot!.entries.length;
      await f.tap('Movimientos');
      await _open(f, old);
      await f.page(
        'Tocar un movimiento abre «Editar movimiento», que dice de dónde vino '
        '(«Anotado a mano») y trae todo lo que tiene: monto, cuenta, '
        'categoría, fecha y nota, y abajo «Dividir este gasto» y «Eliminar».',
        most: 2,
      );
      await f.check('El formulario trae el monto y la categoría guardados', () {
        expect(f.shows('Editar movimiento'), isTrue);
        expect(f.shows('Anotado a mano'), isTrue);
        expect(
          find.descendant(
            of: find.byType(TextField),
            matching: find.text('187.400'),
          ),
          findsOneWidget,
        );
      });
      await f.type('Monto', '178400');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Visa').last);
      await f.tap('Compras');
      await f.step(
        'Cambia el monto a 178.400, la cuenta a Visa y la categoría a '
        '«Compras»: el chip elegido se marca.',
      );
      await _openDate(f);
      await f.step(
        '«Fecha» abre el calendario en el día del movimiento, el 2 de '
        'octubre.',
      );
      await _tapPicker(f, 'Cancelar');
      await f.step('«Cancelar» cierra el calendario y la fecha sigue igual.');
      await f.check('Cancelar no cambia la fecha', () {
        expect(f.shows('Ayer'), isTrue);
      });
      await _openDate(f);
      await _pickDay(f, 1);
      await f.type('Nota (opcional)', 'Ropa para el viaje');
      await f.step(
        'Elegido el 1 y escrita la nota, la fecha dice «1 oct 2026». Falta '
        '«Guardar».',
      );
      await f.tap('Guardar');
      await f.reveal(_row(old));
      await f.step(
        'Guardado: el movimiento pasa al jueves 1 de octubre, en «Compras · '
        'Visa» y por −\$178.400.',
      );
      final Entry now = own.snapshot!.entries.firstWhere(
        (Entry e) => e.id == old.id,
      );
      await f.check('Es el mismo movimiento, no uno nuevo', () {
        expect(own.snapshot!.entries.length, count);
      });
      await f.check('Quedó en Visa, Compras, 178.400, el 1 de octubre', () {
        expect(now.accountId, _account(own, 'Visa').id);
        expect(now.category, 'shopping');
        expect(now.amount, Decimal.parse('-178400'));
        expect(now.date.day, 1);
        expect(now.note, 'Ropa para el viaje');
      });
      await f.check('Bancolombia recuperó los 187.400', () {
        expect(_held(own, 'Bancolombia'), bank + Decimal.parse('187400'));
      });
      await f.check('La Visa debe 178.400 más', () {
        expect(_held(own, 'Visa'), visa - Decimal.parse('178400'));
      });
      await f.check('Lo que puedes gastar subió los 9.000 de diferencia', () {
        expect(own.ledger!.freeUntilPayday, free + 9000);
      });
    },
  ),
  AppFlow(
    '03-04-dividir-un-gasto',
    'Dividir un gasto con amigos',
    area: 'Movimientos',
    goal:
        'Pagué las crepes con Ana y quiero que la app sepa que ella me debe '
        'su parte.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Entry crepes = _entry(own, 'Crepes & Waffles');
      final int free = own.ledger!.freeUntilPayday;
      final int spent = _spentIn(own, 2026, 10);
      await f.tap('Movimientos');
      await f.tap('Crepes & Waffles');
      await f.tap('Dividir este gasto');
      await f.page(
        '«Dividir este gasto» abre «Dividir un gasto»: un grupo nuevo, con '
        'el valor del movimiento fijo y «En partes iguales» elegido.',
        most: 2,
      );
      await f.tap('Guardar');
      await f.step(
        'Sin nadie con quien dividir, «Guardar» avisa: «Agrega al menos a '
        'una persona más.»',
      );
      await f.check('No guarda una división solo contigo', () {
        expect(f.shows('Agrega al menos a una persona más.'), isTrue);
        expect(own.splitOf(crepes.id), isNull);
      });
      await f.type('¿Con quién lo divides?', 'Ana, Juan');
      await f.page(
        'Con «Ana, Juan» quedan tres partes iguales; el peso que sobra del '
        'redondeo queda en tu parte, y abajo dice cuánto te deben.',
        most: 2,
      );
      await f.check('Tres partes: \$7.834 para ti y \$7.833 para cada uno', () {
        expect(f.shows(pesos(7834)), isTrue);
        expect(find.text(pesos(7833)), findsNWidgets(2));
      });
      // Ana and Juan unticked: only the person is left.
      await f.tapFound(find.byType(Checkbox).at(1));
      await f.tapFound(find.byType(Checkbox).at(2));
      await f.tap('Guardar');
      await f.step(
        'Sin Ana ni Juan marcados quedas solo tú: «Guardar» no divide y pide '
        '«$_splitNeedsShare»',
      );
      await f.check('No guarda una división en la que solo quedas tú', () {
        expect(own.splitOf(crepes.id), isNull);
        expect(f.shows(_splitNeedsShare), isTrue);
      });
      // Ana ate, Juan did not: her box on again.
      await f.tapFound(find.byType(Checkbox).at(1));
      await f.check('Al marcar a Ana, el aviso se va', () {
        expect(f.shows(_splitNeedsShare), isFalse);
      });
      await f.tap('Por montos');
      await f.type('Tu parte', '8000');
      await f.type('Parte de Ana', '10000');
      await f.page(
        'Sin Juan y «Por montos»: 8.000 para ti y 10.000 para Ana. Abajo, '
        'en naranja, faltan \$5.500 para el total.',
        most: 2,
      );
      await f.check('Dice cuánto falta para el total', () {
        expect(f.shows('Faltan ${pesos(5500)} para el total'), isTrue);
      });
      await f.check('El aviso de antes se fue al escribir los nombres', () {
        expect(f.shows('Agrega al menos a una persona más.'), isFalse);
      });
      await f.tap('Guardar');
      await f.step(
        '«Guardar» no deja guardar partes que no suman: «Las partes no suman '
        'el total.»',
      );
      await f.check('No guarda partes que no suman', () {
        expect(f.shows('Las partes no suman el total.'), isTrue);
        expect(own.splitOf(crepes.id), isNull);
      });
      await f.type('Parte de Ana', '15500');
      await f.type('Nombre del grupo', 'Ana y yo');
      await f.type('¿Qué fue?', 'Crepes del viernes');
      await f.page(
        'Con 15.500 para Ana ya suma. Arriba, el grupo se llama «Ana y yo» y '
        'el gasto «Crepes del viernes», en vez del nombre del comercio.',
        most: 2,
      );
      await f.tap('Guardar');
      await f.step(
        'Al guardar vuelves a Movimientos y la fila de las crepes lleva, '
        'aparte y entera, la etiqueta «Tu parte \$8.000».',
      );
      await f.check('La fila lleva la etiqueta «Tu parte ${pesos(8000)}»', () {
        expect(_rowSays(crepes, 'Tu parte ${pesos(8000)}'), isTrue);
      });
      await f.check('Ana te debe 15.500 y tu parte es 8.000', () {
        final SharedExpense split = own.splitOf(crepes.id)!.$2;
        expect(split.shares[meId], 8000);
        expect(split.othersPart, 15500);
      });
      await f.check('El grupo y el gasto llevan los nombres escritos', () {
        final (Group group, SharedExpense split) = own.splitOf(crepes.id)!;
        expect(group.name, 'Ana y yo');
        expect(split.label, 'Crepes del viernes');
        expect(group.members.map((Member m) => m.name), <String>[
          '',
          'Ana',
          'Juan',
        ]);
      });
      await f.check(
        'Lo que puedes gastar no cambia: lo de Ana aún no llega',
        () {
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      await f.check('Tu gasto del mes baja 15.500: solo cuenta tu parte', () {
        expect(_spentIn(own, 2026, 10), spent - 15500);
      });
      await f.tap('Crepes & Waffles');
      await f.tap('Cambiar la división');
      await f.step(
        'Al abrirlo de nuevo, el botón dice «Cambiar la división»: la hoja '
        'trae las partes de antes, 8.000 y 15.500, y suma «Quitar la '
        'división».',
      );
      await f.check('La hoja trae las partes guardadas', () {
        expect(_fieldShows('Tu parte', '8.000'), findsOneWidget);
        expect(_fieldShows('Parte de Ana', '15.500'), findsOneWidget);
      });
      await f.tap('Quitar la división');
      await f.step('«Quitar la división» lo deja como un gasto solo tuyo.');
      await f.check(
        'Ya no está dividido y el gasto del mes vuelve a ser el de antes',
        () {
          expect(own.splitOf(crepes.id), isNull);
          expect(_spentIn(own, 2026, 10), spent);
        },
      );
    },
  ),
  AppFlow(
    '03-05-borrar-un-movimiento',
    'Borrar un movimiento',
    area: 'Movimientos',
    goal:
        'Ya cancelé el gimnasio y ese cobro quedó anotado de más; quiero '
        'borrarlo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Entry gym = _entry(own, 'Fit24 gimnasio');
      final int free = own.ledger!.freeUntilPayday;
      final Decimal bank = _held(own, 'Bancolombia');
      await f.tap('Movimientos');
      await f.tap('Fit24 gimnasio');
      await f.tap('Eliminar');
      await f.step(
        '«Eliminar» no borra de una vez: pregunta «¿Eliminar este '
        'movimiento?» con «Cancelar» y «Eliminar».',
      );
      await f.tap('Cancelar');
      await f.step('«Cancelar» vuelve al formulario y no borra nada.');
      await f.check('Cancelar no borra el movimiento', () {
        expect(own.snapshot!.entries.any((Entry e) => e.id == gym.id), isTrue);
      });
      await f.tap('Eliminar');
      await f.tap('Eliminar');
      await f.step(
        'Confirmado, el formulario se cierra y el gimnasio ya no está en la '
        'lista.',
      );
      await f.check('El movimiento ya no existe', () {
        expect(own.snapshot!.entries.any((Entry e) => e.id == gym.id), isFalse);
        expect(f.shows('Fit24 gimnasio'), isFalse);
      });
      await f.check('Bancolombia recuperó los 119.000', () {
        expect(_held(own, 'Bancolombia'), bank + Decimal.parse('119000'));
      });
      await f.check('Lo que puedes gastar subió 119.000', () {
        expect(own.ledger!.freeUntilPayday, free + 119000);
      });
    },
  ),
  AppFlow(
    '03-06-registrar-un-ingreso',
    'Registrar un ingreso',
    area: 'Movimientos',
    goal:
        'Un cliente me pagó un trabajo a Nequi y quiero anotarlo para que '
        'cuente, apartando la reserva que tengo para independientes.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger ledger = own.ledger!;
      final Decimal nequi = _held(own, 'Nequi');
      await f.tapTip('Agregar movimiento');
      await f.tap('Ingreso');
      await f.step(
        'En «Ingreso» las categorías cambian a las de plata que entra y el '
        'campo pregunta «¿De dónde?».',
      );
      await f.check('Muestra las categorías de ingreso, no las de gasto', () {
        expect(f.shows('Trabajos independientes'), isTrue);
        expect(f.shows('Salario'), isTrue);
        expect(f.shows('Mercado'), isFalse);
        expect(f.shows('¿De dónde?'), isTrue);
      });
      await f.tap('Guardar');
      await f.step(
        'Sin monto, «Guardar» no guarda: el campo dice «Escribe un monto».',
      );
      await f.check('Sin monto no guarda nada', () {
        expect(f.shows('Escribe un monto'), isTrue);
        expect(f.shows('Agregar movimiento'), isTrue);
      });
      await f.type('Monto', '350000');
      await f.check('Al escribir el monto, el aviso se va', () {
        expect(f.shows('Escribe un monto'), isFalse);
      });
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Nequi').last);
      await f.tap('Trabajos independientes');
      await f.type('¿De dónde?', 'Cliente Acme');
      await f.step(
        'Con 350.000 a Nequi, «Trabajos independientes» y «Cliente Acme», '
        'queda listo.',
      );
      await f.tap('Guardar');
      await f.page(
        'En Inicio la cifra subió, pero no los 350.000: la «Reserva de '
        'ingresos variables» apartó su 15 %.',
        most: 2,
      );
      await f.check(
        'El ingreso quedó en Nequi, en Trabajos independientes',
        () {
          final Entry e = _entryOf(own, 'Cliente Acme', '350000');
          expect(e.category, 'freelance');
          expect(e.kind, EntryKind.income);
          expect(_held(own, 'Nequi'), nequi + Decimal.parse('350000'));
        },
      );
      await f.check('La reserva apartó 52.500, el 15 % del pago', () {
        expect(own.ledger!.reserved, ledger.reserved + 52500);
        expect(f.screenText, contains(_money(own, -own.ledger!.reserved)));
      });
      await f.check('Lo que puedes gastar subió 297.500, a '
          '${_money(own, ledger.freeUntilPayday + 297500)}', () {
        expect(own.ledger!.freeUntilPayday, ledger.freeUntilPayday + 297500);
        expect(f.shows(_money(own, ledger.freeUntilPayday + 297500)), isTrue);
      });
    },
  ),
  AppFlow(
    '03-07-pasar-plata-entre-mis-cuentas',
    'Pasar plata entre mis cuentas',
    area: 'Movimientos',
    goal:
        'Pasé plata de Bancolombia a Nequi y quiero anotarlo sin que cuente '
        'como gasto ni como ingreso.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final int spent = _spentIn(own, 2026, 10);
      final int count = own.snapshot!.entries.length;
      final Decimal bank = _held(own, 'Bancolombia');
      final Decimal nequi = _held(own, 'Nequi');
      final int bankPart = own.spendableParts[_account(own, 'Bancolombia').id]!;
      final int nequiPart = own.spendableParts[_account(own, 'Nequi').id]!;
      await f.tapTip('Agregar movimiento');
      await f.tap('Transferencia');
      await f.step(
        '«Transferencia» cambia «Cuenta» por «Desde» y «Hacia», y quita la '
        'categoría: no es gasto ni ingreso.',
      );
      await f.check('Pide desde y hacia, sin categoría', () {
        expect(f.shows('Desde'), isTrue);
        expect(f.shows('Hacia'), isTrue);
        expect(f.shows('Categoría'), isFalse);
      });
      await f.type('Monto', '50000');
      await f.tapFound(find.byType(DropdownButtonFormField<String>).last);
      await f.tapFound(find.text('Bancolombia').last);
      await f.tap('Guardar');
      await f.step(
        'Con Bancolombia en las dos, «Guardar» avisa: «Elige dos cuentas '
        'distintas».',
      );
      await f.check('No guarda una transferencia a la misma cuenta', () {
        expect(f.shows('Elige dos cuentas distintas'), isTrue);
        expect(_held(own, 'Bancolombia'), bank);
      });
      await f.tapFound(find.byType(DropdownButtonFormField<String>).last);
      await f.tapFound(find.text('Nequi').last);
      await f.tap('Guardar');
      await f.tap('Movimientos');
      await f.step(
        'Con Nequi en «Hacia» se guarda. En Movimientos aparece como '
        '«Bancolombia → Nequi», con el monto en gris y sin signo.',
      );
      await f.check('Bancolombia bajó 50.000 y Nequi subió 50.000', () {
        expect(_held(own, 'Bancolombia'), bank - Decimal.parse('50000'));
        expect(_held(own, 'Nequi'), nequi + Decimal.parse('50000'));
      });
      await f.check('Quedó como una transferencia de dos partes', () {
        expect(own.snapshot!.entries, hasLength(count + 2));
      });
      await f.check(
        '«¿De dónde sale?» pasa los 50.000 de la línea de Bancolombia a la de '
        'Nequi',
        () {
          expect(
            own.spendableParts[_account(own, 'Bancolombia').id],
            bankPart - 50000,
          );
          expect(
            own.spendableParts[_account(own, 'Nequi').id],
            nequiPart + 50000,
          );
        },
      );
      await f.check(
        'No es gasto: lo gastado y lo que puedes gastar siguen',
        () {
          expect(_spentIn(own, 2026, 10), spent);
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      await _search(f, 'nequi');
      await f.step(
        'Buscar «nequi» la encuentra, aunque Nequi sea la cuenta a la que '
        'llegó.',
      );
      await f.check('La búsqueda por la cuenta de llegada la encuentra', () {
        expect(f.shows('Bancolombia → Nequi'), isTrue);
      });
      await f.tap('Bancolombia → Nequi');
      await f.step(
        'Abierta, se edita como una sola: «Transferencia», 50.000, desde '
        'Bancolombia hacia Nequi.',
      );
      await f.type('Monto', '80000');
      await f.tap('Guardar');
      await f.step('Cambiado el monto a 80.000, la fila lo dice.');
      await f.check('Las dos partes pasaron a 80.000', () {
        expect(_held(own, 'Bancolombia'), bank - Decimal.parse('80000'));
        expect(_held(own, 'Nequi'), nequi + Decimal.parse('80000'));
      });
      await f.tap('Bancolombia → Nequi');
      await f.tap('Eliminar');
      await f.step(
        'Al eliminarla, la pregunta avisa: «Se eliminan las dos partes de la '
        'transferencia.»',
      );
      await f.check('Avisa que se borran las dos partes', () {
        expect(
          f.shows('Se eliminan las dos partes de la transferencia.'),
          isTrue,
        );
      });
      await f.tap('Eliminar');
      await f.step('Borrada, Bancolombia y Nequi quedan como estaban.');
      await f.check('Las dos cuentas volvieron a su saldo', () {
        expect(_held(own, 'Bancolombia'), bank);
        expect(_held(own, 'Nequi'), nequi);
      });
      await f.check('Se borraron las dos partes y nada más', () {
        expect(own.snapshot!.entries, hasLength(count));
      });
    },
  ),
  AppFlow(
    '03-08-registrar-un-gasto-en-dolares',
    'Registrar un gasto en dólares',
    area: 'Movimientos',
    goal:
        'Compré algo en Amazon con mi cuenta en dólares y quiero anotarlo en '
        'dólares, sin hacer la cuenta a pesos.',
    manual: <String>[
      'En un iPhone real, escribir 12.50 con el teclado numérico de la región '
          'Colombia (que trae coma) y con uno que trae punto: debe quedar 12,50 '
          'USD en los dos.',
    ],
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Decimal dollars = _held(own, 'Cuenta en dólares');
      await f.tapTip('Agregar movimiento');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Cuenta en dólares').last);
      await _typeKeys(f, 'Monto', '12.50');
      await f.step(
        'Elegida «Cuenta en dólares», el monto dice USD. Escrito con el punto '
        'del teclado, 12.50 queda «12,50»: el punto se vuelve coma decimal.',
      );
      await f.check('El monto quedó en 12,50 dólares', () {
        expect(_fieldShows('Monto', '12,50'), findsOneWidget);
        expect(f.shows('USD'), isTrue);
      });
      await f.tap('Compras');
      await f.type('¿Dónde o a quién?', 'Amazon');
      await f.tap('Guardar');
      await f.step(
        'De vuelta en Inicio, «Puedes gastar» no se mueve: la cuenta en '
        'dólares no es de uso diario.',
      );
      await f.tap('Movimientos');
      final Money cost = own.inBase(Money(Decimal.parse('-12.5'), Asset.usd))!;
      await f.step(
        'En Movimientos, Amazon dice −US\$12,50 y debajo, en pesos, cuánto '
        'es con la tasa del día.',
      );
      await f.check('Se guardó −12,50 en la cuenta en dólares', () {
        final Entry e = _entryOf(own, 'Amazon', '-12.5');
        expect(e.accountId, _account(own, 'Cuenta en dólares').id);
        expect(
          _held(own, 'Cuenta en dólares'),
          dollars - Decimal.parse('12.5'),
        );
      });
      await f.check(
        'La fila muestra ≈ ${moneyText(cost, base: Asset.cop)} en pesos',
        () {
          expect(f.shows('≈ ${moneyText(cost, base: Asset.cop)}'), isTrue);
        },
      );
      await f.check(
        'Lo que puedes gastar no cambia: la cuenta en dólares no es de uso '
        'diario',
        () => expect(own.ledger!.freeUntilPayday, free),
      );
    },
  ),
  AppFlow(
    '03-09-pasar-pesos-a-dolares',
    'Pasar pesos a mi cuenta en dólares',
    area: 'Movimientos',
    goal:
        'Mandé pesos de Bancolombia a mi cuenta en dólares y quiero anotar '
        'lo que salió y lo que llegó de verdad.',
    manual: <String>[
      'Con conexión, que «Llegó» proponga lo que da la TRM del día y no la '
          'tasa fija de las pruebas.',
    ],
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Decimal bank = _held(own, 'Bancolombia');
      final Decimal dollars = _held(own, 'Cuenta en dólares');
      await f.tapTip('Agregar movimiento');
      await f.tap('Transferencia');
      await f.tapFound(find.byType(DropdownButtonFormField<String>).last);
      await f.tapFound(find.text('Cuenta en dólares').last);
      await f.type('Monto', '331284');
      await f.step(
        'Hacia «Cuenta en dólares» aparece «Llegó», en USD: con 331.284 '
        'pesos la app propone 100 dólares, con la tasa que tiene.',
      );
      await f.check('Propone 100 dólares con la tasa de 3.312,84', () {
        expect(_fieldShows('Llegó', '100'), findsOneWidget);
      });
      await f.type('Llegó', '98,5');
      await f.type('Monto', '331300');
      await f.step(
        'El banco cobró comisión: llegaron 98,5. Escrito en «Llegó», ya no '
        'cambia aunque se corrija el monto a 331.300.',
      );
      await f.check('Lo escrito en «Llegó» se queda', () {
        expect(_fieldShows('Llegó', '98,5'), findsOneWidget);
      });
      await f.type('Llegó', '');
      await f.tap('Guardar');
      await f.step(
        'Con «Llegó» vacío, «Guardar» no guarda y avisa «Escribe un monto» '
        'bajo «Llegó», el campo que falta, no bajo el monto que ya está.',
      );
      await f.check('El aviso sale bajo «Llegó» y no bajo «Monto»', () {
        expect(_fieldShows('Llegó', 'Escribe un monto'), findsOneWidget);
        expect(_fieldShows('Monto', 'Escribe un monto'), findsNothing);
        expect(_held(own, 'Bancolombia'), bank);
      });
      await f.type('Llegó', '98,5');
      await f.check('Al escribir lo que llegó, el aviso se va', () {
        expect(f.shows('Escribe un monto'), isFalse);
      });
      await f.tap('Guardar');
      await f.tap('Movimientos');
      await f.step(
        'En Movimientos: «Bancolombia → Cuenta en dólares», por los pesos que '
        'salieron, y aparte la etiqueta «Llegaron US\$98,50».',
      );
      await f.check('La fila dice lo que llegó: «Llegaron US\$98,50»', () {
        expect(f.shows('Bancolombia → Cuenta en dólares'), isTrue);
        expect(f.shows('Llegaron US\$98,50'), isTrue);
      });
      await f.check('Salieron 331.300 pesos y llegaron 98,50 dólares', () {
        expect(_held(own, 'Bancolombia'), bank - Decimal.parse('331300'));
        expect(
          _held(own, 'Cuenta en dólares'),
          dollars + Decimal.parse('98.5'),
        );
      });
      await f.check(
        'Lo que puedes gastar bajó 331.300: esa plata ya no es de uso diario',
        () => expect(own.ledger!.freeUntilPayday, free - 331300),
      );
    },
  ),
  AppFlow(
    '03-10-crear-una-categoria',
    'Crear una categoría mía',
    area: 'Movimientos',
    goal:
        'Quiero llevar aparte lo que gasto en mi perro, en una categoría '
        'que se llame Mascotas.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int categories = own.categories.length;
      await f.tapTip('Agregar movimiento');
      await f.tap('Nueva categoría');
      await f.step(
        '«Nueva categoría», al final de los chips, abre una ventana que pide '
        'el nombre.',
      );
      await f.tap('Cancelar');
      await f.check('«Cancelar» no crea nada', () {
        expect(own.categories.length, categories);
      });
      await f.tap('Nueva categoría');
      await f.tap('Guardar');
      await f.check('Sin nombre tampoco crea nada', () {
        expect(own.categories.length, categories);
      });
      await f.tap('Nueva categoría');
      await enterTextIn(f.tester, find.byType(TextField).last, 'Mascotas');
      await settle(f.tester);
      await f.step('Escribe «Mascotas» y toca «Guardar».');
      await f.tap('Guardar');
      await f.step(
        'La categoría nueva aparece entre las demás, ya elegida para este '
        'gasto.',
      );
      final CategoryItem? pets = own.categories
          .where((CategoryItem c) => c.name == 'Mascotas')
          .firstOrNull;
      await f.check('Quedó creada como categoría de gasto', () {
        expect(pets, isNotNull);
        expect(pets!.income, isFalse);
        expect(own.categories.length, categories + 1);
      });
      await f.check('El chip de Mascotas quedó elegido', () {
        final ChoiceChip chip = f.tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Mascotas'),
        );
        expect(chip.selected, isTrue);
      });
      await f.type('Monto', '85000');
      await f.type('¿Dónde o a quién?', 'Veterinaria');
      await f.tap('Guardar');
      await f.tap('Movimientos');
      await f.step('Guardado, la fila dice «Mascotas · Bancolombia».');
      await f.check('El gasto quedó en Mascotas', () {
        expect(_entryOf(own, 'Veterinaria', '-85000').category, pets!.key);
        expect(f.shows('Mascotas · Bancolombia'), isTrue);
      });
      await f.tapTip('Agregar movimiento');
      await f.tap('Ingreso');
      await f.step(
        'En un ingreso no aparece: Mascotas es una categoría de gasto.',
      );
      await f.check('Mascotas no está entre las de ingreso', () {
        expect(f.shows('Mascotas'), isFalse);
      });
    },
  ),
  AppFlow(
    '03-11-anotar-un-pago-que-viene',
    'Anotar un pago que viene',
    area: 'Movimientos',
    goal:
        'La factura de EPM llega el 10 y quiero anotarla desde ya para que '
        'la cifra la cuente antes de pagarla.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final int committed = own.ledger!.committedUntilPayday;
      final Decimal bank = _held(own, 'Bancolombia');
      await f.tapTip('Agregar movimiento');
      await f.type('Monto', '120000');
      await f.tap('Servicios');
      await f.type('¿Dónde o a quién?', 'EPM');
      await _openDate(f);
      await _pickDay(f, 10);
      await f.step(
        'Un gasto de 120.000 en Servicios, «EPM», con fecha del 10 de '
        'octubre: todavía no pasa.',
      );
      await f.tap('Guardar');
      await f.page(
        'En Inicio, «Pagos hasta el 15 oct» sumó los 120.000 y la cifra '
        'bajó tanto que ahora dice «Te faltan».',
        most: 2,
      );
      await f.check('Lo comprometido hasta el pago subió 120.000', () {
        expect(own.ledger!.committedUntilPayday, committed + 120000);
        expect(own.ledger!.freeUntilPayday, free - 120000);
      });
      await f.check('Bancolombia no baja todavía: es del 10', () {
        expect(_held(own, 'Bancolombia'), bank);
      });
      await f.check('«Próximos días» lo pone el 10 oct', () {
        expect(
          own.projection!.days.any(
            (ProjectedDay d) =>
                d.date == DateTime(2026, 10, 10) &&
                d.events.any((ProjectedEvent e) => e.label == 'EPM'),
          ),
          isTrue,
        );
      });
      await f.tap('Movimientos');
      await f.step(
        'En Movimientos va arriba de todo, en el sábado 10: «Servicios · '
        'Bancolombia» y, aparte y entera, la etiqueta «Programado».',
      );
      await f.check(
        'La fila dice «Servicios · Bancolombia» y lleva «Programado» aparte',
        () {
          final Entry epm = _entry(own, 'EPM');
          expect(_rowSays(epm, 'Servicios · Bancolombia'), isTrue);
          expect(_rowSays(epm, 'Programado'), isTrue);
        },
      );
    },
  ),
  AppFlow(
    '03-12-empezar-sin-movimientos',
    'Empezar sin movimientos',
    area: 'Movimientos',
    goal:
        'Acabo de entrar y no tengo nada anotado; quiero saber por dónde '
        'empezar y anotar lo primero.',
    data: _noAccounts,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.page(
        'Sin cuentas, Inicio dice \$0 y solo pide pagos fijos. Abajo, «Tus '
        'cuentas» queda vacío y «Últimos movimientos» dice «Aquí aparecerá '
        'tu plata…».',
        most: 3,
      );
      await f.check('No hay cuentas ni movimientos', () {
        expect(own.accounts, isEmpty);
        expect(f.shows('Aquí aparecerá tu plata entrando y saliendo.'), isTrue);
      });
      await f.tapTip('Agregar movimiento');
      await f.step(
        'Sin cuentas, «Movimiento» no abre el formulario: abajo pide '
        '«Primero agrega una cuenta.»',
      );
      await f.check('Pide una cuenta antes del primer movimiento', () {
        expect(f.shows('Primero agrega una cuenta.'), isTrue);
        expect(f.shows('Agregar movimiento'), isFalse);
      });
      await f.tap('Cuentas');
      await f.check('En Cuentas no flota el botón «Movimiento»', () {
        expect(find.byTooltip('Agregar movimiento'), findsNothing);
      });
      await f.tap('Agregar cuenta');
      await f.type('Nombre', 'Nequi');
      await f.tap(_kindWallet);
      await f.type('¿Cuánto tiene hoy?', '150000');
      await f.step('En Cuentas, «Agregar cuenta»: Nequi, con 150.000 hoy.');
      await f.tap('Guardar');
      await f.tap('Movimientos');
      await f.step(
        'Movimientos, todavía vacío, dice dónde aparecerá la plata y que se '
        'registra con «Movimiento».',
      );
      await f.check('Movimientos muestra el aviso de vacío', () {
        expect(f.shows('Aquí aparecerá tu plata entrando y saliendo.'), isTrue);
      });
      await f.tapTip('Agregar movimiento');
      await f.step(
        'Con una sola cuenta el formulario ofrece «Gasto» e «Ingreso»: no '
        'hay a dónde transferir.',
      );
      await f.check('Sin otra cuenta no ofrece transferir', () {
        expect(f.shows('Transferencia'), isFalse);
      });
      await f.type('Monto', '12000');
      await f.tap('Transporte');
      await f.type('¿Dónde o a quién?', 'Bus');
      await f.tap('Guardar');
      await f.step('El primer movimiento ya está en la lista, en «Hoy».');
      await f.check('Quedó el primer movimiento, en Nequi', () {
        expect(own.snapshot!.entries, hasLength(1));
        expect(_held(own, 'Nequi'), Decimal.parse('138000'));
        expect(f.shows('Bus'), isTrue);
      });
      await f.tap('Inicio');
      await f.reveal(find.text('Bus'));
      await f.step('En Inicio, «Últimos movimientos» ya lo muestra.');
      await f.check('Inicio ya no muestra el aviso de vacío', () {
        expect(
          f.shows('Aquí aparecerá tu plata entrando y saliendo.'),
          isFalse,
        );
      });
    },
  ),
  AppFlow(
    '03-13-registrar-en-ingles',
    'Registrar un gasto con la app en inglés',
    area: 'Movimientos',
    english: true,
    goal:
        'Tengo el teléfono en inglés y quiero anotar un café y una compra en '
        'dólares con los números como los escribo en inglés.',
    manual: <String>[
      'Con el iPhone en inglés de verdad, que el teclado numérico traiga el '
          'punto decimal y 10.50 quede en diez dólares con cincuenta.',
    ],
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      await f.tapTip('Add transaction');
      await f.type('Amount', '4500');
      await f.tap('Eating out');
      await f.type('Where or to whom?', 'Coffee');
      await f.step(
        'En inglés: «Add transaction», 4,500 escrito con coma de miles, '
        '«Eating out» y «Coffee».',
      );
      await f.check('El monto se agrupa con coma: 4,500', () {
        expect(_fieldShows('Amount', '4,500'), findsOneWidget);
      });
      await f.tap('Save');
      await f.step(
        'En Home, «You can spend» bajó 4,500, con los montos escritos en '
        'inglés.',
      );
      await f.check(
        'Lo que puedes gastar bajó 4.500 y se lee ${_money(own, free - 4500)}',
        () {
          expect(own.ledger!.freeUntilPayday, free - 4500);
          expect(f.shows(_money(own, free - 4500)), isTrue);
          expect(_money(own, free - 4500), contains(','));
        },
      );
      await f.tapTip('Add transaction');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Cuenta en dólares').last);
      await _typeKeys(f, 'Amount', '10.50');
      await f.tap('Shopping');
      await f.type('Where or to whom?', 'Kindle book');
      await f.step(
        'En dólares, el punto es el decimal: 10.50 queda «10.50» y no mil '
        'cincuenta.',
      );
      await f.tap('Save');
      await f.tap('Transactions');
      await f.step(
        'En «Transactions», bajo «Today», el café y el libro, el de dólares '
        'con su valor en pesos debajo.',
      );
      await f.check('Se guardaron −4.500 pesos y −10,50 dólares', () {
        expect(_entryOf(own, 'Coffee', '-4500').category, 'restaurants');
        expect(
          _entryOf(own, 'Kindle book', '-10.5').accountId,
          _account(own, 'Cuenta en dólares').id,
        );
        expect(f.shows('TODAY'), isTrue);
      });
    },
  ),
  AppFlow(
    '03-14-dividir-con-un-grupo',
    'Dividir un gasto con un grupo que ya tengo',
    area: 'Movimientos',
    goal:
        'Hice el mercado del paseo y quiero dividirlo con Laura y Camilo, '
        'que ya están en el grupo del paseo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Entry market = _entryOf(own, 'Éxito Laureles', '-187400');
      final Group trip = own.groups.firstWhere(
        (Group g) => g.name == 'Paseo a Guatapé',
      );
      final int expenses = trip.expenses.length;
      await f.tap('Movimientos');
      await _open(f, market);
      await f.tap('Dividir este gasto');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.step(
        '«Grupo» ofrece «Un grupo nuevo» o los que ya tienes, como «Paseo a '
        'Guatapé».',
      );
      await f.tapFound(find.text('Paseo a Guatapé').last);
      await f.page(
        'Con el grupo elegido no hay que escribir nombres: salen Tú, Laura y '
        'Camilo, cada uno con su parte de los 187.400.',
        most: 2,
      );
      await f.check('No pide nombres: los trae el grupo', () {
        expect(f.shows('¿Con quién lo divides?'), isFalse);
        expect(f.shows('Laura'), isTrue);
        expect(f.shows('Camilo'), isTrue);
      });
      await f.tap('Guardar');
      await f.step(
        'Guardado, la fila del Éxito lleva aparte la etiqueta «Tu parte '
        '\$62.468», entera, y el grupo del paseo suma el mercado.',
      );
      await f.check('El grupo del paseo tiene el mercado, en tres partes', () {
        final Group now = own.groups.firstWhere((Group g) => g.id == trip.id);
        expect(now.expenses, hasLength(expenses + 1));
        final SharedExpense added = now.expenses.firstWhere(
          (SharedExpense x) => x.entryId == market.id,
        );
        expect(added.shares.values.fold(0, (int a, int b) => a + b), 187400);
        expect(
          added.shares.keys,
          containsAll(<String>[meId, 'laura', 'camilo']),
        );
        expect(added.shares[meId], 62468);
      });
      await f.check('La fila lleva «Tu parte ${pesos(62468)}»', () {
        expect(_rowSays(market, 'Tu parte ${pesos(62468)}'), isTrue);
      });
    },
  ),
  AppFlow(
    '03-15-cambiar-un-gasto-a-ingreso',
    'Cambiar un gasto a ingreso',
    area: 'Movimientos',
    goal:
        'Falabella me devolvió 85.000 y lo anoté como gasto por error; quiero '
        'que cuente como plata que me entró.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final int count = own.snapshot!.entries.length;
      final Decimal bank = _held(own, 'Bancolombia');
      await f.tapTip('Agregar movimiento');
      await f.type('Monto', '85000');
      await f.tap('Compras');
      await f.type('¿Dónde o a quién?', 'Devolución Falabella');
      await f.tap('Guardar');
      await f.step(
        'Anotado por error como gasto en Compras: la cifra bajó 85.000 y '
        'ahora dice «Te faltan».',
      );
      await f.check('Como gasto, lo que puedes gastar bajó 85.000', () {
        expect(own.ledger!.freeUntilPayday, free - 85000);
        expect(f.shows(_money(own, 85000 - free)), isTrue);
      });
      final Entry wrong = _entry(own, 'Devolución Falabella');
      await f.tap('Movimientos');
      await _open(f, wrong);
      await f.tap('Ingreso');
      await f.step(
        'Abierto, toca «Ingreso»: las categorías pasan a las de plata que '
        'entra, ninguna queda elegida, el campo dice «¿De dónde?» y ya no '
        'ofrece dividir.',
      );
      await f.check(
        'Al pasar a ingreso no queda ninguna categoría elegida',
        () {
          expect(
            f.tester
                .widgetList<ChoiceChip>(find.byType(ChoiceChip))
                .where((ChoiceChip c) => c.selected),
            isEmpty,
          );
          expect(
            _fieldShows('¿De dónde?', 'Devolución Falabella'),
            findsOneWidget,
          );
          expect(_fieldShows('Monto', '85.000'), findsOneWidget);
        },
      );
      await f.check('Como ingreso ya no ofrece «Dividir este gasto»', () {
        expect(f.shows('Dividir este gasto'), isFalse);
        expect(f.shows('Eliminar'), isTrue);
      });
      await f.tap('Reembolsos');
      await f.tap('Guardar');
      await f.reveal(_row(wrong));
      await f.step(
        'Guardado: la fila de «Devolución Falabella» queda en «Reembolsos · '
        'Bancolombia», con +\$85.000 en verde.',
      );
      final Entry fixed = own.snapshot!.entries.firstWhere(
        (Entry e) => e.id == wrong.id,
      );
      await f.check(
        'Es el mismo movimiento, ahora un ingreso de 85.000 en Reembolsos',
        () {
          expect(own.snapshot!.entries, hasLength(count + 1));
          expect(fixed.kind, EntryKind.income);
          expect(fixed.amount, Decimal.parse('85000'));
          expect(fixed.category, 'refund');
          expect(f.shows('Reembolsos · Bancolombia'), isTrue);
        },
      );
      await f.check('Bancolombia tiene 85.000 más que antes del error', () {
        expect(_held(own, 'Bancolombia'), bank + Decimal.parse('85000'));
      });
      await f.tap('Inicio');
      await f.step(
        'En Inicio la cifra quedó 85.000 por encima de la de antes del error: '
        'la devolución cuenta como plata que entró.',
      );
      await f.check(
        'Lo que puedes gastar es ${_money(own, free + 85000)}, 85.000 más que '
        'antes',
        () {
          expect(own.ledger!.freeUntilPayday, free + 85000);
          expect(f.shows(_money(own, free + 85000)), isTrue);
        },
      );
    },
  ),
  AppFlow(
    '03-16-anotar-el-pago-de-la-tarjeta',
    'Anotar el pago de la tarjeta',
    area: 'Movimientos',
    goal:
        'Pagué 480.000 de la Visa desde Bancolombia y quiero anotarlo sin que '
        'cuente como un gasto, porque lo que compré con la tarjeta ya está '
        'contado.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final int spent = _spentIn(own, 2026, 10);
      final int count = own.snapshot!.entries.length;
      final int debt = own.spendableCardDebt;
      final Decimal bank = _held(own, 'Bancolombia');
      final Decimal visa = _held(own, 'Visa');
      await f.tapTip('Agregar movimiento');
      await f.type('Monto', '480000');
      await f.tap('Compras');
      // Tapped again, the chip lets go: no category.
      await f.tap('Compras');
      await f.check('Tocar dos veces «Compras» la deja sin elegir', () {
        expect(
          f.tester
              .widgetList<ChoiceChip>(find.byType(ChoiceChip))
              .where((ChoiceChip c) => c.selected),
          isEmpty,
        );
      });
      await f.type('¿Dónde o a quién?', 'Pago Visa');
      await f.tap('Guardar');
      await f.step(
        'Al guardar «Pago Visa» como gasto, la app pregunta «¿Estás pagando '
        'tu Visa?»: Bancolombia → Visa por \$480.000, y explica que pagar la '
        'tarjeta no es un gasto nuevo.',
      );
      await f.check('Pregunta antes de contar el pago como gasto', () {
        expect(f.shows('¿Estás pagando tu Visa?'), isTrue);
        expect(f.screenText, contains('Bancolombia → Visa'));
        expect(own.snapshot!.entries, hasLength(count));
      });
      await f.tap('Sí, registrar el pago');
      await f.tap('Movimientos');
      await f.reveal(find.text('Bancolombia → Visa'));
      await f.step(
        '«Sí, registrar el pago»: en Movimientos la fila es «Bancolombia → '
        'Visa», sin signo, y no hay ningún gasto «Pago Visa».',
      );
      await f.check('Quedó una transferencia de dos partes, no un gasto', () {
        expect(
          own.snapshot!.entries.where(
            (Entry e) => e.payee == 'Pago Visa' && e.transferId == null,
          ),
          isEmpty,
        );
        expect(own.snapshot!.entries, hasLength(count + 2));
        final Entry into = own.snapshot!.entries.firstWhere(
          (Entry e) =>
              e.transferId != null && e.accountId == _account(own, 'Visa').id,
        );
        final Entry out = own.snapshot!.entries.firstWhere(
          (Entry e) => e.transferId == into.transferId && e.id != into.id,
        );
        expect(into.amount, Decimal.parse('480000'));
        expect(out.amount, Decimal.parse('-480000'));
        expect(out.accountId, _account(own, 'Bancolombia').id);
      });
      await f.check(
        'Bancolombia pagó 480.000 y la Visa debe 480.000 menos',
        () {
          expect(_held(own, 'Bancolombia'), bank - Decimal.parse('480000'));
          expect(_held(own, 'Visa'), visa + Decimal.parse('480000'));
        },
      );
      await f.check(
        'Pagar la tarjeta no es gastar: lo gastado del mes y lo que puedes '
        'gastar no cambian',
        () {
          expect(_spentIn(own, 2026, 10), spent);
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      // Said «no» by mistake, or written down elsewhere as an expense: the
      // movement is put right from its edit form.
      await f.tap('Inicio');
      await f.tapTip('Agregar movimiento');
      await f.type('Monto', '120000');
      await f.type('¿Dónde o a quién?', 'Abono Visa');
      await f.tap('Guardar');
      await f.tap('No, es un gasto');
      await f.step(
        'Otro abono, de 120.000, con «No, es un gasto»: queda anotado como '
        'gasto y la cifra baja, como si fuera plata gastada.',
      );
      final Entry wrong = _entry(own, 'Abono Visa');
      await f.check('Con «No, es un gasto» queda como gasto en «Otros»', () {
        expect(wrong.category, 'other');
        expect(own.ledger!.freeUntilPayday, free - 120000);
        expect(_spentIn(own, 2026, 10), spent + 120000);
      });
      await f.tap('Movimientos');
      await _open(f, wrong);
      await f.tap('Transferencia');
      await f.tapFound(find.byType(DropdownButtonFormField<String>).last);
      await f.step(
        'Se corrige desde el movimiento: «Transferencia» y abre «Hacia», la '
        'lista de tus cuentas.',
      );
      await f.tapFound(find.text('Visa').last);
      await f.tap('Guardar');
      await f.check('El gasto se volvió una transferencia de dos partes', () {
        expect(
          own.snapshot!.entries.where(
            (Entry e) => e.payee == 'Abono Visa' && e.transferId == null,
          ),
          isEmpty,
        );
        expect(own.snapshot!.entries, hasLength(count + 4));
        expect(_spentIn(own, 2026, 10), spent);
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.tap('Inicio');
      await f.step(
        'En Inicio, «Lo que debes en tarjetas» bajó los 600.000 pagados y lo '
        'que puedes gastar es el mismo de antes.',
      );
      await f.check(
        '«Lo que debes en tarjetas» dice ${_money(own, -(debt - 600000))}',
        () {
          expect(own.spendableCardDebt, debt - 600000);
          expect(f.shows(_money(own, -(debt - 600000))), isTrue);
          expect(f.shows(_money(own, free)), isTrue);
        },
      );
    },
  ),
  AppFlow(
    '03-17-borrar-un-gasto-dividido',
    'Borrar un gasto que dividí',
    area: 'Movimientos',
    goal:
        'Dividí las crepes con Ana, pero estaban anotadas de más; quiero '
        'borrarlas sin que Ana me quede debiendo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Entry crepes = _entry(own, 'Crepes & Waffles');
      final int free = own.ledger!.freeUntilPayday;
      await f.tap('Movimientos');
      await _splitWithAna(f, crepes);
      await f.step(
        'Las crepes quedan divididas con Ana en partes iguales: la fila lleva '
        'la etiqueta «Tu parte \$11.750».',
      );
      await f.check('Ana te debe 11.750 por las crepes', () {
        final (Group group, SharedExpense split) = own.splitOf(crepes.id)!;
        expect(split.othersPart, 11750);
        expect(group.balances['p-ana'], -11750);
      });
      await f.check('Sin nombre escrito, el grupo toma el del comercio', () {
        expect(own.splitOf(crepes.id)!.$1.name, 'Crepes & Waffles');
      });
      await _open(f, crepes);
      await f.tap('Eliminar');
      await f.step(
        '«Eliminar» pregunta antes de borrar y avisa que la división con Ana '
        'se va con el movimiento.',
      );
      await f.check('La pregunta dice que también se quita la división', () {
        expect(f.shows(_deleteSplitBody), isTrue);
      });
      await f.tap('Eliminar');
      await f.step('Borradas las crepes, la fila ya no está en Movimientos.');
      await f.check('El movimiento ya no existe', () {
        expect(
          own.snapshot!.entries.any((Entry e) => e.id == crepes.id),
          isFalse,
        );
      });
      await f.check('La división se fue con él: Ana ya no te debe nada', () {
        expect(own.splitOf(crepes.id), isNull);
        for (final Group g in own.groups) {
          expect(
            g.expenses.where((SharedExpense x) => x.entryId == crepes.id),
            isEmpty,
          );
          expect(g.balances['p-ana'] ?? 0, 0);
        }
      });
      await f.check('Nequi recuperó los 23.500 y la cifra subió lo mismo', () {
        expect(own.ledger!.freeUntilPayday, free + 23500);
      });
      await f.tap('Plan');
      await f.tap('Gastos compartidos');
      await f.page(
        'En Plan › «Gastos compartidos», el grupo de las crepes ya no tiene '
        'nada pendiente con Ana.',
        most: 2,
      );
    },
  ),
  AppFlow(
    '03-18-corregir-un-gasto-dividido',
    'Corregir el monto de un gasto dividido',
    area: 'Movimientos',
    goal:
        'Las crepes que dividí con Ana costaron 30.000 y no 23.500; quiero '
        'corregir el monto sin tener que dividirlas otra vez.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Entry crepes = _entry(own, 'Crepes & Waffles');
      final int spent = _spentIn(own, 2026, 10);
      await f.tap('Movimientos');
      await _splitWithAna(f, crepes);
      await f.step(
        'Las crepes divididas con Ana: 11.750 cada uno de los 23.500; la '
        'fila lleva la etiqueta «Tu parte \$11.750».',
      );
      await _open(f, crepes);
      await f.type('Monto', '30000');
      await f.tap('Guardar');
      await f.reveal(_row(crepes));
      await f.step(
        'Corregido el monto a 30.000, la división se ajusta sola: en partes '
        'iguales, 15.000 para cada uno.',
      );
      await f.check(
        'Tu parte y la de Ana suman lo que costó: 15.000 cada uno',
        () {
          final SharedExpense split = own.splitOf(crepes.id)!.$2;
          expect(split.amount, 30000);
          expect(split.shares, <String, int>{meId: 15000, 'p-ana': 15000});
        },
      );
      await f.check(
        'La fila lleva «Tu parte ${pesos(15000)}», lo que la app cuenta como '
        'tu gasto',
        () {
          expect(_rowSays(crepes, 'Tu parte ${pesos(15000)}'), isTrue);
          // The crepes count 15.000 of yours instead of 11.750.
          expect(_spentIn(own, 2026, 10), spent - 11750 + 3250);
        },
      );
      await _open(f, crepes);
      await f.tap('Cambiar la división');
      await f.tap('Por montos');
      await f.type('Tu parte', '10000');
      await f.type('Parte de Ana', '20000');
      await f.tap('Guardar');
      await f.reveal(_row(crepes));
      await f.step(
        'Por montos, Ana pidió más: 20.000 para ella y 10.000 para ti. La '
        'etiqueta de la fila pasa a «Tu parte \$10.000».',
      );
      await _open(f, crepes);
      await f.type('Monto', '36000');
      await f.tap('Guardar');
      await f.reveal(_row(crepes));
      await f.step(
        'Con la propina, la fila pasa a −\$36.000: Ana sigue debiendo sus '
        '20.000 y la etiqueta dice que tu parte sube a \$16.000.',
      );
      await f.check(
        'Por montos, lo de Ana no cambia y tu parte toma la diferencia',
        () {
          final SharedExpense split = own.splitOf(crepes.id)!.$2;
          expect(split.shares, <String, int>{meId: 16000, 'p-ana': 20000});
          expect(_rowSays(crepes, 'Tu parte ${pesos(16000)}'), isTrue);
        },
      );
      await f.check('Lo que te deben en el grupo es 20.000', () {
        final Group group = own.splitOf(crepes.id)!.$1;
        expect(group.balances['p-ana'], -20000);
      });
    },
  ),
  AppFlow(
    '03-19-filtrar-movimientos',
    'Filtrar movimientos',
    area: 'Movimientos',
    goal:
        'Quiero ver lo que gasté en restaurantes en esta quincena y, aparte, '
        'lo grande del mes pasado, sin buscar fila por fila.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int all = visibleEntries(own).length;
      await f.tap('Movimientos');
      await f.tapTip('Filtrar');
      await f.page(
        'El embudo de Movimientos abre los filtros: «Tipo», «Fechas», '
        '«Cuentas», «Categorías» y «Monto». Sin nada elegido, el botón dice '
        '«Ver $all movimientos».',
        most: 2,
      );
      await f.check('Sin filtros, el botón cuenta todos los movimientos', () {
        expect(f.shows('Ver $all movimientos'), isTrue);
      });
      await f.tap('Gastos');
      await f.tap('Esta quincena');
      await f.tapFound(find.widgetWithText(FilterChip, 'Restaurantes'));
      await f.reveal(find.text('Ver 2 movimientos'));
      await f.step(
        'Con «Gastos», «Esta quincena» y «Restaurantes» elegidos, el botón ya '
        'dice «Ver 2 movimientos»: cuenta mientras eliges.',
      );
      await f.check('Cuenta 2 mientras se eligen', () {
        expect(f.shows('Ver 2 movimientos'), isTrue);
      });
      await f.tap('Ver 2 movimientos');
      await f.step(
        'Quedan las crepes y Joe\'s Pizza. Bajo el buscador, cada filtro es '
        'una etiqueta con su «x», y arriba dice «2 movimientos · '
        '−\$238.400».',
      );
      final Entry crepes = _entry(own, 'Crepes & Waffles');
      final Entry pizza = _entry(own, 'Joe\'s Pizza');
      final Entry lunch = _entry(own, 'Almuerzo en Guatapé');
      await f.check('Quedan los gastos en restaurantes desde el pago del 30 de '
          'septiembre', () {
        expect(_shownIds(f), <String>{crepes.id, pizza.id});
        expect(f.shows('2 movimientos · ${_signed(own, -238400)}'), isTrue);
      });
      await f.check('Cada filtro queda a la vista como una etiqueta', () {
        for (final String label in <String>[
          'Gastos',
          'Esta quincena',
          'Restaurantes',
        ]) {
          expect(find.widgetWithText(ActionChip, label), findsOneWidget);
        }
      });
      await f.tapFound(find.widgetWithText(ActionChip, 'Esta quincena'));
      await f.step(
        'Tocar «Esta quincena» quita solo ese filtro: vuelve el almuerzo en '
        'Guatapé del 27 de septiembre.',
      );
      await f.check('Sin las fechas, entra el almuerzo de septiembre', () {
        expect(_shownIds(f), <String>{crepes.id, pizza.id, lunch.id});
        expect(f.shows('3 movimientos · ${_signed(own, -328400)}'), isTrue);
        expect(find.widgetWithText(ActionChip, 'Esta quincena'), findsNothing);
      });
      await f.tapFound(find.widgetWithText(TextButton, 'Quitar filtros'));
      await f.step(
        '«Quitar filtros», junto a las etiquetas, los quita todos de una vez.',
      );
      await f.check('Sin filtros vuelve la lista completa', () {
        expect(find.byType(ActiveFilters), findsNothing);
        expect(f.shows('HOY'), isTrue);
      });
      // The funnel is at the top of the list.
      await f.top();
      await f.tapTip('Filtrar');
      await f.tap('Mes pasado');
      await f.type('Desde', '100000');
      await f.reveal(find.text('Ver 2 movimientos'));
      await f.step(
        'Para lo grande del mes pasado: «Mes pasado» y, en «Monto», «Desde» '
        '100.000. El monto es en pesos, como lo dice cada fila.',
      );
      await f.tap('Ver 2 movimientos');
      final Entry pay = _entry(own, 'Nómina');
      final Entry rent = _entry(own, 'Arriendo octubre');
      await f.step(
        'Quedan la Nómina y el arriendo de septiembre; el total suma lo que '
        'entró y lo que salió: «2 movimientos · +\$750.000».',
      );
      await f.check('Quedan los movimientos de septiembre desde 100.000', () {
        expect(_shownIds(f), <String>{pay.id, rent.id});
        expect(f.shows('2 movimientos · ${_signed(own, 750000)}'), isTrue);
        expect(find.widgetWithText(ActionChip, 'Mes pasado'), findsOneWidget);
        expect(
          find.widgetWithText(ActionChip, 'Desde ${_money(own, 100000)}'),
          findsOneWidget,
        );
      });
      await _search(f, 'arriendo');
      await f.step(
        'Con los filtros puestos, buscar «arriendo» busca dentro de ellos: '
        'queda el arriendo, por −\$1.650.000.',
      );
      await f.check('La búsqueda se suma a los filtros', () {
        expect(_shownIds(f), <String>{rent.id});
        expect(f.shows('1 movimiento · ${_signed(own, -1650000)}'), isTrue);
      });
    },
  ),
  AppFlow(
    '03-20-quitar-un-repetido',
    'Quitar un repetido desde la lista',
    area: 'Movimientos',
    goal:
        'El pago del Éxito me quedó dos veces, por la notificación y por el '
        'extracto, y quiero dejar uno. Los dos cobros de Fit24 sí son dos: '
        'pagué mi mes y el de mi hermano.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Entry notified = own.snapshot!.entries.firstWhere(
        (Entry e) => e.source == 'notification',
      );
      final Entry statement = own.snapshot!.entries.firstWhere(
        (Entry e) => e.source == 'statement',
      );
      final Entry fit = _entry(own, 'Fit24', on: DateTime(2026, 10, 1));
      final Entry gym = _entry(own, 'Fit24 gimnasio');
      final int free = own.ledger!.freeUntilPayday;
      final int count = own.snapshot!.entries.length;
      await f.tap('Movimientos');
      // Ayer, the 2nd: both rows under its title.
      await f.reveal(find.text('AYER'));
      await f.step(
        'En Movimientos, los dos pagos de \$63.200 en el Éxito de ayer, '
        'viernes 2, llevan «¿Repetido?»: la misma cuenta, el mismo monto, la '
        'misma hora.',
      );
      await f.check('Los dos pagos del Éxito están marcados', () {
        expect(_markOf(notified), findsOneWidget);
        expect(_markOf(statement), findsOneWidget);
        expect(own.repeats[notified.id]?.repeat.id, statement.id);
      });
      await f.tapFound(_markOf(statement));
      await f.page(
        'La marca abre los dos, uno sobre el otro, con la hora y de dónde '
        'vino cada uno: «De una notificación» y «De un extracto». El del '
        'extracto es «El más reciente», el que se quitaría.',
        most: 2,
      );
      await f.check('Muestra los dos con de dónde vino cada uno', () {
        expect(f.shows('¿El mismo pago dos veces?'), isTrue);
        expect(f.shows('De una notificación'), isTrue);
        expect(f.shows('De un extracto'), isTrue);
        expect(f.shows('El más reciente'), isTrue);
      });
      await f.tap('Quitar repetido');
      await f.reveal(find.text('AYER'));
      await f.step(
        '«Quitar repetido» borra el más reciente, el del extracto, y deja el '
        'de la notificación. Abajo, «Se quitó el repetido.» ofrece '
        '«Deshacer».',
      );
      await f.check(
        'Se borró el del extracto y quedó el de la notificación',
        () {
          final Iterable<String> ids = own.snapshot!.entries.map(
            (Entry e) => e.id,
          );
          expect(ids, isNot(contains(statement.id)));
          expect(ids, contains(notified.id));
          expect(own.snapshot!.entries, hasLength(count - 1));
          expect(f.shows('Se quitó el repetido.'), isTrue);
          expect(_markOf(notified), findsNothing);
        },
      );
      await f.check(
        'Lo que puedes gastar subió los 63.200 que contaba dos veces',
        () {
          expect(own.ledger!.freeUntilPayday, free + 63200);
        },
      );
      await f.tap('Deshacer');
      await f.reveal(find.text('AYER'));
      await f.step(
        '«Deshacer» lo trae de vuelta tal como estaba, y los dos vuelven a '
        'decir «¿Repetido?».',
      );
      await f.check('Volvió el mismo movimiento, del extracto', () {
        final Entry back = own.snapshot!.entries.firstWhere(
          (Entry e) => e.id == statement.id,
        );
        expect(back.source, 'statement');
        expect(back.payee, 'EXITO LAURELES');
        expect(own.ledger!.freeUntilPayday, free);
        expect(_markOf(statement), findsOneWidget);
      });
      await f.tapFound(_markOf(statement));
      await f.tap('Quitar repetido');
      await _hideNotice(f);
      await f.reveal(_row(notified));
      await f.step(
        'Quitado otra vez, el pago del Éxito queda una sola vez, el de la '
        'notificación, ya sin marca.',
      );
      await f.check('Queda un solo pago de \$63.200 en el Éxito', () {
        expect(
          own.snapshot!.entries.where(
            (Entry e) => e.amount == Decimal.parse('-63200'),
          ),
          hasLength(1),
        );
        expect(_markOf(notified), findsNothing);
      });
      await f.reveal(_markOf(gym));
      await f.tapFound(_markOf(gym));
      await f.tap('No es repetido');
      await f.reveal(_row(gym));
      await f.step(
        'Los dos cobros de Fit24 del jueves 1 sí son dos: «No es repetido» '
        'quita la marca, los dos se quedan y la app no vuelve a marcarlos.',
      );
      await f.check(
        'Los dos cobros de Fit24 siguen y ya no están marcados',
        () {
          expect(
            own.snapshot!.entries.map((Entry e) => e.id),
            containsAll(<String>[fit.id, gym.id]),
          );
          expect(own.repeats.containsKey(gym.id), isFalse);
          expect(own.repeats.containsKey(fit.id), isFalse);
          expect(_markOf(gym), findsNothing);
        },
      );
      await f.check(
        'Queda guardado, para tus otros dispositivos y respaldos',
        () async {
          final String? said = await f.tester.runAsync<String?>(
            () => own.store.setting('movements.notRepeated'),
          );
          expect(said, contains(repeatKey(fit.id, gym.id)));
        },
      );
    },
  ),
  AppFlow(
    '03-21-ver-de-donde-vino',
    'Ver de dónde vino un movimiento',
    area: 'Movimientos',
    goal:
        'Antes de borrar o corregir algo quiero saber si lo anoté yo, si me '
        'lo trajo el banco o si vino de un extracto.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Movimientos');
      await _open(f, _entry(own, 'Uber'));
      await f.step(
        'Abierto el Uber del jueves 1, bajo «Editar movimiento» una línea '
        'dice de dónde vino: «Anotado a mano».',
      );
      await f.check('El Uber se anotó a mano', () {
        expect(f.shows('Anotado a mano'), isTrue);
      });
      await f.back();
      await _open(f, _entry(own, 'EXITO LAURELES'));
      await f.step(
        'El pago del Éxito que trajo el extracto lo dice: «De un extracto».',
      );
      await f.check('El del Éxito vino de un extracto', () {
        expect(f.shows('De un extracto'), isTrue);
      });
      await f.back();
      await f.tapTip('Por revisar');
      await f.tapFound(
        find.descendant(
          of: find.ancestor(
            of: find.text('Laura Gómez'),
            matching: find.byType(InboxCard),
          ),
          matching: find.text('Registrar ingreso'),
        ),
      );
      await f.step(
        'En Por revisar, «Registrar ingreso» anota los \$85.000 que Laura '
        'envió por Nequi, como los leyó la notificación.',
      );
      await f.back();
      await _hideNotice(f);
      final Entry laura = _entry(own, 'Laura Gómez');
      await _open(f, laura);
      await f.step(
        'En Movimientos, ese ingreso dice «De una notificación de Nequi»: la '
        'app sabe qué banco le avisó.',
      );
      await f.check('El ingreso de Laura dice de qué notificación vino', () {
        expect(laura.source, 'notification');
        expect(f.shows('De una notificación de Nequi'), isTrue);
      });
    },
  ),
];

/// [minor] in the ledger's unit, as the app writes it.
String _money(OwnController own, int minor) => pesos(own.ledger!.major(minor));

/// What the split sheet says when no one else has a part.
const String _splitNeedsShare = 'Marca al menos a otra persona con su parte.';

/// What deleting a split movement warns of.
const String _deleteSplitBody =
    'También se quita su división: lo que te deben por este gasto deja de '
    'contar.';

/// Splits [entry] in equal parts with Ana, in a group made for it, from
/// the list of movements on screen.
Future<void> _splitWithAna(FlowRun f, Entry entry) async {
  await _open(f, entry);
  await f.tap('Dividir este gasto');
  await f.type('¿Con quién lo divides?', 'Ana');
  await f.tap('Guardar');
  await f.reveal(_row(entry));
}

/// The theme of the screen on top.
ThemeData _theme(FlowRun f) =>
    Theme.of(f.tester.element(find.byType(Scaffold).last));

/// The color [text] is painted in.
Color _inkOf(FlowRun f, String text) => f.tester
    .renderObject<RenderParagraph>(find.text(text).first)
    .text
    .style!
    .color!;

/// How far apart two colors read, as WCAG measures it: 4.5 is enough for
/// text, 7 is plenty.
double _contrast(Color a, Color b) {
  final double x = a.computeLuminance();
  final double y = b.computeLuminance();
  return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
}

/// Someone paid on the 30th whose tuition of 2.000.000, due on the 8th,
/// is more than what there is: that day runs out of money, the week after
/// payday, with a whole fortnight behind to close.
Future<QuincenaStore> _runsOutOnThe8th() async {
  final QuincenaStore store = await emptyStore();
  await store.ensureCategories();
  await store.saveProfile(
    Profile(
      name: 'Diego',
      base: Asset.cop,
      schedule: const TwiceMonthly(),
      pay: Decimal.parse('1800000'),
    ),
  );
  await store.setSetting('app.mode', 'own');
  final Account bank = await store.addAccount(
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: Decimal.parse('500000'),
    institution: 'Bancolombia',
  );
  for (final (String amount, DateTime on, String category, String payee)
      in <(String, DateTime, String, String)>[
        ('200000', DateTime(2026, 8, 30, 12), 'groceries', 'D1'),
        ('80000', DateTime(2026, 9, 10, 20), 'restaurants', 'Crepes'),
        ('210000', DateTime(2026, 9, 16, 12), 'groceries', 'D1'),
        ('70000', DateTime(2026, 9, 20, 20), 'restaurants', 'Rappi'),
        // Entered ahead: it is due on the 8th.
        ('2000000', DateTime(2026, 10, 8, 9), 'other', 'Matrícula'),
      ]) {
    await store.addEntry(
      accountId: bank.id,
      amount: Decimal.parse(amount),
      kind: EntryKind.expense,
      date: on,
      category: category,
      payee: payee,
    );
  }
  await store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse('1800000'),
    kind: EntryKind.income,
    date: DateTime(2026, 9, 30, 8),
    category: 'salary',
    payee: 'Nómina',
  );
  return store;
}

/// What the purchase check says, as its title.
String _verdict(PurchaseVerdict v) => switch (v) {
  PurchaseVerdict.fits => 'Te alcanza, según lo que sabe la app',
  PurchaseVerdict.takesApart => 'Te alcanza, pero tocando lo apartado',
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
  // Set up on 14 September, so the pay of the 30th belongs after the
  // balances written that day and its absence is noticed.
  DateTime at = DateTime(2026, 9, 14, 9);
  final QuincenaStore store = QuincenaStore(
    QuincenaDatabase(NativeDatabase.memory()),
    now: () => at,
  );
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
  at = screensNow;
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

/// The account called [name].
Account _account(OwnController own, String name) =>
    own.accounts.firstWhere((Account a) => a.name == name);

/// What the account called [name] holds now, in its own currency.
Decimal _held(OwnController own, String name) =>
    own.balances[_account(own, name).id]!.amount;

/// The movement paid to or received from [payee] for [amount], signed.
Entry _entryOf(OwnController own, String payee, String amount) =>
    own.snapshot!.entries.firstWhere(
      (Entry e) => e.payee == payee && e.amount == Decimal.parse(amount),
    );

/// The row of [entry] in a list of movements.
Finder _row(Entry entry) => find.byWidgetPredicate(
  (Widget w) => w is MovementRow && w.entry.id == entry.id,
);

/// Opens [entry] from the list on screen.
Future<void> _open(FlowRun f, Entry entry) => f.tapFound(_row(entry));

/// Whether the row of [entry] on screen says [text], whole, in a line or a
/// label of its own.
bool _rowSays(Entry entry, String text) => find
    .descendant(of: _row(entry), matching: find.text(text))
    .evaluate()
    .isNotEmpty;

/// The field labelled [label] when it holds [text].
Finder _fieldShows(String label, String text) => find.descendant(
  of: find.widgetWithText(TextField, label),
  matching: find.text(text),
);

/// What the ledger counts as spent in [month] of [year].
int _spentIn(OwnController own, int year, int month) => own.ledger!
    .expensesIn(year, month)
    .fold(0, (int sum, Movement m) => sum + m.amount);

/// Whether the floating «Movimiento» button is in sight.
bool _fabShown(FlowRun f) =>
    f.tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(ScrollAwareFab),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity ==
    1;

/// Types [text] in the search of Movimientos, replacing what was there.
Future<void> _search(FlowRun f, String text) async {
  await f.top();
  await enterTextIn(f.tester, find.byType(TextField).first, text);
  await settle(f.tester);
}

/// The movements a person searching [query] expects: those whose name,
/// note, account or category has it, with or without accents, or whose
/// amount it is, written with or without its points and sign.
List<Entry> _found(FlowRun f, String query) {
  final OwnController own = f.own;
  final String q = _plain(query);
  final String digits = query.replaceAll(RegExp(r'[$.\s]'), '');
  final Decimal? amount = RegExp(r'^\d+$').hasMatch(digits)
      ? Decimal.parse(digits)
      : null;
  return <Entry>[
    for (final Entry e in visibleEntries(own))
      if (e.amount.abs() == amount ||
          <String>[
            e.payee,
            e.note,
            // A transfer by either of its accounts.
            for (final Entry leg in own.snapshot!.entries)
              if (leg.id == e.id ||
                  (e.transferId != null && leg.transferId == e.transferId))
                own.snapshot!.account(leg.accountId)?.name ?? '',
            if (e.category case final String c)
              categoryLabel(c, 'es', custom: _customName(own, c)),
          ].any((String s) => _plain(s).contains(q)))
        e,
  ];
}

/// The ids of the movements whose rows are on screen.
Set<String> _shownIds(FlowRun f) => <String>{
  for (final MovementRow r in f.tester.widgetList<MovementRow>(
    find.byType(MovementRow),
  ))
    r.entry.id,
};

/// What Movimientos' search holds.
String _searchText(FlowRun f) =>
    f.tester.widget<TextField>(find.byType(TextField).first).controller!.text;

/// [minor] in the ledger's unit with its sign, as the line over what a
/// search found writes it.
String _signed(OwnController own, int minor) =>
    pesos(own.ledger!.major(minor), signed: true);

/// What the day titled [day] says its movements add up to, if anything.
String? _dayTotal(FlowRun f, String day) {
  final List<Text> texts = f.tester
      .widgetList<Text>(
        find.descendant(
          of: find.ancestor(
            of: find.text(day),
            matching: find.byType(SectionLabel),
          ),
          matching: find.byType(Text),
        ),
      )
      .toList();
  return texts.length < 2 ? null : texts.last.data;
}

/// The «¿Repetido?» mark in the row of [entry].
Finder _markOf(Entry entry) => find.descendant(
  of: _row(entry),
  matching: find.widgetWithText(ActionChip, '¿Repetido?'),
);

/// Takes the notice at the bottom away, as its time running out would.
Future<void> _hideNotice(FlowRun f) async {
  for (final ScaffoldMessengerState m in f.tester.stateList(
    find.byWidgetPredicate((Widget w) => w is ScaffoldMessenger),
  )) {
    m.removeCurrentSnackBar();
  }
  await settle(f.tester);
}

String? _customName(OwnController own, String key) {
  for (final CategoryItem c in own.categories) {
    if (c.key == key) return c.name;
  }
  return null;
}

/// [text] in lowercase without accents.
String _plain(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n');

/// Taps [label] on the open date picker, as Material writes it.
Future<void> _tapPicker(FlowRun f, String label) async {
  await f.tester.tap(
    find
        .byWidgetPredicate(
          (Widget w) =>
              w is Text && (w.data == label || w.data == label.toUpperCase()),
        )
        .last,
  );
  await settle(f.tester);
}

/// Types [text] in the field labelled [label] a key at a time, as a
/// keyboard does: the amount field reads a point typed last as a decimal.
Future<void> _typeKeys(FlowRun f, String label, String text) async {
  final Finder field = find.widgetWithText(TextField, label);
  await f.reveal(field);
  for (var i = 1; i <= text.length; i++) {
    final String typed = f.tester
        .widget<TextField>(field.first)
        .controller!
        .text;
    await enterTextIn(f.tester, field.first, typed + text[i - 1]);
    await f.tester.pump();
  }
  await settle(f.tester);
}

/// The wallet kind of account, as the account form names it.
const String _kindWallet = 'Billetera digital';

/// Someone who has just started: the profile, no accounts and nothing
/// recorded.
Future<QuincenaStore> _noAccounts() async {
  final QuincenaStore store = await emptyStore();
  await store.ensureCategories();
  await store.saveProfile(
    const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
  );
  await store.setSetting('app.mode', 'own');
  return store;
}

/// Someone who eats out more: two whole fortnights behind, the second with
/// twice the restaurants of the first, and the pay of the 30th in.
Future<QuincenaStore> _eatingOutMore() async {
  final QuincenaStore store = await emptyStore();
  await store.ensureCategories();
  await store.saveProfile(
    Profile(
      name: 'Diego',
      base: Asset.cop,
      schedule: const TwiceMonthly(),
      pay: Decimal.parse('2000000'),
    ),
  );
  await store.setSetting('app.mode', 'own');
  final Account bank = await store.addAccount(
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: Decimal.parse('1000000'),
    institution: 'Bancolombia',
  );
  for (final (String amount, DateTime on, String category, String payee)
      in <(String, DateTime, String, String)>[
        ('300000', DateTime(2026, 8, 30, 12), 'groceries', 'Éxito'),
        ('100000', DateTime(2026, 9, 5, 20), 'restaurants', 'Crepes'),
        ('290000', DateTime(2026, 9, 16, 12), 'groceries', 'D1'),
        ('110000', DateTime(2026, 9, 18, 20), 'restaurants', 'Crepes'),
        ('90000', DateTime(2026, 9, 25, 21), 'restaurants', 'Rappi'),
      ]) {
    await store.addEntry(
      accountId: bank.id,
      amount: Decimal.parse(amount),
      kind: EntryKind.expense,
      date: on,
      category: category,
      payee: payee,
    );
  }
  await store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse('2000000'),
    kind: EntryKind.income,
    date: DateTime(2026, 9, 30, 8),
    category: 'salary',
    payee: 'Nómina',
  );
  return store;
}
