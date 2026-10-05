// Flows of Por revisar y captura (07), Importar extracto (08).
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/inbox_page.dart';

import '../../test/own_flow_test.dart' show settle;
import '../../test_screens/accounts.dart';
import '../tour.dart';
import 'flow.dart';

final List<AppFlow> porRevisarFlows = <AppFlow>[
  AppFlow(
    '07-01-ver-lo-que-espera',
    'Ver qué está esperando y por qué',
    area: 'Por revisar',
    goal:
        'Me llegaron varias alertas del banco y quiero saber cuáles puedo '
        'registrar ya y qué le falta a cada una.',
    data: _everyKind,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int waiting = own.pendingInbox.length;
      await f.step(
        'Inicio: en «Por hacer» aparece «Revisa $waiting movimientos para '
        'actualizar tu saldo», y la bandeja de arriba lleva un $waiting.',
      );
      await f.check(
        'La bandeja y el aviso cuentan los $waiting que esperan',
        () {
          expect(waiting, 5);
          expect(f.shows('$waiting'), isTrue);
          expect(
            f.screenText,
            contains('Revisa $waiting movimientos para actualizar tu saldo'),
          );
        },
      );
      await f.check('Lo que espera todavía no es un movimiento', () {
        final Set<String> refs = <String>{
          for (final InboxItem i in own.inbox) i.id,
        };
        expect(
          own.snapshot!.entries.where((Entry e) => refs.contains(e.sourceRef)),
          isEmpty,
        );
      });
      await f.tap('Revisar');
      await f.page(
        'Por revisar: arriba lo que se registra de un toque, después lo que '
        'necesita algo de ti y al final el posible repetido.',
      );
      await f.check('Listos: Rappi y Laura Gómez, cada uno con su cuenta', () {
        final List<String> ready = <String>[
          for (final InboxItem i in own.pendingInbox)
            if (CaptureService.isReady(i, own.accounts)) _payee(i),
        ];
        expect(ready, unorderedEquals(<String>['Laura Gómez', 'Rappi']));
      });
      await f.check(
        'Necesitan información: Éxito Laureles, Falabella y Claro, sin cuenta',
        () {
          final List<InboxItem> needs = <InboxItem>[
            for (final InboxItem i in own.pendingInbox)
              if (!CaptureService.isReady(i, own.accounts)) i,
          ];
          expect(
            needs.map(_payee),
            unorderedEquals(<String>['Éxito Laureles', 'Claro', 'Falabella']),
          );
          expect(
            needs.every((InboxItem i) => i.suggestion.accountId == null),
            isTrue,
          );
        },
      );
      await f.check('Cada uno dice por qué le falta la cuenta', () {
        final String text = f.screenText;
        expect(
          text,
          contains(
            'Detectamos Bancolombia y la tarjeta *1234, pero falta asociarla',
          ),
        );
        expect(
          text,
          contains('Detectamos Bancolombia, pero tienes dos cuentas ahí'),
        );
        expect(
          text,
          contains('Detectamos Davivienda, pero no tienes una cuenta'),
        );
      });
      await f.check('El repetido apunta al Spotify que ya estaba anotado', () {
        final InboxItem spotify = own.inbox.firstWhere(
          (InboxItem i) => i.status == InboxStatus.duplicate,
        );
        final Entry twin = own.snapshot!.entries.firstWhere(
          (Entry e) => e.id == spotify.duplicateOf,
        );
        expect(twin.payee, 'Spotify');
        expect(twin.source, 'manual');
      });
      await _openMenu(f, 'Éxito Laureles');
      await f.step(
        'El menú «⋮» de la compra en Éxito Laureles: «Detalles de detección», '
        '«Descartar» y «Descartar y no leer más Bancolombia».',
      );
      await f.tap('Detalles de detección');
      await f.reveal(_card('Éxito Laureles'));
      await f.step(
        'Los detalles dicen cómo llegó (notificación de Bancolombia), por qué '
        'sugiere Éxito Laureles (un comercio a 6 m) y el mensaje tal cual.',
      );
      await f.check('Los detalles citan la notificación del banco', () {
        expect(f.shows('Cómo llegó'), isTrue);
        expect(f.shows('Por qué lo sugerimos'), isTrue);
        expect(
          find.textContaining('Compra por \$63.200 POS 4512'),
          findsOneWidget,
        );
      });
      await _openMenu(f, 'Éxito Laureles');
      await f.tap('Ocultar detalles');
      await f.step(
        'Con «Ocultar detalles» la tarjeta vuelve a ser corta: lo que decide '
        'está a la vista y el resto espera en el menú.',
      );
      await f.check('Los detalles se cerraron', () {
        expect(f.shows('Cómo llegó'), isFalse);
      });
    },
  ),
  AppFlow(
    '07-02-registrar-un-ingreso-y-deshacer',
    'Registrar un ingreso de un toque y deshacerlo',
    area: 'Por revisar',
    goal:
        'Laura me pasó plata por Nequi: quiero registrarla sin escribir nada, '
        'y poder echarme para atrás si me equivoco.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account nequi = _account(own, 'Nequi');
      final Decimal before = own.balances[nequi.id]!.amount;
      final InboxItem laura = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Laura Gómez',
      );
      final int rules = own.captureSettings.rules.length;
      await f.step(
        'Inicio: «Puedes gastar» todavía no cuenta lo que llegó a Nequi; la '
        'bandeja de arriba dice que hay 2 por revisar.',
      );
      await f.tapTip('Por revisar');
      await f.step(
        'Por revisar: Laura Gómez te envió \$85.000; la tarjeta ya trae Nequi '
        'y está en «Listos para registrar».',
      );
      await _tapOn(f, 'Laura Gómez', 'Registrar ingreso');
      await f.step(
        'Con «Registrar ingreso» la tarjeta se va; el aviso de abajo dice '
        'dónde quedó, qué aprendió la app y ofrece «Deshacer».',
      );
      await f.check('Quedó un ingreso de \$85.000 en Nequi', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.sourceRef == laura.id,
        );
        expect(e.accountId, nequi.id);
        expect(e.amount, Decimal.parse('85000'));
        expect(e.category, 'other_income');
        expect(e.payee, 'Laura Gómez');
      });
      await f.check('El saldo de Nequi subió exactamente \$85.000', () {
        expect(own.balances[nequi.id]!.amount, before + Decimal.parse('85000'));
      });
      final String up = _cop(own, free + own.ledger!.minor(85000));
      await f.check('Lo que puedes gastar subió a $up', () {
        expect(own.ledger!.freeUntilPayday, free + own.ledger!.minor(85000));
      });
      await f.check(
        'Aprendió dos reglas: Laura Gómez y las alertas de Nequi',
        () {
          final CaptureSettings s = own.captureSettings;
          expect(s.merchantCategories['laura gomez'], 'other_income');
          expect(s.institutionAccounts['Nequi'], nequi.id);
          expect(s.rules.length, rules + 2);
        },
      );
      await _undoFromNotice(f);
      await f.step(
        'Con «Deshacer» del aviso el ingreso se borra y Laura Gómez vuelve a '
        '«Listos para registrar», como si nada.',
      );
      await f.check('El ingreso ya no está y la captura espera otra vez', () {
        expect(
          own.snapshot!.entries.where((Entry e) => e.sourceRef == laura.id),
          isEmpty,
        );
        expect(own.pendingInbox.map((InboxItem i) => i.id), contains(laura.id));
      });
      await f.check('Las dos reglas que aprendió también se deshicieron', () {
        final CaptureSettings s = own.captureSettings;
        expect(s.merchantCategories.containsKey('laura gomez'), isFalse);
        expect(s.institutionAccounts.containsKey('Nequi'), isFalse);
        expect(s.rules.length, rules);
      });
      await f.back();
      await f.step(
        'De vuelta en Inicio, «Puedes gastar» y Nequi quedaron como al '
        'principio.',
      );
      await f.check('Lo que puedes gastar volvió a ${_cop(own, free)}', () {
        expect(own.ledger!.freeUntilPayday, free);
        expect(own.balances[nequi.id]!.amount, before);
      });
    },
  ),
  AppFlow(
    '07-03-elegir-la-cuenta-de-una-compra',
    'Decir de qué cuenta salió una compra',
    area: 'Por revisar',
    goal:
        'Pagué en el Éxito con la débito y la app no sabe de qué cuenta '
        'salió: quiero decírselo una vez y que la próxima lo sepa sola.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account bank = _account(own, 'Bancolombia');
      final InboxItem exito = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Éxito Laureles',
      );
      await f.tapTip('Por revisar');
      await f.step(
        'La compra en Éxito Laureles dice «Falta la cuenta»: Bancolombia '
        'avisó con la tarjeta *1234, que aún no es de ninguna cuenta.',
      );
      await _tapOn(f, 'Éxito Laureles', 'Elegir la cuenta');
      await f.step(
        '«Elegir la cuenta» abre «¿De qué cuenta salió?», con las de '
        'Bancolombia primero, y avisa que la tarjeta *1234 irá directo la '
        'próxima vez.',
      );
      await f.check('La hoja avisa lo que va a aprender', () {
        expect(
          f.shows(
            'La próxima vez, lo de la tarjeta *1234 irá directo a esa cuenta.',
          ),
          isTrue,
        );
      });
      await f.back();
      await f.step(
        'Cerrar la hoja sin elegir no registra nada: la compra sigue '
        'esperando en «Necesitan información».',
      );
      await f.check('Sin elegir, nada cambió', () {
        expect(own.pendingInbox.map((InboxItem i) => i.id), contains(exito.id));
        expect(
          own.snapshot!.entries.where((Entry e) => e.sourceRef == exito.id),
          isEmpty,
        );
      });
      await _tapOn(f, 'Éxito Laureles', 'Elegir la cuenta');
      await f.tap('Bancolombia');
      await f.step(
        'Elegida Bancolombia, el aviso dice «Gasto registrado en Bancolombia» '
        'y lo que aprendió del comercio, con una regla más.',
      );
      await f.check(
        'Quedó un gasto de \$63.200 en Bancolombia, en Mercado',
        () {
          final Entry e = own.snapshot!.entries.firstWhere(
            (Entry e) => e.sourceRef == exito.id,
          );
          expect(e.accountId, bank.id);
          expect(e.amount, Decimal.parse('-63200'));
          expect(e.category, 'groceries');
          expect(e.payee, 'Éxito Laureles');
        },
      );
      await f.check('La tarjeta *1234 quedó como de Bancolombia', () {
        expect(own.captureSettings.cardAccounts['1234'], bank.id);
        expect(
          own.captureSettings.merchantCategories['exito laureles'],
          'groceries',
        );
      });
      final String down = _cop(own, free - own.ledger!.minor(63200));
      await f.check('Lo que puedes gastar bajó a $down', () {
        expect(own.ledger!.freeUntilPayday, free - own.ledger!.minor(63200));
      });
      await _hideNotice(f);
      await _paste(
        f,
        r'Bancolombia le informa Compra por $25.000 en Carulla con T.Deb *1234',
      );
      await f.step(
        'Otra compra con la tarjeta *1234, pegada con «Leer un pago», llega '
        'en «Listos para registrar» ya con Bancolombia.',
      );
      await f.check('La compra nueva trae Bancolombia por la tarjeta', () {
        final InboxItem carulla = own.pendingInbox.firstWhere(
          (InboxItem i) => _payee(i) == 'Carulla',
        );
        expect(carulla.suggestion.accountId, bank.id);
        expect(carulla.suggestion.why, contains('card'));
        expect(CaptureService.isReady(carulla, own.accounts), isTrue);
      });
      await _hideNotice(f);
      await _openMenu(f, 'Carulla');
      await f.tap('Detalles de detección');
      await f.reveal(_card('Carulla'));
      await f.step(
        'En sus detalles, «Por qué lo sugerimos» dice que la tarjeta *1234 es '
        'de Bancolombia: lo que aprendió hace un momento.',
      );
      await f.check('El porqué cita la regla de la tarjeta', () {
        expect(f.shows('La tarjeta *1234 es de Bancolombia.'), isTrue);
      });
      await f.back();
      await f.step(
        'Inicio: con los \$63.200 de Éxito Laureles, ${_figure(own, free)} '
        'pasó a ${_figure(own, own.ledger!.freeUntilPayday)}; Carulla no '
        'cuenta hasta registrarla.',
      );
    },
  ),
  AppFlow(
    '07-04-plata-de-otra-cuenta-mia',
    'Registrar plata que me pasé de otra cuenta mía',
    area: 'Por revisar',
    goal:
        'Me pasé plata de Bancolombia a Nequi y Nequi me avisó que la '
        'recibí: no es un ingreso, es la misma plata cambiando de bolsillo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account bank = _account(own, 'Bancolombia');
      final Account nequi = _account(own, 'Nequi');
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      final Decimal nequiBefore = own.balances[nequi.id]!.amount;
      final int rules = own.captureSettings.rules.length;
      await f.tapTip('Por revisar');
      await _paste(f, r'Nequi: Recibiste $200.000 de Diego Lopez');
      await f.step(
        'El aviso de Nequi, pegado con «Leer un pago», quedó como ingreso de '
        '\$200.000 con «¿Viene de otra cuenta tuya?» debajo.',
      );
      await _hideNotice(f);
      await _tapOn(f, 'Diego Lopez', '¿Viene de otra cuenta tuya?');
      await f.step(
        'La hoja abre como «Transferencia»: Nequi va en «Hacia» y en «Desde» '
        'propone Bancolombia. El botón dice «Registrar transferencia».',
      );
      await f.check('La hoja propone Bancolombia → Nequi', () {
        expect(f.shows('Transferencia'), isTrue);
        expect(f.shows('Registrar transferencia'), isTrue);
      });
      await f.tap('Registrar transferencia');
      await f.step(
        'Registrada: el aviso dice «Transferencia registrada.» y la tarjeta '
        'salió de Por revisar.',
      );
      await f.check('Salieron \$200.000 de Bancolombia y llegaron a Nequi', () {
        expect(
          own.balances[bank.id]!.amount,
          bankBefore - Decimal.parse('200000'),
        );
        expect(
          own.balances[nequi.id]!.amount,
          nequiBefore + Decimal.parse('200000'),
        );
        final List<Entry> legs = <Entry>[
          for (final Entry e in own.snapshot!.entries)
            if (e.transferId != null &&
                e.amount.abs() == Decimal.parse('200000'))
              e,
        ];
        expect(legs, hasLength(2));
      });
      await f.check(
        'No cuenta como ingreso: lo que puedes gastar no cambió',
        () {
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      await f.check('Una transferencia no enseña reglas', () {
        expect(own.captureSettings.rules.length, rules);
      });
      await _hideNotice(f);
      await f.back();
      await f.step(
        'Inicio: ${_figure(own, free)}, igual que antes: pasar plata entre '
        'tus cuentas no es gastar ni ganar.',
      );
    },
  ),
  AppFlow(
    '07-05-quitar-un-repetido',
    'Quitar un pago que llegó dos veces',
    area: 'Por revisar',
    goal:
        'El cobro de Spotify me llegó por SMS pero yo ya lo había anotado: '
        'quiero quitar el repetido sin que se cuente dos veces.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account dollars = _account(own, 'Cuenta en dólares');
      final Decimal before = own.balances[dollars.id]!.amount;
      final int entries = own.snapshot!.entries.length;
      final InboxItem spotify = own.inbox.firstWhere(
        (InboxItem i) => i.status == InboxStatus.duplicate,
      );
      await f.tapTip('Por revisar');
      await f.reveal(_card('Spotify'));
      await f.step(
        'En «Posibles repetidos», Spotify por US\$10,99 dice «El mismo pago ya '
        'llegó por otra vía.»: el otro lo anotaste a mano, pero no dice cuál.',
      );
      await _openMenu(f, 'Spotify');
      await f.step(
        'Su menú «⋮» tiene «Detalles de detección» y «Descartar»: un SMS no '
        'viene de una app, así que no ofrece dejar de leerla.',
      );
      await f.check('El menú no ofrece silenciar un SMS', () {
        expect(f.shows('Descartar'), isTrue);
        expect(find.textContaining('no leer más'), findsNothing);
      });
      await f.tap('Detalles de detección');
      await f.reveal(_card('Spotify'));
      await f.step(
        'Los detalles: llegó por SMS de Bancolombia el 2 de octubre y el '
        'mensaje dice «Compra por US\$10,99 en SPOTIFY».',
      );
      await f.check('Los detalles dicen que llegó por SMS', () {
        expect(find.textContaining('SMS · Bancolombia'), findsOneWidget);
      });
      await _openMenu(f, 'Spotify');
      await f.tap('Descartar');
      await f.step(
        'Con «Descartar» el repetido sale de la lista y no se anota nada '
        'nuevo.',
      );
      await f.check('La captura quedó descartada', () async {
        final List<InboxItem> all = (await f.tester.runAsync(
          () => own.store.inbox(),
        ))!;
        expect(
          all.firstWhere((InboxItem i) => i.id == spotify.id).status,
          InboxStatus.dismissed,
        );
        expect(
          own.inbox.map((InboxItem i) => i.id),
          isNot(contains(spotify.id)),
        );
      });
      await f.check(
        'La cuenta en dólares no cambió y no hay movimiento nuevo',
        () {
          expect(own.balances[dollars.id]!.amount, before);
          expect(own.snapshot!.entries.length, entries);
        },
      );
    },
  ),
  AppFlow(
    '07-06-no-es-repetido',
    'Registrar un pago que parecía repetido',
    area: 'Por revisar',
    goal:
        'Tengo dos cuentas de Spotify y la app cree que el segundo cobro es '
        'un repetido: quiero decirle que no y registrarlo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account dollars = _account(own, 'Cuenta en dólares');
      final Decimal before = own.balances[dollars.id]!.amount;
      final int charges = own.snapshot!.entries
          .where((Entry e) => e.payee == 'Spotify')
          .length;
      final InboxItem spotify = own.inbox.firstWhere(
        (InboxItem i) => i.status == InboxStatus.duplicate,
      );
      await f.tapTip('Por revisar');
      await f.reveal(_card('Spotify'));
      await f.step(
        'Spotify espera en «Posibles repetidos» con un solo botón a la vista: '
        '«No es repetido».',
      );
      await _tapOn(f, 'Spotify', 'No es repetido');
      await f.top();
      await f.step(
        'Con «No es repetido» pasa a «Listos para registrar», con la Cuenta en '
        'dólares, la única en dólares, y «Registrar gasto».',
      );
      await f.check('Volvió a esperar, con la cuenta en dólares', () {
        final InboxItem now = own.inbox.firstWhere(
          (InboxItem i) => i.id == spotify.id,
        );
        expect(now.status, InboxStatus.pending);
        expect(now.suggestion.accountId, dollars.id);
        expect(CaptureService.isReady(now, own.accounts), isTrue);
      });
      await _tapOn(f, 'Spotify', 'Registrar gasto');
      await f.step(
        'Registrado: el aviso dice «Gasto registrado en Cuenta en dólares» y '
        'que desde ahora Spotify va a Suscripciones.',
      );
      await f.check('La cuenta en dólares bajó US\$10,99', () {
        expect(
          own.balances[dollars.id]!.amount,
          before - Decimal.parse('10.99'),
        );
        expect(
          own.snapshot!.entries.where((Entry e) => e.payee == 'Spotify').length,
          charges + 1,
        );
      });
      await f.check('Spotify quedó como regla de Suscripciones', () {
        expect(
          own.captureSettings.merchantCategories['spotify'],
          'subscriptions',
        );
      });
      await f.check('Un cobro en dólares no manda lo de Bancolombia ahí', () {
        expect(own.captureSettings.institutionAccounts, isEmpty);
      });
      await _hideNotice(f);
      await _paste(f, r'Bancolombia le informa Pago por $89.900 a Claro');
      await f.step(
        'Un pago en pesos de Bancolombia, pegado después, sigue pidiendo la '
        'cuenta: el cobro en dólares no la decidió por él.',
      );
      await f.check('El pago en pesos no va a la cuenta en dólares', () {
        final InboxItem claro = own.pendingInbox.firstWhere(
          (InboxItem i) => _payee(i) == 'Claro',
        );
        expect(claro.suggestion.accountId, isNot(dollars.id));
      });
    },
  ),
  AppFlow(
    '07-07-descartar-y-dejar-de-leer',
    'Descartar lo que no es y dejar de leer una app',
    area: 'Por revisar',
    goal:
        'Hay alertas que no quiero registrar, y una app que me llena la '
        'bandeja: quiero quitarlas y luego poder volver a leerla.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int entries = own.snapshot!.entries.length;
      final InboxItem laura = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Laura Gómez',
      );
      final InboxItem exito = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Éxito Laureles',
      );
      await f.tapTip('Por revisar');
      await _openMenu(f, 'Laura Gómez');
      await f.step(
        'El menú «⋮» de Laura Gómez: «Detalles de detección», «Descartar» y '
        '«Descartar y no leer más Nequi».',
      );
      await f.tap('Descartar');
      await f.step(
        'Con «Descartar» la tarjeta se va sin registrar nada y sin pedir '
        'confirmación.',
      );
      await f.check('Laura Gómez quedó descartada y sin movimiento', () async {
        final List<InboxItem> all = (await f.tester.runAsync(
          () => own.store.inbox(),
        ))!;
        expect(
          all.firstWhere((InboxItem i) => i.id == laura.id).status,
          InboxStatus.dismissed,
        );
        expect(own.snapshot!.entries.length, entries);
      });
      await _openMenu(f, 'Éxito Laureles');
      await f.tap('Descartar y no leer más Bancolombia');
      await f.step(
        'Con «Descartar y no leer más Bancolombia» se va la compra: arriba '
        'dice «Todo al día.» aunque el posible repetido sigue abajo.',
      );
      await f.check('La app de Bancolombia quedó silenciada', () {
        final CaptureSettings s = own.captureSettings;
        expect(s.mutedApps, contains('com.todo1.mobile'));
        expect(s.appNames['com.todo1.mobile'], 'Bancolombia');
        expect(
          own.pendingInbox.map((InboxItem i) => i.id),
          isNot(contains(exito.id)),
        );
      });
      await f.check(
        'Una notificación nueva de Bancolombia se ignora',
        () async {
          final IngestReport r = (await f.tester.runAsync(
            () => own.capture.ingest(<CaptureEvent>[
              _bancolombia(r'Compra por $12.000 en Oxxo T.Deb *1234', 9, 58),
            ]),
          ))!;
          expect(r.ignored, 1);
          expect(r.added + r.recorded, 0);
        },
      );
      await f.back();
      await f.tapTip('Ajustes');
      await f.tap('Captura automática');
      await f.reveal(find.text('Volver a leer'));
      await f.step(
        'En Ajustes › Captura automática, al final, «Apps que no se leen» '
        'muestra Bancolombia con «Volver a leer».',
      );
      await f.tap('Volver a leer');
      await f.step(
        'Con «Volver a leer» la lista desaparece: las notificaciones de '
        'Bancolombia vuelven a llegar a Por revisar.',
      );
      await f.check('Bancolombia ya no está silenciada', () {
        expect(own.captureSettings.mutedApps, isEmpty);
        expect(own.captureSettings.appNames, isEmpty);
      });
      await f.check(
        'Y una notificación nueva de Bancolombia sí entra',
        () async {
          final IngestReport r = (await f.tester.runAsync(
            () => own.capture.ingest(<CaptureEvent>[
              _bancolombia(r'Compra por $12.000 en Oxxo T.Deb *1234', 9, 58),
            ]),
          ))!;
          expect(r.added, 1);
        },
      );
    },
  ),
  AppFlow(
    '07-08-corregir-antes-de-registrar',
    'Corregir una captura antes de registrarla',
    area: 'Por revisar',
    goal:
        'La app dice que en el Éxito compré mercado, pero almorcé: quiero '
        'cambiarlo antes de registrar y que lo recuerde.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final InboxItem exito = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Éxito Laureles',
      );
      await f.tapTip('Por revisar');
      await _tapOn(f, 'Éxito Laureles', 'Editar');
      await f.step(
        '«Editar» abre «Revisar movimiento» con lo que leyó: Gasto, \$63.200, '
        'Mercado y Éxito Laureles. «Cuenta» viene vacía: no la adivina.',
      );
      await f.tapFound(find.text('Registrar gasto'));
      await f.reveal(find.text('Elige la cuenta.'));
      await f.step(
        'Sin cuenta, «Registrar gasto» no guarda: el campo «Cuenta» se pone '
        'en rojo con «Elige la cuenta.»',
      );
      await f.check('Sin cuenta no se registró nada', () {
        expect(
          own.snapshot!.entries.where((Entry e) => e.sourceRef == exito.id),
          isEmpty,
        );
      });
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Bancolombia').last);
      await f.tap('Restaurantes');
      await f.type('Nota (opcional)', 'Almuerzo con el equipo');
      await f.step(
        'Con Bancolombia, Restaurantes y una nota, la hoja queda lista para '
        '«Registrar gasto».',
      );
      await f.tapFound(find.text('Registrar gasto'));
      await f.step(
        'Registrado: el aviso dice que desde ahora «Exito Laureles» va a '
        'Restaurantes, y una regla más (la tarjeta *1234).',
      );
      await f.check('El gasto quedó como lo corregiste', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.sourceRef == exito.id,
        );
        expect(e.accountId, bank.id);
        expect(e.amount, Decimal.parse('-63200'));
        expect(e.category, 'restaurants');
        expect(e.payee, 'Éxito Laureles');
      });
      await f.check('Aprendió Restaurantes para el comercio y la tarjeta', () {
        expect(
          own.captureSettings.merchantCategories['exito laureles'],
          'restaurants',
        );
        expect(own.captureSettings.cardAccounts['1234'], bank.id);
      });
    },
  ),
  AppFlow(
    '07-09-registrar-varios-a-la-vez',
    'Registrar de un toque todo lo que está claro',
    area: 'Por revisar',
    goal:
        'Tengo muchos pagos esperando y la mayoría son obvios: quiero '
        'registrarlos todos juntos y revisar solo los raros.',
    data: _manyWaiting,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final List<String> clear = <String>[
        for (final InboxItem i in own.pendingInbox)
          if (CaptureService.isClear(i, own.accounts)) _payee(i),
      ];
      final Set<String> waiting = <String>{
        for (final InboxItem i in own.pendingInbox) i.id,
      };
      // What recording from Por revisar made in this flow.
      List<Entry> made() => <Entry>[
        for (final Entry e in own.snapshot!.entries)
          if (waiting.contains(e.sourceRef)) e,
      ];
      await f.step(
        'Inicio: «Revisa 7 movimientos para actualizar tu saldo» y la '
        'bandeja con un 7.',
      );
      await f.tapTip('Por revisar');
      await f.page(
        'Con más de 5 esperando, arriba dice cuántos hay y los listos se '
        'vuelven filas cortas con un chulo cada una.',
      );
      await f.check('Hay 7 esperando: 5 listos y 2 que necesitan algo', () {
        expect(own.pendingInbox, hasLength(7));
        expect(f.shows('7 movimientos por revisar'), isTrue);
        expect(f.shows('5 listos · 2 necesitan información'), isTrue);
      });
      await f.check('Solo 3 son tan claros como para ir juntos', () {
        expect(clear, unorderedEquals(<String>['D1', 'Juan Valdez', 'Rappi']));
        expect(f.shows('Registrar 3 de los 5 listos'), isTrue);
      });
      await f.tap('Registrar 3 de los 5 listos');
      await f.top();
      await f.step(
        '«Registrar 3 de los 5 listos» registra D1, Juan Valdez y Rappi; '
        'quedan 4, otra vez en tarjetas, y el aviso ofrece «Deshacer».',
      );
      final int spent = own.ledger!.minor(45000 + 18500 + 32000);
      await f.check('Quedaron los 3 gastos, cada uno en su cuenta', () {
        final List<Entry> made = <Entry>[
          for (final Entry e in own.snapshot!.entries)
            if (e.source == 'notification' && e.sourceRef != null) e,
        ];
        expect(
          made.map((Entry e) => e.payee),
          unorderedEquals(<String>['D1', 'Juan Valdez', 'Rappi']),
        );
        expect(
          _account(own, 'Bancolombia').id,
          made.firstWhere((Entry e) => e.payee == 'D1').accountId,
        );
        expect(
          _account(own, 'Nequi').id,
          made.firstWhere((Entry e) => e.payee == 'Rappi').accountId,
        );
      });
      await f.check(
        'Lo que puedes gastar bajó ${_cop(own, spent)}, lo que suman',
        () => expect(own.ledger!.freeUntilPayday, free - spent),
      );
      await _undoFromNotice(f);
      await f.step(
        'Con «Deshacer» del aviso vuelven los 3 a la lista y los 7 esperan '
        'otra vez.',
      );
      await f.check('Deshacer quitó los 3 movimientos de una vez', () {
        expect(own.pendingInbox, hasLength(7));
        expect(
          own.snapshot!.entries.where((Entry e) => e.source == 'notification'),
          isEmpty,
        );
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.tapFound(find.text('Tienda La Esquina'));
      await f.step(
        'Tocar una fila la abre en tarjeta completa: Tienda La Esquina, sin '
        'categoría conocida, con «Registrar gasto» y «Editar».',
      );
      await f.check('La fila se abrió con sus botones', () {
        expect(
          find.descendant(
            of: _card('Tienda La Esquina'),
            matching: find.text('Editar'),
          ),
          findsOneWidget,
        );
      });
      await f.tapFound(find.text('Tienda La Esquina'));
      await f.step('Tocarla otra vez la vuelve a cerrar en una fila.');
      await f.check('La fila se cerró', () {
        expect(
          find.descendant(
            of: _card('Tienda La Esquina'),
            matching: find.text('Editar'),
          ),
          findsNothing,
        );
      });
      await f.tapFound(
        find.descendant(
          of: _card('D1'),
          matching: find.byTooltip('Registrar gasto'),
        ),
      );
      await f.step(
        'El chulo de la fila de D1 registra solo esa: «Gasto registrado en '
        'Bancolombia», y quedan 6 por revisar.',
      );
      await f.check('Solo se registró D1', () {
        expect(own.pendingInbox, hasLength(6));
        expect(
          own.snapshot!.entries
              .where((Entry e) => e.source == 'notification')
              .map((Entry e) => e.payee),
          <String>['D1'],
        );
        expect(own.ledger!.freeUntilPayday, free - own.ledger!.minor(45000));
      });
    },
  ),
  AppFlow(
    '07-10-leer-un-pago',
    'Leer un pago que copié o capturé',
    area: 'Por revisar',
    goal:
        'Tengo el mensaje del banco copiado (o un pantallazo) y quiero que '
        'la app lo lea sin escribirlo yo.',
    data: fullAccount,
    manual: <String>[
      'Elegir capturas o fotos con el selector de fotos del sistema y ver que '
          'quedan en Por revisar con el aviso «Leí un pago».',
      'Elegir un PDF de un comprobante con el selector de archivos del '
          'sistema.',
      'En el iPhone, al abrir «Un mensaje que copiaste», iOS pide permiso '
          'para pegar lo copiado desde otra app.',
      'Compartir un pantallazo o un texto a Quincena desde otra app (atajo '
          '«Leer comprobante» en iPhone, compartir en Android).',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int waiting = own.inbox.length;
      _clipboard(f, 'Hola, ¿nos vemos a las 5?');
      await f.tapTip('Por revisar');
      await f.tap('Leer un pago');
      await f.step(
        '«Leer un pago» pregunta «¿Dónde está el pago?»: un pantallazo, foto o '
        'PDF, o un mensaje que copiaste.',
      );
      await f.tap('Un pantallazo, foto o PDF');
      await f.step(
        'La primera opción pide «Capturas o fotos» o «Un PDF»; de ahí sigue '
        'el selector del sistema, que se prueba a mano.',
      );
      await f.back();
      await f.tap('Leer un pago');
      await f.tap('Un mensaje que copiaste');
      await f.step(
        '«Pegar un mensaje» ya trae lo último que copiaste: aquí un chat, no '
        'un pago.',
      );
      await f.check('El cuadro trae lo que había en el portapapeles', () {
        expect(find.text('Hola, ¿nos vemos a las 5?'), findsOneWidget);
      });
      await f.tap('Cancelar');
      await f.check('Cancelar no agrega nada', () {
        expect(own.inbox, hasLength(waiting));
      });
      await f.tap('Leer un pago');
      await f.tap('Un mensaje que copiaste');
      await f.tap('Leer');
      await f.step(
        'Con «Leer» sobre el chat, el aviso dice «No encontré un pago en ese '
        'texto.» y nada cambia.',
      );
      await f.check('Un texto sin monto no deja nada', () {
        expect(own.inbox, hasLength(waiting));
        expect(f.shows('No encontré un pago en ese texto.'), isTrue);
      });
      await _hideNotice(f);
      const String unclear =
          r'Bancolombia: movimiento por $50.000 en tu cuenta *5678';
      await _paste(f, unclear);
      await f.top();
      await f.step(
        'Un mensaje que no dice si entró o salió: «Quedó en Por revisar.», '
        'con «No sabemos si es un gasto o un ingreso.» y «Revisar movimiento».',
      );
      await f.check('Quedó esperando sin saber si es gasto o ingreso', () {
        final InboxItem i = own.pendingInbox.firstWhere(
          (InboxItem i) => i.event.text == unclear,
        );
        expect(i.parsed.kind, isNull);
        expect(i.event.source, CaptureSource.paste);
        expect(CaptureService.isReady(i, own.accounts), isFalse);
      });
      await _hideNotice(f);
      await _tapOn(f, 'Sin comercio', 'Revisar movimiento');
      await f.tap('Ingreso');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Bancolombia').last);
      await f.tap('Reembolsos');
      await f.step(
        'En la hoja se elige «Ingreso», la cuenta Bancolombia y Reembolsos: '
        'el botón cambia a «Registrar ingreso».',
      );
      await f.tapFound(find.text('Registrar ingreso'));
      await f.step(
        'Registrado como ingreso en Bancolombia; la tarjeta salió de la '
        'lista.',
      );
      await f.check('Quedó un ingreso de \$50.000 en Bancolombia', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.source == 'paste',
        );
        expect(e.amount, Decimal.parse('50000'));
        expect(e.accountId, _account(own, 'Bancolombia').id);
        expect(e.category, 'refund');
      });
      await _hideNotice(f);
      const String rappi = r'Nequi: Pagaste $32.000 en Rappi';
      await _paste(f, rappi);
      await f.step(
        'Un mensaje claro de Nequi queda en «Listos para registrar» con '
        'Nequi y Restaurantes.',
      );
      await _hideNotice(f);
      await _paste(f, rappi);
      await f.step(
        'Pegar el mismo mensaje otra vez no lo duplica: el aviso dice «Ese '
        'pago ya estaba.»',
      );
      await f.check('El mismo mensaje dos veces queda como repetido', () {
        final List<InboxItem> same = <InboxItem>[
          for (final InboxItem i in own.inbox)
            if (i.event.text == rappi) i,
        ];
        expect(same, hasLength(2));
        expect(
          same.where((InboxItem i) => i.status == InboxStatus.duplicate),
          hasLength(1),
        );
        expect(f.shows('Ese pago ya estaba.'), isTrue);
      });
    },
  ),
  AppFlow(
    '07-11-registrar-solo-lo-claro',
    'Dejar que la app registre sola lo que está claro',
    area: 'Por revisar',
    goal:
        'No quiero tocar cada pago obvio: que la app los registre sola y yo '
        'solo corrija o deshaga si algo no va.',
    data: fullAccount,
    manual: <String>[
      'Que una notificación real de Nequi o Bancolombia llegue sola con la '
          'app cerrada (Atajos en iPhone, acceso a notificaciones en Android).',
      'Los botones «Añadir» de los atajos listos y «Abrir Atajos», que abren '
          'la app Atajos del iPhone.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account nequi = _account(own, 'Nequi');
      await f.tapTip('Ajustes');
      await f.tap('Captura automática');
      await f.page(
        'Ajustes › Captura automática: cómo llegan los pagos solos en el '
        'iPhone, las capturas y los interruptores de abajo.',
      );
      await f.tapFound(
        find.widgetWithText(SwitchListTile, 'Registrar solo lo que esté claro'),
      );
      await f.step(
        'Prendido «Registrar solo lo que esté claro»: lo seguro se registra '
        'sin preguntar; lo demás sigue esperando en Por revisar.',
      );
      await f.check('El ajuste quedó guardado', () async {
        final CaptureSettings saved = (await f.tester.runAsync(
          () => own.store.captureSettings(),
        ))!;
        expect(saved.autoRecord, isTrue);
      });
      await f.back();
      await f.back();
      await f.tapTip('Por revisar');
      await _paste(f, r'Nequi: Pagaste $32.000 en Rappi');
      await f.reveal(find.text('REGISTRADO AUTOMÁTICAMENTE'));
      await f.step(
        'Un pago claro de Nequi: el aviso dice «Quedó registrado.» y aparece '
        'abajo en «Registrado automáticamente», con el porqué.',
      );
      await f.check('Se registró solo, en Nequi y Restaurantes', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.source == 'paste',
        );
        expect(e.accountId, nequi.id);
        expect(e.category, 'restaurants');
        expect(own.recentAutomatic, hasLength(1));
      });
      await f.check(
        'Lo que puedes gastar bajó a ${_cop(own, free - own.ledger!.minor(32000))}',
        () => expect(
          own.ledger!.freeUntilPayday,
          free - own.ledger!.minor(32000),
        ),
      );
      await _hideNotice(f);
      await _tapOn(f, 'Rappi', 'Corregir');
      await f.tap('Salidas');
      await f.step(
        '«Corregir» abre «Editar movimiento» sobre lo ya registrado; aquí se '
        'cambia la categoría a Salidas.',
      );
      await f.tap('Guardar');
      await f.step(
        'Guardado: la tarjeta sigue en «Registrado automáticamente», ahora '
        'con Salidas.',
      );
      await f.check('El movimiento quedó en Salidas', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.source == 'paste',
        );
        expect(e.category, 'leisure');
      });
      await _tapOn(f, 'Rappi', 'Deshacer');
      await f.top();
      await f.step(
        '«Deshacer» borra el movimiento y Rappi vuelve a «Listos para '
        'registrar», para decidir a mano.',
      );
      await f.check('Deshacer borró el movimiento y lo dejó esperando', () {
        expect(
          own.snapshot!.entries.where((Entry e) => e.source == 'paste'),
          isEmpty,
        );
        expect(own.recentAutomatic, isEmpty);
        expect(
          own.pendingInbox.where((InboxItem i) => _payee(i) == 'Rappi'),
          hasLength(1),
        );
        expect(own.ledger!.freeUntilPayday, free);
      });
    },
  ),
  AppFlow(
    '07-12-cambiar-lo-que-aprendio',
    'Revisar y cambiar lo que la app aprendió',
    area: 'Por revisar',
    goal:
        'La app aprendió cosas de lo que registré y una está mal: quiero '
        'verlas, corregirla, apagar otra y borrar las que no sirven.',
    data: _withRules,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tapTip('Ajustes');
      await f.tap('Captura automática');
      await f.reveal(find.text('Reglas aprendidas'));
      await f.step(
        'En Captura automática, «Reglas aprendidas» dice «3 reglas» y, '
        'debajo, «Ya reconoce un comercio.»',
      );
      await f.tap('Reglas aprendidas');
      await f.page(
        '«Reglas aprendidas», por grupos: Comercios, Tarjetas y Bancos y '
        'billeteras, cada una con su interruptor y su papelera.',
      );
      await f.tap('Exito Laureles');
      await f.step(
        'Tocar «Exito Laureles» pregunta «¿A qué categoría va?», con un '
        'chulo en Mercado, la de ahora.',
      );
      await f.tap('Restaurantes');
      await f.step(
        'Elegido Restaurantes: la regla dice ahora «→ Restaurantes».',
      );
      await f.check('La regla del comercio ahora va a Restaurantes', () {
        expect(
          own.captureSettings.merchantCategories['exito laureles'],
          'restaurants',
        );
      });
      await f.tap('Tarjeta *1234');
      await f.step(
        'Tocar «Tarjeta *1234» pregunta «¿A qué cuenta va?», con un chulo en '
        'Bancolombia.',
      );
      await f.back();
      await f.check('Cerrar sin elegir deja la tarjeta como estaba', () {
        expect(
          own.captureSettings.cardAccounts['1234'],
          _account(own, 'Bancolombia').id,
        );
      });
      await f.tapFound(_ruleSwitch('Tarjeta *1234'));
      await f.step(
        'Apagada la regla de la tarjeta: «→ Bancolombia» queda tachado y deja '
        'de usarse.',
      );
      await f.check('La regla quedó apagada, no borrada', () {
        expect(own.captureSettings.disabledRules, contains('card:1234'));
        expect(own.captureSettings.cardAccounts['1234'], isNotNull);
      });
      await f.check('Una compra nueva con *1234 ya no trae cuenta', () async {
        await f.tester.runAsync(
          () => own.capture.ingest(<CaptureEvent>[
            _bancolombia(r'Compra por $45.000 en D1 T.Deb *1234', 9, 50),
          ]),
        );
        await settle(f.tester);
        final InboxItem d1 = own.pendingInbox.firstWhere(
          (InboxItem i) => _payee(i) == 'D1',
        );
        expect(d1.suggestion.accountId, isNull);
      });
      await f.tapFound(_ruleTrash('Nequi'));
      await f.step(
        'La papelera de «Nequi» la borra de una vez, sin preguntar: el grupo '
        'Bancos y billeteras desaparece.',
      );
      await f.check('La regla de Nequi se borró', () {
        expect(own.captureSettings.institutionAccounts, isEmpty);
      });
      await f.tapFound(_ruleTrash('Exito Laureles'));
      await f.tapFound(_ruleTrash('Tarjeta *1234'));
      await f.step(
        'Sin reglas: «Todavía no hay reglas. Aparecen cuando registras tus '
        'primeros movimientos.»',
      );
      await f.check('No queda ninguna regla', () {
        expect(own.captureSettings.rules, isEmpty);
      });
      await f.back();
      await f.tapFound(
        find.widgetWithText(SwitchListTile, 'Usar la ubicación del pago'),
      );
      await f.step(
        'De vuelta en Captura automática: «Reglas aprendidas» dice «Ninguna '
        'todavía» y «Usar la ubicación del pago» quedó apagado.',
      );
      await f.check('La ubicación quedó apagada', () async {
        final CaptureSettings saved = (await f.tester.runAsync(
          () => own.store.captureSettings(),
        ))!;
        expect(saved.useLocation, isFalse);
      });
    },
  ),
  AppFlow(
    '07-13-primera-captura',
    'Pegar mi primer pago con una sola cuenta',
    area: 'Por revisar',
    goal:
        'Aún no tengo nada por revisar y solo uso una cuenta: quiero pegar '
        'el mensaje de una compra y registrarla.',
    data: _oneAccount,
    manual: <String>[
      'El botón «Leer un pantallazo o PDF» del estado vacío sigue al selector '
          'de fotos o de archivos del sistema.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account bank = _account(own, 'Bancolombia');
      await f.step(
        'Inicio sin nada pendiente: no hay aviso de revisar y la bandeja de '
        'arriba va sin número.',
      );
      await f.check('No hay nada esperando', () {
        expect(own.pendingInbox, isEmpty);
        expect(find.textContaining('Revisa '), findsNothing);
      });
      await f.tapTip('Por revisar');
      await f.step(
        'Por revisar vacío: «Todo al día.», qué va a llegar aquí y dos '
        'botones para traer un pago a mano.',
      );
      await f.tap('Leer un pantallazo o PDF');
      await f.step(
        '«Leer un pantallazo o PDF» ofrece «Capturas o fotos» o «Un PDF»; el '
        'selector del sistema se prueba a mano.',
      );
      await f.back();
      await f.tap('Pegar un mensaje');
      await f.tester.enterText(
        find.byType(TextField).last,
        r'Compraste $27.500 en Farmatodo',
      );
      await settle(f.tester);
      await f.step(
        '«Pegar un mensaje» con la compra en Farmatodo escrita; «Leer» la '
        'convierte en un pago por revisar.',
      );
      await f.tap('Leer');
      await f.step(
        '«Quedó en Por revisar.»: sin banco en el mensaje, propone tu única '
        'cuenta en pesos y pide revisarla.',
      );
      await f.check('Propone Bancolombia por ser la única en pesos', () {
        final InboxItem i = own.pendingInbox.single;
        expect(i.suggestion.accountId, bank.id);
        expect(i.suggestion.why, contains('only'));
        expect(CaptureService.isReady(i, own.accounts), isFalse);
        expect(
          f.shows(
            'Revisa la cuenta: la elegimos por ser tu única de uso diario '
            'en COP.',
          ),
          isTrue,
        );
      });
      await _tapOn(f, 'Farmatodo', 'Registrar gasto');
      await f.step(
        'Con «Registrar gasto» queda en Bancolombia, en Salud, y la lista '
        'vuelve a «Todo al día.»',
      );
      await f.check('Quedó un gasto de \$27.500 en Bancolombia, en Salud', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.source == 'paste',
        );
        expect(e.accountId, bank.id);
        expect(e.amount, Decimal.parse('-27500'));
        expect(e.category, 'health');
        expect(own.pendingInbox, isEmpty);
      });
      await f.check(
        'Solo aprendió el comercio: el mensaje no nombra banco',
        () {
          expect(own.captureSettings.merchantCategories['farmatodo'], 'health');
          expect(own.captureSettings.institutionAccounts, isEmpty);
          expect(own.captureSettings.cardAccounts, isEmpty);
        },
      );
      await f.back();
      await f.step('Inicio: «Puedes gastar» bajó lo de Farmatodo.');
      await f.check(
        'Lo que puedes gastar bajó a ${_cop(own, free - own.ledger!.minor(27500))}',
        () => expect(
          own.ledger!.freeUntilPayday,
          free - own.ledger!.minor(27500),
        ),
      );
    },
  ),
];

