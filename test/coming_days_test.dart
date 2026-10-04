import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/close_page.dart';
import 'package:quincena/ui/own/coming_days_page.dart';

import 'own_flow_test.dart' show settle;

Decimal d(String s) => Decimal.parse(s);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// 900.000 in the bank, a 100.000 cushion, internet on the 10th, and two
  /// whole fortnights of groceries and restaurants behind.
  Future<OwnController> open(
    WidgetTester tester,
    Widget Function(OwnController) page,
  ) async {
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
        Profile(
          name: 'Ana',
          base: Asset.cop,
          schedule: const TwiceMonthly(),
          cushion: d('100000'),
        ),
      );
      final Account bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1790000'),
      );
      for (final (String amount, DateTime on, String category)
          in <(String, DateTime, String)>[
            ('300000', DateTime(2026, 8, 30, 12), 'groceries'),
            ('100000', DateTime(2026, 9, 5, 12), 'restaurants'),
            ('290000', DateTime(2026, 9, 16, 12), 'groceries'),
            ('200000', DateTime(2026, 9, 18, 12), 'restaurants'),
          ]) {
        await store.addEntry(
          accountId: bank.id,
          amount: d(amount),
          kind: EntryKind.expense,
          date: on,
          category: category,
          payee: category == 'groceries' ? 'Éxito' : 'Crepes',
        );
      }
      await store.addRecurring(
        name: 'Internet',
        amount: Money(d('300000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 10),
        accountId: bank.id,
        category: 'utilities',
      );
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: page(own),
      ),
    );
    await settle(tester);
    return own;
  }

  testWidgets('a price tried today and after payday, and nothing saved', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => ComingDaysPage(own: own, tryPurchase: true),
    );
    expect(own.ledger!.balance, 900000);
    expect(
      find.text(
        'Saldo mínimo estimado antes del pago: ${pesos(600000)} el 10 oct',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '550.000',
    );
    await settle(tester);
    // 900.000 - 550.000 - 300.000 on the 10th: 50.000, under the cushion.
    expect(find.text('Quedarías por debajo de tu colchón'), findsWidgets);
    expect(
      find.textContaining('El 10 oct quedarías con ${pesos(50000)}'),
      findsOneWidget,
    );
    expect(find.text('Si compras hoy'), findsOneWidget);
    expect(
      find.text(
        'Es una estimación con lo que está programado, no una garantía.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto cuesta?'),
      '700.000',
    );
    await settle(tester);
    expect(find.text('No alcanza antes del pago'), findsWidgets);
    expect(
      find.textContaining('te faltarían ${pesos(100000)}'),
      findsOneWidget,
    );

    // After payday, with no pay known: it says so instead of counting one.
    await tester.tap(find.text('Después del pago'));
    await settle(tester);
    expect(find.textContaining('No sé cuánto te pagan'), findsOneWidget);
    expect(await tester.runAsync(own.store.entries), hasLength(4));
  });

  testWidgets('a charge moved in the simulation moves only the dashed line', (
    tester,
  ) async {
    final OwnController own = await open(
      tester,
      (OwnController own) => ComingDaysPage(own: own),
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Mover en la simulación').first,
      200,
    );
    await tester.tap(find.byTooltip('Mover en la simulación').first);
    await settle(tester);
    // The date picker: the 20th instead of the 10th.
    await tester.tap(find.text('20'));
    final String ok = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(ok));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Estás probando'),
      -200,
    );
    expect(find.textContaining('Estás probando'), findsOneWidget);
    expect(
      (await tester.runAsync(own.store.recurring))!.single.nextDate,
      DateTime(2026, 10, 10),
    );

    await tester.tap(find.text('Quitar lo que pruebas'));
    await settle(tester);
    expect(find.textContaining('Estás probando'), findsNothing);
  });

  testWidgets('the close tells what changed, what comes, and one thing to do', (
    tester,
  ) async {
    await open(tester, (OwnController own) => ClosePage(own: own));
    expect(
      find.text('Del 15 de septiembre al 29 de septiembre'),
      findsOneWidget,
    );
    // 490.000 against 400.000 the fortnight before.
    expect(
      find.text(
        'Gastaste ${pesos(490000)}, ${pesos(90000)} más que la quincena anterior.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Restaurantes pasó de ${pesos(100000)} a ${pesos(200000)}',
      ),
      findsOneWidget,
    );
    final Finder coming = find.textContaining(
      'Hasta el 15 de octubre hay ${pesos(300000)} comprometidos.',
    );
    await tester.scrollUntilVisible(coming, 200);
    expect(coming, findsOneWidget);

    await tester.ensureVisible(find.text('Ver los pagos'));
    await settle(tester);
    await tester.tap(find.text('Ver los pagos'));
    await settle(tester);
    expect(find.text('Crepes'), findsOneWidget);
  });
}
