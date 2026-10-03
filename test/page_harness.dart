// Opens one of the screens for someone's own money over an in-memory
// store, with the native channels answered, and finds things in it the way
// a person would: scrolling to them first.
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';

import 'own_flow_test.dart' show settle;

/// The day the screens believe it is.
final DateTime pageNow = DateTime(2026, 10, 3, 10);

const MethodChannel _reminders = MethodChannel('dev.dlsoft.quincena/reminders');
const MethodChannel _share = MethodChannel('dev.dlsoft.quincena/share');

/// [page] over a store with 2.000.000 in the bank after September's pay
/// and a Visa in the app, plus whatever [data] adds. Calls to the reminder
/// and share channels land in [calls].
Future<OwnController> openPage(
  WidgetTester tester,
  Widget Function(OwnController own) page, {
  Future<void> Function(QuincenaStore store, Account bank, Account card)? data,
  List<MethodCall>? calls,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  for (final MethodChannel channel in <MethodChannel>[_reminders, _share]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall call,
    ) async {
      calls?.add(call);
      return call.method == 'ask' || call.method == 'text' ? true : null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }
  final QuincenaStore store = QuincenaStore(
    QuincenaDatabase(NativeDatabase.memory()),
    now: () => pageNow,
  );
  addTearDown(() => tester.runAsync(store.close));
  final OwnController own = OwnController(
    store,
    now: () => pageNow,
    readNative: false,
  );
  addTearDown(own.dispose);
  await tester.runAsync(() async {
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
    );
    final Account bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: Decimal.zero,
    );
    final Account card = await store.addAccount(
      name: 'Visa',
      kind: AccountKind.card,
      asset: Asset.cop,
      opening: Decimal.zero,
    );
    await store.addEntry(
      accountId: bank.id,
      amount: Decimal.parse('2000000'),
      kind: EntryKind.income,
      date: DateTime(2026, 9, 30, 8),
      category: 'salary',
      payee: 'Nómina',
    );
    await data?.call(store, bank, card);
    await own.start();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: quincenaTheme(Brightness.light),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appLocales,
      home: page(own),
    ),
  );
  await settle(tester);
  return own;
}

/// Brings [finder] into view, building it first when a list has not. A
/// focused field would scroll itself back into view, so none is.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    // A list builds only what is near the screen: look from its top.
    final Finder scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
    }
  }
  await tester.ensureVisible(finder.last);
  await tester.pumpAndSettle();
}

/// Taps the last widget showing [text], once it is in view.
Future<void> tapText(WidgetTester tester, String text) async {
  await reveal(tester, find.text(text));
  await tester.tap(find.text(text).last);
  await settle(tester);
}