/// Diego's account, with more of what the phone caught that morning: a
/// Rappi order on Nequi, a Claro bill from Bancolombia, where he has two
/// accounts, and a purchase from Davivienda, where he has none.
Future<QuincenaStore> _everyKind() async {
  final QuincenaStore store = await fullAccount();
  await _caught(store, <CaptureEvent>[
    _nequi(r'Pagaste $32.000 en Rappi', 9, 5),
    _bancolombia(r'Pago por $89.900 a Claro', 9, 20),
    _davivienda(r'Compra por $120.000 en Falabella', 9, 30),
  ]);
  return store;
}

/// Seven waiting: the morning's three, and with the card *1234 already
/// Bancolombia's, purchases on it and on Nequi the app is sure of, one
/// at a shop it does not know, and one from Davivienda.
Future<QuincenaStore> _manyWaiting() async {
  final QuincenaStore store = await fullAccount();
  final Account bank = (await store.accounts()).firstWhere(
    (Account a) => a.name == 'Bancolombia',
  );
  await store.saveCaptureSettings(
    (await store.captureSettings()).withRule(
      CaptureRule(kind: RuleKind.card, key: '1234', target: bank.id),
    ),
  );
  await _caught(store, <CaptureEvent>[
    _nequi(r'Pagaste $32.000 en Rappi', 9, 5),
    _nequi(r'Pagaste $9.800 en Tienda La Esquina', 9, 10),
    _davivienda(r'Compra por $120.000 en Falabella', 9, 30),
    _bancolombia(r'Compra por $45.000 en D1 T.Deb *1234', 9, 50),
    _bancolombia(r'Compra por $18.500 en Juan Valdez T.Deb *1234', 9, 55),
  ]);
  return store;
}

