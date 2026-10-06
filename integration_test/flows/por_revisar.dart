// Flows of Por revisar y captura (07), Importar extracto (08).
import 'dart:async';

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
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/statements/statement.dart';
import 'package:quincena/statements/statement_import.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/ui/own/statement_page.dart';

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
        'Inicio: ${_headline(own)} todavía no cuenta lo que llegó a Nequi; '
        'la bandeja de arriba dice que hay 2 por revisar.',
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
      await f.check(
        'Aprendió dos reglas: Laura Gómez y las alertas de Nequi',
        () {
          final CaptureSettings s = own.captureSettings;
          expect(s.merchantCategories['laura gomez'], 'other_income');
          expect(s.institutionAccounts['Nequi'], nequi.id);
          expect(s.rules.length, rules + 2);
        },
      );
      await f.back();
      await f.step(
        'De vuelta en Inicio: ${_headline(own)}, con los \$85.000 de Laura, '
        'y el aviso con «Deshacer» sigue abajo.',
      );
      final int up = free + own.ledger!.minor(85000);
      await f.check('Lo que puedes gastar subió a ${_cop(own, up)}', () {
        expect(own.ledger!.freeUntilPayday, up);
        expect(f.shows(_cop(own, up)), isTrue);
      });
      await _undoFromNotice(f);
      await f.step(
        '«Deshacer» desde Inicio: el ingreso se borra, vuelve '
        '${_headline(own)} y la bandeja otra vez dice 2.',
      );
      await f.check('Lo que puedes gastar volvió a ${_cop(own, free)}', () {
        expect(own.ledger!.freeUntilPayday, free);
        expect(own.balances[nequi.id]!.amount, before);
      });
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
      await f.tapTip('Por revisar');
      await f.step(
        'Laura Gómez espera otra vez en «Listos para registrar», como si '
        'nada hubiera pasado.',
      );
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
      final String before = _headline(own);
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
        'Inicio: con los \$63.200 de Éxito Laureles, $before pasó a '
        '${_headline(own)}; Carulla no cuenta hasta registrarla.',
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
        expect(f.shows('Registrar transferencia'), isTrue);
        expect(_menuShows('Desde', 'Bancolombia'), isTrue);
        expect(_menuShows('Hacia', 'Nequi'), isTrue);
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
      await f.check(
        'El aviso quedó registrado y apunta a la salida de Bancolombia',
        () async {
          final InboxItem done = (await f.tester.runAsync(
            () => own.store.inbox(),
          ))!.firstWhere((InboxItem i) => i.event.text.contains('Diego Lopez'));
          expect(done.status, InboxStatus.accepted);
          final Entry left = own.snapshot!.entries.firstWhere(
            (Entry e) => e.id == done.entryId,
          );
          expect(left.accountId, bank.id);
          expect(left.amount, Decimal.parse('-200000'));
        },
      );
      await _hideNotice(f);
      await f.back();
      await f.step(
        'Inicio: sigue ${_headline(own)}, igual que antes: pasar plata '
        'entre tus cuentas no es gastar ni ganar.',
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
      final InboxItem claro = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Claro',
      );
      await f.check('El pago en pesos no va a la cuenta en dólares', () {
        expect(claro.suggestion.accountId, isNot(dollars.id));
      });
      await _hideNotice(f);
      await _tapOn(f, 'Claro', 'Elegir la cuenta');
      await f.step(
        '«Elegir la cuenta» de Claro avisa «La próxima vez, lo de '
        'Bancolombia irá directo a esa cuenta.»: el mensaje no trae tarjeta, '
        'así que aprende el banco.',
      );
      await f.check('La hoja promete la regla del banco', () {
        expect(
          f.shows(
            'La próxima vez, lo de Bancolombia irá directo a esa cuenta.',
          ),
          isTrue,
        );
      });
      final Account bank = _account(own, 'Bancolombia');
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      await f.tap('Bancolombia');
      await f.step(
        'Con Bancolombia elegida, el aviso dice «Gasto registrado en '
        'Bancolombia» y lo que aprendió: Claro va a Servicios y una regla más.',
      );
      await f.check('Quedó el pago de Claro en Bancolombia', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.sourceRef == claro.id,
        );
        expect(e.accountId, bank.id);
        expect(e.amount, Decimal.parse('-89900'));
        expect(
          own.balances[bank.id]!.amount,
          bankBefore - Decimal.parse('89900'),
        );
      });
      await f.check('Lo de Bancolombia ahora va a su cuenta en pesos', () {
        expect(own.captureSettings.institutionAccounts['Bancolombia'], bank.id);
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
      await f.check('El gasto quedó como lo corregiste, con la nota', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.sourceRef == exito.id,
        );
        expect(e.accountId, bank.id);
        expect(e.amount, Decimal.parse('-63200'));
        expect(e.category, 'restaurants');
        expect(e.payee, 'Éxito Laureles');
        expect(e.note, 'Almuerzo con el equipo');
      });
      await f.check('Y con la hora del aviso, 9:40 a. m.', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.sourceRef == exito.id,
        );
        expect(e.date, DateTime(2026, 10, 3, 9, 40));
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
      final Account bank = _account(own, 'Bancolombia');
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
        'vuelven filas cortas con un chulo cada una; solo Falabella necesita '
        'algo.',
      );
      await f.check('Hay 7 esperando: 6 listos y 1 que necesita algo', () {
        expect(own.pendingInbox, hasLength(7));
        expect(f.shows('7 movimientos por revisar'), isTrue);
        expect(f.shows('6 listos · 1 necesita información'), isTrue);
      });
      await f.check(
        'Éxito Laureles, que llegó antes de saber de la tarjeta *1234, ya trae '
        'Bancolombia por la regla',
        () {
          final InboxItem exito = own.pendingInbox.firstWhere(
            (InboxItem i) => _payee(i) == 'Éxito Laureles',
          );
          expect(own.captureSettings.cardAccounts['1234'], bank.id);
          expect(exito.suggestion.accountId, bank.id);
          expect(exito.suggestion.why, contains('card'));
          expect(CaptureService.isReady(exito, own.accounts), isTrue);
          expect(find.textContaining('falta asociarla'), findsNothing);
        },
      );
      await f.check('Solo 4 son tan claros como para ir juntos', () {
        expect(
          clear,
          unorderedEquals(<String>[
            'D1',
            'Juan Valdez',
            'Rappi',
            'Éxito Laureles',
          ]),
        );
        expect(f.shows('Registrar 4 de los 6 listos'), isTrue);
      });
      await f.tap('Registrar 4 de los 6 listos');
      await f.top();
      await f.step(
        '«Registrar 4 de los 6 listos» registra D1, Juan Valdez, Rappi y Éxito '
        'Laureles; quedan 3, otra vez en tarjetas, y el aviso ofrece '
        '«Deshacer».',
      );
      final int spent = own.ledger!.minor(45000 + 18500 + 32000 + 63200);
      await f.check('Quedaron los 4 gastos, cada uno en su cuenta', () {
        final List<Entry> recorded = made();
        expect(
          recorded.map((Entry e) => e.payee),
          unorderedEquals(<String>[
            'D1',
            'Juan Valdez',
            'Rappi',
            'Éxito Laureles',
          ]),
        );
        expect(
          recorded
              .firstWhere((Entry e) => e.payee == 'Éxito Laureles')
              .accountId,
          bank.id,
        );
        expect(
          recorded.firstWhere((Entry e) => e.payee == 'Rappi').accountId,
          _account(own, 'Nequi').id,
        );
        expect(own.pendingInbox, hasLength(3));
      });
      await f.check(
        'Lo que puedes gastar bajó ${_cop(own, spent)}, lo que suman',
        () => expect(own.ledger!.freeUntilPayday, free - spent),
      );
      await _undoFromNotice(f);
      await f.step(
        'Con «Deshacer» del aviso vuelven los 4 a la lista y los 7 esperan '
        'otra vez.',
      );
      await f.check('Deshacer quitó los 4 movimientos de una vez', () {
        expect(own.pendingInbox, hasLength(7));
        expect(made(), isEmpty);
        expect(own.ledger!.freeUntilPayday, free);
        // The card's rule was there before: taking these back leaves it.
        expect(own.captureSettings.cardAccounts['1234'], bank.id);
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
      await f.top();
      await f.step(
        'El chulo de la fila de D1 registra solo esa: «Gasto registrado en '
        'Bancolombia», y arriba dice que quedan 6 por revisar.',
      );
      await f.check('Solo se registró D1', () {
        expect(own.pendingInbox, hasLength(6));
        expect(f.shows('6 movimientos por revisar'), isTrue);
        expect(made().map((Entry e) => e.payee), <String>['D1']);
        expect(own.ledger!.freeUntilPayday, free - own.ledger!.minor(45000));
      });
      await _hideNotice(f);
      await f.tapFound(
        find.descendant(
          of: _card('Tienda La Esquina'),
          matching: find.byTooltip('Registrar gasto'),
        ),
      );
      await _hideNotice(f);
      await f.top();
      await f.step(
        'Con el chulo de Tienda La Esquina quedan 5: vuelven a ser tarjetas, '
        'y arriba dice «Registrar 3 de los 4 listos» porque Laura no tiene '
        'categoría segura.',
      );
      await f.check('Tienda La Esquina quedó en Otros, en Nequi', () {
        final Entry e = made().firstWhere(
          (Entry e) => e.payee == 'Tienda La Esquina',
        );
        expect(e.category, 'other');
        expect(e.amount, Decimal.parse('-9800'));
        expect(e.accountId, _account(own, 'Nequi').id);
        expect(f.shows('Registrar 3 de los 4 listos'), isTrue);
      });
      await _tapOn(f, 'Laura Gómez', 'Registrar ingreso');
      await _hideNotice(f);
      await f.top();
      await f.step(
        'Registrado el ingreso de Laura, los tres listos que quedan son '
        'claros: el botón ahora dice «Registrar los 3 listos».',
      );
      await f.check('El botón cuenta los 3 que quedan listos', () {
        expect(f.shows('Registrar los 3 listos'), isTrue);
      });
      await f.tap('Registrar los 3 listos');
      await f.step(
        '«Registrar los 3 listos» registra Juan Valdez, Rappi y Éxito Laureles '
        'de una vez: solo queda Falabella, que necesita información.',
      );
      final int net = own.ledger!.minor(
        85000 - 45000 - 9800 - 18500 - 32000 - 63200,
      );
      await f.check('Ya se registraron 6 y queda 1 esperando', () {
        expect(
          made().map((Entry e) => e.payee),
          unorderedEquals(<String>[
            'D1',
            'Tienda La Esquina',
            'Laura Gómez',
            'Juan Valdez',
            'Rappi',
            'Éxito Laureles',
          ]),
        );
        expect(own.pendingInbox.map(_payee), <String>['Falabella']);
      });
      await f.check(
        'Lo que puedes gastar se movió ${_cop(own, net)}: lo que suman',
        () => expect(own.ledger!.freeUntilPayday, free + net),
      );
      await _hideNotice(f);
      await _tapOn(f, 'Falabella', 'Elegir la cuenta');
      await f.step(
        'Falabella llegó de Davivienda, donde no tienes cuenta: «Elegir la '
        'cuenta» solo ofrece las que ya tienes y promete mandar ahí todo lo de '
        'Davivienda.',
      );
      await f.check('La hoja promete una regla para un banco sin cuenta', () {
        expect(
          f.shows('La próxima vez, lo de Davivienda irá directo a esa cuenta.'),
          isTrue,
        );
        expect(accountsAt('Davivienda', own.accounts), isEmpty);
      });
      await f.back();
      await f.check('Cerrar sin elegir no registra Falabella', () {
        expect(own.pendingInbox.map(_payee), <String>['Falabella']);
        expect(own.captureSettings.institutionAccounts['Davivienda'], isNull);
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
      await f.check(
        'Aprendió la «tarjeta» *5678, aunque el mensaje decía «cuenta»',
        () {
          expect(
            own.captureSettings.cardAccounts['5678'],
            _account(own, 'Bancolombia').id,
          );
        },
      );
      await _hideNotice(f);
      const String rappi = r'Nequi: Pagaste $32.000 en Rappi';
      await _paste(f, rappi);
      await f.step(
        'Un mensaje claro de Nequi queda en «Listos para registrar» con '
        'Nequi y Restaurantes.',
      );
      await _hideNotice(f);
      await _paste(f, rappi);
      await f.reveal(find.text('POSIBLES REPETIDOS'));
      await f.step(
        'El mismo mensaje pegado otra vez: el aviso dice «Ese pago ya '
        'estaba.» y la copia queda en «Posibles repetidos», no en los listos.',
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
      'En Android, «Permitir acceso a notificaciones» abre los ajustes del '
          'sistema y, al volver, dice «Acceso a notificaciones activado».',
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
        '«Corregir» abre la hoja del movimiento ya registrado, con «Guardar», '
        '«Dividir este gasto» y «Eliminar»; aquí se cambia la categoría a '
        'Salidas.',
      );
      await f.tap('Guardar');
      await f.step(
        'Guardado: la tarjeta sigue en «Registrado automáticamente», ahora '
        'con Salidas.',
      );
      await f.check('El movimiento quedó en Salidas, a la misma hora', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.source == 'paste',
        );
        expect(e.category, 'leisure');
        expect(e.date, screensNow);
      });
      await _openMenu(f, 'Rappi');
      await f.step(
        'En lo que ya se registró, el menú «⋮» solo trae «Detalles de '
        'detección»: no se descarta, se deshace.',
      );
      await f.check('Lo registrado no se puede descartar', () {
        expect(f.shows('Detalles de detección'), isTrue);
        expect(find.text('Descartar'), findsNothing);
      });
      await f.back();
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
      await f.back();
      await f.tapTip('Ajustes');
      await f.tap('Captura automática');
      await f.tap('Leer un pantallazo o PDF');
      await f.step(
        'En Captura automática, «Leer un pantallazo o PDF» ofrece lo mismo que '
        'Por revisar: «Capturas o fotos» o «Un PDF».',
      );
      await f.back();
      await f.tapFound(
        find.widgetWithText(SwitchListTile, 'Registrar solo lo que esté claro'),
      );
      await f.step(
        'Apagado «Registrar solo lo que esté claro»: desde ahora todo vuelve a '
        'esperar en Por revisar.',
      );
      await f.check('El ajuste apagado quedó guardado', () async {
        final CaptureSettings saved = (await f.tester.runAsync(
          () => own.store.captureSettings(),
        ))!;
        expect(saved.autoRecord, isFalse);
      });
      await f.check('Y un pago claro ya no se registra solo', () async {
        final IngestReport r = (await f.tester.runAsync(
          () => own.capture.ingest(<CaptureEvent>[
            _nequi(r'Pagaste $18.000 en Rappi', 10, 30),
          ]),
        ))!;
        expect(r.recorded, 0);
        expect(r.added, 1);
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
    manual: <String>[
      'En Android, prender «Usar la ubicación del pago» pide el permiso de '
          'ubicación del sistema y, después de «Ubicación con la app cerrada», '
          '«Permitir todo el tiempo»; negarlo muestra el aviso con «Abrir '
          'ajustes».',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final Account visa = _account(own, 'Visa');
      Future<CaptureSettings> saved() async =>
          (await f.tester.runAsync(() => own.store.captureSettings()))!;
      await f.tapTip('Ajustes');
      await f.tap('Captura automática');
      await f.reveal(find.text('Reglas aprendidas'));
      await f.step(
        'En Captura automática, «Reglas aprendidas» dice «3 reglas» y, '
        'debajo, «Ya reconoce un comercio.»',
      );
      await f.check('Cuenta las 3 reglas y el comercio que reconoce', () {
        expect(own.captureSettings.rules, hasLength(3));
        expect(f.shows('3 reglas'), isTrue);
        expect(f.shows('Ya reconoce un comercio.'), isTrue);
      });
      await f.tap('Reglas aprendidas');
      await f.page(
        '«Reglas aprendidas», por grupos: Comercios, Tarjetas y Bancos y '
        'billeteras. La tarjeta *1234, que es débito de Bancolombia, quedó '
        'mal: dice «→ Visa».',
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
      await f.check('La regla del comercio ahora va a Restaurantes', () async {
        expect(
          (await saved()).merchantCategories['exito laureles'],
          'restaurants',
        );
      });
      await f.tap('Tarjeta *1234');
      await f.step(
        'Tocar «Tarjeta *1234» pregunta «¿A qué cuenta va?», con un chulo en '
        'Visa, la de ahora; la lista trae todas las cuentas, también Binance '
        'y Bitcoin.',
      );
      await f.check('El chulo está en la cuenta de la regla', () {
        expect(
          find.descendant(
            of: find.widgetWithText(SimpleDialogOption, 'Visa'),
            matching: find.byType(Icon),
          ),
          findsOneWidget,
        );
      });
      await f.back();
      await f.check('Cerrar sin elegir deja la tarjeta como estaba', () async {
        expect((await saved()).cardAccounts['1234'], visa.id);
      });
      await f.tap('Tarjeta *1234');
      await f.tap('Bancolombia');
      await f.step(
        'Abierta otra vez y elegida Bancolombia, la regla de la tarjeta dice '
        'ahora «→ Bancolombia».',
      );
      await f.check(
        'La tarjeta *1234 quedó guardada como de Bancolombia',
        () async {
          expect((await saved()).cardAccounts['1234'], bank.id);
        },
      );
      await f.tapFound(_ruleSwitch('Tarjeta *1234'));
      await f.step(
        'Apagada la regla de la tarjeta: «→ Bancolombia» queda tachado y deja '
        'de usarse.',
      );
      await f.check('La regla quedó apagada, no borrada', () async {
        final CaptureSettings s = await saved();
        expect(s.disabledRules, contains('card:1234'));
        expect(s.cardAccounts['1234'], bank.id);
      });
      InboxItem d1() =>
          own.pendingInbox.firstWhere((InboxItem i) => _payee(i) == 'D1');
      await f.check('Una compra nueva con *1234 ya no trae cuenta', () async {
        await f.tester.runAsync(
          () => own.capture.ingest(<CaptureEvent>[
            _bancolombia(r'Compra por $45.000 en D1 T.Deb *1234', 9, 50),
          ]),
        );
        await settle(f.tester);
        expect(d1().suggestion.accountId, isNull);
      });
      await f.tapFound(_ruleSwitch('Tarjeta *1234'));
      await f.step(
        'Prendida otra vez, la regla de la tarjeta vuelve a decir «→ '
        'Bancolombia» sin tachar.',
      );
      await f.check('La regla de la tarjeta volvió a usarse', () {
        expect(own.captureSettings.disabledRules, isNot(contains('card:1234')));
        expect(own.captureSettings.use(RuleKind.card, '1234'), bank.id);
      });
      await f.check('Y la compra de D1 que esperaba ya trae Bancolombia', () {
        expect(d1().suggestion.accountId, bank.id);
        expect(CaptureService.isReady(d1(), own.accounts), isTrue);
      });
      await f.tapFound(_ruleTrash('Nequi'));
      await f.step(
        'La papelera de «Nequi» la borra de una vez, sin preguntar: el grupo '
        'Bancos y billeteras desaparece.',
      );
      await f.check('La regla de Nequi se borró', () async {
        expect((await saved()).institutionAccounts, isEmpty);
      });
      await f.tapFound(_ruleTrash('Exito Laureles'));
      await f.tapFound(_ruleTrash('Tarjeta *1234'));
      await f.step(
        'Sin reglas: «Todavía no hay reglas. Aparecen cuando registras tus '
        'primeros movimientos.»',
      );
      await f.check('No queda ninguna regla', () async {
        expect((await saved()).rules, isEmpty);
      });
      await f.check('La compra de D1 vuelve a pedir la cuenta', () {
        expect(d1().suggestion.accountId, isNull);
      });
      await f.back();
      final Finder location = find.widgetWithText(
        SwitchListTile,
        'Usar la ubicación del pago',
      );
      await f.tapFound(location);
      await f.step(
        'De vuelta en Captura automática: «Reglas aprendidas» dice «Ninguna '
        'todavía» y «Usar la ubicación del pago» quedó apagado.',
      );
      await f.check('La ubicación quedó apagada', () async {
        expect((await saved()).useLocation, isFalse);
        expect(f.shows('Ninguna todavía'), isTrue);
      });
      await f.tapFound(location);
      await f.step(
        'Prendida otra vez: en el iPhone no pide nada aquí, porque la '
        'ubicación la entrega el atajo con cada pago.',
      );
      await f.check('La ubicación quedó prendida', () async {
        expect((await saved()).useLocation, isTrue);
        expect(f.tester.widget<SwitchListTile>(location).value, isTrue);
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
      await f.step(
        'Inicio: ahora ${_headline(own)}, los \$27.500 de Farmatodo menos '
        'que antes.',
      );
      await f.check(
        'Lo que puedes gastar bajó a ${_cop(own, free - own.ledger!.minor(27500))}',
        () => expect(
          own.ledger!.freeUntilPayday,
          free - own.ledger!.minor(27500),
        ),
      );
    },
  ),
  AppFlow(
    '07-14-pago-sin-banco',
    'Registrar un pago que no dice el banco',
    area: 'Por revisar',
    goal:
        'Camilo me pagó y el mensaje no dice a qué cuenta llegó, y tengo el '
        'pantallazo de un café que pagué ayer en efectivo: quiero decirle a la '
        'app dónde y cuándo fue cada uno.',
    data: fullAccount,
    manual: <String>[
      'Elegir el pantallazo del café con «Leer un pago» › «Capturas o fotos» '
          'y ver el aviso «Leí un pago. Quedó en Por revisar.»',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account nequi = _account(own, 'Nequi');
      final Account cash = _account(own, 'Efectivo');
      final int rules = own.captureSettings.rules.length;
      await f.tapTip('Por revisar');
      // How Davivienda and others say it: the noun first, no bank named.
      await _paste(f, r'Transferencia recibida por $120.000 de CAMILO RUIZ');
      await _hideNotice(f);
      await f.top();
      await f.step(
        'Camilo Ruiz te pagó \$120.000, pero el mensaje no nombra banco: la '
        'tarjeta dice «No sabemos a qué cuenta llegó.»',
      );
      final InboxItem camilo = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Camilo Ruiz',
      );
      await f.check('Espera sin cuenta, como ingreso', () {
        expect(camilo.parsed.kind, EntryKind.income);
        expect(camilo.parsed.institution, isNull);
        expect(camilo.suggestion.accountId, isNull);
        expect(f.shows('No sabemos a qué cuenta llegó.'), isTrue);
      });
      await _tapOn(f, 'Camilo Ruiz', 'Elegir la cuenta');
      await f.step(
        '«¿A qué cuenta llegó?» lista tus cuentas, las de uso diario en pesos '
        'primero, y no promete regla: no hay banco ni tarjeta que aprender.',
      );
      await f.check('La hoja pregunta por la cuenta sin prometer reglas', () {
        expect(f.shows('¿A qué cuenta llegó?'), isTrue);
        expect(find.textContaining('La próxima vez'), findsNothing);
      });
      await f.tap('Nequi');
      await f.step(
        'Elegida Nequi: el aviso dice «Ingreso registrado en Nequi.» y que '
        'Camilo Ruiz va a Otros ingresos desde ahora.',
      );
      await f.check('Quedó un ingreso de \$120.000 en Nequi', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.sourceRef == camilo.id,
        );
        expect(e.accountId, nequi.id);
        expect(e.amount, Decimal.parse('120000'));
      });
      await f.check('Solo aprendió el nombre: no hay banco que recordar', () {
        expect(own.captureSettings.rules.length, rules + 1);
        expect(
          own.captureSettings.merchantCategories['camilo ruiz'],
          isNotNull,
        );
      });
      await _hideNotice(f);
      // What the system's photo picker hands back is read on the phone; its
      // text goes in as a screenshot's.
      await f.tester.runAsync(
        () => own.ingestRead(<String>[r'Pagaste $15.000 en Tostao']),
      );
      await settle(f.tester);
      await f.top();
      await f.step(
        'Lo que la app leyó del pantallazo del café espera igual: Tostao por '
        '\$15.000, con «No sabemos de qué cuenta salió.»',
      );
      final InboxItem tostao = own.pendingInbox.firstWhere(
        (InboxItem i) => _payee(i) == 'Tostao',
      );
      await f.check('Llegó como captura de pantalla, sin cuenta', () {
        expect(tostao.event.source, CaptureSource.screenshot);
        expect(tostao.suggestion.accountId, isNull);
        expect(f.shows('No sabemos de qué cuenta salió.'), isTrue);
      });
      await _openMenu(f, 'Tostao');
      await f.tap('Detalles de detección');
      await f.reveal(_card('Tostao'));
      await f.step(
        'Sus detalles dicen que llegó por «Captura de pantalla» y muestran el '
        'texto que leyó, tal cual.',
      );
      await f.check('Los detalles dicen de dónde salió el texto', () {
        expect(find.textContaining('Captura de pantalla'), findsOneWidget);
        expect(find.text(r'Pagaste $15.000 en Tostao'), findsOneWidget);
      });
      // The café was yesterday: the date is the form's to change.
      await _tapOn(f, 'Tostao', 'Editar');
      await f.tapFound(find.widgetWithText(InputDecorator, 'Fecha'));
      await f.step(
        '«Editar» abre «Revisar movimiento» con la fecha en que se leyó el '
        'pantallazo; tocar «Fecha» abre el calendario en el 3 de octubre.',
      );
      await f.tapFound(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('2'),
        ),
      );
      await f.tap('ACEPTAR');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Efectivo').last);
      await f.step(
        'Elegido el 2 en el calendario, «Fecha» dice «Ayer»; con Efectivo en '
        '«Cuenta», la hoja queda lista para «Registrar gasto».',
      );
      await f.check('La hoja dice «Ayer», el 2 de octubre', () {
        expect(f.shows('Ayer'), isTrue);
      });
      await f.tapFound(find.text('Registrar gasto'));
      await f.step(
        'Registrado: el aviso dice «Gasto registrado en Efectivo.» y que '
        'Tostao va a Restaurantes; quedan los que ya esperaban.',
      );
      await f.check('Quedó un gasto de \$15.000 en Efectivo, ayer', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.sourceRef == tostao.id,
        );
        expect(e.accountId, cash.id);
        expect(e.amount, Decimal.parse('-15000'));
        expect(e.source, 'screenshot');
        // A day picked by hand, with no hour of its own, goes at noon.
        expect(e.date, DateTime(2026, 10, 2, 12));
      });
      await _hideNotice(f);
      await f.back();
      final int now = free + own.ledger!.minor(120000 - 15000);
      await f.step(
        'Inicio: ${_headline(own)}, con los \$120.000 de Camilo y sin los '
        '\$15.000 del café.',
      );
      await f.check('Lo que puedes gastar subió a ${_cop(own, now)}', () {
        expect(own.ledger!.freeUntilPayday, now);
      });
    },
  ),
  AppFlow(
    '07-15-plata-que-mande-a-otra-cuenta-mia',
    'Registrar plata que mandé a otra cuenta mía',
    area: 'Por revisar',
    goal:
        'Me pasé plata de Bancolombia a Nequi y me llegaron los dos avisos: '
        'quiero que cuente una sola vez, como plata que cambió de bolsillo.',
    data: _sentToNequi,
    manual: <String>[
      'Con las notificaciones reales de Bancolombia y de Nequi por una misma '
          'transferencia, que la segunda quede en «Posibles repetidos».',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account bank = _account(own, 'Bancolombia');
      final Account nequi = _account(own, 'Nequi');
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      final Decimal nequiBefore = own.balances[nequi.id]!.amount;
      final int rules = own.captureSettings.rules.length;
      final InboxItem sent = own.pendingInbox.firstWhere(
        (InboxItem i) => i.event.text.contains('Transferiste'),
      );
      // Both sides of the move the alert became.
      List<Entry> legs() => <Entry>[
        for (final Entry e in own.snapshot!.entries)
          if (e.sourceRef == sent.id) e,
      ];
      final Finder from = find.ancestor(
        of: find.text('Desde'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await f.tapTip('Por revisar');
      await f.step(
        'El aviso de Bancolombia, «Transferiste \$150.000 a tu Nequi», espera '
        'como un gasto «Sin comercio» y sin cuenta; a diferencia de lo que '
        'llega, no ofrece «¿Viene de otra cuenta tuya?».',
      );
      await f.check(
        'Espera como gasto, sin cuenta ni atajo a transferencia',
        () {
          expect(sent.parsed.kind, EntryKind.expense);
          expect(sent.suggestion.accountId, isNull);
          expect(
            find.descendant(
              of: _card('Sin comercio'),
              matching: find.text('¿Viene de otra cuenta tuya?'),
            ),
            findsNothing,
          );
        },
      );
      await _tapOn(f, 'Sin comercio', 'Editar');
      await f.tap('Transferencia');
      await f.step(
        'En «Revisar movimiento», «Transferencia» cambia la hoja: «Desde» '
        'queda vacío, «Hacia» propone Nequi y el botón dice «Registrar '
        'transferencia».',
      );
      await f.check('Propone Nequi como destino y deja vacío el origen', () {
        expect(_menuShows('Hacia', 'Nequi'), isTrue);
        expect(
          find.descendant(of: from, matching: find.text('Bancolombia')),
          findsNothing,
        );
      });
      await f.tapFound(find.text('Registrar transferencia'));
      await f.reveal(find.text('Elige la cuenta.'));
      await f.step(
        'Sin «Desde», «Registrar transferencia» no guarda: el campo se pone '
        'en rojo con «Elige la cuenta.»',
      );
      await f.check('Sin origen no se registró nada', () {
        expect(legs(), isEmpty);
        expect(own.pendingInbox.map((InboxItem i) => i.id), contains(sent.id));
      });
      await f.tapFound(from);
      await f.tapFound(find.text('Bancolombia').last);
      await f.tapFound(find.text('Registrar transferencia'));
      await f.step(
        'Con Bancolombia en «Desde»: «Transferencia registrada.», con '
        '«Deshacer», y el aviso salió de Por revisar.',
      );
      Future<void> movedOnce() async {
        expect(legs(), hasLength(2));
        expect(
          own.balances[bank.id]!.amount,
          bankBefore - Decimal.parse('150000'),
        );
        expect(
          own.balances[nequi.id]!.amount,
          nequiBefore + Decimal.parse('150000'),
        );
        expect(own.ledger!.freeUntilPayday, free);
      }

      await f.check(
        'Salieron \$150.000 de Bancolombia y llegaron a Nequi; lo que puedes '
        'gastar no cambió',
        movedOnce,
      );
      await f.check('Pasar plata entre tus cuentas no enseña reglas', () {
        expect(own.captureSettings.rules.length, rules);
      });
      await _undoFromNotice(f);
      await f.step(
        'Con «Deshacer» la transferencia se borra de las dos cuentas y el '
        'aviso vuelve a esperar, como antes.',
      );
      await f.check('Deshacer borró los dos lados y el aviso espera', () {
        expect(legs(), isEmpty);
        expect(own.balances[bank.id]!.amount, bankBefore);
        expect(own.balances[nequi.id]!.amount, nequiBefore);
        expect(own.pendingInbox.map((InboxItem i) => i.id), contains(sent.id));
      });
      await _tapOn(f, 'Sin comercio', 'Editar');
      await f.tap('Transferencia');
      await f.tapFound(from);
      await f.tapFound(find.text('Bancolombia').last);
      await f.tapFound(find.text('Registrar transferencia'));
      await _hideNotice(f);
      await f.check('Registrada otra vez, una sola vez', movedOnce);
      // Then Nequi's own alert for the same money arrives.
      await f.tester.runAsync(
        () => own.capture.ingest(<CaptureEvent>[
          _nequi(r'Recibiste $150.000 de Diego Lopez', 9, 52),
        ]),
      );
      await settle(f.tester);
      await f.reveal(_card('Diego Lopez'));
      await f.step(
        'Al rato llega el aviso de Nequi por la misma plata: queda en '
        '«Posibles repetidos», no como un ingreso de \$150.000 más.',
      );
      await f.check('El aviso de Nequi es la llegada que ya está', () {
        final InboxItem got = own.inbox.firstWhere(
          (InboxItem i) => i.event.text.contains('Diego Lopez'),
        );
        expect(got.status, InboxStatus.duplicate);
        final Entry arrived = legs().firstWhere(
          (Entry e) => e.accountId == nequi.id,
        );
        expect(got.duplicateOf, arrived.id);
        expect(
          own.pendingInbox.where((InboxItem i) => i.id == got.id),
          isEmpty,
        );
      });
      await _openMenu(f, 'Diego Lopez');
      await f.tap('Descartar');
      await f.back();
      await f.step(
        'Inicio: sigue ${_headline(own)}; los \$150.000 pasaron de '
        'Bancolombia a Nequi una sola vez.',
      );
      await f.check('Nequi tiene los \$150.000 una sola vez', movedOnce);
    },
  ),
  AppFlow(
    '07-16-dolares-a-mi-cuenta-en-pesos',
    'Pasar dólares a mi cuenta en pesos',
    area: 'Por revisar',
    goal:
        'Pasé US\$100 de mi cuenta en dólares a Bancolombia y el banco me '
        'avisó cuántos pesos llegaron: quiero registrarlo como un cambio entre '
        'mis cuentas, no como un ingreso.',
    data: fullAccount,
    manual: <String>[
      'La tasa del día llega por la red: en el teléfono, revisar que «Monto» '
          'proponga los dólares que de verdad salieron.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final int free = own.ledger!.freeUntilPayday;
      final Account bank = _account(own, 'Bancolombia');
      final Account dollars = _account(own, 'Cuenta en dólares');
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      final Decimal dollarsBefore = own.balances[dollars.id]!.amount;
      await f.tapTip('Por revisar');
      await _paste(f, r'Bancolombia: Recibiste $331.284 de GLOBAL66 COLOMBIA');
      await _hideNotice(f);
      await f.top();
      final InboxItem arrived = own.pendingInbox.firstWhere(
        (InboxItem i) => i.event.text.contains('GLOBAL66'),
      );
      final String payee = _payee(arrived);
      await f.step(
        'Llegaron \$331.284 a Bancolombia desde Global66: la tarjeta lo trata '
        'como un ingreso, sin cuenta, y ofrece «¿Viene de otra cuenta tuya?».',
      );
      await _tapOn(f, payee, '¿Viene de otra cuenta tuya?');
      await f.step(
        'La hoja abre como «Transferencia» con los \$331.284 en «Monto», pero '
        'propone Bancolombia → Nequi: no sabe a cuál de las dos de '
        'Bancolombia llegó.',
      );
      final Finder from = find.ancestor(
        of: find.text('Desde'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      final Finder to = find.ancestor(
        of: find.text('Hacia'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await f.tapFound(to);
      await f.tapFound(find.text('Bancolombia').last);
      await f.tapFound(from);
      await f.tapFound(find.text('Cuenta en dólares').last);
      await f.step(
        'Con «Desde» en la cuenta en dólares y «Hacia» en Bancolombia aparece '
        '«Llegó»: los \$331.284 del aviso quedan ahí y «Monto» propone '
        'US\$100 por la tasa del día.',
      );
      String field(String label) => f.tester
          .widget<TextField>(find.widgetWithText(TextField, label))
          .controller!
          .text;
      await f.check('Lo que dice el aviso es lo que llegó a Bancolombia', () {
        expect(field('Llegó'), '331.284');
        expect(field('Monto'), '100');
      });
      await f.tapFound(find.text('Registrar transferencia'));
      await f.step(
        'Registrada: «Transferencia registrada.» y el aviso salió de Por '
        'revisar.',
      );
      await f.check(
        'Salieron US\$100 de la cuenta en dólares y llegaron \$331.284',
        () {
          expect(
            own.balances[dollars.id]!.amount,
            dollarsBefore - Decimal.parse('100'),
          );
          expect(
            own.balances[bank.id]!.amount,
            bankBefore + Decimal.parse('331284'),
          );
        },
      );
      final int up = free + own.ledger!.minor(331284);
      await f.check(
        'Lo que puedes gastar subió a ${_cop(own, up)}: los dólares no '
        'eran de uso diario',
        () => expect(own.ledger!.freeUntilPayday, up),
      );
      await _hideNotice(f);
      await f.back();
      await f.step(
        'Inicio: ahora ${_headline(own)}; los pesos que llegaron ya cuentan '
        'en «En tus cuentas de uso diario».',
      );
      await f.check(
        '«En tus cuentas de uso diario» suma los pesos que llegaron',
        () => _cardDebtShown(f, own),
      );
    },
  ),
  AppFlow(
    '08-01-importar-el-extracto-del-banco',
    'Importar el extracto del banco',
    area: 'Importar extracto',
    goal:
        'Bajé el extracto de Bancolombia y quiero traer lo que no anoté, sin '
        'que se dupliquen los que ya tenía.',
    data: fullAccount,
    manual: <String>[
      '«Elegir archivo» abre el selector de archivos del sistema: probar con '
          'un CSV, un Excel (.xlsx) y un PDF reales del banco.',
      'Un PDF que el teléfono no logra leer ofrece «Leer con Gemini», que '
          'necesita la red y gasta una pregunta del día.',
      'Compartir el extracto a Quincena desde otra app (Archivos, el correo) '
          'y que abra directo en la revisión.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final Account visa = _account(own, 'Visa');
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      final Decimal visaBefore = own.balances[visa.id]!.amount;
      final int free = own.ledger!.freeUntilPayday;
      await f.tapTip('Ajustes');
      await f.tap('Importar extracto');
      await f.step(
        'Ajustes › «Importar extracto»: lee CSV, Excel o PDF en el teléfono '
        'y todo se revisa antes de guardar. «Elegir archivo» abre el selector '
        'del sistema.',
      );
      await f.back();
      final StatementRead read = await _openStatement(f, _bankCsv);
      await f.page(
        'El extracto leído va a Bancolombia, la primera cuenta: 7 '
        'movimientos, 4 nuevos y marcados, 3 que ya estaban sin marcar.',
      );
      final List<ImportCandidate> all = await _prepared(f, bank, read);
      await f.check('La pantalla cuenta lo mismo que halló el importador', () {
        expect(all, hasLength(7));
        expect(all.where((ImportCandidate c) => c.proposed), hasLength(4));
        expect(all.where((ImportCandidate c) => c.recorded), hasLength(3));
        expect(
          f.screenText,
          contains(
            '4 nuevos · 3 ya estaban · 2 sin categoría · 1 entre tus cuentas',
          ),
        );
      });
      await f.check(
        'La nómina, Uber y el Éxito ya estaban: van sin marcar',
        () {
          expect(
            <String>[
              for (final ImportCandidate c in all)
                if (c.recorded) c.payee,
            ],
            unorderedEquals(<String>[
              'Nomina DL Soft',
              'Uber Trip',
              'Exito Laureles',
            ]),
          );
          expect(_ticked(f, 'Exito Laureles'), isFalse);
          expect(_ticked(f, 'Claro'), isTrue);
        },
      );
      final Decimal out = <Decimal>[
        for (final ImportCandidate c in all)
          if (c.proposed) c.line.amount,
      ].fold(Decimal.zero, (Decimal a, Decimal b) => a + b);
      await f.check('Salen ${_money(out)}: lo que suman las 4 nuevas', () {
        expect(out, Decimal.parse('-799900'));
        expect(
          f.screenText,
          contains('4 seleccionados · salen ${_money(out)}'),
        );
      });
      await f.check('El pago de la Visa va como movimiento hacia la Visa', () {
        final ImportCandidate c = all.firstWhere(
          (ImportCandidate c) => c.cardPayment,
        );
        expect(c.kind, EntryKind.transfer);
        expect(c.otherAccountId, visa.id);
        expect(f.screenText, contains('Pago de tu tarjeta Visa'));
      });
      await f.reveal(find.text('Sumarlos a mi saldo'));
      await f.check('Como son de antes del 3 oct, tu saldo ya los incluye', () {
        expect(
          f.screenText,
          contains(
            '4 movimientos son de antes del 3 de octubre, cuando escribiste '
            'el saldo de Bancolombia.',
          ),
        );
        expect(
          f.screenText,
          contains(
            'El saldo de Bancolombia sigue en ${_money(bankBefore)}: ya '
            'incluía estos movimientos.',
          ),
        );
      });
      await f.tap('Importar 4 movimientos');
      await f.waitFor(find.text('Se importaron 4 movimientos.'));
      await f.page(
        '«Se importaron 4 movimientos.»: el saldo de Bancolombia sigue '
        'igual, el pago de la Visa no cuenta como gasto y 2 piden categoría.',
      );
      await f.check('Quedaron los 4, cada uno como debía', () {
        final List<Entry> made = _imported(own, bank);
        expect(made, hasLength(4));
        expect(
          made.firstWhere((Entry e) => e.payee == 'Claro').category,
          'utilities',
        );
        expect(
          made.firstWhere((Entry e) => e.payee == 'Juan Perez').category,
          'other',
        );
        final Entry card = made.firstWhere((Entry e) => e.transferId != null);
        expect(card.amount, Decimal.parse('-480000'));
        expect(
          own.snapshot!.entries
              .firstWhere(
                (Entry e) => e.transferId == card.transferId && e.id != card.id,
              )
              .accountId,
          visa.id,
        );
      });
      await f.check('Los saldos de Bancolombia y la Visa no se movieron', () {
        expect(own.balances[bank.id]!.amount, bankBefore);
        expect(own.balances[visa.id]!.amount, visaBefore);
      });
      await f.tapFound(find.text('Juan Perez'));
      await f.tap('Salidas');
      await f.step(
        'Tocar «Juan Perez» abre el movimiento para darle categoría: aquí, '
        'Salidas.',
      );
      await f.tap('Guardar');
      await f.step(
        'Guardado: Juan Perez sale de la lista y ahora dice «Uno quedó sin '
        'categoría: tócalo para ponérsela.»',
      );
      await f.check('Juan Perez quedó en Salidas', () {
        expect(
          _imported(
            own,
            bank,
          ).firstWhere((Entry e) => e.payee == 'Juan Perez').category,
          'leisure',
        );
        expect(f.shows('Juan Perez'), isFalse);
      });
      await f.tap('Listo');
      await f.back();
      await f.step(
        'Inicio: sigue ${_headline(own)}; lo importado ya estaba en el saldo '
        'que escribiste.',
      );
      await f.check('Lo que puedes gastar no cambió', () {
        expect(own.ledger!.freeUntilPayday, free);
      });
      await f.check('«Lo que debes en tarjetas» es lo que dice la Visa', () {
        _cardDebtShown(f, own);
      });
      final int saved = _imported(own, bank).length;
      final StatementRead again = await _openStatement(f, _bankCsv);
      await f.page(
        'El mismo archivo otra vez: «Ninguno nuevo», cada línea dice «Ya '
        'importado» o «Ya registrado» y el botón dice «Nada para importar».',
      );
      await f.check('Otra vez el mismo archivo no trae nada nuevo', () async {
        final List<ImportCandidate> twice = await _prepared(f, bank, again);
        expect(twice.where((ImportCandidate c) => c.proposed), isEmpty);
        expect(
          twice.where((ImportCandidate c) => c.importedBefore),
          hasLength(4),
        );
        expect(
          f.tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Nada para importar'),
              )
              .onPressed,
          isNull,
        );
      });
      await f.tap('Nada para importar');
      await f.check('Y no se guardó nada otra vez', () {
        expect(_imported(own, bank), hasLength(saved));
      });
    },
  ),
  AppFlow(
    '08-02-revisar-linea-por-linea',
    'Revisar el extracto línea por línea',
    area: 'Importar extracto',
    goal:
        'Antes de importar quiero corregir lo que el extracto no dice bien: '
        'un retiro que fue a mi efectivo, una categoría que falta y lo que '
        'ya había anotado.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final Account cash = _account(own, 'Efectivo');
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      final Decimal cashBefore = own.balances[cash.id]!.amount;
      await f.tap('Cuentas');
      await f.tap('Banco · Bancolombia');
      await f.tapTip('Importar extracto');
      await f.step(
        'En la cuenta Bancolombia, el ícono «Importar extracto» de arriba '
        'abre la misma pantalla, con «Elegir archivo».',
      );
      await f.back();
      await _openStatement(f, _bankCsv, account: 'Bancolombia');
      await f.tapTip('Invertir entradas y salidas');
      await f.step(
        '«Invertir entradas y salidas» (arriba) voltea los signos, por si el '
        'banco los trae al revés: ahora la nómina saldría y el resto entraría.',
      );
      await f.check('Volteado, la nómina sale y lo demás entra', () {
        expect(
          f.screenText,
          contains(
            '7 seleccionados · entran '
            '${_money(Decimal.parse('1002900'), signed: true)} · salen '
            '${_money(Decimal.parse('-2400000'))}',
          ),
        );
      });
      await f.tapTip('Invertir entradas y salidas');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Nequi · COP').last);
      await f.step(
        'En «Cuenta» se elige Nequi: allá no hay nada de esto, así que los 7 '
        'quedan nuevos y marcados.',
      );
      await f.check('En Nequi los 7 son nuevos', () {
        expect(f.screenText, contains('7 nuevos · ninguno repetido'));
      });
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tapFound(find.text('Bancolombia · COP').last);
      await f.tapFound(_lineBox('Exito Laureles'));
      await f.step(
        'De vuelta en Bancolombia, marcar a mano «Exito Laureles», que ya '
        'estaba, avisa abajo: «Marcaste 1 que ya estaba: se contaría dos '
        'veces.»',
      );
      await f.check('El aviso y el botón cuentan el repetido', () {
        expect(
          f.shows('Marcaste 1 que ya estaba: se contaría dos veces.'),
          isTrue,
        );
        expect(f.shows('Importar 5 movimientos'), isTrue);
      });
      await f.tapFound(_lineBox('Exito Laureles'));
      await f.tap('Quitar todos');
      await f.step(
        '«Quitar todos» desmarca todo: «Nada seleccionado», el botón queda '
        'apagado en «Nada para importar» y arriba se ofrece «Marcar los '
        'nuevos».',
      );
      await f.check('Sin nada marcado no se puede importar', () {
        expect(f.screenText, contains('Nada seleccionado'));
        expect(
          f.tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Nada para importar'),
              )
              .onPressed,
          isNull,
        );
        expect(
          f.shows('Marcaste 1 que ya estaba: se contaría dos veces.'),
          isFalse,
        );
      });
      await f.tap('Marcar los nuevos');
      await f.check('«Marcar los nuevos» marca solo los 4 nuevos', () {
        expect(f.shows('Importar 4 movimientos'), isTrue);
        expect(_ticked(f, 'Exito Laureles'), isFalse);
      });
      await f.tapFound(find.text('Cajero'));
      await f.step(
        'Tocar «Cajero» abre «Revisar movimiento»: el retiro por −\$200.000, '
        '«RETIRO CAJERO» como lo dice el extracto, y Gasto sin categoría.',
      );
      await f.tap('Transferencia');
      await f.step(
        'Un retiro no es un gasto: con «Transferencia» aparece «Hacia», que '
        'para este retiro en cajero propone la Visa.',
      );
      await f.check('Para el retiro propone la tarjeta, no el efectivo', () {
        expect(
          find.descendant(
            of: find.byType(DropdownButtonFormField<String>).last,
            matching: find.text('Visa'),
          ),
          findsOneWidget,
        );
      });
      await f.tapFound(find.byType(DropdownButtonFormField<String>).last);
      await f.tapFound(find.text('Efectivo').last);
      await f.step('«Hacia» cambiado a Efectivo, adonde fue la plata.');
      await f.tap('Guardar');
      await f.step(
        'Guardado: la línea de Cajero dice «Pasa a Efectivo», con el ícono de '
        'los movimientos entre tus cuentas.',
      );
      await f.check('El retiro quedó como paso a Efectivo', () async {
        expect(f.screenText, contains('Pasa a Efectivo'));
        await f.top();
        expect(
          f.screenText,
          contains(
            '4 nuevos · 3 ya estaban · 1 sin categoría · 2 entre tus cuentas',
          ),
        );
      });
      await f.tapFound(find.text('Juan Perez'));
      await f.tap('Ingreso');
      await f.step(
        'En Juan Perez, «Ingreso» cambia el signo a +\$30.000 y muestra las '
        'categorías de ingresos.',
      );
      await f.back();
      await f.check('Cerrar la hoja sin guardar deja la línea como estaba', () {
        expect(f.screenText, contains('Sin categoría'));
        expect(
          f.screenText,
          contains('salen ${_money(Decimal.parse('-799900'))}'),
        );
      });
      await f.tapFound(find.text('Juan Perez'));
      await f.tap('Salidas');
      await f.tap('Guardar');
      await f.step(
        'Abierta otra vez, con Salidas y «Guardar», Juan Perez ya no dice '
        '«Sin categoría».',
      );
      await f.check('Ya no queda nada sin categoría', () {
        expect(f.screenText, isNot(contains('sin categoría')));
      });
      await f.tap('Importar 4 movimientos');
      await f.waitFor(find.text('Se importaron 4 movimientos.'));
      await f.step(
        'Importado tal como se revisó: «Todos quedaron con su categoría.» y 2 '
        'quedaron como movimientos entre tus cuentas.',
      );
      await f.check('El retiro llegó a Efectivo y Juan Perez a Salidas', () {
        final List<Entry> made = _imported(own, bank);
        final Entry withdrawal = made.firstWhere(
          (Entry e) => e.amount == Decimal.parse('-200000'),
        );
        expect(withdrawal.transferId, isNotNull);
        expect(
          own.snapshot!.entries
              .firstWhere(
                (Entry e) =>
                    e.transferId == withdrawal.transferId &&
                    e.id != withdrawal.id,
              )
              .accountId,
          cash.id,
        );
        expect(
          made.firstWhere((Entry e) => e.payee == 'Juan Perez').category,
          'leisure',
        );
      });
      await f.check(
        'Ya estaban en los saldos: ni Bancolombia ni Efectivo cambiaron',
        () {
          expect(own.balances[bank.id]!.amount, bankBefore);
          expect(own.balances[cash.id]!.amount, cashBefore);
        },
      );
    },
  ),
  AppFlow(
    '08-03-sumar-los-viejos-a-mi-saldo',
    'Sumar al saldo lo que trae el extracto',
    area: 'Importar extracto',
    goal:
        'El saldo que escribí en Bancolombia era de antes de estos '
        'movimientos: quiero que el extracto lo actualice.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final Account visa = _account(own, 'Visa');
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      final Decimal visaBefore = own.balances[visa.id]!.amount;
      final int free = own.ledger!.freeUntilPayday;
      await _openStatement(f, _bankCsv, account: 'Bancolombia');
      await f.reveal(find.text('Sumarlos a mi saldo'));
      await f.step(
        'Al final de la lista: «4 movimientos son de antes del 3 de octubre», '
        'con «Mi saldo ya los incluye (recomendado)» marcado.',
      );
      await f.tap('Sumarlos a mi saldo');
      final Decimal after = bankBefore - Decimal.parse('799900');
      await f.step(
        'Con «Sumarlos a mi saldo», abajo dice «Saldo de Bancolombia: '
        '${_money(bankBefore)} → ${_money(after)}».',
      );
      await f.check('El saldo que anuncia es el de hoy menos lo que sale', () {
        expect(
          f.screenText,
          contains(
            'Saldo de Bancolombia: ${_money(bankBefore)} → ${_money(after)}',
          ),
        );
      });
      await f.tap('Mi saldo ya los incluye (recomendado)');
      await f.check(
        'Volver a «Mi saldo ya los incluye» deja el saldo igual',
        () {
          expect(
            f.screenText,
            contains(
              'El saldo de Bancolombia sigue en ${_money(bankBefore)}: ya '
              'incluía estos movimientos.',
            ),
          );
        },
      );
      await f.tap('Sumarlos a mi saldo');
      await f.tap('Importar 4 movimientos');
      await f.waitFor(find.text('Se importaron 4 movimientos.'));
      await f.step(
        'Importados: el resultado repite «Saldo de Bancolombia: '
        '${_money(bankBefore)} → ${_money(after)}».',
      );
      await f.check('Bancolombia bajó exactamente \$799.900', () {
        expect(own.balances[bank.id]!.amount, after);
      });
      await f.check('Lo que debes en la Visa bajó \$480.000', () {
        expect(
          own.balances[visa.id]!.amount,
          visaBefore + Decimal.parse('480000'),
        );
      });
      await f.tap('Listo');
      final int spent = own.ledger!.minor(89900 + 30000 + 200000);
      await f.step(
        'Inicio: ahora ${_headline(own)}. El pago de la Visa no cambia eso: '
        'baja el banco y «Lo que debes en tarjetas» baja a '
        '${pesos(-_owed(own))}.',
      );
      await f.check(
        'Lo que puedes gastar bajó ${_cop(own, spent)}, sin el pago de la Visa',
        () => expect(own.ledger!.freeUntilPayday, free - spent),
      );
      await f.check(
        '«Lo que debes en tarjetas» bajó a lo que dice la Visa ahora',
        () => _cardDebtShown(f, own),
      );
    },
  ),
  AppFlow(
    '08-04-ajustar-al-saldo-del-extracto',
    'Dejar la cuenta con el saldo del extracto',
    area: 'Importar extracto',
    goal:
        'El extracto trae el saldo de cada día y quiero que Bancolombia '
        'quede con el mismo saldo que dice el banco.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final Decimal before = own.balances[bank.id]!.amount;
      final StatementRead read = await _openStatement(
        f,
        _balanceCsv,
        account: 'Bancolombia',
      );
      await f.page(
        'Este extracto trae saldo: abajo dice «Según el extracto, el 3 de '
        'octubre tenías \$865.100.» y lo que Quincena tendría ese día.',
      );
      final List<ImportCandidate> all = await _prepared(f, bank, read);
      await f.check('Halla el saldo final del extracto', () {
        final ClosingBalance? closing = StatementImporter.closing(bank, all);
        expect(closing?.amount, Decimal.parse('865100'));
        expect(
          f.screenText,
          contains('Según el extracto, el 3 de octubre tenías \$865.100.'),
        );
        expect(f.screenText, contains('Quincena tendría'));
      });
      await f.tapFound(
        find.widgetWithText(SwitchListTile, 'Ajustar al saldo del extracto'),
      );
      await f.step(
        'Con «Ajustar al saldo del extracto» prendido, abajo dice que el '
        'saldo de Bancolombia quedará en \$865.100.',
      );
      await f.check('Promete dejar Bancolombia en \$865.100', () {
        expect(
          f.screenText,
          contains(
            'Saldo de Bancolombia: ${_money(before)} → '
            '${_money(Decimal.parse('865100'))}',
          ),
        );
      });
      final Finder adjust = find.widgetWithText(
        SwitchListTile,
        'Ajustar al saldo del extracto',
      );
      await f.tapFound(adjust);
      await f.check('Apagado, solo resta lo nuevo: \$134.900', () {
        expect(
          f.screenText,
          contains(
            'Saldo de Bancolombia: ${_money(before)} → '
            '${_money(before - Decimal.parse('134900'))}',
          ),
        );
      });
      await f.tapFound(adjust);
      await f.tap('Importar 2 movimientos');
      await f.waitFor(find.text('Se importaron 2 movimientos.'));
      await f.step(
        'Importados D1 y Claro: el saldo de Bancolombia pasó a \$865.100, el '
        'mismo del extracto.',
      );
      await f.check('Bancolombia quedó con el saldo del extracto', () {
        expect(own.balances[bank.id]!.amount, Decimal.parse('865100'));
        expect(_imported(own, bank), hasLength(2));
      });
      await f.tap('Listo');
      await f.tap('Cuentas');
      await f.tap('Banco · Bancolombia');
      await f.step(
        'En la cuenta, el saldo dice \$865.100 y arriba están D1 y Claro, '
        'que llegaron del extracto.',
      );
      await f.check('La cuenta muestra el mismo saldo', () {
        expect(f.shows(_money(Decimal.parse('865100'))), isTrue);
      });
    },
  ),
  AppFlow(
    '08-05-importar-la-tarjeta',
    'Importar el extracto de la tarjeta',
    area: 'Importar extracto',
    goal:
        'Quiero traer las compras de la Visa que no anoté, y que el pago que '
        'le hice no cuente como un ingreso.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account visa = _account(own, 'Visa');
      final Account bank = _account(own, 'Bancolombia');
      final Decimal visaBefore = own.balances[visa.id]!.amount;
      final Decimal bankBefore = own.balances[bank.id]!.amount;
      final int free = own.ledger!.freeUntilPayday;
      final StatementRead read = await _openStatement(
        f,
        _cardCsv,
        account: 'Visa',
      );
      await f.page(
        'El extracto de la Visa trae las compras en positivo y la app las lee '
        'como deuda. Al pago le pregunta «¿De cuál de tus cuentas salió este '
        'pago?».',
      );
      final List<ImportCandidate> all = await _prepared(f, visa, read);
      await f.check('Las compras quedan como gastos y Falabella ya estaba', () {
        expect(
          all.firstWhere((ImportCandidate c) => c.payee == 'Rappi').line.amount,
          Decimal.parse('-35500'),
        );
        expect(
          all
              .firstWhere((ImportCandidate c) => c.payee == 'Falabella')
              .recorded,
          isTrue,
        );
      });
      await f.check('El pago no sabe de qué cuenta salió', () {
        final ImportCandidate pay = all.firstWhere(
          (ImportCandidate c) => c.cardPayment,
        );
        expect(pay.otherAccountId, isNull);
        expect(pay.kind, EntryKind.income);
        expect(
          f.screenText,
          contains('¿De cuál de tus cuentas salió este pago?'),
        );
      });
      await f.tapFound(find.text('SU Pago Gracias'));
      await f.tap('Transferencia');
      await f.step(
        'En su hoja, «Transferencia» pide «Desde» y propone Bancolombia: el '
        'pago salió de ahí.',
      );
      await f.tap('Guardar');
      await f.step(
        'Guardado: el pago dice «Viene de Bancolombia» y arriba explica que '
        'un pago de tarjeta no cuenta como gasto.',
      );
      await f.check('El pago quedó como movimiento desde Bancolombia', () {
        expect(f.screenText, contains('Viene de Bancolombia'));
        expect(
          f.screenText,
          contains(
            'Un pago de tarjeta pasa plata de una cuenta tuya a otra: no '
            'cuenta como gasto',
          ),
        );
      });
      await f.tap('Importar 3 movimientos');
      await f.waitFor(find.text('Se importaron 3 movimientos.'));
      await f.step(
        'Importados: «Lo que debes en Visa» va de un valor al mismo, porque '
        'tu saldo ya los incluía.',
      );
      await f.check('Ni la deuda de la Visa ni Bancolombia cambiaron', () {
        expect(own.balances[visa.id]!.amount, visaBefore);
        expect(own.balances[bank.id]!.amount, bankBefore);
      });
      await f.check('Netflix y Rappi quedaron como gastos de la Visa', () {
        final List<Entry> made = _imported(own, visa);
        expect(made, hasLength(3));
        final Entry netflix = made.firstWhere(
          (Entry e) => e.amount == Decimal.parse('-26900'),
        );
        expect(netflix.category, 'subscriptions');
        final Entry rappi = made.firstWhere(
          (Entry e) => e.amount == Decimal.parse('-35500'),
        );
        expect(rappi.category, 'restaurants');
        expect(made.where((Entry e) => e.payee == 'Falabella'), isEmpty);
      });
      await f.check(
        'Lo que puedes gastar no cambió: la deuda ya los incluía',
        () {
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      await f.check('El pago quedó como transferencia de Bancolombia', () {
        final Entry pay = _imported(
          own,
          visa,
        ).firstWhere((Entry e) => e.amount == Decimal.parse('480000'));
        expect(pay.transferId, isNotNull);
        expect(
          own.snapshot!.entries
              .firstWhere(
                (Entry e) => e.transferId == pay.transferId && e.id != pay.id,
              )
              .accountId,
          bank.id,
        );
      });
    },
  ),
  AppFlow(
    '08-06-archivo-vacio-y-tarjeta-que-falta',
    'Importar sin tener la tarjeta en la app',
    area: 'Importar extracto',
    goal:
        'Solo tengo mi cuenta de ahorros en la app: quiero importar su '
        'extracto, que trae el pago de una tarjeta, y saber qué pasa si el '
        'archivo no sirve.',
    data: _oneAccount,
    manual: <String>[
      'Un archivo que no es un extracto (una foto, un PDF protegido) muestra '
          '«No se pudo leer el archivo. Prueba con un CSV, un Excel (.xlsx) o '
          'un PDF.»',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final Decimal before = own.balances[bank.id]!.amount;
      await _openStatement(
        f,
        'Fecha;Descripción;Valor\n',
        until: find.text('No encontré movimientos en este archivo.'),
      );
      await f.step(
        'Un archivo sin movimientos: «No encontré movimientos en este '
        'archivo.» y «Elegir archivo» para probar con otro.',
      );
      await f.back();
      await _openStatement(f, _noCardCsv, account: 'Bancolombia');
      await f.step(
        'Arriba, en naranja: «Parece el pago de una tarjeta. Agrégala en '
        'Cuentas…». La línea «Tarjeta de Credito» va marcada como gasto en '
        'Créditos.',
      );
      await f.check('Avisa que falta la tarjeta', () {
        expect(
          f.screenText,
          contains('Parece el pago de una tarjeta. Agrégala en Cuentas'),
        );
      });
      await f.tapFound(_lineBox('Tarjeta de Credito'));
      await f.step(
        'Desmarcado el pago de la tarjeta, el botón ofrece «Seleccionar '
        'todos» y abajo quedan «2 seleccionados».',
      );
      await f.check('Quedan marcadas solo las 2 compras', () {
        expect(f.shows('Seleccionar todos'), isTrue);
        expect(f.shows('Importar 2 movimientos'), isTrue);
      });
      await f.tap('Seleccionar todos');
      await f.check('«Seleccionar todos» vuelve a marcar el pago', () {
        expect(_ticked(f, 'Tarjeta de Credito'), isTrue);
        expect(f.shows('Importar 3 movimientos'), isTrue);
        expect(f.shows('Quitar todos'), isTrue);
      });
      await f.tapFound(_lineBox('Tarjeta de Credito'));
      await f.tap('Importar 2 movimientos');
      await f.waitFor(find.text('Se importaron 2 movimientos.'));
      await f.step(
        'Importadas las 2 compras: el pago de la tarjeta no se guardó, y el '
        'saldo de Bancolombia sigue igual porque ya las incluía.',
      );
      await f.check('Se guardaron las compras y no el pago', () {
        final List<Entry> made = _imported(own, bank);
        expect(made, hasLength(2));
        expect(
          made.where((Entry e) => e.amount == Decimal.parse('-350000')),
          isEmpty,
        );
        expect(own.balances[bank.id]!.amount, before);
      });
    },
  ),
  AppFlow(
    '08-07-pago-de-una-de-dos-tarjetas',
    'Decir cuál de mis tarjetas pagué',
    area: 'Importar extracto',
    goal:
        'Tengo dos tarjetas y el extracto del banco solo dice «pago tarjeta '
        'crédito»: quiero decir que fue la Mastercard y que no cuente como '
        'gasto.',
    data: _twoCards,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _account(own, 'Bancolombia');
      final Account master = _account(own, 'Mastercard');
      final Decimal masterBefore = own.balances[master.id]!.amount;
      final StatementRead read = await _openStatement(
        f,
        _twoCardsCsv,
        account: 'Bancolombia',
      );
      await f.step(
        'El pago no nombra la tarjeta: la línea dice «¿Es el pago de una '
        'tarjeta tuya?» en naranja, y por ahora va como gasto.',
      );
      final List<ImportCandidate> all = await _prepared(f, bank, read);
      await f.check('Con dos tarjetas no adivina cuál', () {
        final ImportCandidate pay = all.firstWhere(
          (ImportCandidate c) => c.cardPayment,
        );
        expect(pay.otherAccountId, isNull);
        expect(pay.kind, EntryKind.expense);
        expect(f.screenText, contains('¿Es el pago de una tarjeta tuya?'));
      });
      await f.tapFound(find.text('Tarjeta Credito'));
      await f.tap('Transferencia');
      await f.step(
        'En su hoja, «Transferencia» propone en «Hacia» la primera tarjeta, '
        'la Visa.',
      );
      await f.tapFound(find.byType(DropdownButtonFormField<String>).last);
      await f.tapFound(find.text('Mastercard').last);
      await f.tap('Guardar');
      await f.step(
        'Con Mastercard elegida y guardada, la línea dice «Pago de tu tarjeta '
        'Mastercard» y ya no pregunta.',
      );
      await f.check('La línea va hacia la Mastercard', () {
        expect(f.screenText, contains('Pago de tu tarjeta Mastercard'));
        expect(
          f.screenText,
          isNot(contains('¿Es el pago de una tarjeta tuya?')),
        );
      });
      await f.tap('Importar 2 movimientos');
      await f.waitFor(find.text('Se importaron 2 movimientos.'));
      await f.step(
        'Importados: «Uno quedó como movimiento entre tus cuentas: no cuenta '
        'como gasto.»',
      );
      await f.check('El pago llegó a la Mastercard y su deuda no se movió', () {
        final Entry pay = _imported(
          own,
          bank,
        ).firstWhere((Entry e) => e.amount == Decimal.parse('-250000'));
        expect(
          own.snapshot!.entries
              .firstWhere(
                (Entry e) => e.transferId == pay.transferId && e.id != pay.id,
              )
              .accountId,
          master.id,
        );
        expect(own.balances[master.id]!.amount, masterBefore);
      });
      await f.tap('Listo');
      await f.step(
        'Inicio: «Lo que debes en tarjetas» dice ${pesos(-_owed(own))}, lo '
        'de la Visa y la Mastercard juntas.',
      );
      await f.check('Inicio suma lo que deben las dos tarjetas', () {
        _cardDebtShown(f, own);
      });
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

/// Diego's account, with Bancolombia's alert of money he sent to his own
/// Nequi.
Future<QuincenaStore> _sentToNequi() async {
  final QuincenaStore store = await fullAccount();
  await _caught(store, <CaptureEvent>[
    _bancolombia(r'Transferiste $150.000 a tu Nequi', 9, 50),
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
/// Nequi's alerts go to Nequi, and the card *1234, by a slip, to the Visa.
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
          CaptureRule(kind: RuleKind.card, key: '1234', target: id('Visa')),
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

/// Diego's account with a second card, a Mastercard from Davivienda.
Future<QuincenaStore> _twoCards() async {
  final QuincenaStore store = await fullAccount();
  await store.addAccount(
    name: 'Mastercard',
    kind: AccountKind.card,
    asset: Asset.cop,
    opening: Decimal.parse('-250000'),
    institution: 'Davivienda',
    creditLimit: Decimal.parse('2000000'),
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

/// What Inicio's big figure says now, in its own words.
String _headline(OwnController own) {
  final int free = own.ledger!.freeUntilPayday;
  return free < 0
      ? '«Te faltan ${_cop(own, -free)}»'
      : '«Puedes gastar ${_cop(own, free)}»';
}

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

/// Whether the menu labelled [label] in the open sheet shows [value].
bool _menuShows(String label, String value) => find
    .descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(DropdownButtonFormField<String>),
      ),
      matching: find.text(value),
    )
    .evaluate()
    .isNotEmpty;

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

/// Bancolombia's statement for the end of September: the salary, Uber and
/// the Éxito, already in the account; a bill, a transfer to someone, a
/// cash withdrawal and the Visa's payment, which are not.
const String _bankCsv =
    'Fecha;Descripción;Valor\n'
    '30/09/2026;ABONO NOMINA DL SOFT;2.400.000\n'
    '01/10/2026;COMPRA EN UBER TRIP;-15.600\n'
    '01/10/2026;PAGO PSE CLARO;-89.900\n'
    '01/10/2026;TRANSFERENCIA A JUAN PEREZ;-30.000\n'
    '02/10/2026;COMPRA EN EXITO LAURELES;-187.400\n'
    '02/10/2026;RETIRO CAJERO;-200.000\n'
    '02/10/2026;PAGO TARJETA VISA;-480.000\n';

/// A statement with the balance after each line, which ends today.
const String _balanceCsv =
    'Fecha;Descripción;Valor;Saldo\n'
    '02/10/2026;COMPRA EN EXITO LAURELES;-187.400;1.000.000\n'
    '03/10/2026;COMPRA EN D1;-45.000;955.000\n'
    '03/10/2026;PAGO PSE CLARO;-89.900;865.100\n';

/// The Visa's statement, purchases in positive as cards print them, and
/// the payment the bank received.
const String _cardCsv =
    'Fecha;Descripción;Valor\n'
    '29/09/2026;SU PAGO GRACIAS;-480.000\n'
    '30/09/2026;NETFLIX.COM;26.900\n'
    '02/10/2026;FALABELLA;42.900\n'
    '02/10/2026;RAPPI;35.500\n';

/// Bancolombia's statement with the payment of a card it does not name.
const String _twoCardsCsv =
    'Fecha;Descripción;Valor\n'
    '01/10/2026;PAGO PSE CLARO;-89.900\n'
    '02/10/2026;PAGO TARJETA CREDITO;-250.000\n';

/// A savings account's statement with a card's payment in it.
const String _noCardCsv =
    'Fecha;Descripción;Valor\n'
    '28/09/2026;COMPRA EN D1;-45.000\n'
    '29/09/2026;PAGO TARJETA DE CREDITO;-350.000\n'
    '30/09/2026;COMPRA EN FARMATODO;-27.500\n';

/// Opens the import with [csv] already read, the way a file comes back
/// from the system's picker, for [account] or, with none, for the first
/// one; then waits for [until], by default the review's lines.
Future<StatementRead> _openStatement(
  FlowRun f,
  String csv, {
  String? account,
  Finder? until,
}) async {
  final OwnController own = _shellOwn(f);
  final StatementRead read = readTable(parseCsv(csv));
  final String? id = account == null ? null : _account(own, account).id;
  unawaited(
    Navigator.of(
      f.tester.element(find.byType(OwnShell, skipOffstage: false)),
    ).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            StatementPage(own: own, accountId: id, statement: read),
      ),
    ),
  );
  await settle(f.tester);
  await f.waitFor(until ?? find.byType(Checkbox));
  return read;
}

/// The app's controller, also while a page covers the shell.
OwnController _shellOwn(FlowRun f) =>
    f.tester.widget<OwnShell>(find.byType(OwnShell, skipOffstage: false)).own;

/// What the importer makes of [read] for [account] right now.
Future<List<ImportCandidate>> _prepared(
  FlowRun f,
  Account account,
  StatementRead read,
) async => (await f.tester.runAsync(
  () => StatementImporter(_shellOwn(f).store).prepare(account, read),
))!;

/// What statements brought into [account].
List<Entry> _imported(OwnController own, Account account) => <Entry>[
  for (final Entry e in own.snapshot!.entries)
    if (e.accountId == account.id &&
        (e.sourceRef?.startsWith('statement:${account.id}:') ?? false))
      e,
];

/// The checkbox of the statement line named [name].
Finder _lineBox(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
  matching: find.byType(Checkbox),
);

/// Whether the statement line named [name] is checked to import.
bool _ticked(FlowRun f, String name) =>
    f.tester.widget<Checkbox>(_lineBox(name)).value ?? false;

/// Checks that Inicio's «Lo que debes en tarjetas» is what the cards owe
/// now, and that the money in the everyday accounts is what they hold.
void _cardDebtShown(FlowRun f, OwnController own) {
  final double owed = _owed(own);
  var daily = Decimal.zero;
  for (final Account a in own.accounts) {
    if (a.spendable && a.asset == Asset.cop && a.kind != AccountKind.card) {
      daily += own.balances[a.id]!.amount;
    }
  }
  expect(own.spendableCardDebt, own.ledger!.minor(owed));
  expect(f.screenText, contains(pesos(-owed)));
  expect(
    own.ledger!.balance + own.spendableCardDebt,
    own.ledger!.minor(daily.toDouble()),
  );
}

/// What the everyday cards owe now, by their balances, in pesos.
double _owed(OwnController own) {
  var owed = Decimal.zero;
  for (final Account a in own.accounts) {
    if (a.spendable && a.asset == Asset.cop && a.kind == AccountKind.card) {
      owed -= own.balances[a.id]!.amount;
    }
  }
  return owed.toDouble();
}

/// [amount] in pesos the way the import writes it, with a `+` on what
/// comes in when [signed].
String _money(Decimal amount, {bool signed = false}) =>
    formatAmount(amount, Asset.cop, signed: signed);
