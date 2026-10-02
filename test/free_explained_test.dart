import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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
  Future<OwnController> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
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
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
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
      await store.addRecurring(
        name: 'Netflix',
        amount: Money(d('26900'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 12),
        accountId: bank.id,
        category: 'subscriptions',
      );
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

    expect(inSheet(find.text('Así se calcula lo libre')), findsOneWidget);
    // The sum, on top and again as its parts.
    expect(inSheet(find.text(pesos(2200000))), findsOneWidget);
    expect(inSheet(find.text(pesos(-26900))), findsNWidgets(2));
    expect(inSheet(find.text(pesos(2200000 - 26900))), findsOneWidget);
    expect(inSheet(find.text(pesos(1000000))), findsOneWidget);
    expect(inSheet(find.text(pesos(1200000))), findsOneWidget);
    // The rate that converted the dollars, where it came from and its day.
    expect(inSheet(find.textContaining('TRM oficial')), findsOneWidget);
    expect(inSheet(find.textContaining('tasa del 3 oct')), findsOneWidget);
    expect(inSheet(find.text('Netflix')), findsOneWidget);
    expect(
      inSheet(find.textContaining('Ahorro: las marcaste')),
      findsOneWidget,
    );
    expect(inSheet(find.textContaining('Es una estimación')), findsOneWidget);

    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

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
}