/// Diego's account with three rules learned: Éxito Laureles is groceries,
/// the card *1234 is Bancolombia's and Nequi's alerts go to Nequi.
Future<QuincenaStore> _withRules() async {
  final QuincenaStore store = await fullAccount();
  final List<Account> accounts = await store.accounts();
  String id(String name) =>
      accounts.firstWhere((Account a) => a.name == name).id;
  await store.saveCaptureSettings(
    (await store.captureSettings())
        .withRule(
          const CaptureRule(
            kind: RuleKind.merchant,
            key: 'exito laureles',
            target: 'groceries',
          ),
        )
        .withRule(
          CaptureRule(
            kind: RuleKind.card,
            key: '1234',
            target: id('Bancolombia'),
          ),
        )
        .withRule(
          CaptureRule(
            kind: RuleKind.institution,
            key: 'Nequi',
            target: id('Nequi'),
          ),
        ),
  );
  return store;
}

/// Someone who spends from one account in pesos, and keeps dollars apart.
Future<QuincenaStore> _oneAccount() async {
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
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: Decimal.parse('1500000'),
    institution: 'Bancolombia',
  );
  await store.addAccount(
    name: 'Ahorro en dólares',
    kind: AccountKind.bank,
    asset: Asset.usd,
    opening: Decimal.parse('800'),
    institution: 'Global66',
    spendable: false,
  );
  return store;
}

