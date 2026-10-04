import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/statements/statement.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/statement_page.dart';

import 'fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  testWidgets('a statement is reviewed line by line and imported', (
    tester,
  ) async {
    final (QuincenaStore store, OwnController own, Account bank) = await world(
      tester,
    );
    await tester.runAsync(() async {
      // Already caught from the bank's notification.
      await store.addEntry(
        accountId: bank.id,
        amount: Decimal.parse('89900'),
        kind: EntryKind.expense,
        date: DateTime(2026, 9, 3, 9),
        payee: 'Comcel',
      );
    });
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
          '02/09/2026;ABONO NOMINA DL SOFT;2.500.000\n'
          '03/09/2026;PAGO PSE COMCEL;-89.900\n'
          '04/09/2026;PAGO A JUAN PEREZ;-30.000\n',
        ),
      ),
    );

    // The bank the statement names is the account it goes to.
    expect(find.text('Bancolombia · COP'), findsOneWidget);
    expect(find.text('4 movimientos · 1–4 sept 2026'), findsOneWidget);
    // Before importing: what is new, what was already there, and what
    // comes without a category.
    expect(
      find.text('3 nuevos · 1 ya estaba · 1 sin categoría'),
      findsOneWidget,
    );
    expect(find.text('Exito Laureles'), findsOneWidget);
    // Each new line says what it will be; what was there says so.
    expect(find.text('1 sept · Mercado'), findsOneWidget);
    expect(find.text('4 sept · Sin categoría'), findsOneWidget);
    expect(find.text('3 sept · Ya registrado'), findsOneWidget);
    expect(find.text('Importar 3 movimientos'), findsOneWidget);
    // What the checked lines bring in and take out.
    expect(
      find.text(
        '3 seleccionados · entran +$signJoiner\$2.500.000 · salen −$signJoiner\$75.900',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // The account was added on 2 October with what it had then: by
    // default, the September lines are already in that balance.
    expect(
      find.text(
        '3 movimientos son de antes del 2 de octubre, cuando escribiste el '
        'saldo de Bancolombia.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'El saldo de Bancolombia sigue en −$signJoiner\$89.900: ya incluía estos '
        'movimientos.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Sumarlos a mi saldo'));
    await settle(tester);
    expect(
      find.text('Saldo de Bancolombia: −$signJoiner\$89.900 → \$2.334.200'),
      findsOneWidget,
    );

    // The new ones are checked; the button clears them, and checks the new
    // ones again, never what was already there.
    expect(find.text('Seleccionar todos'), findsNothing);
    await tester.tap(find.text('Quitar todos'));
    await settle(tester);
    expect(find.text('Nada para importar'), findsOneWidget);
    expect(find.text('Nada seleccionado'), findsOneWidget);
    await tester.tap(find.text('Marcar los nuevos'));
    await settle(tester);
    expect(find.text('Importar 3 movimientos'), findsOneWidget);
    expect(
      find.text(
        'Lo que ya estaba quedó sin marcar, para no contarlo dos veces.',
      ),
      findsOneWidget,
    );

    // What was already there can still be checked by hand, and the page
    // says it would count twice.
    await tester.tap(box('Comcel'));
    await settle(tester);
    expect(find.text('Importar 4 movimientos'), findsOneWidget);
    expect(
      find.text(
        '4 seleccionados · entran +$signJoiner\$2.500.000 · salen −$signJoiner\$165.800',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Marcaste 1 que ya estaba: se contaría dos veces.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Lo que ya estaba quedó sin marcar, para no contarlo dos veces.',
      ),
      findsNothing,
    );
    await tester.tap(box('Comcel'));
    await settle(tester);
    expect(
      find.text('Marcaste 1 que ya estaba: se contaría dos veces.'),
      findsNothing,
    );

    await tester.tap(find.text('Importar 3 movimientos'));
    await settle(tester);
    final List<Entry> entries =
        await tester.runAsync(() => store.entries(accountId: bank.id)) ??
        const <Entry>[];
    expect(entries.length, 4);
    expect(
      entries
          .where((Entry e) => e.source == 'statement')
          .map((Entry e) => e.payee),
      unorderedEquals(<String>[
        'Exito Laureles',
        'Nomina DL Soft',
        'Juan Perez',
      ]),
    );
    // It ends on what is left to check, not on the list it came from.
    expect(find.text('Se importaron 3 movimientos.'), findsOneWidget);
    expect(
      find.text('Saldo de Bancolombia: −$signJoiner\$89.900 → \$2.334.200'),
      findsOneWidget,
    );
    expect(own.balances[bank.id]?.amount, Decimal.parse('2334200'));
    expect(
      find.text('Uno quedó sin categoría: tócalo para ponérsela.'),
      findsOneWidget,
    );
    expect(find.text('SIN CATEGORÍA'), findsOneWidget);
    expect(find.text('Juan Perez'), findsOneWidget);
    await tester.tap(find.text('Listo'));
    await settle(tester);
    expect(find.text('abrir'), findsOneWidget);
  });
  testWidgets('without repeats, the button selects every line', (tester) async {
    final (_, OwnController own, _) = await world(tester);
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
          '02/09/2026;ABONO NOMINA DL SOFT;2.500.000\n',
        ),
      ),
    );
    expect(find.text('Importar 2 movimientos'), findsOneWidget);
    await tester.tap(find.text('Quitar todos'));
    await settle(tester);
    expect(find.text('Marcar los nuevos'), findsNothing);
    await tester.tap(find.text('Seleccionar todos'));
    await settle(tester);
    expect(find.text('Importar 2 movimientos'), findsOneWidget);
  });
  testWidgets('a line opens to change what it is recorded as', (tester) async {
    final (QuincenaStore store, OwnController own, Account bank) = await world(
      tester,
    );
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
          '04/09/2026;PAGO A JUAN PEREZ;-30.000\n',
        ),
      ),
    );
    expect(
      find.text('2 nuevos · ninguno repetido · 1 sin categoría'),
      findsOneWidget,
    );

    // The bank's own words, and a category for what came without one.
    await tester.tap(find.text('Juan Perez'));
    await settle(tester);
    expect(find.text('Revisar movimiento'), findsOneWidget);
    expect(find.text('Como aparece en el extracto'), findsOneWidget);
    expect(find.text('PAGO A JUAN PEREZ'), findsOneWidget);
    await tapOn(tester, find.text('Transporte'));
    await tapOn(tester, find.text('Guardar'));
    await settle(tester);
    expect(find.text('4 sept · Transporte'), findsOneWidget);
    expect(find.text('2 nuevos · ninguno repetido'), findsOneWidget);

    // A refund the bank wrote as a purchase: its sign follows.
    await tester.tap(find.text('Exito Laureles'));
    await settle(tester);
    await tapOn(tester, find.text('Ingreso'));
    await settle(tester);
    expect(find.text('+$signJoiner\$45.900'), findsWidgets);
    await tapOn(tester, find.text('Reembolsos'));
    await tapOn(tester, find.text('Guardar'));
    await settle(tester);
    expect(find.text('1 sept · Reembolsos'), findsOneWidget);
    expect(
      find.text(
        '2 seleccionados · entran +$signJoiner\$45.900 · salen −$signJoiner\$30.000',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Importar 2 movimientos'));
    await settle(tester);
    final List<Entry> entries =
        await tester.runAsync(() => store.entries(accountId: bank.id)) ??
        const <Entry>[];
    expect(
      <(String, Decimal, String?)>[
        for (final Entry e in entries) (e.payee, e.amount, e.category),
      ],
      unorderedEquals(<(String, Decimal, String?)>[
        ('Exito Laureles', Decimal.parse('45900'), 'refund'),
        ('Juan Perez', Decimal.parse('-30000'), 'transport'),
      ]),
    );
    expect(find.text('Todos quedaron con su categoría.'), findsOneWidget);
    expect(find.text('SIN CATEGORÍA'), findsNothing);
    // The balance written on 2 October already had these lines.
    expect(
      find.text(
        'El saldo de Bancolombia sigue en \$0: ya incluía estos movimientos.',
      ),
      findsOneWidget,
    );
    expect(own.balances[bank.id]?.amount, Decimal.zero);
  });
  testWidgets('a card payment is a move to the card, not spending', (
    tester,
  ) async {
    final (QuincenaStore store, OwnController own, Account bank) = await world(
      tester,
    );
    late Account visa;
    await tester.runAsync(() async {
      visa = await store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        institution: 'Bancolombia',
      );
    });
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '20/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
          '24/09/2026;PAGO TARJETA VISA;-480.000\n',
        ),
      ),
    );
    expect(
      find.text('2 nuevos · ninguno repetido · 1 entre tus cuentas'),
      findsOneWidget,
    );
    expect(find.text('24 sept · Pago de tu tarjeta Visa'), findsOneWidget);
    expect(
      find.text(
        'Un pago de tarjeta pasa plata de una cuenta tuya a otra: no cuenta '
        'como gasto, porque las compras ya están en la tarjeta.',
      ),
      findsOneWidget,
    );
    // The line says where the money went, and can be changed.
    await tester.tap(find.text('Tarjeta Visa'));
    await settle(tester);
    expect(find.text('Hacia'), findsOneWidget);
    expect(find.text('Visa'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    await tester.tap(find.text('Importar 2 movimientos'));
    await settle(tester);
    final List<Entry> onCard =
        await tester.runAsync(() => store.entries(accountId: visa.id)) ??
        const <Entry>[];
    expect(onCard.single.amount, Decimal.parse('480000'));
    expect(onCard.single.isTransfer, isTrue);
    final List<Entry> onBank =
        await tester.runAsync(() => store.entries(accountId: bank.id)) ??
        const <Entry>[];
    expect(onBank.length, 2);
    expect(
      find.text(
        'Uno quedó como movimiento entre tus cuentas: no cuenta como gasto.',
      ),
      findsOneWidget,
    );
    expect(find.text('Todos quedaron con su categoría.'), findsOneWidget);
  });

  testWidgets('a card payment without a card asks to add it', (tester) async {
    final (_, OwnController own, _) = await world(tester);
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '24/09/2026;PAGO TARJETA VISA;-480.000\n',
        ),
      ),
    );
    expect(
      find.text(
        'Parece el pago de una tarjeta. Agrégala en Cuentas para que '
        'Quincena no cuente dos veces lo que compraste con ella.',
      ),
      findsOneWidget,
    );
    expect(find.text('24 sept · Sin categoría'), findsOneWidget);
  });
  testWidgets('a statement\'s own balance can set the account\'s', (
    tester,
  ) async {
    final (_, OwnController own, Account bank) = await world(tester);
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor;Saldo\n'
          '01/10/2026;COMPRA EN EXITO LAURELES;-45.900;954.100\n'
          '02/10/2026;ABONO NOMINA DL SOFT;2.500.000;3.454.100\n',
        ),
      ),
    );
    expect(
      find.text('Según el extracto, el 2 de octubre tenías \$3.454.100.'),
      findsOneWidget,
    );
    expect(find.text('Quincena tendría \$2.500.000 ese día.'), findsOneWidget);
    expect(find.text('Mi saldo ya los incluye (recomendado)'), findsOneWidget);
    expect(
      find.text('Saldo de Bancolombia: \$0 → \$2.500.000'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ajustar al saldo del extracto'));
    await settle(tester);
    // The statement decides: the question about older lines goes away.
    expect(find.text('Mi saldo ya los incluye (recomendado)'), findsNothing);
    expect(
      find.text('Saldo de Bancolombia: \$0 → \$3.454.100'),
      findsOneWidget,
    );
    await tester.tap(find.text('Importar 2 movimientos'));
    await settle(tester);
    expect(own.balances[bank.id]?.amount, Decimal.parse('3454100'));
    expect(
      find.text('Saldo de Bancolombia: \$0 → \$3.454.100'),
      findsOneWidget,
    );
  });

  testWidgets('a save that stops halfway can be left and tried again', (
    tester,
  ) async {
    final (QuincenaStore store, OwnController own, Account bank) = await world(
      tester,
      failing: true,
    );
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
          '02/09/2026;ABONO NOMINA DL SOFT;2.500.000\n',
        ),
      ),
    );
    await tester.tap(find.text('Importar 2 movimientos'));
    await settle(tester);
    expect(
      find.text(
        'No se pudo terminar de importar. Lo que sí se guardó aparece como '
        '«Ya importado».',
      ),
      findsOneWidget,
    );
    // What was saved is not offered again, and the balance written on 2
    // October still has it.
    expect(find.text('1 sept · Ya importado'), findsOneWidget);
    expect(find.text('Importar un movimiento'), findsOneWidget);
    expect(own.balances[bank.id]?.amount, Decimal.zero);

    await tester.tap(find.text('Importar un movimiento'));
    await settle(tester);
    expect(find.text('Se importó un movimiento.'), findsOneWidget);
    final List<Entry> entries =
        await tester.runAsync(() => store.entries(accountId: bank.id)) ??
        const <Entry>[];
    expect(entries.length, 2);
    expect(own.balances[bank.id]?.amount, Decimal.zero);
  });
  testWidgets('a card\'s statement asks which account paid it', (tester) async {
    final (QuincenaStore store, OwnController own, _) = await world(tester);
    late Account visa;
    await tester.runAsync(() async {
      visa = await store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
      );
      await store.addAccount(
        name: 'Nequi',
        kind: AccountKind.wallet,
        asset: Asset.cop,
      );
    });
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '15/10/2026;RAPPI;45.900\n'
          '16/10/2026;NETFLIX;26.900\n'
          '20/10/2026;PAGO RECIBIDO;-480.000\n',
        ),
      ),
      accountId: visa.id,
    );
    expect(
      find.text(
        '20 oct · Sin categoría\n¿De cuál de tus cuentas salió este pago?',
      ),
      findsOneWidget,
    );
    expect(find.text('¿Es el pago de una tarjeta tuya?'), findsNothing);
  });
  testWidgets(
    'lines that add up to nothing do not claim to be in the balance',
    (tester) async {
      final (_, OwnController own, _) = await world(tester);
      await open(
        tester,
        own,
        readTable(
          parseCsv(
            'Fecha;Descripción;Valor\n'
            '02/10/2026;TRANSFERENCIA DE ANA GOMEZ;50.000\n'
            '02/10/2026;PAGO A ANA GOMEZ;-50.000\n',
          ),
        ),
      );
      expect(find.text('Saldo de Bancolombia: \$0 → \$0'), findsOneWidget);
      expect(find.textContaining('ya incluía'), findsNothing);
    },
  );

  testWidgets('in English', (tester) async {
    await initializeDateFormatting('en_US');
    Intl.defaultLocale = 'en_US';
    addTearDown(() => Intl.defaultLocale = 'es_CO');
    final (_, OwnController own, _) = await world(tester);
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
          '02/09/2026;ABONO NOMINA DL SOFT;2.500.000\n',
        ),
      ),
      locale: const Locale('en'),
    );
    expect(find.text('2 transactions · Sep 1–2, 2026'), findsOneWidget);
    expect(find.text('Sep 1 · Groceries'), findsOneWidget);
    expect(
      find.text(
        '2 selected · +$signJoiner\$2,500,000 in · −$signJoiner\$45,900 out',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '2 transactions are from before October 2, when you entered the '
        'Bancolombia balance.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('My balance already includes them (recommended)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'The Bancolombia balance stays at \$0: it already included these '
        'transactions.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('the page cannot be left while it saves', (tester) async {
    final Completer<void> saved = Completer<void>();
    final (QuincenaStore store, OwnController own, Account bank) = await world(
      tester,
      saving: saved.future,
    );
    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n',
        ),
      ),
    );
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.text('Importar un movimiento'));
    await tester.pump();
    expect(find.text('Importando…'), findsOneWidget);
    // Back does nothing until the import is done.
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(find.byType(StatementPage), findsOneWidget);
    expect(find.text('Importando…'), findsOneWidget);

    saved.complete();
    await settle(tester);
    expect(find.text('Se importó un movimiento.'), findsOneWidget);
    final List<Entry> entries =
        await tester.runAsync(() => store.entries(accountId: bank.id)) ??
        const <Entry>[];
    expect(entries.length, 1);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('abrir'), findsOneWidget);
  });
  testWidgets('with large text, the totals go under the lines', (tester) async {
    final (_, OwnController own, _) = await world(tester);
    final StatementRead read = readTable(
      parseCsv(
        'Fecha;Descripción;Valor\n'
        '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n',
      ),
    );
    const String totals = '1 seleccionado · salen −$signJoiner\$45.900';
    await open(tester, own, read);
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text(totals)),
      findsNothing,
    );
    expect(find.text(totals), findsOneWidget);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settle(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text(totals)),
      findsOneWidget,
    );
  });
  testWidgets('at twice the text size on a small phone, every part fits', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final (QuincenaStore store, OwnController own, _) = await world(tester);
    // Google Play's smallest screenshot phone, 360 by 800.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      for (final String card in <String>['Visa', 'Mastercard']) {
        await store.addAccount(
          name: card,
          kind: AccountKind.card,
          asset: Asset.cop,
        );
      }
    });
    Future<void> holds() async {
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    await open(
      tester,
      own,
      readTable(
        parseCsv(
          'Fecha;Descripción;Valor;Saldo\n'
          '01/10/2026;COMPRA EN EXITO LAURELES;-45.900;954.100\n'
          '02/10/2026;PAGO TARJETA CREDITO;-480.000;474.100\n',
        ),
      ),
    );
    await holds();
    // Under the lines: the older line's question and the statement's own
    // balance.
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Mi saldo ya los incluye (recomendado)'), findsOneWidget);
    expect(find.text('Ajustar al saldo del extracto'), findsOneWidget);
    await holds();

    // The card payment's sheet, as a move to a card.
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tapOn(tester, find.text('Tarjeta Credito'));
    await settle(tester);
    expect(find.text('Revisar movimiento'), findsOneWidget);
    await holds();
    await tapOn(tester, find.text('Transferencia'));
    await settle(tester);
    expect(find.text('Visa'), findsOneWidget);
    await holds();
    semantics.dispose();
  });
}

