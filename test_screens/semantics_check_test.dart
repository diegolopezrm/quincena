// Plays the flows a reviewer starts with, «Empieza aquí», without a phone,
// as iOS, and at every step reads the screen the way VoiceOver and
// TalkBack do: it fails on a control that announces no name, and on two
// controls of one screen that announce the same one, which a person who
// cannot see the screen cannot tell apart. One flow at a time:
//
//   flutter test test_screens/semantics_check_test.dart --plain-name "07-01"
//
// Not part of `flutter test`, like the rest of this folder. With
// SEMANTICS_OUT set to a folder, it also leaves there what each step
// announced, in order, as JSON.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../integration_test/flows/flow.dart';
import '../integration_test/flows/flows.dart';
import '../test/fonts.dart';

/// The flows marked «Empieza aquí» on the review page, in its order.
const List<String> startHere = <String>[
  '01-01',
  '01-02',
  '11-15',
  '02-01',
  '02-02',
  '02-03',
  '02-05',
  '03-01',
  '03-07',
  '03-16',
  '04-01',
  '05-01',
  '06-02',
  '06-03',
  '06-10',
  '06-13',
  '07-01',
  '07-03',
  '07-10',
  '08-01',
  '12-01',
  '09-01',
];

/// Names two controls of a screen may share because both do the same: the
/// note on what Gemini sees opens from the bar and from under the questions.
const Set<String> sameAction = <String>{'Qué ve Gemini'};

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  final String? out = Platform.environment['SEMANTICS_OUT'];

  for (final String id in startHere) {
    final AppFlow flow = flows.firstWhere((AppFlow f) => f.id.startsWith(id));
    testWidgets('semantics ${flow.id}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final SemanticsHandle handle = tester.ensureSemantics();
      useOwnKeychain(tester);
      final Map<String, List<GenUiSemanticNode>> read =
          <String, List<GenUiSemanticNode>>{};
      late FlowRun run;
      try {
        run = await playFlow(tester, flow, (String name, String _) async {
          read[name] = genUiRenderedSemantics();
        }, size: const Size(402, 874));
      } finally {
        handle.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
      final List<GenUiAuditFinding> findings = <GenUiAuditFinding>[
        for (final GenUiAuditFinding f in genUiSemanticsAudit(read))
          if (f.rule != GenUiAuditRule.ambiguousControls ||
              !sameAction.contains(f.detail))
            f,
      ];
      print(
        '${flow.id}: ${read.length} steps, '
        '${findings.length} findings',
      );
      for (final GenUiAuditFinding f in findings) {
        print('  $f');
      }
      if (out != null) {
        Directory(out).createSync(recursive: true);
        File('$out/${flow.id}.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            for (final MapEntry<String, List<GenUiSemanticNode>> step
                in read.entries)
              step.key: <Object?>[
                for (final GenUiSemanticNode node in step.value) node.toJson(),
              ],
          }),
        );
      }
      expect(run.error, isNull, reason: 'the flow broke on the way');
      expect(findings.map((GenUiAuditFinding f) => '$f'), isEmpty);
    });
  }
}
