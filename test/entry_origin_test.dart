// The form that changes a movement says where the movement came from: by
// hand, a bank's notification, a statement, Binance. Knowing it helps tell
// a repeat from two payments.
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/capture/parser.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/own/entry_origin.dart';
import 'package:quincena/ui/own/entry_sheet.dart';
import 'package:quincena/ui/own/movements_tab.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

Entry _from(String source, {String? ref}) => Entry(
  id: 'e',
  accountId: 'bank',
  amount: Decimal.parse('-1000'),
  date: DateTime(2026, 10, 2),
  kind: EntryKind.expense,
  source: source,
  sourceRef: ref,
);

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  test('each source is said the way a person would', () {
    final AppLocalizations l = lookupAppLocalizations(const Locale('es'));
    String? said(Entry e, {String? from}) => entryOrigin(l, e, from: from)?.$2;
    expect(said(_from('manual')), 'Anotado a mano');
    expect(said(_from('statement', ref: 'line')), 'De un extracto');
    expect(said(_from('binance', ref: 'p2p:1')), 'De Binance');
    expect(said(_from('wallet', ref: 'capture')), 'De Apple Pay');
    expect(
      said(_from('wallet', ref: 'wallet:bitcoin:bc1q:BTC:adjust:1')),
      'De una billetera que sigues',
    );
    expect(said(_from('notification')), 'De una notificación');
    expect(
      said(_from('notification'), from: 'Bancolombia'),
      'De una notificación de Bancolombia',
    );
    expect(said(_from('sms'), from: 'Nequi'), 'De un SMS de Nequi');
    expect(said(_from('email')), 'De un correo');
    expect(said(_from('screenshot')), 'De una captura de pantalla');
    expect(said(_from('paste')), 'De un mensaje que pegaste');
    expect(said(_from('script')), 'De la conversación del ejemplo');
    // A source the app has no words for says nothing rather than guess.
    expect(said(_from('something-new')), isNull);

    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(
      entryOrigin(en, _from('notification'), from: 'Bancolombia')?.$2,
      'From a Bancolombia notification',
    );
  });

  testWidgets('the form that changes a movement says where it came from, '
      'and a new one says nothing', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => Scaffold(
        body: ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) =>
              CustomScrollView(slivers: <Widget>[MovementsTab(own: own)]),
        ),
      ),
      data: (QuincenaStore store, Account bank, Account card) async {
        Future<void> spend(
          String payee,
          int day, {
          String source = 'manual',
          String? ref,
        }) => store.addEntry(
          accountId: bank.id,
          amount: Decimal.parse('${10000 + day}'),
          kind: EntryKind.expense,
          date: DateTime(2026, 9, day, 12),
          category: 'other',
          payee: payee,
          source: source,
          sourceRef: ref,
        );
        final InboxItem push = InboxItem(
          id: store.newInboxId(),
          event: CaptureEvent(
            source: CaptureSource.notification,
            at: DateTime(2026, 9, 20, 9, 40),
            app: 'com.todo1.mobile',
            appName: 'Bancolombia',
            text: r'Bancolombia · Compra por $10.020 en D1',
          ),
          parsed: const ParsedCapture(institution: 'Bancolombia'),
          suggestion: const Suggestion(),
          status: InboxStatus.accepted,
        );
        await store.saveInboxItem(push);
        await spend('Uber', 21);
        await spend('D1', 20, source: 'notification', ref: push.id);
        // Captured on another phone: its capture did not come along.
        await spend('Rappi', 19, source: 'sms', ref: 'elsewhere');
        await spend('EXITO LAURELES', 18, source: 'statement', ref: 'line-3');
      },
    );
    for (final (String payee, String origin) in <(String, String)>[
      ('Uber', 'Anotado a mano'),
      ('D1', 'De una notificación de Bancolombia'),
      ('Rappi', 'De un SMS'),
      ('EXITO LAURELES', 'De un extracto'),
      ('Nómina', 'Anotado a mano'),
    ]) {
      await tapText(tester, payee);
      expect(find.text('Editar movimiento'), findsOneWidget, reason: payee);
      expect(find.text(origin), findsOneWidget, reason: payee);
      // Right under the title.
      expect(
        tester.getTopLeft(find.text(origin)).dy,
        greaterThan(tester.getTopLeft(find.text('Editar movimiento')).dy),
        reason: payee,
      );
      Navigator.of(tester.element(find.text(origin))).pop();
      await settle(tester);
    }

    // A movement being written has no past to tell.
    unawaited(
      showEntrySheet(tester.element(find.byType(MovementsTab)), own: own),
    );
    await settle(tester);
    expect(find.text('Agregar movimiento'), findsOneWidget);
    expect(find.text('Anotado a mano'), findsNothing);
  });
}
