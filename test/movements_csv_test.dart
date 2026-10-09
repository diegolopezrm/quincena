// Phase 33: the movements as a CSV a spreadsheet opens, with the accents
// right in Excel, in the separators Excel expects for the language, and no
// cell that a spreadsheet would run as a formula.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/backup/movements_csv.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  final Account bank = Account(
    id: 'a-bank',
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: d('0'),
  );
  final Account savings = Account(
    id: 'a-savings',
    name: 'Ahorros; los de siempre',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: d('0'),
  );
  final Account dollars = Account(
    id: 'a-usd',
    name: 'Cuenta en dólares',
    kind: AccountKind.bank,
    asset: Asset.usd,
    opening: d('0'),
  );
  final List<Entry> entries = <Entry>[
    Entry(
      id: 'e-market',
      accountId: bank.id,
      amount: d('-45900'),
      date: DateTime(2026, 10, 3, 12),
      kind: EntryKind.expense,
      category: 'groceries',
      payee: 'Éxito Laureles',
      note: 'Mercado; de la semana',
    ),
    Entry(
      id: 'e-pay',
      accountId: bank.id,
      amount: d('2400000'),
      date: DateTime(2026, 9, 30, 8),
      kind: EntryKind.income,
      category: 'salary',
      payee: 'Nómina',
    ),
    Entry(
      id: 'e-out',
      accountId: bank.id,
      amount: d('-100000'),
      date: DateTime(2026, 10, 1, 9),
      kind: EntryKind.transfer,
      transferId: 't1',
    ),
    Entry(
      id: 'e-in',
      accountId: savings.id,
      amount: d('100000'),
      date: DateTime(2026, 10, 1, 9),
      kind: EntryKind.transfer,
      transferId: 't1',
    ),
    Entry(
      id: 'e-gym',
      accountId: dollars.id,
      amount: d('-12.5'),
      date: DateTime(2026, 10, 2, 7),
      kind: EntryKind.expense,
      category: 'c-gym',
      payee: '=HYPERLINK("http://x")',
      note: 'Dijo "gracias"',
    ),
    Entry(
      id: 'e-fix',
      accountId: bank.id,
      amount: d('-0.5'),
      date: DateTime(2026, 10, 2, 8),
      kind: EntryKind.adjustment,
    ),
  ];
  const List<CategoryItem> categories = <CategoryItem>[
    CategoryItem(key: 'c-gym', income: false, name: 'Gimnasio'),
  ];

  List<String> linesOf(AppLocalizations l) {
    final List<int> bytes = movementsCsv(
      entries: entries,
      accounts: <Account>[bank, savings, dollars],
      categories: categories,
      l: l,
    );
    // UTF-8 with its byte order mark, which Excel needs for the accents.
    expect(bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
    final String text = utf8.decode(bytes.sublist(3));
    expect(text, endsWith('\r\n'));
    expect(text.replaceAll('\r\n', ''), isNot(contains('\n')));
    return text.split('\r\n')..removeLast();
  }

  test('in Spanish, by semicolons and decimal commas, oldest first', () {
    expect(linesOf(lookupAppLocalizations(const Locale('es'))), <String>[
      'Fecha;Cuenta;Tipo;Categoría;Comercio;Nota;Monto;Moneda',
      '2026-09-30;Bancolombia;Ingreso;Salario;Nómina;;2400000;COP',
      // A transfer is a line in each of its accounts.
      '2026-10-01;Bancolombia;Transferencia;;;;-100000;COP',
      '2026-10-01;"Ahorros; los de siempre";Transferencia;;;;100000;COP',
      // A formula stays text, and quotes are doubled.
      '2026-10-02;Cuenta en dólares;Gasto;Gimnasio;'
          '"\'=HYPERLINK(""http://x"")";"Dijo ""gracias""";-12,50;USD',
      // Cents a peso amount carries are kept.
      '2026-10-02;Bancolombia;Ajuste;;;;-0,5;COP',
      '2026-10-03;Bancolombia;Gasto;Mercado;Éxito Laureles;'
          '"Mercado; de la semana";-45900;COP',
    ]);
  });

  test('in English, by commas and decimal points', () {
    expect(linesOf(lookupAppLocalizations(const Locale('en'))), <String>[
      'Date,Account,Type,Category,Merchant,Note,Amount,Currency',
      '2026-09-30,Bancolombia,Income,Salary,Nómina,,2400000,COP',
      '2026-10-01,Bancolombia,Transfer,,,,-100000,COP',
      '2026-10-01,Ahorros; los de siempre,Transfer,,,,100000,COP',
      '2026-10-02,Cuenta en dólares,Expense,Gimnasio,'
          '"\'=HYPERLINK(""http://x"")","Dijo ""gracias""",-12.50,USD',
      '2026-10-02,Bancolombia,Adjustment,,,,-0.5,COP',
      '2026-10-03,Bancolombia,Expense,Groceries,Éxito Laureles,'
          'Mercado; de la semana,-45900,COP',
    ]);
  });

  test('with no movements, only the header', () {
    final String text = utf8.decode(
      movementsCsv(
        entries: const <Entry>[],
        accounts: const <Account>[],
        categories: const <CategoryItem>[],
        l: lookupAppLocalizations(const Locale('es')),
      ).sublist(3),
    );
    expect(text, 'Fecha;Cuenta;Tipo;Categoría;Comercio;Nota;Monto;Moneda\r\n');
  });
}
