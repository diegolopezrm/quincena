// The floating button steps aside while the list under it scrolls down, so
// it never covers an amount, and comes back going up, at the top and at
// the end. A screen reader keeps it; reduced motion takes it away still.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/ui/icons.dart';
import 'package:quincena/ui/own/look.dart';
import 'package:quincena/ui/own/own_shell.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

/// Whether a tap at [where] lands on the floating button.
bool reaches(WidgetTester tester, Offset where) {
  final Set<RenderObject> button = <RenderObject>{
    for (final Element e
        in find
            .descendant(
              of: find.byType(FloatingActionButton),
              matching: find.byWidgetPredicate((Widget w) => true),
            )
            .evaluate())
      ?e.renderObject,
  };
  return tester
      .hitTestOnBinding(where)
      .path
      .any((entry) => button.contains(entry.target));
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  group('on a page of its own', () {
    late int taps;

    /// A long list with a sideways one in it, under the button.
    Future<void> open(WidgetTester tester) async {
      taps = 0;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ScrollAwareFab(
              child: FloatingActionButton.extended(
                onPressed: () => taps++,
                icon: const Icon(Glyph.plus),
                label: const Text('Agregar'),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                SizedBox(
                  height: 80,
                  child: ListView(
                    key: const Key('sideways'),
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      for (var i = 0; i < 20; i++)
                        SizedBox(width: 120, child: Text('Tarjeta $i')),
                    ],
                  ),
                ),
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 56, child: Text('Fila $i')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final Finder button = find.text('Agregar');
    ScrollPosition list(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    testWidgets('600 points down it takes no taps; going up it is back', (
      tester,
    ) async {
      await open(tester);
      final Offset where = tester.getCenter(button);
      expect(button.hitTestable(), findsOneWidget);

      await tester.drag(find.text('Fila 3'), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(list(tester).pixels, greaterThanOrEqualTo(600));
      expect(button.hitTestable(), findsNothing);
      await tester.tapAt(where);
      await tester.pumpAndSettle();
      expect(taps, 0);

      await tester.drag(find.text('Fila 14'), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      await tester.tapAt(where);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a jump counts too, and the top and the end bring it back', (
      tester,
    ) async {
      await open(tester);
      final ScrollPosition position = list(tester);

      position.jumpTo(600);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsNothing);

      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);

      position.jumpTo(1200);
      await tester.pumpAndSettle();
      // Up from the end: still there.
      expect(button.hitTestable(), findsOneWidget);
      position.jumpTo(1800);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsNothing);

      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
    });

    testWidgets('a sideways list inside leaves it alone', (tester) async {
      await open(tester);
      await tester.drag(
        find.byKey(const Key('sideways')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('sideways')),
                matching: find.byType(Scrollable),
              ),
            )
            .position
            .pixels,
        greaterThan(0),
      );
      expect(button.hitTestable(), findsOneWidget);
    });

    testWidgets('with a screen reader on it stays, and it is read out', (
      tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester);

      await tester.drag(find.text('Fila 3'), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(list(tester).pixels, greaterThanOrEqualTo(600));
      expect(button.hitTestable(), findsOneWidget);
      expect(find.semantics.byLabel('Agregar'), findsOneWidget);
      await tester.tap(button);
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('hidden, a screen reader does not find it either', (
      tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.semantics.byLabel('Agregar'), findsOneWidget);
      list(tester).jumpTo(600);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Agregar'), findsNothing);
      semantics.dispose();
    });

    testWidgets('with reduced motion it goes at once, without sliding', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester);
      final Finder fade = find.descendant(
        of: find.byType(ScrollAwareFab),
        matching: find.byType(FadeTransition),
      );

      list(tester).jumpTo(600);
      // One frame, and it is gone.
      await tester.pump();
      expect(tester.widget<FadeTransition>(fade.first).opacity.value, 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('otherwise it fades on its way out', (tester) async {
      await open(tester);
      final Finder fade = find.descendant(
        of: find.byType(ScrollAwareFab),
        matching: find.byType(FadeTransition),
      );

      list(tester).jumpTo(600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double halfway = tester
          .widget<FadeTransition>(fade.first)
          .opacity
          .value;
      expect(halfway, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(fade.first).opacity.value, 0);
    });
  });

  group('in the shell', () {
    /// The shell over 2.000.000 in the bank and a month of small expenses,
    /// enough for Inicio and Movimientos to scroll.
    Future<AppModeController> openShell(WidgetTester tester) async {
      late AppModeController modes;
      await openPage(
        tester,
        (OwnController own) {
          modes = AppModeController(store: own.store, now: () => pageNow);
          return OwnShell(own: own, modes: modes, settings: AppSettings());
        },
        data: (store, bank, card) async {
          for (var i = 0; i < 30; i++) {
            await store.addEntry(
              accountId: i.isEven ? bank.id : card.id,
              amount: Decimal.fromInt(12000 + i * 1000),
              kind: EntryKind.expense,
              date: DateTime(2026, 10, 3, 9).subtract(Duration(days: i)),
              category: 'groceries',
              payee: 'Tienda $i',
            );
          }
        },
      );
      addTearDown(modes.dispose);
      return modes;
    }

    final Finder button = find.byTooltip('Agregar movimiento');
    ScrollPosition list(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    testWidgets('Inicio and Movimientos hide it going down, show it going up', (
      tester,
    ) async {
      await openShell(tester);
      final Offset where = tester.getCenter(button);
      expect(button.hitTestable(), findsOneWidget);
      expect(list(tester).maxScrollExtent, greaterThan(800));

      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, -600),
        const Duration(milliseconds: 800),
      );
      await settle(tester);
      expect(list(tester).pixels, greaterThanOrEqualTo(600));
      expect(list(tester).extentAfter, greaterThan(24));
      expect(button.hitTestable(), findsNothing);
      expect(reaches(tester, where), isFalse);

      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, 200),
        const Duration(milliseconds: 400),
      );
      await settle(tester);
      expect(button.hitTestable(), findsOneWidget);
      expect(reaches(tester, where), isTrue);

      // Another tab starts with it in sight, even from halfway down.
      list(tester).jumpTo(600);
      await settle(tester);
      expect(button.hitTestable(), findsNothing);
      await tester.tap(find.text('Movimientos'));
      await settle(tester);
      expect(button.hitTestable(), findsOneWidget);
      expect(list(tester).maxScrollExtent, greaterThan(1200));

      list(tester).jumpTo(900);
      await settle(tester);
      expect(button.hitTestable(), findsNothing);
      // Back up, as the tour does before it taps it.
      list(tester).jumpTo(0);
      await settle(tester);
      await tester.tap(button);
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('Cuentas and Plan have no floating button', (tester) async {
      await openShell(tester);
      await tester.tap(find.text('Cuentas'));
      await settle(tester);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('Plan'));
      await settle(tester);
      expect(find.byType(FloatingActionButton), findsNothing);
      // Goals are added from their own header.
      await tester.ensureVisible(find.text('Agregar meta'));
      await tester.tap(find.text('Agregar meta'));
      await settle(tester);
      expect(find.text('¿Para qué es?'), findsOneWidget);
    });

    testWidgets('with a screen reader on, scrolling leaves it in place', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openShell(tester);
      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, -600),
        const Duration(milliseconds: 800),
      );
      await settle(tester);
      expect(list(tester).pixels, greaterThanOrEqualTo(600));
      expect(button.hitTestable(), findsOneWidget);
    });
  });
}
