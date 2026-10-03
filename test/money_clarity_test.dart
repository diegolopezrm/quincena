// Phase 16: that the money reads by itself. One figure to spend and the sum
// under it, a card's debt as a debt, net worth as what is had minus what is
// owed, money moved between the person's own accounts kept out of income, a
// statement import that ends on what is left to check, and every amount in
// one format.
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show LicenseEntry, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/licenses.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/standing.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show screen;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

/// A ledger on 3 October, paid on [schedule], with [balance] in the bank,
/// [due] to pay before payday, and what is kept apart.
Ledger ledgerOf({
  int balance = 500000,
  int due = 26900,
  int cushion = 0,
  int setAside = 0,
  PaySchedule schedule = const TwiceMonthly(),
}) => Ledger(
  owner: 'Ana',
  today: DateTime(2026, 10, 3),
  openingBalance: balance,
  movements: const <Movement>[],
  subscriptions: const <Subscription>[],
  goals: const <Goal>[],
  schedule: schedule,
  cushion: cushion,
  setAside: setAside,
  upcoming: <Movement>[
    if (due > 0)
      Movement(
        id: 'internet',
        date: DateTime(2026, 10, 12),
        merchant: 'Claro',
        amount: due,
        category: Category.subscriptions,
      ),
  ],
);

