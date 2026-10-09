// Plays every flow of integration_test/flows/ without a phone, as iOS, with
// a phone's safe areas and its keyboard, which comes up while a field has
// focus. Something that does not fit above the keyboard, like a dialog that
// overflows, fails the flow. An iPhone 17 Pro, or an iPhone SE:
//
//   flutter test test_screens/flows_keyboard_test.dart
//   flutter test test_screens/flows_keyboard_test.dart --dart-define=PHONE=se
//
// With FLOWS_SHOTS=1 and --update-goldens it also draws every step to
// test_screens/flows_out_<phone>/<step>.png, to see where a flow stops.
//
// Not part of `flutter test`, like the rest of this folder. The checks are
// printed but do not fail a flow: on a short screen some read rows that
// are not drawn. The keyboard does not slide in: what only goes wrong
// while it moves needs a phone.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../integration_test/flows/flow.dart';
import '../integration_test/flows/flows.dart';
import '../test/fonts.dart';

void main() {
  const String name = String.fromEnvironment('PHONE', defaultValue: 'pro');
  final _Phone phone = _phones[name]!;
  final bool shots = Platform.environment['FLOWS_SHOTS'] == '1';

  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  for (final AppFlow flow in flows) {
    testWidgets('flow ${flow.id}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      useOwnKeychain(tester);
      _keyboardFollowsFocus(tester, phone);
      late FlowRun run;
      try {
        run = await playFlow(tester, flow, (String step, String caption) async {
          if (!shots) return;
          await expectLater(
            find.byType(MaterialApp).first,
            matchesGoldenFile('flows_out_$name/$step.png'),
          );
        }, size: phone.size);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      final int held = run.checks.where((Check c) => c.ok).length;
      print(
        '${flow.id}: $held/${run.checks.length} checks'
        '${run.error == null ? '' : ', BROKE: ${run.error}'}'
        '${run.brokeAt == null ? '' : ' at ${run.brokeAt}'}',
      );
    });
  }
}

/// A phone, in points: its screen, its safe areas, and its keyboard with
/// the suggestions bar.
class _Phone {
  const _Phone(
    this.size, {
    required this.top,
    required this.bottom,
    required this.keyboard,
  });

  final Size size;
  final double top;
  final double bottom;
  final double keyboard;
}

const Map<String, _Phone> _phones = <String, _Phone>{
  'pro': _Phone(Size(402, 874), top: 62, bottom: 34, keyboard: 336),
  'se': _Phone(Size(375, 667), top: 20, bottom: 0, keyboard: 260),
};

/// Gives the view [phone]'s safe areas and raises its keyboard while a
/// field has focus, as iOS does.
void _keyboardFollowsFocus(WidgetTester tester, _Phone phone) {
  // playScene draws the phone at three pixels a point.
  FakeViewPadding points(double top, double bottom) =>
      FakeViewPadding(top: top * 3, bottom: bottom * 3);
  tester.view.padding = points(phone.top, phone.bottom);
  tester.view.viewPadding = points(phone.top, phone.bottom);
  bool up = false;
  void follow() {
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    final bool typing =
        focused?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (typing == up) return;
    up = typing;
    // After the frame: the focus can move in the middle of a build.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      tester.view.viewInsets = points(0, up ? phone.keyboard : 0);
      // The keyboard covers the bottom safe area.
      tester.view.padding = points(phone.top, up ? 0 : phone.bottom);
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  FocusManager.instance.addListener(follow);
  addTearDown(() => FocusManager.instance.removeListener(follow));
}
