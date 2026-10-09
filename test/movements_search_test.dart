// Movimientos' search and filters, as a person uses them: typing a name or
// an amount, clearing it, and narrowing the list from the funnel by type,
// dates, account, category and amount.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/look.dart';
import 'package:quincena/ui/own/movement_list.dart';
import 'package:quincena/ui/own/movements_tab.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// The pay of 30 September and, with it: the Éxito on the 2nd, a move
  /// to Nequi on the 1st, Spotify in dollars on the 2nd and a Rappi on the
  /// Visa in September.
  Future<OwnController> open(WidgetTester tester) => openPage(
    tester,
    (OwnController own) => Scaffold(
      body: ListenableBuilder(
        listenable: own,
        builder: (BuildContext context, _) =>
            CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
      ),
    ),
    data: (QuincenaStore store, Account bank, Account card) async {
      final Account nequi = await store.addAccount(
        name: 'Nequi',
        kind: AccountKind.wallet,
        asset: Asset.cop,
        opening: Decimal.zero,
      );
      final Account dollars = await store.addAccount(
        name: 'Cuenta en dólares',
        kind: AccountKind.bank,
        asset: Asset.usd,
        opening: Decimal.parse('100'),
      );
      await store.saveRates(<Rate>[
        Rate(
          asset: 'USD',
          quote: 'COP',
          value: Decimal.parse('4000'),
          asOf: DateTime(2026, 10, 3),
          source: 'trm',
        ),
      ]);
      await store.addEntry(
        accountId: bank.id,
        amount: Decimal.parse('187400'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 12),
        category: 'groceries',
        payee: 'Éxito Laureles',
      );
      await store.addTransfer(
        fromAccountId: bank.id,
        toAccountId: nequi.id,
        sent: Decimal.parse('50000'),
        date: DateTime(2026, 10, 1, 18),
      );
      await store.addEntry(
        accountId: dollars.id,
        amount: Decimal.parse('10.99'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 9),
        category: 'subscriptions',
        payee: 'Spotify',
      );
      await store.addEntry(
        accountId: card.id,
        amount: Decimal.parse('80000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 9, 20, 20),
        category: 'restaurants',
        payee: 'Rappi',
      );
    },
  );

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await settle(tester);
  }

  /// [totals] as a list says what it adds up to, one currency after the
  /// other.
  String sums(List<Money> totals) => <String>[
    for (final Money m in totals) moneyText(m, base: Asset.cop, signed: true),
  ].join(' · ');

  /// What the line over the results says: how many, and what they add up
  /// to in each currency.
  String foundLine(String count, List<Money> totals) =>
      '$count · ${sums(totals)}';

  Money cop(String amount) => Money(Decimal.parse(amount), Asset.cop);
  Money usd(String amount) => Money(Decimal.parse(amount), Asset.usd);

  /// The payees of the rows on screen.
  Set<String> rows(WidgetTester tester) => <String>{
    for (final MovementRow r in tester.widgetList<MovementRow>(
      find.byType(MovementRow),
    ))
      r.entry.payee.isEmpty ? 'transfer' : r.entry.payee,
  };

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Filtrar'));
    await settle(tester);
    expect(find.text('Filtrar movimientos'), findsOneWidget);
  }

  testWidgets('a search finds a name typed without its accents', (
    tester,
  ) async {
    await open(tester);
    for (final String typed in <String>['exito', 'ÉXITO', 'Éxito laur']) {
      await search(tester, typed);
      expect(find.text('Éxito Laureles'), findsOneWidget, reason: typed);
      expect(find.byType(MovementRow), findsOneWidget, reason: typed);
    }
    await search(tester, 'mercádo');
    expect(find.text('Éxito Laureles'), findsOneWidget);
  });

  testWidgets('a transfer is found by the account it went to', (tester) async {
    await open(tester);
    await search(tester, 'nequi');
    expect(find.text('Bancolombia → Nequi'), findsOneWidget);
    expect(find.byType(MovementRow), findsOneWidget);
    await search(tester, 'bancolombia');
    expect(find.text('Bancolombia → Nequi'), findsOneWidget);
    expect(find.text('Éxito Laureles'), findsOneWidget);
  });

  testWidgets('a search of only signs shows everything', (tester) async {
    await open(tester);
    await search(tester, r' $ ');
    expect(find.text('Nada coincide con la búsqueda.'), findsNothing);
    expect(find.text('Éxito Laureles'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ movimientos?')), findsNothing);
  });

  testWidgets('each day says what its movements add up to, in each '
      'currency, leaving out the transfers', (tester) async {
    await open(tester);
    String? totalOf(String day) {
      final Finder label = find.ancestor(
        of: find.text(day),
        matching: find.byType(SectionLabel),
      );
      final Iterable<Text> texts = tester.widgetList<Text>(
        find.descendant(of: label, matching: find.byType(Text)),
      );
      return texts.length < 2 ? null : texts.last.data;
    }

    expect(totalOf('AYER'), sums(<Money>[cop('-187400'), usd('-10.99')]));
    // Only the move to Nequi on the 1st: nothing adds up.
    expect(totalOf('JUEVES 1 DE OCTUBRE'), isNull);
    expect(
      totalOf('MIÉRCOLES 30 DE SEPTIEMBRE'),
      sums(<Money>[cop('2000000')]),
    );
  });

  testWidgets('a search finds an amount written with its points and sign or '
      'without them, and says how many it found and what they add up to', (
    tester,
  ) async {
    await open(tester);
    for (final String typed in <String>['187400', '187.400', r'$187.400']) {
      await search(tester, typed);
      expect(rows(tester), <String>{'Éxito Laureles'}, reason: typed);
      expect(
        find.text(foundLine('1 movimiento', <Money>[cop('-187400')])),
        findsOneWidget,
        reason: typed,
      );
    }
    // Dollars as the row writes them.
    await search(tester, r'US$10,99');
    expect(rows(tester), <String>{'Spotify'});
    expect(
      find.text(foundLine('1 movimiento', <Money>[usd('-10.99')])),
      findsOneWidget,
    );
  });

  testWidgets('the x clears the search and brings everything back', (
    tester,
  ) async {
    await open(tester);
    expect(find.byTooltip('Borrar la búsqueda'), findsNothing);
    await search(tester, 'zapatos rojos');
    expect(find.text('Nada coincide con la búsqueda.'), findsOneWidget);
    await tester.tap(find.byTooltip('Borrar la búsqueda'));
    await settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.byTooltip('Borrar la búsqueda'), findsNothing);
    expect(rows(tester), <String>{
      'Éxito Laureles',
      'Spotify',
      'transfer',
      'Nómina',
      'Rappi',
    });
  });

  testWidgets('the funnel opens the filters, which apply as they are picked, '
      'stay in sight as chips and go one by one', (tester) async {
    await open(tester);
    await openFilters(tester);
    expect(find.text('Ver 5 movimientos'), findsOneWidget);
    await tapText(tester, 'Gastos');
    expect(find.text('Ver 3 movimientos'), findsOneWidget);
    await tapText(tester, 'Este mes');
    expect(find.text('Ver 2 movimientos'), findsOneWidget);
    await tapText(tester, 'Ver 2 movimientos');

    expect(find.text('Filtrar movimientos'), findsNothing);
    expect(rows(tester), <String>{'Éxito Laureles', 'Spotify'});
    expect(
      find.text(
        foundLine('2 movimientos', <Money>[cop('-187400'), usd('-10.99')]),
      ),
      findsOneWidget,
    );
    // What narrows the list, under the search.
    expect(find.widgetWithText(ActionChip, 'Gastos'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Este mes'), findsOneWidget);

    // A chip takes its part away: the move to Nequi is back, and the total
    // says it leaves it out.
    await tester.tap(find.widgetWithText(ActionChip, 'Gastos'));
    await settle(tester);
    expect(rows(tester), <String>{'Éxito Laureles', 'Spotify', 'transfer'});
    expect(
      find.text(
        foundLine('3 movimientos', <Money>[cop('-187400'), usd('-10.99')]),
      ),
      findsOneWidget,
    );
    expect(
      find.text('El total deja fuera las transferencias entre tus cuentas.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Este mes'));
    await settle(tester);
    expect(find.byType(ActionChip), findsNothing);
    expect(rows(tester), hasLength(5));
    expect(find.textContaining('movimientos ·'), findsNothing);
  });

  testWidgets('accounts, categories and amounts narrow together with the '
      'search, and «Quitar filtros» lets go of all of it', (tester) async {
    await open(tester);
    await openFilters(tester);
    // Only the accounts that have movements.
    expect(find.widgetWithText(FilterChip, 'Visa'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Nequi'), findsOneWidget);
    await tapText(tester, 'Nequi');
    // The move to Nequi, by the end where it arrived.
    expect(find.text('Ver 1 movimiento'), findsOneWidget);
    await tapText(tester, 'Bancolombia');
    expect(find.text('Ver 3 movimientos'), findsOneWidget);
    await tapText(tester, 'Mercado');
    expect(find.text('Ver 1 movimiento'), findsOneWidget);
    await tapText(tester, 'Mercado');
    await tester.enterText(find.widgetWithText(TextField, 'Desde'), '100000');
    await settle(tester);
    expect(find.text('Ver 2 movimientos'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Hasta'), '1000000');
    await settle(tester);
    expect(find.text('Ver 1 movimiento'), findsOneWidget);
    await tapText(tester, 'Ver 1 movimiento');
    expect(rows(tester), <String>{'Éxito Laureles'});
    expect(
      find.widgetWithText(ActionChip, '${pesos(100000)} a ${pesos(1000000)}'),
      findsOneWidget,
    );

    // The search narrows what the filters leave.
    await search(tester, 'uber');
    expect(
      find.text('Nada coincide con la búsqueda y los filtros.'),
      findsOneWidget,
    );
    await search(tester, '');

    await openFilters(tester);
    await tapText(tester, 'Quitar filtros');
    expect(find.text('Ver 5 movimientos'), findsOneWidget);
    expect(
      tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .where((FilterChip c) => c.selected),
      isEmpty,
    );
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Desde')),
      isA<TextField>().having(
        (TextField f) => f.controller!.text,
        'text',
        isEmpty,
      ),
    );
    await tapText(tester, 'Ver 5 movimientos');
    expect(find.byType(ActionChip), findsNothing);
    expect(rows(tester), hasLength(5));
  });

  testWidgets('days picked in the calendar narrow the list to them', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);
    await openFilters(tester);
    await tapText(tester, 'Elegir fechas');
    for (final int day in <int>[1, 2]) {
      await tester.tap(
        find.bySemanticsLabel(
          RegExp('(^|\\s)$day, [^,]+, $day de octubre de 2026'),
        ),
      );
      await settle(tester);
    }
    await tester.tap(
      find.byWidgetPredicate(
        (Widget w) => w is Text && (w.data == 'Guardar' || w.data == 'GUARDAR'),
      ),
    );
    await settle(tester);
    expect(find.widgetWithText(ChoiceChip, '1–2 oct 2026'), findsOneWidget);
    expect(find.text('Ver 3 movimientos'), findsOneWidget);
    await tapText(tester, 'Ver 3 movimientos');
    expect(rows(tester), <String>{'Éxito Laureles', 'Spotify', 'transfer'});
    expect(find.widgetWithText(ActionChip, '1–2 oct 2026'), findsOneWidget);

    // Another choice of days lets go of the days picked.
    await openFilters(tester);
    await tapText(tester, 'Mes pasado');
    expect(find.widgetWithText(ChoiceChip, 'Elegir fechas'), findsOneWidget);
    expect(find.text('Ver 2 movimientos'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('filters that leave nothing say so, and the funnel says how '
      'many are on', (tester) async {
    await open(tester);
    await openFilters(tester);
    await tapText(tester, 'Ingresos');
    await tapText(tester, 'Restaurantes');
    await tapText(tester, 'Ver 0 movimientos');
    expect(find.text('Nada coincide con los filtros.'), findsOneWidget);
    expect(find.byType(MovementRow), findsNothing);
    // Two parts on, said on the funnel.
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('2')),
      findsOneWidget,
    );
  });
}
