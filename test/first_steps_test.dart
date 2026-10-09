// Starting without learning Quincena: setting up asks three things, the
// rest waits on Inicio in «Termina de preparar Quincena», and with no
// account Inicio leads to the first one instead of showing $0.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/messages.dart';
import 'package:quincena/ui/own/onboarding_page.dart';
import 'package:quincena/ui/own/own_shell.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// Inicio over the page's accounts and what [data] adds.
  Future<OwnController> home(
    WidgetTester tester, {
    Future<void> Function(QuincenaStore store, Account bank, Account card)?
    data,
  }) async {
    late AppModeController modes;
    final OwnController own = await openPage(tester, (OwnController own) {
      modes = AppModeController(store: own.store, now: () => pageNow);
      return OwnShell(own: own, modes: modes, settings: AppSettings());
    }, data: data);
    addTearDown(modes.dispose);
    return own;
  }

  /// The setup over a store with nothing in it, [done] once it finishes.
  Future<QuincenaStore> setup(WidgetTester tester, VoidCallback done) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => pageNow,
    );
    addTearDown(() => tester.runAsync(store.close));
    await tester.runAsync(store.ensureCategories);
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: OnboardingPage(
          store: store,
          newOwn: () =>
              OwnController(store, now: () => pageNow, readNative: false),
          now: () => pageNow,
          onDone: done,
          onCancel: () {},
        ),
      ),
    );
    await settle(tester);
    return store;
  }

  testWidgets('the name says what is missing, and stops saying it once '
      'typed', (tester) async {
    await setup(tester, () {});
    await tapText(tester, 'Siguiente');
    expect(find.text('Escribe tu nombre para seguir.'), findsOneWidget);
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'L');
    await tester.pump();
    expect(find.text('Escribe tu nombre para seguir.'), findsNothing);
  });

  testWidgets('three questions: the currency waits behind «Cambiar», and the '
      'account is the last one; then the list is left open on Inicio', (
    tester,
  ) async {
    var finished = false;
    final QuincenaStore store = await setup(tester, () => finished = true);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('COP · Peso colombiano'), findsOneWidget);
    await tapText(tester, 'Cambiar');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('USD · Dólar estadounidense').last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tapText(tester, 'Siguiente');
    expect(find.text('Paso 2 de 3'), findsOneWidget);
    expect(find.text('¿Cuándo te pagan?'), findsOneWidget);
    await tapText(tester, 'Siguiente');
    expect((await tester.runAsync(store.profile))!.base, Asset.usd);

    expect(find.text('Paso 3 de 3'), findsOneWidget);
    expect(find.text('¿Dónde tienes tu plata?'), findsOneWidget);
    await tapText(tester, 'Empezar');
    expect(finished, isFalse);
    expect(
      find.text('Agrega al menos una cuenta para empezar.'),
      findsOneWidget,
    );
    await tapText(tester, 'Banco · USD');
    // Named already: what it holds is all that is left, and it is asked.
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
          )
          .autofocus,
      isTrue,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '2500',
    );
    await tapText(tester, 'Guardar');
    await tapText(tester, 'Empezar');
    expect(finished, isTrue);
    expect(
      await tester.runAsync(() => store.setting('setup.checklist')),
      'open',
    );
  });

  testWidgets('Inicio lists what setting up left, each opening where it is '
      'done, and lets it go for good once all of it is', (tester) async {
    final OwnController own = await home(
      tester,
      data: (QuincenaStore store, _, _) =>
          store.setSetting('setup.checklist', 'open'),
    );
    expect(find.text('TERMINA DE PREPARAR QUINCENA'), findsOneWidget);
    for (final String step in <String>[
      'Tus pagos fijos',
      'Cuánto te pagan',
      'Tu colchón',
      'Pagos que llegan solos',
    ]) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    // Said once: the list has the fixed payments, «Por hacer» does not.
    expect(find.text('Agrega tus pagos fijos'), findsNothing);
    expect(find.textContaining('listos'), findsNothing);

    await tapText(tester, 'Escribir');
    expect(find.text('Lo que te pagan'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, '2.400.000');
    await tester.tap(find.text('Guardar').last);
    await settle(tester);
    expect(own.profile!.pay, Decimal.parse('2400000'));
    expect(find.text('1 de 4 listos'), findsOneWidget);

    await tapText(tester, 'Definir');
    await tester.enterText(find.byType(TextField).last, '300.000');
    await tester.tap(find.text('Guardar').last);
    await settle(tester);
    expect(own.profile!.cushion, Decimal.parse('300000'));

    await tapText(tester, 'Agregar');
    expect(find.text('¿Qué pagas fijo?'), findsOneWidget);
    await tapText(tester, 'No tengo pagos fijos');
    expect(own.noFixedPayments, isTrue);
    expect(find.text('3 de 4 listos'), findsOneWidget);

    await tapText(tester, 'Activar');
    expect(find.text('Captura automática'), findsWidgets);
    Navigator.of(tester.element(find.text('Captura automática').last)).pop();
    await settle(tester);

    // A payment the bank's alert brought: nothing left, and the list goes.
    await tester.runAsync(
      () => own.store.addEntry(
        accountId: own.accounts.first.id,
        amount: Decimal.parse('45900'),
        kind: EntryKind.expense,
        date: pageNow,
        category: 'groceries',
        payee: 'Éxito',
        source: 'notification',
      ),
    );
    await settle(tester);
    expect(find.text('TERMINA DE PREPARAR QUINCENA'), findsNothing);
    expect(own.setupOpen, isFalse);
  });

  testWidgets('hidden, the list goes with a way to bring it back, and the '
      'fixed payments go back to «Por hacer»', (tester) async {
    final OwnController own = await home(
      tester,
      data: (QuincenaStore store, _, _) =>
          store.setSetting('setup.checklist', 'open'),
    );
    await tester.tap(find.byTooltip('Ocultar'));
    await settle(tester);
    expect(find.text('TERMINA DE PREPARAR QUINCENA'), findsNothing);
    expect(own.setupOpen, isFalse);
    expect(
      find.text('Listo. Todo esto sigue en Ajustes y en Plan.'),
      findsOneWidget,
    );
    expect(find.text('Agrega tus pagos fijos'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(find.text('TERMINA DE PREPARAR QUINCENA'), findsOneWidget);
    expect(own.setupOpen, isTrue);
  });

  testWidgets('someone who did not just set up has no list', (tester) async {
    await home(tester);
    expect(find.text('TERMINA DE PREPARAR QUINCENA'), findsNothing);
    expect(find.text('Agrega tus pagos fijos'), findsOneWidget);
  });

  testWidgets('with no account, Inicio leads to the first one, and with it '
      'shows the figure', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => pageNow,
    );
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => pageNow,
      readNative: false,
    );
    addTearDown(own.dispose);
    final AppModeController modes = AppModeController(
      store: store,
      now: () => pageNow,
    );
    addTearDown(modes.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        builder: (BuildContext context, Widget? child) =>
            LatestMessenger(child: child!),
        home: OwnShell(own: own, modes: modes, settings: AppSettings()),
      ),
    );
    await settle(tester);

    expect(find.text('Agrega dónde tienes tu plata'), findsOneWidget);
    expect(find.text('Puedes gastar'), findsNothing);
    expect(find.text('Próximos días'), findsNothing);
    // Fixed payments wait for an account to pay them from.
    expect(find.text('Agrega tus pagos fijos'), findsNothing);
    // «Tus cuentas» is not an empty title: it has its way to add one.
    expect(find.text('Agregar cuenta'), findsOneWidget);
    expect(
      find.text(
        'Con una cuenta, aquí registras lo que gastas y lo que te entra.',
      ),
      findsOneWidget,
    );

    await tapText(tester, 'Agregar mi primera cuenta');
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Nequi');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '150000',
    );
    await tapText(tester, 'Guardar');
    expect(find.text('Puedes gastar'), findsOneWidget);
    expect(find.text('Agrega dónde tienes tu plata'), findsNothing);
    expect(own.accounts.single.name, 'Nequi');
  });
}
