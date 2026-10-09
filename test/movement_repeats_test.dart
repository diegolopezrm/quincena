// A payment recorded twice, by its notification and again by the
// statement, is marked «¿Repetido?» in Movimientos. The mark shows both;
// «Quitar repetido» deletes the newer one, with a moment to undo it, and
// «No es repetido» is remembered, in backups and on the person's other
// devices too.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/repeats.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/merge.dart';
import 'package:quincena/ui/own/movement_list.dart';
import 'package:quincena/ui/own/movements_tab.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

/// The Éxito's 63.200 from the bank's notification, and the same payment
/// read again from the statement, split with Ana.
Future<void> _twice(QuincenaStore store, Account bank, Account card) async {
  final DateTime at = DateTime(2026, 10, 2, 9, 40);
  await store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse('63200'),
    kind: EntryKind.expense,
    date: at,
    category: 'groceries',
    payee: 'Éxito Laureles',
    source: 'notification',
  );
  final Entry statement = await store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse('63200'),
    kind: EntryKind.expense,
    date: at,
    category: 'groceries',
    payee: 'EXITO LAURELES',
    source: 'statement',
    sourceRef: 'line-7',
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
            id: 'market',
            label: 'Mercado',
            date: at,
            paidBy: meId,
            shares: const <String, int>{meId: 31600, 'p-ana': 31600},
            entryId: statement.id,
          ),
        ],
      ).toJson(),
    ]),
  );
  // Said before about two movements that are no longer there.
  await store.setSetting(
    'movements.notRepeated',
    jsonEncode(<String, String>{'gone+old': '2026-09-01'}),
  );
}

Widget _movements(OwnController own) => Scaffold(
  body: ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) =>
        CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
  ),
);

/// The «¿Repetido?» marks on screen.
Finder get _marks => find.widgetWithText(ActionChip, '¿Repetido?');

Entry _named(OwnController own, String payee) =>
    own.snapshot!.entries.firstWhere((Entry e) => e.payee == payee);

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('both records of one payment say «¿Repetido?», and the mark '
      'shows them side by side with where each came from', (tester) async {
    final OwnController own = await openPage(tester, _movements, data: _twice);
    expect(_marks, findsNWidgets(2));
    final PossibleRepeat pair = own.repeats[_named(own, 'Éxito Laureles').id]!;
    expect(pair.kept.payee, 'Éxito Laureles');
    expect(pair.repeat.payee, 'EXITO LAURELES');

    await tester.tap(_marks.first);
    await settle(tester);
    expect(find.text('¿El mismo pago dos veces?'), findsOneWidget);
    expect(
      find.text(
        'Los dos están en Bancolombia, por el mismo monto y en fechas '
        'cercanas.',
      ),
      findsOneWidget,
    );
    expect(find.text('De una notificación'), findsOneWidget);
    expect(find.text('De un extracto'), findsOneWidget);
    // The newer one is the one that would go.
    final Finder newer = find.text('El más reciente');
    expect(newer, findsOneWidget);
    expect(
      tester.getTopLeft(newer).dy,
      greaterThan(tester.getTopLeft(find.text('De un extracto')).dy),
    );
    expect(find.text('Quitar repetido'), findsOneWidget);
    expect(find.text('No es repetido'), findsOneWidget);
  });

  testWidgets('«Quitar repetido» deletes the newer one with its split, and '
      '«Deshacer» brings both back', (tester) async {
    final OwnController own = await openPage(tester, _movements, data: _twice);
    final Entry newer = _named(own, 'EXITO LAURELES');
    final int count = own.snapshot!.entries.length;
    expect(own.splitOf(newer.id), isNotNull);

    await tester.tap(_marks.first);
    await settle(tester);
    await tapText(tester, 'Quitar repetido');
    expect(find.text('¿El mismo pago dos veces?'), findsNothing);
    expect(find.text('Se quitó el repetido.'), findsOneWidget);
    expect(own.snapshot!.entries, hasLength(count - 1));
    expect(own.snapshot!.entries.any((Entry e) => e.id == newer.id), isFalse);
    expect(own.splitOf(newer.id), isNull);
    expect(_marks, findsNothing);
    expect(find.text('Éxito Laureles'), findsOneWidget);
    expect(find.text('EXITO LAURELES'), findsNothing);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    final Entry back = own.snapshot!.entries.firstWhere(
      (Entry e) => e.id == newer.id,
    );
    expect(back.source, 'statement');
    expect(back.sourceRef, 'line-7');
    expect(back.amount, newer.amount);
    expect(own.splitOf(newer.id)?.$2.shares[meId], 31600);
    expect(_marks, findsNWidgets(2));
  });

  testWidgets('«No es repetido» is remembered, travels with the movements and '
      'lets go of pairs whose movements are gone', (tester) async {
    final OwnController own = await openPage(tester, _movements, data: _twice);
    final PossibleRepeat pair = own.repeats.values.first;
    await tester.tap(_marks.first);
    await settle(tester);
    await tapText(tester, 'No es repetido');
    expect(find.text('¿El mismo pago dos veces?'), findsNothing);
    expect(_marks, findsNothing);
    expect(own.repeats, isEmpty);
    // Both stay.
    expect(find.text('Éxito Laureles'), findsOneWidget);
    expect(find.text('EXITO LAURELES'), findsOneWidget);

    final QuincenaStore store = own.store;
    final String? saved = await tester.runAsync<String?>(
      () => store.setting('movements.notRepeated'),
    );
    final Map<String, Object?> said =
        jsonDecode(saved!) as Map<String, Object?>;
    expect(said.keys, <String>[pair.key]);
    expect(said[pair.key], '2026-10-03');

    // Another start of the app does not mark them either.
    final OwnController again = OwnController(
      store,
      now: () => pageNow,
      readNative: false,
    );
    addTearDown(again.dispose);
    await tester.runAsync(again.start);
    expect(again.snapshot, isNotNull);
    expect(again.repeats, isEmpty);

    // It goes in a backup, and to other devices one pair at a time.
    final Map<String, Object?> export = (await tester.runAsync(
      store.exportJson,
    ))!;
    expect(
      (export['settings']! as Map<String, Object?>).keys,
      contains('movements.notRepeated'),
    );
    final List<SyncRecord> records = (await tester.runAsync(
      store.syncRecords,
    ))!;
    expect(
      records.where((SyncRecord r) => r.table == 'map').map((r) => r.id),
      contains('movements.notRepeated/${pair.key}'),
    );
  });

  testWidgets('a row outside the full lists, as on Inicio, carries no mark', (
    tester,
  ) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListView(
          children: <Widget>[
            for (final Entry e in own.snapshot!.entries)
              MovementRow(own: own, entry: e),
          ],
        ),
      ),
      data: _twice,
    );
    expect(own.repeats, hasLength(2));
    expect(find.byType(MovementRow), findsNWidgets(3));
    expect(_marks, findsNothing);
  });
}
