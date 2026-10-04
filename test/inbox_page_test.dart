// Por revisar as a person meets it: what one tap records apart from what
// needs a choice, an account chosen among those at the bank the alert
// names, and many captures at once.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/inbox_page.dart';

import '../test_screens/accounts.dart';
import 'fonts.dart';
import 'own_flow_test.dart' show settle;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// Por revisar over [data], on a phone [size] wide and tall.
  Future<OwnController> open(
    WidgetTester tester,
    Future<QuincenaStore> Function() data, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = (await tester.runAsync(data))!;
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => screensNow,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(own.start);
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: InboxPage(own: own),
      ),
    );
    await settle(tester);
    return own;
  }

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('what one tap records comes first, what needs a choice after', (
    tester,
  ) async {
    await open(tester, withCaptures);
    final double ready = top(tester, find.text('LISTOS PARA REGISTRAR'));
    final double needs = top(tester, find.text('NECESITAN INFORMACIÓN'));
    expect(ready, lessThan(needs));

    // Laura's transfer has its account: one tap, and it says what it saves.
    final double laura = top(tester, find.text('Laura Gómez'));
    expect(laura, inExclusiveRange(ready, needs));
    expect(find.text('Otros ingresos · Nequi'), findsOneWidget);
    expect(find.text('Registrar ingreso'), findsOneWidget);

    // The purchase at Éxito names a bank where there are two accounts.
    expect(top(tester, find.text('Éxito Laureles')), greaterThan(needs));
    expect(find.text('Mercado · Falta la cuenta'), findsOneWidget);
    expect(
      find.text(
        'Detectamos Bancolombia y la tarjeta *1234, pero falta asociarla a '
        'una de tus cuentas.',
      ),
      findsOneWidget,
    );
    // The name came from OpenStreetMap, and its credit stays beside it.
    expect(find.text('Por ubicación · © OpenStreetMap'), findsOneWidget);
    expect(find.text('Elegir la cuenta'), findsOneWidget);

    // How each was detected is in the menu, not on the card.
    expect(find.textContaining('Sugerido porque'), findsNothing);
    expect(find.textContaining('Cerca:'), findsNothing);
    // Laura's category is a guess: nothing to record all at once.
    expect(find.textContaining('Registrar los'), findsNothing);
  });

  testWidgets(
    'the account is chosen among those at the bank, and the choice is learned',
    (tester) async {
      final OwnController own = await open(tester, withCaptures);
      await tester.tap(find.text('Elegir la cuenta'));
      await settle(tester);
      expect(find.text('¿De qué cuenta salió?'), findsOneWidget);
      expect(
        find.text(
          'La próxima vez, lo de la tarjeta *1234 irá directo a esa cuenta.',
        ),
        findsOneWidget,
      );
      final List<String?> choices = <String?>[
        for (final ListTile t in tester.widgetList<ListTile>(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(ListTile),
          ),
        ))
          (t.title! as Text).data,
      ];
      expect(choices.take(2), <String>['Bancolombia', 'Visa']);

      await tester.tap(find.text('Visa').last);
      await settle(tester);
      final Account visa = own.accounts.firstWhere(
        (Account a) => a.name == 'Visa',
      );
      final List<Entry> entries = (await tester.runAsync(own.store.entries))!;
      final Entry exito = entries.firstWhere(
        (Entry e) => e.payee == 'Éxito Laureles' && e.source != 'manual',
      );
      expect(exito.accountId, visa.id);
      expect(exito.amount, Decimal.parse('-63200'));
      expect(find.textContaining('Gasto registrado en Visa.'), findsOneWidget);
      expect(
        (await tester.runAsync(own.store.captureSettings))!.cardAccounts,
        <String, String>{'1234': visa.id},
      );
      expect(find.text('NECESITAN INFORMACIÓN'), findsNothing);
    },
  );

  testWidgets('the form asks for the account instead of guessing one', (
    tester,
  ) async {
    final OwnController own = await open(tester, withCaptures);
    await tester.tap(find.text('Editar').last);
    await settle(tester);
    expect(find.text('Revisar movimiento'), findsOneWidget);

    await tester.ensureVisible(find.text('Registrar gasto'));
    await tester.tap(find.text('Registrar gasto'));
    await settle(tester);
    expect(find.text('Elige la cuenta.'), findsOneWidget);
    bool fromCapture(Entry e) =>
        e.payee == 'Éxito Laureles' && e.source != 'manual';
    expect(
      (await tester.runAsync(own.store.entries))!.where(fromCapture),
      isEmpty,
    );

    await tester.ensureVisible(find.text('Cuenta'));
    await tester.tap(find.text('Cuenta'));
    await settle(tester);
    await tester.tap(find.text('Visa').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Registrar gasto'));
    await tester.tap(find.text('Registrar gasto'));
    await settle(tester);
    final Entry exito = (await tester.runAsync(
      own.store.entries,
    ))!.singleWhere(fromCapture);
    expect(
      exito.accountId,
      own.accounts.firstWhere((Account a) => a.name == 'Visa').id,
    );
    expect(find.textContaining('Gasto registrado en Visa.'), findsOneWidget);
  });

  testWidgets('the payment to read is a picture or a copied message', (
    tester,
  ) async {
    await open(tester, withCaptures);
    await tester.tap(find.text('Leer un pago'));
    await settle(tester);
    expect(find.text('¿Dónde está el pago?'), findsOneWidget);
    expect(find.text('Un pantallazo, foto o PDF'), findsOneWidget);

    await tester.tap(find.text('Un mensaje que copiaste'));
    await settle(tester);
    expect(find.text('Pegar un mensaje'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a narrow phone keeps the title whole and the name its room', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, withCaptures, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    // The way to read a payment leaves the bar to the title.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Leer un pago'),
      ),
      findsNothing,
    );
    expect(find.text('Leer un pago'), findsOneWidget);
    // The amount goes under the name rather than squeezing it.
    expect(
      tester.getTopLeft(find.text(r'+$85.000')).dy,
      greaterThan(tester.getBottomLeft(find.text('Laura Gómez')).dy),
    );
  });

  testWidgets('a phone with room keeps both in the bar, side by side', (
    tester,
  ) async {
    await open(tester, withCaptures);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Leer un pago'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text(r'+$85.000')).dy,
      lessThan(tester.getBottomLeft(find.text('Laura Gómez')).dy),
    );
  });

  group('some clear, some not', () {
    /// Nequi, its card and a bakery known; two purchases there, one at a
    /// shop the app has no category for, and one with no bank named that
    /// only the single peso account could be.
    Future<QuincenaStore> mixed() async {
      final store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => screensNow,
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      final Account nequi = await store.addAccount(
        name: 'Nequi',
        kind: AccountKind.wallet,
        asset: Asset.cop,
        institution: 'Nequi',
        opening: Decimal.parse('900000'),
      );
      await store.saveCaptureSettings(
        const CaptureSettings(
          merchantCategories: <String, String>{
            'panaderia la espiga': 'groceries',
          },
        ).copyWith(cardAccounts: <String, String>{'9876': nequi.id}),
      );
      CaptureEvent nequiPush(String text, int minutes) => CaptureEvent(
        source: CaptureSource.notification,
        at: screensNow.subtract(Duration(minutes: minutes)),
        app: 'com.nequi.MobileApp',
        appName: 'Nequi',
        text: text,
      );
      final OwnController own = OwnController(
        store,
        now: () => screensNow,
        readNative: false,
      );
      await own.capture.ingest(<CaptureEvent>[
        nequiPush(
          r'Pagaste $8.000 en PANADERIA LA ESPIGA con tu tarjeta *9876',
          10,
        ),
        nequiPush(
          r'Pagaste $9.500 en PANADERIA LA ESPIGA con tu tarjeta *9876',
          20,
        ),
        nequiPush(r'Pagaste $5.000 en TIENDA X con tu tarjeta *9876', 30),
        CaptureEvent(
          source: CaptureSource.notification,
          at: screensNow.subtract(const Duration(minutes: 40)),
          app: 'com.some.wallet',
          text: r'Compraste $12.000 en TIENDAS D1',
        ),
      ]);
      own.dispose();
      return store;
    }

    testWidgets('the button says how many of the ready it records', (
      tester,
    ) async {
      final OwnController own = await open(tester, mixed);
      // Only guessed from being the one peso account: it needs a look.
      final double needs = top(tester, find.text('NECESITAN INFORMACIÓN'));
      expect(top(tester, find.text('Tiendas D1')), greaterThan(needs));
      expect(
        find.text(
          'Revisa la cuenta: la elegimos por ser tu única de uso diario en '
          'COP.',
        ),
        findsOneWidget,
      );

      // The shop without a category is ready, but not as clear as the
      // bakery: the button names the share it takes.
      expect(top(tester, find.text('Tienda X')), lessThan(needs));
      await tester.tap(find.text('Registrar 2 de los 3 listos'));
      await settle(tester);
      expect(find.text('2 movimientos registrados.'), findsOneWidget);
      expect(
        <String>[
          for (final Entry e in (await tester.runAsync(own.store.entries))!)
            e.payee,
        ],
        <String>['Panaderia la Espiga', 'Panaderia la Espiga'],
      );
      expect(find.text('Tienda X'), findsOneWidget);
      expect(find.textContaining('listos'), findsNothing);
    });
  });

  group('many waiting', () {
    /// Nequi, its card and a bakery already known, and twenty purchases
    /// there on the card.
    Future<QuincenaStore> twenty() async {
      final store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => screensNow,
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      final Account nequi = await store.addAccount(
        name: 'Nequi',
        kind: AccountKind.wallet,
        asset: Asset.cop,
        institution: 'Nequi',
        opening: Decimal.parse('900000'),
      );
      await store.saveCaptureSettings(
        const CaptureSettings(
          merchantCategories: <String, String>{
            'panaderia la espiga': 'groceries',
          },
        ).copyWith(cardAccounts: <String, String>{'9876': nequi.id}),
      );
      final OwnController own = OwnController(
        store,
        now: () => screensNow,
        readNative: false,
      );
      await own.capture.ingest(<CaptureEvent>[
        for (var k = 0; k < 20; k++)
          CaptureEvent(
            source: CaptureSource.notification,
            at: screensNow.subtract(Duration(minutes: 40 * k + 5)),
            app: 'com.nequi.MobileApp',
            appName: 'Nequi',
            text:
                'Pagaste \$${k + 1}.${k % 10}00 en PANADERIA LA ESPIGA con tu '
                'tarjeta *9876',
          ),
      ]);
      own.dispose();
      return store;
    }

    testWidgets('take a line each, and the ready ones go in at once', (
      tester,
    ) async {
      final OwnController own = await open(tester, twenty);
      expect(own.pendingInbox, hasLength(20));
      expect(find.text('20 movimientos por revisar'), findsOneWidget);
      expect(find.text('20 listos'), findsOneWidget);
      // A line each: the button that records it, and nothing else to tap.
      expect(find.byTooltip('Registrar gasto'), findsNWidgets(20));
      expect(find.text('Editar'), findsNothing);
      expect(tester.takeException(), isNull);

      // A line opens into the whole card.
      await tester.tap(find.text('Panaderia la Espiga').first);
      await settle(tester);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.byTooltip('Registrar gasto'), findsNWidgets(19));

      await tester.tap(find.text('Registrar los 20 listos'));
      await settle(tester);
      expect(find.text('20 movimientos registrados.'), findsOneWidget);
      expect(find.text('Todo al día.'), findsOneWidget);
      expect((await tester.runAsync(own.store.entries))!, hasLength(20));

      await tester.tap(find.text('Deshacer'));
      await settle(tester);
      expect((await tester.runAsync(own.store.entries))!, isEmpty);
      expect(own.pendingInbox, hasLength(20));
      expect(find.text('Registrar los 20 listos'), findsOneWidget);
    });

    testWidgets('hold at twice the text size on a small phone', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, twenty, size: const Size(360, 800));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Panaderia la Espiga').first);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
