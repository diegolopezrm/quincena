import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:decimal/decimal.dart';
import 'package:xml/xml.dart';

import '../capture/merchants.dart';
import 'statement.dart';
import 'values.dart';

/// The text of a file a bank exported: UTF-8 when it is, Latin-1 otherwise,
/// as older bank systems in Colombia still write.
String decodeText(Uint8List bytes) {
  var data = bytes;
  // A UTF-8 byte order mark.
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = data.sublist(3);
  }
  try {
    return utf8.decode(data);
  } on FormatException {
    return latin1.decode(data);
  }
}

/// The rows of a CSV file, whatever it separates values with: a comma, a
/// semicolon (Excel in Spanish) or a tab.
List<List<String>> parseCsv(String text) {
  final List<String> sample = text
      .split(RegExp(r'\r?\n'))
      .where((String l) => l.trim().isNotEmpty)
      .take(20)
      .toList();
  int count(String c) =>
      sample.fold(0, (int n, String l) => n + c.allMatches(l).length);
  final String sep = <String>[
    ';',
    '\t',
    ',',
    '|',
  ].reduce((String best, String c) => count(c) > count(best) ? c : best);

  final List<List<String>> rows = <List<String>>[];
  List<String> row = <String>[];
  final StringBuffer cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final String c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == sep) {
      row.add(cell.toString().trim());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString().trim());
      cell.clear();
      if (row.any((String v) => v.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  row.add(cell.toString().trim());
  if (row.any((String v) => v.isNotEmpty)) rows.add(row);
  return rows;
}

/// The rows of the first sheet of an Excel workbook (.xlsx), every cell as
/// text. A date stored as a day count stays a number: [readTable] knows a
/// date column when it sees one.
List<List<String>> readXlsx(Uint8List bytes) {
  final Archive zip = ZipDecoder().decodeBytes(bytes);
  String? read(String name) {
    final ArchiveFile? f = zip.findFile(name);
    return f == null ? null : utf8.decode(f.content);
  }

  final List<String> shared = <String>[];
  final String? strings = read('xl/sharedStrings.xml');
  if (strings != null) {
    for (final XmlElement si in XmlDocument.parse(
      strings,
    ).findAllElements('si')) {
      shared.add(
        si.findAllElements('t').map((XmlElement t) => t.innerText).join(),
      );
    }
  }

  // The first sheet in the workbook's order, not the first file in the zip.
  var sheetPath = 'xl/worksheets/sheet1.xml';
  final String? workbook = read('xl/workbook.xml');
  final String? rels = read('xl/_rels/workbook.xml.rels');
  if (workbook != null && rels != null) {
    final XmlElement? first = XmlDocument.parse(
      workbook,
    ).findAllElements('sheet').firstOrNull;
    final String? id = first?.attributes
        .where((XmlAttribute a) => a.name.local == 'id')
        .firstOrNull
        ?.value;
    for (final XmlElement r in XmlDocument.parse(
      rels,
    ).findAllElements('Relationship')) {
      if (r.getAttribute('Id') == id) {
        final String target = r.getAttribute('Target') ?? '';
        sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/$target';
      }
    }
  }
  final String? sheet = read(sheetPath);
  if (sheet == null) return const <List<String>>[];

  final List<List<String>> rows = <List<String>>[];
  for (final XmlElement r in XmlDocument.parse(sheet).findAllElements('row')) {
    final Map<int, String> cells = <int, String>{};
    for (final XmlElement c in r.findElements('c')) {
      final int column = _column(c.getAttribute('r') ?? '');
      final String type = c.getAttribute('t') ?? 'n';
      final String raw = c.getElement('v')?.innerText ?? '';
      final String value;
      if (type == 's') {
        final int? i = int.tryParse(raw);
        value = i != null && i < shared.length ? shared[i] : raw;
      } else if (type == 'inlineStr') {
        value = c
            .findAllElements('t')
            .map((XmlElement t) => t.innerText)
            .join();
      } else {
        value = raw;
      }
      cells[column < 0 ? cells.length : column] = value.trim();
    }
    if (cells.isEmpty) continue;
    final int width = cells.keys.reduce((int a, int b) => a > b ? a : b) + 1;
    final List<String> row = <String>[
      for (var i = 0; i < width; i++) cells[i] ?? '',
    ];
    if (row.any((String v) => v.isNotEmpty)) rows.add(row);
  }
  return rows;
}

/// The zero-based column of a cell reference such as `C12`.
int _column(String ref) {
  var n = 0;
  var any = false;
  for (final int unit in ref.toUpperCase().codeUnits) {
    if (unit < 65 || unit > 90) break;
    n = n * 26 + (unit - 64);
    any = true;
  }
  return any ? n - 1 : -1;
}

/// What a statement's columns hold.
class _Layout {
  int header = -1;
  int date = -1;
  int description = -1;
  int amount = -1;
  int debit = -1;
  int credit = -1;
  int balance = -1;
  int kind = -1;

  bool get usable => date >= 0 && (amount >= 0 || debit >= 0 || credit >= 0);
}

const List<String> _dateWords = <String>['fecha', 'date', 'posted', 'dia'];
const List<String> _descriptionWords = <String>[
  'descripcion',
  'concepto',
  'detalle',
  'movimiento',
  'transaccion',
  'establecimiento',
  'comercio',
  'description',
  'details',
  'memo',
  'payee',
  'narrative',
];
const List<String> _amountWords = <String>[
  'valor',
  'monto',
  'importe',
  'amount',
  'total',
];
const List<String> _debitWords = <String>[
  'debito',
  'debitos',
  'cargo',
  'cargos',
  'retiro',
  'retiros',
  'salida',
  'salidas',
  'egreso',
  'egresos',
  'debit',
  'withdrawal',
  'withdrawals',
];
const List<String> _creditWords = <String>[
  'credito',
  'creditos',
  'abono',
  'abonos',
  'deposito',
  'depositos',
  'consignacion',
  'consignaciones',
  'entrada',
  'entradas',
  'ingreso',
  'ingresos',
  'credit',
  'deposit',
  'deposits',
];
const List<String> _balanceWords = <String>['saldo', 'balance'];
const List<String> _kindWords = <String>[
  'tipo',
  'naturaleza',
  'type',
  'd/c',
  'db/cr',
];

bool _has(String header, List<String> words) {
  final List<String> parts = normalize(header).split(' ');
  return words.any(
    (String w) => w.contains(' ')
        ? normalize(header).contains(w)
        : parts.contains(w) || normalize(header) == w,
  );
}

_Layout _layout(List<List<String>> rows) {
  for (var r = 0; r < rows.length && r < 40; r++) {
    final _Layout l = _Layout()..header = r;
    final List<String> row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final String h = row[c];
      if (h.isEmpty) continue;
      // The balance first: "saldo" columns also say "valor" sometimes.
      if (l.balance < 0 && _has(h, _balanceWords)) {
        l.balance = c;
      } else if (l.date < 0 && _has(h, _dateWords)) {
        l.date = c;
      } else if (l.debit < 0 && _has(h, _debitWords)) {
        l.debit = c;
      } else if (l.credit < 0 && _has(h, _creditWords)) {
        l.credit = c;
      } else if (l.amount < 0 && _has(h, _amountWords)) {
        l.amount = c;
      } else if (l.description < 0 && _has(h, _descriptionWords)) {
        l.description = c;
      } else if (l.kind < 0 && _has(h, _kindWords)) {
        l.kind = c;
      }
    }
    if (l.usable) return l;
  }
  return _guess(rows);
}

