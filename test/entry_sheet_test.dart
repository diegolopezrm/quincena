import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
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

  /// The form for a new movement, opened from the floating button, over
  /// what [data] adds to the page's accounts.
  Future<OwnController> open(
    WidgetTester tester, {
    Future<void> Function(QuincenaStore store, Account bank, Account card)?
    data,
  }) async {
    late AppModeController modes;
    final OwnController own = await openPage(tester, (OwnController own) {
      modes = AppModeController(store: own.store, now: () => pageNow);
      return OwnShell(own: own, modes: modes, settings: AppSettings());
    }, data: data);
    addTearDown(modes.dispose);
    await tester.tap(find.byTooltip('Agregar movimiento'));
    await settle(tester);
    return own;
  }

  testWidgets('a category made from the form is chosen, and its dialog '
      'closes cleanly as the keyboard goes', (tester) async {
    final OwnController own = await open(tester);
    final int before = own.categories.length;
    addTearDown(tester.view.resetViewInsets);

    await tapText(tester, 'Nueva categoría');
    await tapText(tester, 'Cancelar');
    expect(own.categories, hasLength(before));

    await tapText(tester, 'Nueva categoría');
    await tapText(tester, 'Guardar');
    expect(own.categories, hasLength(before), reason: 'no name, nothing made');

    await tapText(tester, 'Nueva categoría');
    // The keyboard is up while the name is typed...
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '  Mascotas ');
    await tester.tap(find.text('Guardar').last);
    // ...and goes while the dialog closes, which builds its field again.
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await settle(tester);
    expect(tester.takeException(), isNull);

    final CategoryItem pets = own.categories.singleWhere(
      (CategoryItem c) => c.name == 'Mascotas',
    );
    expect(pets.income, isFalse);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mascotas'))
          .selected,
      isTrue,
    );
  });

  testWidgets('what saving said goes once the field is put right', (
    tester,
  ) async {
    await open(tester);
    await tapText(tester, 'Guardar');
    expect(find.text('Escribe un monto'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '12000');
    await settle(tester);
    expect(find.text('Escribe un monto'), findsNothing);

    await tapText(tester, 'Transferencia');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.text('Bancolombia').last);
    await settle(tester);
    await tapText(tester, 'Guardar');
    expect(find.text('Elige dos cuentas distintas'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.text('Visa').last);
    await settle(tester);
    expect(find.text('Elige dos cuentas distintas'), findsNothing);
  });

  testWidgets('what arrived in another currency is asked for under its own '
      'field', (tester) async {
    final OwnController own = await open(
      tester,
      data: (QuincenaStore store, _, _) async {
        await store.addAccount(
          name: 'Dólares',
          kind: AccountKind.bank,
          asset: Asset.usd,
          opening: Decimal.zero,
        );
        await store.saveRates(<Rate>[
          Rate(
            asset: 'USD',
            quote: 'COP',
            value: Decimal.fromInt(4000),
            asOf: pageNow,
            source: 'trm',
          ),
        ]);
      },
    );
    Finder under(String label, String text) => find.descendant(
      of: find.widgetWithText(TextField, label),
      matching: find.text(text),
    );
    final int before = own.snapshot!.entries.length;
    await tapText(tester, 'Transferencia');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester);
    await tester.tap(find.text('Dólares').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '400000');
    await settle(tester);
    expect(under('Llegó', '100'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Llegó'), '');
    await settle(tester);
    await tapText(tester, 'Guardar');
    expect(under('Llegó', 'Escribe un monto'), findsOneWidget);
    expect(under('Monto', 'Escribe un monto'), findsNothing);
    expect(own.snapshot!.entries, hasLength(before));

    await tester.enterText(find.widgetWithText(TextField, 'Llegó'), '98,5');
    await settle(tester);
    expect(find.text('Escribe un monto'), findsNothing);
  });
}
