import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/categories.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/icons.dart';
import 'package:quincena/ui/messages.dart';
import 'package:quincena/ui/own/account_page.dart';
import 'package:quincena/ui/own/entry_sheet.dart';
import 'package:quincena/ui/own/look.dart' show categoryIconFor;
import 'package:quincena/ui/own/own_shell.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';
import 'real_life_data.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// The form for a new movement, opened from the floating button, over
  /// what [data] adds to the page's accounts, answered with [answer] when
  /// given.
  Future<OwnController> open(
    WidgetTester tester, {
    Future<void> Function(QuincenaStore store, Account bank, Account card)?
    data,
    String? answer = 'Gasté plata',
  }) async {
    late AppModeController modes;
    final OwnController own = await openPage(tester, (OwnController own) {
      modes = AppModeController(store: own.store, now: () => pageNow);
      return OwnShell(own: own, modes: modes, settings: AppSettings());
    }, data: data);
    addTearDown(modes.dispose);
    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    if (answer != null) await tapText(tester, answer);
    return own;
  }

  /// Opens [page] and, from its only button, what [show] shows.
  Future<OwnController> openFrom(
    WidgetTester tester,
    Future<void> Function(BuildContext context, OwnController own) show, {
    Future<void> Function(QuincenaStore store, Account bank, Account card)?
    data,
  }) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => show(context, own),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
      data: data,
    );
    await tester.tap(find.text('Abrir'));
    await settle(tester);
    return own;
  }

  /// The movement paid to [payee].
  Entry entryTo(OwnController own, String payee) =>
      own.snapshot!.entries.firstWhere((Entry e) => e.payee == payee);

  testWidgets('a new movement starts by what happened, and the title takes '
      'back to the question', (tester) async {
    await open(tester, answer: null);
    expect(find.text('¿Qué pasó?'), findsOneWidget);
    expect(find.text('Gasté plata'), findsOneWidget);
    expect(find.text('Me entró plata'), findsOneWidget);
    expect(find.text('Moví plata entre mis cuentas'), findsOneWidget);
    // No kinds to pick from before saying what happened.
    expect(find.byType(SegmentedButton<EntryKind>), findsNothing);
    expect(find.text('Monto'), findsNothing);

    await tapText(tester, 'Me entró plata');
    expect(find.text('¿De dónde?'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '50000');
    await tester.tap(find.byTooltip('Cambiar qué pasó'));
    await settle(tester);
    expect(find.text('¿Qué pasó?'), findsOneWidget);
    await tapText(tester, 'Gasté plata');
    // What was typed stays.
    expect(
      find.descendant(
        of: find.widgetWithText(TextField, 'Monto'),
        matching: find.text('50.000'),
      ),
      findsOneWidget,
    );
    expect(find.text('¿Dónde o a quién?'), findsOneWidget);
  });

  testWidgets('a normal expense is the amount, where and save: the rest comes '
      'from the last time at that place', (tester) async {
    final OwnController own = await open(
      tester,
      answer: null,
      data: (QuincenaStore store, Account bank, Account card) async {
        await store.addEntry(
          accountId: card.id,
          amount: Decimal.parse('41000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 9, 20, 13),
          category: 'restaurants',
          payee: 'Crepes & Waffles',
        );
        // Written by hand later, somewhere else.
        await store.addEntry(
          accountId: bank.id,
          amount: Decimal.parse('9000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2, 8),
          category: 'transport',
          payee: 'Bus',
        );
      },
    );
    final Account visa = own.accounts.firstWhere(
      (Account a) => a.name == 'Visa',
    );
    var taps = 1;
    await tapText(tester, 'Gasté plata');
    taps++;
    // The amount takes the keyboard on its own.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Monto'))
          .autofocus,
      isTrue,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '23500');
    await settle(tester);
    // Before a name, the account of the last time and no category.
    expect(find.text('Sin categoría · Bancolombia · Hoy'), findsOneWidget);
    expect(find.text('Si no eliges una, queda en Otros.'), findsOneWidget);
    await tapText(tester, 'Crepes & Waffles');
    taps++;
    expect(find.text('Restaurantes · Visa · Hoy'), findsOneWidget);
    expect(
      find.text('Como la última vez en Crepes & Waffles.'),
      findsOneWidget,
    );
    // The rest waits out of the way.
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Nota (opcional)'), findsNothing);
    await tapText(tester, 'Guardar');
    taps++;

    expect(taps, 4, reason: 'the button, what happened, where and save');
    final Entry saved = own.snapshot!.entries.firstWhere(
      (Entry e) => e.amount == Decimal.parse('-23500'),
    );
    expect(saved.payee, 'Crepes & Waffles');
    expect(saved.category, 'restaurants');
    expect(saved.accountId, visa.id);
    expect(saved.date.day, pageNow.day);
  });

  testWidgets('a new place goes in «Otros» unless a category is chosen, and '
      '«Cambiar» opens the account, the category, the day and the note', (
    tester,
  ) async {
    final OwnController own = await open(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '15000');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde o a quién?'),
      'Uber',
    );
    await settle(tester);
    // A well-known name brings its category.
    expect(find.text('Transporte · Bancolombia · Hoy'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde o a quién?'),
      'Papelería',
    );
    await settle(tester);
    expect(find.text('Sin categoría · Bancolombia · Hoy'), findsOneWidget);
    expect(find.text('Si no eliges una, queda en Otros.'), findsOneWidget);

    await tapText(tester, 'Cambiar');
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Fecha'), findsOneWidget);
    expect(find.text('Nota (opcional)'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await settle(tester);
    await tester.tap(find.text('Visa').last);
    await settle(tester);
    await tapText(tester, 'Compras');
    // Typed again, the name no longer moves what was chosen.
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde o a quién?'),
      'Papelería Panamericana',
    );
    await settle(tester);
    await tapText(tester, 'Guardar');
    final Entry saved = entryTo(own, 'Papelería Panamericana');
    expect(saved.category, 'shopping');
    expect(
      saved.accountId,
      own.accounts.firstWhere((Account a) => a.name == 'Visa').id,
    );
  });

  testWidgets('a category made from the form is chosen, and its dialog '
      'closes cleanly as the keyboard goes', (tester) async {
    final OwnController own = await open(tester);
    await tapText(tester, 'Cambiar');
    final int before = own.categories.length;
    addTearDown(tester.view.resetViewInsets);

    await tapText(tester, 'Nueva categoría');
    await tapText(tester, 'Cancelar');
    expect(own.categories, hasLength(before));

    await tapText(tester, 'Nueva categoría');
    await tapText(tester, 'Guardar');
    expect(own.categories, hasLength(before), reason: 'no name, nothing made');

    await tapText(tester, 'Nueva categoría');
    // The keyboard is up while the name is typed...
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '  Mascotas ');
    await tester.tap(find.text('Guardar').last);
    // ...and goes while the dialog closes, which builds its field again.
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await settle(tester);
    expect(tester.takeException(), isNull);

    final CategoryItem pets = own.categories.singleWhere(
      (CategoryItem c) => c.name == 'Mascotas',
    );
    expect(pets.income, isFalse);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mascotas'))
          .selected,
      isTrue,
    );
  });

  testWidgets('a new category takes the icon and the color chosen for it', (
    tester,
  ) async {
    final OwnController own = await open(tester);
    await tapText(tester, 'Cambiar');
    await tapText(tester, 'Nueva categoría');
    await tester.enterText(find.byType(TextField).last, 'Colegio');
    await tester.tap(find.bySemanticsLabel('Estudio'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Color 3'));
    await tester.pump();
    await tester.tap(find.text('Guardar').last);
    await settle(tester);

    final CategoryItem school = own.categories.singleWhere(
      (CategoryItem c) => c.name == 'Colegio',
    );
    expect(categoryLooks[school.key]?.icon, 'graduationCap');
    expect(categoryIconFor(school.key), Glyph.graduationCap);
    final Icon avatar = tester.widget<Icon>(
      find.descendant(
        of: find.widgetWithText(ChoiceChip, 'Colegio'),
        matching: find.byType(Icon),
      ),
    );
    expect(avatar.icon, Glyph.graduationCap);
  });

  testWidgets('what saving said goes once the field is put right', (
    tester,
  ) async {
    await open(tester);
    await tapText(tester, 'Guardar');
    expect(find.text('Escribe un monto'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '12000');
    await settle(tester);
    expect(find.text('Escribe un monto'), findsNothing);

    await tester.tap(find.byTooltip('Cambiar qué pasó'));
    await settle(tester);
    await tapText(tester, 'Moví plata entre mis cuentas');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.text('Bancolombia').last);
    await settle(tester);
    await tapText(tester, 'Guardar');
    expect(find.text('Elige dos cuentas distintas'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.text('Visa').last);
    await settle(tester);
    expect(find.text('Elige dos cuentas distintas'), findsNothing);
  });

  testWidgets('what arrived in another currency is asked for under its own '
      'field', (tester) async {
    final OwnController own = await open(
      tester,
      answer: 'Moví plata entre mis cuentas',
      data: (QuincenaStore store, _, _) async {
        await store.addAccount(
          name: 'Dólares',
          kind: AccountKind.bank,
          asset: Asset.usd,
          opening: Decimal.zero,
        );
        await store.saveRates(<Rate>[
          Rate(
            asset: 'USD',
            quote: 'COP',
            value: Decimal.fromInt(4000),
            asOf: pageNow,
            source: 'trm',
          ),
        ]);
      },
    );
    Finder under(String label, String text) => find.descendant(
      of: find.widgetWithText(TextField, label),
      matching: find.text(text),
    );
    final int before = own.snapshot!.entries.length;
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.text('Dólares').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '400000');
    await settle(tester);
    expect(under('Llegó', '100'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Llegó'), '');
    await settle(tester);
    await tapText(tester, 'Guardar');
    expect(under('Llegó', 'Escribe un monto'), findsOneWidget);
    expect(under('Monto', 'Escribe un monto'), findsNothing);
    expect(own.snapshot!.entries, hasLength(before));

    await tester.enterText(find.widgetWithText(TextField, 'Llegó'), '98,5');
    await settle(tester);
    expect(find.text('Escribe un monto'), findsNothing);
  });

  testWidgets('what comes in takes the account and the category of the last '
      'time the same payer paid', (tester) async {
    final OwnController own = await open(tester, answer: 'Me entró plata');
    // The pay of the page's account, from «Nómina» into Bancolombia.
    await tapText(tester, 'Nómina');
    expect(find.text('Salario · Bancolombia · Hoy'), findsOneWidget);
    expect(find.text('Como la última vez de Nómina.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '2000000');
    await tapText(tester, 'Guardar');
    final List<Entry> pay = own.snapshot!.entries
        .where((Entry e) => e.payee == 'Nómina')
        .toList();
    expect(pay, hasLength(2));
    expect(pay.every((Entry e) => e.category == 'salary'), isTrue);
  });

  testWidgets('on a card\'s page, moving money is paying it: into the card, '
      'from where payments come', (tester) async {
    late Account visa;
    await openPage(tester, (OwnController own) {
      visa = own.accounts.firstWhere((Account a) => a.name == 'Visa');
      return AccountPage(own: own, accountId: visa.id);
    });
    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    await tapText(tester, 'Moví plata entre mis cuentas');
    final List<DropdownButtonFormField<String>> fields = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    expect(fields, hasLength(2));
    expect(
      find.descendant(
        of: find.byWidget(fields.first),
        matching: find.text('Bancolombia'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byWidget(fields.last),
        matching: find.text('Visa'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a draft opens as it comes, without the question, and saves in '
      'one tap', (tester) async {
    bool? saved;
    final OwnController own = await openFrom(tester, (
      BuildContext context,
      OwnController own,
    ) async {
      saved = await showEntrySheet(
        context,
        own: own,
        kind: EntryKind.expense,
        draft: EntryDraft(
          amount: Decimal.parse('180000'),
          payee: 'Chaqueta',
          category: 'shopping',
          date: own.today,
        ),
      );
    });
    expect(find.text('¿Qué pasó?'), findsNothing);
    expect(find.text('Gasté plata'), findsOneWidget);
    expect(find.text('Compras · Bancolombia · Hoy'), findsOneWidget);
    // Nothing to type: no keyboard comes up.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Monto'))
          .autofocus,
      isFalse,
    );
    await tapText(tester, 'Guardar');
    expect(saved, isTrue);
    final Entry e = entryTo(own, 'Chaqueta');
    expect(e.amount, Decimal.parse('-180000'));
    expect(e.category, 'shopping');
  });

  testWidgets('changing a movement shows every field at once, its kind '
      'among them', (tester) async {
    final OwnController own = await openFrom(
      tester,
      (BuildContext context, OwnController own) =>
          showEntrySheet(context, own: own, entry: entryTo(own, 'Nómina')),
    );
    expect(own.snapshot!.entries, isNotEmpty);
    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(find.byType(SegmentedButton<EntryKind>), findsOneWidget);
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Fecha'), findsOneWidget);
    expect(find.text('Cambiar'), findsNothing);
    expect(find.text('¿Qué pasó?'), findsNothing);
  });

  testWidgets('an amount written for one currency says so when the account '
      'goes to another, until it is written again', (tester) async {
    await open(
      tester,
      data: (QuincenaStore store, Account bank, _) async {
        final Account dollars = await store.addAccount(
          name: 'Dólares',
          kind: AccountKind.bank,
          asset: Asset.usd,
          opening: Decimal.fromInt(500),
        );
        await store.addEntry(
          accountId: dollars.id,
          amount: Decimal.parse('10.99'),
          kind: EntryKind.expense,
          date: DateTime(2026, 9, 20, 9),
          category: 'subscriptions',
          payee: 'Spotify',
        );
        // The last one written by hand, in pesos.
        await store.addEntry(
          accountId: bank.id,
          amount: Decimal.parse('9000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2, 8),
          category: 'transport',
          payee: 'Bus',
        );
      },
    );
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '16900');
    await settle(tester);
    expect(find.textContaining('revisa el monto'), findsNothing);
    // The place was paid in dollars last time.
    await tapText(tester, 'Spotify');
    expect(find.text('Suscripciones · Dólares · Hoy'), findsOneWidget);
    expect(find.text('Pasó de COP a USD: revisa el monto.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '10,99');
    await settle(tester);
    expect(find.textContaining('revisa el monto'), findsNothing);
  });

  testWidgets('a split expense saved as something else says first that its '
      'split goes', (tester) async {
    final OwnController own = await openFrom(
      tester,
      (BuildContext context, OwnController own) => showEntrySheet(
        context,
        own: own,
        entry: entryTo(own, 'Almuerzo en Guatapé'),
      ),
      data: (QuincenaStore store, _, _) => addRealLife(store),
    );
    final Entry lunch = entryTo(own, 'Almuerzo en Guatapé');
    expect(own.splitOf(lunch.id), isNotNull);
    await tapText(tester, 'Ingreso');
    await tapText(tester, 'Guardar');
    expect(find.text('¿Ya no es un gasto?'), findsOneWidget);
    expect(
      find.text(
        'También se quita su división: lo que te deben por este gasto deja '
        'de contar.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Cancelar');
    expect(entryTo(own, 'Almuerzo en Guatapé').kind, EntryKind.expense);
    expect(own.splitOf(lunch.id), isNotNull);

    await tapText(tester, 'Guardar');
    await tapText(tester, 'Sí, cambiarlo');
    expect(entryTo(own, 'Almuerzo en Guatapé').kind, EntryKind.income);
    expect(own.splitOf(lunch.id), isNull);
  });

  testWidgets('with no account yet, the button offers the first one and the '
      'form opens in it', (tester) async {
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

    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    // An offer, not an error.
    expect(find.text('Primero, ¿dónde tienes tu plata?'), findsOneWidget);
    expect(find.text('Primero agrega una cuenta.'), findsNothing);
    await tapText(tester, 'Ahora no');
    expect(find.text('¿Qué pasó?'), findsNothing);

    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    await tester.tap(find.text('Agregar mi primera cuenta').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Nequi');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '150000',
    );
    await tapText(tester, 'Guardar');
    // In it, what happened; with one account there is nothing to move
    // between.
    expect(find.text('¿Qué pasó?'), findsOneWidget);
    expect(find.text('Moví plata entre mis cuentas'), findsNothing);
    await tapText(tester, 'Gasté plata');
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '12000');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde o a quién?'),
      'Bus',
    );
    await settle(tester);
    await tapText(tester, 'Guardar');
    final Entry bus = entryTo(own, 'Bus');
    expect(bus.accountId, own.accounts.single.id);
    expect(bus.amount, Decimal.parse('-12000'));
    expect(tester.takeException(), isNull);
  });
}
