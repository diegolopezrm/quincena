// A walk through everything the app shows, scene by scene, for review.
//
// Each scene opens the app on an account, goes somewhere and takes a
// picture of every screen it passes, scrolled from top to bottom. What
// takes the picture is up to whoever plays it: the simulator's own
// screenshot in integration_test/tour_test.dart, nothing in
// test_screens/tour_check_test.dart, which only checks the way is still
// there.
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/statements/statement.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/ui/own/statement_page.dart';

import '../test/commitments_data.dart';
import '../test/own_flow_test.dart' show fakeRates, settle;
import '../test/real_life_data.dart';
import '../test_screens/accounts.dart';

/// Takes the picture of what is on screen now, under [name].
typedef Shot = Future<void> Function(String name);

/// Somewhere to go in the app, from a fresh start on an account.
class Scene {
  const Scene(
    this.name,
    this.play, {
    this.data,
    this.dark = false,
    this.english = false,
    this.demo = false,
  });

  final String name;
  final Future<void> Function(Tour tour) play;

  /// The account to open on; null opens on none, as on a first launch.
  final Future<QuincenaStore> Function()? data;
  final bool dark;
  final bool english;
  final bool demo;
}

/// A store with no one in it yet.
Future<QuincenaStore> emptyStore() async => QuincenaStore(
  QuincenaDatabase(NativeDatabase.memory()),
  now: () => screensNow,
);

/// Everything at once: the account, what the phone caught, commitments,
/// shared expenses, variable income, a trip, a goal and two wishes.
Future<QuincenaStore> fullAccount() async {
  final QuincenaStore store = await withCaptures();
  await addCommitments(store);
  await addRealLife(store);
  await store.addGoal(
    name: 'Viaje a Cartagena',
    target: Money(Decimal.parse('2400000'), Asset.cop),
    saved: Money(Decimal.parse('650000'), Asset.cop),
    monthly: Money(Decimal.parse('300000'), Asset.cop),
    deadline: DateTime(2026, 12, 20),
  );
  return store;
}

/// Opens the app for [scene] and plays it, taking pictures with [shot].
Future<void> playScene(
  WidgetTester tester,
  Scene scene,
  Shot shot, {
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  tester.platformDispatcher.localesTestValue = <Locale>[
    Locale(scene.english ? 'en' : 'es'),
  ];
  tester.platformDispatcher.platformBrightnessTestValue = scene.dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  addTearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });
  final QuincenaStore store = (await tester.runAsync(
    scene.data ?? emptyStore,
  ))!;
  addTearDown(() => tester.runAsync(store.close));
  await tester.pumpWidget(
    QuincenaApp(
      store: store,
      startInDemo: scene.demo,
      fetcher: fakeRates(),
      now: () => screensNow,
    ),
  );
  await settle(tester);
  try {
    await scene.play(Tour(tester, shot, scene.name));
  } finally {
    // The app goes before its store closes, so nothing reads a closed one.
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }
}

/// Moves through the app the way a person would, and names its pictures in
/// the order they were taken.
class Tour {
  Tour(this.tester, this._shot, this.scene);

  final WidgetTester tester;
  final Shot _shot;
  final String scene;
  int _taken = 0;

  /// The picture of the screen as it is, without the keyboard a field
  /// that takes focus by itself brings up.
  Future<void> shot(String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Long enough for the keyboard to go, touches to fade and animations to
    // end.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await settle(tester);
    _taken++;
    await _shot('$scene-${_taken.toString().padLeft(2, '0')}-$name');
  }

  /// The tallest vertical list on the top screen, if there is one.
  ScrollableState? _list() {
    ScrollableState? found;
    for (final Element e in find.byType(Scrollable).evaluate()) {
      final ScrollableState s = (e as StatefulElement).state as ScrollableState;
      if (s.position.axis != Axis.vertical) continue;
      final RenderBox? box = e.renderObject as RenderBox?;
      if (box == null || !box.hasSize || box.size.height < 240) continue;
      found = s; // The last one in the tree sits on top.
    }
    return found;
  }

