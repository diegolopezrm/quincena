// Phase 19: the widget on the phone's home screen says what Inicio says,
// from when, and nothing of the amount when the person hides it. The phone
// draws it; these check what the app hands it and when.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/own_settings_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/widget/home_widget.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

const MethodChannel _widget = MethodChannel('dev.dlsoft.quincena/widget');

/// What the app hands the widget, as the phone would get it.
List<MethodCall> listen(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_widget, (
    MethodCall call,
  ) async {
    calls.add(call);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _widget,
      null,
    ),
  );
  return calls;
}

Map<Object?, Object?> shown(MethodCall call) {
  expect(call.method, 'show');
  return call.arguments as Map<Object?, Object?>;
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });
  tearDown(() => Intl.defaultLocale = 'es_CO');

  testWidgets('it says what the home says, and from when', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => const SizedBox(),
    );
    final AppLocalizations es = lookupAppLocalizations(const Locale('es'));
    final Map<String, Object?> figure = widgetFigure(
      es,
      own.ledger!,
      now: pageNow,
      hidden: false,
    );
    expect(figure['label'], 'Puedes gastar');
    expect(figure['amount'], r'$2.000.000');
    expect(figure['short'], false);
    expect(figure['until'], 'hasta el 15 de octubre');
    expect(figure['when'], 'Tu quincena llega en 12 días');
    expect(figure['day'], '2026-10-03');
    expect(figure['updated'], startsWith('Actualizado: 10:00'));
    expect(figure['stale'], 'Abre Quincena para ver la cifra de hoy.');

    // Hidden, the amount is not sent at all.
    final Map<String, Object?> hidden = widgetFigure(
      es,
      own.ledger!,
      now: pageNow,
      hidden: true,
    );
    expect(hidden['amount'], '••••••');
    expect(jsonEncode(hidden), isNot(contains('2.000.000')));
    expect(hidden['until'], 'hasta el 15 de octubre');

    // In English, as the interface speaks it.
    Intl.defaultLocale = 'en_US';
    final Map<String, Object?> en = widgetFigure(
      lookupAppLocalizations(const Locale('en')),
      own.ledger!,
      now: pageNow,
      hidden: false,
    );
    expect(en['label'], 'You can spend');
    expect(en['amount'], r'$2,000,000');
    expect(en['until'], 'until October 15');
  });

  testWidgets('short of payday, it says what is missing', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => const SizedBox(),
      data: (QuincenaStore store, Account bank, Account card) => store.addEntry(
        accountId: bank.id,
        amount: Decimal.parse('2300000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 12),
        payee: 'Arriendo',
      ),
    );
    final Map<String, Object?> figure = widgetFigure(
      lookupAppLocalizations(const Locale('es')),
      own.ledger!,
      now: pageNow,
      hidden: false,
    );
    expect(figure['label'], 'Te faltan');
    expect(figure['amount'], r'$300.000');
    expect(figure['short'], true);
    expect(figure['until'], 'para llegar al 15 de octubre');
  });

  testWidgets('own mode keeps it current, and only sends what changed', (
    tester,
  ) async {
    final List<MethodCall> calls = listen(tester);
    late AppModeController modes;
    final OwnController own = await openPage(tester, (OwnController own) {
      modes = AppModeController(store: own.store, now: () => pageNow);
      return OwnShell(own: own, modes: modes, settings: AppSettings());
    });
    expect(calls, hasLength(1));
    expect(shown(calls.single)['amount'], r'$2.000.000');

    // Nothing changed: nothing sent.
    own.notifyListeners();
    await settle(tester);
    expect(calls, hasLength(1));

    // A movement changes the figure.
    await tester.runAsync(
      () => own.store.addEntry(
        accountId: own.accounts.first.id,
        amount: Decimal.parse('50000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3, 9),
        payee: 'Mercado',
      ),
    );
    await settle(tester);
    expect(calls, hasLength(2));
    expect(shown(calls.last)['amount'], r'$1.950.000');

    // Hidden: the next figure leaves the amount out.
    await tester.runAsync(() => own.hideWidgetAmounts(true));
    await settle(tester);
    expect(own.widgetHidesAmounts, isTrue);
    expect(shown(calls.last)['amount'], '••••••');

    // The example leaves it alone: it keeps saying the person's own
    // figure, and none of Valentina's reaches it.
    final int sent = calls.length;
    await tester.runAsync(modes.useDemo);
    await settle(tester);
    expect(modes.example, isNotNull);
    expect(calls, hasLength(sent));
    modes.dispose();
  });

  testWidgets('settings say how to add it and can hide the amounts', (
    tester,
  ) async {
    final List<MethodCall> calls = listen(tester);
    final OwnController own = await openPage(
      tester,
      (OwnController own) => OwnSettingsPage(
        own: own,
        modes: AppModeController(store: own.store, now: () => pageNow),
        settings: AppSettings(),
      ),
    );
    // Under Apariencia, with a title of its own.
    await reveal(tester, find.text('Widget de inicio'));
    expect(find.textContaining('mantén presionado'), findsOneWidget);
    await tapText(tester, 'Ocultar montos en el widget');
    expect(own.widgetHidesAmounts, isTrue);
    await tapText(tester, 'Ocultar montos en el widget');
    expect(own.widgetHidesAmounts, isFalse);

    // Android's launcher can add it from here; one that will not says how.
    await tapText(tester, 'Agregar a la pantalla de inicio');
    expect(calls.last.method, 'pin');
    expect(find.textContaining('no deja agregarlo desde aquí'), findsOneWidget);
  });
}
