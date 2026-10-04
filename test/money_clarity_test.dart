// Phase 16: that the money reads by itself. One figure to spend and the sum
// under it, a card's debt as a debt, net worth as what is had minus what is
// owed, money moved between the person's own accounts kept out of income, a
// statement import that ends on what is left to check, and every amount in
// one format.
import 'dart:convert';

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
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/licenses.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/home_tab.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/standing.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show screen, settle;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

/// A ledger on 3 October, paid on [schedule], with [balance] in the bank,
/// [due] to pay before payday, and what is kept apart.
Ledger ledgerOf({
  int balance = 500000,
  int due = 26900,
  DateTime? dueOn,
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
        date: dueOn ?? DateTime(2026, 10, 12),
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
      expect(text, contains('En tus cuentas de uso diario'));
      expect(text, contains(r'$500.000'));
      // Payday's own charges are in it too: until, not before.
      expect(text, contains('Pagos hasta el 15 oct'));
      expect(text, contains(r'−$26.900'));
      expect(text, contains('Colchón'));
      expect(text, contains(r'−$100.000'));
      expect(text, contains('Apartado en sobres'));
      expect(text, contains(r'−$50.000'));
      // No second figure that reads as spendable.
      expect(text, isNot(contains('Para gastar')));
      expect(text, isNot(contains('Disponible')));
    });

    testWidgets('a line only for what there is', (tester) async {
      await showCard(tester, ledgerOf(due: 0));
      final String text = screen(tester);
      expect(text, contains('En tus cuentas de uso diario'));
      expect(text, isNot(contains('Pagos hasta')));
      expect(text, isNot(contains('Lo que debes en tarjetas')));
      expect(text, isNot(contains('Colchón')));
    });

    testWidgets('a charge due on payday itself is among the payments', (
      tester,
    ) async {
      await showCard(tester, ledgerOf(dueOn: DateTime(2026, 10, 15)));
      final String text = screen(tester);
      expect(text, contains('Pagos hasta el 15 oct\n−\$26.900'));
      expect(text, contains(r'$473.100'));
    });

    testWidgets(
      'what a card owes is its own line, not taken off the accounts unsaid',
      (tester) async {
        await openPage(
          tester,
          (OwnController own) => Scaffold(
            body: SingleChildScrollView(
              child: OwnHomeTab(own: own, onSeeAll: () {}),
            ),
          ),
          data: (QuincenaStore store, Account bank, Account card) =>
              store.addEntry(
                accountId: card.id,
                amount: d('300000'),
                kind: EntryKind.expense,
                date: DateTime(2026, 10, 1, 12),
                category: 'shopping',
                payee: 'Falabella',
              ),
        );
        final String text = screen(tester);
        // 2.000.000 in the bank, 300.000 owed on the Visa.
        expect(text, contains(r'$1.700.000'));
        expect(text, contains('En tus cuentas de uso diario\n\$2.000.000'));
        expect(text, contains('Lo que debes en tarjetas\n−\$300.000'));
      },
    );

    testWidgets(
      'the pay that arrived says how much, when and where, before the '
      'envelopes',
      (tester) async {
        await openPage(
          tester,
          (OwnController own) => Scaffold(
            body: SingleChildScrollView(
              child: OwnHomeTab(own: own, onSeeAll: () {}),
            ),
          ),
          data: (QuincenaStore store, Account bank, Account card) async {
            final Account nequi = await store.addAccount(
              name: 'Nequi',
              kind: AccountKind.wallet,
              asset: Asset.cop,
              opening: Decimal.zero,
            );
            await store.addEntry(
              accountId: nequi.id,
              amount: d('400000'),
              kind: EntryKind.income,
              date: DateTime(2026, 10, 1, 9),
              category: 'salary',
              payee: 'Bono',
            );
          },
        );
        final String text = screen(tester);
        // 2.000.000 on the 30th in Bancolombia and 400.000 on the 1st in
        // Nequi: both days, and both accounts in the order the money came.
        expect(text, contains(r'Te llegó la quincena: $2.400.000'));
        expect(text, contains('Del 30 sept al 1 oct en Bancolombia y Nequi.'));
        expect(text, contains('Ponle a cada parte su sobre'));
      },
    );

    testWidgets(
      'a pay with no rate leaves the amount out rather than a short total',
      (tester) async {
        final OwnController own = await openPage(
          tester,
          (OwnController own) => Scaffold(
            body: SingleChildScrollView(
              child: OwnHomeTab(own: own, onSeeAll: () {}),
            ),
          ),
          data: (QuincenaStore store, Account bank, Account card) async {
            final Account itau = await store.addAccount(
              name: 'Itaú',
              kind: AccountKind.bank,
              asset: Asset.usd,
              opening: Decimal.zero,
            );
            await store.addEntry(
              accountId: itau.id,
              amount: d('500'),
              kind: EntryKind.income,
              date: DateTime(2026, 9, 30, 9),
              category: 'salary',
              payee: 'Cliente',
            );
          },
        );
        expect(own.payArrivals, hasLength(2));
        expect(own.payArrivedTotal, isNull);
        final String text = screen(tester);
        // The dollars have no rate: $2.000.000 would read as all of it.
        expect(text, isNot(contains('Te llegó la quincena:')));
        expect(text, contains('Te llegó la quincena'));
        // One day, two accounts, and "e" before the sound of an i.
        expect(text, contains('El 30 sept en Bancolombia e Itaú.'));
      },
    );

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
        // Every account is in pesos: no code beside the figure.
        expect(text, isNot(contains('COP')));
        // Under it, what the money to spend starts from, as on the home
        // card: the debt taken off in a line of its own.
        expect(text, contains('En tus cuentas de uso diario\n\$2.000.000'));
        expect(text, contains('Lo que debes en tarjetas\n−\$300.000'));
        expect(text, isNot(contains('Disponible')));
        expect(text, contains('CUENTAS DE USO DIARIO'));
        expect(text, contains('TARJETAS DE CRÉDITO'));
        // The card's own row says it is owed, not money of another sign.
        expect(text, contains('Debes\n\$300.000'));

        await tapText(tester, '¿De dónde sale?');
        text = screen(tester);
        expect(text, contains('Así se calcula tu patrimonio'));
        expect(text, contains('LO QUE TIENES'));
        expect(text, contains('LO QUE DEBES'));
        expect(text, contains(r'$2.000.000'));
        expect(text, contains(r'−$300.000'));
        Navigator.of(tester.element(find.text('LO QUE TIENES'))).pop();
        await settle(tester);

        // Its page says the same: what is owed, not a negative balance.
        await tapText(tester, 'Visa');
        expect(find.text('Debes'), findsOneWidget);
        expect(find.text(r'$300.000'), findsOneWidget);
        expect(find.text('Saldo hoy'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('net worth counts shared debts and instalments outside a card, '
        'estimated when a figure is missing', (tester) async {
      await openPage(
        tester,
        (OwnController own) => Scaffold(
          body: SingleChildScrollView(child: AccountsTab(own: own)),
        ),
        data: (QuincenaStore store, Account bank, Account card) async {
          await store.setSetting(
            'shared.groups',
            jsonEncode(<Object?>[
              Group(
                id: 'paseo',
                name: 'Paseo a Guatapé',
                members: const <Member>[
                  Member(id: meId, name: ''),
                  Member(id: 'laura', name: 'Laura'),
                ],
                expenses: <SharedExpense>[
                  // Laura paid the cabin; the person's part is owed.
                  SharedExpense(
                    id: 'cabana',
                    label: 'Cabaña',
                    date: DateTime(2026, 9, 20),
                    paidBy: 'laura',
                    shares: const <String, int>{meId: 170000, 'laura': 170000},
                  ),
                ],
              ).toJson(),
              Group(
                id: 'pedro',
                name: 'Pedro',
                members: const <Member>[
                  Member(id: meId, name: ''),
                  Member(id: 'pedro', name: 'Pedro'),
                ],
                expenses: <SharedExpense>[
                  // Money lent: owed to the person.
                  SharedExpense(
                    id: 'prestamo',
                    label: 'Préstamo',
                    date: DateTime(2026, 9, 25),
                    paidBy: meId,
                    shares: const <String, int>{'pedro': 50000},
                  ),
                ],
              ).toJson(),
            ]),
          );
          await store.setSetting(
            'commitments.instalments',
            jsonEncode(<Object?>[
              // Paid at a shop, the fee unknown: an estimate.
              Instalments(
                id: 'tv',
                name: 'Televisor',
                principal: 1200000,
                count: 12,
                firstDue: DateTime(2026, 11, 5),
                instalment: 100000,
              ).toJson(),
              // On the Visa: its balance already holds it.
              Instalments(
                id: 'phone',
                name: 'Celular',
                principal: 600000,
                count: 6,
                firstDue: DateTime(2026, 11, 5),
                rate: 0,
                fee: 0,
                accountId: card.id,
              ).toJson(),
            ]),
          );
        },
      );
      // 2.000.000 + 50.000 owed to the person − 170.000 owed to Laura −
      // 1.200.000 left on the TV.
      String text = screen(tester);
      expect(text, contains(r'$680.000'));

      await tapText(tester, '¿De dónde sale?');
      text = screen(tester);
      expect(text, contains('Te deben\nGastos compartidos y préstamos'));
      expect(text, contains(r'$50.000'));
      expect(
        text,
        contains('Les debes a otras personas\nGastos compartidos y préstamos'),
      );
      expect(text, contains(r'−$170.000'));
      expect(
        text,
        contains(
          'Compras a cuotas\nLo que falta pagar, fuera de tus tarjetas · '
          'estimado',
        ),
      );
      expect(text, contains(r'−$1.200.000'));
      expect(text, isNot(contains('Celular')));
      // What is had and what is owed add up to it.
      expect(text, contains('Lo que tienes\n\$2.050.000'));
      expect(text, contains('Lo que debes\n−\$1.370.000'));
      expect(text, contains('Patrimonio\n\$680.000'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a purchase in instalments with no instalment known still '
        'counts what was financed, as an estimate', (tester) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => Scaffold(
          body: SingleChildScrollView(child: AccountsTab(own: own)),
        ),
        data: (QuincenaStore store, Account bank, Account card) =>
            store.setSetting(
              'commitments.instalments',
              jsonEncode(<Object?>[
                // Neither the rate nor the instalment: no schedule to read.
                Instalments(
                  id: 'nevera',
                  name: 'Nevera',
                  principal: 900000,
                  count: 12,
                  firstDue: DateTime(2026, 11, 5),
                  payments: <(DateTime, int)>[(DateTime(2026, 10, 1), 100000)],
                ).toJson(),
              ]),
            ),
      );
      expect(own.instalments.single.remaining, isNull);
      // 2.000.000 less the 800.000 still owed of what was financed.
      expect(own.netWorth().instalments.amount, d('800000'));
      expect(own.netWorth().estimated, isTrue);
      expect(screen(tester), contains(r'$1.200.000'));

      await tapText(tester, '¿De dónde sale?');
      final String text = screen(tester);
      expect(
        text,
        contains(
          'Compras a cuotas\nLo que falta pagar, fuera de tus tarjetas · '
          'estimado',
        ),
      );
      expect(text, contains(r'−$800.000'));
    });
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
        await tapText(tester, 'Registrar transferencia');

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
