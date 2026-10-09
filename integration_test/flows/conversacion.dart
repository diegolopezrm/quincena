// Flows of La demo y sus respuestas (11), Preguntar con tus cuentas (12).
import 'dart:async';
import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show ChatMessage, Surface;
import 'package:quincena/agent/catalog.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/ai/allowance.dart';
import 'package:quincena/ai/reports.dart' show ReportReason;
import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:quincena/app.dart';
import 'package:quincena/catalog/budget_meter.dart';
import 'package:quincena/catalog/goal_planner.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/example_prices.dart';
import 'package:quincena/data/ledger.dart' show Goal, Ledger, Movement;
import 'package:quincena/data/seed.dart';
import 'package:quincena/domain/records.dart' show Account, Entry;
import 'package:quincena/format/dates.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/functions/money_functions.dart'
    show arrivalMonth, monthlyNeeded;
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/tokens.dart';
import 'package:quincena/ui/ask_bar.dart';
import 'package:quincena/ui/conversation.dart';
import 'package:quincena/ui/home_page.dart';
import 'package:quincena/ui/own/ask_page.dart';
import 'package:quincena/ui/own/gemini_note_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/ui/own/onboarding_page.dart';
import 'package:quincena/ui/welcome.dart';

import '../../test/own_flow_test.dart' show settle;
import '../../test_screens/accounts.dart' show screensNow;
import '../tour.dart';
import 'flow.dart';

const String _demoArea = 'La cuenta de ejemplo';
const String _askArea = 'Preguntar con tus cuentas';

