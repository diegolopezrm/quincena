// Flows of Primeros pasos (01), Ajustes (09), Varios dispositivos y respaldo (10).
import 'dart:convert';

// The picker hands over files as cross_file's, and its fake must too.
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app.dart';
import 'package:quincena/backup/backup.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/projection.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/exchanges/binance_link.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/licenses.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/sync_file.dart';
import 'package:quincena/sync/merge.dart' show SyncConflict;
import 'package:quincena/sync/sync_service.dart';
import 'package:quincena/sync/vault.dart';
import 'package:quincena/version.dart';
import 'package:quincena/ui/home_page.dart';
import 'package:quincena/ui/own/capture_rules_page.dart';
import 'package:quincena/ui/own/look.dart' show Panel, SectionLabel, moneyText;
import 'package:quincena/ui/own/own_settings_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/ui/own/statement_page.dart';
import 'package:quincena/data/example_prices.dart';
// Links open through it; the fake keeps the app on screen.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../test/own_flow_test.dart' show fakeRates, settle;
import '../../test_screens/accounts.dart' show screensNow, seeded;
import '../tour.dart';
import 'flow.dart';

final List<AppFlow> primerosPasosYAjustesFlows = <AppFlow>[
  AppFlow(
    '01-01-elegir-como-empezar',
    'Elegir entre el ejemplo y mis cuentas',
    area: 'Primeros pasos',
    goal:
        'Quiero ver primero cómo funciona con datos de ejemplo y después '
        'pasar a mis propias cuentas.',
    (FlowRun f) async {
      await f.step(
        'La primera pantalla: «Con mis cuentas» o «Con datos de ejemplo». '
        'Abajo dice que tus cuentas se guardan solo en este dispositivo.',
      );
      await f.tap('Con datos de ejemplo');
      await f.step(
        'Toca «Con datos de ejemplo»: abre toda la app con la cuenta de '
        'Valentina, con la franja «Cuenta de ejemplo de Valentina» arriba y '
        'el botón «Usar mis cuentas».',
      );
      await f.check('La app recuerda que se eligió el ejemplo', () async {
        expect(await _read(f, () => _store(f).setting('app.mode')), 'demo');
        expect(_own(f).example, isTrue);
      });
      await f.tap('Usar mis cuentas');
      await f.step(
        'Toca «Usar mis cuentas»: empieza la configuración, «Paso 1 de 4», '
        'con la pregunta por tu nombre.',
      );
      await f.check('Todavía no hay un perfil guardado', () async {
        expect(await _read(f, () => _store(f).profile()), isNull);
      });
      await f.tapTip('Atrás');
      await f.step(
        'Con la flecha «Atrás» en el paso 1 vuelves a la primera pantalla, '
        'no al ejemplo de donde venías.',
      );
      await f.check('Se ve otra vez la primera pantalla', () {
        expect(f.shows('¿Cómo quieres empezar?'), isTrue);
      });
    },
  ),
  AppFlow(
    '01-02-configurar-mis-cuentas',
    'Configurar la app con mis cuentas y pagos fijos',
    area: 'Primeros pasos',
    goal:
        'Me pagan cada quincena y quiero que la app sepa qué tengo en el '
        'banco, en efectivo, lo que debo en la tarjeta y lo que pago fijo.',
    (FlowRun f) async {
      await f.tap('Con mis cuentas');
      await f.tap('Siguiente');
      await f.step(
        'Sin nombre, «Siguiente» no avanza: el campo se pone en rojo y pide '
        '«Tu nombre».',
      );
      await f.type('Tu nombre', 'Diego');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.step(
        'Con el nombre escrito, abre la moneda de los totales: pesos, dólares, '
        'euros y otras. El aviso rojo sigue hasta volver a tocar «Siguiente».',
      );
      await f.tapFound(find.text('COP · Peso colombiano').last);
      await f.tap('Siguiente');
      await f.step(
        'Paso 2: «¿Cómo te pagan?». Viene marcado «Quincenal», los días 15 y '
        '30, y abajo cuánto te llega cada quincena.',
      );
      await f.type('Monto', '2400000');
      await f.step(
        'Escribe 2.400.000 en lo que te llega cada quincena: es opcional y '
        'no cuenta como plata hasta que llega.',
      );
      await f.tap('Siguiente');
      await f.check(
        'El perfil quedó con nombre, pesos, quincena y pago',
        () async {
          final Profile? p = await _read(f, () => _store(f).profile());
          expect(p?.name, 'Diego');
          expect(p?.base, Asset.cop);
          expect(p?.schedule, const TwiceMonthly());
          expect(p?.pay, Decimal.parse('2400000'));
        },
      );
      await f.step(
        'Paso 3: «Agrega tus cuentas», con sugerencias para empezar rápido: '
        'Bancolombia, Nequi, Efectivo, tarjeta, dólares y Binance.',
      );
      await f.tap('Siguiente');
      await f.step(
        'Sin cuentas, «Siguiente» no avanza y avisa abajo: «Agrega al menos '
        'una cuenta para empezar».',
      );
      await f.tap('Bancolombia · COP');
      await f.type('¿Cuánto tiene hoy?', '1500000');
      await f.page(
        'Toca «Bancolombia · COP»: el formulario viene lleno con el nombre, '
        'tipo Banco y la entidad; solo falta cuánto tiene hoy.',
      );
      await f.tap('Guardar');
      await f.tap('Tarjeta de crédito · COP');
      await f.type('¿Cuánto debes hoy?', '480000');
      await f.type('Cupo total (opcional)', '3000000');
      await f.step(
        'La tarjeta pregunta «¿Cuánto debes hoy?» y el cupo, y explica que '
        'el cupo nunca se suma a lo que puedes gastar.',
      );
      await f.tap('Guardar');
      await f.tap('Efectivo · COP');
      await f.type('¿Cuánto tiene hoy?', '60000');
      await f.tap('Guardar');
      // The other suggestions come filled in too.
      for (final (String chip, String name, String kind) in _otherSuggestions) {
        await f.tap(chip);
        await f.check('«$chip» abre el formulario de $name, tipo $kind', () {
          expect(find.widgetWithText(TextField, name), findsWidgets);
          expect(
            f.tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, kind))
                .selected,
            isTrue,
          );
        });
        await f.back();
      }
      await f.step(
        'Bancolombia, la tarjeta y el efectivo quedan en la lista con su '
        'saldo; la tarjeta muestra lo que debes.',
      );
      await f.check('Quedaron tres cuentas con lo que se escribió', () async {
        final List<Account> accounts = await _read(
          f,
          () => _store(f).accounts(),
        );
        expect(
          <String, String>{
            for (final Account a in accounts) a.name: '${a.opening}',
          },
          <String, String>{
            'Bancolombia': '1500000',
            'Tarjeta de crédito': '-480000',
            'Efectivo': '60000',
          },
        );
        final Account card = accounts.firstWhere(
          (Account a) => a.kind == AccountKind.card,
        );
        expect(card.creditLimit, Decimal.parse('3000000'));
      });
      await f.tap('Siguiente');
      await f.page(
        'Paso 4: «¿Qué pagas fijo?», con sugerencias: Arriendo, '
        'Administración, Servicios, Internet, Plan del celular, suscripción.',
      );
      await f.tap('Arriendo');
      await f.type('¿Cuánto cobra?', '1650000');
      await f.page(
        'Toca «Arriendo»: viene con nombre y categoría Arriendo, cada mes, '
        'el 1 del mes siguiente y pagado desde Bancolombia.',
      );
      await f.tapContaining('Próximo cobro');
      await f.step(
        'Toca «Próximo cobro»: un calendario para elegir el día en que se '
        'paga el arriendo.',
      );
      await f.tapFound(find.text('5').last);
      await f.tap('Aceptar');
      await f.tap('Guardar');
      for (final String chip in _otherFixed) {
        await f.tap(chip);
        await f.check('«$chip» abre el pago fijo con ese nombre', () {
          expect(find.widgetWithText(TextField, chip), findsOneWidget);
        });
        await f.back();
      }
      await f.tap('Una suscripción');
      await f.type('¿Qué es?', 'Netflix');
      await f.type('¿Cuánto cobra?', '26900');
      await f.page(
        '«Una suscripción» llega sin nombre: escribe Netflix y 26.900. Al '
        'ser suscripción pregunta por prueba gratis y si la sigues usando.',
      );
      await f.tap('Guardar');
      await f.step(
        'El arriendo y Netflix quedan en la lista con su próximo cobro y '
        'su valor. «No tengo pagos fijos» ya no aparece.',
      );
      await f.check(
        'Quedaron dos pagos fijos, el arriendo el 5 de nov',
        () async {
          final List<RecurringCharge> fixed = await _read(
            f,
            () => _store(f).recurring(),
          );
          expect(fixed.map((RecurringCharge r) => r.name).toSet(), <String>{
            'Arriendo',
            'Netflix',
          });
          final RecurringCharge rent = fixed.firstWhere(
            (RecurringCharge r) => r.name == 'Arriendo',
          );
          expect(rent.nextDate, DateTime(2026, 11, 5));
          expect(rent.amount.amount, Decimal.parse('1650000'));
          expect(rent.category, 'housing');
        },
      );
      await f.tap('Empezar');
      await f.page(
        'Toca «Empezar»: puedes gastar el banco y el efectivo menos lo que '
        'debes en la tarjeta hasta el 15 de octubre, sin «Provisional». '
        'Más abajo, «Próximos días» dice que el mínimo antes del pago es el '
        'de hoy y no avisa de ningún día sin plata.',
      );
      await f.check(
        'Puedes gastar ${pesos(1080000)}: el banco y el efectivo menos la '
        'tarjeta',
        () {
          // Nothing fixed falls before the 15th.
          expect(_own(f).ledger!.freeUntilPayday, 1080000);
          expect(f.screenText, contains(pesos(1080000)));
        },
      );
      await f.check(
        'Recién configurada, Inicio no pide registrar el pago del 30 de '
        'septiembre, que ya estaba en los saldos escritos',
        () {
          expect(_own(f).projection!.latePay, isNull);
          expect(f.shows('Registra tu pago del 30 de septiembre'), isFalse);
        },
      );
      await f.check('La cifra no es provisional', () {
        expect(_own(f).provisional, isFalse);
        expect(f.shows('Provisional: faltan tus pagos fijos'), isFalse);
      });
      await f.check(
        '«Próximos días» no avisa que te quedes sin plata: los pagos del 15 y '
        'del 31 de octubre llegan antes del arriendo del 5 de noviembre, y '
        'sin colchón no habla de él',
        () {
          final Projection p = _own(f).projection!;
          expect(_own(f).ledger!.cushion, 0);
          expect(p.firstTight, isNull);
          expect(f.screenText, isNot(contains('te quedarías sin plata')));
          expect(f.screenText, isNot(contains('colchón')));
        },
      );
      await f.check(
        'Nada baja el saldo antes del pago: dice que lo mínimo libre es lo '
        'de hoy, sin nombrar el 3 de octubre como otro día',
        () {
          final ProjectedDay low = _own(f).projection!.lowestBeforePayday;
          expect(low.date, DateTime(2026, 10, 3));
          expect(
            f.shows(
              'Lo mínimo que tendrás libre antes del pago es lo de hoy: '
              '${pesos(1080000)}.',
            ),
            isTrue,
          );
          expect(f.screenText, isNot(contains('el 3 de octubre')));
        },
      );
      await f.check('La app abre en adelante en tus cuentas', () async {
        expect(await _read(f, () => _store(f).setting('app.mode')), 'own');
      });
    },
  ),
  AppFlow(
    '01-03-agregar-una-cuenta-a-mano',
    'Agregar, corregir y quitar una cuenta al empezar',
    area: 'Primeros pasos',
    goal:
        'Mi banco no está en las sugerencias: quiero escribir la cuenta yo '
        'mismo, corregir el saldo si me equivoco y quitarla si sobra.',
    (FlowRun f) async {
      await _toAccountsStep(f, 'Laura');
      await f.tap('Agregar cuenta');
      await f.tap('Guardar');
      await f.step(
        '«Agregar cuenta» abre el formulario vacío. «Guardar» sin nombre no '
        'guarda: el campo pide un nombre, por ejemplo Bancolombia ahorros.',
      );
      await f.type('Nombre', 'Davivienda nómina');
      await f.tap('Ahorro o inversión');
      await f.step(
        'Con el tipo «Ahorro o inversión», «Cuenta de uso diario» se apaga '
        'sola: su saldo no cuenta en lo que puedes gastar.',
      );
      await f.check('Un ahorro no cuenta para gastar', () {
        expect(_switchOf(f, 'Cuenta de uso diario'), isFalse);
      });
      await f.tap('Banco');
      await f.check('Con «Banco» vuelve a contar para gastar', () {
        expect(_switchOf(f, 'Cuenta de uso diario'), isTrue);
      });
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.step(
        'Toca «Banco» (vuelve a ser de uso diario) y abre «Moneda»: monedas, '
        'cripto y «Otra cripto» para escribir cualquier otra.',
      );
      await f.tapFound(find.text('COP · Peso colombiano').last);
      await f.type('Entidad (opcional)', 'Davivienda');
      await f.type('¿Cuánto tiene hoy?', '850000');
      await f.tap('Guardar');
      await f.step(
        'Guardada: Davivienda nómina aparece arriba con 850.000, y debajo '
        'siguen las sugerencias.',
      );
      await f.check('La cuenta quedó con 850.000 y de uso diario', () async {
        final Account a = (await _read(f, () => _store(f).accounts())).single;
        expect(a.name, 'Davivienda nómina');
        expect(a.institution, 'Davivienda');
        expect(a.opening, Decimal.parse('850000'));
        expect(a.spendable, isTrue);
      });
      await f.tap('Davivienda nómina');
      await f.type('¿Cuánto tiene hoy?', '900000');
      await f.step(
        'Tocar la cuenta abre «Editar cuenta»: la moneda ya no se cambia y el '
        'saldo se corrige a 900.000.',
      );
      await f.tap('Guardar');
      await f.check('El saldo pasó de 850.000 a 900.000', () async {
        final Account a = (await _read(f, () => _store(f).accounts())).single;
        expect(a.opening, Decimal.parse('900000'));
      });
      await f.tap('Davivienda nómina');
      await f.tap('Eliminar');
      await f.step(
        '«Eliminar» pregunta antes: «¿Eliminar Davivienda nómina?», y dice que '
        'no tiene movimientos.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» la cuenta sigue ahí', () async {
        expect(await _read(f, () => _store(f).accounts()), hasLength(1));
      });
      await f.tap('Eliminar');
      await f.tap('Eliminar');
      await f.step(
        'Con «Eliminar» la cuenta se va y el paso vuelve a mostrar solo '
        '«Agregar cuenta» y las sugerencias.',
      );
      await f.check('No queda ninguna cuenta', () async {
        expect(await _read(f, () => _store(f).accounts()), isEmpty);
      });
      await f.tapTip('Atrás');
      await f.tapTip('Atrás');
      await f.step(
        'Con «Atrás» dos veces vuelves al paso 1 con el nombre que habías '
        'escrito; nada se pierde.',
      );
      await f.check('El paso 1 conserva el nombre Laura', () {
        expect(f.shows('Paso 1 de 4'), isTrue);
        expect(find.widgetWithText(TextField, 'Laura'), findsOneWidget);
      });
    },
  ),
  AppFlow(
    '01-04-mensual-en-dolares-sin-pagos-fijos',
    'Empezar en dólares, con pago mensual y sin pagos fijos',
    area: 'Primeros pasos',
    goal:
        'Cobro en dólares una vez al mes y no pago arriendo ni suscripciones: '
        'quiero que la app lo sepa sin inventarse nada.',
    (FlowRun f) async {
      await f.tap('Con mis cuentas');
      await f.type('Tu nombre', 'Ana');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('USD · Dólar estadounidense').last);
      await f.step(
        'Escribe «Ana» y elige «USD · Dólar estadounidense» para ver los '
        'totales en dólares.',
      );
      await f.tap('Siguiente');
      await f.tap('Mensual');
      await f.tapFound(find.byType(DropdownButtonFormField<int>));
      await f.step(
        'Toca «Mensual»: aparece «Día de pago», con los días del 1 al 31 '
        'para elegir.',
      );
      await f.tapFound(find.text('Día 25').last);
      await f.type('Monto', '3000');
      await f.step(
        'Con el día 25 elegido, la opción dice «El día 25 de cada mes». La '
        'pregunta cambia a «¿Cuánto te llega cada pago?» y el monto va en USD.',
      );
      await f.tap('Siguiente');
      await f.check('Quedó mensual el 25, en dólares y con 3.000', () async {
        final Profile? p = await _read(f, () => _store(f).profile());
        expect(p?.base, Asset.usd);
        expect(p?.schedule, const Monthly(25));
        expect(p?.pay, Decimal.parse('3000'));
      });
      await f.step(
        'En dólares las sugerencias cambian: Banco, Efectivo y Tarjeta en '
        'USD, y Binance; ya no aparecen Bancolombia ni Nequi.',
      );
      await f.check('Las sugerencias son las de alguien que cuenta en USD', () {
        expect(f.shows('Banco · USD'), isTrue);
        expect(f.shows('Bancolombia · COP'), isFalse);
        expect(f.shows('Cuenta en dólares · USD'), isFalse);
      });
      for (final (String chip, String kind) in <(String, String)>[
        ('Efectivo · USD', 'Efectivo'),
        ('Tarjeta de crédito · USD', 'Tarjeta de crédito'),
      ]) {
        await f.tap(chip);
        await f.check('«$chip» abre el formulario en dólares, tipo $kind', () {
          expect(f.shows('USD · Dólar estadounidense'), isTrue);
          expect(
            f.tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, kind))
                .selected,
            isTrue,
          );
        });
        await f.back();
      }
      await f.tap('Banco · USD');
      await f.type('¿Cuánto tiene hoy?', '2500');
      await f.tap('Guardar');
      await f.tap('Siguiente');
      await f.step(
        'En el paso 4, mientras no haya pagos fijos, abajo aparece «No tengo '
        'pagos fijos» además de «Empezar».',
      );
      await f.tap('No tengo pagos fijos');
      await f.step(
        'Con «No tengo pagos fijos» Inicio muestra lo que puedes gastar en '
        'dólares hasta el 25 de octubre, sin la marca «Provisional».',
      );
      final String free = pesos(_own(f).ledger!.major(250000));
      await f.check('Puedes gastar $free hasta el 25 de octubre', () {
        expect(_own(f).ledger!.freeUntilPayday, 250000);
        expect(_own(f).ledger!.nextPayday, DateTime(2026, 10, 25));
        expect(f.screenText, contains(free));
      });
      await f.check('La app recuerda que no hay pagos fijos', () {
        expect(_own(f).noFixedPayments, isTrue);
        expect(_own(f).provisional, isFalse);
        expect(f.shows('Provisional: faltan tus pagos fijos'), isFalse);
      });
    },
  ),
  AppFlow(
    '01-05-cada-dos-semanas-o-semanal',
    'Pagos cada dos semanas o semanales, y empezar sin pagos fijos',
    area: 'Primeros pasos',
    goal:
        'No me pagan por quincenas: quiero contar desde mi último pago o por '
        'semanas, y empezar ya aunque no tenga a mano los pagos fijos.',
    (FlowRun f) async {
      await f.tap('Con mis cuentas');
      await f.type('Tu nombre', 'Camilo');
      await f.tap('Siguiente');
      await f.tap('Cada dos semanas');
      await f.step(
        'Toca «Cada dos semanas»: cuenta 14 días desde un pago que conoces; '
        'el botón «Tu último pago» dice desde cuál.',
      );
      await f.tapContaining('Tu último pago');
      await f.step(
        'Al tocarlo se abre el calendario «Tu último pago», en el día que '
        'venía marcado.',
      );
      await f.tapFound(find.text('1').last);
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» sigue contando desde hoy, el 3', () {
        expect(f.shows('Cada 14 días, contando desde el 3 oct 2026'), isTrue);
      });
      await f.tapContaining('Tu último pago');
      await f.tapFound(find.text('1').last);
      await f.tap('Aceptar');
      await f.step(
        'Con el 1 de octubre elegido, la opción dice «Cada 14 días, contando '
        'desde el 1 oct 2026».',
      );
      await f.tap('Siguiente');
      await f.check('El próximo pago queda el 15 de octubre', () async {
        final Profile? p = await _read(f, () => _store(f).profile());
        expect(p?.schedule, EveryTwoWeeks(DateTime(2026, 10, 1)));
        expect(
          p?.schedule.nextAfter(DateTime(2026, 10, 3)),
          DateTime(2026, 10, 15),
        );
      });
      await f.tapTip('Atrás');
      await f.tap('Semanal');
      await f.tapFound(find.byType(DropdownButtonFormField<int>));
      await f.step(
        'De vuelta en el paso 2, «Semanal» pide el día de la semana: viene '
        'el viernes y se puede elegir otro.',
      );
      await f.tapFound(find.text('lunes').last);
      await f.tap('Siguiente');
      await f.check('Ahora le pagan cada lunes', () async {
        final Profile? p = await _read(f, () => _store(f).profile());
        expect(p?.schedule, const Weekly(DateTime.monday));
      });
      await f.tap('Bancolombia · COP');
      await f.type('¿Cuánto tiene hoy?', '500000');
      await f.tap('Guardar');
      await f.tap('Siguiente');
      await f.tap('Empezar');
      await f.step(
        '«Empezar» sin pagos fijos: «Puedes gastar» lleva «Provisional: '
        'faltan tus pagos fijos» y lo primero por hacer es agregarlos.',
      );
      await f.check('La cifra es provisional y llega hasta el lunes 5', () {
        expect(_own(f).provisional, isTrue);
        expect(_own(f).ledger!.nextPayday, DateTime(2026, 10, 5));
        expect(f.shows('Provisional: faltan tus pagos fijos'), isTrue);
        expect(f.shows('Agrega tus pagos fijos'), isTrue);
      });
      await f.tap('Agregar');
      await f.step(
        '«Agregar» en «Por hacer» lleva a «Pagos fijos», donde también está '
        '«No tengo pagos fijos».',
      );
      await f.tap('No tengo pagos fijos');
      await f.check('Desde Pagos fijos también se dice que no hay', () {
        expect(_own(f).noFixedPayments, isTrue);
        expect(_own(f).provisional, isFalse);
      });
      await f.back();
      await f.top();
      await f.step(
        'De vuelta en Inicio, abajo dice «Listo. Lo que puedes gastar ya no es '
        'provisional.» y «Agrega tus pagos fijos» salió de «Por hacer».',
      );
      await f.check('Inicio ya no pide los pagos fijos', () {
        expect(f.shows('Provisional: faltan tus pagos fijos'), isFalse);
        expect(f.shows('Agrega tus pagos fijos'), isFalse);
        expect(f.screenText, contains(pesos(500000)));
      });
    },
  ),
  AppFlow(
    '01-06-retomar-la-configuracion',
    'Volver a la configuración que dejé a medias',
    area: 'Primeros pasos',
    goal:
        'Empecé a configurar, me salí antes de agregar cuentas y quiero '
        'seguir donde iba, sin quedar en una app vacía.',
    (FlowRun f) async {
      await _toAccountsStep(f, 'Laura');
      await f.tapTip('Atrás');
      await f.tapTip('Atrás');
      await f.tapTip('Atrás');
      await f.step(
        'Después de llegar al paso 3, «Atrás» tres veces devuelve a la '
        'primera pantalla. El perfil de Laura ya quedó guardado.',
      );
      await f.tap('Con mis cuentas');
      await f.step(
        'Al tocar otra vez «Con mis cuentas» la configuración sigue donde '
        'iba: el paso 1 ya trae el nombre de Laura.',
      );
      await f.check(
        'Vuelve a la configuración, no a un Inicio sin cuentas',
        () {
          expect(f.shows('Paso 1 de 4'), isTrue);
        },
      );
      await f.check('Con el nombre de Laura ya escrito', () {
        expect(find.widgetWithText(TextField, 'Laura'), findsOneWidget);
      });
      await f.tap('Siguiente');
      await f.tap('Siguiente');
      await f.tap('Nequi · COP');
      await f.type('¿Cuánto tiene hoy?', '320000');
      await f.tap('Guardar');
      await f.tap('Siguiente');
      await f.tap('No tengo pagos fijos');
      await f.step(
        'Con «Siguiente» hasta las cuentas, Nequi con 320.000 y «No tengo '
        'pagos fijos», Laura llega a su Inicio.',
      );
      await f.check('Puedes gastar ${pesos(320000)}', () {
        expect(_own(f).ledger!.freeUntilPayday, 320000);
        expect(_own(f).profile!.name, 'Laura');
      });
    },
  ),
  AppFlow(
    '01-07-mis-dias-de-quincena-y-un-pago-a-mano',
    'Escoger mis días de quincena y escribir un pago fijo a mano',
    area: 'Primeros pasos',
    goal:
        'Me pagan el 10 y el 25, y pago un gimnasio que no está en las '
        'sugerencias: quiero escribirlo, corregirlo y quitarlo si me equivoco.',
    (FlowRun f) async {
      await f.tap('Con mis cuentas');
      await enterTextIn(f.tester, find.byType(TextField).first, 'Sofía');
      // «Siguiente» on the keyboard moves on, as the button does.
      await pressKeyIn(
        f.tester,
        find.byType(TextField).first,
        TextInputAction.next,
      );
      await settle(f.tester);
      await f.check('«Siguiente» del teclado pasa al paso 2', () {
        expect(f.shows('Paso 2 de 4'), isTrue);
      });
      await f.tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await settle(f.tester);
      await f.step(
        'En «Quincenal», «Primer pago» abre la lista de días del 1 al 27 '
        'para escoger el primero.',
      );
      await f.tapFound(find.text('Día 10').last);
      await f.tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await settle(f.tester);
      await f.tapFound(find.text('Día 25').last);
      await f.step(
        'Con el 10 y el 25 escogidos, la opción dice «Los días 10 y 25 de '
        'cada mes».',
      );
      await f.check('La opción quincenal muestra los días 10 y 25', () {
        expect(f.shows('Los días 10 y 25 de cada mes'), isTrue);
      });
      await f.tap('Siguiente');
      await f.check('El perfil quedó con quincenas el 10 y el 25', () async {
        final Profile? p = await _read(f, () => _store(f).profile());
        expect(p?.schedule, const TwiceMonthly(first: 10, second: 25));
      });
      await f.tap('Nequi · COP');
      await f.type('¿Cuánto tiene hoy?', '400000');
      await f.tap('Guardar');
      await f.tap('Siguiente');
      await f.tap('Agregar pago fijo');
      await f.step(
        '«Agregar pago fijo» abre el formulario vacío: cada mes, próximo cobro '
        'el 3 de noviembre, pagado desde Nequi y en Suscripciones.',
      );
      await f.tap('Guardar');
      await f.reveal(find.text('Falta el nombre o el valor.'));
      await f.step(
        '«Guardar» sin nombre ni valor no guarda: arriba del botón dice «Falta '
        'el nombre o el valor.»',
      );
      await f.check('Sin nombre ni valor no se guarda', () async {
        expect(await _read(f, () => _store(f).recurring()), isEmpty);
      });
      await f.type('¿Qué es?', 'Gimnasio');
      await f.type('¿Cuánto cobra?', '90000');
      await f.tap('Guardar');
      await f.step(
        'Con «Gimnasio» y 90.000, el pago queda en la lista con su próximo '
        'cobro y su valor.',
      );
      await f.check(
        'Quedó el gimnasio por 90.000, pagado desde Nequi, como suscripción '
        'y con cobro el 3 de noviembre',
        () async {
          final RecurringCharge gym = (await _read(
            f,
            () => _store(f).recurring(),
          )).single;
          expect(gym.name, 'Gimnasio');
          expect(gym.amount.amount, Decimal.parse('90000'));
          expect(gym.category, 'subscriptions');
          expect(gym.nextDate, DateTime(2026, 11, 3));
          final List<Account> accounts = await _read(
            f,
            () => _store(f).accounts(),
          );
          expect(gym.accountId, accounts.single.id);
        },
      );
      await f.tap('Gimnasio');
      await f.type('¿Cuánto cobra?', '95000');
      await f.page(
        'Tocar el pago lo abre como «Pago fijo»: se corrige el valor a 95.000 '
        'y abajo están «Pausar» y «Borrar pago fijo».',
      );
      await f.tap('Guardar');
      await f.check('El gimnasio ahora cobra 95.000', () async {
        final RecurringCharge gym = (await _read(
          f,
          () => _store(f).recurring(),
        )).single;
        expect(gym.amount.amount, Decimal.parse('95000'));
      });
      await f.tap('Gimnasio');
      await f.tap('Borrar pago fijo');
      await f.step(
        '«Borrar pago fijo» pregunta antes: «¿Borrar Gimnasio?», y explica '
        'que deja de contarse como comprometido.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el gimnasio sigue', () async {
        expect(await _read(f, () => _store(f).recurring()), hasLength(1));
      });
      await f.tap('Borrar pago fijo');
      await f.tap('Borrar pago fijo');
      await f.step(
        'Con «Borrar pago fijo» la lista queda vacía y vuelve a aparecer «No '
        'tengo pagos fijos» bajo «Empezar».',
      );
      await f.check('No queda ningún pago fijo', () async {
        expect(await _read(f, () => _store(f).recurring()), isEmpty);
        expect(f.shows('No tengo pagos fijos'), isTrue);
      });
      await f.tapTip('Atrás');
      await f.step(
        '«Atrás» en el paso 4 vuelve a las cuentas: Nequi sigue ahí con sus '
        '400.000.',
      );
      await f.check('El paso 3 conserva la cuenta Nequi', () {
        expect(f.shows('Paso 3 de 4'), isTrue);
        expect(f.shows('Nequi'), isTrue);
      });
      await f.tap('Siguiente');
      await f.tap('No tengo pagos fijos');
      await f.step(
        'Con «No tengo pagos fijos», Inicio cuenta hasta el 10 de octubre, '
        'el próximo de sus días de pago.',
      );
      await f.check('El próximo pago es el 10 de octubre', () {
        expect(_own(f).ledger!.nextPayday, DateTime(2026, 10, 10));
        expect(_own(f).ledger!.freeUntilPayday, 400000);
      });
    },
  ),
  AppFlow(
    '01-08-configurar-en-ingles-y-en-euros',
    'Configurar la app en inglés y en euros',
    area: 'Primeros pasos',
    goal:
        'Vivo fuera de Colombia y uso el teléfono en inglés: quiero configurar '
        'Quincena en inglés, con mis cuentas en euros y pago mensual.',
    english: true,
    (FlowRun f) async {
      await f.step(
        'Con el teléfono en inglés, la primera pantalla pregunta «How do you '
        'want to start?»: «With my accounts» o «With sample data».',
      );
      await f.tap('With my accounts');
      await f.type('Your name', 'Sam');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('EUR · Euro').last);
      await f.step(
        'Paso 1 en inglés: «What\'s your name?» con Sam escrito y la moneda '
        'de los totales en «EUR · Euro».',
      );
      await f.tap('Next');
      await f.tap('Monthly');
      await f.type('Amount', '2800');
      await f.step(
        '«How do you get paid?»: «Monthly», el día 30, y 2.800 euros en «How '
        'much do you get each payday?».',
      );
      await f.tap('Next');
      await f.check(
        'Quedó en euros, mensual el 30 y con 2.800 de pago',
        () async {
          final Profile? p = await _read(f, () => _store(f).profile());
          expect(p?.name, 'Sam');
          expect(p?.base, Asset.of('EUR'));
          expect(p?.schedule, const Monthly(30));
          expect(p?.pay, Decimal.parse('2800'));
        },
      );
      await f.step(
        '«Add your accounts», con sugerencias en euros: «Bank · EUR», «Cash · '
        'EUR», «Credit card · EUR», «Dollar account · USD» y Binance.',
      );
      await f.check('Las sugerencias están en inglés y en euros', () {
        for (final String chip in <String>[
          'Bank · EUR',
          'Cash · EUR',
          'Credit card · EUR',
          'Dollar account · USD',
          'Binance · USDT',
        ]) {
          expect(f.shows(chip), isTrue, reason: chip);
        }
        expect(f.screenText, isNot(contains('Cuenta en dólares')));
        expect(f.shows('Bancolombia · COP'), isFalse);
      });
      await f.tap('Bank · EUR');
      await f.type('How much is in it today?', '1500');
      await f.tap('Save');
      await f.tap('Next');
      await f.step(
        '«What do you pay regularly?» sugiere «Rent», «Building fee», '
        '«Utilities», «Internet», «Phone plan» y «A subscription».',
      );
      await f.check('Los pagos fijos sugeridos están en inglés', () {
        for (final String chip in <String>[
          'Rent',
          'Building fee',
          'Utilities',
          'Internet',
          'Phone plan',
          'A subscription',
        ]) {
          expect(f.shows(chip), isTrue, reason: chip);
        }
      });
      await f.tap("I don't have recurring payments");
      final String free = pesos(_own(f).ledger!.major(150000));
      await f.step(
        'Inicio en inglés y en euros: «You can spend» $free «until October '
        '30», sin nada en español.',
      );
      await f.check(
        'Puedes gastar $free, en euros, hasta el 30 de octubre',
        () {
          expect(_own(f).ledger!.currency, Asset.of('EUR'));
          expect(_own(f).ledger!.freeUntilPayday, 150000);
          expect(_own(f).ledger!.nextPayday, DateTime(2026, 10, 30));
          expect(f.screenText, contains(free));
        },
      );
      await f.check('Inicio no deja nada en español', () {
        expect(f.shows('You can spend'), isTrue);
        for (final String word in <String>[
          'Puedes gastar',
          'Próximos días',
          'Movimientos',
          'Cuentas',
        ]) {
          expect(f.screenText, isNot(contains(word)), reason: word);
        }
      });
    },
  ),
  AppFlow(
    '09-01-recorrer-ajustes',
    'Recorrer Ajustes de arriba abajo',
    area: 'Ajustes',
    goal:
        'Quiero saber qué puedo cambiar en la app y a dónde lleva cada '
        'opción de Ajustes.',
    data: fullAccount,
    (FlowRun f) async {
      await f.tapTip('Ajustes');
      await f.page(
        'Ajustes va por secciones: «Tu perfil», «Automatización», «Cuentas '
        'conectadas», «Apariencia», «Tus datos» y «Ayuda y privacidad»; al '
        'final, aparte y en rojo, «Borrar todo».',
        most: 8,
      );
      await f.check('Las secciones van en ese orden y «Borrar todo» va solo, '
          'al final', () async {
        expect(_sections(f), <String>[
          'Tu perfil',
          'Automatización',
          'Cuentas conectadas',
          'Apariencia',
          'Tus datos',
          'Ayuda y privacidad',
        ]);
        expect(_settingsRows(f).last, isA<Panel>());
        await f.reveal(find.text('Borrar todo'));
        expect(
          f.tester.getTopLeft(find.text('Borrar todo')).dy,
          greaterThan(
            f.tester.getTopLeft(find.text('Licencias y créditos')).dy,
          ),
        );
      });
      await f.tap('Reglas aprendidas');
      await f.step(
        '«Reglas aprendidas» es ahora una fila propia en «Automatización», '
        'bajo «Captura automática»: abre lo que la app aprendió de tus pagos.',
      );
      await f.check('Abrió las reglas aprendidas', () {
        expect(find.byType(CaptureRulesPage), findsOneWidget);
      });
      await f.back();
      await f.tap('Billeteras propias');
      await f.step(
        'En «Cuentas conectadas», «Billeteras propias» abre la página para '
        'seguir Ledger, MetaMask o Trust Wallet por su dirección pública.',
      );
      await f.check('Abrió Billeteras propias, sin ninguna seguida', () {
        expect(f.shows('Agregar billetera'), isTrue);
        expect(f.shows('Aún no sigues ninguna billetera.'), isTrue);
        expect(_own(f).wallets.wallets, isEmpty);
      });
      await f.back();
      await f.tap('Binance');
      await f.step(
        '«Binance», en la misma sección, abre la conexión con una llave de '
        'solo lectura: Quincena nunca podrá mover tus fondos.',
      );
      await f.check('Binance abre sin conectar, pidiendo las dos llaves', () {
        expect(_own(f).binance.connected, isFalse);
        expect(find.widgetWithText(TextField, 'API Key'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Secret Key'), findsOneWidget);
      });
      await f.back();
      await f.tap('Importar extracto');
      await f.step(
        '«Importar extracto» abre la lectura de un CSV, Excel o PDF de tu '
        'banco, con «Elegir archivo».',
      );
      await f.check('Abrió Importar extracto', () {
        expect(f.shows('Elegir archivo'), isTrue);
      });
      await f.back();
    },
  ),
  AppFlow(
    '09-02-cambiar-nombre-y-moneda',
    'Cambiar mi nombre y la moneda de los totales',
    area: 'Ajustes',
    goal:
        'Quiero que la app me llame como me gusta y ver los totales en '
        'dólares por un rato.',
    data: seeded,
    (FlowRun f) async {
      final int free = _own(f).ledger!.freeUntilPayday;
      await f.tapTip('Ajustes');
      await f.tap('Nombre');
      await enterTextIn(f.tester, find.byType(TextField), 'Diego Alejandro');
      await f.step(
        '«Nombre» abre un cuadro con el nombre actual. Se escribe «Diego '
        'Alejandro».',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el nombre sigue siendo Diego', () {
        expect(_own(f).profile!.name, 'Diego');
      });
      await f.tap('Nombre');
      await enterTextIn(f.tester, find.byType(TextField), '   ');
      await f.tap('Guardar');
      await f.step(
        'Con el nombre en blanco, «Guardar» no cierra el cuadro: bajo el campo '
        'dice «Escribe tu nombre.»',
      );
      await f.check('Un nombre en blanco no se guarda y el cuadro dice qué '
          'falta', () {
        expect(_own(f).profile!.name, 'Diego');
        expect(f.shows('Escribe tu nombre.'), isTrue);
        expect(find.byType(AlertDialog), findsOneWidget);
      });
      await enterTextIn(f.tester, find.byType(TextField), 'Diego Alejandro');
      await settle(f.tester);
      await f.check('Al escribir el nombre, el aviso se va', () {
        expect(f.shows('Escribe tu nombre.'), isFalse);
      });
      await f.tap('Guardar');
      await f.step('Con «Guardar» la fila «Nombre» dice «Diego Alejandro».');
      await f.check('El perfil quedó con el nombre nuevo', () {
        expect(_own(f).profile!.name, 'Diego Alejandro');
      });
      await f.tap('Moneda de los totales');
      await f.step(
        '«Moneda de los totales» muestra las monedas con un visto en la que '
        'usas, el peso colombiano.',
      );
      await f.tap('USD · Dólar estadounidense');
      await f.step(
        'Al elegir USD la fila cambia a «USD · Dólar estadounidense» y los '
        'totales se recalculan en dólares.',
      );
      await f.check('Los totales ahora van en dólares', () {
        expect(_own(f).profile!.base, Asset.usd);
        expect(_own(f).ledger!.currency, Asset.usd);
      });
      await f.back();
      final String usd = pesos(
        _own(f).ledger!.major(_own(f).ledger!.freeUntilPayday),
      );
      await f.step('Inicio muestra lo que puedes gastar en dólares: $usd.');
      await f.check('Inicio dice $usd, lo que calcula la app', () {
        expect(f.screenText, contains(usd));
      });
      await f.tapTip('Ajustes');
      await f.tap('Moneda de los totales');
      await f.tap('COP · Peso colombiano');
      await f.back();
      await f.check(
        'De vuelta en pesos la cifra es la de antes: ${pesos(free)}',
        () {
          expect(_own(f).profile!.base, Asset.cop);
          expect(_own(f).ledger!.freeUntilPayday, free);
        },
      );
    },
  ),
  AppFlow(
    '09-03-cambiar-como-y-cuanto-me-pagan',
    'Cambiar cómo y cuánto me pagan',
    area: 'Ajustes',
    goal:
        'Cambié de trabajo: ahora me pagan una vez al mes y quiero que la app '
        'cuente hasta ese día y sepa cuánto me llega.',
    data: fullAccount,
    (FlowRun f) async {
      await f.tapTip('Ajustes');
      await f.tap('Cómo te pagan');
      await f.step(
        '«Cómo te pagan» abre las mismas opciones del comienzo, con la '
        'quincena del 15 y el 30 marcada.',
      );
      await f.tap('Mensual');
      await f.back();
      await f.check('Cerrar sin «Guardar» deja la quincena', () {
        expect(_own(f).profile!.schedule, const TwiceMonthly());
      });
      await f.tap('Cómo te pagan');
      await f.tap('Mensual');
      await f.step('Toca «Mensual»: queda el día 30 de cada mes.');
      await f.tap('Guardar');
      await f.step(
        'Con «Guardar», la fila dice «Mensual: el día 30 de cada mes».',
      );
      await f.check('Ahora el próximo pago es el 30 de octubre', () {
        expect(_own(f).profile!.schedule, const Monthly(30));
        expect(_own(f).ledger!.nextPayday, DateTime(2026, 10, 30));
      });
      await f.tap('Lo que te pagan');
      await enterTextIn(f.tester, find.byType(TextField), '0');
      await f.step(
        '«Lo que te pagan» explica para qué sirve. Se escribe 0, que no es '
        'un monto válido.',
      );
      await f.tap('Guardar');
      await f.step(
        'Con 0 y «Guardar» el cuadro no se cierra: bajo el monto dice «Escribe '
        'un monto mayor que cero.»',
      );
      await f.check('Un 0 no se guarda y el cuadro dice por qué', () {
        expect(_own(f).profile!.pay, isNull);
        expect(f.shows('Escribe un monto mayor que cero.'), isTrue);
        expect(find.byType(AlertDialog), findsOneWidget);
      });
      await enterTextIn(f.tester, find.byType(TextField), '4800000');
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no cambia nada', () {
        expect(_own(f).profile!.pay, isNull);
      });
      await f.tap('Lo que te pagan');
      await enterTextIn(f.tester, find.byType(TextField), '4800000');
      await f.tap('Guardar');
      await f.step('Con 4.800.000 y «Guardar», la fila lo muestra.');
      await f.check('Quedó guardado el pago de 4.800.000', () {
        expect(_own(f).profile!.pay, Decimal.parse('4800000'));
        expect(_own(f).ledger!.pay, 4800000);
      });
      await f.tap('Lo que te pagan');
      await f.step(
        'Al abrirlo con un monto aparece también «Quitar», para dejarlo sin '
        'definir.',
      );
      await f.tap('Quitar');
      await f.check('Con «Quitar» el pago vuelve a no estar definido', () {
        expect(_own(f).profile!.pay, isNull);
      });
      await f.back();
      await f.step(
        'Inicio cuenta ahora hasta el 30 de octubre: «Tu próximo pago llega '
        'en 27 días».',
      );
      await f.check('Inicio dice hasta el 30 de octubre', () {
        expect(f.shows('hasta el 30 de octubre'), isTrue);
      });
    },
  ),
  AppFlow(
    '09-04-guardar-un-colchon',
    'Apartar un colchón que no quiero tocar',
    area: 'Ajustes',
    goal:
        'Quiero tener siempre 200 mil guardados y que la app no me los cuente '
        'como plata para gastar.',
    data: seeded,
    (FlowRun f) async {
      final int free = _own(f).ledger!.freeUntilPayday;
      await f.step(
        'Antes del colchón, Inicio dice que puedes gastar ${pesos(free)}.',
      );
      await f.tapTip('Ajustes');
      await f.tap('Colchón');
      await enterTextIn(f.tester, find.byType(TextField), '0');
      await f.tap('Guardar');
      await f.step(
        '«Colchón» explica que no cuenta en lo que puedes gastar. Con 0 y '
        '«Guardar» el cuadro sigue abierto y dice «Escribe un monto mayor que '
        'cero.»; para no tener colchón está «Cancelar».',
      );
      await f.check(
        'Un colchón de 0 no se guarda y el cuadro dice por qué',
        () {
          expect(_own(f).profile!.cushion, isNull);
          expect(f.shows('Escribe un monto mayor que cero.'), isTrue);
          expect(find.byType(AlertDialog), findsOneWidget);
        },
      );
      await enterTextIn(f.tester, find.byType(TextField), '200000');
      await f.step('Se corrige a 200.000.');
      await f.tap('Guardar');
      await f.back();
      await f.step(
        'En Inicio «Puedes gastar» bajó 200.000 y aparece la línea «Colchón».',
      );
      await f.check(
        'Puedes gastar pasó de ${pesos(free)} a ${pesos(free - 200000)}',
        () {
          expect(_own(f).ledger!.cushion, 200000);
          expect(_own(f).ledger!.freeUntilPayday, free - 200000);
          expect(f.screenText, contains(pesos(free - 200000)));
        },
      );
      await f.tapTip('Ajustes');
      await f.tap('Colchón');
      await f.tap('Quitar');
      await f.back();
      await f.check('Con «Quitar» vuelve a ${pesos(free)}', () {
        expect(_own(f).profile!.cushion, isNull);
        expect(_own(f).ledger!.freeUntilPayday, free);
      });
    },
  ),
  AppFlow(
    '09-05-aviso-del-dia-de-pago',
    'Recibir un aviso el día de pago',
    area: 'Ajustes',
    goal:
        'Quiero que el teléfono me avise cada día de pago para revisar el '
        'cierre, sin mostrar montos en la pantalla bloqueada.',
    data: fullAccount,
    manual: <String>[
      'El permiso de notificaciones del sistema la primera vez, y el aviso '
          'real a las 9 de la mañana del día de pago.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      phone.notifications = false;
      await f.tapTip('Ajustes');
      await f.tap('Avisarme el día de pago');
      await f.step(
        'En «Automatización», si el teléfono no deja notificar, el interruptor '
        'sigue apagado y abajo explica que hay que permitirlas en los ajustes '
        'del teléfono, con el botón «Abrir ajustes».',
      );
      await f.check('Sin permiso no queda encendido y dice qué hacer', () {
        expect(_own(f).remindsClose, isFalse);
        expect(phone.scheduledClose(), isEmpty);
        expect(
          f.shows(
            'Para los avisos, permite las notificaciones de Quincena en los '
            'ajustes del teléfono.',
          ),
          isTrue,
        );
      });
      await f.tap('Abrir ajustes');
      await f.check('«Abrir ajustes» abre la página de Quincena en los ajustes '
          'del iPhone', () {
        expect(phone.opened.last, 'app-settings:');
      });
      phone.notifications = true;
      phone.reminders.clear();
      await f.tap('Avisarme el día de pago');
      await f.step(
        'Con permiso, «Avisarme el día de pago» queda encendido: un aviso sin '
        'montos para ver el cierre de la quincena.',
      );
      await f.check(
        'Quedan avisos a las 9 a. m. del 15 y el 30 de octubre, y se guarda',
        () async {
          expect(
            await _read(f, () => _store(f).setting('reminders.close')),
            isNotEmpty,
          );
          final List<DateTime> close = phone.scheduledClose();
          expect(close.take(2), <DateTime>[
            DateTime(2026, 10, 15, 9),
            DateTime(2026, 10, 30, 9),
          ]);
          expect(close, hasLength(6));
        },
      );
      await f.check('El aviso no lleva montos', () {
        expect(phone.scheduledTexts().join(' '), isNot(contains(r'$')));
      });
      await f.tap('Avisarme el día de pago');
      await f.step(
        'Al tocarlo otra vez queda apagado: ya no habrá aviso el día de pago.',
      );
      await f.check('Al apagarlo ya no queda ningún aviso de cierre', () {
        expect(_own(f).remindsClose, isFalse);
        expect(phone.scheduledClose(), isEmpty);
      });
    },
  ),
  AppFlow(
    '09-06-ocultar-montos-del-widget',
    'Ocultar los montos del widget de inicio',
    area: 'Ajustes',
    goal:
        'Tengo el widget en la pantalla de inicio y no quiero que cualquiera '
        'vea cuánta plata tengo.',
    data: fullAccount,
    manual: <String>[
      'Agregar el widget desde la galería de la pantalla de inicio y ver que '
          'muestra la cifra, y luego «••••••» con los montos ocultos.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final String free = pesos(_own(f).ledger!.freeUntilPayday);
      // The widget gets the figure again whenever it changes.
      await f.tapTip('Ajustes');
      await _near(f, find.text('Widget de inicio'));
      await f.step(
        'En «Apariencia», «Widget de inicio» explica cómo agregarlo desde la '
        'pantalla de inicio. «Ocultar montos en el widget» está apagado.',
      );
      await f.tap('Ocultar montos en el widget');
      await f.step('Encendido: el widget dice hasta cuándo, sin la cifra.');
      await f.check('El widget recibe «••••••» en vez de la cifra', () {
        expect(_own(f).widgetHidesAmounts, isTrue);
        expect(phone.widget?['amount'], '••••••');
      });
      await f.tap('Ocultar montos en el widget');
      await f.step(
        'Apagado otra vez, el widget vuelve a mostrar lo que puedes gastar.',
      );
      await f.check('Apagado, el widget vuelve a mostrar $free', () {
        expect(_own(f).widgetHidesAmounts, isFalse);
        expect(phone.widget?['amount'], free);
      });
    },
  ),
  AppFlow(
    '09-07-captura-automatica',
    'Revisar cómo llegan los pagos solos',
    area: 'Ajustes',
    goal:
        'Quiero saber cómo hace la app para anotar mis pagos sola, leerle un '
        'pantallazo y decidir qué registra sin preguntarme.',
    data: _withRules,
    manual: <String>[
      'En un iPhone con iOS 27, los atajos listos con «Añadir» abren iCloud y '
          'se instalan en Atajos.',
      '«Abrir Atajos» abre la app Atajos del iPhone.',
      'Elegir capturas o un PDF en el selector de fotos o de archivos del '
          'sistema, y que Vision lea el texto de verdad.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int pending = _own(f).pendingInbox.length;
      await f.tapTip('Ajustes');
      await f.tap('Captura automática');
      await f.page(
        '«Captura automática» explica cómo se arma en el iPhone con Atajos, '
        'cómo leer capturas y comprobantes, y qué decide la app sola.',
      );
      // Before iOS 27 the person makes the automation in Atajos; from 27
      // each ready shortcut is added from its link. Which one shows depends
      // on the system the flow runs on.
      if (f.shows('Abrir Atajos')) {
        await f.tap('Abrir Atajos');
        await f.check('«Abrir Atajos» abre la app Atajos', () {
          expect(phone.opened, contains('shortcuts://'));
        });
      } else {
        await f.tapFound(find.text('Añadir').first);
        await f.check('«Añadir» abre el atajo listo en iCloud', () {
          expect(
            phone.opened.last,
            startsWith('https://www.icloud.com/shortcuts/'),
          );
        });
      }
      await f.tap('Leer un pantallazo o PDF');
      await f.step(
        '«Leer un pantallazo o PDF» pregunta qué elegir: «Capturas o fotos» '
        'o «Un PDF».',
      );
      await f.back();
      await f.check('Cerrar esa hoja no abre ningún selector', () {
        expect(phone.asked, isEmpty);
      });
      await f.tap('Leer un pantallazo o PDF');
      await f.tap('Un PDF');
      await f.check(
        '«Un PDF» abre el selector solo con PDF; si se cierra sin elegir, no '
        'pasa nada',
        () {
          expect(phone.asked, <String>['pdf']);
          expect(_own(f).pendingInbox, hasLength(pending));
        },
      );
      phone.toPick.add(Uint8List.fromList(<int>[1, 2, 3]));
      phone.screenshotText =
          r'Bancolombia le informa Compra por $45.900 en RAPPI. '
          '03/10/2026 09:30';
      await f.tap('Leer un pantallazo o PDF');
      await f.tap('Capturas o fotos');
      await f.step(
        'Con una captura de una compra en Rappi, abajo dice «Leí un pago. '
        'Quedó en Por revisar.»',
      );
      await f.check('Queda un pago más por revisar, de 45.900 en Rappi', () {
        expect(phone.asked.last, 'image');
        expect(f.shows('Leí un pago. Quedó en Por revisar.'), isTrue);
        expect(_own(f).pendingInbox, hasLength(pending + 1));
        final InboxItem read = _own(f).pendingInbox.firstWhere(
          (InboxItem i) => i.event.source == CaptureSource.screenshot,
        );
        expect(read.parsed.amount, Decimal.parse('45900'));
        expect(read.suggestion.category, 'restaurants');
        expect(read.suggestion.why, contains('learned'));
      });
      phone.toPick.add(Uint8List.fromList(<int>[4, 5]));
      phone.screenshotText = 'Foto del perro';
      await f.tap('Leer un pantallazo o PDF');
      await f.tap('Capturas o fotos');
      await f.step(
        'Con una foto sin pago, abajo dice «No encontré un monto con su '
        'moneda» y no se agrega nada.',
      );
      await f.check('Una foto sin pago no agrega nada', () {
        expect(_own(f).pendingInbox, hasLength(pending + 1));
        expect(f.screenText, contains('No encontré un monto con su moneda'));
      });
      final bool auto = _own(f).captureSettings.autoRecord;
      await f.tap('Registrar solo lo que esté claro');
      await f.check('«Registrar solo lo que esté claro» queda '
          '${auto ? 'apagado' : 'encendido'} y guardado', () async {
        expect(_own(f).captureSettings.autoRecord, !auto);
        final CaptureSettings saved = await _read(
          f,
          () => _store(f).captureSettings(),
        );
        expect(saved.autoRecord, !auto);
      });
      final bool located = _own(f).captureSettings.useLocation;
      await f.tap('Usar la ubicación del pago');
      await f.check('«Usar la ubicación del pago» queda '
          '${located ? 'apagado' : 'encendido'}', () {
        expect(_own(f).captureSettings.useLocation, !located);
      });
      await f.reveal(find.text('Volver a leer'));
      await f.step(
        '«Registrar solo lo que esté claro» quedó encendido y la ubicación '
        'apagada. Abajo: cuántos comercios reconoce y las apps que no se leen.',
      );
      final int merchants = _own(f).captureSettings.merchantCategories.length;
      await f.check('Dice que reconoce $merchants comercios', () {
        expect(f.shows('Ya reconoce $merchants comercios.'), isTrue);
      });
      await f.tap('Volver a leer');
      await f.check('Rappi vuelve a leerse', () async {
        final CaptureSettings saved = await _read(
          f,
          () => _store(f).captureSettings(),
        );
        expect(saved.mutedApps, isEmpty);
        expect(saved.appNames, isNot(contains('com.grability.rappi')));
        expect(f.shows('Apps que no se leen'.toUpperCase()), isFalse);
      });
      await f.back();
      await f.tap('Captura automática');
      await f.reveal(find.text('Usar la ubicación del pago'));
      await f.check('Los dos interruptores siguen así al volver a entrar', () {
        expect(_switchOf(f, 'Registrar solo lo que esté claro'), !auto);
        expect(_switchOf(f, 'Usar la ubicación del pago'), !located);
      });
    },
  ),
  AppFlow(
    '09-08-reglas-aprendidas',
    'Corregir, apagar y borrar lo que la app aprendió',
    area: 'Ajustes',
    goal:
        'La app aprendió que Rappi es restaurante, pero yo pido mercado por '
        'ahí: quiero corregirlo y quitar lo que ya no me sirve.',
    data: _withRules,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int rules = _own(f).captureSettings.rules.length;
      await f.tapTip('Ajustes');
      await f.tap('Captura automática');
      await f.reveal(find.text('Reglas aprendidas'));
      await f.check('La fila dice $rules reglas', () {
        expect(f.shows('$rules reglas'), isTrue);
      });
      await f.tap('Reglas aprendidas');
      await f.page(
        '«Reglas aprendidas» las agrupa en comercios, tarjetas y bancos, cada '
        'una con su destino, un interruptor y la papelera.',
      );
      await f.tap('Rappi');
      await f.step(
        'Tocar «Rappi» pregunta «¿A qué categoría va?», con un visto en '
        'Restaurantes.',
      );
      await f.tap('Mercado');
      await f.check('Rappi ahora va a Mercado', () {
        expect(
          _own(f).captureSettings.use(RuleKind.merchant, 'rappi'),
          'groceries',
        );
      });
      final Finder exito = find.bySemanticsLabel(
        'Usar esta regla: Exito Laureles',
      );
      await f.tapFound(
        find.descendant(
          of: find.ancestor(of: exito, matching: find.byType(ListTile)),
          matching: find.byType(Switch),
        ),
      );
      await f.step(
        'Con el interruptor de Exito Laureles apagado, su destino se ve '
        'tachado: la regla se guarda pero no se usa.',
      );
      await f.check('La regla de Exito Laureles se guarda pero no se usa', () {
        final CaptureSettings s = _own(f).captureSettings;
        expect(s.merchantCategories['exito laureles'], 'groceries');
        expect(s.use(RuleKind.merchant, 'exito laureles'), isNull);
      });
      await f.tapFound(
        find.descendant(
          of: find.ancestor(
            of: find.text('Tarjeta *1234'),
            matching: find.byType(ListTile),
          ),
          matching: find.byTooltip('Borrar regla'),
        ),
      );
      await f.step(
        '«Borrar regla» en «Tarjeta *1234» la quita enseguida, sin preguntar '
        'ni ofrecer deshacer.',
      );
      await f.check('La tarjeta *1234 ya no tiene regla', () async {
        final CaptureSettings saved = await _read(
          f,
          () => _store(f).captureSettings(),
        );
        expect(saved.cardAccounts.containsKey('1234'), isFalse);
        expect(saved.rules, hasLength(rules - 1));
      });
      await f.tap('Nequi');
      await f.step(
        'Una regla de banco o billetera pregunta «¿A qué cuenta va?», con '
        'tus cuentas y un visto en Nequi.',
      );
      await f.back();
      await f.check('Cerrar sin elegir deja lo de Nequi en Nequi', () {
        final String? to = _own(
          f,
        ).captureSettings.use(RuleKind.institution, 'Nequi');
        expect(
          _own(f).accounts.firstWhere((Account a) => a.id == to).name,
          'Nequi',
        );
      });
      await f.tap('Rappi');
      await f.back();
      await f.check('Cerrar la de Rappi sin elegir la deja en Mercado', () {
        expect(
          _own(f).captureSettings.use(RuleKind.merchant, 'rappi'),
          'groceries',
        );
      });
      await f.tapFound(
        find.descendant(
          of: find.ancestor(of: exito, matching: find.byType(ListTile)),
          matching: find.byType(Switch),
        ),
      );
      await f.check(
        'Encendida otra vez, la regla de Exito Laureles se usa',
        () {
          expect(
            _own(f).captureSettings.use(RuleKind.merchant, 'exito laureles'),
            'groceries',
          );
        },
      );
      await f.back();
      await f.check('De vuelta, la fila dice ${rules - 1} reglas', () {
        expect(f.shows('${rules - 1} reglas'), isTrue);
      });
      phone.toPick.add(Uint8List.fromList(<int>[1]));
      phone.screenshotText =
          r'Bancolombia le informa Compra por $52.300 en RAPPI. '
          '03/10/2026 09:45';
      await f.tap('Leer un pantallazo o PDF');
      await f.tap('Capturas o fotos');
      await f.check('Un pago nuevo de Rappi llega sugerido en Mercado', () {
        final InboxItem read = _own(f).pendingInbox.firstWhere(
          (InboxItem i) => i.event.source == CaptureSource.screenshot,
        );
        expect(read.suggestion.category, 'groceries');
        expect(read.suggestion.why, contains('learned'));
      });
      await _waitMessages(f);
      await f.tap('Reglas aprendidas');
      while (find.byTooltip('Borrar regla').evaluate().isNotEmpty) {
        await f.tapFound(find.byTooltip('Borrar regla').first);
      }
      await f.step(
        'Con todas borradas, a alguien con muchos movimientos le dice «No '
        'tienes reglas ahora. Cuando registres algo en Por revisar, se crea '
        'la de su comercio, su tarjeta o su banco. Tus movimientos no '
        'cambian.»',
      );
      await f.check('No queda ninguna regla guardada', () async {
        final CaptureSettings saved = await _read(
          f,
          () => _store(f).captureSettings(),
        );
        expect(saved.rules, isEmpty);
      });
      await f.check(
        'Con ${_own(f).snapshot!.entries.length} movimientos, no habla de '
        'los primeros sino de cómo vuelven las reglas',
        () {
          expect(_own(f).snapshot!.entries, isNotEmpty);
          expect(f.screenText, contains('No tienes reglas ahora.'));
          expect(f.screenText, isNot(contains('primeros movimientos')));
          expect(f.screenText, contains('Tus movimientos no cambian.'));
        },
      );
      await f.back();
      await f.check('La fila dice «Ninguna todavía»', () {
        expect(f.shows('Ninguna todavía'), isTrue);
      });
      phone.toPick.add(Uint8List.fromList(<int>[2]));
      phone.screenshotText =
          r'Bancolombia le informa Compra por $18.700 en RAPPI. '
          '03/10/2026 10:05';
      await f.tap('Leer un pantallazo o PDF');
      await f.tap('Capturas o fotos');
      await f.check('Sin reglas, otro pago de Rappi ya no llega por lo '
          'aprendido', () {
        final InboxItem read = _own(f).pendingInbox.firstWhere(
          (InboxItem i) =>
              i.event.source == CaptureSource.screenshot &&
              i.parsed.amount == Decimal.parse('18700'),
        );
        expect(read.suggestion.why, isNot(contains('learned')));
      });
    },
  ),
  AppFlow(
    '09-09-tema-e-idioma',
    'Cambiar el tema y el idioma',
    area: 'Ajustes',
    goal:
        'De noche prefiero la app oscura, y a veces se la muestro a alguien '
        'que no habla español.',
    data: seeded,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      await f.tapTip('Ajustes');
      await _near(f, find.text('APARIENCIA'));
      await f.step(
        '«Apariencia» tiene una fila «Tema» (Sistema, Claro, Oscuro) y debajo '
        'una fila «Idioma» (Sistema, Español, English), cada una con su '
        'título.',
      );
      await f.check(
        '«Tema» va sobre sus botones e «Idioma» sobre los suyos',
        () {
          double top(Finder finder) => f.tester.getTopLeft(finder).dy;
          expect(top(find.text('Tema')), lessThan(top(find.text('Claro'))));
          expect(top(find.text('Claro')), lessThan(top(find.text('Idioma'))));
          expect(top(find.text('Idioma')), lessThan(top(find.text('English'))));
        },
      );
      await f.tap('Oscuro');
      await f.step(
        'En «Tema», «Oscuro» cambia toda la app a colores oscuros al instante.',
      );
      await f.check('La app quedó en modo oscuro', () {
        expect(_app(f).themeMode, ThemeMode.dark);
        expect(_brightness(f), Brightness.dark);
      });
      await f.tap('Claro');
      await f.check('Con «Claro» queda clara aunque el teléfono cambie', () {
        expect(_app(f).themeMode, ThemeMode.light);
      });
      await f.tap('English');
      await f.step(
        'Con «Claro» vuelve a los colores claros, y en «Idioma» «English» pasa '
        'todo a inglés: «Settings», «Theme», «Language», «Your data».',
      );
      await f.check('La app quedó en inglés', () {
        expect(_app(f).locale, const Locale('en'));
        expect(f.shows('Settings'), isTrue);
        expect(f.shows('Theme'), isTrue);
        expect(f.shows('Language'), isTrue);
      });
      await f.tap('Privacy policy');
      await f.check('En inglés, la política abre su página en inglés', () {
        expect(
          phone.opened.last,
          'https://diegolopezrm.github.io/quincena/privacy/',
        );
      });
      await f.tap('Español');
      await f.check(
        '«Español» vuelve al español aunque el teléfono cambie',
        () {
          expect(_app(f).locale, const Locale('es'));
          expect(f.shows('Ajustes'), isTrue);
        },
      );
      // The two rows start with «Sistema»: «Tema»'s first, «Idioma»'s
      // second.
      await f.tapFound(find.text('Sistema').first);
      await f.tapFound(find.text('Sistema').last);
      await f.check(
        'Los dos «Sistema» dejan el tema y el idioma del teléfono, y se guarda',
        () async {
          expect(_app(f).themeMode, ThemeMode.system);
          expect(_app(f).locale, isNull);
          expect(
            await _read(f, () => _store(f).setting('app.theme')),
            'system',
          );
          expect(await _read(f, () => _store(f).setting('app.language')), '');
        },
      );
      await f.tap('Oscuro');
      await f.tap('English');
      await _reopen(f);
      await f.step(
        'Con «Oscuro» e «English» elegidos, al cerrar y volver a abrir la app '
        'Inicio sigue oscuro y en inglés: «You can spend».',
      );
      await f.check('Al volver a abrir, sigue oscura y en inglés', () {
        expect(_app(f).themeMode, ThemeMode.dark);
        expect(_app(f).locale, const Locale('en'));
      });
    },
  ),
  AppFlow(
    '09-10-privacidad-soporte-y-licencias',
    'Leer la privacidad, pedir ayuda y ver las licencias',
    area: 'Ajustes',
    goal:
        'Antes de poner mis cuentas quiero saber qué pasa con mis datos y a '
        'quién escribir si algo falla.',
    data: seeded,
    manual: <String>[
      'Que las páginas de privacidad y soporte abran en el navegador y '
          'carguen.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      await f.tapTip('Ajustes');
      await _near(f, find.text('AYUDA Y PRIVACIDAD'));
      await f.step(
        '«Ayuda y privacidad» dice que todo se guarda solo en el teléfono, sin '
        'publicidad ni venta de datos, y tiene tres filas: «Soporte», '
        '«Política de privacidad» y «Licencias y créditos».',
      );
      await f.tap('Política de privacidad');
      await f.check('«Política de privacidad» abre la página en español', () {
        expect(phone.opened, <String>[
          'https://diegolopezrm.github.io/quincena/privacidad/',
        ]);
      });
      await f.tap('Soporte');
      await f.check('«Soporte» abre la página de soporte', () {
        expect(
          phone.opened.last,
          'https://diegolopezrm.github.io/quincena/soporte/',
        );
      });
      // What main() adds to the packages' own licenses.
      registerLicenses();
      await f.tap('Licencias y créditos');
      await f.waitFor(find.text('OpenStreetMap'));
      await f.step(
        '«Licencias y créditos» muestra Quincena con su versión y los créditos '
        'de OpenStreetMap, y debajo cada fuente, ícono y paquete con su '
        'licencia.',
      );
      await f.check('La página nombra la app, su versión y los créditos', () {
        expect(f.shows('Quincena'), isTrue);
        expect(f.shows(appVersion), isTrue);
        expect(f.screenText, contains('© 2026 DL SOFT TECHNOLOGIES SAS'));
      });
      await f.tap('OpenStreetMap');
      await f.waitFor(find.textContaining('Open Database License'));
      await f.step(
        'Tocar «OpenStreetMap» abre su licencia: de dónde salen los comercios '
        'cercanos y la Open Database License.',
      );
      await f.check('La licencia de OpenStreetMap se lee completa', () {
        expect(f.screenText, contains('Open Database License (ODbL) 1.0'));
      });
      await f.back();
      await f.back();
    },
  ),
  AppFlow(
    '09-11-ver-el-ejemplo-y-volver',
    'Mirar el ejemplo y volver a mis cuentas',
    area: 'Ajustes',
    goal:
        'Quiero ver otra vez la cuenta de ejemplo sin perder nada de lo mío, '
        'y volver cuando termine.',
    data: fullAccount,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int free = _own(f).ledger!.freeUntilPayday;
      final int entries = _own(f).snapshot!.entries.length;
      await f.tapTip('Ajustes');
      await _near(f, find.text('TUS DATOS'));
      await f.step(
        'En «Tus datos», «Ver los datos de ejemplo» va al final, después de '
        'exportar y de «Restaurar un respaldo».',
      );
      await f.tap('Ver los datos de ejemplo');
      await f.step(
        '«Ver los datos de ejemplo» abre toda la app con la cuenta de '
        'Valentina, y arriba la franja «Cuenta de ejemplo de Valentina» con '
        '«Usar mis cuentas».',
      );
      await f.check('La app recuerda que está en el ejemplo', () async {
        expect(await _read(f, () => _store(f).setting('app.mode')), 'demo');
        expect(_own(f).example, isTrue);
        expect(f.shows('Usar mis cuentas'), isTrue);
      });
      await f.check('Al widget no le llega nada del ejemplo', () {
        expect(phone.widgetCalls, isEmpty);
      });
      await f.check('Tus movimientos siguen guardados', () async {
        expect(await _read(f, () => _store(f).entries()), hasLength(entries));
      });
      await f.tapTip('Ajustes');
      await f.step(
        'Los Ajustes del ejemplo empiezan con «Cuenta de ejemplo»: «Usar mis '
        'cuentas» y «Volver a la primera pantalla».',
      );
      await f.tapFound(find.text('Usar mis cuentas'));
      await f.check('Desde Ajustes también vuelve a tus cuentas', () async {
        expect(find.byType(OwnShell), findsOneWidget);
        expect(_own(f).example, isFalse);
        expect(_own(f).ledger!.freeUntilPayday, free);
        expect(await _read(f, () => _store(f).setting('app.mode')), 'own');
      });
      await f.tapTip('Ajustes');
      await f.tap('Ver los datos de ejemplo');
      await f.tap('Usar mis cuentas');
      await f.step(
        'Otra vez en el ejemplo, «Usar mis cuentas» de la franja de arriba '
        'regresa a tu Inicio, con la misma cifra que antes.',
      );
      await f.check('Puedes gastar sigue en ${pesos(free)}', () {
        expect(_own(f).ledger!.freeUntilPayday, free);
        expect(f.screenText, contains(pesos(free)));
      });
      await f.check('La app abre de nuevo en tus cuentas', () async {
        expect(await _read(f, () => _store(f).setting('app.mode')), 'own');
      });
      await f.check('El widget muestra tu cifra, ${pesos(free)}', () {
        expect(phone.widget?['amount'], pesos(free));
      });
    },
  ),
  AppFlow(
    '09-12-borrar-todo',
    'Borrar todos mis datos',
    area: 'Ajustes',
    goal: 'Voy a vender el teléfono y quiero que no quede nada mío en la app.',
    data: fullAccount,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      // A device that synced, made a sealed backup and linked Binance keeps
      // three keys in the keychain.
      await _read(f, () => SecureKeyStore().write(VaultKey.generate().bytes));
      await _read(
        f,
        () => SecureBackupKeyStore().write(VaultKey.generate().bytes),
      );
      await _read(
        f,
        () => SecureKeyVault().write('llave-de-prueba', 'secreto-de-prueba'),
      );
      final int accounts = _own(f).accounts.length;
      await f.tapTip('Ajustes');
      await f.tap('Avisarme el día de pago');
      await f.tap('Oscuro');
      await f.check(
        'Antes de borrar, el teléfono tiene avisos del día de pago y la app '
        'está oscura',
        () {
          expect(phone.scheduledClose(), isNotEmpty);
          expect(_app(f).themeMode, ThemeMode.dark);
        },
      );
      await f.tap('Borrar todo');
      await f.step(
        'Con el aviso del día de pago encendido y «Oscuro», «Borrar todo» '
        'pregunta antes: «¿Borrar todos tus datos?». Dice que no se deshace, '
        'que para recuperarlos hace falta un respaldo guardado fuera del '
        'teléfono y su código, y que el teléfono olvida el código al borrar.',
      );
      await f.check('Recuerda qué hace falta para recuperar los datos', () {
        expect(
          f.screenText,
          contains('un respaldo guardado fuera de este teléfono'),
        );
        expect(f.shows('Ver mi código de respaldo'), isTrue);
        expect(f.shows('Guardar un respaldo primero'), isTrue);
      });
      final String backupCode = (await _read(
        f,
        () => Backups(_store(f)).code(),
      ))!;
      await f.tap('Ver mi código de respaldo');
      await f.check('«Ver mi código de respaldo» muestra el código que el '
          'teléfono va a olvidar', () {
        expect(find.text(backupCode.split('-').first), findsWidgets);
      });
      await f.tap('Listo');
      await f.tap('Guardar un respaldo primero');
      await f.tap('Exportar');
      await f.step(
        '«Guardar un respaldo primero» abre la hoja de exportar; al guardar el '
        'respaldo cifrado vuelve la misma pregunta.',
      );
      await f.check(
        'Se guardó un respaldo de todo y la pregunta sigue',
        () async {
          final Uint8List? kept = phone.saved['quincena-2026-10-03.qbackup'];
          expect(kept, isNotNull);
          expect(
            await _openBackup(f, kept!, backupCode),
            hasLength(_own(f).snapshot!.entries.length),
          );
          expect(f.shows('¿Borrar todos tus datos?'), isTrue);
        },
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no se borra nada', () async {
        expect(await _read(f, () => _store(f).accounts()), hasLength(accounts));
        expect(f.shows('Ajustes'), isTrue);
        expect(phone.scheduledClose(), isNotEmpty);
      });
      await f.tap('English');
      await f.check('Antes de borrar, la app está en inglés', () async {
        expect(_app(f).locale, const Locale('en'));
        // «Borrar todo» sits apart at the end of the list.
        await f.reveal(find.text('Delete everything'));
        expect(f.shows('Delete everything'), isTrue);
      });
      await f.tap('Delete everything');
      await f.tap('Delete everything');
      await f.step(
        'En inglés, «Delete everything» y confirmar: la app vuelve a «¿Cómo '
        'quieres empezar?», como recién instalada, ya en el idioma y los '
        'colores del teléfono, sin esperar a volver a abrirla.',
      );
      await f.check(
        'No queda perfil, cuentas, movimientos ni pagos fijos',
        () async {
          final QuincenaStore store = _store(f);
          expect(await _read(f, store.profile), isNull);
          expect(await _read(f, () => store.accounts(archived: true)), isEmpty);
          expect(await _read(f, store.entries), isEmpty);
          expect(await _read(f, store.recurring), isEmpty);
          expect(await _read(f, () => store.setting('app.mode')), isNull);
        },
      );
      await f.check(
        'Se borraron las llaves de sincronizar, de respaldo y de Binance',
        () async {
          expect(await _read(f, () => SecureKeyStore().read()), isNull);
          expect(await _read(f, () => SecureBackupKeyStore().read()), isNull);
          expect(await _read(f, () => SecureKeyVault().read()), isNull);
        },
      );
      await f.check(
        'El teléfono ya no tiene avisos de Quincena: ninguno nombra tus pagos',
        () {
          expect(phone.reminders, isEmpty);
        },
      );
      await f.check('El widget ya no muestra ninguna cifra', () {
        expect(phone.widget, isNull);
      });
      await f.check(
        'El tema y el idioma vuelven a los del teléfono, como en lo guardado',
        () async {
          expect(_app(f).themeMode, ThemeMode.system);
          expect(_app(f).locale, isNull);
          expect(_brightness(f), Brightness.light);
          expect(f.shows('¿Cómo quieres empezar?'), isTrue);
          expect(await _read(f, () => _store(f).setting('app.theme')), isNull);
          expect(
            await _read(f, () => _store(f).setting('app.language')),
            isNull,
          );
        },
      );
      await f.tap('Con mis cuentas');
      await f.step(
        '«Con mis cuentas» empieza la configuración desde cero: el nombre '
        'vacío y la moneda en pesos.',
      );
      await f.check('La configuración empieza vacía, en el paso 1', () {
        expect(f.shows('Paso 1 de 4'), isTrue);
        expect(
          f.tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty,
        );
      });
      await f.tapTip('Atrás');
      await _reopen(f);
      await f.check('Al volver a abrir, sigue en la primera pantalla', () {
        expect(f.shows('¿Cómo quieres empezar?'), isTrue);
        expect(_app(f).themeMode, ThemeMode.system);
      });
    },
  ),
  AppFlow(
    '09-13-ajustes-de-la-conversacion-del-ejemplo',
    'Buscar los ajustes de la conversación del ejemplo',
    area: 'Ajustes',
    goal:
        'En la cuenta de ejemplo quiero saber quién contesta mis preguntas y '
        'dónde se cambian el idioma y la apariencia.',
    demo: true,
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      await f.tapContaining('¿Qué suscripciones tengo?');
      await f.step(
        'En la conversación del ejemplo, arriba solo están «EJEMPLO» y '
        '«Nueva»: no tiene «Ajustes» propios. Responde el guion del ejemplo, '
        'sin red: no hay a quién escoger.',
      );
      await f.check('Responde el guion del ejemplo, sin red', () {
        expect(_session(f).mode, AgentMode.demo);
        expect(_session(f).choosable, isFalse);
      });
      await f.check(
        'En el teléfono la conversación no tiene engranaje, ni key propia, '
        'ni Gemini a escoger, ni modo desarrollador',
        () {
          expect(find.byTooltip('Ajustes'), findsNothing);
          expect(f.shows('Tu key'), isFalse);
          expect(f.shows('Gemini'), isFalse);
          expect(f.shows('Modo desarrollador'), isFalse);
        },
      );
      await f.back();
      await f.tapTip('Ajustes');
      await f.reveal(find.text('English'));
      await f.step(
        'El idioma y la apariencia están en los Ajustes de la app, los '
        'mismos para todo el ejemplo y para la conversación.',
      );
      await f.check(
        'Los Ajustes de la app traen el idioma y la apariencia',
        () {
          expect(f.shows('English'), isTrue);
          expect(f.shows('Oscuro'), isTrue);
        },
      );
    },
  ),
  AppFlow(
    '09-14-del-ejemplo-a-mis-cuentas',
    'Ver el ejemplo en inglés y pasar a mis cuentas',
    area: 'Ajustes',
    goal:
        'Le mostré el ejemplo a un amigo en inglés y oscuro; ahora quiero '
        'empezar con mis cuentas.',
    demo: true,
    (FlowRun f) async {
      await f.tapTip('Ajustes');
      await f.tap('Oscuro');
      await f.tap('English');
      await f.page(
        'En los Ajustes del ejemplo, «Oscuro» lo oscurece y «English» lo pasa '
        'a inglés: ahora dicen «Settings», «Example account» y «Use my '
        'accounts».',
      );
      await f.check('El ejemplo quedó en inglés y oscuro, Ajustes también', () {
        expect(_app(f).locale, const Locale('en'));
        expect(_app(f).themeMode, ThemeMode.dark);
        expect(f.shows('Settings'), isTrue);
        expect(f.shows("Valentina's example account"), isTrue);
        expect(_brightness(f), Brightness.dark);
      });
      await f.tap('Español');
      await f.tap('Claro');
      await f.step(
        '«Español» y «Claro» lo pasan otra vez a español y a colores claros; '
        'arriba sigue «Usar mis cuentas».',
      );
      await f.check('Quedó en español y claro, escogidos a mano', () {
        expect(_app(f).locale, const Locale('es'));
        expect(_app(f).themeMode, ThemeMode.light);
      });
      // In Ajustes the theme comes first, then the language.
      await f.tapFound(find.text('Sistema').first);
      await f.tapFound(find.text('Sistema').last);
      await f.check('Los dos «Sistema» de Ajustes siguen al teléfono', () {
        expect(_app(f).locale, isNull);
        expect(_app(f).themeMode, ThemeMode.system);
      });
      await f.tapFound(find.text('Usar mis cuentas'));
      await f.step(
        'Siguiendo al teléfono, en español y claro, «Usar mis cuentas» cierra '
        'Ajustes y abre el paso 1 de la configuración.',
      );
      await f.check('Empieza la configuración', () {
        expect(f.shows('Paso 1 de 4'), isTrue);
        expect(f.shows('Cuenta de ejemplo de Valentina'), isFalse);
      });
    },
  ),
  AppFlow(
    '09-15-la-moneda-con-colchon-y-pago',
    'Ver los totales en dólares sin cambiar mi colchón',
    area: 'Ajustes',
    goal:
        'Tengo un colchón de 200 mil y me llegan 2,4 millones por quincena; '
        'quiero ver todo en dólares un rato sin que esas cifras se dañen.',
    data: _withCushionAndPay,
    (FlowRun f) async {
      final int free = _own(f).ledger!.freeUntilPayday;
      // In pesos, said before the totals change currency.
      final String freeCop = pesos(free);
      final String cushionCop = pesos(200000);
      final String payCop = pesos(2400000);
      // The rate in force when the currency changes: what one peso is worth
      // in dollars.
      final Decimal rate = _own(f).rates.rate(Asset.cop, Asset.usd)!;
      int cents(String pesos) =>
          (Decimal.parse(pesos) * rate * Decimal.fromInt(100))
              .round()
              .toBigInt()
              .toInt();
      await f.tapTip('Ajustes');
      await f.step(
        'En «Perfil», «Lo que te pagan» dice $payCop y «Colchón» $cushionCop: '
        'las dos cifras en pesos.',
      );
      await f.tap('Moneda de los totales');
      await f.tap('USD · Dólar estadounidense');
      await f.step(
        'Con «USD · Dólar estadounidense», «Lo que te pagan» y «Colchón» '
        'pasan a dólares con la tasa del día: la misma plata de antes.',
      );
      await f.check(
        'El colchón sigue siendo $cushionCop, ahora en dólares',
        () {
          expect(_own(f).profile!.base, Asset.usd);
          expect(_own(f).ledger!.cushion, cents('200000'));
        },
      );
      await f.check('Lo que te pagan sigue siendo $payCop, en dólares', () {
        expect(_own(f).ledger!.pay, cents('2400000'));
      });
      await f.check(
        'Lo que puedes gastar en dólares es el de antes a la tasa del día',
        () {
          final int expected = cents('$free');
          expect(
            (_own(f).ledger!.freeUntilPayday - expected).abs(),
            lessThanOrEqualTo(5),
          );
        },
      );
      await f.back();
      final String usd = pesos(
        _own(f).ledger!.major(_own(f).ledger!.freeUntilPayday),
      );
      final String cushion = pesos(
        _own(f).ledger!.major(_own(f).ledger!.cushion),
      );
      await f.step(
        'Inicio en dólares: puedes gastar $usd, ya sin el colchón de '
        '$cushion, que es el mismo de antes.',
      );
      await f.check('Inicio dice $usd y el colchón $cushion', () {
        expect(f.screenText, contains(usd));
        expect(f.screenText, contains(cushion));
      });
      await f.tapTip('Ajustes');
      await f.tap('Moneda de los totales');
      await f.tap('COP · Peso colombiano');
      await f.check(
        'De vuelta en pesos: colchón $cushionCop, pago $payCop y puedes '
        'gastar $freeCop, como al comienzo',
        () {
          expect(_own(f).ledger!.cushion, 200000);
          expect(_own(f).ledger!.pay, 2400000);
          expect(_own(f).ledger!.freeUntilPayday, free);
        },
      );
    },
  ),
  AppFlow(
    '09-17-en-android',
    'Dar los permisos en Android y poner el widget',
    area: 'Ajustes',
    goal:
        'Tengo Android: quiero que Quincena lea las notificaciones de mi banco, '
        'sepa dónde pagué aunque esté cerrada y tener el widget a mano.',
    data: fullAccount,
    manual: <String>[
      'Los diálogos de permisos de Android (notificaciones, ubicación al usar '
          'la app y «Permitir todo el tiempo»), que esta prueba responde sola, '
          'y que cada uno aparezca justo después de «Aceptar» en el aviso de '
          'Quincena, nunca antes.',
      'Que «Agregar a la pantalla de inicio» muestre el diálogo del lanzador y '
          'el widget quede puesto.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final TargetPlatform? before = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await f.tapTip('Ajustes');
        phone.pins = false;
        await f.tap('Agregar a la pantalla de inicio');
        await f.step(
          'En Android, «Widget de inicio» suma «Agregar a la pantalla de '
          'inicio». Si el lanzador no deja, abajo dice cómo hacerlo a mano.',
        );
        await f.check('Se le pidió al lanzador y avisa que no dejó', () {
          expect(phone.asks, <String>['pin']);
          expect(
            f.screenText,
            contains('Tu pantalla de inicio no deja agregarlo desde aquí.'),
          );
        });
        phone.pins = true;
        await _waitMessages(f);
        await f.tap('Agregar a la pantalla de inicio');
        await f.check('Si el lanzador deja, no hay nada que avisar', () {
          expect(phone.asks, <String>['pin', 'pin']);
          expect(find.byType(SnackBar), findsNothing);
        });
        await f.tap('Captura automática');
        await f.step(
          'En Android, «Captura automática» lee las notificaciones de los '
          'bancos: arriba está «Permitir acceso a notificaciones».',
        );
        await f.tap('Permitir acceso a notificaciones');
        await f.step(
          'Antes de ir a Android, Quincena dice qué lee (las notificaciones de '
          'bancos, billeteras y SMS; guarda solo las que traen un monto), '
          'cuándo y que se queda en el teléfono, con «Ahora no» y «Aceptar».',
        );
        await f.check('Con el aviso abierto todavía no se abrió nada', () {
          expect(phone.asks, isNot(contains('openNotificationAccess')));
        });
        await f.tap('Ahora no');
        await f.check('«Ahora no» no lleva a los ajustes del teléfono', () {
          expect(phone.asks, isNot(contains('openNotificationAccess')));
          expect(f.shows('Permitir acceso a notificaciones'), isTrue);
        });
        await f.tap('Permitir acceso a notificaciones');
        await f.tap('Aceptar');
        await f.check('Con «Aceptar» lleva a dar el acceso en el teléfono', () {
          expect(phone.asks.last, 'openNotificationAccess');
        });
        // The person gives it there and comes back to the app.
        phone.notificationAccess = true;
        await _awayAndBack(f);
        await f.step(
          'De vuelta con el acceso dado, el botón cambió por «Acceso a '
          'notificaciones activado».',
        );
        await f.check('Ya dice que el acceso está activado', () {
          expect(f.shows('Acceso a notificaciones activado'), isTrue);
          expect(f.shows('Permitir acceso a notificaciones'), isFalse);
        });
        // The location was on: off, and on again from nothing.
        bool locationAsked() =>
            phone.asks.any((String a) => a == 'location' || a == 'always');
        await f.tap('Usar la ubicación del pago');
        phone.location = 'none';
        await f.tap('Usar la ubicación del pago');
        await f.step(
          'Al encender la ubicación, antes de que Android pida nada, Quincena '
          'dice qué usa (la ubicación precisa), para qué, cuándo (solo al '
          'llegar una notificación de pago, también con la app cerrada) y que '
          'solo las coordenadas van a OpenStreetMap. Abajo, «Ahora no» y '
          '«Aceptar».',
        );
        await f.check('Con el aviso abierto Android no ha pedido nada', () {
          expect(locationAsked(), isFalse);
          expect(_switchOf(f, 'Usar la ubicación del pago'), isFalse);
        });
        await f.back();
        await f.check('Volver atrás es un no: no pide nada y sigue '
            'apagada', () async {
          expect(locationAsked(), isFalse);
          expect(_switchOf(f, 'Usar la ubicación del pago'), isFalse);
          final CaptureSettings saved = await _read(
            f,
            () => _store(f).captureSettings(),
          );
          expect(saved.useLocation, isFalse);
        });
        await f.tap('Usar la ubicación del pago');
        await f.tap('Ahora no');
        await f.check('«Ahora no» tampoco pide nada', () {
          expect(locationAsked(), isFalse);
          expect(_switchOf(f, 'Usar la ubicación del pago'), isFalse);
        });
        await f.tap('Usar la ubicación del pago');
        await f.tap('Aceptar');
        await f.step(
          'Con «Aceptar», Android la pide con la app abierta y, dada, Quincena '
          'explica por qué la usa también con la app cerrada y que Android '
          'pedirá elegir «Permitir todo el tiempo».',
        );
        await f.check('Android la pidió justo después de «Aceptar», y todo el '
            'tiempo todavía no', () {
          expect(phone.asks.last, 'location');
          expect(phone.asks.where((String a) => a == 'always'), isEmpty);
        });
        await f.tap('Ahora no');
        await f.reveal(find.text('Permitir todo el tiempo'));
        await f.step(
          'Con «Ahora no» queda encendida solo con la app abierta: lo dice en '
          'naranja y ofrece «Permitir todo el tiempo».',
        );
        await f.check('Encendida con la app abierta, sin pedir más', () async {
          expect(phone.asks.where((String a) => a == 'always'), isEmpty);
          final CaptureSettings saved = await _read(
            f,
            () => _store(f).captureSettings(),
          );
          expect(saved.useLocation, isTrue);
        });
        await f.tap('Permitir todo el tiempo');
        await f.step(
          '«Permitir todo el tiempo» vuelve a explicar, antes de que Android '
          'lo pida, por qué usa la ubicación con la app cerrada.',
        );
        await f.check('Con la explicación abierta todavía no lo pidió', () {
          expect(phone.asks.where((String a) => a == 'always'), isEmpty);
        });
        await f.tap('Aceptar');
        await f.check('Con «Aceptar» lo pide y el aviso naranja se va', () {
          expect(phone.asks.last, 'always');
          expect(f.shows('Permitir todo el tiempo'), isFalse);
        });
        // Again, with Android already letting it in use.
        await f.tap('Usar la ubicación del pago');
        phone.location = 'foreground';
        final int asked = phone.asks.length;
        await f.tap('Usar la ubicación del pago');
        await f.check('Aunque Android ya la dé, primero viene el aviso', () {
          expect(f.shows('Ubicación de tus pagos'), isTrue);
          expect(phone.asks, hasLength(asked));
        });
        await f.tap('Aceptar');
        await f.tap('Aceptar');
        await f.check('Con «Aceptar» en los dos avisos la pide todo el tiempo '
            'de una vez', () {
          expect(phone.asks.sublist(asked), <String>['always']);
          expect(phone.location, 'always');
          expect(_own(f).captureSettings.useLocation, isTrue);
          expect(f.shows('Permitir todo el tiempo'), isFalse);
        });
        // And with Android saying no.
        await f.tap('Usar la ubicación del pago');
        phone.location = 'none';
        phone.locationAnswer = 'none';
        await f.tap('Usar la ubicación del pago');
        await f.tap('Aceptar');
        await f.step(
          'Si Android la niega, el interruptor queda apagado y abajo ofrece '
          '«Abrir ajustes» para darla en el teléfono.',
        );
        await f.check('Sin permiso, la ubicación queda apagada', () {
          expect(_own(f).captureSettings.useLocation, isFalse);
          expect(
            f.shows(
              'Quincena no tiene permiso para usar la ubicación. Puedes darlo '
              'en los ajustes del teléfono.',
            ),
            isTrue,
          );
        });
        await f.tap('Abrir ajustes');
        await f.check('«Abrir ajustes» abre la página de Quincena en el '
            'teléfono', () {
          expect(phone.asks.last, 'openAppSettings');
        });
      } finally {
        debugDefaultTargetPlatformOverride = before;
      }
    },
  ),
  AppFlow(
    '09-18-en-el-computador',
    'Usar Quincena en el computador y pegar un mensaje del banco',
    area: 'Ajustes',
    goal:
        'En el computador no llegan las notificaciones del banco: quiero '
        'pegar el mensaje que me llegó y que la app lo lea.',
    data: fullAccount,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int pending = _own(f).pendingInbox.length;
      final TargetPlatform? before = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await f.tapTip('Ajustes');
        await f.step(
          'En el computador, Ajustes no tiene el aviso del día de pago ni el '
          'widget: «Automatización» trae «Captura automática» y «Reglas '
          'aprendidas».',
        );
        await f.check('Sin avisos ni widget en el computador', () async {
          expect(f.shows('Avisarme el día de pago'), isFalse);
          expect(f.shows('AUTOMATIZACIÓN'), isTrue);
          expect(f.shows('Captura automática'), isTrue);
          await f.reveal(find.text('APARIENCIA'));
          expect(f.shows('Widget de inicio'), isFalse);
        });
        await f.top();
        await f.tap('Captura automática');
        await f.step(
          '«Captura automática» dice que lo automático funciona en el teléfono '
          'y ofrece «Pegar un mensaje»; no pide la ubicación.',
        );
        await f.check('Ofrece pegar y no pide ubicación', () {
          expect(f.shows('En este dispositivo'), isTrue);
          expect(f.shows('Usar la ubicación del pago'), isFalse);
        });
        phone.clipboard =
            r'Bancolombia le informa Compra por $64.000 en FARMATODO. '
            '03/10/2026 11:20';
        await f.tap('Pegar un mensaje');
        await f.step(
          '«Pegar un mensaje» trae lo que copiaste del banco ya escrito, '
          'listo para «Leer».',
        );
        await f.tap('Cancelar');
        await f.check('Con «Cancelar» no se lee nada', () {
          expect(_own(f).pendingInbox, hasLength(pending));
        });
        await f.tap('Pegar un mensaje');
        await f.tap('Leer');
        await f.step('Con «Leer», abajo dice «Quedó en Por revisar.»');
        await f.check(
          'Quedó por revisar una compra de 64.000 en Farmatodo',
          () {
            expect(f.screenText, contains('Quedó en Por revisar.'));
            expect(_own(f).pendingInbox, hasLength(pending + 1));
            expect(
              _own(f).pendingInbox.where(
                (InboxItem i) => i.parsed.amount == Decimal.parse('64000'),
              ),
              hasLength(1),
            );
          },
        );
      } finally {
        debugDefaultTargetPlatformOverride = before;
      }
    },
  ),
  AppFlow(
    '09-19-lo-que-el-ejemplo-no-toca',
    'Probar en el ejemplo lo que solo sirve con mis cuentas',
    area: 'Ajustes',
    goal:
        'Quiero tocar todo en el ejemplo sin miedo: que no pida permisos, no '
        'guarde nada en mi teléfono y no cambie mis cuentas.',
    data: fullAccount,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int free = _own(f).ledger!.freeUntilPayday;
      final int entries = _own(f).snapshot!.entries.length;
      final int accounts = _own(f).accounts.length;
      await f.tapTip('Ajustes');
      await f.tap('Ver los datos de ejemplo');
      await f.tapTip('Ajustes');
      await f.tap('Avisarme el día de pago');
      await f.step(
        'En los Ajustes del ejemplo, «Avisarme el día de pago» no pide '
        'permiso ni programa nada: dice que en la cuenta de ejemplo esto no '
        'hace nada y ofrece «Usar mis cuentas».',
      );
      await f.check('No se programó ni se pidió nada al teléfono', () {
        expect(f.shows('Avisos'), isTrue);
        expect(f.screenText, contains('no le pide permisos a tu teléfono'));
        expect(phone.reminders, isEmpty);
        expect(_own(f).remindsClose, isFalse);
      });
      await f.tap('Seguir en el ejemplo');
      final List<String> refused = <String>[];
      for (final String row in <String>[
        'Captura automática',
        'Billeteras propias',
        'Binance',
        'Varios dispositivos',
        'Exportar mis datos',
        'Exportar movimientos en CSV',
        'Restaurar un respaldo',
        'Reglas aprendidas',
      ]) {
        await f.tap(row);
        if (!f.shows('Seguir en el ejemplo')) refused.add(row);
        await f.tap('Seguir en el ejemplo');
      }
      await f.tap('Borrar todo');
      await f.step(
        'Lo mismo dicen «Captura automática», «Reglas aprendidas», '
        '«Billeteras propias», «Binance», «Varios dispositivos», los dos '
        'exportar, «Restaurar un respaldo» y hasta «Borrar todo»: en el '
        'ejemplo no hacen nada.',
      );
      await f.check('Cada una lo dijo y no abrió nada', () {
        expect(refused, isEmpty);
        expect(phone.asks, isEmpty);
        expect(phone.saved, isEmpty);
        expect(phone.asked, isEmpty);
      });
      await f.check('Ninguna llave quedó en el llavero', () async {
        expect(await _read(f, () => SecureKeyStore().read()), isNull);
        expect(await _read(f, () => SecureKeyVault().read()), isNull);
      });
      await f.tap('Seguir en el ejemplo');
      await f.tap('Ocultar montos en el widget');
      await f.tap('Seguir en el ejemplo');
      await f.check('El widget tampoco se tocó', () {
        expect(phone.widgetCalls, isEmpty);
      });
      await f.tap('Importar extracto');
      await f.page(
        '«Importar extracto» no abre tus archivos: revisa un extracto de '
        'ejemplo de la cuenta de nómina, para ver cómo funciona.',
      );
      await f.check('No se pidió ningún archivo', () {
        expect(phone.asked, isEmpty);
        expect(find.byType(StatementPage), findsOneWidget);
      });
      await f.back();
      await f.tap('Borrar todo');
      await f.tap('Usar mis cuentas');
      await f.step(
        'Desde ese aviso, «Usar mis cuentas» vuelve a su Inicio, con la '
        'misma cifra de antes.',
      );
      await f.check('Sus cuentas siguen como estaban', () async {
        expect(_own(f).example, isFalse);
        expect(_own(f).ledger!.freeUntilPayday, free);
        expect(_own(f).accounts, hasLength(accounts));
        expect(await _read(f, () => _store(f).entries()), hasLength(entries));
        expect(f.screenText, contains(pesos(free)));
      });
    },
  ),
  AppFlow(
    '09-20-exportar-movimientos-en-csv',
    'Exportar mis movimientos en CSV',
    area: 'Ajustes',
    goal:
        'Quiero llevar mis movimientos a Excel para hacer mis propias cuentas, '
        'con las tildes bien y cada dato en su columna.',
    data: fullAccount,
    manual: <String>[
      'Abrir el archivo .csv en Excel, Numbers y Google Sheets, con las tildes '
          'bien y cada dato en su columna.',
      'El selector del sistema para guardar el archivo en Archivos, iCloud o '
          'Drive.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final List<Entry> entries = _own(f).snapshot!.entries;
      await f.tapTip('Ajustes');
      await _near(f, find.text('Exportar movimientos en CSV'));
      await f.step(
        'En «Tus datos», «Exportar movimientos en CSV» va después de «Exportar '
        'mis datos»: es para abrirlos en Excel o en otra hoja de cálculo.',
      );
      await f.check('Dice para qué sirve', () {
        expect(
          f.shows('Para abrirlos en Excel o en otra hoja de cálculo'),
          isTrue,
        );
      });
      // The person closes the system's save dialog without saving.
      phone.cancelSave = true;
      await f.tap('Exportar movimientos en CSV');
      await f.check('Si no se guarda, no dice que se guardó', () {
        expect(phone.saved, isEmpty);
        expect(f.shows('Archivo guardado.'), isFalse);
      });
      phone.cancelSave = false;
      await f.tap('Exportar movimientos en CSV');
      await f.step(
        'Guarda quincena-movimientos-2026-10-03.csv con el selector del sistema '
        'y dice «Archivo guardado.»',
      );
      final Uint8List? file =
          phone.saved['quincena-movimientos-2026-10-03.csv'];
      List<String> lines() =>
          utf8.decode(file!.sublist(3)).split('\r\n')..removeLast();
      await f.check('Es UTF-8 con su marca, para que Excel lea las tildes, y '
          'trae una línea por movimiento', () {
        expect(file!.take(3), <int>[0xEF, 0xBB, 0xBF]);
        expect(
          lines().first,
          'Fecha;Cuenta;Tipo;Categoría;Comercio;Nota;Monto;Moneda',
        );
        expect(lines(), hasLength(entries.length + 1));
        expect(f.shows('Archivo guardado.'), isTrue);
      });
      final Entry sample = entries.firstWhere(
        (Entry e) =>
            e.kind == EntryKind.expense &&
            e.payee.isNotEmpty &&
            !e.payee.contains(';'),
      );
      final Account account = _own(f).snapshot!.account(sample.accountId)!;
      String two(int n) => n.toString().padLeft(2, '0');
      final String day =
          '${sample.date.year}-${two(sample.date.month)}-'
          '${two(sample.date.day)}';
      await f.check('«${sample.payee}» sale con su fecha, cuenta, tipo y monto '
          'con signo', () {
        expect(
          lines().where(
            (String line) =>
                line.startsWith('$day;${account.name};Gasto;') &&
                line.contains(';${sample.payee};') &&
                line.endsWith(
                  ';${sample.amount.toString().replaceAll('.', ',')};'
                  '${account.asset.code}',
                ),
          ),
          isNotEmpty,
        );
      });
    },
  ),
  AppFlow(
    '10-01-empezar-a-sincronizar',
    'Empezar a sincronizar y cuidar el código',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Quiero usar Quincena también en el computador: necesito el código '
        'para unirlo, poder cambiarlo y dejar de sincronizar si me arrepiento.',
    data: seeded,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int accounts = _own(f).accounts.length;
      await f.tapTip('Ajustes');
      await f.tap('Varios dispositivos');
      await f.step(
        '«Varios dispositivos» explica que los cambios viajan en un archivo '
        'cifrado que mueves tú, y que sincronizar no es un respaldo.',
      );
      await f.tap('Empezar en este dispositivo');
      final String? code = await _syncCode(f);
      await f.step(
        '«Empezar en este dispositivo» muestra «Tu código para sincronizar» en '
        'grupos de cuatro, con «Copiar el código», «Compartir el código» y '
        '«Listo».',
      );
      await f.check('El código mostrado es el que guardó el teléfono', () {
        expect(code, isNotNull);
        for (final String group in code!.split('-')) {
          expect(find.text(group), findsWidgets);
        }
      });
      await f.tap('Compartir el código');
      await f.check('«Compartir el código» abre la hoja de compartir con una '
          'línea que dice qué código es, y el cuadro sigue ahí', () {
        expect(phone.shared, <String>[
          'Código de Quincena para unir tus dispositivos: $code',
        ]);
        expect(f.shows('Tu código para sincronizar'), isTrue);
      });
      await f.tap('Copiar el código');
      await f.step(
        '«Copiar el código» lo copia, cierra el cuadro y avisa «Código '
        'copiado.»; ahora están los botones para mover archivos.',
      );
      await f.check('El código quedó en el portapapeles', () {
        expect(phone.clipboard, code);
      });
      await f.page(
        'Sincronizando: «Guardar mis cambios en un archivo», «Abrir un archivo '
        'de otro dispositivo» y, abajo, «Este dispositivo».',
      );
      await f.tap('Ver el código');
      await f.check('«Ver el código» muestra el mismo código', () {
        expect(find.text(code!.split('-').first), findsWidgets);
      });
      await f.tap('Listo');
      await f.tap('Cambiar el código');
      await f.step(
        '«Cambiar el código» pregunta antes y explica que los archivos nuevos '
        'solo se abren con el código nuevo.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el código sigue igual', () async {
        expect(await _syncCode(f), code);
      });
      await f.tap('Cambiar el código');
      await f.tap('Cambiar el código');
      final String? changed = await _syncCode(f);
      await f.step(
        'Al confirmar aparece «Tu código nuevo para sincronizar», distinto del '
        'anterior.',
      );
      await f.check('El teléfono guardó un código nuevo', () {
        expect(changed, isNotNull);
        expect(changed, isNot(code));
        expect(find.text(changed!.split('-').first), findsWidgets);
      });
      await f.tap('Listo');
      await f.tap('Dejar de sincronizar');
      await f.step(
        '«Dejar de sincronizar» pregunta antes: el teléfono olvida el código y '
        'tus datos se quedan.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» sigue sincronizando', () async {
        expect(await _syncCode(f), changed);
      });
      await f.tap('Dejar de sincronizar');
      await f.tap('Dejar de sincronizar');
      await f.step(
        'Al confirmar vuelven «Empezar en este dispositivo» y «Unir este '
        'dispositivo».',
      );
      await f.check('El código se olvidó y las cuentas siguen', () async {
        expect(await _syncCode(f), isNull);
        expect(f.shows('Empezar en este dispositivo'), isTrue);
        expect(await _read(f, () => _store(f).accounts()), hasLength(accounts));
      });
    },
  ),
  AppFlow(
    '10-02-unir-este-telefono',
    'Unir un teléfono nuevo con el código',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Ya uso Quincena en el computador. En el teléfono nuevo quiero pegar '
        'el código que me compartí y traer todo lo de allá.',
    data: _newPhone,
    manual: <String>[
      'Mover el archivo .qsync del computador al teléfono por AirDrop, '
          'Archivos o un chat, y elegirlo en el selector del sistema.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      // The computer, where Quincena already has everything.
      final (QuincenaStore computer, SyncService there) = await _otherDevice(
        f,
        data: seeded,
      );
      final String code = await _read(f, there.start);
      final Uint8List file = await _read(f, there.export);
      final int theirs = (await _read(f, computer.entries)).length;
      // This phone opened a backup before, so it knows a backup code too.
      final VaultKey backup = VaultKey.generate();
      await _read(f, () => SecureBackupKeyStore().write(backup.bytes));
      await f.tapTip('Ajustes');
      await f.tap('Varios dispositivos');
      await f.tap('Unir este dispositivo');
      await f.step(
        '«Unir este dispositivo» pide pegar el código que copiaste o '
        'compartiste desde el otro dispositivo, con el botón «Pegar»; '
        'escribirlo queda de último recurso.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no se une', () async {
        expect(await _syncCode(f), isNull);
      });
      await f.tap('Unir este dispositivo');
      phone.clipboard = null;
      await f.tap('Pegar');
      await f.step(
        'Con nada copiado, «Pegar» lo dice: «No hay nada copiado. Copia el '
        'código de donde lo guardaste, o escríbelo.»',
      );
      await f.check('Dice que no hay nada copiado', () {
        expect(
          f.shows(
            'No hay nada copiado. Copia el código de donde lo guardaste, o '
            'escríbelo.',
          ),
          isTrue,
        );
      });
      phone.clipboard = 'Código de respaldo de Quincena: ${backup.code}';
      await f.tap('Pegar');
      await f.tap('Unir');
      await f.step(
        'Con el código de respaldo copiado, «Pegar» trae solo el código y '
        '«Unir» dice cuál es: «Ese es tu código de respaldo, no el de '
        'sincronizar.»',
      );
      await f.check('El código de respaldo no une el teléfono y dice cuál '
          'es', () async {
        expect(
          f.shows(
            'Ese es tu código de respaldo, no el de sincronizar. Para unir '
            'este dispositivo usa el código que muestra el otro en Varios '
            'dispositivos.',
          ),
          isTrue,
        );
        expect(await _syncCode(f), isNull);
      });
      await f.type('Código', 'ABCD-EFGH');
      await f.tap('Unir');
      await f.step(
        'Un código corto no pasa: «Al código le sobran o le faltan '
        'caracteres: son 54.»',
      );
      await f.check('Avisa que le faltan caracteres', () {
        expect(
          f.shows('Al código le sobran o le faltan caracteres: son 54.'),
          isTrue,
        );
      });
      await f.type('Código', 'U${code.substring(1)}');
      await f.tap('Unir');
      await f.check('Con una U avisa que el código no la usa', () {
        expect(
          f.shows(
            'Hay un carácter que el código no usa. Revisa que no sea una U.',
          ),
          isTrue,
        );
      });
      final String typo =
          '${code.substring(0, 2)}${code[2] == 'A' ? 'B' : 'A'}'
          '${code.substring(3)}';
      await f.type('Código', typo);
      await f.tap('Unir');
      await f.step(
        'Con un carácter cambiado: «El código no cuadra: revisa si hay un '
        'carácter cambiado.»',
      );
      await f.check('Un código con un error no une el teléfono', () async {
        expect(await _syncCode(f), isNull);
      });
      // What the computer shared, copied from a note to oneself.
      phone.clipboard = 'Código de Quincena para unir tus dispositivos: $code';
      await f.tap('Pegar');
      await f.check(
        '«Pegar» deja en el campo solo el código del computador',
        () {
          expect(
            f.tester.widget<TextField>(find.byType(TextField)).controller!.text,
            code,
          );
        },
      );
      await f.tap('Unir');
      await f.step(
        'Con el código del computador pegado, une el teléfono: «Listo. Ahora '
        'abre un archivo de tu otro dispositivo».',
      );
      await f.check('El teléfono quedó con el código del computador', () async {
        expect(await _syncCode(f), code);
      });
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.check(
        'Si el selector se cierra sin elegir, no cambia nada',
        () async {
          expect(await _read(f, () => _store(f).accounts()), hasLength(1));
        },
      );
      phone.toPick.add(file);
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      final String arrived = _notice(f);
      await f.step(
        'Al abrir el archivo del computador, el aviso dice qué llegó: '
        '«$arrived»',
      );
      // Their movements, a transfer once, and their accounts: all new here.
      final List<Entry> moved = await _read(f, computer.entries);
      final int movements = <String>{
        for (final Entry e in moved) e.transferId ?? e.id,
      }.length;
      final int accounts = (await _read(
        f,
        () => computer.accounts(archived: true),
      )).length;
      await f.check(
        'El aviso dice que llegaron $movements movimientos y $accounts cuentas',
        () {
          expect(
            arrived,
            startsWith('Llegaron $movements movimientos, $accounts cuentas'),
          );
        },
      );
      await f.check(
        'Llegaron las cuentas y los $theirs movimientos del computador, y '
        'Daviplata sigue',
        () async {
          final List<Account> accounts = await _read(
            f,
            () => _store(f).accounts(),
          );
          expect(
            accounts.map((Account a) => a.name),
            containsAll(<String>['Bancolombia', 'Visa', 'Daviplata']),
          );
          expect(await _read(f, () => _store(f).entries()), hasLength(theirs));
        },
      );
      await f.back();
      await f.back();
      final int free = _own(f).ledger!.freeUntilPayday;
      await f.step(
        'Inicio ya cuenta lo del computador y Daviplata: puedes gastar '
        '${pesos(free)}.',
      );
      await f.check('Inicio muestra ${pesos(free)}, lo que calcula la app', () {
        expect(f.screenText, contains(pesos(free)));
        expect(_own(f).accounts.map((Account a) => a.name), contains('Visa'));
      });
    },
  ),
  AppFlow(
    '10-03-llevar-mis-cambios',
    'Pasar los cambios de un dispositivo al otro',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Anoto en el teléfono y a veces en el computador: quiero que los dos '
        'queden con lo mismo.',
    data: seeded,
    manual: <String>[
      'El selector del sistema para guardar el archivo y para elegirlo en el '
          'otro dispositivo.',
      'Abrir en el computador el archivo que guardó el teléfono.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int free = _own(f).ledger!.freeUntilPayday;
      final int mine = _own(f).snapshot!.entries.length;
      await f.tapTip('Ajustes');
      await f.tap('Varios dispositivos');
      await f.tap('Empezar en este dispositivo');
      await f.tap('Copiar el código');
      await f.tap('Guardar mis cambios en un archivo');
      await f.step(
        'Copia el código y enseguida toca «Guardar mis cambios en un '
        'archivo»: guarda quincena-2026-10-03.qsync y el aviso de abajo ya '
        'dice «Archivo guardado. Ábrelo en tu otro dispositivo.»',
      );
      final Uint8List? saved = phone.saved['quincena-2026-10-03.qsync'];
      await f.check('Se guardó el archivo cifrado del 3 de octubre', () {
        expect(saved, isNotNull);
        expect(SealedFile.sync.marks(saved!), isTrue);
        expect(
          utf8.decode(saved, allowMalformed: true),
          isNot(contains('Bancolombia')),
        );
        expect(
          f.shows('Archivo guardado. Ábrelo en tu otro dispositivo.'),
          isTrue,
        );
      });
      await f.check('El aviso del código copiado ya no está, ni espera', () {
        expect(f.shows('Código copiado.'), isFalse);
        expect(find.byType(SnackBar), findsOneWidget);
      });
      // The computer joins with the code copied and opens the file.
      final (QuincenaStore computer, SyncService there) = await _otherDevice(f);
      await _read(f, () => there.join(phone.clipboard!));
      await _read(f, () => there.import(saved!));
      await f.check('El computador recibe los $mine movimientos', () async {
        expect(await _read(f, computer.entries), hasLength(mine));
      });
      // On the computer, a lunch paid from Bancolombia.
      await _read(f, () async {
        final Account bank = (await computer.accounts()).firstWhere(
          (Account a) => a.name == 'Bancolombia',
        );
        await computer.addEntry(
          accountId: bank.id,
          amount: Decimal.parse('-32000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 3, 13),
          category: 'restaurants',
          payee: 'Almuerzo en el computador',
        );
      });
      phone.toPick.add(await _read(f, there.export));
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.step(
        'Al abrir el archivo del computador el aviso dice qué llegó: «Llegó un '
        'movimiento.»',
      );
      await f.check('Llegó el almuerzo anotado en el computador', () {
        expect(_own(f).snapshot!.entries, hasLength(mine + 1));
        expect(
          _own(f).snapshot!.entries.map((Entry e) => e.payee),
          contains('Almuerzo en el computador'),
        );
        expect(f.shows('Llegó un movimiento.'), isTrue);
      });
      phone.toPick.add(await _read(f, there.export));
      await f.tap('Abrir un archivo de otro dispositivo');
      // Right after the tap, before the picture takes its time: queued, the
      // notice before would still be the one showing.
      await f.check(
        'Al momento, el aviso es el de este archivo y no el de antes',
        () {
          expect(f.shows('Ya estaba todo al día.'), isTrue);
          expect(f.shows('Llegó un movimiento.'), isFalse);
          expect(find.byType(SnackBar), findsOneWidget);
        },
      );
      await f.step(
        'Abrir enseguida otra vez un archivo con lo mismo no duplica nada, y '
        'el aviso cambia al momento: «Ya estaba todo al día.»',
      );
      await f.check('Nada se duplicó', () {
        expect(_own(f).snapshot!.entries, hasLength(mine + 1));
      });
      await f.back();
      await f.back();
      await f.check(
        'Puedes gastar pasó de ${pesos(free)} a ${pesos(free - 32000)}',
        () {
          expect(_own(f).ledger!.freeUntilPayday, free - 32000);
          expect(f.screenText, contains(pesos(free - 32000)));
        },
      );
    },
  ),
  AppFlow(
    '10-04-archivos-que-no-sirven-y-cambios-que-esperan',
    'Archivos que no sirven y cambios que quedaron esperando',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Si abro un archivo equivocado no quiero dañar nada, y si cambié lo '
        'mismo en dos lados quiero escoger qué versión queda.',
    data: seeded,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int mine = _own(f).snapshot!.entries.length;
      await f.tapTip('Ajustes');
      await f.tap('Varios dispositivos');
      await f.tap('Empezar en este dispositivo');
      await f.tap('Listo');
      final String code = (await _syncCode(f))!;
      // A backup in JSON, not a sync file.
      phone.toPick.add(await _read(f, () => Backups(_store(f)).plain()));
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.step(
        'Un respaldo en JSON no es de sincronizar: «Ese no es un archivo de '
        'sincronización de Quincena.»',
      );
      // A sealed backup, brought here by mistake.
      final SealedBackup sealed = await _read(
        f,
        () => Backups(_store(f)).seal(),
      );
      phone.toPick.add(sealed.file);
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.step(
        'Un respaldo cifrado dice qué es y dónde se abre: «Ese es un respaldo, '
        'no un archivo de sincronizar: se abre en Ajustes, «Restaurar un '
        'respaldo». No cambió nada.»',
      );
      await f.check('El respaldo cifrado se reconoce y no cambia nada', () {
        expect(
          f.shows(
            'Ese es un respaldo, no un archivo de sincronizar: se abre en '
            'Ajustes, «Restaurar un respaldo». No cambió nada.',
          ),
          isTrue,
        );
        expect(_own(f).snapshot!.entries, hasLength(mine));
      });
      // A file from a vault with another code.
      final (QuincenaStore stranger, SyncService elsewhere) =
          await _otherDevice(f);
      await _read(f, () => stranger.ensureCategories());
      await _read(f, elsewhere.start);
      phone.toPick.add(await _read(f, elsewhere.export));
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.step(
        'Uno hecho con otro código: «Ese archivo se hizo con otro código.»',
      );
      // The right vault, cut short on the way.
      final (QuincenaStore computer, SyncService there) = await _otherDevice(f);
      await _read(f, () => there.join(code));
      final Uint8List whole = await _read(
        f,
        () => SyncService(
          _store(f),
          keys: SecureKeyStore(),
          now: () => screensNow,
        ).export(),
      );
      phone.toPick.add(Uint8List.sublistView(whole, 0, whole.length ~/ 2));
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.step(
        'Uno que se cortó: «El archivo está dañado o se cortó: guárdalo de '
        'nuevo en el otro dispositivo. No cambió nada.»',
      );
      // From a newer Quincena.
      phone.toPick.add(
        await _read(
          f,
          () => SyncFile.seal(VaultKey.fromCode(code), <String, Object?>{
            'app': 'quincena',
            'format': 99,
            'records': <Object?>[],
          }),
        ),
      );
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.check('Ningún archivo malo cambió nada', () {
        expect(_own(f).snapshot!.entries, hasLength(mine));
        expect(
          f.shows(
            'Ese archivo es de una versión más nueva de Quincena: actualiza '
            'la app.',
          ),
          isTrue,
        );
      });
      // The same lunch changed on both: here the name, there a note, later.
      await _read(f, () async {
        await there.import(whole);
        final Entry here = (await _store(
          f,
        ).entries()).firstWhere((Entry e) => e.payee == 'Crepes & Waffles');
        await _store(f).updateEntry(here.copyWith(payee: 'Crepes con Laura'));
        final Entry theirs = (await computer.entries()).firstWhere(
          (Entry e) => e.id == here.id,
        );
        await computer.updateEntry(theirs.copyWith(note: 'Con factura'));
      });
      phone.toPick.add(await _read(f, there.export));
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.check('El aviso dice qué llegó y que uno espera', () {
        expect(
          f.shows('Llegó un movimiento. Uno espera en «Para revisar».'),
          isTrue,
        );
      });
      await f.reveal(find.text('Traer de vuelta'));
      await f.step(
        'Cambiado en los dos: quedó lo del computador y tu cambio espera en '
        '«Para revisar», lado a lado con lo que quedó: «Nombre» y «Nota» '
        'marcados porque cambiaron. Abajo, «Descartar», «Combinar» y «Traer '
        'de vuelta».',
      );
      Entry lunch() => _own(
        f,
      ).snapshot!.entries.firstWhere((Entry e) => e.category == 'restaurants');
      await f.check('Quedó la versión del computador y la tuya espera, campo '
          'por campo', () {
        expect(lunch().payee, 'Crepes & Waffles');
        expect(lunch().note, 'Con factura');
        expect(find.textContaining('Crepes con Laura'), findsOneWidget);
        expect(_compared(f), <String, (String, String, bool)>{
          'Nombre': ('Crepes & Waffles', 'Crepes con Laura', true),
          'Monto': (
            _rowAmount(f, 'Crepes & Waffles'),
            _rowAmount(f, 'Crepes & Waffles'),
            false,
          ),
          'Categoría': ('Restaurantes', 'Restaurantes', false),
          'Fecha': (
            _compared(f)['Fecha']!.$1,
            _compared(f)['Fecha']!.$1,
            false,
          ),
          'Nota': ('Con factura', '\u2014', true),
        });
      });
      await f.tap('Traer de vuelta');
      await f.reveal(find.text('Descartar'));
      await f.step(
        '«Traer de vuelta» deja tu nombre, y lo que había antes queda a su vez '
        'en «Para revisar»: nada se pierde.',
      );
      await f.check('Tu versión volvió: Crepes con Laura', () {
        expect(lunch().payee, 'Crepes con Laura');
        expect(
          find.textContaining('Lo que había antes de traer de vuelta'),
          findsOneWidget,
        );
      });
      await f.check(
        'Lo del computador, con su nota, espera ahora en «Para revisar»',
        () async {
          final List<SyncConflict> waiting = await _read(
            f,
            () => SyncService(_store(f), keys: SecureKeyStore()).conflicts(),
          );
          expect(waiting, hasLength(1));
          expect(waiting.single.record.data?['note'], 'Con factura');
        },
      );
      await _waitMessages(f);
      await f.tap('Dejar de sincronizar');
      await f.tap('Dejar de sincronizar');
      await f.reveal(find.text('Descartar'));
      await f.step(
        'Al dejar de sincronizar, lo que espera sigue en «Para revisar», bajo '
        '«Empezar en este dispositivo»: parar no pierde nada.',
      );
      await f.check('Sin código, lo que espera sigue ahí', () async {
        expect(await _syncCode(f), isNull);
        expect(f.shows('Empezar en este dispositivo'), isTrue);
        expect(f.shows('PARA REVISAR'), isTrue);
      });
      await f.tap('Descartar');
      await f.step(
        '«Descartar» lo quita de la lista, «Para revisar» desaparece y abajo '
        'dice «Descartado.» con «Deshacer», por si fue sin querer.',
      );
      Future<List<SyncConflict>> waiting() => _read(
        f,
        () => SyncService(_store(f), keys: SecureKeyStore()).conflicts(),
      );
      await f.check('No queda nada por revisar', () async {
        expect(f.shows('PARA REVISAR'), isFalse);
        expect(await waiting(), isEmpty);
        expect(lunch().payee, 'Crepes con Laura');
      });
      await f.tap('Deshacer');
      await f.step('Con «Deshacer» vuelve a «Para revisar», como estaba.');
      await f.check('Volvió lo del computador, con su nota', () async {
        expect(f.shows('PARA REVISAR'), isTrue);
        final List<SyncConflict> back = await waiting();
        expect(back, hasLength(1));
        expect(back.single.record.data?['note'], 'Con factura');
      });
      await _waitMessages(f);
      await f.tap('Descartar');
      await f.check('Descartado otra vez, ya no queda nada', () async {
        expect(f.shows('PARA REVISAR'), isFalse);
        expect(await waiting(), isEmpty);
      });
    },
  ),
  AppFlow(
    '10-05-respaldo-cifrado',
    'Guardar un respaldo cifrado y cuidar su código',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Quiero una copia de todo por si pierdo el teléfono, que nadie más '
        'pueda leer.',
    data: fullAccount,
    manual: <String>[
      'El selector del sistema para guardar el archivo .qbackup en Archivos, '
          'iCloud o Drive.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int entries = _own(f).snapshot!.entries.length;
      await f.tapTip('Ajustes');
      await _waitMessages(f);
      await f.tap('Exportar mis datos');
      await f.step(
        '«Exportar mis datos» ofrece «Cifrado (recomendado)», ya marcado, o '
        '«Sin cifrar (JSON)». Aún no hay código de respaldo.',
      );
      await f.check('Todavía no hay código ni botón para verlo', () async {
        expect(await _read(f, () => Backups(_store(f)).code()), isNull);
        expect(f.shows('Ver mi código de respaldo'), isFalse);
      });
      await f.back();
      await f.check('Cerrar la hoja no guarda nada', () {
        expect(phone.saved, isEmpty);
      });
      await _waitMessages(f);
      await f.tap('Exportar mis datos');
      await f.tap('Exportar');
      final String? code = await _read(f, () => Backups(_store(f)).code());
      await f.step(
        'La primera vez, antes de guardar, muestra «Tu código de respaldo» con '
        '«Copiar el código», «Compartir el código» y «Ya lo guardé».',
      );
      await f.check('El código mostrado es el que quedó en el teléfono', () {
        expect(code, isNotNull);
        expect(find.text(code!.split('-').first), findsWidgets);
      });
      await f.tap('Compartir el código');
      await f.check('«Compartir el código» lo pasa a la hoja de compartir '
          'diciendo que es el de respaldo', () {
        expect(phone.shared, <String>['Código de respaldo de Quincena: $code']);
        expect(f.shows('Tu código de respaldo'), isTrue);
      });
      await f.tap('Ya lo guardé');
      await f.step(
        'Con «Ya lo guardé» se guarda el archivo: «Archivo guardado.»',
      );
      final Uint8List? first = phone.saved['quincena-2026-10-03.qbackup'];
      await f.check(
        'El respaldo abre con ese código en otro teléfono y trae los $entries '
        'movimientos',
        () async {
          expect(first, isNotNull);
          final List<Object?>? inside = await _openBackup(f, first!, code!);
          expect(inside, hasLength(entries));
        },
      );
      await f.check('Sin el código, otro teléfono no lo abre', () async {
        expect(await _openBackup(f, first!, null), isNull);
      });
      await _waitMessages(f);
      await f.tap('Exportar mis datos');
      await f.step(
        'Con un código ya hecho, la hoja suma «Ver mi código de respaldo» y '
        '«Cambiar el código».',
      );
      await f.tap('Ver mi código de respaldo');
      await f.check('«Ver mi código de respaldo» muestra el mismo', () {
        expect(find.text(code!.split('-').first), findsWidgets);
      });
      await f.tap('Listo');
      await f.tap('Cambiar el código');
      await f.step(
        '«Cambiar el código» avisa que los respaldos viejos siguen abriendo '
        'con el código de antes.',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el código sigue igual', () async {
        expect(await _read(f, () => Backups(_store(f)).code()), code);
      });
      await f.tap('Cambiar el código');
      await f.tap('Cambiar');
      final String? changed = await _read(f, () => Backups(_store(f)).code());
      await f.step('Con «Cambiar» aparece «Tu nuevo código de respaldo».');
      await f.tap('Copiar el código');
      await f.check('«Copiar el código» copia el código nuevo', () {
        expect(phone.clipboard, changed);
      });
      await f.tap('Exportar');
      await f.check('Esta vez no muestra el código antes de guardar', () {
        expect(f.shows('Tu código de respaldo'), isFalse);
      });
      final Uint8List? second = phone.saved['quincena-2026-10-03.qbackup'];
      await f.check(
        'El respaldo nuevo abre con el código nuevo y el viejo con el viejo',
        () async {
          expect(changed, isNot(code));
          expect(await _openBackup(f, second!, changed!), hasLength(entries));
          expect(await _openBackup(f, first!, code!), hasLength(entries));
          expect(await _openBackup(f, second, code), isNull);
        },
      );
      phone.toPick.add(second!);
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.step(
        'En este teléfono, «Restaurar un respaldo» abre su propio respaldo '
        'sin pedir el código y, antes de reemplazar, dice qué trae: «Respaldo '
        'del 3 de octubre de 2026», sus cuentas, movimientos, metas y lo demás '
        'del Plan.',
      );
      await f.check('Dice qué trae el respaldo antes de tocar nada', () async {
        final BackupContents held = BackupContents.of(
          await _read(f, () => _store(f).exportJson()),
        );
        expect(f.shows('Respaldo del 3 de octubre de 2026:'), isTrue);
        for (final String line in _holds(held)) {
          expect(f.shows(line), isTrue, reason: line);
        }
      });
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» todo sigue igual', () {
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
    },
  ),
  AppFlow(
    '10-06-exportar-sin-cifrar',
    'Exportar mis datos en JSON para otra herramienta',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Quiero llevar mis movimientos a una hoja de cálculo y necesito un '
        'archivo que cualquier programa lea.',
    data: fullAccount,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      await f.tapTip('Ajustes');
      await _waitMessages(f);
      await f.tap('Exportar mis datos');
      await f.step(
        'La hoja viene con «Cifrado (recomendado)» marcado; «Sin cifrar (JSON)» '
        'está debajo.',
      );
      await f.tap('Sin cifrar (JSON)');
      await f.step(
        'Con «Sin cifrar (JSON)» marcado: cualquiera que tenga el archivo puede '
        'leer tus finanzas.',
      );
      // The person closes the system's save dialog without saving.
      phone.cancelSave = true;
      await f.tap('Exportar');
      await f.check('Si no se guarda, no dice que se guardó', () {
        expect(phone.saved, isEmpty);
        expect(f.shows('Archivo guardado.'), isFalse);
      });
      phone.cancelSave = false;
      await f.tap('Exportar mis datos');
      await f.tap('Sin cifrar (JSON)');
      await f.tap('Exportar');
      await f.step(
        'Sin pedir código, guarda quincena-2026-10-03.json y dice «Archivo '
        'guardado.»',
      );
      final Uint8List? file = phone.saved['quincena-2026-10-03.json'];
      await f.check(
        'El JSON trae el perfil, las cuentas y los movimientos',
        () async {
          final Map<String, Object?> json =
              jsonDecode(utf8.decode(file!)) as Map<String, Object?>;
          expect(json['app'], 'quincena');
          expect((json['profile']! as Map<String, Object?>)['name'], 'Diego');
          expect(
            json['accounts'],
            hasLength(
              (await _read(f, () => _store(f).accounts(archived: true))).length,
            ),
          );
          expect(json['entries'], hasLength(_own(f).snapshot!.entries.length));
        },
      );
      await f.check('No lleva llaves ni crea un código de respaldo', () async {
        final Map<String, Object?> json =
            jsonDecode(utf8.decode(file!)) as Map<String, Object?>;
        expect(
          (json['settings']! as Map<String, Object?>).keys.where(
            (String k) => k.startsWith('sync.') || k.startsWith('app.'),
          ),
          isEmpty,
        );
        expect(await _read(f, () => Backups(_store(f)).code()), isNull);
      });
    },
  ),
  AppFlow(
    '10-07-importar-un-respaldo',
    'Recuperar mis datos desde un archivo',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Me equivoqué borrando cosas y quiero volver a la copia que guardé, '
        'sin que un archivo equivocado me dañe nada.',
    data: fullAccount,
    manual: <String>[
      'Elegir el archivo en el selector del sistema, desde Archivos, iCloud o '
          'Drive.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int entries = _own(f).snapshot!.entries.length;
      // The copy kept: the account before the captures and the rest.
      final (QuincenaStore copy, _) = await _otherDevice(f, data: seeded);
      final Uint8List backup = await _read(f, () => Backups(copy).plain());
      final int kept = (await _read(f, copy.entries)).length;
      await f.tapTip('Ajustes');
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.check('Si el selector se cierra sin elegir, nada cambia', () {
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
      phone.toPick.add(Uint8List.fromList(utf8.encode('Lista del mercado')));
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.step(
        'Un archivo que no es de Quincena: «Ese archivo no lo exportó '
        'Quincena. No se cambió nada.»',
      );
      await f.check('Nada cambió', () {
        expect(_own(f).snapshot!.entries, hasLength(entries));
        expect(f.screenText, contains('Ese archivo no lo exportó Quincena.'));
      });
      // A copy from a newer Quincena.
      phone.toPick.add(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'app': 'quincena',
              'version': QuincenaStore.exportVersion + 1,
            }),
          ),
        ),
      );
      await f.tap('Restaurar un respaldo');
      // Right after the tap, before the picture takes its time: queued, the
      // notice about the other file would still be the one showing.
      await f.check('Al momento, el aviso es el de este archivo', () {
        expect(f.screenText, contains('Actualiza la app'));
        expect(
          f.screenText,
          isNot(contains('Ese archivo no lo exportó Quincena.')),
        );
        expect(find.byType(SnackBar), findsOneWidget);
      });
      await f.step(
        'Enseguida, uno de una Quincena más nueva: el aviso cambia al momento '
        'a «Actualiza la app y vuelve a intentarlo; no se cambió nada.»',
      );
      await f.check('Un archivo más nuevo no cambia nada', () {
        expect(f.screenText, contains('Actualiza la app'));
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
      // One that looks whole but breaks halfway in.
      phone.toPick.add(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'app': 'quincena',
              'version': QuincenaStore.exportVersion,
              'accounts': <Object?>[
                <String, Object?>{'id': 'a1'},
              ],
            }),
          ),
        ),
      );
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.tap('Restaurar');
      await f.step(
        'Uno que se rompe a mitad de camino: aunque se dijo «Restaurar», '
        'avisa «Ese archivo está dañado o incompleto. No se cambió nada.»',
      );
      await f.check(
        'El archivo dañado no borró nada: siguen el perfil, las cuentas y los '
        '$entries movimientos',
        () async {
          expect(
            f.screenText,
            contains('Ese archivo está dañado o incompleto'),
          );
          expect(await _read(f, () => _store(f).entries()), hasLength(entries));
          expect((await _read(f, () => _store(f).profile()))!.name, 'Diego');
          expect(
            await _read(f, () => _store(f).accounts()),
            hasLength(_own(f).accounts.length),
          );
        },
      );
      phone.toPick.add(backup);
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.step(
        'Con el respaldo, antes de tocar nada pregunta «¿Restaurar este '
        'respaldo?» y dice qué trae: la fecha, las cuentas, los movimientos, '
        'las metas y lo demás del Plan. Avisa que lo de ahora se borra y '
        'ofrece «Guardar lo de ahora primero».',
      );
      final BackupContents held = BackupContents.of(
        jsonDecode(utf8.decode(backup)) as Map<String, Object?>,
      );
      await f.check('Dice lo que trae el archivo, no lo que hay ahora', () {
        expect(f.shows('Respaldo del 3 de octubre de 2026:'), isTrue);
        for (final String line in _holds(held)) {
          expect(f.shows(line), isTrue, reason: line);
        }
        expect(
          f.shows('${_own(f).snapshot!.entries.length} movimientos'),
          isFalse,
        );
      });
      await f.tap('Guardar lo de ahora primero');
      await f.tap('Exportar');
      await f.tap('Ya lo guardé');
      await f.step(
        '«Guardar lo de ahora primero» abre la hoja de exportar; al guardar el '
        'respaldo cifrado de lo de ahora vuelve la misma pregunta, con lo que '
        'trae el archivo.',
      );
      await f.check('Se guardó lo de ahora y la pregunta sigue ahí', () async {
        final Uint8List? now = phone.saved['quincena-2026-10-03.qbackup'];
        expect(now, isNotNull);
        final String code = (await _read(f, () => Backups(_store(f)).code()))!;
        expect(await _openBackup(f, now!, code), hasLength(entries));
        expect(f.shows('¿Restaurar este respaldo?'), isTrue);
      });
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» siguen los $entries movimientos', () {
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
      phone.toPick.add(backup);
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.tap('Restaurar');
      await f.step('Con «Restaurar»: «Respaldo restaurado.»');
      await f.check('Quedaron los $kept movimientos del archivo', () async {
        expect(await _read(f, () => _store(f).entries()), hasLength(kept));
        expect(_own(f).snapshot!.entries, hasLength(kept));
      });
      await f.back();
      final int free = _own(f).ledger!.freeUntilPayday;
      await f.step(
        'Inicio muestra lo del archivo: puedes gastar ${pesos(free)}.',
      );
      await f.check('Inicio dice ${pesos(free)}, lo que calcula la app', () {
        expect(f.screenText, contains(pesos(free)));
      });
      await _reopen(f);
      await f.check('Al volver a abrir, la app abre en tus cuentas', () {
        expect(find.byType(OwnShell), findsOneWidget);
        expect(f.shows('¿Cómo quieres empezar?'), isFalse);
      });
    },
  ),
  AppFlow(
    '10-08-respaldo-de-otro-telefono',
    'Abrir en el teléfono nuevo el respaldo cifrado del viejo',
    area: 'Varios dispositivos y respaldo',
    goal:
        'Cambié de teléfono y tengo el respaldo cifrado del viejo: quiero '
        'abrirlo aquí con mi código.',
    data: fullAccount,
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final int entries = _own(f).snapshot!.entries.length;
      // The old phone: its sealed backup and its code, and a sync file.
      final (QuincenaStore old, SyncService oldSync) = await _otherDevice(
        f,
        data: seeded,
      );
      final SealedBackup sealed = await _read(
        f,
        () => Backups(old, keys: MemoryBackupKeyStore()).seal(),
      );
      final String code = sealed.newCode!;
      final int kept = (await _read(f, old.entries)).length;
      final String syncCode = await _read(f, oldSync.start);
      phone.toPick.add(await _read(f, oldSync.export));
      // This phone already syncs with the old one: it keeps that code too.
      await _read(
        f,
        () => SecureKeyStore().write(VaultKey.fromCode(syncCode).bytes),
      );
      await f.tapTip('Ajustes');
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.step(
        'Un archivo de sincronizar no es un respaldo: dice que se abre en '
        '«Varios dispositivos» y no cambia nada.',
      );
      await f.check('El archivo de sincronizar no cambia nada', () {
        expect(f.screenText, contains('Ese es un archivo de sincronización'));
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
      phone.toPick.add(sealed.file);
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.step(
        'El respaldo cifrado del otro teléfono pide su código: «Respaldo '
        'cifrado», con «Cancelar» y «Abrir».',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no cambia nada', () {
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
      phone.toPick.add(sealed.file);
      await _waitMessages(f);
      await f.tap('Restaurar un respaldo');
      await f.type('Código', VaultKey.generate().code);
      await f.tap('Abrir');
      await f.step(
        'Con otro código: «Ese código no abre este respaldo. Si es el de '
        'sincronización, el de respaldo es otro.»',
      );
      await f.check('Un código equivocado no abre nada', () {
        expect(
          f.shows(
            'Ese código no abre este respaldo. Si es el de sincronización, '
            'el de respaldo es otro.',
          ),
          isTrue,
        );
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
      phone.clipboard = syncCode;
      await f.tap('Pegar');
      await f.tap('Abrir');
      await f.step(
        'Con el código de sincronizar pegado dice cuál es: «Ese es tu código '
        'para sincronizar, no el de respaldo.»',
      );
      await f.check('El código de sincronizar no abre el respaldo y se '
          'nombra', () {
        expect(
          f.shows(
            'Ese es tu código para sincronizar, no el de respaldo. Este '
            'respaldo se abre con el código de respaldo que Quincena te '
            'mostró al exportar cifrado.',
          ),
          isTrue,
        );
        expect(_own(f).snapshot!.entries, hasLength(entries));
      });
      // The backup code, from the note it was shared to.
      phone.clipboard = 'Código de respaldo de Quincena: $code';
      await f.tap('Pegar');
      await f.tap('Abrir');
      await f.step(
        'Con el código de respaldo pegado se abre y, antes de reemplazar, dice '
        'qué trae el respaldo del otro teléfono.',
      );
      await f.check(
        'Dice lo que trae el respaldo del teléfono viejo',
        () async {
          final BackupContents held = BackupContents.of(
            await _read(f, old.exportJson),
          );
          for (final String line in _holds(held)) {
            expect(f.shows(line), isTrue, reason: line);
          }
        },
      );
      await f.tap('Restaurar');
      await f.step('Con «Restaurar»: «Respaldo restaurado.»');
      await f.check(
        'Quedaron los $kept movimientos del teléfono viejo',
        () async {
          expect(await _read(f, () => _store(f).entries()), hasLength(kept));
        },
      );
      await f.check(
        'Este teléfono se queda con ese código de respaldo',
        () async {
          expect(await _read(f, () => Backups(_store(f)).code()), code);
        },
      );
    },
  ),
  AppFlow(
    '10-09-combinar-dos-cambios',
    'Combinar dos cambios del mismo movimiento',
    area: 'Varios dispositivos y respaldo',
    goal:
        'En el teléfono le cambié el nombre a un movimiento y en el computador '
        'le puse una nota: quiero quedarme con las dos cosas.',
    data: seeded,
    manual: <String>[
      'Llevar el archivo de un dispositivo al otro y de vuelta, y ver el '
          'movimiento combinado en los dos.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      await f.tapTip('Ajustes');
      await f.tap('Varios dispositivos');
      await f.tap('Empezar en este dispositivo');
      await f.tap('Listo');
      final String code = (await _syncCode(f))!;
      // The computer joins with the code and opens this phone's file.
      final (QuincenaStore computer, SyncService there) = await _otherDevice(f);
      await _read(f, () async {
        await there.join(code);
        await there.import(
          await SyncService(
            _store(f),
            keys: SecureKeyStore(),
            now: () => screensNow,
          ).export(),
        );
        // The same lunch: here a new name; there, later, a note.
        final Entry here = (await _store(
          f,
        ).entries()).firstWhere((Entry e) => e.payee == 'Crepes & Waffles');
        await _store(f).updateEntry(here.copyWith(payee: 'Crepes con Laura'));
        final Entry theirs = (await computer.entries()).firstWhere(
          (Entry e) => e.id == here.id,
        );
        await computer.updateEntry(theirs.copyWith(note: 'Con factura'));
      });
      phone.toPick.add(await _read(f, there.export));
      await _waitMessages(f);
      await f.tap('Abrir un archivo de otro dispositivo');
      await f.reveal(find.text('Combinar'));
      await f.step(
        'Al abrir el archivo del computador, «Para revisar» muestra las dos '
        'versiones lado a lado: el nombre y la nota cambiaron, cada uno en un '
        'lado, y están marcados. Abajo está «Combinar».',
      );
      Entry lunch() => _own(
        f,
      ).snapshot!.entries.firstWhere((Entry e) => e.category == 'restaurants');
      await f.check('Quedó lo del computador; tu nombre espera al lado', () {
        expect(lunch().payee, 'Crepes & Waffles');
        expect(lunch().note, 'Con factura');
        final Map<String, (String, String, bool)> rows = _compared(f);
        expect(rows['Nombre'], ('Crepes & Waffles', 'Crepes con Laura', true));
        expect(rows['Nota'], ('Con factura', '\u2014', true));
        expect(rows['Categoría']!.$3, isFalse);
      });
      await f.tap('Combinar');
      await f.step(
        '«Combinar» pregunta solo por lo que cambió: en «Nombre», lo que quedó '
        'o lo que espera; en «Nota» ya viene marcada la que dice algo, «Con '
        'factura».',
      );
      bool chosen(String text) {
        final Finder tile = find.ancestor(
          of: find.text(text),
          matching: find.byType(RadioListTile<bool>),
        );
        final RadioGroup<bool> group = f.tester.widget<RadioGroup<bool>>(
          find.ancestor(of: tile, matching: find.byType(RadioGroup<bool>)),
        );
        return group.groupValue ==
            f.tester.widget<RadioListTile<bool>>(tile).value;
      }

      await f.check('Pregunta por el nombre y la nota, y nada más', () {
        expect(f.shows('NOMBRE'), isTrue);
        expect(f.shows('NOTA'), isTrue);
        expect(f.shows('CATEGORÍA'), isFalse);
        expect(chosen('Crepes & Waffles'), isTrue);
        expect(chosen('Con factura'), isTrue);
      });
      await f.tap('Crepes con Laura');
      await f.tap('Guardar');
      await f.step(
        'Con «Crepes con Laura» y «Guardar», el movimiento queda con el nombre '
        'del teléfono y la nota del computador; «Para revisar» se va y abajo '
        'dice «Combinado. Tus otros dispositivos lo reciben con el próximo '
        'archivo.»',
      );
      await f.check('Quedaron los dos cambios y nada espera', () async {
        expect(lunch().payee, 'Crepes con Laura');
        expect(lunch().note, 'Con factura');
        expect(f.shows('PARA REVISAR'), isFalse);
        expect(
          await _read(
            f,
            () => SyncService(_store(f), keys: SecureKeyStore()).conflicts(),
          ),
          isEmpty,
        );
      });
      await _waitMessages(f);
      await f.tap('Guardar mis cambios en un archivo');
      await f.step(
        'El cambio combinado viaja como cualquier otro: «Guardar mis cambios '
        'en un archivo» guarda quincena-2026-10-03.qsync para el computador.',
      );
      await f.check('El computador recibe el movimiento combinado, sin nada '
          'que revisar', () async {
        final SyncReport report = await _read(
          f,
          () => there.import(phone.saved['quincena-2026-10-03.qsync']!),
        );
        expect(report.conflicts, 0);
        final Entry theirs = (await _read(
          f,
          computer.entries,
        )).firstWhere((Entry e) => e.category == 'restaurants');
        expect(theirs.payee, 'Crepes con Laura');
        expect(theirs.note, 'Con factura');
      });
    },
  ),
];

/// The suggestions on the accounts step not added in 01-02: the chip, the
/// name it fills in and the kind it picks.
const List<(String, String, String)> _otherSuggestions =
    <(String, String, String)>[
      ('Nequi · COP', 'Nequi', 'Billetera digital'),
      ('Cuenta en dólares · USD', 'Cuenta en dólares', 'Banco'),
      ('Binance · USDT', 'Binance', 'Exchange de cripto'),
    ];

/// The fixed payments suggested on the last step and not added in 01-02.
const List<String> _otherFixed = <String>[
  'Administración',
  'Servicios',
  'Internet',
  'Plan del celular',
];

/// What the message at the bottom says now.
String _notice(FlowRun f) => <String>[
  for (final Element e
      in find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
          .evaluate())
    (e.widget as Text).data ?? '',
].join(' ');

/// The comparison in «Para revisar», by the field's name: what stayed,
/// what waits, and whether the row is marked as different.
Map<String, (String, String, bool)> _compared(FlowRun f) {
  final Table table = f.tester.widget<Table>(find.byType(Table).first);
  String text(Widget cell) =>
      cell is Padding ? (cell.child! as Text).data! : '';
  return <String, (String, String, bool)>{
    for (final TableRow row in table.children.skip(1))
      text(row.children[0]): (
        text(row.children[1]),
        text(row.children[2]),
        row.decoration != null,
      ),
  };
}

/// The amount and account a movement named [payee] shows, as the
/// comparison writes them.
String _rowAmount(FlowRun f, String payee) {
  final Entry e = _own(
    f,
  ).snapshot!.entries.firstWhere((Entry e) => e.payee == payee);
  final Account a = _own(f).snapshot!.account(e.accountId)!;
  return '${moneyText(Money(e.amount, a.asset), base: _own(f).profile!.base)}'
      ' · ${a.name}';
}

/// What «¿Restaurar este respaldo?» says [held] brings, line by line.
List<String> _holds(BackupContents held) {
  String count(int n, String none, String one, String many) =>
      n == 0 ? none : (n == 1 ? one : '$n $many');
  return <String>[
    count(held.accounts, 'Ninguna cuenta', 'Una cuenta', 'cuentas'),
    count(held.movements, 'Ningún movimiento', 'Un movimiento', 'movimientos'),
    count(held.goals, 'Ninguna meta', 'Una meta', 'metas'),
    count(
      held.plan,
      'Nada más del Plan',
      'Una cosa más del Plan',
      'cosas más del Plan',
    ),
  ];
}

/// The sync code this device keeps, if it syncs.
Future<String?> _syncCode(FlowRun f) =>
    _read(f, () => SyncService(_store(f), keys: SecureKeyStore()).code());

/// Another device: its store, with what [data] puts in it, and its sync,
/// with a key of its own. Its clock runs an hour ahead, so what it changes
/// is the later change. It closes after the flow.
Future<(QuincenaStore, SyncService)> _otherDevice(
  FlowRun f, {
  Future<QuincenaStore> Function()? data,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final DateTime later = screensNow.add(const Duration(hours: 1));
  final QuincenaStore store = await _read(f, () async {
    if (data != null) return data();
    final QuincenaStore empty = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => later,
    );
    await empty.ensureCategories();
    return empty;
  });
  addTearDown(() => f.tester.runAsync(store.close));
  return (store, SyncService(store, keys: MemoryKeyStore(), now: () => later));
}

/// The movements in a sealed backup, opened with [code] on a phone that
/// never had it; null when it does not open.
Future<List<Object?>?> _openBackup(FlowRun f, Uint8List file, String? code) =>
    _read(f, () async {
      final QuincenaStore elsewhere = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
      );
      try {
        final OpenedBackup opened = await Backups(
          elsewhere,
          keys: MemoryBackupKeyStore(),
        ).open(file, code: code);
        return opened.json['entries']! as List<Object?>;
      } on BackupException {
        return null;
      } finally {
        await elsewhere.close();
      }
    });

/// Lets the messages at the bottom go, as when the person reads them,
/// before something that says one of its own.
Future<void> _waitMessages(FlowRun f) async {
  for (var i = 0; i < 4 && find.byType(SnackBar).evaluate().isNotEmpty; i++) {
    await f.tester.pump(const Duration(seconds: 5));
    await settle(f.tester);
  }
}

/// A phone set up a moment ago with one account, Daviplata.
Future<QuincenaStore> _newPhone() async {
  final QuincenaStore store = QuincenaStore(
    QuincenaDatabase(NativeDatabase.memory()),
    now: () => screensNow,
  );
  await store.ensureCategories();
  await store.saveProfile(
    const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
  );
  await store.setSetting('app.mode', 'own');
  await store.addAccount(
    name: 'Daviplata',
    kind: AccountKind.wallet,
    asset: Asset.cop,
    opening: Decimal.parse('120000'),
    institution: 'Daviplata',
  );
  return store;
}

/// The seeded account with 2.400.000 coming each fortnight and a cushion
/// of 200.000, both in pesos, and the dollar at what the sources say today,
/// so the rate stays the same while the flow goes back and forth.
Future<QuincenaStore> _withCushionAndPay() async {
  final QuincenaStore store = await seeded();
  final Profile p = (await store.profile())!;
  await store.saveProfile(
    p.copyWith(pay: Decimal.parse('2400000'), cushion: Decimal.parse('200000')),
  );
  await store.saveRates(<Rate>[
    Rate(
      asset: 'USD',
      quote: 'COP',
      value: Decimal.parse('4000'),
      asOf: DateTime(2026, 10, 3),
      source: 'trm',
    ),
  ]);
  return store;
}

/// The person leaves the app, as for the phone's settings, and comes back.
Future<void> _awayAndBack(FlowRun f) async {
  for (final AppLifecycleState state in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    f.tester.binding.handleAppLifecycleStateChanged(state);
  }
  await settle(f.tester);
}

/// The app as built now: its theme and language.
MaterialApp _app(FlowRun f) =>
    f.tester.widget<MaterialApp>(find.byType(MaterialApp).first);

/// Whether the screen is drawn light or dark.
Brightness _brightness(FlowRun f) =>
    Theme.of(f.tester.element(find.byType(Scaffold).last)).brightness;

/// The sample's conversation.
Session _session(FlowRun f) =>
    f.tester.widget<HomePage>(find.byType(HomePage)).session;

/// Scrolls [finder] near the top of the screen, for a picture that starts
/// with it.
Future<void> _near(FlowRun f, Finder finder) async {
  await f.reveal(finder);
  await Scrollable.ensureVisible(f.tester.element(finder.last), alignment: 0.1);
  await settle(f.tester);
}

/// What Ajustes lists, top to bottom, built or not yet.
List<Widget> _settingsRows(FlowRun f) =>
    (f.tester
                .widget<ListView>(
                  find.descendant(
                    of: find.byType(OwnSettingsPage),
                    matching: find.byType(ListView),
                  ),
                )
                .childrenDelegate
            as SliverChildListDelegate)
        .children;

/// The titles of Ajustes' sections, in order.
List<String> _sections(FlowRun f) => <String>[
  for (final Widget w in _settingsRows(f))
    if (w is SectionLabel) w.text,
];

/// The person's accounts, also from a page pushed over them.
OwnController _own(FlowRun f) =>
    f.tester.widget<OwnShell>(find.byType(OwnShell, skipOffstage: false)).own;

/// The store the app runs on, whatever it is showing.
QuincenaStore _store(FlowRun f) =>
    f.tester.widget<QuincenaApp>(find.byType(QuincenaApp)).store!;

/// What [read] answers, read outside the test's fake clock as the
/// database needs.
Future<T> _read<T>(FlowRun f, Future<T> Function() read) async =>
    (await f.tester.runAsync(read)) as T;

/// Through the first two steps with [name], twice a month and no pay
/// amount, to the step that adds accounts.
Future<void> _toAccountsStep(FlowRun f, String name) async {
  await f.tap('Con mis cuentas');
  await f.type('Tu nombre', name);
  await f.tap('Siguiente');
  await f.tap('Siguiente');
}

/// Whether the switch in the row titled [title] is on.
bool _switchOf(FlowRun f, String title) => f.tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
    .value;

/// Opens the app again on the same data, as after closing it.
Future<void> _reopen(FlowRun f) async {
  final QuincenaStore store = _store(f);
  await f.tester.pumpWidget(const SizedBox());
  await settle(f.tester);
  await f.tester.pumpWidget(
    QuincenaApp(
      store: store,
      startInDemo: f.flow.demo,
      fetcher: fakeRates(),
      now: () => screensNow,
      market: ExampleMarket(now: () => screensNow),
    ),
  );
  await settle(f.tester);
}

/// The full account, with rules learned from what was confirmed and an app
/// whose notifications are no longer read.
Future<QuincenaStore> _withRules() async {
  final QuincenaStore store = await fullAccount();
  final List<Account> accounts = await store.accounts();
  String id(String name) =>
      accounts.firstWhere((Account a) => a.name == name).id;
  final CaptureSettings s = await store.captureSettings();
  await store.saveCaptureSettings(
    s.copyWith(
      merchantCategories: <String, String>{
        ...s.merchantCategories,
        'exito laureles': 'groceries',
        'rappi': 'restaurants',
      },
      cardAccounts: <String, String>{
        ...s.cardAccounts,
        '1234': id('Bancolombia'),
      },
      institutionAccounts: <String, String>{
        ...s.institutionAccounts,
        'Nequi': id('Nequi'),
      },
      mutedApps: <String>{'com.grability.rappi'},
      appNames: <String, String>{'com.grability.rappi': 'Rappi'},
    ),
  );
  return store;
}

/// What happens outside the app, played inside it: files saved and picked,
/// links opened, notifications allowed or not, the clipboard, the widget on
/// the home screen and a screenshot read. Set up for one flow and taken
/// away after it.
class _Phone {
  _Phone._();

  /// The files saved, by name.
  final Map<String, Uint8List> saved = <String, Uint8List>{};

  /// Whether the next saves are closed without saving.
  bool cancelSave = false;

  /// What the next pickers answer, in order; null is a picker closed
  /// without choosing.
  final List<Uint8List?> toPick = <Uint8List?>[];

  /// What each picker was opened for: 'image', 'any', or the extensions
  /// it allowed, as 'pdf'.
  final List<String> asked = <String>[];

  /// The links opened.
  final List<String> opened = <String>[];

  /// Whether the phone lets the app notify.
  bool notifications = true;

  /// The reminders the app last asked the phone to keep.
  List<Map<Object?, Object?>> reminders = <Map<Object?, Object?>>[];

  /// The last figure sent to the widget.
  Map<Object?, Object?>? widget;

  /// Every time the app wrote to the widget: 'show' or 'clear'.
  final List<String> widgetCalls = <String>[];

  String? clipboard;

  /// What reached the share sheet, which opens.
  final List<String> shared = <String>[];

  /// What a screenshot reads as.
  String? screenshotText;

  /// What the app asked of Android: 'pin', 'location', 'always',
  /// 'openNotificationAccess', 'openAppSettings'.
  final List<String> asks = <String>[];

  /// Whether the launcher adds the widget when asked.
  bool pins = true;

  /// Whether Android lets the app read notifications.
  bool notificationAccess = false;

  /// The location the app may use: 'none', 'foreground' or 'always', and
  /// what Android answers when asked for it while in use and all the time.
  String location = 'none';
  String locationAnswer = 'foreground';
  String alwaysAnswer = 'always';

  static const MethodChannel _reminders = MethodChannel(
    'dev.dlsoft.quincena/reminders',
  );
  static const MethodChannel _widget = MethodChannel(
    'dev.dlsoft.quincena/widget',
  );
  static const MethodChannel _capture = MethodChannel(
    'dev.dlsoft.quincena/capture',
  );
  static const MethodChannel _share = MethodChannel(
    'dev.dlsoft.quincena/share',
  );

  static Future<_Phone> install(FlowRun f) async {
    final _Phone phone = _Phone._();
    final FilePickerPlatform picker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _Picker(phone);
    addTearDown(() => FilePickerPlatform.instance = picker);
    final UrlLauncherPlatform links = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _Links(phone);
    addTearDown(() => UrlLauncherPlatform.instance = links);
    final TestDefaultBinaryMessenger messenger =
        f.tester.binding.defaultBinaryMessenger;
    void answer(
      MethodChannel channel,
      Object? Function(MethodCall call) reply,
    ) {
      messenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async => reply(call),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    answer(_reminders, (MethodCall call) {
      switch (call.method) {
        case 'ask':
          return phone.notifications;
        case 'schedule':
          phone.reminders = <Map<Object?, Object?>>[
            for (final Object? item
                in (call.arguments as Map<Object?, Object?>)['items']!
                    as List<Object?>)
              item! as Map<Object?, Object?>,
          ];
        case 'cancel':
          phone.reminders = <Map<Object?, Object?>>[];
      }
      return null;
    });
    answer(_widget, (MethodCall call) {
      if (call.method == 'show' || call.method == 'clear') {
        phone.widgetCalls.add(call.method);
      }
      if (call.method == 'show') {
        phone.widget = call.arguments as Map<Object?, Object?>?;
      }
      if (call.method == 'clear') phone.widget = null;
      if (call.method == 'pin') {
        phone.asks.add('pin');
        return phone.pins;
      }
      return null;
    });
    answer(_capture, (MethodCall call) {
      switch (call.method) {
        case 'readText':
          return phone.screenshotText;
        case 'takeOpenInbox':
          return false;
        case 'notificationAccess':
          return phone.notificationAccess;
        case 'locationAccess':
          return phone.location;
        case 'askForLocation':
          phone.asks.add('location');
          return phone.location = phone.locationAnswer;
        case 'askForBackgroundLocation':
          phone.asks.add('always');
          return phone.location = phone.alwaysAnswer;
        case 'openNotificationAccess' || 'openAppSettings':
          phone.asks.add(call.method);
      }
      return null;
    });
    answer(_share, (MethodCall call) {
      if (call.method == 'text') phone.shared.add('${call.arguments}');
      return true;
    });
    answer(SystemChannels.platform, (MethodCall call) {
      if (call.method == 'Clipboard.setData') {
        phone.clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      // Nothing copied reads as nothing, as on a phone.
      if (call.method == 'Clipboard.getData') {
        return phone.clipboard == null
            ? null
            : <String, Object?>{'text': phone.clipboard};
      }
      return null;
    });
    return phone;
  }

  /// The days the payday reminder is set for.
  List<DateTime> scheduledClose() => <DateTime>[
    for (final Map<Object?, Object?> r in reminders)
      if (r['title'] == 'Tu cierre de quincena está listo')
        DateTime.fromMillisecondsSinceEpoch(r['at']! as int),
  ];

  /// What every reminder set says.
  List<String> scheduledTexts() => <String>[
    for (final Map<Object?, Object?> r in reminders)
      '${r['title']} ${r['body']}',
  ];
}

class _Picker extends FilePickerPlatform {
  _Picker(this.phone);

  final _Phone phone;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (phone.cancelSave) return null;
    phone.saved[fileName] = bytes;
    return Uri.file('/Archivos/$fileName');
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    phone.asked.add(
      type == FileType.custom
          ? (allowedExtensions ?? <String>[]).join(',')
          : type.name,
    );
    final Uint8List? bytes = phone.toPick.isEmpty
        ? null
        : phone.toPick.removeAt(0);
    return bytes == null
        ? const <PlatformFile>[]
        : <PlatformFile>[_Picked(bytes)];
  }
}

final class _Picked extends PlatformFile {
  _Picked(this.bytes);

  final Uint8List bytes;

  @override
  String get name => 'archivo';

  @override
  Uri get uri => Uri.file('/Archivos/archivo');

  @override
  XFile get xFile => XFile.fromData(bytes, name: name);

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(bytes);
}

class _Links extends UrlLauncherPlatform {
  _Links(this.phone);

  final _Phone phone;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    phone.opened.add(url);
    return true;
  }
}
