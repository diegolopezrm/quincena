// The screens for someone's own money, the way people with a screen reader,
// large text or low vision meet them: on the smallest common phone, with
// the system text at twice its size, in both themes, held to Flutter's
// accessibility guidelines.
import 'dart:convert';

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
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/portfolio/market.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/sync/sync_service.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/account_page.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/balance_explained.dart';
import 'package:quincena/ui/own/binance_page.dart';
import 'package:quincena/ui/own/capture_settings_page.dart';
import 'package:quincena/ui/own/close_page.dart';
import 'package:quincena/ui/own/commitments_page.dart';
import 'package:quincena/ui/own/coming_days_page.dart';
import 'package:quincena/ui/own/cushion_page.dart';
import 'package:quincena/ui/own/detective_page.dart';
import 'package:quincena/ui/own/envelopes_page.dart';
import 'package:quincena/ui/own/free_explained.dart';
import 'package:quincena/ui/own/freelance_page.dart';
import 'package:quincena/ui/own/home_tab.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/instalments_page.dart';
import 'package:quincena/ui/own/plan_tab.dart';
import 'package:quincena/ui/own/portfolio_page.dart';
import 'package:quincena/ui/own/shared_page.dart';
import 'package:quincena/ui/own/statement_page.dart';
import 'package:quincena/ui/own/sync_page.dart';
import 'package:quincena/ui/own/trips_page.dart';
import 'package:quincena/ui/own/wallets_page.dart';
import 'package:quincena/ui/own/what_if_page.dart';
import 'package:quincena/ui/own/wishes_page.dart';

import '../test_screens/store_screens_test.dart' show ExampleMarket, example;
import 'commitments_data.dart';
import 'fonts.dart';
import 'real_life_data.dart';
import 'own_flow_test.dart' show settle;

final DateTime _now = DateTime(2026, 10, 3, 10);

/// A Ledger the example person follows by address, with the bitcoin it
/// holds; the address is made up.
Future<void> followLedger(QuincenaStore store) async {
  const String address = 'bc1qexampqe2wa77etq9yxz8c2kdu3ts6hrv0lmg5w';
  await store.setSetting(
    'wallets',
    jsonEncode(<String, Object?>{
      'wallets': <Object?>[
        <String, Object?>{
          'chain': 'bitcoin',
          'address': address,
          'label': 'Ledger',
        },
      ],
      'syncedAt': _now.toIso8601String(),
    }),
  );
  await store.addAccount(
    name: 'Bitcoin',
    kind: AccountKind.wallet,
    asset: Asset.btc,
    opening: Decimal.parse('0.0042'),
    institution: 'Ledger',
    spendable: false,
    syncRef: 'wallet:bitcoin:$address:BTC',
  );
}

/// A tab scrolled the way the app's shell scrolls it.
Widget tab(Widget body) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
    child: body,
  ),
);