final List<AppFlow> conversacionFlows = <AppFlow>[
  AppFlow(
    '11-01-entrar-a-la-demo',
    'Entrar al ejemplo desde la primera pantalla',
    area: _demoArea,
    goal:
        'Antes de poner mis cuentas quiero ver cómo funciona la app con '
        'datos de ejemplo.',
    manual: <String>[
      'Con el teclado del teléfono, la tecla de enviar manda la pregunta y '
          'el teclado se cierra.',
    ],
    (FlowRun f) async {
      await f.step(
        'Primera pantalla: «Con mis cuentas» o «Con datos de ejemplo», y '
        'abajo la nota de que todo se guarda solo en este dispositivo.',
      );
      await f.tap('Con datos de ejemplo');
      final Ledger mine = f.own.ledger!;
      final String free = pesos(mine.major(mine.freeUntilPayday));
      await f.page(
        'Toca «Con datos de ejemplo»: abre toda la app con la cuenta de '
        'Valentina. Arriba, «Cuenta de ejemplo de Valentina» y «Usar mis '
        'cuentas»; en Inicio, lo que puede gastar, lo que hay por hacer y '
        'sus cuentas.',
      );
      await f.check(
        'La app recuerda el ejemplo y abre en él la próxima vez',
        () async => expect(await _setting(f, 'app.mode'), 'demo'),
      );
      await f.check('Inicio dice que Valentina puede gastar $free', () {
        expect(f.own.example, isTrue);
        expect(_said(f), contains(free));
      });
      await f.check(
        'Nada del ejemplo queda en la base de datos de la persona',
        () async {
          expect(await f.tester.runAsync(_store(f).profile), isNull);
          expect(await f.tester.runAsync(_store(f).entries), isEmpty);
        },
      );
      await f.toConversation();
      final Session s = _demo(f);
      final Ledger ledger = s.ledger;
      await f.page(
        'Más abajo en Inicio, «Otra pregunta» abre la conversación del '
        'ejemplo: arriba dice «DEMO» y la tarjeta dice lo mismo que Inicio, '
        'con cinco preguntas debajo.',
      );
      await f.check(
        'La conversación dice la misma cifra que Inicio, $free, de la misma '
        'historia',
        () {
          expect(ledger.freeUntilPayday, mine.freeUntilPayday);
          expect(ledger.balance, mine.balance);
          expect(_said(f), contains(free));
        },
      );
      await f.tap('¿De dónde sale?');
      await f.page(
        'Toca «¿De dónde sale?»: una hoja resta de lo que hay hoy cada pago '
        'que vence hasta el 15 de octubre, y dice lo que supone.',
      );
      final String held = pesos(ledger.major(ledger.balance));
      final String due = pesos(ledger.major(-ledger.committedUntilPayday));
      await f.check('La hoja resta $due de $held y llega a $free, la cifra de '
          'la tarjeta', () {
        final String said = _said(f);
        expect(said, contains(held));
        expect(said, contains(due));
        expect(said, contains('Puedes gastar hasta el 15 de octubre'));
        expect(
          ledger.balance - ledger.committedUntilPayday,
          ledger.freeUntilPayday,
        );
      });
      await f.back();
      // Untouched, the ask bar turns its hint to one of the questions.
      await f.tester.pump(AskBar.turn);
      await settle(f.tester);
      await f.step(
        'Sin tocar nada, la barra de abajo cambia su texto cada pocos '
        'segundos por una pregunta de ejemplo, cortada con «…» si es larga.',
      );
      await f.check(
        'La pista de la barra es una de las preguntas de la demo',
        () {
          final String hint = _hint(f);
          expect(hint, startsWith('Por ejemplo: '));
          expect(
            ScriptedAgent.starters,
            contains(hint.replaceFirst('Por ejemplo: ', '')),
          );
        },
      );
      await f.tapTip('Preguntar');
      await f.check('Con la barra vacía, la flecha no pregunta nada', () {
        expect(s.turns, isEmpty);
        expect(find.byType(Welcome), findsOneWidget);
      });
      const String own = '¿Cuánto gasté en el Éxito?';
      await f.tester.enterText(_askField, own);
      await settle(f.tester);
      await f.step(
        'Escribe una pregunta propia en la barra: «$own». La flecha verde '
        'de la derecha la envía.',
      );
      await f.tapTip('Preguntar');
      await _read(
        f,
        'La demo reconoce «gasté» y responde con el resumen de septiembre, '
        'sin decir que no sabe nada del Éxito.',
        most: 1,
      );
      await f.check('La pregunta quedó en la conversación y la barra se '
          'vació', () {
        expect(s.turns.single.question, own);
        expect(_askText(f), isEmpty);
      });
      const String unknown = '¿Cuánto debo en la tarjeta?';
      await f.tester.enterText(_askField, unknown);
      await f.tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(f.tester);
      await _read(
        f,
        'Envía «$unknown» con la tecla de enviar del teclado: no lo reconoce, '
        'dice «En el ejemplo respondo estas preguntas», que con tus cuentas '
        'Gemini responde lo que preguntes, y ofrece las cinco.',
        most: 2,
      );
      await f.check('Ofrece las cinco preguntas que sí sabe responder', () {
        expect(s.turns.last.question, unknown);
        expect(_said(f), contains('En el ejemplo respondo estas preguntas'));
        expect(_said(f), contains('Con tus propias cuentas, Gemini responde'));
        for (final String q in ScriptedAgent.starters) {
          expect(find.text(q), findsWidgets);
        }
      });
      await f.tap(ScriptedAgent.starters[2]);
      await _read(
        f,
        'Toca «¿Qué suscripciones tengo?» en la respuesta: la pregunta se '
        'hace sola y llega su respuesta debajo.',
        most: 1,
      );
      await f.check('Cada botón de la respuesta hace su pregunta', () {
        expect(s.turns, hasLength(3));
        expect(s.turns.last.question, ScriptedAgent.starters[2]);
      });
    },
  ),
  AppFlow(
    '11-02-en-que-se-fue-la-plata',
    'Ver en qué se fue la plata del mes',
    area: _demoArea,
    goal:
        'Quiero entender en qué se me fue la plata en septiembre y ver los '
        'pagos de lo que más subió.',
    demo: true,
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      final Ledger ledger = s.ledger;
      await f.tap(ScriptedAgent.starters[0]);
      await _read(
        f,
        'Toca «¿En qué se me fue la plata en septiembre?»: «Gastaste casi '
        'todo lo que entró», lo gastado contra agosto, cada categoría y lo '
        'que más cambió.',
      );
      final int spent = ledger.spentIn(2026, 9);
      final int income = ledger.incomeIn(2026, 9);
      final int before = ledger.spentIn(2026, 8);
      await f.check('Gastado en septiembre: ${pesos(ledger.major(spent))} de '
          '${pesos(ledger.major(income))}, como suma la cuenta', () {
        final String said = _said(f);
        expect(said, contains('Gastado en septiembre'));
        expect(said, contains(pesos(ledger.major(spent))));
        expect(said, contains(pesos(ledger.major(income))));
      });
      await f.check(
        'Contra agosto dice ${pesos(ledger.major(before))}, lo gastado ese mes',
        () => expect(_said(f), contains(pesos(ledger.major(before)))),
      );
      final List<Movement> meals = ledger.inCategory(
        Category.restaurants,
        2026,
        9,
      );
      final int eaten = ledger.spentOn(Category.restaurants, 2026, 9);
      await f.tap('Ver esos pagos');
      await _read(
        f,
        'Toca «Ver esos pagos»: aparece «Pediste ver los pagos» y los pagos '
        'de restaurantes de septiembre, del más grande al más pequeño.',
      );
      await f.check(
        'Son ${meals.length} pagos de restaurantes por '
        '${pesos(ledger.major(eaten))}, los de la cuenta',
        () => expect(
          _said(f),
          contains('${meals.length} pagos por ${pesos(ledger.major(eaten))}'),
        ),
      );
      final Movement biggest = meals.reduce(
        (Movement a, Movement b) => b.amount > a.amount ? b : a,
      );
      await f.check(
        'El primero es el más grande de la cuenta: ${biggest.merchant}, '
        '${pesos(ledger.major(biggest.amount))}',
        () {
          expect(
            _said(f),
            contains('El más grande fue ${biggest.merchant}, el '),
          );
          expect(find.text(biggest.merchant), findsWidgets);
        },
      );
      await f.check('Ver los pagos no cambia la cuenta', () {
        expect(ledger.spentIn(2026, 9), spent);
      });
    },
  ),
  AppFlow(
    '11-03-planear-el-viaje',
    'Planear la meta del viaje a Cartagena',
    area: _demoArea,
    goal:
        'Quiero saber cuánto apartar al mes para ir a Cartagena en diciembre '
        'y dejar ese plan guardado.',
    demo: true,
    manual: <String>[
      'La vibración suave al pasar por el monto que hace falta, moviendo el '
          'control con el dedo en un teléfono.',
    ],
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      final Goal goal = _trip(s);
      final int needed = monthlyNeeded(
        goal.target.toDouble(),
        goal.saved.toDouble(),
        _iso(goal.deadline),
      ).round();
      await f.tap(ScriptedAgent.starters[1]);
      await _read(
        f,
        'Toca «¿Me alcanza para ir a Cartagena en diciembre?»: dice cuánto '
        'hace falta al mes y abajo trae un control para simular.',
      );
      await f.check(
        'Dice que hacen falta ${pesos(needed)} al mes y que hoy aparta '
        '${pesos(goal.monthly)}',
        () {
          final String said = _said(f);
          expect(said, contains('necesitas ${pesos(needed)} al mes'));
          expect(said, contains('Hoy apartas ${pesos(goal.monthly)}'));
        },
      );
      final Finder slider = find.byType(Slider);
      await f.reveal(slider);
      await f.tester.drag(slider.last, const Offset(600, 0));
      await settle(f.tester);
      await f.step(
        'Arrastra el control al máximo: llega antes, dice «Simulación · hoy '
        'apartas …» y aparece «Volver a …» para deshacer.',
      );
      await f.check('El control quedó en ${pesos(800000)} y la meta sigue en '
          '${pesos(goal.monthly)}: simular no guarda', () {
        expect(_planner(f).monthly, 800000);
        expect(_planner(f).onTime, isTrue);
        expect(_trip(s).monthly, goal.monthly);
      });
      await f.tester.drag(slider.last, const Offset(-600, 0));
      await settle(f.tester);
      final String late = arrivalMonth(
        goal.target.toDouble(),
        goal.saved.toDouble(),
        100000,
      );
      await f.step(
        'Ahora al mínimo, ${pesos(100000)}: el aviso se pone ámbar, dice que '
        'llega en $late, después del ${dayMonth(goal.deadline)}.',
      );
      await f.check('Con ${pesos(100000)} al mes llega en $late, tarde', () {
        expect(_planner(f).monthly, 100000);
        expect(_planner(f).arrival, late);
        expect(_planner(f).onTime, isFalse);
      });
      await f.tap('Volver a ${pesos(goal.monthly)}');
      await f.step(
        'Toca «Volver a ${pesos(goal.monthly)}»: el control vuelve a lo que '
        'aparta hoy y la simulación desaparece.',
      );
      await f.check('El control volvió a ${pesos(goal.monthly)}', () {
        expect(_planner(f).monthly, goal.monthly);
      });
      await f.tapFound(find.byTooltip('Escribir monto'));
      await f.tester.enterText(_dialogField, '');
      await f.tap('Usar este monto');
      await f.step(
        'Toca el lápiz junto al monto: pide uno exacto. Vacío, «Usar este '
        'monto» responde «Escribe un monto mayor que cero.»',
      );
      await f.tap('Cancelar');
      await f.check('«Cancelar» cierra sin cambiar el monto', () {
        expect(find.byType(AlertDialog), findsNothing);
        expect(_planner(f).monthly, goal.monthly);
      });
      await f.tapFound(find.byTooltip('Escribir monto'));
      await f.tester.enterText(_dialogField, '455000');
      await settle(f.tester);
      await f.step(
        'Otra vez el lápiz: escribe 455.000, un monto que el control no '
        'alcanza con sus saltos de 10.000.',
      );
      await f.tap('Usar este monto');
      await f.step(
        'Toca «Usar este monto»: el plan queda en \$455.000 y dice en qué mes '
        'llega con ese aporte.',
      );
      await f.check('El control quedó en ${pesos(455000)} exactos', () {
        expect(_planner(f).monthly, 455000);
      });
      await f.tap('Usar ${pesos(needed)} al mes');
      await f.step(
        'Toca «Usar ${pesos(needed)} al mes»: el control salta a lo justo '
        'para llegar a tiempo y el aviso se pone verde.',
      );
      await f.check(
        'El control quedó en ${pesos(needed)}, lo que hace falta',
        () {
          expect(_planner(f).monthly, needed);
        },
      );
      await f.tap('Guardar este plan');
      await _read(
        f,
        'Toca «Guardar este plan»: queda el recibo «Plan guardado» y la '
        'respuesta recuerda que Quincena no mueve la plata.',
      );
      await f.check('La meta quedó en ${pesos(needed)} al mes', () {
        expect(_trip(s).monthly, needed);
      });
      // A finger on the saved planner, which takes nothing more.
      final Finder kept = find.byType(Slider).first;
      await f.reveal(kept);
      await f.tester.drag(kept, const Offset(-300, 0), warnIfMissed: false);
      await settle(f.tester);
      await f.check('El control guardado ya no se mueve: sigue en '
          '${pesos(needed)}', () {
        expect(s.settledOf(s.turns.first.surfaceIds.single), isNotNull);
        expect(
          f.tester.widget<GoalPlanner>(find.byType(GoalPlanner).first).monthly,
          needed,
        );
        expect(_trip(s).monthly, needed);
        expect(_said(f), contains('Plan guardado · '));
      });
      await f.tap('Editar');
      await f.step(
        'Toca «Editar» en el recibo: el control se abre otra vez y el recibo '
        'se va hasta guardar de nuevo.',
      );
      await f.tapFound(find.byTooltip('Escribir monto'));
      await f.tester.enterText(_dialogField, '700000');
      await f.tap('Usar este monto');
      await f.tap('Guardar este plan');
      await _read(
        f,
        'Con \$700.000 y «Guardar este plan» otra vez: el plan nuevo '
        'reemplaza al anterior y sale su propia respuesta.',
        most: 1,
      );
      await f.check('La meta quedó en ${pesos(700000)}, no en las dos', () {
        expect(_trip(s).monthly, 700000);
        expect(find.textContaining('Plan guardado · '), findsOneWidget);
      });
      await _ask(f, ScriptedAgent.starters[1]);
      await _read(
        f,
        'Pregunta otra vez por Cartagena: ahora la respuesta parte del plan '
        'guardado y dice que sí llega antes del 20 de diciembre.',
        most: 1,
      );
      await f.check('La nueva respuesta parte de ${pesos(700000)} al mes', () {
        expect(
          _said(f),
          contains('Sí: con ${pesos(700000)} al mes llegas antes del'),
        );
      });
      await f.tap('Revisar suscripciones');
      await _read(
        f,
        'En «Podrías liberar…», «Revisar suscripciones» pregunta por las '
        'suscripciones, para ver qué soltar.',
        most: 1,
      );
      await f.check('El enlace hizo la pregunta de las suscripciones', () {
        expect(s.turns.last.question, ScriptedAgent.starters[2]);
      });
    },
  ),
  AppFlow(
    '11-04-cancelar-suscripciones',
    'Escoger qué suscripciones cancelar',
    area: _demoArea,
    goal:
        'Quiero ver lo que pago en suscripciones, escoger las que no uso y '
        'saber cuánto me ahorro.',
    demo: true,
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      final Ledger ledger = s.ledger;
      final int monthly = ledger.subscriptionsMonthly;
      await f.tap(ScriptedAgent.starters[2]);
      await _read(
        f,
        'Toca «¿Qué suscripciones tengo?»: cuánto paga al mes, cuáles no usa '
        'hace más de un mes y una casilla por cada una.',
      );
      await f.check(
        'Dice que paga ${pesos(ledger.major(monthly))} al mes, la suma de '
        'sus suscripciones',
        () => expect(_said(f), contains(pesos(ledger.major(monthly)))),
      );
      await f.check('Ninguna viene marcada', () {
        expect(_ticked, findsNothing);
      });
      await f.tap('Revisar las marcadas');
      await _read(
        f,
        'Toca «Revisar las marcadas» sin marcar ninguna: responde «No '
        'marcaste ninguna» y todas siguen activas.',
        most: 1,
      );
      await _tick(f, 'Fit24 gimnasio');
      await _tick(f, 'Lingo Pro');
      await f.step(
        'Marca Fit24 gimnasio y Lingo Pro en la lista: cada una dice «Para '
        'cancelar» y abajo aparece cuánto se ahorra al mes.',
      );
      final int two =
          _price(ledger, 'Fit24 gimnasio') + _price(ledger, 'Lingo Pro');
      await f.check(
        'Marcadas las dos, el ahorro es ${pesos(ledger.major(two))} al mes',
        () => expect(_said(f), contains('${pesos(ledger.major(two))} al mes')),
      );
      await f.tap('Revisar las marcadas');
      await _read(
        f,
        '«Revisar las marcadas»: «Antes de cancelar» dice lo que ahorra y '
        'cuándo cobra cada una; Quincena no las cancela por ella.',
      );
      await f.check('Con dos marcadas, el botón dice «Ya las cancelé»', () {
        expect(find.text('Ya las cancelé'), findsOneWidget);
      });
      await f.tap('Cambiar selección');
      await f.check(
        'La revisión de las dos dice que la reemplazó la selección nueva',
        () {
          expect(
            find.text('Reemplazada por tu nueva selección'),
            findsOneWidget,
          );
          expect(find.text('Ver la nueva'), findsOneWidget);
        },
      );
      await _untick(f, 'Lingo Pro');
      await f.step(
        '«Cambiar selección» trae la lista con las dos marcadas; quita Lingo '
        'Pro y queda solo Fit24 gimnasio.',
      );
      await f.tap('Revisar las marcadas');
      await _read(
        f,
        'Revisa otra vez: ahora es una sola, y el botón dice «Ya la cancelé» '
        'en singular.',
        most: 1,
      );
      await f.tap('Ya la cancelé');
      await _read(
        f,
        'Toca «Ya la cancelé» después de cancelarla en el servicio: queda el '
        'recibo «Marcadas como canceladas» y Fit24 tachada.',
      );
      final int fit = _price(ledger, 'Fit24 gimnasio');
      await f.check(
        'Dice que desde el próximo cobro ahorra ${pesos(ledger.major(fit))} '
        'al mes',
        () => expect(
          _said(f),
          contains('te ahorras ${pesos(ledger.major(fit))} al mes'),
        ),
      );
      await f.check(
        'En la demo la cuenta no cambia: sigue pagando '
        '${pesos(ledger.major(monthly))} al mes',
        () => expect(ledger.subscriptionsMonthly, monthly),
      );
      await f.check('Solo Fit24 gimnasio quedó tachada', () {
        expect(find.text('Cancelada'), findsOneWidget);
      });
      final int turns = s.turns.length;
      await f.tap('Editar');
      await f.step(
        'Toca «Editar» en el recibo: «Ya la cancelé» se puede tocar otra vez '
        'y el recibo se va hasta confirmar de nuevo.',
      );
      await f.check('«Editar» abrió otra vez la revisión', () {
        expect(
          find.textContaining('Marcadas como canceladas · '),
          findsNothing,
        );
      });
      await f.tap('Ya la cancelé');
      await _read(
        f,
        'La confirma otra vez: llega otra respuesta igual, con Fit24 tachada, '
        'y la anterior se queda arriba.',
        most: 1,
      );
      await f.check('Hay un solo recibo y una respuesta más', () {
        expect(find.textContaining('Marcadas como canceladas · '), findsOne);
        expect(s.turns, hasLength(turns + 1));
        expect(ledger.subscriptionsMonthly, monthly);
      });
      // The first review, from before «Cambiar selección», with both.
      final Finder stale = find.text('Ya las cancelé');
      final Finder replaced = find.text('Reemplazada por tu nueva selección');
      await f.reveal(replaced);
      await Scrollable.ensureVisible(f.tester.element(replaced));
      await settle(f.tester);
      await f.step(
        'Más arriba sigue la primera revisión, la de las dos: atenuada, con '
        '«Reemplazada por tu nueva selección» y «Ver la nueva» encima.',
      );
      final int answered = s.turns.length;
      await f.check('Su «Ya las cancelé» está a la vista', () {
        final Size screen =
            f.tester.view.physicalSize / f.tester.view.devicePixelRatio;
        expect(
          f.tester.getCenter(stale).dy,
          inExclusiveRange(0, screen.height),
        );
      });
      await f.tester.tap(stale, warnIfMissed: false);
      await settle(f.tester);
      await _read(
        f,
        'Toca su «Ya las cancelé»: no pasa nada, no llega ninguna respuesta '
        'y sigue confirmada solo Fit24 gimnasio.',
        most: 1,
      );
      await f.check(
        'La revisión de antes de «Cambiar selección» ya no confirma nada',
        () {
          expect(s.turns, hasLength(answered));
          expect(find.textContaining('Canceladas: '), findsNothing);
          expect(find.text('Cancelada'), findsNWidgets(2));
          expect(ledger.subscriptionsMonthly, monthly);
        },
      );
    },
  ),
  AppFlow(
    '11-05-anotar-un-gasto-en-la-demo',
    'Anotar un gasto conversando',
    area: _demoArea,
    goal:
        'Quiero anotar lo que gasté escribiéndolo como lo diría, corregirlo '
        'si me equivoqué y ver cuánto me queda.',
    demo: true,
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      // The example's account, read again at every check: what the
      // conversation saves goes to its database, and the screens read it.
      Ledger ledger() => s.ledger;
      final int free = ledger().freeUntilPayday;
      final Set<String> before = <String>{
        for (final Movement m in ledger().movements) m.id,
      };
      List<Movement> added() => <Movement>[
        for (final Movement m in ledger().movements)
          if (!before.contains(m.id)) m,
      ];
      await f.tap(ScriptedAgent.starters[4]);
      await _read(
        f,
        'Toca «Registra 45 mil en el mercado»: llega un formulario con '
        '45.000 y Mercado ya puestos, para corregir antes de guardar.',
      );
      final String form = s.turns.single.surfaceIds.single;
      await f.type('Monto', '');
      await f.tap('Guardar gasto');
      await f.step(
        'Borra el monto y toca «Guardar gasto»: no guarda nada, y debajo del '
        'monto sigue «Escribe un monto mayor que cero.»',
      );
      await f.check(
        'Sin monto no se guarda nada ni aparece otro formulario',
        () {
          expect(added(), isEmpty);
          expect(s.turns, hasLength(1));
          expect(s.settledOf(form), isNull);
          expect(find.text('Guardar gasto'), findsOneWidget);
        },
      );
      await f.type('Monto', '99000000');
      await f.tap('Guardar gasto');
      await f.step(
        'Escribe 99.000.000 y toca «Guardar gasto»: avisa «Es más de lo que '
        'hay en la cuenta.» y tampoco lo guarda.',
      );
      await f.check('Un monto mayor que lo que hay no se guarda: puede gastar '
          '${pesos(ledger().major(free))}, como antes', () {
        expect(added(), isEmpty);
        expect(ledger().freeUntilPayday, free);
        expect(s.turns, hasLength(1));
        expect(find.text('Es más de lo que hay en la cuenta.'), findsOne);
      });
      await f.type('Monto', '52000');
      await f.tap('Restaurantes');
      await f.type('Dónde', 'Tienda Don Pacho');
      await f.step(
        'Con 52.000, la categoría Restaurantes y «Tienda Don Pacho» en '
        '«Dónde», el formulario queda listo.',
      );
      await f.tap('Guardar gasto');
      await _read(
        f,
        'Toca «Guardar gasto»: queda el recibo «Gasto guardado», y la '
        'respuesta dice cuánto puede gastar ahora y cómo va restaurantes.',
      );
      await f.check('Queda un movimiento más, de ${pesos(52000)} en '
          'restaurantes', () {
        final Movement m = added().single;
        expect(m.amount, 52000);
        expect(m.category, Category.restaurants);
        expect(m.merchant, 'Tienda Don Pacho');
      });
      await f.check(
        'Lo que puede gastar pasó de ${pesos(ledger().major(free))} a '
        '${pesos(ledger().major(free - 52000))}, como dice la respuesta',
        () {
          expect(ledger().freeUntilPayday, free - 52000);
          expect(
            _said(f),
            contains(
              'Ahora puedes gastar ${pesos(ledger().major(free - 52000))}',
            ),
          );
        },
      );
      await f.tap('Editar');
      await f.step(
        'Toca «Editar» en el recibo: el formulario vuelve a abrirse con lo '
        'que guardó.',
      );
      await f.type('Monto', '60000');
      await f.tap('Guardar gasto');
      await _read(
        f,
        'Corrige a 60.000 y guarda otra vez: el gasto se reemplaza, no se '
        'suma uno nuevo.',
        most: 1,
      );
      await f.check('Sigue habiendo un solo gasto nuevo, ahora de '
          '${pesos(60000)}', () {
        expect(added().single.amount, 60000);
        expect(ledger().freeUntilPayday, free - 60000);
      });
      await f.check('Hay un solo recibo «Gasto guardado»', () {
        expect(find.textContaining('Gasto guardado · '), findsOneWidget);
      });
      await f.tap('Ver resultado');
      await f.step(
        'Arriba, en el recibo, «Ver resultado» lleva a la respuesta que '
        'tuvo el gasto corregido.',
      );
      await f.check('La respuesta al gasto corregido quedó a la vista', () {
        expect(_inView(f, _surfaceOf(s, s.turns.last)), isTrue);
      });
      // Back to the example: the conversation and the screens are one
      // account.
      await f.back();
      await f.tap('Movimientos');
      await f.step(
        'Vuelve al ejemplo y abre Movimientos: el gasto de \$60.000 en '
        '«Tienda Don Pacho» está ahí, hoy: la conversación y las pantallas '
        'son la misma cuenta.',
      );
      await f.check(
        'El gasto está en la cuenta de ejemplo y Movimientos lo muestra',
        () {
          expect(f.shows('Tienda Don Pacho'), isTrue);
          expect(f.own.ledger!.freeUntilPayday, free - 60000);
        },
      );
    },
  ),
  AppFlow(
    '11-06-comparar-con-agosto',
    'Comparar septiembre con agosto',
    area: _demoArea,
    goal:
        'Quiero saber si gasté más o menos que el mes pasado y en qué cambió.',
    demo: true,
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      final Ledger ledger = s.ledger;
      final int now = ledger.spentIn(2026, 9);
      final int before = ledger.spentIn(2026, 8);
      await f.tap(ScriptedAgent.starters[3]);
      await _read(
        f,
        'Toca «¿Cómo voy contra agosto?»: cuánto más gastó, los dos meses '
        'lado a lado, seis meses en barras y lo que más cambió.',
      );
      await f.check(
        'Gastó ${pesos(ledger.major(now - before))} más que en agosto, la '
        'resta de los dos meses',
        () => expect(
          _said(f),
          contains(
            'Gastaste ${pesos(ledger.major(now - before))} más que en agosto',
          ),
        ),
      );
      await f.check('Septiembre ${pesos(ledger.major(now))} y agosto '
          '${pesos(ledger.major(before))}', () {
        final String said = _said(f);
        expect(said, contains(pesos(ledger.major(now))));
        expect(said, contains(pesos(ledger.major(before))));
      });
      // What changed most, worked out from the account: the three
      // categories that moved the most between the two months.
      final List<Category> moved =
          <Category>[
            for (final Category c in Category.values)
              if (c != Category.housing && c != Category.debt) c,
          ]..sort(
            (Category a, Category b) =>
                _moved(ledger, b).compareTo(_moved(ledger, a)),
          );
      final List<Category> top = moved.take(3).toList();
      await f.check(
        'Lo que más cambió son ${top.map((Category c) => c.label).join(', ')}, '
        'con lo de cada mes',
        () {
          final List<BudgetMeter> meters = f.tester
              .widgetList<BudgetMeter>(find.byType(BudgetMeter))
              .toList();
          expect(<Category>[
            for (final BudgetMeter m in meters) m.category,
          ], top);
          for (final BudgetMeter m in meters) {
            expect(m.spent, ledger.spentOn(m.category, 2026, 9));
            expect(m.limit, ledger.spentOn(m.category, 2026, 8));
          }
        },
      );
      await f.tap(ScriptedAgent.starters[0]);
      await _read(
        f,
        'Al final, «¿En qué se me fue la plata en septiembre?» lleva a la '
        'otra respuesta sin escribir nada.',
        most: 1,
      );
      await f.check('La sugerencia hizo su pregunta', () {
        expect(s.turns.last.question, ScriptedAgent.starters[0]);
      });
    },
  ),
  AppFlow(
    '11-07-empezar-de-nuevo',
    'Empezar una conversación nueva y recuperar la anterior',
    area: _demoArea,
    goal:
        'Quiero limpiar la conversación para empezar otra, y poder volver '
        'atrás si la borré sin querer.',
    demo: true,
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      final int free = s.ledger.freeUntilPayday;
      await f.tap(ScriptedAgent.starters[4]);
      // Two quick taps, as an impatient finger does.
      final Finder save = find.text('Guardar gasto');
      await f.reveal(save);
      await f.tester.tap(save.last);
      await f.tester.pump();
      await f.tester.tap(save.last, warnIfMissed: false);
      await settle(f.tester);
      await f.step(
        'Con un gasto de 45.000 guardado en la conversación, arriba a la '
        'derecha aparece «Nueva».',
      );
      await f.check('Dos toques seguidos en «Guardar gasto» guardan uno', () {
        expect(s.ledger.freeUntilPayday, free - 45000);
        expect(find.textContaining('Gasto guardado · '), findsOneWidget);
      });
      await f.tap('Nueva');
      await f.step(
        'Toca «Nueva»: vuelven las preguntas de inicio y abajo «Empezaste '
        'una conversación nueva.» con «Deshacer». El gasto guardado sigue en '
        'la cuenta de ejemplo.',
      );
      await f.check('La conversación quedó vacía y el gasto sigue en la '
          'cuenta', () {
        expect(s.turns, isEmpty);
        expect(s.ledger.freeUntilPayday, free - 45000);
      });
      await f.tap('Deshacer');
      await f.step(
        'Toca «Deshacer»: vuelve la conversación anterior, con su recibo '
        '«Gasto guardado».',
      );
      await f.check(
        'Volvió la conversación, y la cuenta no cambió: puede gastar '
        '${pesos(s.ledger.major(free - 45000))}',
        () {
          expect(s.turns, hasLength(2));
          expect(s.ledger.freeUntilPayday, free - 45000);
        },
      );
      await f.tap('Nueva');
      await f.tap(ScriptedAgent.starters[3]);
      await f.step(
        '«Nueva» otra vez y una pregunta en la conversación nueva: el '
        '«Deshacer» se va y la anterior ya no se puede recuperar.',
      );
      await f.check('Ya no hay conversación para recuperar', () {
        expect(s.canRestore, isFalse);
        expect(find.text('Deshacer'), findsNothing);
      });
      await f.tap('Nueva');
      // Six seconds untouched, the time the offer to undo lasts.
      await f.tester.pump(const Duration(seconds: 7));
      await settle(f.tester);
      await f.step(
        '«Nueva» otra vez, y sin tocar «Deshacer»: a los seis segundos el '
        'aviso se va, y con él la conversación anterior.',
      );
      await f.check('Pasado el aviso, la conversación anterior no vuelve', () {
        expect(s.turns, isEmpty);
        expect(s.canRestore, isFalse);
        expect(find.text('Deshacer'), findsNothing);
      });
      await f.tap(ScriptedAgent.starters[4]);
      await f.tap('Guardar gasto');
      final int spent = s.ledger.freeUntilPayday;
      await f.tapTip('Ajustes');
      await f.tap('Empezar de nuevo');
      await f.step(
        'Con otro gasto guardado, «Empezar de nuevo» en «Ajustes» limpia la '
        'conversación, sin «Deshacer». Los dos gastos siguen en la cuenta de '
        'ejemplo hasta salir de ella.',
      );
      await f.check('«Empezar de nuevo» limpia la conversación y deja los '
          'gastos en la cuenta: puede gastar '
          '${pesos(s.ledger.major(free - 90000))}', () {
        expect(spent, free - 90000);
        expect(s.turns, isEmpty);
        expect(s.ledger.freeUntilPayday, free - 90000);
        expect(s.canRestore, isFalse);
        expect(find.text('Deshacer'), findsNothing);
      });
    },
  ),
  AppFlow(
    '11-08-leer-sin-que-salte',
    'Leer una respuesta mientras llega otra',
    area: _demoArea,
    goal:
        'Quiero volver a leer la respuesta anterior mientras llega la nueva '
        'sin que la pantalla me saque de donde estoy.',
    demo: true,
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      await f.tap(ScriptedAgent.starters[0]);
      await f.step(
        'Pregunta en qué se fue la plata: la respuesta sube sola hasta '
        'arriba, para leerla desde su titular.',
      );
      final Finder chip = find.text(ScriptedAgent.starters[3]);
      await f.reveal(chip);
      await f.tester.tap(chip.last);
      // The question comes to the top; then the person scrolls back up to
      // read the first answer while the second is on its way.
      await f.tester.pump();
      await f.tester.pump(const Duration(milliseconds: 400));
      await f.tester.drag(find.byType(FollowedScroll), const Offset(0, 400));
      await f.tester.pump(const Duration(milliseconds: 50));
      final double reading = _scroll(f).pixels;
      await f.check('Mientras responde, la flecha de preguntar se apaga', () {
        expect(s.busy, isTrue);
        expect(_sendButton(f).onPressed, isNull);
      });
      await f.step(
        'Toca «¿Cómo voy contra agosto?» y sube a releer mientras responde: '
        'la pantalla se queda quieta y ofrece «Ver resultado».',
      );
      await f.check('La pantalla no se movió al llegar la respuesta', () {
        expect(_scroll(f).pixels, reading);
        expect(find.text('Ver resultado'), findsOneWidget);
      });
      await f.tap('Ver resultado');
      await f.step(
        'Toca «Ver resultado»: la respuesta nueva sube hasta arriba y el '
        'botón se va.',
      );
      await f.check('La respuesta nueva quedó a la vista', () {
        expect(_inView(f, _surfaceOf(s, s.turns.last)), isTrue);
        expect(find.text('Ver resultado'), findsNothing);
        expect(_sendButton(f).onPressed, isNotNull);
      });
    },
  ),
  AppFlow(
    '11-09-lo-que-respondio-gemini',
    'Ver lo que respondió Gemini de verdad',
    area: _demoArea,
    goal:
        'Quiero ver si un modelo de verdad responde igual de bien que la '
        'demo, sin poner una key.',
    (FlowRun f) async {
      // A flow that ended while the home was still reading its recordings
      // leaves them cached half read: this home reads them afresh.
      rootBundle.clear();
      await f.tap('Con datos de ejemplo');
      await f.toConversation();
      await f.waitFor(find.text(_seeRecorded));
      await f.reveal(find.text(_seeRecorded));
      await f.step(
        'En el ejemplo, «Otra pregunta» abre la conversación; al final de su '
        'inicio está «Mira lo que respondió Gemini de verdad».',
      );
      await f.tap(_seeRecorded);
      await f.page(
        'Lo abre: cinco sesiones grabadas, una por pregunta, con el modelo, '
        'los pasos y cuántos segundos tardó.',
      );
      await f.check('Hay una sesión grabada por cada pregunta de la demo', () {
        for (final String q in ScriptedAgent.starters) {
          expect(find.text(q), findsOneWidget);
        }
      });
      await f.tap(ScriptedAgent.starters[0]);
      await f.page(
        'Toca la primera: la pregunta, la respuesta como la armó Gemini y un '
        'control con los pasos que mandó.',
      );
      final RecordedSlider at = RecordedSlider(f);
      await f.check('La reproducción empieza en el último paso', () {
        expect(at.value, at.max);
        expect(find.text('${at.max.round()} de ${at.max.round()}'), findsOne);
      });
      await f.tester.drag(_replaySlider, const Offset(-800, 0));
      await settle(f.tester);
      await f.step(
        'Arrastra el control al principio: «Antes de la respuesta», 0 de 5, '
        'y la respuesta desaparece.',
      );
      await f.check('Al principio no hay nada dibujado', () {
        expect(RecordedSlider(f).value, 0);
        expect(find.text('Antes de la respuesta'), findsOneWidget);
      });
      await _seek(f, 3);
      await f.step(
        'En el paso 3, «Manda los componentes»: la pantalla aparece armada '
        'pero sin cifras, que llegan en el paso siguiente.',
      );
      await f.check('El paso 3 es el que manda los componentes', () {
        expect(RecordedSlider(f).value, 3);
        expect(find.text('Manda los componentes'), findsOneWidget);
      });
      await f.back();
      // Each of the five, opened from the list: every one plays to its end.
      final List<String> short = <String>[];
      for (final String q in ScriptedAgent.starters) {
        await f.tap(q);
        final RecordedSlider played = RecordedSlider(f);
        if (played.max < 1 || played.value != played.max) short.add(q);
        if (find.byType(Surface).evaluate().isEmpty) short.add(q);
        await f.back();
      }
      await f.check(
        'Las cinco grabaciones abren con su respuesta armada, en el último '
        'paso',
        () => expect(short, isEmpty),
      );
      await f.back();
      await f.check('Ver las grabaciones no toca la conversación', () {
        expect(_demo(f).turns, isEmpty);
      });
    },
  ),
  AppFlow(
    '11-10-quien-responde',
    'Saber quién responde en el ejemplo',
    area: _demoArea,
    goal:
        'Quiero saber quién contesta en el ejemplo y si gasto preguntas del '
        'día.',
    demo: true,
    manual: <String>[
      'Con tus cuentas, «Pregúntale a tu plata» lo responde Gemini a través '
          'de Quincena: necesita red.',
    ],
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      await f.tap(ScriptedAgent.starters[3]);
      await _read(
        f,
        'Toca «¿Cómo voy contra agosto?»: arriba dice «EJEMPLO», no «EN '
        'VIVO»: lo responde el guion del ejemplo, sin red.',
        most: 1,
      );
      await f.check(
        'Responde el guion, sin red y sin gastar preguntas del día',
        () {
          expect(s.mode, AgentMode.demo);
          expect(s.choosable, isFalse);
          expect(s.allowance, isNull);
          expect(f.shows('EJEMPLO'), isTrue);
          expect(f.shows('EN VIVO'), isFalse);
        },
      );
      await f.tapTip('Ajustes');
      await f.step(
        'En «Ajustes» de la conversación no hay a quién escoger: en el '
        'teléfono, el ejemplo siempre lo responde el guion.',
      );
      await f.check(
        'No ofrece Gemini, ni una key propia, ni el modo desarrollador',
        () {
          expect(f.shows('Tu key'), isFalse);
          expect(f.shows('Gemini'), isFalse);
          expect(f.shows('Modo desarrollador'), isFalse);
        },
      );
    },
  ),
  AppFlow(
    '11-11-idioma-y-apariencia',
    'Cambiar el idioma y la apariencia',
    area: _demoArea,
    goal: 'Quiero ver la demo en inglés y en modo oscuro.',
    demo: true,
    manual: <String>[
      'Con «Sistema» en Idioma y en Apariencia, cambiar el idioma y el modo '
          'oscuro del teléfono y ver que la app los sigue.',
      'Escoger «English» y «Oscuro», cerrar la app del todo y abrirla: debe '
          'volver en inglés y oscura.',
    ],
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      final AppSettings settings = _settings(f);
      await f.tap(ScriptedAgent.starters[0]);
      await f.tapTip('Ajustes');
      await f.tap('English');
      await f.step(
        'Con una respuesta en pantalla, en Ajustes toca «English»: la hoja '
        'pasa a inglés al instante.',
      );
      await f.check('El idioma quedó en inglés, también el de las '
          'respuestas', () {
        expect(settings.locale, const Locale('en'));
        expect(s.language, 'en');
      });
      await f.back();
      await f.page(
        'Cierra la hoja: la demo está en inglés y la conversación empezó de '
        'nuevo, sin aviso, con las preguntas en inglés.',
      );
      await f.check('Cambiar el idioma borró la conversación', () {
        expect(s.turns, isEmpty);
        expect(find.text(ScriptedAgent.startersEn[0]), findsOneWidget);
      });
      await f.tap(ScriptedAgent.startersEn[3]);
      final Ledger ledger = s.ledger;
      final int more = ledger.spentIn(2026, 9) - ledger.spentIn(2026, 8);
      // Written while the app speaks English, with a comma between thousands.
      final String english = pesos(ledger.major(more));
      await _read(
        f,
        'En inglés, «${ScriptedAgent.startersEn[3]}» responde «You spent '
        '$english more than in August», con coma entre los miles.',
        most: 1,
      );
      await f.check(
        'La respuesta en inglés da la misma cifra, $english, escrita en '
        'inglés',
        () {
          expect(english, contains(','));
          expect(_said(f), contains('You spent $english more than in August'));
        },
      );
      await f.tapTip('Settings');
      await f.tap('Español');
      await f.tap('Oscuro');
      await f.step(
        'Vuelve a «Español» y toca «Oscuro» en Apariencia: toda la app se '
        'pone oscura, también la hoja de Ajustes.',
      );
      await f.check('Quedó en español y en modo oscuro, Ajustes incluido', () {
        expect(settings.locale, const Locale('es'));
        expect(settings.themeMode, ThemeMode.dark);
        expect(
          f.tester
              .widget<BottomSheet>(find.byType(BottomSheet))
              .backgroundColor,
          QuincenaColors.dark.surface,
        );
      });
      await f.check(
        'Español y oscuro quedan guardados para la próxima vez que abra la '
        'app',
        () async {
          expect(await _setting(f, 'app.theme'), 'dark');
          expect(await _setting(f, 'app.language'), 'es');
        },
      );
      await f.back();
      await f.step('Así se ve el inicio de la demo en modo oscuro.');
      await f.tapTip('Ajustes');
      await f.tap('Claro');
      await f.tester.tap(find.text('Sistema').first);
      await settle(f.tester);
      await f.step(
        '«Claro» devuelve los colores; «Sistema» en Idioma deja que el '
        'teléfono decida el idioma.',
      );
      await f.tester.tap(find.text('Sistema').last);
      await settle(f.tester);
      await f.check('Idioma y apariencia siguen al teléfono, también al '
          'volver a abrir la app', () async {
        expect(settings.locale, isNull);
        expect(settings.themeMode, ThemeMode.system);
        expect(await _setting(f, 'app.theme'), 'system');
        expect(await _setting(f, 'app.language'), isEmpty);
      });
    },
  ),
  AppFlow(
    '11-12-modo-desarrollador',
    'Mirar por dentro una respuesta',
    area: _demoArea,
    goal:
        'Soy desarrollador y quiero ver cómo arma la pantalla el agente y '
        'copiar la sesión para reportar un error.',
    demo: true,
    manual: <String>[
      'Pegar en otra app lo que dejó «Copiar la sesión» y ver que llega '
          'entero.',
      'El inspector con su letra de verdad (Menlo): en una prueba sin '
          'teléfono se dibuja con cuadros.',
    ],
    (FlowRun f) async {
      // The conversation opens from the example's Inicio.
      await f.toConversation();
      final Session s = _demo(f);
      final AppSettings settings = _settings(f);
      await f.tapTip('Ajustes');
      await f.tap('Modo desarrollador');
      await f.step(
        'En Ajustes, enciende «Modo desarrollador»: aparece «Copiar la '
        'sesión», apagado porque todavía no hay conversación.',
      );
      await f.check('El modo quedó encendido y no hay nada que copiar', () {
        expect(settings.developer, isTrue);
        final OutlinedButton copy = f.tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Copiar la sesión'),
        );
        expect(copy.onPressed, isNull);
      });
      await f.back();
      await f.tap(ScriptedAgent.starters[4]);
      await f.type('Dónde', 'Regalo para mamá');
      await f.step(
        'Pide anotar un gasto y escribe «Regalo para mamá» en «Dónde»; '
        'abajo a la izquierda está la pestaña «genui 1».',
      );
      // The inspector writes in a monospace font that a run without a phone
      // draws as squares a whole letter wide, too wide for its tab bar;
      // with the phone's Menlo it fits. Only that overflow is let through.
      final FlutterExceptionHandler? report = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails e) {
        if (!e.exceptionAsString().startsWith('A RenderFlex overflowed')) {
          report?.call(e);
        }
      };
      try {
        await f.tap('genui 1');
        await f.step(
          'Toca «genui 1»: el inspector muestra el árbol de componentes que '
          'mandó el agente.',
        );
        await f.tap('data');
        await f.step(
          '«data» muestra los datos del formulario tal como están ahora.',
        );
        await f.tap('messages');
        await f.step('«messages» lista cada mensaje que llegó del agente.');
        await f.tap('semantics');
        await f.step(
          '«semantics» muestra lo que leería un lector de pantalla, con '
          '«reload» para leerlo otra vez.',
        );
        await f.tap('reload');
        await f.tap('close');
      } finally {
        FlutterError.onError = report;
      }
      await f.tapTip('Ajustes');
      String? copied;
      f.tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      try {
        await f.tap('Copiar la sesión');
      } finally {
        f.tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      }
      await f.step(
        'Cierra el inspector y toca «Copiar la sesión» en Ajustes: la hoja se '
        'cierra sola y abajo avisa que la sesión se copió sin lo que '
        'escribió.',
      );
      await f.check('Lo copiado trae la sesión sin «Regalo para mamá»', () {
        expect(copied, isNotNull);
        expect(copied, contains('"draft"'));
        expect(copied, isNot(contains('Regalo para mamá')));
      });
      await f.check('La hoja se cerró y el aviso se ve, sin nada encima', () {
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find
              .text(
                'Sesión copiada, sin lo que escribiste. Pégala en un issue y '
                'se puede reproducir.',
              )
              .hitTestable(),
          findsOneWidget,
        );
      });
      await f.tapTip('Ajustes');
      await f.tap('Modo desarrollador');
      await f.back();
      await f.check('Apagado, el inspector desaparece', () {
        expect(settings.developer, isFalse);
        expect(find.text('genui 1'), findsNothing);
        expect(s.turns, hasLength(1));
      });
    },
  ),
  AppFlow(
    '11-13-salir-de-la-demo',
    'Pasar del ejemplo a mis cuentas',
    area: _demoArea,
    goal: 'Ya entendí cómo funciona y quiero empezar con mis propias cuentas.',
    demo: true,
    (FlowRun f) async {
      final int waiting = f.own.pendingInbox.length;
      await f.tapTip('Por revisar');
      await f.tap('Registrar gasto');
      await f.step(
        'En el ejemplo, en «Por revisar», toca «Registrar gasto» en la compra '
        'del Supermercado Andino: queda en la cuenta de Valentina.',
      );
      await f.check('Queda uno menos por revisar en el ejemplo', () {
        expect(f.own.pendingInbox, hasLength(waiting - 1));
      });
      await f.back();
      await f.tap('Usar mis cuentas');
      await f.step(
        'Toca «Usar mis cuentas» en la franja de arriba: empieza la '
        'configuración de sus cuentas, paso 1, con su nombre, y la franja '
        'del ejemplo ya no está.',
      );
      await f.check(
        'Se abrió la configuración, sin nada del ejemplo',
        () async {
          expect(find.byType(OnboardingPage), findsOneWidget);
          expect(find.text('Cuenta de ejemplo de Valentina'), findsNothing);
          expect(await f.tester.runAsync(_store(f).profile), isNull);
          expect(await f.tester.runAsync(_store(f).entries), isEmpty);
        },
      );
      await f.tapTip('Atrás');
      await f.step(
        'Toca «Atrás» en el primer paso: vuelve al ejemplo, abierto desde el '
        'comienzo: lo que registró ya no está.',
      );
      await f.check('El ejemplo volvió como nuevo, con $waiting por revisar, '
          'y la app lo recuerda', () async {
        expect(find.byType(OwnShell), findsOneWidget);
        expect(f.own.example, isTrue);
        expect(f.own.pendingInbox, hasLength(waiting));
        expect(await _setting(f, 'app.mode'), 'demo');
      });
      await f.tapTip('Ajustes');
      await f.step(
        'En sus Ajustes, arriba, «Cuenta de ejemplo» dice que Valentina es '
        'inventada y que lo que se haga se borra al salir, con «Usar mis '
        'cuentas».',
      );
      await f.check('Ajustes ofrece el mismo «Usar mis cuentas»; no hay '
          'primera pantalla a la que volver', () {
        expect(f.shows('CUENTA DE EJEMPLO'), isTrue);
        expect(f.shows('Usar mis cuentas'), isTrue);
        expect(f.shows('Volver a la primera pantalla'), isFalse);
        expect(f.shows('Ver los datos de ejemplo'), isFalse);
      });
      await f.tapFound(find.text('Usar mis cuentas'));
      await f.check('Desde Ajustes también abre la configuración', () {
        expect(find.byType(OnboardingPage), findsOneWidget);
      });
    },
  ),
  AppFlow(
    '11-14-ver-el-ejemplo-y-volver',
    'Mirar el ejemplo y volver a mis cuentas',
    area: _demoArea,
    goal:
        'Ya tengo mis cuentas, pero quiero mostrarle el ejemplo a alguien y '
        'volver a lo mío.',
    data: fullAccount,
    (FlowRun f) async {
      final int entries = f.own.snapshot!.entries.length;
      final int free = f.own.ledger!.freeUntilPayday;
      await f.tapTip('Ajustes');
      await f.reveal(find.text('Ver los datos de ejemplo'));
      await f.step(
        'En Ajustes de sus cuentas está «Ver los datos de ejemplo».',
      );
      await f.tap('Ver los datos de ejemplo');
      await f.step(
        'Lo toca: abre toda la app con la cuenta de Valentina, con la franja '
        '«Cuenta de ejemplo de Valentina» y «Usar mis cuentas» arriba.',
      );
      await f.check(
        'Es el ejemplo, la app lo recuerda y sus movimientos siguen ahí',
        () async {
          expect(f.own.example, isTrue);
          expect(f.own.profile!.name, 'Valentina');
          expect(await _setting(f, 'app.mode'), 'demo');
          expect(
            await f.tester.runAsync(_store(f).entries),
            hasLength(entries),
          );
        },
      );
      await f.tap('Usar mis cuentas');
      await f.step(
        'Toca «Usar mis cuentas»: vuelve a su Inicio con todo como estaba.',
      );
      await f.check('Volvió a las cuentas propias, sin perder nada', () async {
        expect(find.byType(OwnShell), findsOneWidget);
        expect(f.own.example, isFalse);
        expect(await _setting(f, 'app.mode'), 'own');
        expect(f.own.snapshot!.entries, hasLength(entries));
        expect(f.own.ledger!.freeUntilPayday, free);
      });
      await f.tapTip('Ajustes');
      await f.tap('Ver los datos de ejemplo');
      await f.tapTip('Ajustes');
      await f.step(
        'Otra vez en el ejemplo, sus Ajustes empiezan con «Cuenta de '
        'ejemplo»: «Usar mis cuentas» y «Volver a la primera pantalla».',
      );
      await f.tapFound(find.text('Usar mis cuentas'));
      await f.check('Desde Ajustes también vuelve a sus cuentas', () async {
        expect(find.byType(OwnShell), findsOneWidget);
        expect(f.own.example, isFalse);
        expect(f.own.ledger!.freeUntilPayday, free);
        expect(await _setting(f, 'app.mode'), 'own');
      });
    },
  ),
  AppFlow(
    '11-15-recorrer-la-cuenta-de-ejemplo',
    'Recorrer toda la app con la cuenta de ejemplo',
    area: _demoArea,
    goal:
        'Antes de poner mis cuentas quiero ver todo lo que hace la app: '
        'Inicio, lo que hay por hacer, los movimientos, las cuentas, la '
        'cripto y el plan.',
    demo: true,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Ledger story = demoLedger();
      final String free = pesos(story.major(story.freeUntilPayday));
      await f.page(
        'Al abrir, Inicio de la cuenta de ejemplo de Valentina: «Puedes '
        'gastar $free hasta el 15 de octubre», lo que hay por hacer, los '
        'próximos días y sus cuentas.',
      );
      await f.check(
        'Inicio dice $free, la misma cifra que la conversación del ejemplo',
        () {
          expect(own.ledger!.freeUntilPayday, story.freeUntilPayday);
          expect(_said(f), contains(free));
        },
      );
      await f.check('Por hacer: revisar 2 movimientos y repartir la '
          'quincena que llegó', () {
        expect(_said(f), contains('Revisa 2 movimientos'));
        expect(_said(f), contains('Te llegó la quincena'));
      });
      await f.tapTip('Por revisar');
      await f.step(
        'En «Por revisar», lo que el teléfono captó esta mañana: una compra '
        'lista para registrar, un pago al que le falta la cuenta y el '
        'gimnasio, que ya estaba anotado, como posible repetido.',
      );
      await f.check('Dos esperan y uno es un posible repetido', () {
        expect(own.pendingInbox, hasLength(2));
        expect(f.shows('LISTOS PARA REGISTRAR'), isTrue);
        expect(f.shows('NECESITAN INFORMACIÓN'), isTrue);
        expect(f.shows('POSIBLES REPETIDOS'), isTrue);
      });
      await f.back();
      await f.tap('Movimientos');
      await f.step(
        'En «Movimientos», seis meses de la historia de Valentina, lo más '
        'reciente arriba: hoy el gimnasio y ayer la nómina.',
      );
      await f.check('Son los movimientos de la historia, desde abril', () {
        final List<Entry> entries = own.snapshot!.entries;
        expect(entries.length, greaterThan(300));
        expect(
          entries
              .map((Entry e) => e.date)
              .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b),
          DateTime(2026, 4, 1),
        );
        expect(f.shows('Nómina Estudio Lumen'), isTrue);
      });
      await f.tap('Cuentas');
      await f.page(
        'En «Cuentas», su patrimonio y cada cuenta: la de nómina, la '
        'billetera, el efectivo, la tarjeta con su cupo libre, el bolsillo de '
        'Cartagena, los dólares y la cripto.',
      );
      await f.check('Hay tarjeta con cupo, dólares y cripto con su costo', () {
        final List<String> names = <String>[
          for (final Account a in own.accounts) a.name,
        ];
        expect(
          names,
          containsAll(<String>[
            'Tarjeta de crédito',
            'Cuenta en dólares',
            'Bitcoin',
          ]),
        );
        expect(
          own.accounts
              .where((Account a) => a.asset.isCrypto)
              .every((Account a) => a.openingCost != null),
          isTrue,
        );
      });
      await f.tap('Rendimiento y ganancia');
      await f.page(
        '«Rendimiento y ganancia» abre la cripto: lo que costó, lo que vale '
        'con los precios fijos del ejemplo y la ganancia.',
      );
      await f.check('Los precios son los fijos del ejemplo', () {
        expect(
          own.rates.rate(Asset.btc, Asset.usdt),
          Decimal.parse(examplePrices['BTC']!.$1),
        );
      });
      await f.back();
      await f.tap('Plan');
      await f.page(
        'En «Plan», repartir la quincena en sobres, los ingresos variables, '
        'el viaje, la meta de Cartagena, los deseos, los pagos fijos, las '
        'compras a cuotas, los gastos compartidos y los cargos para revisar.',
      );
      await f.check('Cada parte del plan tiene algo que mostrar', () {
        expect(own.trips, hasLength(1));
        expect(own.wishes, isNotEmpty);
        expect(own.freelance.incomes, isNotEmpty);
        expect(own.instalments, hasLength(1));
        expect(own.groups, hasLength(1));
        expect(own.recurring, isNotEmpty);
      });
      await f.tap('Compras a cuotas');
      await f.step(
        '«Compras a cuotas»: los audífonos de septiembre, en tres cuotas sin '
        'interés en la tarjeta.',
      );
      await f.back();
      await f.tap('Gastos compartidos');
      await f.step(
        '«Gastos compartidos»: el paseo a Santa Elena con Laura y Mateo, que '
        'pagaron la cabaña y el mercado; Valentina les debe su parte.',
      );
      await f.check('Valentina debe su parte del paseo', () {
        expect(own.sharedBalance.$2, 222000);
      });
      await f.back();
      await f.tap('Cuenta de ejemplo de Valentina');
      await f.step(
        'La franja de arriba explica qué es: Valentina es inventada, lo que '
        'se haga aquí no toca los datos de nadie y se borra al salir.',
      );
      await f.check('La explicación ofrece «Usar mis cuentas» y seguir', () {
        expect(f.shows('Usar mis cuentas'), isTrue);
        expect(f.shows('Seguir en el ejemplo'), isTrue);
      });
      await f.tap('Seguir en el ejemplo');
    },
  ),
  AppFlow(
    '12-01-abrir-preguntale-a-tu-plata',
    'Abrir las preguntas sobre mis cuentas',
    area: _askArea,
    goal:
        'Quiero preguntarle a la app por mi plata y saber antes qué ve '
        'Gemini y cuántas preguntas tengo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Allowance allowance = _allowance(f);
      await _showAskPanel(f);
      await f.step(
        'En Inicio, más abajo, «Pregúntale a tu plata» ofrece tres preguntas '
        'y «Otra pregunta».',
      );
      await f.tap('Otra pregunta');
      await f.page(
        'Toca «Otra pregunta»: cinco preguntas sobre sus cuentas, cuántas le '
        'quedan hoy y «Qué ve Gemini».',
      );
      await f.check(
        'Dice «Te quedan ${allowance.perDay} preguntas hoy», las del día '
        'sin usar',
        () {
          expect(allowance.left, allowance.perDay);
          expect(
            find.text('Te quedan ${allowance.perDay} preguntas hoy'),
            findsOneWidget,
          );
        },
      );
      await f.check('Ofrece las cinco preguntas de sus cuentas', () {
        for (final String q in _ownStarters) {
          expect(find.text(q), findsOneWidget);
        }
      });
      await f.tap('Qué ve Gemini');
      await f.page(
        'Toca «Qué ve Gemini»: qué viaja a Gemini y qué no, en qué '
        'condiciones, y cuántas preguntas hay al día.',
      );
      await f.check(
        'Dice que cada persona tiene ${allowance.perDay} preguntas al día',
        () => expect(
          _said(f),
          contains('Cada persona tiene ${allowance.perDay} preguntas al día.'),
        ),
      );
      await f.back();
      await f.tapTip('Qué ve Gemini');
      await f.step(
        'La «i» de arriba a la derecha lleva a la misma '
        'explicación.',
      );
      await f.check('La «i» abre la misma página de lo que ve Gemini', () {
        expect(find.byType(GeminiNotePage), findsOneWidget);
        expect(
          _said(f),
          contains('Cada persona tiene ${allowance.perDay} preguntas al día.'),
        );
      });
      await f.back();
      final String goal = own.goalShares.first.name;
      await _hintTo(f, '¿Llego a mi meta de $goal?');
      await f.step(
        'Sin escribir, la barra va mostrando preguntas que esta cuenta sí '
        'puede responder, como la de su meta «$goal», cortada con «…».',
      );
      await f.check('Las pistas salen de esta cuenta: su meta, la tarjeta '
          'y la cripto', () {
        final List<String> hints = _hints(f);
        expect(hints, contains('¿Llego a mi meta de $goal?'));
        expect(hints, contains('¿Cuánto debo en la tarjeta?'));
        expect(hints, contains('¿Cómo va mi cripto esta semana?'));
      });
      await f.tapTip('Atrás');
      await f.check(
        'La flecha «Atrás» vuelve a Inicio sin gastar preguntas',
        () {
          expect(find.byType(AskPage), findsNothing);
          expect(find.text('Otra pregunta'), findsOneWidget);
          expect(allowance.left, allowance.perDay);
        },
      );
    },
  ),
  AppFlow(
    '12-02-preguntar-sin-gemini',
    'Preguntar cuando Gemini no responde',
    area: _askArea,
    goal:
        'Quiero preguntarle a la app en qué se me fue la plata este mes, '
        'aunque Gemini no esté disponible.',
    data: fullAccount,
    manual: <String>[
      'La respuesta real de Gemini a cada una de las cinco preguntas, con '
          'red y App Check.',
      'Si App Check o Gemini rechazan la pregunta, el aviso que sale en un '
          'teléfono de verdad.',
    ],
    (FlowRun f) async {
      final Allowance allowance = _allowance(f);
      final int left = allowance.left;
      await _tapWaiting(f, _ownStarters[1]);
      await f.step(
        'Toca «${_ownStarters[1]}» en Inicio: abre «Pregúntale a tu plata» '
        'con la pregunta hecha y, sin Gemini, dice «No pude responder esta '
        'vez».',
      );
      final Session s = _conversation(f);
      await f.check('La pregunta quedó con un aviso, no en blanco', () {
        expect(s.turns.single.question, _ownStarters[1]);
        expect(s.turns.single.error, AnswerProblem.other);
        expect(_problem, findsOneWidget);
      });
      await f.check(
        'Una pregunta que no tuvo respuesta no gasta del día: siguen $left',
        () => expect(allowance.left, left),
      );
      await _askWaiting(f, '¿Qué es lo que más gasto?');
      await f.step(
        'Escribe otra pregunta en la barra y la envía: cada intento queda '
        'con su aviso, y la barra sigue activa para probar de nuevo.',
      );
      await f.check('Dos intentos, dos avisos, y el cupo sigue en $left', () {
        expect(s.turns, hasLength(2));
        expect(s.turns.every((Turn t) => t.error != null), isTrue);
        expect(allowance.left, left);
      });
      await f.tap('Nueva');
      await f.step(
        'Toca «Nueva»: vuelven las cinco preguntas con el cupo del día, y '
        'abajo «Deshacer».',
      );
      await f.check('Dice cuántas preguntas quedan: $left', () {
        expect(s.turns, isEmpty);
        expect(find.text('Te quedan $left preguntas hoy'), findsOneWidget);
      });
      await f.tap('Deshacer');
      await f.step('Toca «Deshacer»: vuelven los dos intentos con sus avisos.');
      await f.check('«Deshacer» trae de vuelta los dos intentos', () {
        expect(s.turns, hasLength(2));
      });
      await f.tap('Nueva');
      await _tapWaiting(f, _ownStarters[4]);
      await f.step(
        '«Nueva» otra vez y «${_ownStarters[4]}»: con una pregunta en la '
        'conversación nueva, la anterior ya no se puede recuperar.',
      );
      await f.check('Ya no hay conversación para recuperar', () {
        expect(s.canRestore, isFalse);
        expect(find.text('Deshacer'), findsNothing);
        expect(s.turns.single.question, _ownStarters[4]);
      });
      await f.tap('Nueva');
      await f.tapTip('Atrás');
      await f.step(
        '«Nueva» y enseguida la flecha «Atrás»: en Inicio no queda el aviso '
        'con «Deshacer», que ya no llevaría a ninguna parte.',
      );
      await f.check('Al salir de la página se va la opción de deshacer', () {
        expect(find.byType(AskPage), findsNothing);
        expect(find.text('Deshacer'), findsNothing);
        expect(s.canRestore, isFalse);
      });
    },
  ),
  AppFlow(
    '12-03-volver-a-preguntar',
    'Volver a preguntar cuando falla',
    area: _askArea,
    goal:
        'Me quedé sin señal y quiero saber cuánto puedo gastar; cuando vuelva '
        'la red, preguntar otra vez sin perder preguntas del día.',
    data: fullAccount,
    manual: <String>[
      'Con el teléfono en modo avión, preguntar de verdad y ver el mismo '
          'aviso.',
      'Con Gemini saturado de verdad, el aviso de «Prueba en un minuto».',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final Allowance allowance = _allowance(f);
      final int left = allowance.left;
      late final _StandIn model;
      final Session s = await _openAsk(
        f,
        clientFor: (List<dartantic.Tool> tools) => model = _StandIn(
          tools,
          failures: <Object>[
            Exception('Failed host lookup: firebasevertexai.googleapis.com'),
            Exception('429 RESOURCE_EXHAUSTED'),
          ],
        ),
      );
      await f.step(
        'Aquí contesta un modelo de prueba, no Gemini: la primera vez sin '
        'internet, la segunda con Gemini saturado, la tercera sí.',
      );
      await f.tap(_ownStarters[0]);
      await f.step(
        'Toca «${_ownStarters[0]}»: dice «Sin conexión a internet» y que sus '
        'cuentas y movimientos siguen funcionando.',
      );
      await f.check('El aviso es el de estar sin conexión', () {
        expect(s.turns.single.error, AnswerProblem.offline);
        expect(find.textContaining('Sin conexión a internet.'), findsOne);
      });
      await f.check(
        'Sin internet no se gasta una pregunta del día: siguen $left',
        () => expect(allowance.left, left),
      );
      await _ask(f, _ownStarters[0]);
      await f.step(
        'Con red otra vez, la escribe en la barra: ahora dice «El modelo está '
        'recibiendo demasiadas preguntas. Prueba en un minuto.»',
      );
      await f.check('El aviso es el de Gemini ocupado, y siguen $left', () {
        expect(s.turns.last.error, AnswerProblem.busy);
        expect(allowance.left, left);
      });
      await _ask(f, _ownStarters[0]);
      final String free = pesos(own.ledger!.major(own.ledger!.freeUntilPayday));
      await _read(
        f,
        'La envía otra vez y ahora sí llega la respuesta: lo que puede gastar '
        'hasta el pago, con «Calculado en tu teléfono».',
        most: 1,
      );
      await f.check('Respondió con $free, lo que la cuenta calcula', () {
        expect(s.turns.last.error, isNull);
        expect(_said(f), contains(free));
        expect(model.asked, 3);
      });
      await f.check(
        'Solo la pregunta respondida gastó del día: quedan ${left - 1}',
        () async {
          expect(allowance.left, left - 1);
          final String? saved = await _setting(f, 'gemini.usage');
          expect((jsonDecode(saved!) as Map)['used'], 1);
        },
      );
    },
  ),
  AppFlow(
    '12-04-sin-preguntas-por-hoy',
    'Quedarme sin preguntas del día',
    area: _askArea,
    goal:
        'Ya usé todas las preguntas de hoy y quiero saber qué pasa si '
        'pregunto otra.',
    data: _usedUp,
    (FlowRun f) async {
      final Allowance allowance = _allowance(f);
      await _showAskPanel(f);
      await f.step(
        'Con las ${allowance.perDay} preguntas de hoy usadas, Inicio sigue '
        'ofreciendo «Pregúntale a tu plata» igual que siempre.',
      );
      await f.tap(_ownStarters[2]);
      await f.step(
        'Toca «${_ownStarters[2]}»: abre la conversación y responde «Ya '
        'usaste las preguntas de hoy. Mañana puedes seguir preguntando.»',
      );
      final Session s = _conversation(f);
      await f.check('La pregunta no salió: el aviso es el del límite', () {
        expect(s.turns.single.error, AnswerProblem.limit);
        expect(allowance.left, 0);
      });
      await f.tap('Nueva');
      await f.step(
        'Toca «Nueva»: debajo de las cinco preguntas dice «Ya no te quedan '
        'preguntas hoy».',
      );
      await f.check('Dice que no queda ninguna pregunta hoy', () {
        expect(find.text('Ya no te quedan preguntas hoy'), findsOneWidget);
      });
      await f.tap(_ownStarters[3]);
      await f.step(
        'Aun así toca «${_ownStarters[3]}»: sale el mismo aviso del límite, '
        'sin esperar a Gemini.',
      );
      await f.check('Tampoco salió, y el límite sigue en cero', () {
        expect(s.turns.single.question, _ownStarters[3]);
        expect(s.turns.single.error, AnswerProblem.limit);
        expect(allowance.left, 0);
      });
      await f.tapTip('Atrás');
      await _showAskPanel(f);
      await f.tap(_ownStarters[0]);
      await f.step(
        'De vuelta en Inicio toca «${_ownStarters[0]}»: la conversación abre '
        'con el mismo aviso, nada se le pregunta a Gemini.',
      );
      await f.check('Desde Inicio tampoco sale: otra vez el límite', () {
        final Session again = _conversation(f);
        expect(again.turns.single.question, _ownStarters[0]);
        expect(again.turns.single.error, AnswerProblem.limit);
        expect(allowance.left, 0);
      });
      await f.check(
        'Lo guardado del día sigue en ${allowance.perDay} usadas: ningún '
        'intento contó de más',
        () async {
          final String? saved = await _setting(f, 'gemini.usage');
          expect((jsonDecode(saved!) as Map)['used'], allowance.perDay);
        },
      );
    },
  ),
  AppFlow(
    '12-05-de-donde-salen-las-cifras',
    'Ver de dónde salen las cifras de una respuesta',
    area: _askArea,
    goal:
        'Quiero confiar en lo que me responde: ver que las cifras salen de '
        'mis cuentas y poder reportar una respuesta mala.',
    data: fullAccount,
    manual: <String>[
      'Enviar un reporte de verdad con «Enviar reporte»: necesita red y App '
          'Check, y le llega a DL SOFT.',
      'El aviso «No se pudo enviar» cuando el reporte no llega.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final String free = pesos(own.ledger!.major(own.ledger!.freeUntilPayday));
      final Session s = await _openAsk(
        f,
        clientFor: (List<dartantic.Tool> tools) => _StandIn(tools),
      );
      await f.tap(_ownStarters[0]);
      await f.step(
        'Aquí contesta un modelo de prueba con las mismas herramientas, no '
        'Gemini. Debajo de la respuesta: «Calculado en tu teléfono» y '
        '«Reportar».',
      );
      await f.check(
        'La respuesta dice $free, lo que la cuenta calcula para gastar',
        () => expect(_said(f), contains(free)),
      );
      await f.tap('Calculado en tu teléfono');
      await f.step(
        'Toca «Calculado en tu teléfono»: «Cómo se calculó» lista lo que se '
        'calculó en el teléfono, y Gemini solo lo explica.',
      );
      await f.check('Lista el cálculo que usó la respuesta', () {
        expect(s.turns.single.computed.single.tool, 'account_overview');
        expect(
          find.text(
            'Tus saldos, lo comprometido, el colchón y lo que puedes gastar '
            'hasta el pago',
          ),
          findsOneWidget,
        );
      });
      await f.tap('Ver cómo se calcula lo que puedes gastar');
      await f.page(
        '«Ver cómo se calcula lo que puedes gastar» abre la suma cuenta por '
        'cuenta, la misma de «¿De dónde sale?» en Inicio.',
      );
      await f.check('La suma termina en $free, la cifra de la respuesta', () {
        expect(_said(f), contains('Puedes gastar hasta el'));
        expect(_said(f), contains(free));
      });
      await f.back();
      await f.tap('Reportar');
      await f.step(
        'Toca «Reportar»: pide qué tiene de malo, deja contar más y dice qué '
        'le llega a DL SOFT. «Enviar reporte» está apagado.',
      );
      await f.check('Sin escoger un motivo no se puede enviar', () {
        expect(_sendReport(f).onPressed, isNull);
      });
      await f.tap('Es ofensiva o inapropiada');
      await f.tap('Otra cosa');
      await f.check('Los motivos son excluyentes: queda «Otra cosa»', () {
        expect(_reason(f), ReportReason.other);
      });
      await f.tap('Es incorrecta o engañosa');
      await f.type('Cuéntanos más (opcional)', 'La cifra no cuadra.');
      await f.step(
        'Escoge «Es incorrecta o engañosa» y escribe un comentario: ahora '
        '«Enviar reporte» se puede tocar.',
      );
      await f.check('Con un motivo, «Enviar reporte» se enciende', () {
        expect(_reason(f), ReportReason.wrong);
        expect(_sendReport(f).onPressed, isNotNull);
      });
      await f.back();
      await f.step(
        'Cierra la hoja sin enviar: la respuesta sigue con «Reportar», nada '
        'se mandó.',
      );
      await f.check('Cerrar sin enviar no marca la respuesta', () {
        expect(s.turns.single.reported, isFalse);
        expect(find.text('Reportar'), findsOneWidget);
      });
      await f.tap('Reportar');
      await f.check('Al abrirla otra vez, el motivo y el comentario se '
          'perdieron', () {
        expect(_reason(f), isNull);
        expect(
          f.tester
              .widget<TextField>(
                find.widgetWithText(TextField, 'Cuéntanos más (opcional)'),
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(_sendReport(f).onPressed, isNull);
      });
      await f.back();
    },
  ),
  AppFlow(
    '12-06-anotar-un-gasto-preguntando',
    'Anotar un gasto desde la conversación',
    area: _askArea,
    goal:
        'Quiero anotar lo que gasté pidiéndoselo a la app, que quede en mis '
        'cuentas y poder corregirlo si me equivoqué.',
    data: fullAccount,
    manual: <String>[
      'Con Gemini de verdad: «Quiero anotar un gasto», llenar el formulario '
          'que arme, guardarlo y verlo en Movimientos con lo que puedes gastar '
          'ya rebajado.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      final Allowance allowance = _allowance(f);
      final int left = allowance.left;
      final int free = own.ledger!.freeUntilPayday;
      final int entries = own.snapshot!.entries.length;
      List<Entry> written() => <Entry>[
        for (final Entry e in own.snapshot!.entries)
          if (e.source == 'gemini') e,
      ];
      final Session s = await _openAsk(f, clientFor: _Bookkeeper.new);
      await f.tap(_ownStarters[4]);
      await _read(
        f,
        'Aquí contesta un modelo de prueba con las mismas herramientas, no '
        'Gemini. Toca «${_ownStarters[4]}»: llega un formulario para llenar '
        'antes de guardar.',
        most: 2,
      );
      await f.check('Antes de guardar no se anota nada', () {
        expect(own.snapshot!.entries, hasLength(entries));
        expect(written(), isEmpty);
      });
      await f.check(
        'Pedir el formulario gastó una pregunta del día: quedan ${left - 1}',
        () => expect(allowance.left, left - 1),
      );
      await f.type('Monto', '4500');
      await f.tap('Restaurantes');
      await f.type('Dónde', 'Tinto y pandebono');
      await f.step(
        'Con 4.500, Restaurantes y «Tinto y pandebono» en «Dónde», el '
        'formulario queda listo para guardar.',
      );
      await f.tap('Guardar gasto');
      final String after = pesos(own.ledger!.major(free - 4500));
      await _read(
        f,
        'Toca «Guardar gasto»: el formulario se apaga y la respuesta dice '
        'que quedó en tus cuentas y que ahora puedes gastar $after.',
        most: 2,
      );
      await f.check(
        'Quedó un movimiento nuevo de ${pesos(4500)} en Restaurantes, '
        '«Tinto y pandebono»',
        () {
          expect(own.snapshot!.entries, hasLength(entries + 1));
          final Entry e = written().single;
          expect(e.amount.toString(), '-4500');
          expect(e.category, 'restaurants');
          expect(e.payee, 'Tinto y pandebono');
        },
      );
      await f.check(
        'Lo que puedes gastar pasó de ${pesos(own.ledger!.major(free))} a '
        '$after, como dice la respuesta',
        () {
          expect(own.ledger!.freeUntilPayday, free - 4500);
          expect(_said(f), contains(after));
        },
      );
      await f.check(
        'Guardar también gastó una pregunta del día: quedan ${left - 2}',
        () => expect(allowance.left, left - 2),
      );
      await f.tap('Editar');
      await f.type('Monto', '5500');
      await f.tap('Guardar gasto');
      final String corrected = pesos(own.ledger!.major(free - 5500));
      await _read(
        f,
        '«Editar» en el recibo, 5.500 y «Guardar gasto» otra vez: la nueva '
        'respuesta dice $corrected, y arriba sigue la anterior con $after.',
        most: 1,
      );
      await f.check(
        'Sigue habiendo un solo gasto, ahora de ${pesos(5500)}: puedes '
        'gastar $corrected',
        () {
          expect(own.snapshot!.entries, hasLength(entries + 1));
          expect(written().single.amount.toString(), '-5500');
          expect(own.ledger!.freeUntilPayday, free - 5500);
          expect(find.textContaining('Gasto guardado · '), findsOneWidget);
        },
      );
      await f.tap('Calculado en tu teléfono');
      await f.step(
        'Bajo la respuesta, «Calculado en tu teléfono»: «Cómo se calculó» '
        'dice que la cifra salió del gasto que se registró.',
      );
      await f.check(
        'El cálculo de la respuesta es el gasto que se registró',
        () {
          expect(s.turns.last.computed.single.tool, 'record_expense');
          expect(find.text('El gasto que se registró'), findsOneWidget);
        },
      );
      await f.back();
      await f.tapTip('Atrás');
      await f.top();
      await f.step(
        'De vuelta en Inicio, «Puedes gastar» ya cuenta el tinto: '
        '$corrected.',
      );
      await f.check('Inicio dice $corrected, lo mismo que la conversación', () {
        expect(_said(f), contains(corrected));
      });
    },
  ),
  AppFlow(
    '12-07-guardar-con-la-ultima-pregunta',
    'Anotar un gasto con la última pregunta del día',
    area: _askArea,
    goal:
        'Me queda una sola pregunta hoy y quiero anotar un gasto '
        'conversando.',
    data: _oneLeft,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Allowance allowance = _allowance(f);
      final int entries = own.snapshot!.entries.length;
      final int free = own.ledger!.freeUntilPayday;
      final Session s = await _openAsk(f, clientFor: _Bookkeeper.new);
      await f.step(
        'Aquí contesta un modelo de prueba, no Gemini. Debajo de las '
        'preguntas dice «Te queda una pregunta hoy».',
      );
      await f.check('Queda una sola pregunta del día', () {
        expect(allowance.left, 1);
        expect(find.text('Te queda una pregunta hoy'), findsOneWidget);
      });
      await f.tap(_ownStarters[4]);
      await f.type('Monto', '4500');
      await f.step(
        'Toca «${_ownStarters[4]}»: el formulario llega con esa última '
        'pregunta, y escribe 4.500.',
      );
      await f.check('Pedir el formulario se llevó la última pregunta', () {
        expect(allowance.left, 0);
        expect(s.turns.single.error, isNull);
      });
      final String form = s.turns.single.surfaceIds.single;
      await f.tap('Guardar gasto');
      await _read(
        f,
        'Toca «Guardar gasto»: no se guarda; dice «Tocaste una acción» y «Ya '
        'usaste las preguntas de hoy», y el formulario lleno no se puede '
        'guardar hasta mañana.',
        most: 2,
      );
      await f.check('El gasto no quedó en sus cuentas: puede gastar '
          '${pesos(own.ledger!.major(free))}, como antes', () {
        expect(own.snapshot!.entries, hasLength(entries));
        expect(own.ledger!.freeUntilPayday, free);
        expect(s.turns.last.error, AnswerProblem.limit);
        expect(s.settledOf(form), isNull);
        expect(allowance.left, 0);
      });
      await f.check('Nada en pantalla dice que el gasto se guardó', () {
        expect(find.text('Guardaste el gasto'), findsNothing);
        expect(find.textContaining('Gasto guardado · '), findsNothing);
      });
    },
  ),
];

