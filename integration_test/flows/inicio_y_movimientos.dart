// Flows of Inicio (02) and Movimientos (03).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';

import '../tour.dart';
import 'flow.dart';

final List<AppFlow> inicioYMovimientosFlows = <AppFlow>[
  AppFlow(
    '03-01-registrar-un-gasto',
    'Registrar un gasto a mano',
    area: 'Movimientos',
    goal:
        'Pagué un almuerzo en efectivo y quiero anotarlo para que lo que '
        'puedo gastar baje.',
    data: fullAccount,
    (FlowRun f) async {
      final int free = f.own.ledger!.freeUntilPayday;
      final int entries = f.own.snapshot!.entries.length;
      await f.step('Inicio: cuánto puedes gastar antes de anotar el gasto.');
      await f.tapTip('Agregar movimiento');
      await f.step(
        'Toca «+ Movimiento»: el formulario abre en Gasto, con la cuenta que '
        'más usas ya elegida.',
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
        'De vuelta en Inicio: «Puedes gastar» bajó en lo que costó el '
        'almuerzo.',
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
      });
      final String before = pesos(f.own.ledger!.major(free));
      final String after = pesos(f.own.ledger!.major(free - 32000));
      await f.check('Lo que puedes gastar pasó de $before a $after', () {
        expect(f.own.ledger!.freeUntilPayday, free - 32000);
      });
    },
  ),
];