/// Runs [events] through the inbox, as if they had just arrived.
Future<void> _caught(QuincenaStore store, List<CaptureEvent> events) async {
  await CaptureService(store, now: () => screensNow).ingest(events);
}

CaptureEvent _nequi(String text, int hour, int minute) => CaptureEvent(
  source: CaptureSource.notification,
  at: DateTime(2026, 10, 3, hour, minute),
  app: 'com.nequi.MobileApp',
  appName: 'Nequi',
  title: 'Nequi',
  text: 'Nequi · $text',
);

CaptureEvent _bancolombia(String text, int hour, int minute) => CaptureEvent(
  source: CaptureSource.notification,
  at: DateTime(2026, 10, 3, hour, minute),
  app: 'com.todo1.mobile',
  appName: 'Bancolombia',
  title: 'Bancolombia',
  text: 'Bancolombia · $text',
);

CaptureEvent _davivienda(String text, int hour, int minute) => CaptureEvent(
  source: CaptureSource.notification,
  at: DateTime(2026, 10, 3, hour, minute),
  app: 'com.davivienda.daviviendaapp',
  appName: 'Davivienda',
  title: 'Davivienda',
  text: 'Davivienda · $text',
);

Account _account(OwnController own, String name) =>
    own.accounts.firstWhere((Account a) => a.name == name);