/// The questions offered for the person's own accounts.
const List<String> _ownStarters = <String>[
  '¿Cuánto puedo gastar antes de que me paguen?',
  '¿En qué se me fue la plata este mes?',
  '¿Cuánto tengo en total, con dólares y cripto?',
  '¿Cómo voy comparado con el mes pasado?',
  'Quiero anotar un gasto',
];

const String _seeRecorded = 'Mira lo que respondió Gemini de verdad';

/// The demo's conversation.
/// The trip to Cartagena in the account the conversation is about, as it is
/// now: the example keeps its goals in its own database, by name.
Goal _trip(Session s) => s.ledger.goals.firstWhere(
  (Goal g) => g.name.toLowerCase().contains('cartagena'),
);

Session _demo(FlowRun f) =>
    f.tester.widget<HomePage>(find.byType(HomePage)).session;

AppSettings _settings(FlowRun f) =>
    f.tester.widget<HomePage>(find.byType(HomePage)).settings;

QuincenaStore _store(FlowRun f) =>
    f.tester.widget<QuincenaApp>(find.byType(QuincenaApp)).store!;

Future<String?> _setting(FlowRun f, String key) async =>
    f.tester.runAsync<String?>(() => _store(f).setting(key));

/// Everything on screen, with the space after a sign as a plain one.
String _said(FlowRun f) => f.screenText.replaceAll(' ', ' ');

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final Finder _askField = find.descendant(
  of: find.byType(AskBar),
  matching: find.byType(TextField),
);

