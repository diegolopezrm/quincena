// Flows of Primeros pasos (01), Ajustes (09), Varios dispositivos y respaldo (10).
// The picker hands over files as cross_file's, and its fake must too.
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/own_shell.dart';
// Links open through it; the fake keeps the app on screen.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../test/own_flow_test.dart' show fakeRates, settle;
import '../../test_screens/accounts.dart' show screensNow, seeded;
import '../../test_screens/store_screens_test.dart' show ExampleMarket;
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
        'Abajo dice que las cuentas se guardan solo en el teléfono.',
      );
      await f.tap('Con datos de ejemplo');
      await f.step(
        'Toca «Con datos de ejemplo»: abre la cuenta de Valentina, con un '
        'aviso arriba de que no es la tuya y el botón «Usar con mis cuentas».',
      );
      await f.check('La app recuerda que se eligió el ejemplo', () async {
        expect(await _read(f, () => _store(f).setting('app.mode')), 'demo');
      });
      await f.tap('Usar con mis cuentas');
      await f.step(
        'Toca «Usar con mis cuentas»: empieza la configuración, «Paso 1 de '
        '4», con la pregunta por tu nombre.',
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
      await f.tap('ACEPTAR');
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
        'debes en la tarjeta hasta el 15 de octubre, sin «Provisional».',
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
      await f.tap('ACEPTAR');
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
      await f.back();
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
        'Ajustes: perfil, avisos, widget, captura automática, apariencia, '
        'tus datos y privacidad, en ese orden.',
        most: 7,
      );
      await f.tap('Billeteras propias');
      await f.step(
        '«Billeteras propias» abre la página para seguir Ledger, MetaMask o '
        'Trust Wallet por su dirección pública.',
      );
      await f.check('Abrió Billeteras propias', () {
        expect(f.shows('Agregar billetera'), isTrue);
      });
      await f.back();
      await f.tap('Binance');
      await f.step(
        '«Binance» abre la conexión con una llave de solo lectura: Quincena '
        'nunca podrá mover tus fondos.',
      );
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
      await f.tester.enterText(find.byType(TextField), 'Diego Alejandro');
      await f.step(
        '«Nombre» abre un cuadro con el nombre actual. Se escribe «Diego '
        'Alejandro».',
      );
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» el nombre sigue siendo Diego', () {
        expect(_own(f).profile!.name, 'Diego');
      });
      await f.tap('Nombre');
      await f.tester.enterText(find.byType(TextField), 'Diego Alejandro');
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
      await f.tester.enterText(find.byType(TextField), '0');
      await f.step(
        '«Lo que te pagan» explica para qué sirve. Se escribe 0, que no es '
        'un monto válido.',
      );
      await f.tap('Guardar');
      await f.step(
        'Con 0 y «Guardar» el cuadro se cierra sin guardar y sin decir por '
        'qué: la fila sigue «Sin definir».',
      );
      await f.check('Un 0 no se guarda', () {
        expect(_own(f).profile!.pay, isNull);
      });
      await f.tap('Lo que te pagan');
      await f.tester.enterText(find.byType(TextField), '4800000');
      await f.tap('Cancelar');
      await f.check('Con «Cancelar» no cambia nada', () {
        expect(_own(f).profile!.pay, isNull);
      });
      await f.tap('Lo que te pagan');
      await f.tester.enterText(find.byType(TextField), '4800000');
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
      await f.tester.enterText(find.byType(TextField), '200000');
      await f.step(
        '«Colchón» explica que no cuenta en lo que puedes gastar. Se escribe '
        '200.000.',
      );
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
        'Si el teléfono no deja notificar, el interruptor sigue apagado y '
        'abajo explica que hay que permitirlas en los ajustes del teléfono.',
      );
      await f.check('Sin permiso no queda encendido', () {
        expect(_own(f).remindsClose, isFalse);
      });
      phone.notifications = true;
      phone.reminders.clear();
      await f.tap('Avisarme el día de pago');
      await f.step(
        'Con permiso, «Avisarme el día de pago» queda encendido: un aviso sin '
        'montos para ver el cierre de la quincena.',
      );
      await f.check(
        'Quedan avisos a las 9 a. m. del 15 y el 30 de octubre',
        () {
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
      'En Android, «Agregar a la pantalla de inicio» desde Ajustes.',
    ],
    (FlowRun f) async {
      final _Phone phone = await _Phone.install(f);
      final String free = pesos(_own(f).ledger!.freeUntilPayday);
      // The widget gets the figure again whenever it changes.
      await f.tapTip('Ajustes');
      await f.reveal(find.text('Ocultar montos en el widget'));
      await f.step(
        '«Widget de inicio» explica cómo agregarlo desde la pantalla de '
        'inicio. «Ocultar montos en el widget» está apagado.',
      );
      await f.tap('Ocultar montos en el widget');
      await f.step('Encendido: el widget dice hasta cuándo, sin la cifra.');
      await f.check('El widget recibe «••••••» en vez de la cifra', () {
        expect(_own(f).widgetHidesAmounts, isTrue);
        expect(phone.widget?['amount'], '••••••');
      });
      await f.tap('Ocultar montos en el widget');
      await f.check('Apagado, el widget vuelve a mostrar $free', () {
        expect(_own(f).widgetHidesAmounts, isFalse);
        expect(phone.widget?['amount'], free);
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
      market: ExampleMarket(),
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

  /// What the next pickers answer, in order; null is a picker closed
  /// without choosing.
  final List<Uint8List?> toPick = <Uint8List?>[];

  /// The links opened.
  final List<String> opened = <String>[];

  /// Whether the phone lets the app notify.
  bool notifications = true;

  /// The reminders the app last asked the phone to keep.
  List<Map<Object?, Object?>> reminders = <Map<Object?, Object?>>[];

  /// The last figure sent to the widget.
  Map<Object?, Object?>? widget;

  String? clipboard;

  /// What a screenshot reads as.
  String? screenshotText;

  static const MethodChannel _reminders = MethodChannel(
    'dev.dlsoft.quincena/reminders',
  );
  static const MethodChannel _widget = MethodChannel(
    'dev.dlsoft.quincena/widget',
  );
  static const MethodChannel _capture = MethodChannel(
    'dev.dlsoft.quincena/capture',
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
      if (call.method == 'show') {
        phone.widget = call.arguments as Map<Object?, Object?>?;
      }
      if (call.method == 'clear') phone.widget = null;
      return null;
    });
    answer(_capture, (MethodCall call) {
      if (call.method == 'readText') return phone.screenshotText;
      if (call.method == 'takeOpenInbox') return false;
      return null;
    });
    answer(SystemChannels.platform, (MethodCall call) {
      if (call.method == 'Clipboard.setData') {
        phone.clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': phone.clipboard};
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
