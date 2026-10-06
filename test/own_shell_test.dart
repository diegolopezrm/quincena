import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/own_shell.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('each tab keeps its own place in the list', (tester) async {
    late AppModeController modes;
    await openPage(
      tester,
      (OwnController own) {
        modes = AppModeController(store: own.store, now: () => pageNow);
        return OwnShell(own: own, modes: modes, settings: AppSettings());
      },
      data: (QuincenaStore store, Account bank, _) async {
        for (var i = 0; i < 60; i++) {
          await store.addEntry(
            accountId: bank.id,
            amount: Decimal.fromInt(10000 + i),
            kind: EntryKind.expense,
            date: pageNow.subtract(Duration(hours: 9 * i)),
            category: 'groceries',
            payee: 'Mercado $i',
          );
        }
      },
    );
    addTearDown(modes.dispose);
    ScrollPosition position() =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    await tester.tap(find.text('Movimientos'));
    await settle(tester);
    position().jumpTo(2000);
    await settle(tester);

    // Inicio opens at its top, not as far down as Movimientos was.
    await tester.tap(find.text('Inicio'));
    await settle(tester);
    expect(position().pixels, 0);

    // And Movimientos is where it was left.
    await tester.tap(find.text('Movimientos'));
    await settle(tester);
    expect(position().pixels, 2000);
  });
}