/// [minor] of the base currency the way the app writes it.
String _cop(OwnController own, int minor) => pesos(own.ledger!.major(minor));

/// Who a capture says was paid, as its card shows it.
String _payee(InboxItem i) =>
    i.suggestion.payee ?? i.parsed.merchant ?? 'Sin comercio';

/// The card of the capture that paid [payee].
Finder _card(String payee) =>
    find.ancestor(of: find.text(payee), matching: find.byType(InboxCard));

/// Opens the "⋮" menu of [payee]'s card.
Future<void> _openMenu(FlowRun f, String payee) => f.tapFound(
  find.descendant(of: _card(payee), matching: find.byTooltip('Más acciones')),
);

/// Taps [label] on [payee]'s card.
Future<void> _tapOn(FlowRun f, String payee, String label) =>
    f.tapFound(find.descendant(of: _card(payee), matching: find.text(label)));

/// Reads [text] as a message the person copied, through «Leer un pago».
Future<void> _paste(FlowRun f, String text) async {
  await f.top();
  await f.tap('Leer un pago');
  await f.tap('Un mensaje que copiaste');
  await f.tester.enterText(find.byType(TextField).last, text);
  await settle(f.tester);
  await f.tap('Leer');
}

/// Taps «Deshacer» on the notice at the bottom.
Future<void> _undoFromNotice(FlowRun f) => f.tapFound(
  find.descendant(of: find.byType(SnackBar), matching: find.text('Deshacer')),
);

/// Takes the notice at the bottom away, as its time running out would.
Future<void> _hideNotice(FlowRun f) async {
  for (final ScaffoldMessengerState m in f.tester.stateList(
    find.byType(ScaffoldMessenger),
  )) {
    m.removeCurrentSnackBar();
  }
  await settle(f.tester);
}

/// What the phone's clipboard holds, for the paste dialog to read.
void _clipboard(FlowRun f, String text) {
  final TestDefaultBinaryMessenger messenger =
      f.tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (
    MethodCall call,
  ) async {
    if (call.method == 'Clipboard.getData') {
      return <String, Object?>{'text': text};
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

/// The row of a learned rule.
Finder _ruleRow(String subject) =>
    find.ancestor(of: find.text(subject), matching: find.byType(ListTile));

Finder _ruleSwitch(String subject) =>
    find.descendant(of: _ruleRow(subject), matching: find.byType(Switch));

Finder _ruleTrash(String subject) => find.descendant(
  of: _ruleRow(subject),
  matching: find.byTooltip('Borrar regla'),
);