final Finder _dialogField = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

String _hint(FlowRun f) =>
    f.tester.widget<TextField>(_askField).decoration!.hintText ?? '';

String _askText(FlowRun f) =>
    f.tester.widget<TextField>(_askField).controller!.text;

/// Types [question] in the ask bar and sends it.
Future<void> _ask(FlowRun f, String question) async {
  await f.tester.enterText(_askField, question);
  await settle(f.tester);
  await f.tapTip('Preguntar');
}

GoalPlanner _planner(FlowRun f) =>
    f.tester.widget<GoalPlanner>(find.byType(GoalPlanner).last);

final Finder _ticked = find.byWidgetPredicate(
  (Widget w) => w is Checkbox && w.value == true,
);

Finder _box(String name) => find.byWidgetPredicate(
  (Widget w) =>
      w is Checkbox && w.semanticLabel == 'Seleccionar $name para cancelar',
);

/// Ticks [name] in the latest list that has it.
Future<void> _tick(FlowRun f, String name) => f.tapFound(_box(name));

Future<void> _untick(FlowRun f, String name) => f.tapFound(_box(name));

int _price(Ledger ledger, String name) =>
    ledger.subscriptions.firstWhere((s) => s.name == name).price;

ScrollPosition _scroll(FlowRun f) => f.tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(FollowedScroll),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// The surface that answered [turn].
Finder _surfaceOf(Session s, Turn turn) => find.byWidgetPredicate(
  (Widget w) =>
      w is Surface && w.surfaceContext.surfaceId == turn.surfaceIds.last,
);

