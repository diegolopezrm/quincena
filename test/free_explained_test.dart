import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/free_explained.dart';
import 'package:quincena/ui/own/home_tab.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;

Decimal d(String s) => Decimal.parse(s);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// Pesos and dollars to spend, savings that do not count, and Netflix
  /// due before payday.
  Future<OwnController> open(
    WidgetTester tester, {
    String? pay,
    String? cushion,
    bool fixed = true,
    Future<void> Function(QuincenaStore store)? data,
    DateTime? since,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // The accounts are written down at [since], today unless a test says.
    DateTime clock = since ?? now;
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => clock,
    );
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => now,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        Profile(
          name: 'Ana',
          base: Asset.cop,
          schedule: const TwiceMonthly(),
          pay: pay == null ? null : d(pay),
          cushion: cushion == null ? null : d(cushion),
        ),
      );
      await store.saveRates(<Rate>[
        Rate(
          asset: 'USD',
          quote: 'COP',
          value: d('4000'),
          asOf: DateTime(2026, 10, 3),
          source: 'trm',
        ),
      ]);
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1000000'),
      );
      await store.addAccount(
        name: 'Dólares',
        kind: AccountKind.bank,
        asset: Asset.usd,
        opening: d('300'),
      );
      await store.addAccount(
        name: 'Ahorro',
        kind: AccountKind.investment,
        asset: Asset.cop,
        opening: d('500000'),
        spendable: false,
      );
      if (fixed) {
        await store.addRecurring(
          name: 'Netflix',
          amount: Money(d('26900'), Asset.cop),
          cadence: Cadence.monthly,
          nextDate: DateTime(2026, 10, 12),
          accountId: bank.id,
          category: 'subscriptions',
        );
      }
      await data?.call(store);
      clock = now;
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: OwnHomeTab(own: own, onSeeAll: () {}),
          ),
        ),
      ),
    );
    await settle(tester);
    return own;
  }

  testWidgets('the free amount shows where every peso of it comes from', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final OwnController own = await open(tester);
    final Ledger ledger = own.ledger!;
    // 1.000.000 in pesos and 300 dollars at 4.000; Netflix before payday.
    expect(ledger.balance, 2200000);
    expect(ledger.committedUntilPayday, 26900);

    await tester.tap(find.text('¿De dónde sale?'));
    await settle(tester);
    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(FreeExplained), matching: f);

    expect(
      inSheet(find.text('Así se calcula lo que puedes gastar')),
      findsOneWidget,
    );
    // The sum, on top and again as its parts.
    expect(inSheet(find.text(pesos(2200000))), findsOneWidget);
    expect(inSheet(find.text(pesos(-26900))), findsNWidgets(2));
    expect(inSheet(find.text(pesos(2200000 - 26900))), findsOneWidget);
    expect(inSheet(find.text(pesos(1000000))), findsOneWidget);
    expect(inSheet(find.text(pesos(1200000))), findsOneWidget);
    // The rate that converted the dollars, where it came from and its day.
    expect(inSheet(find.textContaining('TRM oficial')), findsOneWidget);
    expect(
      inSheet(
        find.textContaining(
          r'Conversión a COP: 1 US$ = $4.000 · TRM oficial del 3 oct',
        ),
      ),
      findsOneWidget,
    );
    expect(inSheet(find.text('Netflix')), findsOneWidget);
    expect(
      inSheet(find.textContaining('Ahorro: las marcaste')),
      findsOneWidget,
    );
    // Further down: what it assumes, said plainly.
    final Finder sheetScroll = find
        .descendant(
          of: find.byType(FreeExplained),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final String line in <String>[
      'No sabe cuánto te pagan',
      'No tiene colchón',
      'Es una estimación',
    ]) {
      await tester.scrollUntilVisible(
        inSheet(find.textContaining(line)),
        120,
        scrollable: sheetScroll,
      );
      expect(inSheet(find.textContaining(line)), findsOneWidget);
    }

    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets(
    'what waits in Por revisar and what a card owes are said, not hidden',
    (tester) async {
      final OwnController own = await open(
        tester,
        data: (QuincenaStore store) async {
          final Account visa = await store.addAccount(
            name: 'Visa',
            kind: AccountKind.card,
            asset: Asset.cop,
            opening: d('-300000'),
          );
          expect(visa.spendable, isTrue);
          await CaptureService(store, now: () => now).ingest(<CaptureEvent>[
            CaptureEvent(
              source: CaptureSource.notification,
              at: now,
              app: 'com.todo1.mobile',
              text:
                  r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES con '
                  r'tu T.Deb *1234',
            ),
          ]);
        },
      );
      expect(own.pendingInbox, hasLength(1));
      // The capture is not in the figure yet, and the row says so.
      expect(own.ledger!.balance, 2200000 - 300000);
      expect(
        find.text('Aún no cuenta en lo que puedes gastar.'),
        findsOneWidget,
      );
      // On the card, the accounts and the Visa's debt apart.
      expect(find.text(pesos(2200000)), findsOneWidget);
      expect(find.text(pesos(-300000)), findsOneWidget);

      await tester.tap(find.text('¿De dónde sale?'));
      await settle(tester);
      Finder inSheet(Finder f) =>
          find.descendant(of: find.byType(FreeExplained), matching: f);
      expect(inSheet(find.text('Lo que debes en tarjetas')), findsOneWidget);
      expect(inSheet(find.text(pesos(2200000))), findsOneWidget);
      // The Visa under what is owed on cards, not among the accounts, so
      // each panel adds up to its line of the sum.
      expect(inSheet(find.text('LO QUE DEBES EN TARJETAS')), findsOneWidget);
      expect(inSheet(find.text(pesos(-300000))), findsNWidgets(2));
      expect(
        tester.getTopLeft(inSheet(find.text('Visa'))).dy,
        greaterThan(
          tester.getTopLeft(inSheet(find.text('LO QUE DEBES EN TARJETAS'))).dy,
        ),
      );
      expect(
        inSheet(find.text(pesos(2200000 - 300000 - 26900))),
        findsOneWidget,
      );
      final Finder sheetScroll = find
          .descendant(
            of: find.byType(FreeExplained),
            matching: find.byType(Scrollable),
          )
          .first;
      const String pending =
          'No cuenta 1 movimiento que espera en Por revisar. Cuando lo '
          'registres, la cifra puede cambiar.';
      await tester.scrollUntilVisible(
        inSheet(find.text(pending)),
        120,
        scrollable: sheetScroll,
      );
      expect(inSheet(find.text(pending)), findsOneWidget);
    },
  );

  testWidgets('a screen reader can reach the question from the card', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);
    expect(
      tester.getSemantics(find.text('¿De dónde sale?')),
      matchesSemantics(
        label: '¿De dónde sale?',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });
  testWidgets('the cushion is taken out, and a late pay is said', (
    tester,
  ) async {
    // Paid on the 30th, nothing came in since the accounts were written
    // down on the 20th, and 100.000 kept untouched.
    final OwnController own = await open(
      tester,
      pay: '2400000',
      cushion: '100000',
      since: DateTime(2026, 9, 20),
    );
    final Ledger ledger = own.ledger!;
    expect(ledger.freeUntilPayday, 2200000 - 26900 - 100000);
    // On the home, the first thing to do, and it opens on an income.
    expect(find.text('Registra tu pago del 30 de septiembre'), findsOneWidget);
    expect(
      find.text('Todavía no aparece. Si ya llegó, regístralo para que cuente.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
    await settle(tester);
    // Money that came in, without asking what happened.
    expect(find.text('Me entró plata'), findsOneWidget);
    expect(find.text('¿Qué pasó?'), findsNothing);
    Navigator.of(tester.element(find.text('Me entró plata'))).pop();
    await settle(tester);

    await tester.tap(find.text('¿De dónde sale?'));
    await settle(tester);
    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(FreeExplained), matching: f);
    expect(inSheet(find.text('Colchón que guardas')), findsOneWidget);
    expect(inSheet(find.text(pesos(-100000))), findsOneWidget);
    expect(inSheet(find.text(pesos(2200000 - 26900 - 100000))), findsOneWidget);
    final Finder sheetScroll = find
        .descendant(
          of: find.byType(FreeExplained),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final String line in <String>[
      'Tu pago de ${pesos(2400000)} del 15 de octubre no cuenta',
      'Deja por fuera ${pesos(100000)} de colchón',
    ]) {
      await tester.scrollUntilVisible(
        inSheet(find.textContaining(line)),
        120,
        scrollable: sheetScroll,
      );
      expect(inSheet(find.textContaining(line)), findsOneWidget);
    }
    // The late pay is still said among what the figure assumes.
    const String late =
        'Tu pago del 30 de septiembre todavía no aparece. '
        'Si ya llegó, regístralo.';
    await tester.scrollUntilVisible(
      inSheet(find.text(late)),
      120,
      scrollable: sheetScroll,
    );
    expect(inSheet(find.text(late)), findsOneWidget);
  });

  testWidgets('with no fixed payment told, the figure says what it assumes', (
    tester,
  ) async {
    final OwnController own = await open(tester, fixed: false);
    expect(own.provisional, isTrue);
    // On the card, under the figure, and heard with it.
    expect(find.text('Provisional: faltan tus pagos fijos'), findsOneWidget);
    expect(find.text('Agrega tus pagos fijos'), findsOneWidget);

    await tester.tap(find.text('¿De dónde sale?'));
    await settle(tester);
    final Finder sheetScroll = find
        .descendant(
          of: find.byType(FreeExplained),
          matching: find.byType(Scrollable),
        )
        .first;
    final Finder noFixed = find.descendant(
      of: find.byType(FreeExplained),
      matching: find.textContaining('No tiene pagos fijos'),
    );
    // First among the assumptions: the one that moves the figure most.
    final Finder today = find.descendant(
      of: find.byType(FreeExplained),
      matching: find.textContaining('Cuenta lo que hay hoy'),
    );
    await tester.scrollUntilVisible(today, 120, scrollable: sheetScroll);
    expect(noFixed, findsOneWidget);
    expect(
      tester.getTopLeft(noFixed).dy,
      lessThan(tester.getTopLeft(today).dy),
    );
  });

  testWidgets('saying there are none, where they are added, ends it', (
    tester,
  ) async {
    final OwnController own = await open(tester, fixed: false);
    // The first thing to do opens the fixed payments.
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await settle(tester);
    expect(find.text('Pagos fijos'), findsOneWidget);
    await tester.tap(find.text('No tengo pagos fijos'));
    await settle(tester);
    expect(
      find.text('Listo. Lo que puedes gastar ya no es provisional.'),
      findsOneWidget,
    );
    expect(find.text('No tengo pagos fijos'), findsNothing);
    expect(own.noFixedPayments, isTrue);
    expect(own.provisional, isFalse);
  });
}
