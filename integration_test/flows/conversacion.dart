// Flows of La demo y sus respuestas (11), Preguntar con tus cuentas (12).
import 'dart:async';
import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show ChatMessage, Surface;
import 'package:quincena/agent/catalog.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/ai/allowance.dart';
import 'package:quincena/app.dart';
import 'package:quincena/catalog/goal_planner.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/data/ledger.dart' show Goal, Ledger, Movement;
import 'package:quincena/format/dates.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/functions/money_functions.dart' show monthlyNeeded;
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/ask_bar.dart';
import 'package:quincena/ui/conversation.dart';
import 'package:quincena/ui/home_page.dart';
import 'package:quincena/ui/own/ask_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/ui/own/onboarding_page.dart';

import '../../test/own_flow_test.dart' show settle;
import '../../test_screens/accounts.dart' show screensNow;
import '../tour.dart';
import 'flow.dart';

const String _demoArea = 'La demo';
const String _askArea = 'Preguntar con tus cuentas';

final List<AppFlow> conversacionFlows = <AppFlow>[
  AppFlow(
    '11-01-entrar-a-la-demo',
    'Entrar a la demo desde la primera pantalla',
    area: _demoArea,
    goal:
        'Antes de poner mis cuentas quiero ver cómo funciona la app con '
        'datos de ejemplo.',
    (FlowRun f) async {
      await f.step(
        'Primera pantalla: «Con mis cuentas» o «Con datos de ejemplo», y '
        'abajo la nota de que todo se guarda solo en este dispositivo.',
      );
      await f.tap('Con datos de ejemplo');
      final Session s = _demo(f);
      final Ledger ledger = s.ledger;
      final String free = pesos(ledger.major(ledger.freeUntilPayday));
      await f.page(
        'Toca «Con datos de ejemplo»: arriba dice «DEMO», el aviso ofrece '
        '«Usar con mis cuentas» y debajo están lo que puede gastar y cinco '
        'preguntas.',
      );
      await f.check(
        'La app recuerda la demo y abre en ella la próxima vez',
        () async => expect(await _setting(f, 'app.mode'), 'demo'),
      );
      await f.check(
        'La tarjeta dice que Valentina puede gastar $free, lo que calcula su '
        'cuenta',
        () => expect(_said(f), contains(free)),
      );
      await f.tap('¿De dónde sale?');
      await f.page(
        'Toca «¿De dónde sale?»: una hoja resta de lo que hay hoy cada pago '
        'que vence hasta el 15 de octubre, y dice lo que supone.',
      );
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
      await _ask(f, unknown);
      await _read(
        f,
        'Con «$unknown» no reconoce nada: dice «En la demo respondo estas '
        'preguntas» y ofrece las cinco como botones.',
        most: 2,
      );
      await f.check('Ofrece las cinco preguntas que sí sabe responder', () {
        expect(s.turns.last.question, unknown);
        expect(_said(f), contains('En la demo respondo estas preguntas'));
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
    (FlowRun f) async {
      final Session s = _demo(f);
      final Ledger ledger = s.ledger;
      final Goal goal = ledger.goal('cartagena');
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
        expect(ledger.goal('cartagena').monthly, goal.monthly);
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
        expect(ledger.goal('cartagena').monthly, needed);
      });
      await f.check('El control guardado ya no se mueve', () {
        expect(s.settledOf(s.turns.first.surfaceIds.single), isNotNull);
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
        expect(ledger.goal('cartagena').monthly, 700000);
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
      await f.tap('Cambiar selección');
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
      final Session s = _demo(f);
      final Ledger ledger = s.ledger;
      final int free = ledger.freeUntilPayday;
      final Set<Movement> before = Set<Movement>.identity()
        ..addAll(ledger.movements);
      List<Movement> added() => <Movement>[
        for (final Movement m in ledger.movements)
          if (!before.contains(m)) m,
      ];
      await f.tap(ScriptedAgent.starters[4]);
      await _read(
        f,
        'Toca «Registra 45 mil en el mercado»: llega un formulario con '
        '45.000 y Mercado ya puestos, para corregir antes de guardar.',
      );
      await f.type('Monto', '');
      await f.step(
        'Borra el monto: debajo aparece «Escribe un monto mayor que cero.»',
      );
      await f.type('Monto', '99000000');
      await f.step(
        'Escribe 99.000.000: avisa «Es más de lo que hay en la cuenta.»',
      );
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
        'Lo que puede gastar pasó de ${pesos(ledger.major(free))} a '
        '${pesos(ledger.major(free - 52000))}, como dice la respuesta',
        () {
          expect(ledger.freeUntilPayday, free - 52000);
          expect(
            _said(f),
            contains(
              'Ahora puedes gastar ${pesos(ledger.major(free - 52000))}',
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
        expect(ledger.freeUntilPayday, free - 60000);
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
      final Session s = _demo(f);
      final int free = s.ledger.freeUntilPayday;
      await f.tap(ScriptedAgent.starters[4]);
      await f.tap('Guardar gasto');
      await f.step(
        'Con un gasto de 45.000 guardado en la conversación, arriba a la '
        'derecha aparece «Nueva».',
      );
      await f.tap('Nueva');
      await f.step(
        'Toca «Nueva»: vuelven las preguntas de inicio y abajo «Empezaste '
        'una conversación nueva.» con «Deshacer».',
      );
      await f.check('La conversación quedó vacía y la cuenta como al '
          'principio', () {
        expect(s.turns, isEmpty);
        expect(s.ledger.freeUntilPayday, free);
      });
      await f.tap('Deshacer');
      await f.step(
        'Toca «Deshacer»: vuelve la conversación anterior, con su recibo '
        '«Gasto guardado».',
      );
      await f.check(
        'Volvió el gasto: puede gastar ${pesos(s.ledger.major(free - 45000))}',
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
      await f.tapTip('Ajustes');
      await f.tap('Empezar de nuevo');
      await f.step(
        'En «Ajustes», «Empezar de nuevo» también limpia la conversación, '
        'pero sin «Deshacer».',
      );
      await f.check('«Empezar de nuevo» deja la conversación vacía', () {
        expect(s.turns, isEmpty);
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
      await f.waitFor(find.text(_seeRecorded));
      await f.reveal(find.text(_seeRecorded));
      await f.step(
        'Al final del inicio de la demo está «Mira lo que respondió Gemini '
        'de verdad».',
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
      await f.tester.drag(find.byType(Slider), const Offset(-800, 0));
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
      await f.back();
      await f.check('Ver las grabaciones no toca la conversación', () {
        expect(_demo(f).turns, isEmpty);
      });
    },
  ),
  AppFlow(
    '11-10-quien-responde',
    'Escoger quién responde en la demo',
    area: _demoArea,
    goal:
        'Quiero saber quién contesta en la demo y probar con Gemini en vez '
        'del guion.',
    demo: true,
    manual: <String>[
      'Preguntar con «Gemini» elegido: necesita red y que App Check '
          'reconozca la app.',
      'Pegar una key real de Gemini en «Tu key», tocar «Conectar» y '
          'preguntar algo que no está en las cinco preguntas.',
    ],
    (FlowRun f) async {
      final Session s = _demo(f);
      await f.tapTip('Ajustes');
      await f.page(
        'Toca el engranaje: «Ajustes» de la demo, con quién responde, '
        'idioma, apariencia, modo desarrollador y cómo salir.',
      );
      await f.check('Responde el guion de la demo', () {
        expect(s.mode, AgentMode.demo);
      });
      await f.tap('Tu key');
      await f.step(
        'Toca «Tu key»: explica que la key no se guarda y pide «Key de '
        'Gemini» con el botón «Conectar».',
      );
      await f.tap('Conectar');
      await f.check('«Conectar» sin key no cambia quién responde', () {
        expect(s.mode, AgentMode.demo);
        expect(find.text('Key de Gemini'), findsOneWidget);
      });
      await f.tap('Gemini');
      await f.step(
        'Toca «Gemini»: responde el modelo a través de Quincena, sin key, y '
        'se puede preguntar cualquier cosa sobre la cuenta.',
      );
      await f.check('Ahora responde Gemini a través de Quincena', () {
        expect(s.mode, AgentMode.gemini);
      });
      await f.back();
      await f.step(
        'Cierra Ajustes: la etiqueta de arriba dice «EN VIVO», porque ya no '
        'responde el guion.',
      );
      await f.check('Con Gemini respondiendo, arriba dice «EN VIVO»', () {
        expect(find.text('EN VIVO'), findsOneWidget);
        expect(find.text('DEMO'), findsNothing);
      });
      await f.tapTip('Ajustes');
      await f.tap('Demo');
      await f.back();
      await f.step(
        'De vuelta en «Demo»: la etiqueta dice «DEMO» y responden otra vez '
        'las cinco preguntas, sin red.',
      );
      await f.check('Volvió a responder el guion', () {
        expect(s.mode, AgentMode.demo);
        expect(find.text('DEMO'), findsOneWidget);
      });
    },
  ),
  AppFlow(
    '11-11-idioma-y-apariencia',
    'Cambiar el idioma y la apariencia',
    area: _demoArea,
    goal: 'Quiero ver la demo en inglés y en modo oscuro.',
    demo: true,
    (FlowRun f) async {
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
      await f.tapTip('Settings');
      await f.tap('Español');
      await f.tap('Oscuro');
      await f.step(
        'Vuelve a «Español» y toca «Oscuro» en Apariencia: toda la app se '
        'pone oscura.',
      );
      await f.check('Quedó en español y en modo oscuro', () {
        expect(settings.locale, const Locale('es'));
        expect(settings.themeMode, ThemeMode.dark);
      });
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
      await f.check('Idioma y apariencia siguen al teléfono', () {
        expect(settings.locale, isNull);
        expect(settings.themeMode, ThemeMode.system);
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
    (FlowRun f) async {
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
        'Cierra el inspector y en Ajustes toca «Copiar la sesión»: avisa '
        'que se copió sin lo que escribió.',
      );
      await f.check('Lo copiado trae la sesión sin «Regalo para mamá»', () {
        expect(copied, isNotNull);
        expect(copied, contains('"draft"'));
        expect(copied, isNot(contains('Regalo para mamá')));
      });
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
    'Pasar de la demo a mis cuentas',
    area: _demoArea,
    goal: 'Ya entendí cómo funciona y quiero empezar con mis propias cuentas.',
    demo: true,
    (FlowRun f) async {
      await f.tap('Usar con mis cuentas');
      await f.step(
        'Toca «Usar con mis cuentas» en el aviso: empieza a crear la cuenta, '
        'paso 1, con tu nombre.',
      );
      await f.check('Se abrió la configuración de la cuenta', () {
        expect(find.byType(OnboardingPage), findsOneWidget);
      });
      await f.tapTip('Atrás');
      await f.step(
        'Toca la flecha «Atrás» en el primer paso: vuelve a la demo, donde '
        'estaba.',
      );
      await f.check('Volvió a la demo y la recuerda', () async {
        expect(find.byType(HomePage), findsOneWidget);
        expect(await _setting(f, 'app.mode'), 'demo');
      });
      await f.tapTip('Ajustes');
      await f.reveal(find.text('Usar con mis cuentas'));
      await f.step(
        'En Ajustes, al final, está el mismo botón «Usar con mis cuentas».',
      );
      await f.tap('Usar con mis cuentas');
      await f.check('Desde Ajustes también abre la configuración', () {
        expect(find.byType(OnboardingPage), findsOneWidget);
      });
    },
  ),
  AppFlow(
    '11-14-ver-el-ejemplo-y-volver',
    'Mirar la demo y volver a mis cuentas',
    area: _demoArea,
    goal:
        'Ya tengo mis cuentas, pero quiero mostrarle la demo a alguien y '
        'volver a lo mío.',
    data: fullAccount,
    (FlowRun f) async {
      final int entries = f.own.snapshot!.entries.length;
      await f.tapTip('Ajustes');
      await f.reveal(find.text('Ver los datos de ejemplo'));
      await f.step(
        'En Ajustes de mis cuentas está «Ver los datos de ejemplo».',
      );
      await f.tap('Ver los datos de ejemplo');
      await f.step(
        'Lo toca: abre la demo de Valentina, y el aviso ahora ofrece '
        '«Volver a mis cuentas».',
      );
      await f.check(
        'La demo sabe que hay cuentas propias a las que volver',
        () {
          expect(find.text('Volver a mis cuentas'), findsOneWidget);
        },
      );
      await f.tap('Volver a mis cuentas');
      await f.step(
        'Toca «Volver a mis cuentas»: vuelve a Inicio con todo como estaba.',
      );
      await f.check('Volvió a las cuentas propias, sin perder nada', () async {
        expect(find.byType(OwnShell), findsOneWidget);
        expect(await _setting(f, 'app.mode'), 'own');
        expect(f.own.snapshot!.entries, hasLength(entries));
      });
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
      await f.reveal(find.text('Otra pregunta'));
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
      await f.back();
      final String goal = own.goalShares.first.name;
      await _hintTo(f, '¿Llego a mi meta de $goal?');
      await f.step(
        'Sin escribir, la barra va mostrando preguntas que esta cuenta sí '
        'puede responder, como la de su meta «$goal».',
      );
      await f.check('Las pistas salen de esta cuenta: su meta, la tarjeta '
          'y la cripto', () {
        final List<String> hints = _hints(f);
        expect(hints, contains('¿Llego a mi meta de $goal?'));
        expect(hints, contains('¿Cuánto debo en la tarjeta?'));
        expect(hints, contains('¿Cómo va mi cripto esta semana?'));
      });
      await f.back();
      await f.check('Abrir y cerrar no gasta preguntas', () {
        expect(allowance.left, allowance.perDay);
      });
    },
  ),
  AppFlow(
    '12-02-preguntar-sin-gemini',
    'Preguntar cuando Gemini no responde',
    area: _askArea,
    goal:
        'Quiero saber cuánto puedo gastar antes de que me paguen, '
        'preguntándole a la app.',
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
      await f.tap(_ownStarters[0]);
      await f.waitFor(_problem, most: const Duration(seconds: 30));
      await f.step(
        'Toca «${_ownStarters[0]}» en Inicio: abre la conversación con la '
        'pregunta hecha y, sin Gemini, avisa que no pudo responder.',
      );
      final Session s = _conversation(f);
      await f.check('La pregunta quedó con un aviso, no en blanco', () {
        expect(s.turns.single.question, _ownStarters[0]);
        expect(s.turns.single.error, isNotNull);
        expect(_problem, findsOneWidget);
      });
      await f.check(
        'Una pregunta que no tuvo respuesta no gasta del día: siguen $left',
        () => expect(allowance.left, left),
      );
      await _ask(f, 'Qué es lo que más gasto?');
      await f.waitFor(_problem.at(1), most: const Duration(seconds: 30));
      await f.step(
        'Escribe otra pregunta en la barra y la envía: cada intento queda '
        'con su aviso, y la barra sigue activa para probar de nuevo.',
      );
      await f.tap('Nueva');
      await f.step(
        'Toca «Nueva»: vuelven las cinco preguntas con el cupo del día, y '
        'abajo «Deshacer».',
      );
      await f.check('Dice cuántas preguntas quedan: ${allowance.left}', () {
        expect(
          find.text('Te quedan ${allowance.left} preguntas hoy'),
          findsOneWidget,
        );
      });
      await f.tap('Deshacer');
      await f.check('«Deshacer» trae de vuelta los dos intentos', () {
        expect(s.turns, hasLength(2));
      });
    },
  ),
  AppFlow(
    '12-03-preguntar-sin-internet',
    'Preguntar sin internet',
    area: _askArea,
    goal:
        'Estoy sin señal y quiero preguntarle a la app en qué se me fue la '
        'plata este mes.',
    data: fullAccount,
    manual: <String>[
      'Con el teléfono en modo avión, preguntar de verdad y ver el mismo '
          'aviso.',
    ],
    (FlowRun f) async {
      final Allowance allowance = _allowance(f);
      final int left = allowance.left;
      final Session s = await _openAsk(f, client: _Offline());
      await f.step(
        'Simulamos que el teléfono no tiene internet y abre «Pregúntale a tu '
        'plata» con sus cinco preguntas.',
      );
      await f.tap(_ownStarters[1]);
      await f.step(
        'Toca «${_ownStarters[1]}»: dice «Sin conexión a internet» y que sus '
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
      await f.tap('Otra pregunta');
      await f.step(
        'Con las ${allowance.perDay} preguntas de hoy usadas, «Pregúntale a '
        'tu plata» dice «Ya no te quedan preguntas hoy».',
      );
      await f.check('No queda ninguna pregunta hoy', () {
        expect(allowance.left, 0);
        expect(find.text('Ya no te quedan preguntas hoy'), findsOneWidget);
      });
      await f.tap(_ownStarters[2]);
      await f.step(
        'Aun así toca «${_ownStarters[2]}»: responde «Ya usaste las '
        'preguntas de hoy. Mañana puedes seguir preguntando.»',
      );
      await f.check('La pregunta no salió: el aviso es el del límite', () {
        final Session s = _conversation(f);
        expect(s.turns.single.error, AnswerProblem.limit);
        expect(allowance.left, 0);
      });
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
      await f.back();
      await f.tap('Reportar');
      await f.step(
        'Toca «Reportar»: pide qué tiene de malo, deja contar más y dice qué '
        'le llega a DL SOFT. «Enviar reporte» está apagado.',
      );
      await f.check('Sin escoger un motivo no se puede enviar', () {
        expect(_sendReport(f).onPressed, isNull);
      });
      await f.tap('Es incorrecta o engañosa');
      await f.type('Cuéntanos más (opcional)', 'La cifra no cuadra.');
      await f.step(
        'Escoge «Es incorrecta o engañosa» y escribe un comentario: ahora '
        '«Enviar reporte» se puede tocar.',
      );
      await f.check('Con un motivo, «Enviar reporte» se enciende', () {
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
  RecordedSlider(FlowRun f)
    : _slider = f.tester.widget<Slider>(find.byType(Slider));

  final Slider _slider;

  double get value => _slider.value;
  double get max => _slider.max;
}

/// Taps the replay's slider where step [position] is.
Future<void> _seek(FlowRun f, int position) async {
  final Finder found = find.byType(Slider);
  final Slider slider = f.tester.widget<Slider>(found);
  final Rect track = f.tester.getRect(found);
  await f.tester.tapAt(
    Offset(track.left + track.width * position / slider.max, track.center.dy),
  );
  await settle(f.tester);
}

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
Future<QuincenaStore> _usedUp() async {
  final QuincenaStore store = await fullAccount();
  await store.setSetting(
    'gemini.usage',
    jsonEncode(<String, Object>{
      'day': '${screensNow.year}-${screensNow.month}-${screensNow.day}',
      'used': 30,
    }),
  );
  return store;
}

/// A phone with no connection: every question fails the way it does there.
class _Offline implements ModelClient {
  @override
  Stream<String> send(String prompt, {required List<ChatMessage> history}) =>
      Stream<String>.error(
        Exception('Failed host lookup: firebasevertexai.googleapis.com'),
      );
}

/// Answers what can be spent until payday the way a model does: it asks the
/// account through its tools, on the phone, and writes the answer in the
/// catalog's components. No network, and never shown as Gemini's.
class _StandIn implements ModelClient {
  _StandIn(List<dartantic.Tool> tools)
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
