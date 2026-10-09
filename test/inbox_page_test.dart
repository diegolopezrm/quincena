// Por revisar as a person meets it: what one tap records apart from what
// needs a choice, an account chosen among those at the bank the alert
// names, and many captures at once.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/capture/merchants.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
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

  testWidgets('what the card taught reaches what waits with the same card, '
      'and goes back with Deshacer', (tester) async {
    await open(tester, () async {
      final QuincenaStore store = await withCaptures();
      await CaptureService(store, now: () => screensNow).ingest(<CaptureEvent>[
        CaptureEvent(
          source: CaptureSource.notification,
          at: DateTime(2026, 10, 3, 9, 50),
          app: 'com.todo1.mobile',
          appName: 'Bancolombia',
          title: 'Bancolombia',
          text: r'Bancolombia · Compra por $25.000 en Carulla T.Deb *1234',
        ),
      ]);
      return store;
    });
    Finder on(String payee, String text) => find.descendant(
      of: find.ancestor(of: find.text(payee), matching: find.byType(InboxCard)),
      matching: find.text(text),
    );
    expect(on('Carulla', 'Elegir la cuenta'), findsOneWidget);

    await tester.tap(on('Éxito Laureles', 'Elegir la cuenta'));
    await settle(tester);
    await tester.tap(find.text('Bancolombia').last);
    await settle(tester);
    // The notice names every rule, the shop with its accent, and what they
    // settled.
    expect(
      find.text(
        'Gasto registrado en Bancolombia. Desde ahora, «Éxito Laureles» va a '
        'Mercado y la tarjeta *1234 va a Bancolombia. También quedó listo '
        'otro movimiento.',
      ),
      findsOneWidget,
    );
    // Carulla, paid with the same card, no longer asks.
    expect(on('Carulla', 'Mercado · Bancolombia'), findsOneWidget);
    expect(on('Carulla', 'Registrar gasto'), findsOneWidget);
    expect(find.text('NECESITAN INFORMACIÓN'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Deshacer'),
      ),
    );
    await settle(tester);
    expect(on('Carulla', 'Elegir la cuenta'), findsOneWidget);
    expect(on('Éxito Laureles', 'Elegir la cuenta'), findsOneWidget);
  });

  testWidgets(
    'a category taught on one capture reaches the same shop waiting',
    (tester) async {
      final OwnController own = await open(tester, () async {
        final QuincenaStore store = await withCaptures();
        await CaptureService(store, now: () => screensNow).ingest(
          <CaptureEvent>[
            for (final (String amount, int minute) in <(String, int)>[
              (r'$9.800', 50),
              (r'$12.000', 55),
            ])
              CaptureEvent(
                source: CaptureSource.notification,
                at: DateTime(2026, 10, 3, 9, minute),
                app: 'com.nequi.MobileApp',
                appName: 'Nequi',
                title: 'Nequi',
                text: 'Nequi · Pagaste $amount en Tienda La Esquina',
              ),
          ],
        );
        return store;
      });
      List<InboxItem> shop() => <InboxItem>[
        for (final InboxItem i in own.pendingInbox)
          if (i.suggestion.payee == 'Tienda La Esquina') i,
      ];
      expect(shop(), hasLength(2));
      expect(shop().map((InboxItem i) => i.suggestion.category), <String?>[
        null,
        null,
      ]);

      // One of them goes to Mercado.
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.textContaining('9.800'),
            matching: find.byType(InboxCard),
          ),
          matching: find.text('Editar'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Mercado'));
      await settle(tester);
      await tester.ensureVisible(find.text('Registrar gasto').last);
      await tester.tap(find.text('Registrar gasto').last);
      await settle(tester);
      expect(
        own.captureSettings.merchantCategories[merchantKey(
          'Tienda La Esquina',
        )],
        'groceries',
      );
      // The other, still waiting, already says Mercado, and why.
      final InboxItem other = shop().single;
      expect(other.suggestion.category, 'groceries');
      expect(other.suggestion.why, contains('learned'));
      expect(CaptureService.isClear(other, own.accounts), isTrue);
      expect(find.text('Mercado · Nequi'), findsOneWidget);
    },
  );

  testWidgets('an account\'s number is learned as the account, not a card', (
    tester,
  ) async {
    final OwnController own = await open(tester, withCaptures);
    final Account bank = own.accounts.firstWhere(
      (Account a) => a.name == 'Bancolombia',
    );
    await tester.runAsync(
      () => own.ingestText(
        r'Bancolombia: movimiento por $50.000 en tu cuenta *5678',
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Revisar movimiento'));
    await settle(tester);
    await tester.tap(find.text('Ingreso'));
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Bancolombia').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Registrar ingreso').last);
    await tester.tap(find.text('Registrar ingreso').last);
    await settle(tester);
    expect(
      find.textContaining('Desde ahora, la cuenta *5678 va a Bancolombia.'),
      findsOneWidget,
    );
    expect(find.textContaining('tarjeta *5678'), findsNothing);
    final CaptureSettings settings = own.captureSettings;
    expect(settings.cardAccounts.containsKey('5678'), isFalse);
    expect(settings.accountNumbers['5678'], bank.id);

    // The account's next alert knows where it goes, and says why.
    await tester.runAsync(
      () =>
          own.ingestText(r'Bancolombia: Recibiste $20.000 en tu cuenta *5678'),
    );
    await settle(tester);
    final InboxItem next = own.pendingInbox.firstWhere(
      (InboxItem i) => i.parsed.account == '5678',
    );
    expect(next.suggestion.accountId, bank.id);
    expect(CaptureService.isReady(next, own.accounts), isTrue);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.textContaining('20.000'),
          matching: find.byType(InboxCard),
        ),
        matching: find.text('Registrar ingreso'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pesos that arrived from the dollar account stay what arrived', (
    tester,
  ) async {
    final OwnController own = await open(tester, () async {
      final QuincenaStore store = await withCaptures();
      await CaptureService(store, now: () => screensNow).ingest(<CaptureEvent>[
        CaptureEvent(
          source: CaptureSource.paste,
          at: screensNow,
          text: r'Bancolombia: Recibiste $331.284 de GLOBAL66 COLOMBIA',
        ),
      ]);
      return store;
    });
    Account named(String name) =>
        own.accounts.firstWhere((Account a) => a.name == name);
    final Account bank = named('Bancolombia');
    final Account dollars = named('Cuenta en dólares');
    final Decimal bankBefore = own.balances[bank.id]!.amount;
    final Decimal dollarsBefore = own.balances[dollars.id]!.amount;
    Finder menu(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    String field(String label) => tester
        .widget<TextField>(find.widgetWithText(TextField, label))
        .controller!
        .text;

    final Finder fromOwn = find.descendant(
      of: find.ancestor(
        of: find.text('Global66 Colombia'),
        matching: find.byType(InboxCard),
      ),
      matching: find.text('¿Viene de otra cuenta tuya?'),
    );
    await tester.ensureVisible(fromOwn);
    await tester.tap(fromOwn);
    await settle(tester);
    expect(field('Monto'), '331.284');

    await tester.tap(menu('Hacia'));
    await settle(tester);
    await tester.tap(find.text('Bancolombia').last);
    await settle(tester);
    await tester.tap(menu('Desde'));
    await settle(tester);
    await tester.tap(find.text('Cuenta en dólares').last);
    await settle(tester);
    // What the alert says arrived is what arrived; what left comes from
    // the day's rate.
    expect(field('Llegó'), '331.284');
    expect(field('Monto'), '100');

    // Typing what left keeps what the bank said arrived.
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '100,5');
    await settle(tester);
    expect(field('Llegó'), '331.284');
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '100');
    await settle(tester);

    final Finder record = find.text('Registrar transferencia');
    await tester.ensureVisible(record);
    await tester.tap(record);
    await settle(tester);
    expect(
      own.balances[dollars.id]!.amount,
      dollarsBefore - Decimal.parse('100'),
    );
    expect(own.balances[bank.id]!.amount, bankBefore + Decimal.parse('331284'));
  });

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

  testWidgets('what was recorded on its own shows as it was corrected', (
    tester,
  ) async {
    Future<QuincenaStore> automatic() async {
      final QuincenaStore store = await withCaptures();
      await store.saveCaptureSettings(
        (await store.captureSettings()).copyWith(autoRecord: true),
      );
      return store;
    }

    final OwnController own = await open(tester, automatic);
    await tester.runAsync(
      () => own.ingestText(r'Nequi: Pagaste $32.000 en Rappi'),
    );
    await settle(tester);
    expect(find.text('Restaurantes · Nequi'), findsOneWidget);

    // Corrected in its sheet: another category, a name, an amount.
    final Entry made = (await tester.runAsync(
      own.store.entries,
    ))!.singleWhere((Entry e) => e.source == 'paste');
    await tester.runAsync(
      () => own.store.updateEntry(
        made.copyWith(
          category: 'leisure',
          payee: 'Rappi Turbo',
          amount: Decimal.parse('-30000'),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Rappi Turbo'), findsOneWidget);
    expect(find.text('Salidas · Nequi'), findsOneWidget);
    expect(find.textContaining('30.000'), findsOneWidget);
    expect(find.text('Restaurantes · Nequi'), findsNothing);
  });

  testWidgets('a payment that does not say which way it went has no sign', (
    tester,
  ) async {
    final OwnController own = await open(tester, withCaptures);
    await tester.runAsync(
      () => own.ingestText(
        r'Bancolombia: movimiento por $50.000 en tu cuenta *5678',
      ),
    );
    await settle(tester);
    expect(
      find.text('No sabemos si es un gasto o un ingreso.'),
      findsOneWidget,
    );
    final String shown = tester
        .widget<Text>(find.textContaining('50.000'))
        .data!;
    expect(shown, isNot(contains('−')));
    expect(shown, isNot(contains('+')));
  });

  testWidgets('what the sheet records keeps its note and when it was paid', (
    tester,
  ) async {
    final OwnController own = await open(tester, withCaptures);
    final InboxItem exito = own.pendingInbox.firstWhere(
      (InboxItem i) => i.suggestion.payee == 'Éxito Laureles',
    );
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Éxito Laureles'),
          matching: find.byType(InboxCard),
        ),
        matching: find.text('Editar'),
      ),
    );
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Bancolombia').last);
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nota (opcional)'),
      'Almuerzo con el equipo',
    );
    await tester.ensureVisible(find.text('Registrar gasto'));
    await tester.tap(find.text('Registrar gasto'));
    await settle(tester);

    final Entry made = (await tester.runAsync(
      own.store.entries,
    ))!.singleWhere((Entry e) => e.sourceRef == exito.id);
    expect(made.note, 'Almuerzo con el equipo');
    // The alert came at 9:40: the day was not changed, nor is its hour.
    expect(made.date, exito.event.at);
  });

  testWidgets('a pasted message is read once the dialog has closed', (
    tester,
  ) async {
    final OwnController own = await open(tester, withCaptures);
    final int waiting = own.pendingInbox.length;
    Future<void> paste(String text, String button) async {
      await tester.tap(find.text('Leer un pago'));
      await settle(tester);
      await tester.tap(find.text('Un mensaje que copiaste'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text(button));
      // The dialog draws its field while it closes: the field still has
      // its text then.
      await settle(tester);
    }

    await paste(r'Nequi: Pagaste $32.000 en Rappi', 'Cancelar');
    expect(tester.takeException(), isNull);
    expect(own.pendingInbox, hasLength(waiting));

    await paste(r'Nequi: Pagaste $32.000 en Rappi', 'Leer');
    expect(tester.takeException(), isNull);
    expect(find.text('Pegar un mensaje'), findsNothing);
    expect(find.text('Quedó en Por revisar.'), findsOneWidget);
    expect(own.pendingInbox, hasLength(waiting + 1));
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
      tester.getTopLeft(find.text('+$signJoiner\$85.000')).dy,
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
      tester.getTopLeft(find.text('+$signJoiner\$85.000')).dy,
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
