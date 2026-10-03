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
import 'package:quincena/ui/own/capture_rules_page.dart';
import 'package:quincena/ui/own/inbox_page.dart';

import 'own_flow_test.dart' show settle;

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  CaptureEvent bakery(String amount, int hour) => CaptureEvent(
    source: CaptureSource.notification,
    at: DateTime(2026, 10, 3, hour),
    app: 'com.nequi.MobileApp',
    appName: 'Nequi',
    text: 'Pagaste \$$amount en PANADERIA LA ESPIGA con tu tarjeta *9876',
  );

  Future<(OwnController, QuincenaStore)> open(
    WidgetTester tester,
    Widget Function(OwnController own) page,
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
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await store.addAccount(
        name: 'Nequi',
        kind: AccountKind.wallet,
        asset: Asset.cop,
        institution: 'Nequi',
        opening: Decimal.parse('200000'),
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
    return (own, store);
  }

  testWidgets('confirming says what it learned, and the rule can be undone', (
    tester,
  ) async {
    final (OwnController own, QuincenaStore store) = await open(
      tester,
      (OwnController own) => InboxPage(own: own),
    );
    await tester.runAsync(
      () => own.capture.ingest(<CaptureEvent>[bakery('8.000', 8)]),
    );
    await settle(tester);
    // The account comes from Nequi's alerts going to the only Nequi account.
    expect(find.textContaining('Sugerido porque'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await settle(tester);
    expect(
      find.textContaining('Desde ahora, «Panaderia la Espiga» va a'),
      findsOneWidget,
    );
    expect((await tester.runAsync(store.captureSettings))!.rules, isNotEmpty);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(
      (await tester.runAsync(store.captureSettings))!.merchantCategories,
      isEmpty,
    );
  });

  testWidgets('what was recorded on its own says why, and can be undone', (
    tester,
  ) async {
    final (OwnController own, QuincenaStore store) = await open(
      tester,
      (OwnController own) => InboxPage(own: own),
    );
    // Taught once, then recorded without asking.
    await tester.runAsync(() async {
      await own.capture.ingest(<CaptureEvent>[bakery('8.000', 8)]);
      final InboxItem first = (await store.inbox(
        statuses: <InboxStatus>{InboxStatus.pending},
      )).single;
      await own.capture.accept(
        first,
        accountId: own.accounts.single.id,
        category: 'groceries',
      );
      await store.saveCaptureSettings(
        (await store.captureSettings()).copyWith(autoRecord: true),
      );
      await own.capture.ingest(<CaptureEvent>[bakery('9.500', 9)]);
    });
    await settle(tester);

    expect(find.text('REGISTRADO AUTOMÁTICAMENTE'), findsOneWidget);
    expect(
      find.textContaining('así registraste Panaderia la Espiga antes'),
      findsOneWidget,
    );
    expect((await tester.runAsync(store.entries))!, hasLength(2));

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    // The movement is gone, and the capture waits for the person again.
    expect((await tester.runAsync(store.entries))!, hasLength(1));
    expect(find.text('REGISTRADO AUTOMÁTICAMENTE'), findsNothing);
    expect(find.text('Confirmar'), findsOneWidget);
  });

  testWidgets('a rule can be turned off and deleted', (tester) async {
    final (OwnController own, QuincenaStore store) = await open(
      tester,
      (OwnController own) => CaptureRulesPage(own: own),
    );
    await tester.runAsync(() async {
      await store.saveCaptureSettings(
        const CaptureSettings().withRule(
          const CaptureRule(
            kind: RuleKind.merchant,
            key: 'panaderia la espiga',
            target: 'groceries',
          ),
        ),
      );
    });
    await settle(tester);
    expect(find.text('Panaderia la Espiga'), findsOneWidget);
    expect(find.text('→ Mercado'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(
      (await tester.runAsync(store.captureSettings))!.disabledRules,
      <String>{'merchant:panaderia la espiga'},
    );

    await tester.tap(find.byTooltip('Borrar regla'));
    await settle(tester);
    expect((await tester.runAsync(store.captureSettings))!.rules, isEmpty);
    expect(find.textContaining('Todavía no hay reglas'), findsOneWidget);
  });
}
