// The forms with the keyboard up, on the smallest common phone with the
// system text at twice its size: the field being typed in stays in sight
// above the keyboard, and the button that saves or goes on is in sight or
// a scroll away, never under the keyboard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/account_sheet.dart';
import 'package:quincena/ui/own/ask_page.dart';
import 'package:quincena/ui/own/charge_sheet.dart';
import 'package:quincena/ui/own/entry_sheet.dart';
import 'package:quincena/ui/own/goal_sheet.dart';
import 'package:quincena/ui/own/home_tab.dart';
import 'package:quincena/ui/own/onboarding_page.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

final AppLocalizations l = lookupAppLocalizations(const Locale('es'));

/// How tall the keyboard is on a 360 by 800 phone: 336 points.
const double _keyboard = 336;

/// Where the keyboard starts.
const double _above = 800 - _keyboard;

/// [page] on Google Play's smallest screenshot phone, 360 by 800, with the
/// text at twice its size and the keyboard down, over what [data] adds.
Future<OwnController> _open(
  WidgetTester tester,
  Widget Function(OwnController own) page, {
  Future<void> Function(QuincenaStore store, Account bank, Account card)? data,
}) async {
  final OwnController own = await openPage(tester, page, data: data);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await settle(tester);
  return own;
}

/// The text field labelled [label].
Finder _field(String label) => find.widgetWithText(TextField, label);

/// Taps [field], scrolled only as far as it takes to show, at the bottom
/// of the screen, as a finger would, with the keyboard still down.
Future<void> _tapField(WidgetTester tester, Finder field) async {
  await Scrollable.ensureVisible(
    tester.element(field),
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
  );
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

/// The phone raises the keyboard over the field that took focus.
Future<void> _keyboardUp(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 3);
  await tester.pumpAndSettle();
}

/// The text field with focus.
Finder get _focused => find.ancestor(
  of: find.byWidgetPredicate(
    (Widget w) => w is EditableText && w.focusNode.hasFocus,
  ),
  matching: find.byType(TextField),
);

/// [found] whole on the screen above the keyboard, and what a finger
/// there would touch.
void _inSight(WidgetTester tester, Finder found) {
  expect(found, findsOneWidget);
  final Rect rect = tester.getRect(found);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(_above));
  expect(found.hitTestable(), findsOneWidget);
}

/// The field with focus stays above the keyboard as it comes up, and the
/// button [go] is in sight, or, with [scroll], a scroll away.
Future<void> _typesIn(
  WidgetTester tester,
  Finder field, {
  required Finder go,
  bool scroll = false,
}) async {
  await _tapField(tester, field);
  expect(_focused, findsOneWidget);
  await _keyboardUp(tester);
  expect(tester.takeException(), isNull);
  _inSight(tester, _focused);
  expect(tester.widget<TextField>(_focused), tester.widget<TextField>(field));
  if (scroll) {
    await tester.ensureVisible(go);
    await tester.pumpAndSettle();
  }
  _inSight(tester, go);
  // Typing keeps it there.
  await tester.enterText(_focused, '120000');
  await tester.pumpAndSettle();
  _inSight(tester, _focused);
  expect(tester.takeException(), isNull);
  tester.view.resetViewInsets();
  await tester.pumpAndSettle();
}

/// A page with only a button that opens [open], for a sheet.
Widget _opener(void Function(BuildContext context) open) => Scaffold(
  body: Builder(
    builder: (BuildContext context) => Center(
      child: TextButton(onPressed: () => open(context), child: const Text('+')),
    ),
  ),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('+'));
  await settle(tester);
  // The field that takes focus by itself waits for a tap here.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