  /// Pictures of the whole screen, from its top to its end.
  Future<void> page(String name, {int most = 8}) async {
    final ScrollableState? list = _list();
    if (list == null || list.position.maxScrollExtent <= 0) {
      await shot(name);
      return;
    }
    list.position.jumpTo(0);
    await settle(tester);
    final double step = list.position.viewportDimension * 0.8;
    var part = 1;
    var offset = 0.0;
    while (true) {
      await shot(part == 1 ? name : '$name-$part');
      if (offset >= list.position.maxScrollExtent || part >= most) break;
      offset = (offset + step).clamp(0, list.position.maxScrollExtent);
      list.position.jumpTo(offset);
      await settle(tester);
      part++;
    }
    list.position.jumpTo(0);
    await settle(tester);
  }

  /// Scrolls the top list until [finder] shows.
  Future<void> reveal(Finder finder) async {
    try {
      if (finder.evaluate().isEmpty) {
        final ScrollableState? list = _list();
        if (list != null) {
          list.position.jumpTo(0);
          await settle(tester);
          await tester.scrollUntilVisible(
            finder,
            240,
            scrollable: find.byWidget(list.widget),
            maxScrolls: 60,
          );
        }
      }
      await tester.ensureVisible(finder.last);
    } on StateError {
      // What is there instead, to find the way again.
      debugPrint(
        'Not found: $finder. On screen: ${<String?>[for (final Element e in find.byType(Text).evaluate()) (e.widget as Text).data].whereType<String>().take(40).join(' | ')}',
      );
      rethrow;
    }
    await settle(tester);
  }

  /// Taps the last widget showing [text], the one on top.
  Future<void> tap(String text) async {
    final Finder f = find.text(text);
    await reveal(f);
    await tester.tap(f.last);
    await settle(tester);
  }

  Future<void> tapContaining(String text) async {
    final Finder f = find.textContaining(text);
    await reveal(f);
    await tester.tap(f.first);
    await settle(tester);
  }

  Future<void> tapTip(String tooltip) async {
    await tester.tap(find.byTooltip(tooltip).last);
    await settle(tester);
  }

  /// Types [text] in the field labelled [label].
  Future<void> type(String label, String text) async {
    final Finder f = find.widgetWithText(TextField, label);
    await reveal(f);
    await tester.enterText(f.first, text);
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
  }

  /// Closes the top screen, sheet or dialog.
  Future<void> back() async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
  }

  /// Waits up to [most] for [finder] to show, as for what loads slowly.
  Future<void> waitFor(
    Finder finder, {
    Duration most = const Duration(seconds: 6),
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    while (finder.evaluate().isEmpty && watch.elapsed < most) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await settle(tester);
  }

  /// Opens [text] and photographs it all, then comes back.
  Future<void> visit(String text, String name) async {
    await tap(text);
    await page(name);
    await back();
  }

  OwnController get own => tester.widget<OwnShell>(find.byType(OwnShell)).own;
}

