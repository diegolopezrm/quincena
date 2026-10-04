// Keeps the English interface in the words of the glossary: the literal
// translations from Spanish it once had do not come back.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words the English interface never uses, with the one it says instead.
final Map<RegExp, String> _banned = <RegExp, String>{
  RegExp(r'\bmovements?\b', caseSensitive: false): 'transaction',
  RegExp(r'\bfortnights?\b', caseSensitive: false): 'pay period, paycheck',
  // The old name of the inbox. "Changes to review" is plain English.
  RegExp(r'\bTo review\b'): 'Needs review',
  RegExp(r'\bfree until\b', caseSensitive: false): 'you can spend … until',
  RegExp(r'\bworked out\b', caseSensitive: false): 'calculated',
  RegExp(r'\binstalments?\b', caseSensitive: false): 'installment',
  RegExp(r'\bmetres\b', caseSensitive: false): 'meters',
  RegExp(r'\bcushions?\b', caseSensitive: false): 'safety buffer',
};

/// What a person reads in [message]: placeholders' names and the keywords
/// of a plural or select are code, not words.
String _readable(String message) => message
    .replaceAll(RegExp(r'\{\w+(?=[,}])'), '{')
    .replaceAll(RegExp(r'(?:=\d+|\w+)\{'), '{');

/// Every English message by key, without the metadata.
Map<String, String> _english() {
  final Map<String, Object?> arb =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, Object?>;
  return <String, String>{
    for (final MapEntry<String, Object?> e in arb.entries)
      if (!e.key.startsWith('@')) e.key: e.value! as String,
  };
}

/// The messages that use a banned word, as `key: "word" (say …)`.
List<String> _offenders(Map<String, String> messages) => <String>[
  for (final MapEntry<String, String> m in messages.entries)
    for (final MapEntry<RegExp, String> ban in _banned.entries)
      for (final RegExpMatch hit in ban.key.allMatches(_readable(m.value)))
        '${m.key}: "${hit[0]}" (say ${ban.value})',
];

void main() {
  test('the English interface keeps to its glossary', () {
    expect(_offenders(_english()), isEmpty);
  });

  test('the check finds each word, whole and in any case', () {
    expect(
      _offenders(<String, String>{
        'a': 'Search movements',
        'b': 'Fortnight close',
        'c': 'It is in To review.',
        'd': 'You have {amount} free until payday',
        'e': 'How it was worked out',
        'f': 'Instalment {number}',
        'g': 'A few metres away',
        'h': 'Under your Cushion',
      }),
      hasLength(8),
    );
    // Part of a longer word, or the inbox's own words, are fine.
    expect(
      _offenders(<String, String>{
        'a': 'Installments and recurring payments',
        'b': '{count} transactions to review',
        'c': 'Changes to review',
      }),
      isEmpty,
    );
  });

  test('placeholder names and plural keywords are not words', () {
    expect(
      _offenders(<String, String>{
        'a': 'Done: {movements, plural, =1{one new} other{{movements} new}}.',
        'b': 'Nearby: {name}, {metres} m away',
        'c': '{kind, select, fortnight{How much?} other{How much?}}',
      }),
      isEmpty,
    );
  });
}
