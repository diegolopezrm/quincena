// One thing a person does in the app, step by step: a picture of every
// step with a line that says what was done and what to look at, and checks
// of what each step changed underneath.
//
// The flows live in integration_test/flows/, one file per part of the app,
// and are listed together in flows.dart. They play on a simulator through
// integration_test/flows_test.dart (tool/flows/run.sh takes the pictures
// and puts each flow's together in one image), and without a phone through
// test_screens/flows_check_test.dart, which runs every check.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';

import '../../test/own_flow_test.dart' show settle;
import '../tour.dart';

/// Takes the picture of what is on screen now, under [name], with the line
/// that goes under it.
typedef StepShot = Future<void> Function(String name, String caption);

/// Something a person sets out to do, from a fresh start on an account.
class AppFlow {
  const AppFlow(
    this.id,
    this.title,
    this.play, {
    required this.area,
    required this.goal,
    this.data,
    this.dark = false,
    this.english = false,
    this.demo = false,
    this.manual = const <String>[],
  });

  /// Orders the flows and names their pictures: the part of the app, then
  /// the flow, as in '04-03-agregar-tarjeta'.
  final String id;

  /// The part of the app, as the person calls it: 'Cuentas'.
  final String area;

  /// What the flow is, in a few words: 'Agregar una tarjeta de crédito'.
  final String title;

  /// What the person wants, in their words: 'Quiero que la app cuente lo
  /// que debo en la Visa'.
  final String goal;

  final Future<void> Function(FlowRun f) play;

  /// The account to open on; null opens on none, as on a first launch.
  final Future<QuincenaStore> Function()? data;
  final bool dark;
  final bool english;
  final bool demo;

  /// What this flow cannot do on a simulator and a person has to try on a
  /// phone, a line each.
  final List<String> manual;
}

/// What a check found.
class Check {
  const Check(this.what, this.ok, [this.detail]);

  final String what;
  final bool ok;
  final String? detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'what': what,
    'ok': ok,
    if (detail != null) 'detail': detail,
  };
}

/// A flow being played: the way through the app, its pictures and checks.
class FlowRun {
  FlowRun(this.tour, this._shot, this.flow);

  /// The moves through the app: taps, typing, scrolling, going back.
  final Tour tour;
  final StepShot _shot;
  final AppFlow flow;
  final List<Check> checks = <Check>[];
  final List<String> captions = <String>[];
  Object? error;
  int _taken = 0;

  WidgetTester get tester => tour.tester;
  OwnController get own => tour.own;

