import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rate_sources.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/accounts_tab.dart';

import 'own_flow_test.dart' show fakeRates, settle;

Decimal d(String s) => Decimal.parse(s);

/// Every source down, as when the phone is offline.
RateFetcher downRates() =>
    RateFetcher(client: MockClient((_) async => http.Response('', 500)));

void main() {
  final DateTime now = DateTime(2026, 10, 4, 10);
  late QuincenaStore store;

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// The rates page for someone with dollars, and the dollar typed by hand
  /// at 3.400 pesos when [typed].
  Future<OwnController> open(
    WidgetTester tester, {
    required RateFetcher fetcher,
    bool typed = true,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      fetcher: fetcher,
      now: () => now,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await store.addAccount(
        name: 'Dólares',
        kind: AccountKind.bank,
        asset: Asset.usd,
        opening: d('100'),
        spendable: false,
      );
      if (typed) await store.setManualRate('USD', 'COP', d('3400'));
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: RatesPage(own: own),
      ),
    );
    await settle(tester);
    return own;
  }

  Future<Rate> storedDollar(WidgetTester tester) async =>
      (await tester.runAsync(store.rates))!.firstWhere(
        (Rate r) => r.pair == 'USD/COP',
      );

  testWidgets('a rate typed by hand says so, and goes back to the automatic', (
    tester,
  ) async {
    await open(tester, fetcher: fakeRates());

    expect(find.text(r'1 USD = $3.400'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Escrita a mano el 4 oct'), findsOneWidget);
    // The fetch on opening brought the TRM, which did not replace it.
    expect(find.text(r'La automática hoy: $4.000'), findsOneWidget);
    expect((await storedDollar(tester)).manual, isTrue);

    await tester.tap(find.text('Usar la automática'));
    await settle(tester);

    expect(find.text(r'1 USD = $4.000'), findsOneWidget);
    expect(find.textContaining('TRM oficial'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
    expect(find.text('Usar la automática'), findsNothing);
    final Rate dollar = await storedDollar(tester);
    expect(dollar.manual, isFalse);
    expect(dollar.value, d('4000'));
  });

  testWidgets('offline, the typed rate stays and a notice says why', (
    tester,
  ) async {
    await open(tester, fetcher: downRates());

    // From the dialog, the long way back.
    await tester.tap(find.text(r'1 USD = $3.400'));
    await settle(tester);
    await tester.tap(find.text('Volver a la tasa automática'));
    await settle(tester);

    expect(
      find.text(
        'No se pudo traer la tasa automática. Sigue la tuya; intenta de '
        'nuevo con conexión.',
      ),
      findsOneWidget,
    );
    expect(find.text(r'1 USD = $3.400'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.textContaining('Sin tasa'), findsNothing);
    final Rate dollar = await storedDollar(tester);
    expect(dollar.manual, isTrue);
    expect(dollar.value, d('3400'));
  });

  testWidgets('an automatic rate has nothing to go back to', (tester) async {
    await open(tester, fetcher: fakeRates(), typed: false);

    expect(find.text(r'1 USD = $4.000'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
    expect(find.text('Usar la automática'), findsNothing);

    await tester.tap(find.text(r'1 USD = $4.000'));
    await settle(tester);
    expect(find.text('Escribir una tasa'), findsOneWidget);
    expect(find.text('Volver a la tasa automática'), findsNothing);

    // Saving an empty field keeps the rate rather than dropping it.
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(find.text(r'1 USD = $4.000'), findsOneWidget);
    expect((await storedDollar(tester)).source, 'trm');
  });
}
