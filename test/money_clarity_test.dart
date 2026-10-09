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
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/data/category.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/licenses.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/account_page.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/home_tab.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/portfolio_page.dart';
import 'package:quincena/ui/standing.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show screen, settle;
import 'page_harness.dart';
import 'portfolio_test.dart' show FakeMarket;

Decimal d(String s) => Decimal.parse(s);

/// A ledger on 3 October, paid on [schedule], with [balance] in the bank,
/// [due] to pay before payday to [merchant], and what is kept apart.
Ledger ledgerOf({
  int balance = 500000,
  int due = 26900,
  DateTime? dueOn,
  String merchant = 'Claro',
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
        merchant: merchant,
        amount: due,
        category: Category.subscriptions,
      ),
  ],
);

Future<void> showCard(
  WidgetTester tester,
  Ledger ledger, {
  bool greet = true,
  String? caveat,
}) async {
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
        body: SingleChildScrollView(
          child: StandingCard(ledger: ledger, greet: greet, caveat: caveat),
        ),
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
      // And the one that comes first, not only their total.
      expect(text, contains(r'El próximo: Claro, $26.900 el 12 oct'));
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
      expect(text, isNot(contains('El próximo')));
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

    testWidgets('the sample greets its person; someone\'s own card does not', (
      tester,
    ) async {
      await showCard(tester, ledgerOf());
      expect(screen(tester), contains('Hola, Ana'));
      await showCard(tester, ledgerOf(), greet: false);
      expect(screen(tester), isNot(contains('Hola')));
      expect(screen(tester), contains('Puedes gastar'));
    });

    testWidgets('what the figure still leaves out is said, and heard', (
      tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await showCard(
        tester,
        ledgerOf(due: 0),
        caveat: 'Provisional: faltan tus pagos fijos',
      );
      expect(screen(tester), contains('Provisional: faltan tus pagos fijos'));
      expect(
        find.bySemanticsLabel(
          'Puedes gastar \$500.000 hasta el 15 de octubre; tu quincena llega '
          'en 12 días. Provisional: faltan tus pagos fijos',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a next payment with no name is said as one, mid-sentence', (
      tester,
    ) async {
      await showCard(tester, ledgerOf(merchant: ''));
      expect(
        screen(tester),
        contains(r'El próximo: un cobro programado, $26.900 el 12 oct'),
      );
    });

    testWidgets(
      'on a phone the way to ask sits beside its label, in either language',
      (tester) async {
        // An iPhone 17 Pro, the card as wide as on the home.
        tester.view.physicalSize = const Size(402, 874) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        for (final (String lang, String label, String ask)
            in <(String, String, String)>[
              ('es', 'Puedes gastar', '¿De dónde sale?'),
              ('en', 'You can spend', 'Where does it come from?'),
            ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: quincenaTheme(Brightness.light),
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: appLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: StandingCard(
                    ledger: ledgerOf(),
                    greet: false,
                    onExplain: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final Rect said = tester.getRect(find.text(label));
          final Rect button = tester.getRect(find.text(ask));
          // On the label's line, not a line of its own under it.
          expect(button.left, greaterThan(said.right), reason: lang);
          expect(
            (button.center.dy - said.center.dy).abs(),
            lessThan(4),
            reason: lang,
          );
        }
      },
    );

    testWidgets(
      'what changes the figure comes first, and the pay to split after it',
      (tester) async {
        await openPage(
          tester,
          (OwnController own) => Scaffold(
            body: ListenableBuilder(
              listenable: own,
              builder: (BuildContext context, _) => SingleChildScrollView(
                child: OwnHomeTab(own: own, onSeeAll: () {}),
              ),
            ),
          ),
          data: (QuincenaStore store, Account bank, Account card) =>
              CaptureService(store, now: () => pageNow).ingest(<CaptureEvent>[
                CaptureEvent(
                  source: CaptureSource.notification,
                  at: pageNow,
                  app: 'com.todo1.mobile',
                  text:
                      r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES '
                      r'con tu T.Deb *1234',
                ),
              ]),
        );
        // The capture waits for review, and the salary of the 30th arrived.
        const String review = 'Revisa 1 movimiento para actualizar tu saldo';
        const String split = r'Te llegó la quincena: $2.000.000';
        expect(find.text(review), findsOneWidget);
        expect(find.text(split), findsOneWidget);
        // Rows in one panel: the first has the button, the pay to split
        // comes after it with its action in words.
        expect(find.widgetWithText(FilledButton, 'Revisar'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Repartir'), findsNothing);
        expect(find.text('Repartir'), findsOneWidget);
        expect(find.text('Después'), findsNothing);
        expect(
          tester.getTopLeft(find.text(review)).dy,
          lessThan(tester.getTopLeft(find.text(split)).dy),
        );
      },
    );

    testWidgets(
      'with no fixed payment told the home is provisional, and the first one '
      'told ends it',
      (tester) async {
        final OwnController own = await openPage(
          tester,
          (OwnController own) => Scaffold(
            body: ListenableBuilder(
              listenable: own,
              builder: (BuildContext context, _) => SingleChildScrollView(
                child: OwnHomeTab(own: own, onSeeAll: () {}),
              ),
            ),
          ),
        );
        String text = screen(tester);
        expect(own.provisional, isTrue);
        expect(text, contains('Provisional: faltan tus pagos fijos'));
        // A thing to do, after the pay that arrived and wants its envelopes.
        expect(text, contains('Agrega tus pagos fijos'));
        expect(
          text,
          contains(
            'Lo que pagues hasta el 15 oct sale de lo que puedes gastar.',
          ),
        );
        // After the pay that arrived, in the same panel.
        expect(
          tester.getTopLeft(find.textContaining('Te llegó la quincena')).dy,
          lessThan(tester.getTopLeft(find.text('Agrega tus pagos fijos')).dy),
        );

        await tester.runAsync(
          () => own.store.addRecurring(
            name: 'Arriendo',
            amount: Money(d('900000'), Asset.cop),
            cadence: Cadence.monthly,
            nextDate: DateTime(2026, 10, 5),
            accountId: own.accounts.first.id,
            category: 'housing',
          ),
        );
        await settle(tester);
        text = screen(tester);
        expect(own.provisional, isFalse);
        expect(text, isNot(contains('Provisional')));
        expect(text, isNot(contains('Agrega tus pagos fijos')));
        expect(text, contains(r'El próximo: Arriendo, $900.000 el 5 oct'));
        expect(text, contains(r'$1.100.000'));
      },
    );
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

    testWidgets(
      'what is under the net worth adds up to it: savings, what others owe '
      'and what is left of instalments are in view',
      (tester) async {
        final OwnController own = await openPage(
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
            await store.addAccount(
              name: 'Ahorros',
              kind: AccountKind.bank,
              asset: Asset.cop,
              opening: d('1000000'),
              spendable: false,
            );
            // Laura owes half of a rent paid for both.
            await store.setSetting(
              'shared.groups',
              jsonEncode(<Object?>[
                Group(
                  id: 'finca',
                  name: 'Finca',
                  members: const <Member>[
                    Member(id: meId, name: ''),
                    Member(id: 'laura', name: 'Laura'),
                  ],
                  expenses: <SharedExpense>[
                    SharedExpense(
                      id: 'arriendo',
                      label: 'Arriendo',
                      date: DateTime(2026, 10, 1),
                      paidBy: meId,
                      shares: const <String, int>{
                        meId: 150000,
                        'laura': 150000,
                      },
                    ),
                  ],
                ).toJson(),
              ]),
            );
            // A fridge in instalments, paid outside the card.
            await store.setSetting(
              'commitments.instalments',
              jsonEncode(<Object?>[
                Instalments(
                  id: 'nevera',
                  name: 'Nevera',
                  principal: 1200000,
                  count: 12,
                  firstDue: DateTime(2026, 10, 25),
                ).toJson(),
              ]),
            );
          },
        );
        final String text = screen(tester);
        expect(text, contains('En tus cuentas de uso diario\n\$2.000.000'));
        expect(text, contains('Lo que debes en tarjetas\n−\$300.000'));
        expect(text, contains('En ahorros e inversiones\n\$1.000.000'));
        expect(text, contains('Te deben\n\$150.000'));
        expect(text, contains('Compras a cuotas\n−\$1.200.000'));
        // 2.000.000 − 300.000 + 1.000.000 + 150.000 − 1.200.000.
        expect(own.netWorth().total.amount, d('1650000'));
        expect(text, contains(r'$1.650.000'));
      },
    );

    testWidgets('a card with a limit says how much of it is left, and its '
        'sheet ends on what it owes, as its page starts', (tester) async {
      await openPage(
        tester,
        (OwnController own) => Scaffold(
          body: SingleChildScrollView(child: AccountsTab(own: own)),
        ),
        data: (QuincenaStore store, Account bank, Account card) async {
          await store.updateAccount(card.copyWith(creditLimit: d('3000000')));
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
      expect(text, contains('Debes\n\$300.000\nCupo libre \$2.700.000'));
      // Borrowed money: no total counts the limit.
      expect(text, contains('En tus cuentas de uso diario\n\$2.000.000'));
      expect(text, contains('Lo que debes en tarjetas\n−\$300.000'));
      expect(text, contains(r'$1.700.000'));
      expect(text, isNot(contains(r'$4.700.000')));

      await tapText(tester, 'Visa');
      text = screen(tester);
      expect(text, contains('Cupo libre \$2.700.000 de \$3.000.000'));
      expect(find.text('Saldo hoy'), findsNothing);

      // Where the debt comes from ends on the same words as the page.
      await tester.tap(find.text('¿De dónde sale?').first);
      await settle(tester);
      Finder inSheet(String text) => find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(text),
      );
      expect(inSheet('Así se llega al saldo'), findsOneWidget);
      expect(inSheet('Debes'), findsOneWidget);
      expect(inSheet(r'$300.000'), findsOneWidget);
      expect(inSheet('Saldo hoy'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('what is left of a card\'s limit wraps at twice the text '
        'size rather than pushing the amount out', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openPage(
        tester,
        (OwnController own) => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AccountsTab(own: own),
          ),
        ),
        data: (QuincenaStore store, Account bank, Account card) async {
          await store.updateAccount(card.copyWith(creditLimit: d('12000000')));
          await store.addEntry(
            accountId: card.id,
            amount: d('1300000'),
            kind: EntryKind.expense,
            date: DateTime(2026, 10, 1, 12),
            category: 'shopping',
            payee: 'Falabella',
          );
        },
      );
      // Google Play's smallest screenshot phone, 360 by 800.
      tester.view.physicalSize = const Size(1080, 2400);
      await settle(tester);
      expect(find.text(r'Cupo libre $10.700.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a card takes its limit in its sheet, and gives it back', (
      tester,
    ) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => AccountPage(
          own: own,
          accountId: own.accounts
              .firstWhere((Account a) => a.kind == AccountKind.card)
              .id,
        ),
      );
      Account visa() =>
          own.accounts.firstWhere((Account a) => a.kind == AccountKind.card);

      await tester.tap(find.byTooltip('Editar cuenta'));
      await settle(tester);
      final Finder limit = find.widgetWithText(
        TextField,
        'Cupo total (opcional)',
      );
      expect(limit, findsOneWidget);
      expect(find.textContaining('es plata prestada'), findsOneWidget);
      await tester.enterText(limit, '3000000');
      await tapText(tester, 'Guardar');
      expect(visa().creditLimit, d('3000000'));
      expect(screen(tester), contains('Cupo libre \$3.000.000 de \$3.000.000'));

      // Emptied, the card has no limit again, and says nothing of one.
      await tester.tap(find.byTooltip('Editar cuenta'));
      await settle(tester);
      await tester.enterText(limit, '');
      await tapText(tester, 'Guardar');
      expect(visa().creditLimit, isNull);
      expect(screen(tester), isNot(contains('Cupo libre')));

      // Not a card: no limit to give.
      await tester.tap(find.byTooltip('Editar cuenta'));
      await settle(tester);
      await tapText(tester, 'Banco');
      expect(limit, findsNothing);
    });

    testWidgets('crypto has a section of its own: its total is what its rows '
        'add up to, and how it did is a row that repeats no total', (
      tester,
    ) async {
      final OwnController own = await openPage(
        tester,
        (OwnController own) => Scaffold(
          body: SingleChildScrollView(child: AccountsTab(own: own)),
        ),
        market: FakeMarket(
          prices: const <String, (String, String)>{'BTC': ('100000', '98000')},
        ),
        data: (QuincenaStore store, Account bank, Account card) async {
          await store.saveRates(<Rate>[
            Rate(
              asset: 'USD',
              quote: 'COP',
              value: d('4000'),
              asOf: DateTime(2026, 10, 3),
              source: 'trm',
            ),
            Rate(
              asset: 'BTC',
              quote: 'USDT',
              value: d('100000'),
              asOf: pageNow,
              source: 'binance',
            ),
          ]);
          await store.addAccount(
            name: 'Cuenta en dólares',
            kind: AccountKind.bank,
            asset: Asset.usd,
            opening: d('100'),
            spendable: false,
          );
          await store.addAccount(
            name: 'Binance',
            kind: AccountKind.exchange,
            asset: Asset.usdt,
            opening: d('500'),
            institution: 'Binance',
          );
          await store.addAccount(
            name: 'Bitcoin',
            kind: AccountKind.exchange,
            asset: Asset.btc,
            opening: d('0.01'),
            institution: 'Binance',
            openingCost: Money(d('3000000'), Asset.cop),
          );
        },
      );
      await tester.runAsync(own.portfolio.refresh);
      await settle(tester);
      final String text = screen(tester);
      // The dollars are savings; the coins are not among them.
      expect(text, contains('AHORROS E INVERSIONES'));
      expect(text, contains('≈ \$400.000'));
      // 500 USDT and 0,01 BTC at 100.000 dollars, at 4.000 pesos.
      expect(text, contains('CRIPTO\n\$6.000.000'));
      expect(text, contains('500 USDT\n≈ \$2.000.000'));
      expect(text, contains('0,01 BTC\n≈ \$4.000.000'));
      expect(find.text(r'$6.000.000'), findsOneWidget);
      expect(
        text,
        contains('Rendimiento y ganancia\nGanancia no realizada +33,3 %'),
      );
      // The way to add an account sits after the sections, in the list.
      expect(
        tester.getTopLeft(find.text('Agregar cuenta')).dy,
        greaterThan(tester.getTopLeft(find.text('Rendimiento y ganancia')).dy),
      );

      await tapText(tester, 'Rendimiento y ganancia');
      expect(find.byType(PortfolioPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

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
    expect(pesos(-63200), '−$signJoiner\$63.200');
    expect(pesosShort(280300000).replaceAll(' ', ' '), r'$280,3 M');
    expect(signedPercent(106.98, 100).replaceAll(' ', ' '), '+7 %');
    Intl.defaultLocale = 'en_US';
    expect(pesos(299900), r'$299,900');
    Intl.defaultLocale = 'es_CO';
  });

  test('a percentage has one format', () {
    Intl.defaultLocale = 'es_CO';
    expect(percent(27), '27\u00a0%');
    expect(percent(2121), '2.121\u00a0%');
    expect(percent(26.5, decimals: 2), '26,50\u00a0%');
    expect(percent(26.5, decimals: 2, trim: true), '26,5\u00a0%');
    expect(signedPercent(87, 100), '−13\u00a0%');
    Intl.defaultLocale = 'en_US';
    // No space in English: "27%", as the goal and the reserve say it.
    expect(percent(27), '27%');
    expect(percent(2121), '2,121%');
    expect(percent(26.5, decimals: 2, trim: true), '26.5%');
    expect(signedPercent(106.98, 100), '+7%');
    Intl.defaultLocale = 'es_CO';
  });

  test('a sign is held to the symbol after it', () {
    Intl.defaultLocale = 'es_CO';
    expect(pesos(45900, signed: true), '+$signJoiner\$45.900');
    expect(pesos(0, signed: true), r'$0');
    expect(pesosShort(-4700000), '−$signJoiner\$4,7\u00a0M');
    expect(
      formatAmount(Decimal.parse('-12.5'), Asset.usd, base: Asset.cop),
      '−${signJoiner}US\$12,50',
    );
    // A coin's digits come first: there is no symbol to hold.
    expect(formatAmount(Decimal.parse('-0.5'), Asset.btc), '−0,5\u00a0BTC');
  });

  testWidgets('a narrow line keeps a sign with its amount and an hour with '
      'its a. m.', (tester) async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    const TextStyle style = TextStyle(fontFamily: 'Geist', fontSize: 16);
    TextPainter laid(String text, [double width = double.infinity]) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      addTearDown(painter.dispose);
      return painter;
    }

    /// Whether [first] and [last] of [text] end up on the same line when
    /// the line is as wide as the wider of [head] and [tail], which each
    /// fit on one but not together.
    bool together(
      String text,
      String head,
      String tail,
      String first,
      String last,
    ) {
      final double width =
          <double>[
            laid(head).width,
            laid(tail).width,
          ].reduce((double a, double b) => a > b ? a : b) +
          1;
      final TextPainter painter = laid(text, width);
      expect(painter.computeLineMetrics(), hasLength(2));
      TextRange line(String of) =>
          painter.getLineBoundary(TextPosition(offset: text.indexOf(of)));
      return line(first) == line(last);
    }

    final String paid = 'Pagaste ${pesos(-45900)}';
    expect(together(paid, 'Pagaste −', pesos(-45900), '−', r'$'), isTrue);
    final String at = 'A las ${timeOfDay(DateTime(2026, 10, 3, 10))}';
    expect(at, endsWith('10:00\u00a0a.\u202fm.'));
    expect(together(at, 'A las 10:00', '10:00 a. m.', '10', 'm.'), isTrue);
  });
}
