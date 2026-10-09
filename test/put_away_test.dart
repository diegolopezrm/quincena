// What was discarded or archived waits in «Archivado y descartado», each
// thing with the way to bring it back: from Por revisar, from Ajustes, and
// on a trip's page for what was taken out of it.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/messages.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/put_away_page.dart';
import 'package:quincena/ui/own/trips_page.dart';

import '../test_screens/accounts.dart';
import 'fonts.dart';
import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  /// Por revisar over the morning's captures, its messages one at a time
  /// as in the app.
  Future<OwnController> openInbox(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = (await tester.runAsync(withCaptures))!;
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => screensNow,
      readNative: false,
    );
    addTearDown(own.dispose);
    await tester.runAsync(own.start);
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        builder: (BuildContext context, Widget? child) =>
            LatestMessenger(child: child!),
        home: InboxPage(own: own),
      ),
    );
    await settle(tester);
    return own;
  }

  /// Picks [choice] in the «⋮» menu of [payee]'s card.
  Future<void> fromMenu(
    WidgetTester tester,
    String payee,
    String choice,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text(payee),
          matching: find.byType(InboxCard),
        ),
        matching: find.byTooltip('Más acciones'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(choice).last);
    await settle(tester);
  }

  group('Por revisar', () {
    testWidgets('what was discarded waits in one place, and comes back from '
        'there', (tester) async {
      final OwnController own = await openInbox(tester);
      expect(find.textContaining('Ver lo descartado'), findsNothing);
      await fromMenu(tester, 'Laura Gómez', 'Descartar');
      expect(find.text('Ver lo descartado (1)'), findsOneWidget);
      await fromMenu(
        tester,
        'Éxito Laureles',
        'Descartar y no leer más Bancolombia',
      );
      await tester.tap(find.text('Dejar de leer'));
      await settle(tester);
      // Two captures and an app not read.
      await tester.tap(find.text('Ver lo descartado (3)'));
      await settle(tester);

      expect(find.byType(PutAwayPage), findsOneWidget);
      double top(Finder f) => tester.getTopLeft(f).dy;
      // What came from Por revisar goes first.
      expect(
        top(find.text('DESCARTADO EN POR REVISAR')),
        lessThan(top(find.text('APPS QUE NO SE LEEN'))),
      );
      expect(find.text('Laura Gómez'), findsOneWidget);
      expect(find.text('Éxito Laureles'), findsOneWidget);
      expect(find.text('Bancolombia'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Laura Gómez'),
            matching: find.byType(PutAwayRow),
          ),
          matching: find.text('Traer de vuelta'),
        ),
      );
      await settle(tester);
      expect(find.text('Laura Gómez volvió a Por revisar.'), findsOneWidget);
      expect(find.text('Laura Gómez'), findsNothing);
      expect(
        own.pendingInbox.map((InboxItem i) => i.suggestion.payee),
        contains('Laura Gómez'),
      );

      await tester.tap(find.text('Volver a leer'));
      await settle(tester);
      expect(own.captureSettings.mutedApps, isEmpty);
      expect(find.text('APPS QUE NO SE LEEN'), findsNothing);
    });
  });

  testWidgets('with nothing put away, the page says so', (tester) async {
    await openPage(tester, (OwnController own) => PutAwayPage(own: own));
    expect(find.text('No hay nada archivado ni descartado.'), findsOneWidget);
  });

  testWidgets('accounts, alerts, merchants that are not fixed payments and '
      'expenses taken out of a trip come back from the same page', (
    tester,
  ) async {
    late Entry dinner;
    final OwnController own = await openPage(
      tester,
      (OwnController own) => PutAwayPage(own: own),
      data: (QuincenaStore store, Account bank, Account card) async {
        final Account nequi = await store.addAccount(
          name: 'Nequi',
          kind: AccountKind.wallet,
          asset: Asset.cop,
          opening: d('35000'),
        );
        await store.updateAccount(nequi.copyWith(archived: true));
        for (final int hour in <int>[9, 10]) {
          await store.addEntry(
            accountId: bank.id,
            amount: d('63200'),
            kind: EntryKind.expense,
            date: DateTime(2026, 10, 2, hour),
            category: 'groceries',
            payee: 'Éxito Laureles',
          );
        }
        dinner = await store.addEntry(
          accountId: bank.id,
          amount: d('80000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2, 20),
          category: 'restaurants',
          payee: 'Andrés Carne de Res',
        );
        await store.setSetting(
          'trips',
          jsonEncode(<Object?>[
            Trip(
              id: 'trip-ny',
              name: 'Nueva York',
              from: DateTime(2026, 10, 1),
              to: DateTime(2026, 10, 8),
              currency: 'COP',
              excluded: <String>{dinner.id},
            ).toJson(),
          ]),
        );
      },
    );
    final ChargeAlert twice = own.allAlerts.firstWhere(
      (ChargeAlert a) => a.kind == AlertKind.twice,
    );
    // One answer read back before the next, as two taps would be.
    await tester.runAsync(
      () => own.answerAlert(twice.id, AlertAnswer.dismissed),
    );
    await settle(tester);
    await tester.runAsync(() => own.notRecurring('Netflix'));
    await settle(tester);

    for (final String title in <String>[
      'CARGOS QUE MARCASTE',
      'NO SON PAGOS FIJOS',
      'SACADOS DE UN VIAJE',
      'CUENTAS ARCHIVADAS',
    ]) {
      await reveal(tester, find.text(title));
      expect(find.text(title), findsOneWidget, reason: title);
    }

    await tapText(tester, 'Volver a mostrar');
    expect(own.detective.answers[twice.id], isNull);
    await tapText(tester, 'Volver a proponer');
    expect(own.detective.notRecurring, isEmpty);
    await tapText(tester, 'Es del viaje');
    expect(own.trip('trip-ny')!.excluded, isEmpty);
    expect(own.trip('trip-ny')!.covers(dinner), isTrue);
    await tapText(tester, 'Restaurar');
    expect(own.archivedAccounts, isEmpty);
    expect(find.text('No hay nada archivado ni descartado.'), findsOneWidget);
  });

  testWidgets('an expense taken out of a trip waits under «Gastos que '
      'sacaste», with the way back into it', (tester) async {
    final OwnController own = await openPage(
      tester,
      (OwnController own) => TripPage(own: own, id: 'trip-ny'),
      data: (QuincenaStore store, Account bank, Account card) async {
        await store.addEntry(
          accountId: bank.id,
          amount: d('119000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2, 7),
          category: 'health',
          payee: 'Fit24',
        );
        await store.setSetting(
          'trips',
          jsonEncode(<Object?>[
            Trip(
              id: 'trip-ny',
              name: 'Nueva York',
              from: DateTime(2026, 10, 1),
              to: DateTime(2026, 10, 8),
              currency: 'COP',
            ).toJson(),
          ]),
        );
      },
    );
    Trip trip() => own.trip('trip-ny')!;

    await tester.tap(find.byTooltip('No es del viaje'));
    await settle(tester);
    await reveal(tester, find.text('GASTOS QUE SACASTE'));
    expect(find.text('Es del viaje'), findsOneWidget);
    await tapText(tester, 'Es del viaje');
    expect(trip().excluded, isEmpty);
    expect(find.text('GASTOS QUE SACASTE'), findsNothing);
  });
}
