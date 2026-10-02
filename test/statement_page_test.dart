import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/statements/statement.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/statement_page.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  testWidgets('a statement is reviewed line by line and imported', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final DateTime now = DateTime(2026, 10, 2, 10);
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
    late Account bank;
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
      );
      bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        institution: 'Bancolombia',
      );
      // Already caught from the bank's notification.
      await store.addEntry(
        accountId: bank.id,
        amount: Decimal.parse('89900'),
        kind: EntryKind.expense,
        date: DateTime(2026, 9, 3, 9),
        payee: 'Comcel',
      );
      await own.start();
    });
    final StatementRead read = readTable(
      parseCsv(
        'Fecha;Descripción;Valor\n'
        '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
        '02/09/2026;ABONO NOMINA DL SOFT;2.500.000\n'
        '03/09/2026;PAGO PSE COMCEL;-89.900\n',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        StatementPage(own: own, statement: read),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await settle(tester);

    // The bank the statement names is the account it goes to.
    expect(find.text('Bancolombia · COP'), findsOneWidget);
    expect(
      find.text('3 movimientos, del 1 sept 2026 al 3 sept 2026'),
      findsOneWidget,
    );
    expect(find.text('Exito Laureles'), findsOneWidget);
    expect(find.textContaining('Ya registrado'), findsOneWidget);
    expect(find.text('Importar 2 movimientos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Importar 2 movimientos'));
    await settle(tester);
    final List<Entry> entries =
        await tester.runAsync(() => store.entries(accountId: bank.id)) ??
        const <Entry>[];
    expect(entries.length, 3);
    expect(
      entries
          .where((Entry e) => e.source == 'statement')
          .map((Entry e) => e.payee),
      unorderedEquals(<String>['Exito Laureles', 'Nomina DL Soft']),
    );
    expect(find.text('Se importaron 2 movimientos.'), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }
}
