// Months of history, the way someone who imports their statements has it:
// Movimientos and an account's page build only the days on the screen, go
// down to the oldest and search through all of it, at twice the text size;
// Por revisar holds two dozen waiting.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/account_page.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/movement_list.dart';
import 'package:quincena/ui/own/own_shell.dart';

import 'fonts.dart';
import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

/// How many movements the history has.
const int _count = 1500;

/// The places they were at, in turn.
const List<(String, String)> _places = <(String, String)>[
  ('Éxito Laureles', 'groceries'),
  ('D1', 'groceries'),
  ('Rappi', 'restaurants'),
  ('Uber', 'transport'),
  ('Metro de Medellín', 'transport'),
  ('Crepes & Waffles', 'restaurants'),
  ('Farmatodo', 'health'),
];

/// When the [i]th movement, newest first, happened: one every 3.2 hours,
/// back 200 days.
DateTime _when(int i) =>
    DateTime(2026, 10, 3, 9).subtract(Duration(minutes: 192 * i));

/// [_count] expenses at [_places], alternating between the bank and the
/// card.
Future<void> _history(QuincenaStore store, Account bank, Account card) =>
    store.db.transaction(() async {
      for (var i = 0; i < _count; i++) {
        final (String payee, String category) = _places[i % _places.length];
        await store.addEntry(
          accountId: i.isEven ? bank.id : card.id,
          amount: Decimal.fromInt(5000 + (i % 40) * 1000),
          kind: EntryKind.expense,
          date: _when(i),
          category: category,
          payee: payee,
        );
      }
    });

/// Android's largest text, where each row is the tallest.
void _largeText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The rows built, on the screen or near it.
int _built(WidgetTester tester) =>
    find.byType(MovementRow, skipOffstage: false).evaluate().length;

/// Goes down the list until the oldest day's title shows, as a person
/// flicking through it would, and back to the top.
Future<void> _toOldest(WidgetTester tester) async {
  final String title = weekdayDayMonth(_when(_count - 1)).toUpperCase();
  final Finder oldest = find.text(title);
  expect(oldest, findsNothing);
  final Finder list = find.byType(Scrollable).first;
  // Until the oldest day is built: a day taller than the screen, as the
  // last can be with the largest text, ends the list with its title above
  // it, where scrolling down never shows it.
  await tester.scrollUntilVisible(
    find.text(title, skipOffstage: false),
    4000,
    scrollable: list,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
  expect(oldest, findsOneWidget);
  expect(tester.takeException(), isNull);
  // Still only what is near the screen.
  expect(_built(tester), lessThan(100));
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('Movimientos builds only the days on the screen, goes down to '
      'the oldest and searches all of it', (tester) async {
    _largeText(tester);
    late AppModeController modes;
    final OwnController own = await openPage(tester, (OwnController own) {
      modes = AppModeController(store: own.store, now: () => pageNow);
      return OwnShell(own: own, modes: modes, settings: AppSettings());
    }, data: _history);
    addTearDown(modes.dispose);
    await tester.tap(find.text('Movimientos'));
    await settle(tester);

    // The pay and the history, and a handful of rows built for them.
    expect(visibleEntries(own), hasLength(_count + 1));
    expect(find.byType(MovementRow), findsWidgets);
    expect(_built(tester), lessThan(100));
    expect(tester.takeException(), isNull);

    await _toOldest(tester);

    // A search runs through all 1,500, and shows what it found the same
    // way: a few days at a time.
    await tester.enterText(find.byType(TextField), 'éxito');
    await settle(tester);
    expect(find.text('Éxito Laureles'), findsWidgets);
    expect(find.text('D1'), findsNothing);
    expect(_built(tester), lessThan(100));
    final List<Entry> found = visibleEntries(
      own,
    ).where((Entry e) => e.payee == 'Éxito Laureles').toList();
    expect(found, hasLength((_count / _places.length).ceil()));
    await _toOldest(tester);
  });

  testWidgets('an account\'s page builds only the days on the screen and '
      'goes down to the oldest', (tester) async {
    _largeText(tester);
    late String bankId;
    await openPage(
      tester,
      (OwnController own) => AccountPage(own: own, accountId: bankId),
      data: (QuincenaStore store, Account bank, Account card) {
        bankId = bank.id;
        return _history(store, bank, card);
      },
    );
    expect(find.byType(MovementRow), findsWidgets);
    expect(_built(tester), lessThan(100));
    await _toOldest(tester);
  });

  testWidgets('Por revisar holds two dozen waiting', (tester) async {
    _largeText(tester);
    final OwnController own = await openPage(
      tester,
      (OwnController own) => InboxPage(own: own),
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
          for (var k = 0; k < 25; k++)
            CaptureEvent(
              source: CaptureSource.notification,
              at: pageNow.subtract(Duration(minutes: 40 * k + 5)),
              app: 'com.todo1.mobile',
              appName: 'Bancolombia',
              text:
                  'Bancolombia: Compraste \$${k + 1}.${k % 10}00 en '
                  '${_places[k % _places.length].$1.toUpperCase()} con tu '
                  'T.Cred *9876',
            ),
        ]);
        own.dispose();
      },
    );
    expect(own.pendingInbox, hasLength(25));
    expect(tester.takeException(), isNull);
    final ScrollableState list = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    while (list.position.extentAfter > 0) {
      list.position.jumpTo(list.position.pixels + 600);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
