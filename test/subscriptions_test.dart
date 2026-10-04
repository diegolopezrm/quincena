// Subscriptions: the person ticks what to cancel, Quincena says what it
// would save, and only what the person says they cancelled is struck
// through. Quincena itself never cancels anything.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/catalog/shapes.dart';
import 'package:quincena/catalog/subscription_list.dart';
import 'package:quincena/catalog/subscription_row.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/functions/money_functions.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/theme/theme.dart';

import 'fonts.dart';

Widget app(Widget child) => MaterialApp(
  theme: quincenaTheme(Brightness.light),
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: appLocales,
  home: Scaffold(body: child),
);

final Finder struck = find.byWidgetPredicate(
  (Widget w) => w is Text && w.style?.decoration == TextDecoration.lineThrough,
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  test('only what is ticked and not cancelled yet counts as saved', () {
    expect(
      savingsIfCancelled(const <SubscriptionItem>[
        SubscriptionItem(name: 'Fit24', price: 119000, keep: false),
        SubscriptionItem(name: 'Cineplus', price: 38900, keep: true),
        SubscriptionItem(
          name: 'Lingo Pro',
          price: 34900,
          keep: false,
          cancelled: true,
        ),
      ]),
      119000,
    );
  });

  test('the next charge is the first charge day after today', () {
    Subscription on(int day) => Subscription(
      id: 's',
      name: 'S',
      price: 1,
      chargeDay: day,
      since: DateTime(2026),
    );
    // A charge due today has already gone out.
    expect(on(1).nextCharge(DateTime(2026, 10, 1)), DateTime(2026, 11, 1));
    expect(on(20).nextCharge(DateTime(2026, 10, 1)), DateTime(2026, 10, 20));
    // On the last day of a shorter month, and across the year.
    expect(on(31).nextCharge(DateTime(2026, 11, 5)), DateTime(2026, 11, 30));
    expect(on(10).nextCharge(DateTime(2026, 12, 15)), DateTime(2027, 1, 10));
  });

  group('a subscription row', () {
    Future<List<bool>> pump(
      WidgetTester tester, {
      bool keep = true,
      bool cancelled = false,
    }) async {
      final List<bool> kept = <bool>[];
      await tester.pumpWidget(
        app(
          SubscriptionRow(
            name: 'Fit24 gimnasio',
            price: 119000,
            keep: keep,
            cancelled: cancelled,
            lastUsed: '2026-08-19',
            onKeepChanged: kept.add,
          ),
        ),
      );
      return kept;
    }

    Checkbox box(WidgetTester tester) =>
        tester.widget<Checkbox>(find.byType(Checkbox));

    testWidgets('starts with its box clear, and ticking it asks to cancel', (
      tester,
    ) async {
      final List<bool> kept = await pump(tester);
      expect(box(tester).value, isFalse);
      expect(
        box(tester).semanticLabel,
        'Seleccionar Fit24 gimnasio para cancelar',
      );
      expect(find.text('Para cancelar'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      expect(kept, <bool>[false]);
    });

    testWidgets('ticked, it says so without striking the name', (tester) async {
      final List<bool> kept = await pump(tester, keep: false);
      expect(box(tester).value, isTrue);
      expect(find.text('Para cancelar'), findsOneWidget);
      expect(struck, findsNothing);

      await tester.tap(find.byType(Checkbox));
      expect(kept, <bool>[true]);
    });

    testWidgets('cancelled, it is struck through and has no box', (
      tester,
    ) async {
      await pump(tester, keep: false, cancelled: true);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Para cancelar'), findsNothing);
      expect(struck, findsOneWidget);
    });
  });

  group('the footer of the list', () {
    Future<void> pump(WidgetTester tester, String savings) => tester.pumpWidget(
      app(
        SubscriptionList(
          title: 'Tus suscripciones',
          rows: const <Widget>[],
          savings: savings,
        ),
      ),
    );

    testWidgets('asks for a tick while nothing is saved', (tester) async {
      // What `money` writes for a list with nothing ticked.
      await pump(tester, money(0));
      expect(
        find.text('Marca las que quieras cancelar para ver cuánto ahorras'),
        findsOneWidget,
      );
      expect(find.textContaining('al mes'), findsNothing);
    });

    testWidgets('says what the ticked ones save', (tester) async {
      await pump(tester, money(153900));
      expect(
        find.text('Si cancelas las que marcaste, te ahorras'),
        findsOneWidget,
      );
      expect(find.textContaining(r'$153.900 al mes'), findsOneWidget);
    });
  });
}