/// The sheet's button, apart from the page under it.
Finder _inSheet(Finder found) =>
    find.descendant(of: find.byType(BottomSheet), matching: found);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('a new movement: its amount, where it was and its note', (
    tester,
  ) async {
    await _open(
      tester,
      (OwnController own) =>
          _opener((BuildContext context) => showEntrySheet(context, own: own)),
    );
    await _openSheet(tester);
    await tester.tap(find.text(l.entrySpent));
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final Finder save = _inSheet(find.widgetWithText(FilledButton, l.save));
    await _typesIn(tester, _field(l.amount), go: save, scroll: true);
    await _typesIn(tester, _field(l.payee), go: save, scroll: true);
    // The rest, opened: the note is the last field, and the button comes
    // up with it.
    await tester.ensureVisible(find.text(l.entryChange));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.entryChange));
    await settle(tester);
    await _typesIn(tester, _field(l.note), go: save);
  });

  testWidgets('a payment to review: its amount and its note', (tester) async {
    final OwnController own = await _open(
      tester,
      (OwnController own) => _opener(
        (BuildContext context) => showEntrySheet(
          context,
          own: own,
          fromInbox: own.pendingInbox.single,
        ),
      ),
      data: (QuincenaStore store, Account bank, Account card) async {
        await store.saveCaptureSettings(
          const CaptureSettings().copyWith(
            cardAccounts: <String, String>{'9876': card.id},
          ),
        );
        final OwnController own = OwnController(
          store,
          now: () => pageNow,
          readNative: false,
        );
        await own.capture.ingest(<CaptureEvent>[
          CaptureEvent(
            source: CaptureSource.notification,
            at: pageNow.subtract(const Duration(minutes: 5)),
            app: 'com.todo1.mobile',
            appName: 'Bancolombia',
            text:
                'Bancolombia: Compraste \$45.900 en EXITO LAURELES con tu '
                'T.Cred *9876',
          ),
        ]);
        own.dispose();
      },
    );
    expect(own.pendingInbox, hasLength(1));
    await _openSheet(tester);
    final Finder record = _inSheet(
      find.widgetWithText(FilledButton, l.recordExpense),
    );
    await _typesIn(tester, _field(l.amount), go: record, scroll: true);
    await _typesIn(tester, _field(l.note), go: record);
  });

  testWidgets('a new account: its name and its balance', (tester) async {
    await _open(
      tester,
      (OwnController own) => _opener(
        (BuildContext context) => showAccountSheet(context, own: own),
      ),
    );
    await _openSheet(tester);
    final Finder save = _inSheet(find.widgetWithText(FilledButton, l.save));
    await _typesIn(tester, _field(l.accountName), go: save, scroll: true);
    await _typesIn(tester, _field(l.accountBalanceNow), go: save, scroll: true);
  });

  testWidgets('a new goal and a new fixed payment: their names', (
    tester,
  ) async {
    await _open(
      tester,
      (OwnController own) => Scaffold(
        body: Builder(
          builder: (BuildContext context) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton(
                onPressed: () => showGoalForm(context, own: own),
                child: const Text('meta'),
              ),
              TextButton(
                onPressed: () => showChargeForm(context, own: own),
                child: const Text('pago'),
              ),
            ],
          ),
        ),
      ),
    );
    // Each opens on a page of its own, over the one with the buttons.
    final Finder save = find.widgetWithText(FilledButton, l.save);
    await tester.tap(find.text('meta'));
    await settle(tester);
    await _typesIn(tester, _field(l.goalName), go: save, scroll: true);
    Navigator.of(tester.element(save)).pop();
    await settle(tester);

    await tester.tap(find.text('pago'));
    await settle(tester);
    await _typesIn(tester, _field(l.chargeName), go: save, scroll: true);
  });

  testWidgets('asking: the question and the button that sends it', (
    tester,
  ) async {
    await _open(tester, (OwnController own) {
      final Session session = Session(
        thinking: Duration.zero,
        ledgerOf: () => own.ledger!,
        own: true,
      );
      addTearDown(session.dispose);
      return AskPage(own: own, session: session);
    });
    await _typesIn(tester, find.byType(TextField), go: find.byTooltip(l.ask));
  });

  testWidgets('the sample: the question and the button that sends it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final Session session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    await _typesIn(tester, find.byType(TextField), go: find.byTooltip(l.ask));
  });

  testWidgets('can I afford it, on Inicio: the price and the button', (
    tester,
  ) async {
    await _open(
      tester,
      (OwnController own) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
          child: OwnHomeTab(own: own, onSeeAll: () {}),
        ),
      ),
    );
    await _typesIn(
      tester,
      _field(l.buyAskHint),
      go: find.widgetWithText(FilledButton, l.buyAskGo),
    );
  });

  testWidgets('onboarding: the name, and what arrives each payday', (
    tester,
  ) async {
    await _open(
      tester,
      (OwnController own) => OnboardingPage(
        store: own.store,
        newOwn: () =>
            OwnController(own.store, now: () => pageNow, readNative: false),
        onDone: () {},
        onCancel: () {},
      ),
    );
    final Finder next = find.widgetWithText(FilledButton, l.next);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _typesIn(tester, _field(l.onboardingNameHint), go: next);

    await tester.tap(next);
    await settle(tester);
    expect(find.text(l.onboardingPayTitle), findsOneWidget);
    await _typesIn(tester, _field(l.amount), go: next);
  });
}