/// Whether the top of what [finder] finds is in the upper part of the
/// screen.
bool _inView(FlowRun f, Finder finder) {
  final double top = f.tester.getTopLeft(finder.last).dy;
  return top >= 0 && top < 874 / 2;
}

/// Pictures of the newest answer, from where the conversation put it to
/// its end: [caption] under the first, "(sigue)" under the rest.
Future<void> _read(FlowRun f, String caption, {int most = 4}) async {
  final ScrollPosition list = _scroll(f);
  // Where the newest turn starts, as the conversation scrolled to it.
  var offset = list.pixels;
  final double stride = list.viewportDimension * 0.8;
  // The room left under the last answer is not part of it.
  final double end = list.maxScrollExtent;
  var part = 1;
  while (true) {
    await f.step(part == 1 ? caption : '(sigue) $caption');
    if (offset >= end - 120 || part >= most) break;
    offset = (offset + stride).clamp(0, end);
    list.jumpTo(offset);
    await settle(f.tester);
    part++;
  }
}

/// The replay's slider.
class RecordedSlider {
  RecordedSlider(FlowRun f) : _slider = f.tester.widget<Slider>(_replaySlider);

  final Slider _slider;

  double get value => _slider.value;
  double get max => _slider.max;
}

/// The slider that steps through a replay, above the answer it replays,
/// which may have sliders of its own.
final Finder _replaySlider = find.byType(Slider).first;