/// A statement with no header row: the column that holds dates, the one
/// that holds amounts, and the longest text.
_Layout _guess(List<List<String>> rows) {
  final _Layout l = _Layout();
  final int width = rows.fold(
    0,
    (int w, List<String> r) => r.length > w ? r.length : w,
  );
  double share(int c, bool Function(String) test) {
    var yes = 0;
    var all = 0;
    for (final List<String> r in rows) {
      if (c >= r.length || r[c].isEmpty) continue;
      all++;
      if (test(r[c])) yes++;
    }
    return all == 0 ? 0 : yes / all;
  }

  var longest = 0.0;
  for (var c = 0; c < width; c++) {
    if (l.date < 0 &&
        share(c, (String v) => parseStatementDate(v, year: 2000) != null) >
            0.6) {
      l.date = c;
    } else if (share(c, (String v) => parseSignedAmount(v) != null) > 0.6) {
      if (l.amount < 0) {
        l.amount = c;
      } else if (l.balance < 0) {
        l.balance = c;
      }
    } else {
      final double avg =
          rows.fold(
            0,
            (int s, List<String> r) => s + (c < r.length ? r[c].length : 0),
          ) /
          rows.length;
      if (avg > longest) {
        longest = avg;
        l.description = c;
      }
    }
  }
  return l;
}

