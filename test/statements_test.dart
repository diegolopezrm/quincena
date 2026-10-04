import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/statements/gemini_statement.dart';
import 'package:quincena/statements/statement.dart';
import 'package:quincena/statements/statement_import.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/statements/text_statement.dart';
import 'package:quincena/statements/values.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

/// An .xlsx with one sheet, the way Excel writes it: text in the shared
/// strings, numbers and day counts in the cells.
Uint8List xlsx(List<List<Object>> rows) {
  final List<String> shared = <String>[];
  final StringBuffer sheet = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final String ref = '${String.fromCharCode(65 + c)}${r + 1}';
      final Object v = rows[r][c];
      if (v is num) {
        sheet.write('<c r="$ref"><v>$v</v></c>');
      } else {
        shared.add('$v');
        sheet.write('<c r="$ref" t="s"><v>${shared.length - 1}</v></c>');
      }
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');
  final String strings =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '${shared.map((String s) => '<si><t>$s</t></si>').join()}</sst>';
  final Archive zip = Archive()
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet.toString()))
    ..addFile(ArchiveFile.string('xl/sharedStrings.xml', strings));
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

void main() {
  group('dates', () {
    test('read as banks write them', () {
      final DateTime day = DateTime(2026, 9, 30);
      expect(parseStatementDate('30/09/2026'), day);
      expect(parseStatementDate('2026-09-30'), day);
      expect(parseStatementDate('2026/09/30 14:22:01'), day);
      expect(parseStatementDate('30-SEP-26'), day);
      expect(parseStatementDate('30 sept 2026'), day);
      expect(parseStatementDate('Sep 30, 2026'), day);
      expect(parseStatementDate('30/09', year: 2026), day);
      expect(parseStatementDate('46295', serial: true), day);
      expect(parseStatementDate('09/30/2026', order: DayOrder.monthFirst), day);
    });

    test('are not anything that looks a bit like one', () {
      expect(parseStatementDate('31/02/2026'), isNull);
      expect(parseStatementDate('Pago PSE'), isNull);
      expect(parseStatementDate('45900'), isNull);
      expect(parseStatementDate('30/09'), isNull);
    });

    test('a column with a day over twelve says how it orders them', () {
      expect(
        dayOrderOf(<String>['09/30/2026', '10/01/2026']),
        DayOrder.monthFirst,
      );
      expect(
        dayOrderOf(<String>['30/09/2026', '01/10/2026']),
        DayOrder.dayFirst,
      );
      expect(dayOrderOf(<String>['01/02/2026']), DayOrder.dayFirst);
    });
  });

  test('amounts carry the sign however the statement writes it', () {
    expect(parseSignedAmount('-45.900,00'), d('-45900'));
    expect(parseSignedAmount(r'$ 45.900'), d('45900'));
    expect(parseSignedAmount('45.900-'), d('-45900'));
    expect(parseSignedAmount('(1,250.50)'), d('-1250.5'));
    expect(parseSignedAmount('1.250.000 CR'), d('1250000'));
    expect(parseSignedAmount('45.900 DB'), d('-45900'));
    expect(parseSignedAmount('−12.000'), d('-12000'));
    expect(parseSignedAmount('Compra'), isNull);
    expect(parseSignedAmount(''), isNull);
  });

  group('tables', () {
    test('a CSV in Spanish, with semicolons and quoted text', () {
      final List<List<String>> rows = parseCsv(
        'Banco;Extracto\n'
        'FECHA;DESCRIPCIÓN;SUCURSAL;DCTO.;VALOR;SALDO\n'
        '01/09/2026;"COMPRA EN EXITO LAURELES; MEDELLIN";00;;-45.900,00;1.954.100,00\n'
        '02/09/2026;ABONO NOMINA DL SOFT;00;;2.500.000,00;4.454.100,00\n',
      );
      final StatementRead read = readTable(rows);
      expect(read.lines, <StatementLine>[
        StatementLine(
          date: DateTime(2026, 9, 1),
          description: 'COMPRA EN EXITO LAURELES; MEDELLIN',
          amount: d('-45900'),
          balance: d('1954100'),
        ),
        StatementLine(
          date: DateTime(2026, 9, 2),
          description: 'ABONO NOMINA DL SOFT',
          amount: d('2500000'),
          balance: d('4454100'),
        ),
      ]);
    });

    test('debits and credits in columns of their own', () {
      final StatementRead read = readTable(
        parseCsv(
          'Fecha,Descripción,Débito,Crédito,Saldo\n'
          '2026-09-03,Pago PSE Comcel,"89,900",,"4,364,200"\n'
          '2026-09-04,Transferencia de Ana,,"40,000","4,404,200"\n',
        ),
      );
      expect(read.lines.map((StatementLine l) => l.amount), <Decimal>[
        d('-89900'),
        d('40000'),
      ]);
    });

    test('positive amounts take their sign from the balance', () {
      final StatementRead read = readTable(
        parseCsv(
          'Fecha;Concepto;Valor;Saldo\n'
          '05/09/2026;Rappi;35.000;965.000\n'
          '04/09/2026;Consignación;500.000;1.000.000\n'
          '03/09/2026;Netflix;26.900;500.000\n',
        ),
      );
      expect(read.lines.map((StatementLine l) => l.amount), <Decimal>[
        d('-35000'),
        d('500000'),
        d('26900'),
      ]);
    });

    test('an English export with the month first', () {
      final StatementRead read = readTable(
        parseCsv(
          'Date,Description,Amount\n'
          '09/30/2026,AMAZON MKTPLACE,-25.99\n'
          '10/01/2026,PAYROLL,1500.00\n',
        ),
      );
      expect(read.lines.first.date, DateTime(2026, 9, 30));
      expect(read.lines.last.amount, d('1500'));
    });

    test('text in Latin-1, as older bank systems write it', () {
      final Uint8List bytes = Uint8List.fromList(
        latin1.encode('Fecha;Descripción;Valor\n01/09/2026;Café;-8.000\n'),
      );
      final StatementRead read = readTable(parseCsv(decodeText(bytes)));
      expect(read.lines.single.description, 'Café');
    });

    test('an Excel workbook, dates as day counts', () {
      final List<List<String>> rows = readXlsx(
        xlsx(<List<Object>>[
          <Object>['Fecha', 'Descripción', 'Valor', 'Saldo'],
          <Object>[46295, 'Compra D1', -12500, 87500],
          <Object>[46296, 'Recarga Nequi', 100000, 187500],
        ]),
      );
      final StatementRead read = readTable(rows, source: StatementSource.xlsx);
      expect(read.lines.first.date, DateTime(2026, 9, 30));
      expect(read.lines.first.description, 'Compra D1');
      expect(read.lines.last.amount, d('100000'));
    });
  });

  group('the text of a PDF', () {
    test('a savings statement with its balance', () {
      final StatementRead read = readStatementText(
        'NEQUI\nExtracto de septiembre de 2026\n'
        'Fecha  Descripción  Valor  Saldo\n'
        r'01/09/2026  Recarga desde Bancolombia  $ 200.000,00  $ 250.000,00'
        '\n'
        r'03/09/2026  Pago en D1 Laureles  $ 18.500,00  $ 231.500,00'
        '\n'
        'Total movimientos 2\n',
      );
      expect(read.institution, 'Nequi');
      expect(read.lines.map((StatementLine l) => l.amount), <Decimal>[
        d('200000'),
        d('-18500'),
      ]);
      expect(read.lines.last.description, 'Pago en D1 Laureles');
    });

    test('a card statement without years or signs', () {
      final StatementRead read = readStatementText(
        'Extracto tarjeta de crédito Bancolombia\nPeriodo 2026\n'
        '15/09  RAPPI RESTAURANTE  45.900,00\n'
        '20/09  PAGO TARJETA ABONO  500.000,00\n',
      );
      expect(read.lines.first.date, DateTime(2026, 9, 15));
      expect(read.lines.map((StatementLine l) => l.amount), <Decimal>[
        d('-45900'),
        d('500000'),
      ]);
    });

    test('a card payment is money out of a bank account', () {
      final StatementRead read = readStatementText(
        'Extracto cuenta de ahorros Bancolombia 2026\n'
        '20/09  PAGO TARJETA VISA  480.000,00\n'
        '21/09  ABONO NOMINA  2.500.000,00\n',
      );
      expect(read.lines.map((StatementLine l) => l.amount), <Decimal>[
        d('-480000'),
        d('2500000'),
      ]);
    });

    test('a reference number is not an amount', () {
      final StatementRead read = readStatementText(
        '05/09/2026  Transferencia 123456789  -50.000,00\n',
      );
      expect(read.lines.single.amount, d('-50000'));
    });
  });

  test('Gemini\'s answer is parsed, never trusted blindly', () {
    final StatementRead read = GeminiStatementReader.parseAnswer(
      jsonEncode(<String, Object?>{
        'lines': <Object?>[
          <String, Object?>{
            'date': '2026-09-02',
            'description': 'Uber',
            'amount': '-23500',
          },
          <String, Object?>{'date': 'ayer', 'description': 'x', 'amount': '1'},
          <String, Object?>{'date': '2026-09-03', 'amount': 'mucho'},
        ],
      }),
      'Davivienda',
    );
    expect(read.lines.single.amount, d('-23500'));
    expect(read.institution, 'Davivienda');
    expect(GeminiStatementReader.parseAnswer('no es JSON', '').lines, isEmpty);
  });

  test('the merchant is found inside the bank\'s words', () {
    expect(payeeOf('COMPRA EN EXITO LAURELES 1234'), 'Exito Laureles');
    expect(payeeOf('PAGO PSE COMCEL'), 'Comcel');
    expect(payeeOf('TRANSFERENCIA A ANA GOMEZ'), 'Ana Gomez');
    expect(payeeOf('NETFLIX.COM'), isNotEmpty);
  });

  group('importing', () {
    late QuincenaStore store;
    late Account bank;
    late Account card;

    setUp(() async {
      store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => DateTime(2026, 10, 2),
      );
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
      card = await store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
      );
    });

    tearDown(() => store.close());

    StatementRead statement() => readTable(
      parseCsv(
        'Fecha;Descripción;Valor\n'
        '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
        '01/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
        '02/09/2026;ABONO NOMINA;2.500.000\n'
        '03/09/2026;PAGO PSE COMCEL;-89.900\n',
      ),
    );

    test(
      'what is already in the account is found and left unchecked',
      () async {
        // Caught from the bank's notification two days before it posted.
        await store.addEntry(
          accountId: bank.id,
          amount: d('89900'),
          kind: EntryKind.expense,
          date: DateTime(2026, 9, 1, 18),
          payee: 'Comcel',
          source: 'notification',
        );
        final List<ImportCandidate> all = await StatementImporter(
          store,
        ).prepare(bank, statement());
        expect(all.map((ImportCandidate c) => c.recorded), <bool>[
          false,
          false,
          false,
          true,
        ]);
        expect(all.first.payee, 'Exito Laureles');
        expect(all.first.category, 'groceries');
        expect(all[2].category, 'salary');
        // Two purchases of the same amount the same day are two lines.
        expect(all[0].ref, isNot(all[1].ref));
      },
    );

    test('importing the same statement twice records nothing new', () async {
      final StatementImporter importer = StatementImporter(store);
      final List<ImportCandidate> first = await importer.prepare(
        bank,
        statement(),
      );
      expect(
        await importer.record(
          bank,
          first.where((ImportCandidate c) => c.proposed).toList(),
        ),
        4,
      );
      final List<ImportCandidate> again = await importer.prepare(
        bank,
        statement(),
      );
      expect(again.where((ImportCandidate c) => c.proposed), isEmpty);
      final List<Entry> entries = await store.entries(accountId: bank.id);
      expect(entries.length, 4);
      expect(entries.every((Entry e) => e.source == 'statement'), isTrue);
    });

    test('a line is recorded as what the person made it', () async {
      final StatementImporter importer = StatementImporter(store);
      final List<ImportCandidate> all = await importer.prepare(
        bank,
        statement(),
      );
      // The bank wrote a refund as a purchase.
      final ImportCandidate refund = all.first.copyWith(
        amount: d('45900'),
        kind: EntryKind.income,
        category: 'refund',
      );
      expect(refund.ref, all.first.ref);
      await importer.record(bank, <ImportCandidate>[refund]);
      final Entry saved = (await store.entries(accountId: bank.id)).single;
      expect(saved.kind, EntryKind.income);
      expect(saved.amount, d('45900'));
      expect(saved.category, 'refund');
      expect(saved.sourceRef, all.first.ref);
    });

    test('flipped signs keep each line\'s mark', () async {
      final StatementImporter importer = StatementImporter(store);
      final List<ImportCandidate> plain = await importer.prepare(
        bank,
        statement(),
      );
      final List<ImportCandidate> flipped = await importer.prepare(
        bank,
        statement(),
        flip: true,
      );
      expect(
        flipped.map((ImportCandidate c) => c.line.amount),
        plain.map((ImportCandidate c) => -c.line.amount),
      );
      expect(flipped.map((ImportCandidate c) => c.kind), <EntryKind>[
        EntryKind.income,
        EntryKind.income,
        EntryKind.expense,
        EntryKind.income,
      ]);
      expect(
        flipped.map((ImportCandidate c) => c.ref),
        plain.map((ImportCandidate c) => c.ref),
      );
    });

    group('a card payment', () {
      StatementRead bankStatement() => readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '20/09/2026;COMPRA EN EXITO LAURELES;-45.900\n'
          '24/09/2026;PAGO TARJETA VISA;-480.000\n',
        ),
      );
      StatementRead cardStatement() => readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '15/09/2026;RAPPI;45.900\n'
          '16/09/2026;NETFLIX;26.900\n'
          '25/09/2026;PAGO RECIBIDO;-480.000\n',
        ),
      );

      test(
        'is a move to the card, and the card\'s statement finds it',
        () async {
          final StatementImporter importer = StatementImporter(store);
          final List<ImportCandidate> all = await importer.prepare(
            bank,
            bankStatement(),
          );
          expect(all.first.kind, EntryKind.expense);
          final ImportCandidate payment = all.last;
          expect(payment.cardPayment, isTrue);
          expect(payment.kind, EntryKind.transfer);
          expect(payment.otherAccountId, card.id);
          expect(payment.proposed, isTrue);

          await importer.record(bank, all);
          final List<Entry> legs = <Entry>[
            for (final Entry e in await store.entries())
              if (e.isTransfer) e,
          ];
          expect(legs.length, 2);
          expect(legs.first.transferId, legs.last.transferId);
          expect(
            <(String, Decimal)>[
              for (final Entry e in legs) (e.accountId, e.amount),
            ],
            unorderedEquals(<(String, Decimal)>[
              (bank.id, d('-480000')),
              (card.id, d('480000')),
            ]),
          );
          final Map<String, Money> balances = balancesOf(
            await store.accounts(),
            await store.entries(),
            DateTime(2026, 10, 2),
          );
          // What is owed on the card went down by the payment.
          expect(balances[card.id]!.amount, d('480000'));

          // The card's statement lists the same payment: it is already
          // there, and nothing is counted twice.
          final List<ImportCandidate> onCard = await importer.prepare(
            card,
            cardStatement(),
          );
          expect(onCard.last.line.amount, d('480000'));
          expect(onCard.last.recorded, isTrue);
          expect(onCard.last.proposed, isFalse);
          await importer.record(
            card,
            onCard.where((ImportCandidate c) => c.proposed).toList(),
          );
          expect((await store.entries(accountId: card.id)).length, 3);
          // And the bank's statement again brings nothing new.
          final List<ImportCandidate> again = await importer.prepare(
            bank,
            bankStatement(),
          );
          expect(again.where((ImportCandidate c) => c.proposed), isEmpty);
        },
      );

      test('imported earlier as an expense is joined, not repeated', () async {
        // The bank's statement came in before the app knew card payments.
        await store.addEntry(
          accountId: bank.id,
          amount: d('480000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 9, 24),
          category: 'other',
          payee: 'Tarjeta Visa',
          source: 'statement',
          sourceRef:
              'statement:${bank.id}:2026-09-24|-480000|pago tarjeta visa#1',
        );
        final StatementImporter importer = StatementImporter(store);
        final List<ImportCandidate> onCard = await importer.prepare(
          card,
          cardStatement(),
        );
        final ImportCandidate payment = onCard.last;
        expect(payment.kind, EntryKind.transfer);
        expect(payment.otherAccountId, bank.id);
        expect(payment.otherLeg?.amount, d('-480000'));

        await importer.record(card, onCard);
        final List<Entry> onBank = await store.entries(accountId: bank.id);
        expect(onBank.length, 1);
        expect(onBank.single.kind, EntryKind.transfer);
        expect(onBank.single.category, isNull);
        final Entry received = (await store.entries(
          accountId: card.id,
        )).firstWhere((Entry e) => e.isTransfer);
        expect(received.amount, d('480000'));
        expect(received.transferId, onBank.single.transferId);
      });

      test('with more than one card it asks which', () async {
        final Account master = await store.addAccount(
          name: 'Mastercard',
          kind: AccountKind.card,
          asset: Asset.cop,
          institution: 'Bancolombia',
        );
        final StatementImporter importer = StatementImporter(store);
        Future<ImportCandidate> paying(String description) async =>
            (await importer.prepare(
              bank,
              readTable(
                parseCsv(
                  'Fecha;Descripción;Valor\n24/09/2026;$description;-480.000\n',
                ),
              ),
            )).single;
        final ImportCandidate unclear = await paying('PAGO TARJETA CREDITO');
        expect(unclear.cardPayment, isTrue);
        expect(unclear.kind, EntryKind.expense);
        expect(unclear.otherAccountId, isNull);
        // The card the bank's words name is the one.
        expect((await paying('PAGO TARJETA VISA')).otherAccountId, card.id);
        final ImportCandidate bancolombia = await paying('PAGO TC BANCOLOMBIA');
        expect(bancolombia.kind, EntryKind.transfer);
        expect(bancolombia.otherAccountId, master.id);
      });
    });

    test('a card statement\'s positive purchases are debt', () async {
      final StatementRead read = readTable(
        parseCsv(
          'Fecha;Descripción;Valor\n'
          '15/09/2026;RAPPI;45.900\n'
          '16/09/2026;NETFLIX;26.900\n'
          '20/09/2026;PAGO RECIBIDO;-500.000\n',
        ),
      );
      final List<ImportCandidate> all = await StatementImporter(
        store,
      ).prepare(card, read);
      expect(all.map((ImportCandidate c) => c.line.amount), <Decimal>[
        d('-45900'),
        d('-26900'),
        d('500000'),
      ]);
    });
  });
}