/// A tab that is a list built as it scrolls, scrolled the same way.
Widget sliverTab(Widget sliver) => Scaffold(
  body: CustomScrollView(
    slivers: <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        sliver: sliver,
      ),
    ],
  ),
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  final Map<String, Widget Function(OwnController own)> screens =
      <String, Widget Function(OwnController own)>{
        'home': (OwnController own) =>
            tab(OwnHomeTab(own: own, onSeeAll: () {}, onAsk: ([String? _]) {})),
        'movements': (OwnController own) => sliverTab(MovementsTab(own: own)),
        'accounts': (OwnController own) => tab(AccountsTab(own: own)),
        'where the net worth comes from': (OwnController own) =>
            tab(TotalExplained(own: own)),
        'a card': (OwnController own) => AccountPage(
          own: own,
          accountId: own.accounts
              .firstWhere((Account a) => a.kind == AccountKind.card)
              .id,
        ),
        'where the money to spend comes from': (OwnController own) =>
            Scaffold(body: FreeExplained(own: own)),
        'crypto': (OwnController own) => PortfolioPage(own: own),
        'Binance': (OwnController own) => BinancePage(own: own),
        'wallets': (OwnController own) => WalletsPage(own: own),
        'a statement': (OwnController own) => StatementPage(
          own: own,
          accountId: own.accounts
              .firstWhere((Account a) => a.name == 'Bancolombia')
              .id,
          statement: readTable(
            parseCsv(
              'Fecha;Descripción;Valor;Saldo\n'
              '28/09/2026;COMPRA EN D1 LAURELES;-32.400;1.245.600\n'
              '27/09/2026;PAGO PSE CLARO HOGAR;-98.900;1.278.000\n'
              '26/09/2026;TRANSFERENCIA DE CAMILO RIOS;150.000;1.376.900\n',
            ),
          ),
        ),
        'to review': (OwnController own) => InboxPage(own: own),
        'the next 30 days': (OwnController own) => ComingDaysPage(own: own),
        'can I afford it': (OwnController own) =>
            ComingDaysPage(own: own, tryPurchase: true),
        'the close': (OwnController own) => ClosePage(own: own),
        'plan': (OwnController own) => tab(PlanTab(own: own)),
        'envelopes': (OwnController own) => EnvelopesPage(own: own),
        'the cushion in days': (OwnController own) => CushionPage(own: own),
        'wishes': (OwnController own) => WishesPage(own: own),
        'what if': (OwnController own) => WhatIfPage(own: own),
        'automatic capture': (OwnController own) =>
            CaptureSettingsPage(own: own),
        'fixed payments': (OwnController own) => CommitmentsPage(own: own),
        'instalments': (OwnController own) => InstalmentsPage(own: own),
        'an instalment purchase': (OwnController own) =>
            InstalmentDetailPage(own: own, id: televisor),
        'charges to check': (OwnController own) => DetectivePage(own: own),
        'shared expenses': (OwnController own) => SharedPage(own: own),
        'a group': (OwnController own) => GroupPage(own: own, id: guatape),
        'variable income': (OwnController own) => FreelancePage(own: own),
        'trips': (OwnController own) => TripsPage(own: own),
        'a trip': (OwnController own) => TripPage(own: own, id: newYork),
        'more than one device': (OwnController own) =>
            SyncPage(own: own, keys: MemoryKeyStore()),
      };

  for (final MapEntry<String, Widget Function(OwnController)> screen
      in screens.entries) {
    for (final Brightness brightness in Brightness.values) {
      testWidgets(
        '${screen.key} holds at twice the text size, ${brightness.name}',
        (WidgetTester tester) async {
          final SemanticsHandle semantics = tester.ensureSemantics();
          // Google Play's smallest screenshot phone, 360 by 800.
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final QuincenaStore store = (await tester.runAsync(() async {
            final QuincenaStore store = await example();
            await followLedger(store);
            await addCommitments(store);
            await addRealLife(store);
            return store;
          }))!;
          addTearDown(() => tester.runAsync(store.close));
          final MarketData market = ExampleMarket();
          final OwnController own = OwnController(
            store,
            now: () => _now,
            readNative: false,
            market: market,
          );
          addTearDown(own.dispose);
          await tester.runAsync(own.start);
          await tester.runAsync(() => own.portfolio.refresh());

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: quincenaTheme(brightness),
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: appLocales,
              home: screen.value(own),
            ),
          );
          await settle(tester);

          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        },
      );
    }
  }

  testWidgets('the buttons inside the lists are 48 points tall at twice '
      'the text size', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = await example();
      await followLedger(store);
      return store;
    }))!;
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => _now,
      readNative: false,
      market: ExampleMarket(),
    );
    addTearDown(own.dispose);
    await tester.runAsync(own.start);
    await tester.runAsync(() => own.portfolio.refresh());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: tab(AccountsTab(own: own)),
      ),
    );
    await settle(tester);

    Future<double> tall(Finder label, Type type) async {
      await tester.scrollUntilVisible(
        label,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await settle(tester);
      return tester
          .getSize(find.ancestor(of: label, matching: find.byType(type)).first)
          .height;
    }

    expect(
      await tall(find.text('Agregar cuenta'), OutlinedButton),
      greaterThanOrEqualTo(48),
    );
    expect(
      await tall(find.text('Rendimiento y ganancia'), InkWell),
      greaterThanOrEqualTo(48),
    );

    // The sources on the crypto page, rows of a panel now.
    await tester.tap(find.text('Rendimiento y ganancia'));
    await settle(tester);
    expect(find.byType(PortfolioPage), findsOneWidget);
    expect(
      await tall(find.text('Billeteras propias'), InkWell),
      greaterThanOrEqualTo(48),
    );
    expect(
      await tall(find.text('Binance').last, InkWell),
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  // Just set up: one account, nothing paid regularly yet, so the figure is
  // provisional and the first thing to do is to add the fixed payments.
  for (final Brightness brightness in Brightness.values) {
    testWidgets(
      'home, new account, holds at twice the text size, ${brightness.name}',
      (WidgetTester tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final QuincenaStore store = (await tester.runAsync(() async {
          final QuincenaStore store = QuincenaStore(
            QuincenaDatabase(NativeDatabase.memory()),
            now: () => _now,
          );
          await store.ensureCategories();
          await store.saveProfile(
            const Profile(
              name: 'Diego',
              base: Asset.cop,
              schedule: TwiceMonthly(),
            ),
          );
          await store.addAccount(
            name: 'Nequi',
            kind: AccountKind.wallet,
            asset: Asset.cop,
            opening: Decimal.parse('850000'),
          );
          return store;
        }))!;
        addTearDown(() => tester.runAsync(store.close));
        final OwnController own = OwnController(
          store,
          now: () => _now,
          readNative: false,
        );
        addTearDown(own.dispose);
        await tester.runAsync(own.start);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: quincenaTheme(brightness),
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: appLocales,
            home: tab(
              OwnHomeTab(own: own, onSeeAll: () {}, onAsk: ([String? _]) {}),
            ),
          ),
        );
        await settle(tester);

        expect(find.text('Provisional: faltan tus pagos fijos'), findsOne);
        expect(find.text('Agrega tus pagos fijos'), findsOne);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }
}