/// The movements in a table a bank exported.
///
/// The header row is found by its words, in Spanish or in English: the
/// date, the description, and the amount as one signed column or as a
/// debit and a credit column. A positive amount with a balance beside it
/// takes its sign from how the balance moved.
StatementRead readTable(
  List<List<String>> rows, {
  StatementSource source = StatementSource.csv,
  int? year,
}) {
  const List<StatementLine> none = <StatementLine>[];
  if (rows.isEmpty) return StatementRead(lines: none, source: source);
  final _Layout l = _layout(rows);
  if (!l.usable) return StatementRead(lines: none, source: source);

  String cell(List<String> row, int c) =>
      c >= 0 && c < row.length ? row[c] : '';
  final List<List<String>> body = rows.sublist(l.header + 1);
  final DayOrder order = dayOrderOf(<String>[
    for (final List<String> r in body) cell(r, l.date),
  ]);

  final List<StatementLine> lines = <StatementLine>[];
  for (final List<String> r in body) {
    final DateTime? date = parseStatementDate(
      cell(r, l.date),
      order: order,
      year: year,
      serial: source == StatementSource.xlsx,
    );
    if (date == null) continue;
    Decimal? amount;
    if (l.debit >= 0 || l.credit >= 0) {
      final Decimal? out = parseSignedAmount(cell(r, l.debit));
      final Decimal? into = parseSignedAmount(cell(r, l.credit));
      if (out != null && out != Decimal.zero) {
        amount = -out.abs();
      } else if (into != null && into != Decimal.zero) {
        amount = into.abs();
      }
    }
    amount ??= parseSignedAmount(cell(r, l.amount));
    if (amount == null || amount == Decimal.zero) continue;
    final String kind = normalize(cell(r, l.kind));
    if (kind.isNotEmpty) {
      final bool out =
          kind.startsWith('d') ||
          kind.contains('cargo') ||
          kind.contains('retiro');
      final bool into = kind.startsWith('c') || kind.contains('abono');
      if (out) amount = -amount.abs();
      if (into && !out) amount = amount.abs();
    }
    final List<String> words = <String>[
      if (l.description >= 0) cell(r, l.description),
    ];
    if (words.join().trim().isEmpty) {
      // No description column: whatever text the row has.
      words.addAll(<String>[
        for (var c = 0; c < r.length; c++)
          if (c != l.date &&
              c != l.amount &&
              c != l.debit &&
              c != l.credit &&
              c != l.balance &&
              parseSignedAmount(r[c]) == null)
            r[c],
      ]);
    }
    lines.add(
      StatementLine(
        date: date,
        description: words
            .where((String w) => w.trim().isNotEmpty)
            .join(' ')
            .trim(),
        amount: amount,
        balance: l.balance >= 0 ? parseSignedAmount(cell(r, l.balance)) : null,
      ),
    );
  }
  return StatementRead(lines: signFromBalance(lines), source: source);
}

/// [lines] with the signs their balances show, when every amount came
/// positive: a statement that lists payments and deposits alike as
/// positive numbers, with the balance after each.
List<StatementLine> signFromBalance(List<StatementLine> lines) {
  if (lines.length < 2 ||
      lines.any((StatementLine l) => l.amount < Decimal.zero) ||
      lines.any((StatementLine l) => l.balance == null)) {
    return lines;
  }
  // Oldest first or newest first: whichever the balances agree with.
  int fits(List<StatementLine> ordered) {
    var n = 0;
    for (var i = 1; i < ordered.length; i++) {
      final Decimal moved = ordered[i].balance! - ordered[i - 1].balance!;
      if (moved.abs() == ordered[i].amount.abs()) n++;
    }
    return n;
  }

  final List<StatementLine> reversed = lines.reversed.toList();
  final bool newestFirst = fits(reversed) > fits(lines);
  final List<StatementLine> ordered = newestFirst ? reversed : lines;
  if (fits(ordered) == 0) return lines;
  final List<StatementLine> out = <StatementLine>[ordered.first];
  for (var i = 1; i < ordered.length; i++) {
    final StatementLine l = ordered[i];
    final Decimal moved = l.balance! - ordered[i - 1].balance!;
    out.add(
      moved.abs() == l.amount.abs() && moved < Decimal.zero
          ? StatementLine(
              date: l.date,
              description: l.description,
              amount: -l.amount.abs(),
              balance: l.balance,
            )
          : l,
    );
  }
  return newestFirst ? out.reversed.toList() : out;
}
