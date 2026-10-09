// The rows of Movimientos keep whole what sets a movement apart: what it
// was and where go on one line, and «Programado», the person's part of a
// shared expense and what arrived across currencies each go in a label of
// its own, which no narrow row cuts short and large text wraps.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/account_page.dart';
import 'package:quincena/ui/own/movement_list.dart';
import 'package:quincena/ui/own/movements_tab.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

/// EPM due on the 10th, crepes split with Ana and pesos sent to dollars.
Future<void> _data(QuincenaStore store, Account bank, Account card) async {
  final Account nequi = await store.addAccount(
    name: 'Nequi',
    kind: AccountKind.wallet,
    asset: Asset.cop,
    opening: Decimal.parse('100000'),
  );
  final Account dollars = await store.addAccount(
    name: 'Cuenta en dólares',
    kind: AccountKind.bank,
    asset: Asset.usd,
    opening: Decimal.zero,
  );
  await store.saveRates(<Rate>[
    Rate(
      asset: 'USD',
      quote: 'COP',
      value: Decimal.parse('3312.84'),
      asOf: DateTime(2026, 10, 3),
      source: 'trm',
    ),
  ]);
  await store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse('120000'),
    kind: EntryKind.expense,
    date: DateTime(2026, 10, 10, 12),
    category: 'utilities',
    payee: 'EPM',
  );
  final Entry crepes = await store.addEntry(
    accountId: nequi.id,
    amount: Decimal.parse('23500'),
    kind: EntryKind.expense,
    date: DateTime(2026, 10, 3, 9),
    category: 'restaurants',
    payee: 'Crepes & Waffles',
  );
  await store.addTransfer(
    fromAccountId: bank.id,
    toAccountId: dollars.id,
    sent: Decimal.parse('331300'),
    received: Decimal.parse('98.5'),
    date: DateTime(2026, 10, 1, 18),
  );
  await store.setSetting(
    'shared.groups',
    jsonEncode(<Object?>[
      Group(
        id: 'ana',
        name: 'Ana y yo',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'p-ana', name: 'Ana'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'crepes',
            label: 'Crepes',
            date: crepes.date,
            paidBy: meId,
            shares: const <String, int>{meId: 11750, 'p-ana': 11750},
            entryId: crepes.id,
          ),
        ],
      ).toJson(),
    ]),
  );
}

Widget _movements(OwnController own) => Scaffold(
  body: ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) => CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: MovementsTab(own: own),
        ),
      ],
    ),
  ),
);

/// The row of the movement titled [title].
Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(MovementRow));

/// Whether [text] shows inside the row titled [title].
bool _rowSays(String title, String text) => find
    .descendant(of: _row(title), matching: find.text(text))
    .evaluate()
    .isNotEmpty;

/// The texts on screen cut short: past their lines, or ending in an
/// ellipsis.
List<String> _cut(WidgetTester tester) => <String>[
  for (final Element e in find.byType(RichText).evaluate())
    if (e.renderObject case final RenderParagraph p
        when p.attached && p.didExceedMaxLines)
      p.text.toPlainText(),
];

/// The phone's text [scale] times its size.
void _textScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('a movement ahead says «Programado» in a label of its own, '
      'after its category and account', (tester) async {
    await openPage(tester, _movements, data: _data);
    expect(_rowSays('EPM', 'Servicios · Bancolombia'), isTrue);
    expect(_rowSays('EPM', 'Programado'), isTrue);
    expect(find.textContaining('· Programado'), findsNothing);
  });

  testWidgets('a shared expense says the person\'s part in a label', (
    tester,
  ) async {
    await openPage(tester, _movements, data: _data);
    expect(_rowSays('Crepes & Waffles', 'Restaurantes · Nequi'), isTrue);
    expect(_rowSays('Crepes & Waffles', 'Tu parte ${pesos(11750)}'), isTrue);
    expect(find.textContaining('Dividido'), findsNothing);
  });

  testWidgets('a transfer between currencies says what arrived, and in the '
      'account it arrived in, what left', (tester) async {
    await openPage(tester, _movements, data: _data);
    const String title = 'Bancolombia → Cuenta en dólares';
    expect(_rowSays(title, 'Transferencia'), isTrue);
    expect(_rowSays(title, r'Llegaron US$98,50'), isTrue);
    // A transfer within one currency has nothing else to say.
    expect(find.textContaining('Salieron'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await openPage(
      tester,
      (OwnController own) => AccountPage(
        own: own,
        accountId: own.accounts
            .firstWhere((Account a) => a.asset == Asset.usd)
            .id,
      ),
      data: _data,
    );
    await tester.scrollUntilVisible(
      find.text(title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_rowSays(title, r'Salieron $331.300'), isTrue);
  });

  testWidgets('on a narrow phone the labels stay whole, and a transfer '
      'keeps both accounts in two lines', (tester) async {
    await openPage(tester, _movements, data: _data);
    // The first iPhone SE: 320 points wide.
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    await settle(tester);
    expect(tester.takeException(), isNull);
    final List<String> cut = _cut(tester);
    for (final String whole in <String>[
      'Programado',
      'Tu parte ${pesos(11750)}',
      r'Llegaron US$98,50',
      'Bancolombia → Cuenta en dólares',
    ]) {
      expect(cut, isNot(contains(whole)), reason: whole);
      expect(find.text(whole), findsOneWidget, reason: whole);
    }
  });

  for (final double scale in <double>[2, 3.1]) {
    testWidgets('at $scale times the text size the rows wrap and nothing '
        'is cut', (tester) async {
      _textScale(tester, scale);
      await openPage(tester, _movements, data: _data);
      final ScrollableState list = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final Set<String> seen = <String>{};
      while (true) {
        expect(tester.takeException(), isNull);
        expect(_cut(tester), isEmpty);
        for (final String label in <String>[
          'Programado',
          'Tu parte ${pesos(11750)}',
          r'Llegaron US$98,50',
        ]) {
          if (find.text(label).evaluate().isNotEmpty) seen.add(label);
        }
        if (list.position.extentAfter <= 0) break;
        list.position.jumpTo(list.position.pixels + 300);
        await tester.pump();
      }
      expect(seen, hasLength(3));
    });
  }
}