/// Taps the replay's slider where step [position] is.
Future<void> _seek(FlowRun f, int position) async {
  final Finder found = _replaySlider;
  final Slider slider = f.tester.widget<Slider>(found);
  final Rect track = f.tester.getRect(found);
  await f.tester.tapAt(
    Offset(track.left + track.width * position / slider.max, track.center.dy),
  );
  await settle(f.tester);
}

/// How much [c] moved between August and September in [ledger].
int _moved(Ledger ledger, Category c) =>
    (ledger.spentOn(c, 2026, 9) - ledger.spentOn(c, 2026, 8)).abs();

/// The day's questions, as the app counts them.
Allowance _allowance(FlowRun f) =>
    f.tester.widget<OwnShell>(find.byType(OwnShell)).modes.allowance!;

/// The conversation on the ask page, once it has a turn.
Session _conversation(FlowRun f) =>
    f.tester.widget<Conversation>(find.byType(Conversation)).session;

/// Any of the notices an answer that did not arrive shows.
final Finder _problem = find.byWidgetPredicate(
  (Widget w) =>
      w is Text &&
      const <String>[
        'La key no funcionó. Revísala en Ajustes.',
        'El modelo está recibiendo demasiadas preguntas. Prueba en un minuto.',
        'Ya usaste las preguntas de hoy. Mañana puedes seguir preguntando.',
        'Sin conexión a internet. Tus cuentas y movimientos siguen '
            'funcionando; vuelve a preguntar cuando tengas red.',
        'No pude responder esta vez. Prueba de nuevo.',
      ].contains(w.data),
);