  /// A picture of the screen as it is, under [caption]: what was just done
  /// and what to look at, in a sentence or two of plain Spanish.
  Future<void> step(String caption) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Long enough for the keyboard to go, touches to fade and animations
    // to end.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await settle(tester);
    _taken++;
    captions.add(caption);
    await _shot('${flow.id}-${_taken.toString().padLeft(2, '0')}', caption);
  }

  /// Pictures of the whole screen from its top to its end, [caption] under
  /// the first and "(sigue)" under the rest.
  Future<void> page(String caption, {int most = 6}) async {
    final ScrollableState? list = _list();
    if (list == null || list.position.maxScrollExtent <= 0) {
      await step(caption);
      return;
    }
    list.position.jumpTo(0);
    await settle(tester);
    final double stride = list.position.viewportDimension * 0.8;
    var part = 1;
    var offset = 0.0;
    while (true) {
      await step(part == 1 ? caption : '(sigue) $caption');
      if (offset >= list.position.maxScrollExtent || part >= most) break;
      offset = (offset + stride).clamp(0, list.position.maxScrollExtent);
      list.position.jumpTo(offset);
      await settle(tester);
      part++;
    }
    list.position.jumpTo(0);
    await settle(tester);
  }

  /// Checks [what] with [body], which fails by throwing, as `expect` does.
  /// A failed check is written down and the flow goes on.
  Future<void> check(String what, FutureOr<void> Function() body) async {
    try {
      await body();
      checks.add(Check(what, true));
    } catch (e) {
      final String detail = '$e'
          .split('\n')
          .map((String l) => l.trim())
          .where((String l) => l.isNotEmpty)
          .take(6)
          .join(' ');
      checks.add(Check(what, false, detail));
    }
  }

  // The moves, as the tour makes them.
  Future<void> tap(String text) => tour.tap(text);
  Future<void> tapContaining(String text) => tour.tapContaining(text);
  Future<void> tapTip(String tooltip) => tour.tapTip(tooltip);
  Future<void> type(String label, String text) => tour.type(label, text);
  Future<void> reveal(Finder finder) => tour.reveal(finder);
  Future<void> back() => tour.back();
  Future<void> top() => tour.top();
  Future<void> waitFor(Finder finder, {Duration? most}) =>
      most == null ? tour.waitFor(finder) : tour.waitFor(finder, most: most);

  /// From the example's Inicio to its conversation over the same story.
  Future<void> toConversation() => tour.conversation(english: flow.english);

  /// Taps what [finder] finds, after scrolling it into view.
  Future<void> tapFound(Finder finder) async {
    await reveal(finder);
    await tester.tap(finder.last);
    await settle(tester);
  }

  /// Whether [text] shows anywhere on screen right now.
  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  /// Everything the screen says, joined, for checks that look for words.
  String get screenText => <String>[
    for (final Element e in find.byType(RichText).evaluate())
      (e.widget as RichText).text.toPlainText(),
  ].join(' | ');

  ScrollableState? _list() {
    ScrollableState? found;
    for (final Element e in find.byType(Scrollable).evaluate()) {
      final ScrollableState s = (e as StatefulElement).state as ScrollableState;
      if (s.position.axis != Axis.vertical) continue;
      final RenderBox? box = e.renderObject as RenderBox?;
      if (box == null || !box.hasSize || box.size.height < 240) continue;
      found = s;
    }
    return found;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': flow.id,
    'area': flow.area,
    'title': flow.title,
    'goal': flow.goal,
    'manual': flow.manual,
    'steps': captions,
    'checks': <Map<String, Object?>>[for (final Check c in checks) c.toJson()],
    if (error != null) 'error': '$error'.split('\n').take(8).join(' '),
  };
}

/// Opens the app for [flow] and plays it, taking pictures with [shot]. The
/// run comes back even when the flow broke on the way, with the error in it.
Future<FlowRun> playFlow(
  WidgetTester tester,
  AppFlow flow,
  StepShot shot, {
  Size? size,
}) async {
  FlowRun? run;
  final Scene scene = Scene(
    flow.id,
    (Tour tour) async {
      final FlowRun playing = run = FlowRun(tour, shot, flow);
      await flow.play(playing);
    },
    data: flow.data,
    dark: flow.dark,
    english: flow.english,
    demo: flow.demo,
  );
  try {
    await playScene(tester, scene, (String _) async {}, size: size);
  } catch (e) {
    // It may break before the flow starts, as while opening its account.
    (run ??= FlowRun(
      Tour(tester, (String _) async {}, flow.id),
      shot,
      flow,
    )).error = e;
  }
  return run!;
}

/// Gives the flow a keychain of its own, kept in a map: the phone's would
/// keep the sync and backup keys that the flow before left behind.
void useOwnKeychain(WidgetTester tester) {
  final Map<String, String> keychain = <String, String>{};
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_keychain, (
    MethodCall call,
  ) async {
    final Map<Object?, Object?> args =
        (call.arguments as Map<Object?, Object?>?) ?? const {};
    final String? key = args['key'] as String?;
    return switch (call.method) {
      'read' => keychain[key],
      'write' => keychain[key!] = args['value']! as String,
      'delete' => keychain.remove(key),
      'containsKey' => keychain.containsKey(key),
      'readAll' => keychain,
      'deleteAll' => keychain.clear(),
      _ => null,
    };
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _keychain,
      null,
    ),
  );
}

const MethodChannel _keychain = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