/// Taps [finder] once it is scrolled into view.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// The checkbox of the line that names [name].
Finder box(String name) => find.byWidgetPredicate(
  (Widget w) => w is Checkbox && w.semanticLabel == name,
);

/// A person with a Bancolombia account, added on 2 October 2026.
Future<(QuincenaStore, OwnController, Account)> world(
  WidgetTester tester, {
  Future<void>? saving,
  bool failing = false,
}) async {
  // A tall phone, so the whole statement fits without scrolling.
  tester.view.physicalSize = const Size(1170, 4200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final DateTime now = DateTime(2026, 10, 2, 10);
  final QuincenaStore store = _Store(
    QuincenaDatabase(NativeDatabase.memory()),
    now: () => now,
    saving: saving,
    failing: failing,
  );
  addTearDown(() => tester.runAsync(store.close));
  final OwnController own = OwnController(
    store,
    now: () => now,
    readNative: false,
  );
  addTearDown(own.dispose);
  late Account bank;
  await tester.runAsync(() async {
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
    bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      institution: 'Bancolombia',
    );
  });
  return (store, own, bank);
}

/// The statement [read] opened over a page, the way the app pushes it,
/// into [accountId] when given.
Future<void> open(
  WidgetTester tester,
  OwnController own,
  StatementRead read, {
  Locale locale = const Locale('es'),
  String? accountId,
}) async {
  await tester.runAsync(own.start);
  await tester.pumpWidget(
    MaterialApp(
      theme: quincenaTheme(Brightness.light),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => StatementPage(
                    own: own,
                    statement: read,
                    accountId: accountId,
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }
}

/// A store whose movements wait for [saving] before they are written, to
/// see the page while it saves, and when [failing], whose second line of a
/// statement fails once.
class _Store extends QuincenaStore {
  _Store(super.db, {super.now, this.saving, this.failing = false});

  final Future<void>? saving;
  final bool failing;
  int _lines = 0;

  @override
  Future<Entry> addEntry({
    required String accountId,
    required Decimal amount,
    required EntryKind kind,
    required DateTime date,
    String? category,
    String payee = '',
    String note = '',
    String source = 'manual',
    String? sourceRef,
    Money? cost,
  }) async {
    if (source == 'statement') {
      await saving;
      if (failing && ++_lines == 2) throw StateError('The disk is full.');
    }
    return super.addEntry(
      accountId: accountId,
      amount: amount,
      kind: kind,
      date: date,
      category: category,
      payee: payee,
      note: note,
      source: source,
      sourceRef: sourceRef,
      cost: cost,
    );
  }
}