/// Every hint the ask bar can turn to.
List<String> _hints(FlowRun f) =>
    f.tester.widget<AskBar>(find.byType(AskBar)).examples;

/// Lets the ask bar's hint turn until it shows [example].
Future<void> _hintTo(FlowRun f, String example) async {
  for (var i = 0; i < 10 && _hint(f) != 'Por ejemplo: $example'; i++) {
    await f.tester.pump(AskBar.turn);
  }
  await settle(f.tester);
}

/// The reason picked in the report sheet.
ReportReason? _reason(FlowRun f) => f.tester
    .widget<RadioGroup<ReportReason>>(find.byType(RadioGroup<ReportReason>))
    .groupValue;

FilledButton _sendReport(FlowRun f) => f.tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Enviar reporte'),
);

/// Opens the ask page over the person's own accounts with a conversation
/// that answers through [client] or [clientFor] instead of Gemini.
Future<Session> _openAsk(
  FlowRun f, {
  ModelClient? client,
  ModelClient Function(List<dartantic.Tool> tools)? clientFor,
}) async {
  final OwnController own = f.own;
  final Allowance allowance = _allowance(f);
  final Session session = Session(
    mode: AgentMode.gemini,
    client: client,
    clientFor: clientFor,
    ledgerOf: () => own.ledger!,
    toolsFor: (_) => ownTools(own),
    own: true,
    allowance: allowance,
  );
  addTearDown(session.dispose);
  // Pushed, not awaited: the page stays open for its pictures.
  unawaited(
    Navigator.of(f.tester.element(find.byType(OwnShell))).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            AskPage(own: own, allowance: allowance, session: session),
      ),
    ),
  );
  await settle(f.tester);
  return session;
}