/// Every scene, in the order the folder shows them.
final List<Scene> scenes = <Scene>[
  Scene('01-primeros-pasos', (Tour t) async {
    await t.shot('empezar');
    await t.tap('Con mis cuentas');
    await t.tester.enterText(find.byType(TextField).first, 'Diego');
    await t.shot('nombre-y-moneda');
    await t.tap('Siguiente');
    await t.shot('como-te-pagan');
    await t.tap('Mensual');
    await t.shot('como-te-pagan-mensual');
    await t.tap('Quincenal');
    await t.tap('Siguiente');
    await t.shot('agrega-tus-cuentas');
    await t.tap('Bancolombia · COP');
    await t.page('cuenta-sugerida');
    await t.back();
    await t.tap('Tarjeta de crédito · COP');
    await t.page('tarjeta-sugerida');
    await t.back();
  }),
  Scene('02-inicio', data: fullAccount, (Tour t) async {
    await t.page('inicio');
    await t.visit('¿De dónde sale?', 'de-donde-sale');
    await t.visit('Ver 30 días', 'proximos-30-dias');
    await t.type('Precio', '350000');
    await t.tap('Ver');
    await t.page('me-alcanza');
    await t.back();
    if (find.text('Cierre de la quincena').evaluate().isNotEmpty) {
      await t.visit('Cierre de la quincena', 'cierre-de-la-quincena');
    }
  }),
  Scene('03-por-revisar', data: fullAccount, (Tour t) async {
    await t.tapTip('Por revisar');
    await t.page('por-revisar');
    await t.tester.tap(find.byTooltip('Más acciones').first);
    await settle(t.tester);
    await t.shot('mas-acciones');
    await t.back();
    await t.tester.tap(find.text('Editar').first);
    await settle(t.tester);
    await t.page('editar-captura');
    await t.back();
  }),
  Scene('04-movimientos', data: fullAccount, (Tour t) async {
    await t.tap('Movimientos');
    await t.page('movimientos', most: 6);
    await t.tap('Éxito Laureles');
    await t.page('editar-movimiento');
    await t.back();
    await t.tapTip('Agregar movimiento');
    await t.page('nuevo-gasto');
    await t.tap('Ingreso');
    await t.page('nuevo-ingreso');
    await t.tap('Transferencia');
    await t.page('nueva-transferencia');
    await t.back();
  }),
  Scene('05-cuentas', data: fullAccount, (Tour t) async {
    await t.tap('Cuentas');
    await t.page('cuentas');
    await t.tester.tap(find.text('¿De dónde sale?').first);
    await settle(t.tester);
    await t.page('patrimonio-de-donde-sale');
    await t.back();
    await t.visit('Ver tasas usadas', 'tasas');
    // Its own row: "Bancolombia" alone is also the card's bank.
    await t.tap('Banco · Bancolombia');
    await t.page('cuenta-bancolombia');
    await t.tester.tap(find.text('¿De dónde sale?').first);
    await settle(t.tester);
    await t.page('saldo-de-donde-sale');
    await t.back();
    await t.back();
    await t.tap('Visa');
    await t.page('tarjeta-visa');
    await t.back();
    await t.tap('Cuenta en dólares');
    await t.page('cuenta-en-dolares');
    await t.back();
    // Shown once prices have been read.
    if (find.text('Cripto').evaluate().isNotEmpty) {
      await t.visit('Cripto', 'cripto');
    }
    await t.tap('Agregar cuenta');
    await t.page('agregar-cuenta');
    await t.back();
  }),
  Scene('06-plan', data: fullAccount, (Tour t) async {
    await t.tap('Plan');
    await t.page('plan');
    await t.visit('Repartir en sobres', 'repartir-en-sobres');
    await t.tap('Viaje a Cartagena');
    await t.page('meta');
    await t.back();
    await t.tap('Agregar meta');
    await t.page('agregar-meta');
    await t.back();
  }),
  Scene('07-compromisos', data: fullAccount, (Tour t) async {
    await t.tap('Plan');
    await t.tap('Pagos fijos');
    await t.page('pagos-fijos');
    await t.tap('Netflix');
    await t.page('pago-fijo');
    await t.back();
    await t.back();
    await t.tap('Compras a cuotas');
    await t.page('compras-a-cuotas');
    await t.tap('Televisor');
    await t.page('compra-a-cuotas');
    await t.back();
    await t.back();
    await t.visit('Cargos para revisar', 'cargos-para-revisar');
  }),
  Scene('08-si-te-sirve', data: fullAccount, (Tour t) async {
    await t.tap('Plan');
    await t.tap('Gastos compartidos');
    await t.page('gastos-compartidos');
    await t.tap('Paseo a Guatapé');
    await t.page('grupo');
    await t.back();
    await t.tap('Le presté');
    await t.page('le-preste');
    await t.back();
    await t.tap('Me prestaron');
    await t.page('me-prestaron');
    await t.back();
    await t.back();
    await t.visit('Ingresos variables', 'ingresos-variables');
    await t.tap('Viajes');
    await t.page('viajes');
    await t.tap('Nueva York');
    await t.page('viaje');
    await t.back();
    await t.back();
  }),
  Scene('09-para-decidir', data: fullAccount, (Tour t) async {
    await t.tap('Plan');
    await t.visit('Colchón en días', 'colchon-en-dias');
    await t.tap('Lo quiero, pero después');
    await t.page('lo-quiero-pero-despues');
    await t.tap('Agregar deseo');
    await t.page('agregar-deseo');
    await t.back();
    await t.back();
    await t.tap('¿Y si…?');
    await t.page('y-si');
    await t.back();
  }),
  Scene('10-importar-extracto', data: fullAccount, (Tour t) async {
    await t.tapTip('Ajustes');
    await t.tap('Importar extracto');
    await t.page('elegir-archivo');
    await t.back();
    await t.back();
    final StatementRead read = readTable(
      parseCsv(
        'Fecha;Descripción;Valor\n'
        '01/09/2026;COMPRA EN EXITO LAURELES;-187.400\n'
        '02/09/2026;ABONO NOMINA DL SOFT;2.400.000\n'
        '03/09/2026;PAGO PSE CLARO;-89.900\n'
        '04/09/2026;PAGO A JUAN PEREZ;-30.000\n'
        '05/09/2026;RETIRO CAJERO;-200.000\n',
      ),
    );
    final OwnController own = t.own;
    final Account bank = own.accounts.firstWhere(
      (Account a) => a.name == 'Bancolombia',
    );
    // Pushed, not awaited: the page stays open for its pictures.
    unawaited(
      Navigator.of(t.tester.element(find.byType(OwnShell))).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              StatementPage(own: own, accountId: bank.id, statement: read),
        ),
      ),
    );
    await settle(t.tester);
    await t.page('revisar-extracto');
    await t.tapContaining('Importar 5');
    await t.page('extracto-importado');
    await t.back();
  }),
  Scene('11-ajustes', data: fullAccount, (Tour t) async {
    await t.tapTip('Ajustes');
    await t.page('ajustes');
    await t.tap('Captura automática');
    await t.page('captura-automatica');
    if (find.text('Reglas aprendidas').evaluate().isNotEmpty) {
      await t.visit('Reglas aprendidas', 'reglas-aprendidas');
    }
    await t.back();
    await t.visit('Billeteras propias', 'billeteras-propias');
    await t.tap('Binance');
    await t.page('binance');
    await t.back();
    await t.visit('Licencias y créditos', 'licencias');
    await t.tap('Borrar todo');
    await t.shot('borrar-todo');
    await t.back();
  }),
  Scene('12-varios-dispositivos', data: fullAccount, (Tour t) async {
    await t.tapTip('Ajustes');
    await t.tap('Varios dispositivos');
    await t.page('varios-dispositivos');
    await t.tap('Unir este dispositivo');
    await t.shot('unir-con-codigo');
    await t.back();
    await t.tap('Empezar en este dispositivo');
    await t.shot('tu-codigo');
    await t.tap('Listo');
    await t.page('sincronizando');
  }),
  Scene('13-respaldo', data: fullAccount, (Tour t) async {
    await t.tapTip('Ajustes');
    await t.tap('Exportar mis datos');
    await t.shot('exportar');
    await t.tap('Sin cifrar (JSON)');
    await t.shot('exportar-json');
    await t.tap('Cifrado (recomendado)');
    await t.tap('Exportar');
    // The code shows before anything is saved; the system's own save
    // screen comes after it and is left out.
    await t.shot('codigo-de-respaldo');
  }),
  Scene('14-demo', demo: true, (Tour t) async {
    await t.page('demo-inicio');
    // The recordings load after the home shows.
    await t.waitFor(find.text(_seeRecorded));
    await t.tap(_seeRecorded);
    await t.page('lo-que-respondio-gemini');
    await t.back();
    await t.tapTip('Ajustes');
    await t.page('demo-ajustes');
    await t.back();
    for (var i = 0; i < _starters.length; i++) {
      await t.tapContaining(_starters[i]);
      await t.page('respuesta-${i + 1}', most: 10);
      await t.tapTip('Nueva conversación');
    }
  }),
  Scene('15-modo-oscuro', data: fullAccount, dark: true, (Tour t) async {
    await t.page('inicio', most: 3);
    await t.tap('Movimientos');
    await t.shot('movimientos');
    await t.tap('Cuentas');
    await t.page('cuentas', most: 3);
    await t.tap('Plan');
    await t.page('plan', most: 3);
    await t.tapTip('Por revisar');
    await t.shot('por-revisar');
  }),
  Scene('16-ingles', data: fullAccount, english: true, (Tour t) async {
    await t.page('home', most: 3);
    await t.tap('Accounts');
    await t.page('accounts', most: 3);
    await t.tap('Plan');
    await t.page('plan', most: 3);
    await t.tapTip('Settings');
    await t.page('settings', most: 4);
  }),
  Scene('17-demo-ingles', demo: true, english: true, (Tour t) async {
    await t.page('demo-home');
    await t.tapContaining(_startersEn[1]);
    await t.page('answer', most: 6);
  }),
];

const List<String> _starters = <String>[
  '¿En qué se me fue la plata en septiembre?',
  '¿Me alcanza para ir a Cartagena en diciembre?',
  '¿Qué suscripciones tengo?',
  '¿Cómo voy contra agosto?',
  'Registra 45 mil en el mercado',
];

const List<String> _startersEn = <String>[
  'Where did my money go in September?',
  'Can I afford Cartagena in December?',
];

const String _seeRecorded = 'Mira lo que respondió Gemini de verdad';