Future<void> showCard(WidgetTester tester, Ledger ledger) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: quincenaTheme(Brightness.light),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: StandingCard(ledger: ledger)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  group('the home card', () {
    testWidgets('one figure to spend, until when, and the sum under it', (
      tester,
    ) async {
      await showCard(tester, ledgerOf(cushion: 100000, setAside: 50000));
      final String text = screen(tester);
      expect(text, contains('Puedes gastar'));
      expect(text, contains(r'$323.100'));
      expect(text, contains('hasta el 15 de octubre'));
      expect(text, contains('Tu quincena llega en 12 días'));
      // What is there, and each thing held back from it, in its own line.
      expect(text, contains('Disponible hoy'));
      expect(text, contains(r'$500.000'));
      expect(text, contains('Pagos antes del 15 oct'));
      expect(text, contains(r'−$26.900'));
      expect(text, contains('Colchón'));
      expect(text, contains(r'−$100.000'));
      expect(text, contains('Apartado en sobres'));
      expect(text, contains(r'−$50.000'));
      // No second figure that reads as spendable.
      expect(text, isNot(contains('Para gastar')));
    });

    testWidgets('a line only for what there is', (tester) async {
      await showCard(tester, ledgerOf(due: 0));
      final String text = screen(tester);
      expect(text, contains('Disponible hoy'));
      expect(text, isNot(contains('Pagos antes')));
      expect(text, isNot(contains('Colchón')));
    });

    testWidgets('short of payday, it says how much is missing', (tester) async {
      await showCard(tester, ledgerOf(balance: 20000, due: 50000));
      final String text = screen(tester);
      expect(text, contains('Te faltan'));
      expect(text, contains(r'$30.000'));
      expect(text, contains('para llegar al 15 de octubre'));
      expect(text, isNot(contains('Puedes gastar')));
    });

    testWidgets('paid once a month, it speaks of the next pay', (tester) async {
      await showCard(tester, ledgerOf(schedule: const Monthly(30)));
      final String text = screen(tester);
      expect(text, contains('hasta el 30 de octubre'));
      expect(text, contains('Tu próximo pago llega en 27 días'));
      expect(text, isNot(contains('quincena')));
    });
  });

  group('accounts', () {
    testWidgets(
      'a credit card is a debt, and net worth is what is had minus what is '
      'owed',
      (tester) async {
        await openPage(
          tester,
          (OwnController own) => Scaffold(
            body: SingleChildScrollView(child: AccountsTab(own: own)),
          ),
          data: (QuincenaStore store, Account bank, Account card) async {
            await store.addEntry(
              accountId: card.id,
              amount: d('300000'),
              kind: EntryKind.expense,
              date: DateTime(2026, 10, 1, 12),
              category: 'shopping',
              payee: 'Falabella',
            );
          },
        );
        String text = screen(tester);
        expect(text, contains('Patrimonio'));
        expect(text, contains('Lo que tienes menos lo que debes'));
        expect(text, contains(r'$1.700.000'));
        expect(text, contains('TARJETAS DE CRÉDITO'));
        expect(text, contains('Debes'));
        expect(text, contains(r'$300.000'));
        // The card's debt is not written as money of another sign.
        expect(text, isNot(contains(r'−$300.000')));

        await tapText(tester, '¿De dónde sale?');
        text = screen(tester);
        expect(text, contains('Así se calcula tu patrimonio'));
        expect(text, contains('LO QUE TIENES'));
        expect(text, contains('LO QUE DEBES'));
        expect(text, contains(r'$2.000.000'));
        expect(text, contains(r'−$300.000'));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('captures', () {
    testWidgets(
      'money that arrives from another of the person\'s accounts is a '
      'transfer, not income',
      (tester) async {
        late Account nequi;
        final OwnController own = await openPage(
          tester,
          (OwnController own) => InboxPage(own: own),
          data: (QuincenaStore store, Account bank, Account card) async {
            nequi = await store.addAccount(
              name: 'Nequi',
              kind: AccountKind.wallet,
              asset: Asset.cop,
              opening: Decimal.zero,
              institution: 'Nequi',
            );
            await CaptureService(
              store,
              now: () => pageNow,
            ).ingest(<CaptureEvent>[
              CaptureEvent(
                source: CaptureSource.notification,
                at: DateTime(2026, 10, 3, 8, 12),
                app: 'com.nequi.MobileApp',
                appName: 'Nequi',
                title: 'Nequi',
                text: r'Nequi · Laura Gómez te envió $85.000',
              ),
            ]);
          },
        );
        expect(screen(tester), contains('¿Viene de otra cuenta tuya?'));

        await tapText(tester, '¿Viene de otra cuenta tuya?');
        // The form opens as a transfer into Nequi, where the money arrived.
        expect(find.text('Transferencia'), findsOneWidget);
        expect(screen(tester), contains('Nequi'));
        await tapText(tester, 'Guardar');

        final List<Entry> entries = (await tester.runAsync(own.store.entries))!;
        final List<Entry> moved = <Entry>[
          for (final Entry e in entries)
            if (e.kind == EntryKind.transfer) e,
        ];
        expect(moved, hasLength(2));
        expect(
          moved.singleWhere((Entry e) => e.amount > Decimal.zero).accountId,
          nequi.id,
        );
        expect(
          entries.where((Entry e) => e.kind == EntryKind.income),
          hasLength(1),
          reason: 'only the pay, not the money moved in',
        );
        expect(own.pendingInbox, isEmpty);
      },
    );
  });

  test('the licenses page credits OpenStreetMap and the fonts', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerLicenses();
    final List<String> packages = <String>[
      await for (final LicenseEntry e in LicenseRegistry.licenses)
        ...e.packages,
    ];
    expect(
      packages,
      containsAll(<String>[
        'OpenStreetMap',
        'Geist',
        'Bricolage Grotesque',
        'Phosphor Icons',
      ]),
    );
  });

  test('amounts have one format', () {
    Intl.defaultLocale = 'es_CO';
    expect(pesos(299900), r'$299.900');
    expect(pesos(-63200), r'−$63.200');
    expect(pesosShort(280300000).replaceAll(' ', ' '), r'$280,3 M');
    expect(signedPercent(106.98, 100).replaceAll(' ', ' '), '+7 %');
    Intl.defaultLocale = 'en_US';
    expect(pesos(299900), r'$299,900');
    Intl.defaultLocale = 'es_CO';
  });
}