/// The person's account with every question of the day already asked.
Future<QuincenaStore> _usedUp() => _used(30);

/// The person's account with every question of the day asked but one.
Future<QuincenaStore> _oneLeft() => _used(29);

Future<QuincenaStore> _used(int used) async {
  final QuincenaStore store = await fullAccount();
  await store.setSetting(
    'gemini.usage',
    jsonEncode(<String, Object>{
      'day': '${screensNow.year}-${screensNow.month}-${screensNow.day}',
      'used': used,
    }),
  );
  return store;
}

/// Answers what can be spent until payday the way a model does: it asks the
/// account through its tools, on the phone, and writes the answer in the
/// catalog's components. No network, and never shown as Gemini's.
class _StandIn implements ModelClient {
  _StandIn(List<dartantic.Tool> tools, {List<Object>? failures})
    : _tools = <String, dartantic.Tool>{
        for (final dartantic.Tool t in tools) t.name: t,
      },
      _failures = failures ?? <Object>[];

  final Map<String, dartantic.Tool> _tools;

  /// What the next questions fail with, in order, before one is answered.
  final List<Object> _failures;
  int _serial = 0;

  /// How many questions reached it.
  int asked = 0;

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    asked++;
    if (_failures.isNotEmpty) throw _failures.removeAt(0);
    final Map<Object?, Object?> overview =
        await _tools['account_overview']!.call(<String, dynamic>{})
            as Map<Object?, Object?>;
    final String id = 'prueba-${++_serial}';
    final String payday = dayMonth(
      DateTime.parse(overview['nextPayday']! as String),
    );
    String block(Map<String, Object?> message) =>
        '```json\n${jsonEncode(<String, Object?>{'version': 'v0.9', ...message})}\n```\n';
    yield block(<String, Object?>{
      'createSurface': <String, Object?>{
        'surfaceId': id,
        'catalogId': quincenaCatalog.catalogId,
      },
    });
    yield block(<String, Object?>{
      'updateComponents': <String, Object?>{
        'surfaceId': id,
        'components': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'root',
            'component': 'Answer',
            'children': <String>['head', 'free'],
          },
          <String, Object?>{
            'id': 'head',
            'component': 'Headline',
            'kicker': 'Hasta tu pago',
            'title': 'Esto puedes gastar hasta el $payday',
            'body':
                'Ya quité los pagos que vienen antes de esa fecha y tu '
                'colchón.',
          },
          <String, Object?>{
            'id': 'free',
            'component': 'StatTile',
            'label': 'Puedes gastar',
            'value': <String, Object?>{
              'call': 'money',
              'args': <String, Object?>{'amount': overview['freeUntilPayday']},
            },
            'caption': 'hasta el $payday',
          },
        ],
      },
    });
  }
}

/// Writes down an expense the way a model does: a form first, and once the
/// person saves it, record_expense with what the form sent, through the
/// tools the conversation hands it. No network, and never shown as Gemini's.
class _Bookkeeper implements ModelClient {
  _Bookkeeper(List<dartantic.Tool> tools)
    : _tools = <String, dartantic.Tool>{
        for (final dartantic.Tool t in tools) t.name: t,
      };

  final Map<String, dartantic.Tool> _tools;
  int _serial = 0;

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    final String id = 'gasto-${++_serial}';
    final Object? sent = prompt.trimLeft().startsWith('{')
        ? jsonDecode(prompt)
        : null;
    if (sent case {
      'action': {
        'name': 'save_expense',
        'context': final Map<Object?, Object?> form,
      },
    }) {
      final Map<Object?, Object?> saved =
          await _tools['record_expense']!.call(<String, dynamic>{
                'amount': form['amount'],
                'category': form['category'],
                'note': form['note'],
                'id': form['id'],
              })
              as Map<Object?, Object?>;
      yield* _blocks(
        id,
        AgentTurn(
          components: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'root',
              'component': 'Answer',
              'children': <String>['head', 'free'],
            },
            <String, Object?>{
              'id': 'head',
              'component': 'Headline',
              'kicker': 'Guardado',
              'title': 'Listo: quedó en tus cuentas',
            },
            <String, Object?>{
              'id': 'free',
              'component': 'StatTile',
              'label': 'Ahora puedes gastar',
              'value': <String, Object?>{
                'call': 'money',
                'args': <String, Object?>{'amount': saved['freeUntilPayday']},
              },
              'caption': 'hasta tu próximo pago',
            },
          ],
        ),
      );
      return;
    }
    Map<String, Object?> path(String to) => <String, Object?>{'path': to};
    yield* _blocks(
      id,
      AgentTurn(
        components: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'root',
            'component': 'Answer',
            'children': <String>['head', 'form'],
          },
          <String, Object?>{
            'id': 'head',
            'component': 'Headline',
            'kicker': 'Nuevo gasto',
            'title': 'Anoto un gasto',
            'body': 'Corrige lo que haga falta antes de guardar.',
          },
          <String, Object?>{
            'id': 'form',
            'component': 'Group',
            'title': 'Hoy',
            'children': <String>['amount', 'category', 'note', 'save'],
          },
          <String, Object?>{
            'id': 'amount',
            'component': 'MoneyField',
            'label': 'Monto',
            'value': path('/draft/amount'),
            'checks': <Object?>[
              <String, Object?>{
                'condition': <String, Object?>{
                  'call': 'numeric',
                  'args': <String, Object?>{
                    'value': path('/draft/amount'),
                    'min': 1,
                  },
                },
                'message': 'Escribe un monto mayor que cero.',
              },
            ],
          },
          <String, Object?>{
            'id': 'category',
            'component': 'CategoryChoice',
            'label': 'Categoría',
            'value': path('/draft/category'),
          },
          <String, Object?>{
            'id': 'note',
            'component': 'TextEntry',
            'label': 'Dónde',
            'value': path('/draft/note'),
          },
          <String, Object?>{
            'id': 'save',
            'component': 'ActionButton',
            'label': 'Guardar gasto',
            'emphasis': 'primary',
            'onPressed': <String, Object?>{
              'event': <String, Object?>{
                'name': 'save_expense',
                'context': <String, Object?>{
                  'amount': path('/draft/amount'),
                  'category': path('/draft/category'),
                  'note': path('/draft/note'),
                },
              },
            },
          },
        ],
        data: <String, Object?>{
          'draft': <String, Object?>{
            'amount': 0,
            'category': 'groceries',
            'note': '',
          },
        },
      ),
    );
  }

  /// [answer]'s messages, each in the block a model writes it in.
  Stream<String> _blocks(String id, AgentTurn answer) async* {
    for (final core.A2uiMessage m in answer.messages(
      id,
      quincenaCatalog.catalogId!,
    )) {
      yield '```json\n${jsonEncode(m.toJson())}\n```\n';
    }
  }
}

/// Taps [text], which asks Gemini, and waits for the answer or its notice
/// without waiting for the screen to be still: while it thinks, it moves.
Future<void> _tapWaiting(FlowRun f, String text) async {
  final Finder found = find.text(text);
  await f.reveal(found);
  await f.tester.tap(found.last);
  await _answered(f);
}

/// Waits up to 30 seconds for the conversation's answer, or its notice.
Future<void> _answered(FlowRun f) async {
  final Stopwatch watch = Stopwatch()..start();
  while (find.byType(Conversation).evaluate().isEmpty ||
      _conversation(f).busy) {
    if (watch.elapsed > const Duration(seconds: 30)) {
      throw StateError('No answer after 30 s: ${f.screenText}');
    }
    await f.tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await f.tester.pump(const Duration(milliseconds: 100));
  }
  await settle(f.tester);
}

/// Types [question] in the ask bar and sends it to Gemini, waiting as
/// [_tapWaiting] does.
Future<void> _askWaiting(FlowRun f, String question) async {
  await f.tester.enterText(_askField, question);
  await settle(f.tester);
  await f.tester.tap(find.byTooltip('Preguntar'));
  await _answered(f);
}

/// Scrolls Inicio until «Pregúntale a tu plata» shows whole, near the top.
Future<void> _showAskPanel(FlowRun f) async {
  final Finder first = find.text(_ownStarters[0]);
  await f.reveal(first);
  await Scrollable.ensureVisible(f.tester.element(first), alignment: 0.2);
  await settle(f.tester);
}

/// The ask bar's send button.
IconButton _sendButton(FlowRun f) => f.tester.widget<IconButton>(
  find.descendant(of: find.byType(AskBar), matching: find.byType(IconButton)),
);
