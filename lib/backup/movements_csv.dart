import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';

import '../domain/categories.dart';
import '../domain/records.dart';
import '../l10n/l10n.dart';

/// The person's movements as a table any spreadsheet opens: one line per
/// movement of an account, oldest first, with its date, account, kind,
/// category, where or who, note, signed amount and currency. A transfer
/// is a line in each of its two accounts, as each account saw it.
///
/// Written in the language of [l]. In Spanish the columns are separated by
/// semicolons and decimals by a comma, as Excel reads a file in Colombia; in
/// English, by commas and a point. Dates are `2026-10-03`, which every
/// spreadsheet reads. UTF-8 with a byte order mark, so Excel shows accents
/// right; a line ends in CR LF.
Uint8List movementsCsv({
  required List<Entry> entries,
  required List<Account> accounts,
  required List<CategoryItem> categories,
  required AppLocalizations l,
}) {
  final String language = l.localeName.startsWith('en') ? 'en' : 'es';
  final String separator = language == 'en' ? ',' : ';';
  final String point = language == 'en' ? '.' : ',';
  final Map<String, Account> byId = <String, Account>{
    for (final Account a in accounts) a.id: a,
  };
  final Map<String, String?> named = <String, String?>{
    for (final CategoryItem c in categories) c.key: c.name,
  };

  String cell(String text) {
    var value = text;
    // A cell that starts like a formula would run as one in a spreadsheet:
    // text from a bank's message or a statement is shown, never run.
    if (value.isNotEmpty && '=+-@\t\r'.contains(value[0])) value = "'$value";
    final bool quoted =
        value.contains(separator) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    return quoted ? '"${value.replaceAll('"', '""')}"' : value;
  }

  String amount(Decimal value, Account? account) {
    final int decimals = max(account?.asset.decimals ?? 2, value.scale);
    return value.toStringAsFixed(decimals).replaceAll('.', point);
  }

  String kind(EntryKind k) => switch (k) {
    EntryKind.expense => l.kindExpense,
    EntryKind.income => l.kindIncome,
    EntryKind.transfer => l.kindTransfer,
    EntryKind.adjustment => l.kindAdjustment,
  };

  String two(int n) => n.toString().padLeft(2, '0');
  String day(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  // Oldest first; the same day keeps the order the movements came in.
  final List<(int, Entry)> sorted = entries.indexed.toList()
    ..sort(((int, Entry) a, (int, Entry) b) {
      final int byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });

  final StringBuffer out = StringBuffer('﻿')
    ..write(
      <String>[
        l.csvDate,
        l.csvAccount,
        l.csvKind,
        l.csvCategory,
        l.csvPayee,
        l.csvNote,
        l.csvAmount,
        l.csvCurrency,
      ].map(cell).join(separator),
    )
    ..write('\r\n');
  for (final (_, Entry e) in sorted) {
    final Account? account = byId[e.accountId];
    final String? category = e.category;
    out
      ..write(
        <String>[
          day(e.date),
          cell(account?.name ?? ''),
          cell(kind(e.kind)),
          cell(
            category == null
                ? ''
                : categoryLabel(category, language, custom: named[category]),
          ),
          cell(e.payee),
          cell(e.note),
          amount(e.amount, account),
          account?.asset.code ?? '',
        ].join(separator),
      )
      ..write('\r\n');
  }
  return Uint8List.fromList(utf8.encode(out.toString()));
}
