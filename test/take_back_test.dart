// What the person takes away says so, with «Deshacer» for a few seconds,
// and what has a big effect asks first.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/exchanges/wallets.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/messages.dart';
import 'package:quincena/ui/own/capture_rules_page.dart';
import 'package:quincena/ui/own/detective_page.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/instalments_page.dart';
import 'package:quincena/ui/own/shared_page.dart';
import 'package:quincena/ui/own/trips_page.dart';
import 'package:quincena/ui/own/wallets_page.dart';

import '../test_screens/accounts.dart';
import 'fonts.dart';
import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// Por revisar over the morning's captures, its messages one at a time
  /// as in the app.
  Future<OwnController> openInbox(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = (await tester.runAsync(withCaptures))!;
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
        builder: (BuildContext context, Widget? child) =>
            LatestMessenger(child: child!),
        home: InboxPage(own: own),
      ),
    );
    await settle(tester);
    return own;
  }

  /// Picks [choice] in the «⋮» menu of [payee]'s card.
  Future<void> fromMenu(
    WidgetTester tester,
    String payee,
    String choice,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text(payee),
          matching: find.byType(InboxCard),
        ),
        matching: find.byTooltip('Más acciones'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(choice).last);
    await settle(tester);
  }

  InboxItem capture(OwnController own, String payee) => own.inbox.firstWhere(
    (InboxItem i) => (i.suggestion.payee ?? i.parsed.merchant) == payee,
  );

  group('Por revisar', () {
    testWidgets('discarding a capture says so with a way back, and it waits '
        'again as it was', (tester) async {
      final OwnController own = await openInbox(tester);
      final InboxItem laura = capture(own, 'Laura Gómez');

      await fromMenu(tester, 'Laura Gómez', 'Descartar');
      expect(find.text('Se descartó Laura Gómez.'), findsOneWidget);
      expect(
        own.pendingInbox.map((InboxItem i) => i.id),
        isNot(contains(laura.id)),
      );

      await tester.tap(find.text('Deshacer'));
      await settle(tester);
      expect(capture(own, 'Laura Gómez').status, InboxStatus.pending);
      expect(find.text('Laura Gómez'), findsOneWidget);
    });

    testWidgets('stopping reading an app asks first, and can be taken back', (
      tester,
    ) async {
      final OwnController own = await openInbox(tester);

      await fromMenu(
        tester,
        'Éxito Laureles',
        'Descartar y no leer más Bancolombia',
      );
      expect(
        find.text('¿Dejar de leer las notificaciones de Bancolombia?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Lo que llegue de Bancolombia no va a aparecer en Por revisar. Las '
          'puedes volver a leer desde Ajustes › Captura automática.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      // Nothing happened, and the card can still be acted on.
      expect(own.captureSettings.mutedApps, isEmpty);
      expect(find.text('Éxito Laureles'), findsOneWidget);
      expect(find.text('Elegir la cuenta'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Elegir la cuenta'),
            )
            .onPressed,
        isNotNull,
      );

      await fromMenu(
        tester,
        'Éxito Laureles',
        'Descartar y no leer más Bancolombia',
      );
      await tester.tap(find.text('Dejar de leer'));
      await settle(tester);
      expect(own.captureSettings.mutedApps, <String>{'com.todo1.mobile'});
      expect(
        find.text(
          'Se descartó Éxito Laureles y ya no se leen las notificaciones de '
          'Bancolombia.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Deshacer'));
      await settle(tester);
      expect(own.captureSettings.mutedApps, isEmpty);
      expect(own.captureSettings.appNames, isEmpty);
      expect(capture(own, 'Éxito Laureles').status, InboxStatus.pending);
    });
  });

  testWidgets('an expense taken out of a trip says so, and comes back with '
      '«Deshacer»', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => TripPage(own: own, id: 'trip-ny'),
      data: (QuincenaStore store, Account bank, Account card) async {
        await store.addEntry(
          accountId: bank.id,
          amount: d('119000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2, 7),
          category: 'health',
          payee: 'Fit24',
        );
        await store.setSetting(
          'trips',
          jsonEncode(<Object?>[
            Trip(
              id: 'trip-ny',
              name: 'Nueva York',
              from: DateTime(2026, 10, 1),
              to: DateTime(2026, 10, 8),
              currency: 'COP',
            ).toJson(),
          ]),
        );
      },
    );
    Trip trip() => own.trip('trip-ny')!;

    await tester.tap(find.byTooltip('No es del viaje'));
    await settle(tester);
    expect(find.text('Fit24 ya no cuenta en el viaje.'), findsOneWidget);
    expect(trip().excluded, hasLength(1));
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(trip().excluded, isEmpty);
  });

  testWidgets('a deleted rule comes back with «Deshacer», off as it was', (
    tester,
  ) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => CaptureRulesPage(own: own),
      data: (QuincenaStore store, Account bank, Account card) =>
          store.saveCaptureSettings(
            CaptureSettings(
              cardAccounts: <String, String>{'1234': card.id},
              disabledRules: const <String>{'card:1234'},
            ),
          ),
    );
    final CaptureRule rule = own.captureSettings.rules.single;
    await tester.tap(find.byTooltip('Borrar regla'));
    await settle(tester);
    expect(own.captureSettings.rules, isEmpty);
    expect(find.text('Regla borrada.'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(own.captureSettings.rules.single, rule);
  });

  testWidgets('a wallet stops being followed without a question, and comes '
      'back with «Deshacer»', (tester) async {
    const WalletAddress ledger = WalletAddress(
      chain: Chain.bitcoin,
      address: 'bc1qexampleaddress0000000000000000000lmg5w',
      label: 'Ledger',
    );
    final OwnController own = await openPage(
      tester,
      (OwnController own) => WalletsPage(own: own),
      data: (QuincenaStore store, Account bank, Account card) =>
          store.setSetting(
            'wallets',
            jsonEncode(<String, Object?>{
              'wallets': <Object?>[ledger.toJson()],
              'syncedAt': null,
            }),
          ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Dejar de seguir'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(own.wallets.wallets, isEmpty);
    expect(
      find.text('Ya no sigues Ledger; sus cuentas se quedan como tuyas.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(own.wallets.wallets, <WalletAddress>[ledger]);
  });

  group('a group', () {
    Group flat({List<Settlement> settlements = const <Settlement>[]}) => Group(
      id: 'g-flat',
      name: 'Apto',
      members: const <Member>[
        Member(id: meId, name: ''),
        Member(id: 'p-ana', name: 'Ana'),
      ],
      expenses: <SharedExpense>[
        SharedExpense(
          id: 'x-market',
          label: 'Mercado',
          date: DateTime(2026, 10, 1),
          paidBy: meId,
          shares: const <String, int>{meId: 50000, 'p-ana': 50000},
        ),
      ],
      settlements: settlements,
    );

    Future<OwnController> openGroup(WidgetTester tester, Group group) =>
        openPage(
          tester,
          (OwnController own) => Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (BuildContext context) => Scaffold(
                body: Builder(
                  builder: (BuildContext context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            GroupPage(own: own, id: group.id),
                      ),
                    ),
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
          data: (QuincenaStore store, Account bank, Account card) =>
              store.setSetting(
                'shared.groups',
                jsonEncode(<Object?>[group.toJson()]),
              ),
        );

    testWidgets('with debts, deleting asks first and says what stops '
        'counting; then it can be taken back', (tester) async {
      final OwnController own = await openGroup(tester, flat());
      await tapText(tester, 'Abrir');
      await tester.tap(find.byTooltip('Borrar grupo'));
      await settle(tester);
      expect(find.text('¿Borrar Apto?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(
            'En este grupo te deben ${pesos(50000)}',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Borrar grupo').last);
      await settle(tester);
      expect(own.groups, isEmpty);
      expect(find.text('Se borró «Apto».'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await settle(tester);
      expect(own.groups.single.balances[meId], 50000);
    });

    testWidgets('settled, deleting asks nothing; a payment taken back says '
        'so', (tester) async {
      final Settlement paid = Settlement(
        id: 's-ana',
        from: 'p-ana',
        to: meId,
        amount: 50000,
        date: DateTime(2026, 10, 2),
      );
      final OwnController own = await openGroup(
        tester,
        flat(settlements: <Settlement>[paid]),
      );
      await tapText(tester, 'Abrir');
      await tester.tap(find.byTooltip('Quitar este pago'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Se quitó el pago de ${pesos(50000)}.'), findsOneWidget);
      expect(own.groups.single.settlements, isEmpty);
      await tester.tap(find.text('Deshacer'));
      await settle(tester);
      expect(own.groups.single.settlements.single.id, paid.id);

      await tester.tap(find.byTooltip('Borrar grupo'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(own.groups, isEmpty);
    });
  });

  testWidgets('a charge put away by the detective comes back with '
      '«Deshacer»', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => DetectivePage(own: own),
      data: (QuincenaStore store, Account bank, Account card) async {
        for (final int hour in <int>[9, 10]) {
          await store.addEntry(
            accountId: bank.id,
            amount: d('63200'),
            kind: EntryKind.expense,
            date: DateTime(2026, 10, 2, hour),
            category: 'groceries',
            payee: 'Éxito Laureles',
          );
        }
      },
    );
    final String twice = own.alerts.single.id;
    await tapText(tester, 'Descartar');
    expect(own.detective.answers[twice], AlertAnswer.dismissed);
    expect(find.text('Alerta descartada.'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(own.detective.answers[twice], isNull);
    await tapText(tester, 'Es esperado');
    expect(find.text('Marcada como esperada.'), findsOneWidget);
    expect(own.detective.answers[twice], AlertAnswer.expected);
  });

  testWidgets('a purchase in instalments asks before going only while '
      'something is left to pay', (tester) async {
    final Instalments phone = Instalments(
      id: 'i-phone',
      name: 'Celular',
      principal: 600000,
      count: 6,
      firstDue: DateTime(2026, 10, 1),
      instalment: 100000,
    );
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (BuildContext context) => Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        InstalmentDetailPage(own: own, id: phone.id),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
      data: (QuincenaStore store, Account bank, Account card) =>
          store.setSetting(
            'commitments.instalments',
            jsonEncode(<Object?>[phone.toJson()]),
          ),
    );
    await tapText(tester, 'Abrir');
    await tester.tap(find.byTooltip('Borrar compra'));
    await settle(tester);
    expect(find.text('¿Borrar Celular?'), findsOneWidget);
    expect(find.textContaining('Todavía te falta pagar'), findsOneWidget);
    await tester.tap(find.text('Borrar compra').last);
    await settle(tester);
    expect(own.instalments, isEmpty);
    expect(find.text('Se borró «Celular».'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(own.instalments.single.id, phone.id);

    // Paid off, it goes without a question.
    await tester.runAsync(
      () => own.saveInstalments(
        phone.withPayments(<(DateTime, int)>[
          for (var i = 0; i < 6; i++) (DateTime(2026, 10 + i), 100000),
        ]),
      ),
    );
    await settle(tester);
    await tapText(tester, 'Abrir');
    await tester.tap(find.byTooltip('Borrar compra'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(own.instalments, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('the way back lasts a few seconds', () {
    expect(undoTime, const Duration(seconds: 6));
  });
}
