// Writes the system prompt as the app sends it, by part, so its size can
// be counted against the model's own tokenizer, `countTokens`:
//
//   flutter test tool/prompt
//
// On 3 October 2026 it was 11,822 tokens; with genui's indented schemas it
// was 19,080. Not part of `flutter test`: it measures, it checks nothing.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/prompt.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/agent/catalog.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  test('the prompt, by part', () {
    final String prompt = quincenaPrompt(quincenaCatalog, demoLedger());
    final Directory out = Directory('tool/prompt/out')
      ..createSync(recursive: true);
    File('${out.path}/prompt.txt').writeAsStringSync(prompt);
    final RegExp fenced = RegExp(
      r'-----([A-Z_]+)_START-----\n([\s\S]*?)\n-----\1_END-----',
    );
    var rest = prompt;
    for (final RegExpMatch m in fenced.allMatches(prompt)) {
      final String name = m.group(1)!;
      final String body = m.group(2)!;
      final Object? json;
      try {
        json = jsonDecode(body);
      } on FormatException {
        continue;
      }
      // The app sends them on one line already: this says it still does.
      final String compact = jsonEncode(json);
      print(
        '$name: ${body.length} characters'
        '${compact.length == body.length ? '' : ', ${compact.length} compact'}',
      );
      File('${out.path}/${name.toLowerCase()}.json').writeAsStringSync(body);
      rest = rest.replaceFirst(m.group(0)!, '');
    }
    File('${out.path}/instructions.txt').writeAsStringSync(rest);
    print('Instructions: ${rest.length} characters');
    print('Whole: ${prompt.length} characters');
  });
}
