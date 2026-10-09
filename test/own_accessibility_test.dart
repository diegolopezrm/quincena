// The screens for someone's own money, the way people with a screen reader,
// large text or low vision meet them: on the smallest common phone, with
// the system text at twice its size, in both themes and both languages,
// held to Flutter's accessibility guidelines. The ones looked at most hold
// at iOS's largest text size too.
import 'dart:convert';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/movement_search.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/portfolio/market.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/statements/tables.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/sync/sync_service.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/icons.dart';
import 'package:quincena/ui/own/account_page.dart';
import 'package:quincena/ui/own/account_leaving.dart';
import 'package:quincena/ui/own/account_sheet.dart';
import 'package:quincena/ui/own/accounts_tab.dart';
import 'package:quincena/ui/own/ask_page.dart';
import 'package:quincena/ui/own/balance_explained.dart';
import 'package:quincena/ui/own/binance_page.dart';
import 'package:quincena/ui/own/capture_settings_page.dart';
import 'package:quincena/ui/own/charge_sheet.dart';
import 'package:quincena/ui/own/close_page.dart';
import 'package:quincena/ui/own/commitments_page.dart';
import 'package:quincena/ui/own/coming_days_page.dart';
import 'package:quincena/ui/own/cushion_page.dart';
import 'package:quincena/ui/own/detective_page.dart';
import 'package:quincena/ui/own/entry_sheet.dart';
import 'package:quincena/ui/own/envelopes_page.dart';
import 'package:quincena/ui/own/free_explained.dart';
import 'package:quincena/ui/own/freelance_page.dart';
import 'package:quincena/ui/own/goal_sheet.dart';
import 'package:quincena/ui/own/home_tab.dart';
import 'package:quincena/ui/own/inbox_page.dart';
import 'package:quincena/ui/own/instalments_page.dart';
import 'package:quincena/ui/own/movement_filters.dart';
import 'package:quincena/ui/own/movement_list.dart';
import 'package:quincena/ui/own/movements_tab.dart';
import 'package:quincena/ui/own/onboarding_page.dart';
import 'package:quincena/ui/own/own_settings_page.dart';
import 'package:quincena/ui/own/own_shell.dart';
import 'package:quincena/ui/own/plan_tab.dart';
import 'package:quincena/ui/own/portfolio_page.dart';
import 'package:quincena/ui/own/repeat_sheet.dart';
import 'package:quincena/ui/own/shared_page.dart';
import 'package:quincena/ui/own/start_page.dart';
import 'package:quincena/ui/own/statement_page.dart';
import 'package:quincena/ui/own/sync_page.dart';
import 'package:quincena/ui/own/trips_page.dart';
import 'package:quincena/ui/own/wallets_page.dart';
import 'package:quincena/ui/own/what_if_page.dart';
import 'package:quincena/ui/own/wishes_page.dart';
import 'package:quincena/data/example_prices.dart';

import '../test_screens/store_screens_test.dart' show example;
import 'commitments_data.dart';
import 'fonts.dart';
import 'real_life_data.dart';
import 'own_flow_test.dart' show settle;

final DateTime _now = DateTime(2026, 10, 3, 10);

/// A Ledger the example person follows by address, with the bitcoin it
/// holds; the address is made up.
Future<void> followLedger(QuincenaStore store) async {
  const String address = 'bc1qexampqe2wa77etq9yxz8c2kdu3ts6hrv0lmg5w';
  await store.setSetting(
    'wallets',
    jsonEncode(<String, Object?>{
      'wallets': <Object?>[
        <String, Object?>{
          'chain': 'bitcoin',
          'address': address,
          'label': 'Ledger',
        },
      ],
      'syncedAt': _now.toIso8601String(),
    }),
  );
  await store.addAccount(
    name: 'Bitcoin',
    kind: AccountKind.wallet,
    asset: Asset.btc,
    opening: Decimal.parse('0.0042'),
    institution: 'Ledger',
    spendable: false,
    syncRef: 'wallet:bitcoin:$address:BTC',
  );
}

/// A tab scrolled the way the app's shell scrolls it.
Widget tab(Widget body) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
    child: body,
  ),
);

/// A tab that is a list built as it scrolls, scrolled the same way.
Widget sliverTab(Widget sliver) => Scaffold(
  body: CustomScrollView(
    slivers: <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        sliver: sliver,
      ),
    ],
  ),
);

/// The languages the app speaks.
const List<Locale> languages = <Locale>[Locale('es'), Locale('en')];

/// iOS's largest text size, AX5, puts body text at 53 points where the
/// default is 17: about 3.1 times. Android stops at twice.
const double largestText = 3.1;

/// A page with only a button that opens [open], for a sheet: the test taps
/// it with [openIt].
Widget opener(void Function(BuildContext context) open) => Scaffold(
  body: Builder(
    builder: (BuildContext context) => Center(
      child: TextButton(onPressed: () => open(context), child: const Text('+')),
    ),
  ),
);

/// Opens what [opener] holds.
Future<void> openIt(WidgetTester tester) async {
  await tester.tap(find.text('+'));
  await settle(tester);
}

/// The text in [tester]'s screen cut short: past its lines, or ending in
/// an ellipsis.
List<String> cutShort(WidgetTester tester) => <String>[
  for (final Element e in find.byType(RichText).evaluate())
    if (e.renderObject case final RenderParagraph p
        when p.attached && p.didExceedMaxLines)
      p.text.toPlainText(),
];

/// The words broken across lines in text squeezed into less than half the
/// screen's width: a column too narrow to be read, though nothing is cut.
List<String> squeezed(WidgetTester tester) {
  final double half =
      tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
  return <String>[
    for (final Element e in find.byType(RichText).evaluate())
      if (e.renderObject case final RenderParagraph p
          when p.attached && p.hasSize && p.size.width < half)
        for (final RegExpMatch word in RegExp(
          r'\S+',
        ).allMatches(p.text.toPlainText()))
          if (p
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: word.start,
                      extentOffset: word.end,
                    ),
                  )
                  .map((TextBox b) => b.top)
                  .toSet()
                  .length >
              1)
            word[0]!,
  ];
}

/// Scrolls the screen's main list from its top to its end and back,
/// doing [check] at each stop: a list builds its rows only as they show.
Future<void> scrollThrough(
  WidgetTester tester, [
  void Function()? check,
]) async {
  check?.call();
  ScrollPosition? main;
  for (final ScrollableState list in tester.stateList<ScrollableState>(
    find.byType(Scrollable),
  )) {
    final ScrollPosition p = list.position;
    if (p.axis == Axis.vertical &&
        p.maxScrollExtent > (main?.maxScrollExtent ?? 0)) {
      main = p;
    }
  }
  if (main == null) return;
  while (main.pixels < main.maxScrollExtent) {
    main.jumpTo(math.min(main.pixels + 400, main.maxScrollExtent));
    await tester.pump();
    check?.call();
  }
  main.jumpTo(0);
  await tester.pumpAndSettle();
}

/// Opens [page] over the example person's money on Google Play's smallest
/// screenshot phone, 360 by 800, with the system text [scale] times its
/// size, in [brightness] and [locale]; does [then] there and scrolls it
/// through, and holds it to Flutter's accessibility guidelines. With
/// [wordsWhole], no words on it are squeezed into a narrow column; with
/// [nothingCut], no text is cut short either.
Future<void> expectAccessible(
  WidgetTester tester,
  Widget Function(OwnController own) page, {
  required Brightness brightness,
  required Locale locale,
  double scale = 2,
  Future<void> Function(WidgetTester tester)? then,
  bool wordsWhole = true,
  bool nothingCut = false,
}) async {
  final SemanticsHandle semantics = tester.ensureSemantics();
  // Google Play's smallest screenshot phone, 360 by 800.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => Intl.defaultLocale = 'es_CO');

  final QuincenaStore store = (await tester.runAsync(() async {
    final QuincenaStore store = await example();
    await followLedger(store);
    await addCommitments(store);
    await addRealLife(store);
    return store;
  }))!;
  addTearDown(() => tester.runAsync(store.close));
  final MarketData market = ExampleMarket(now: () => _now);
  final OwnController own = OwnController(
    store,
    now: () => _now,
    readNative: false,
    market: market,
  );
  addTearDown(own.dispose);
  await tester.runAsync(own.start);
  await tester.runAsync(() => own.portfolio.refresh());

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: quincenaTheme(brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appLocales,
      // Amounts and dates in the interface's language, as in the app.
      builder: (BuildContext context, Widget? child) {
        Intl.defaultLocale = intlLocaleFor(
          Localizations.localeOf(context).languageCode,
        );
        return child!;
      },
      home: page(own),
    ),
  );
  await settle(tester);
  await then?.call(tester);
  await scrollThrough(tester, () {
    if (wordsWhole) expect(squeezed(tester), isEmpty, reason: 'squeezed');
    if (nothingCut) expect(cutShort(tester), isEmpty, reason: 'cut short');
  });

  expect(tester.takeException(), isNull);
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  semantics.dispose();
}

/// A screen reached from another: the page to open, and the taps from it
/// to the screen, if any.
typedef Reached = (
  Widget Function(OwnController own),
  Future<void> Function(WidgetTester tester)?,
);

/// Onboarding over what the example person already told, so each step has
/// something in it and the steps can be walked with Siguiente alone.
Widget onboarding(OwnController own) => OnboardingPage(
  store: own.store,
  newOwn: () => OwnController(own.store, now: () => _now, readNative: false),
  onDone: () {},
  onCancel: () {},
);

/// Taps the main button [times].
Future<void> Function(WidgetTester tester) next(int times) =>
    (WidgetTester tester) async {
      for (var i = 0; i < times; i++) {
        await tester.tap(find.byType(FilledButton));
        await settle(tester);
      }
    };

/// What the app's frame and settings switch between, closed with the test.
AppModeController modesFor(OwnController own) {
  final AppModeController modes = AppModeController(
    store: own.store,
    now: () => _now,
  );
  addTearDown(modes.dispose);
  return modes;
}

/// The app's frame: its bar, its tabs and its floating button.
Widget shell(OwnController own) =>
    OwnShell(own: own, modes: modesFor(own), settings: AppSettings());

/// The frame's tabs, by the icon on each.
const List<(String, IconData)> shellTabs = <(String, IconData)>[
  ('Inicio', Glyph.house),
  ('Movimientos', Glyph.listBullets),
  ('Cuentas', Glyph.bank),
  ('Plan', Glyph.piggyBank),
];

/// Goes to the frame's tab with [icon].
Future<void> Function(WidgetTester tester) tapTab(IconData icon) =>
    (WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(icon),
        ),
      );
      await settle(tester);
    };

Account cardOf(OwnController own) =>
    own.accounts.firstWhere((Account a) => a.kind == AccountKind.card);

/// An expense of the example person's, which can be split.
Entry expenseOf(OwnController own) => own.snapshot!.entries.firstWhere(
  (Entry e) => e.kind == EntryKind.expense && !e.isTrade && !e.isTransfer,
);

/// The page that asks about the person's money, over a scripted
/// conversation in the interface's language instead of Gemini.
class _Ask extends StatefulWidget {
  const _Ask({required this.own});

  final OwnController own;

  @override
  State<_Ask> createState() => _AskState();
}

class _AskState extends State<_Ask> {
  Session? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session ??= Session(
      thinking: Duration.zero,
      language: Localizations.localeOf(context).languageCode,
      ledgerOf: () => widget.own.ledger!,
      own: true,
    );
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AskPage(own: widget.own, session: _session);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  final Map<String, Widget Function(OwnController own)> screens =
      <String, Widget Function(OwnController own)>{
        'home': (OwnController own) =>
            tab(OwnHomeTab(own: own, onSeeAll: () {}, onAsk: ([String? _]) {})),
        'movements': (OwnController own) => sliverTab(MovementsTab(own: own)),
        'accounts': (OwnController own) => tab(AccountsTab(own: own)),
        'where the net worth comes from': (OwnController own) =>
            tab(TotalExplained(own: own)),
        'a card': (OwnController own) => AccountPage(
          own: own,
          accountId: own.accounts
              .firstWhere((Account a) => a.kind == AccountKind.card)
              .id,
        ),
        'where the money to spend comes from': (OwnController own) =>
            Scaffold(body: FreeExplained(own: own)),
        'crypto': (OwnController own) => PortfolioPage(own: own),
        'Binance': (OwnController own) => BinancePage(own: own),
        'wallets': (OwnController own) => WalletsPage(own: own),
        'a statement': (OwnController own) => StatementPage(
          own: own,
          accountId: own.accounts
              .firstWhere((Account a) => a.name == 'Bancolombia')
              .id,
          statement: readTable(
            parseCsv(
              'Fecha;Descripción;Valor;Saldo\n'
              '28/09/2026;COMPRA EN D1 LAURELES;-32.400;1.245.600\n'
              '27/09/2026;PAGO PSE CLARO HOGAR;-98.900;1.278.000\n'
              '26/09/2026;TRANSFERENCIA DE CAMILO RIOS;150.000;1.376.900\n',
            ),
          ),
        ),
        'to review': (OwnController own) => InboxPage(own: own),
        'the next 30 days': (OwnController own) => ComingDaysPage(own: own),
        'can I afford it': (OwnController own) =>
            ComingDaysPage(own: own, tryPurchase: true),
        'the close': (OwnController own) => ClosePage(own: own),
        'plan': (OwnController own) => tab(PlanTab(own: own)),
        'envelopes': (OwnController own) => EnvelopesPage(own: own),
        'the cushion in days': (OwnController own) => CushionPage(own: own),
        'wishes': (OwnController own) => WishesPage(own: own),
        'what if': (OwnController own) => WhatIfPage(own: own),
        'automatic capture': (OwnController own) =>
            CaptureSettingsPage(own: own),
        'fixed payments': (OwnController own) => CommitmentsPage(own: own),
        'instalments': (OwnController own) => InstalmentsPage(own: own),
        'an instalment purchase': (OwnController own) =>
            InstalmentDetailPage(own: own, id: televisor),
        'charges to check': (OwnController own) => DetectivePage(own: own),
        'shared expenses': (OwnController own) => SharedPage(own: own),
        'a group': (OwnController own) => GroupPage(own: own, id: guatape),
        'variable income': (OwnController own) => FreelancePage(own: own),
        'trips': (OwnController own) => TripsPage(own: own),
        'a trip': (OwnController own) => TripPage(own: own, id: newYork),
        'more than one device': (OwnController own) =>
            SyncPage(own: own, keys: MemoryKeyStore()),
      };

  // Screens not yet laid out for large text: at twice the size they hold,
  // but squeeze some words into narrow columns, a letter or two a line.
  const Set<String> squeezing = <String>{
    'crypto',
    'can I afford it',
    'the close',
    'fixed payments',
    'instalments',
    'an instalment purchase',
    'charges to check',
    'shared expenses',
    'variable income',
    'trips',
    'a trip',
    'an answer about one\'s money',
  };

  for (final Locale locale in languages) {
    for (final MapEntry<String, Widget Function(OwnController)> screen
        in screens.entries) {
      for (final Brightness brightness in Brightness.values) {
        testWidgets(
          '${screen.key} holds at twice the text size, ${brightness.name}, '
          'in ${locale.languageCode}',
          (WidgetTester tester) => expectAccessible(
            tester,
            screen.value,
            brightness: brightness,
            locale: locale,
            wordsWhole: !squeezing.contains(screen.key),
          ),
        );
      }
    }
  }

  // Screens one gets to from another, with the taps that get there: the
  // first screen and onboarding, the app's frame on each tab, the sheets.
  final Map<String, Reached> reached = <String, Reached>{
    'the first screen': (
      (OwnController own) => StartPage(onOwn: () {}, onDemo: () {}),
      null,
    ),
    for (var step = 1; step <= 4; step++)
      'onboarding, step $step': (onboarding, next(step - 1)),
    'settings': (
      (OwnController own) => OwnSettingsPage(
        own: own,
        modes: modesFor(own),
        settings: AppSettings(),
      ),
      null,
    ),
    for (final (String name, IconData icon) in shellTabs)
      'the app on $name': (shell, tapTab(icon)),
    'asking about one\'s money': ((OwnController own) => _Ask(own: own), null),
    'an answer about one\'s money': (
      (OwnController own) => _Ask(own: own),
      (WidgetTester tester) async {
        final Session session = tester
            .widget<AskPage>(find.byType(AskPage))
            .session!;
        final Future<void> answered = session.ask(
          ScriptedAgent.startersFor(session.language).first,
        );
        await settle(tester);
        await tester.runAsync(() => answered);
        await settle(tester);
      },
    ),
    'where the money to spend comes from, as a sheet': (
      (OwnController own) =>
          opener((BuildContext context) => showFreeExplained(context, own)),
      openIt,
    ),
    'where a card\'s balance comes from': (
      (OwnController own) => opener(
        (BuildContext context) =>
            showAccountExplained(context, own, cardOf(own)),
      ),
      openIt,
    ),
    'where the net worth comes from, as a sheet': (
      (OwnController own) =>
          opener((BuildContext context) => showTotalExplained(context, own)),
      openIt,
    ),
    'the filters of the movements': (
      (OwnController own) => opener(
        (BuildContext context) => showMovementFilters(
          context,
          own: own,
          filter: const MovementFilter(),
          entries: visibleEntries(own),
          count: (MovementFilter _) => 12,
          onChanged: (MovementFilter _) {},
        ),
      ),
      openIt,
    ),
    'the movements, filtered': (
      (OwnController own) => sliverTab(MovementsTab(own: own)),
      (WidgetTester tester) async {
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await settle(tester);
          await tester.tap(finder);
          await settle(tester);
        }

        await tap(find.byIcon(Glyph.funnel));
        // Expenses, this month, the first account and from 50.000 up.
        await tap(find.byType(ChoiceChip).at(1));
        await tap(find.byType(ChoiceChip).at(6));
        await tap(find.byType(FilterChip).first);
        await tester.enterText(find.byType(TextField).at(1), '50000');
        await settle(tester);
        await tap(find.byType(FilledButton));
        // What narrows the list, in sight under the search.
        expect(
          find.descendant(
            of: find.byType(ActiveFilters),
            matching: find.byType(ActionChip),
          ),
          findsNWidgets(4),
        );
      },
    ),
    'a possible repeat, both side by side': (
      (OwnController own) => opener(
        (BuildContext context) =>
            showRepeatSheet(context, own: own, pair: own.repeats.values.first),
      ),
      openIt,
    ),
    'a new movement': (
      (OwnController own) =>
          opener((BuildContext context) => showEntrySheet(context, own: own)),
      openIt,
    ),
    'a movement to change': (
      (OwnController own) => opener(
        (BuildContext context) =>
            showEntrySheet(context, own: own, entry: expenseOf(own)),
      ),
      openIt,
    ),
    'a new account': (
      (OwnController own) =>
          opener((BuildContext context) => showAccountSheet(context, own: own)),
      openIt,
    ),
    'a card to change': (
      (OwnController own) => opener(
        (BuildContext context) =>
            showAccountSheet(context, own: own, account: cardOf(own)),
      ),
      openIt,
    ),
    'deleting a card, asked first': (
      (OwnController own) => opener(
        (BuildContext context) =>
            confirmLeaving(context, own, <Account>[cardOf(own)], delete: true),
      ),
      openIt,
    ),
    'the archived accounts': (
      (OwnController own) => ArchivedAccountsPage(own: own),
      (WidgetTester tester) async {
        final OwnController own = tester
            .widget<ArchivedAccountsPage>(find.byType(ArchivedAccountsPage))
            .own;
        await tester.runAsync(
          () => own.archiveAccounts(<String>{cardOf(own).id}),
        );
        await settle(tester);
      },
    ),
    'a new goal': (
      (OwnController own) =>
          opener((BuildContext context) => showGoalSheet(context, own: own)),
      openIt,
    ),
    'a new fixed payment': (
      (OwnController own) =>
          opener((BuildContext context) => showChargeSheet(context, own: own)),
      openIt,
    ),
  };

  for (final Locale locale in languages) {
    for (final MapEntry<String, Reached> screen in reached.entries) {
      for (final Brightness brightness in Brightness.values) {
        testWidgets(
          '${screen.key} holds at twice the text size, ${brightness.name}, '
          'in ${locale.languageCode}',
          (WidgetTester tester) => expectAccessible(
            tester,
            screen.value.$1,
            then: screen.value.$2,
            brightness: brightness,
            locale: locale,
            wordsWhole: !squeezing.contains(screen.key),
          ),
        );
      }
    }
  }

  // At iOS's largest text, what is looked at most: Inicio, Cuentas, Por
  // revisar, Plan and the way in. Nothing overflows, nothing that says an
  // amount or what to do is cut short, and every control can be reached.
  final Map<String, Reached> largest = <String, Reached>{
    'home': ((OwnController own) => screens['home']!(own), null),
    'accounts': ((OwnController own) => screens['accounts']!(own), null),
    'to review': ((OwnController own) => screens['to review']!(own), null),
    'plan': ((OwnController own) => screens['plan']!(own), null),
    for (final (String name, IconData icon) in shellTabs)
      'the app on $name': (shell, tapTab(icon)),
    'the first screen': reached['the first screen']!,
    for (var step = 1; step <= 4; step++)
      'onboarding, step $step': reached['onboarding, step $step']!,
  };

  for (final Locale locale in languages) {
    for (final MapEntry<String, Reached> screen in largest.entries) {
      for (final Brightness brightness in Brightness.values) {
        testWidgets(
          '${screen.key} holds at iOS\'s largest text size, '
          '${brightness.name}, in ${locale.languageCode}',
          (WidgetTester tester) => expectAccessible(
            tester,
            screen.value.$1,
            then: screen.value.$2,
            brightness: brightness,
            locale: locale,
            scale: largestText,
            nothingCut: true,
          ),
        );
      }
    }
  }

  testWidgets('at iOS\'s largest text the count of what waits to be '
      'reviewed does not hide its tray', (WidgetTester tester) async {
    await expectAccessible(
      tester,
      shell,
      brightness: Brightness.light,
      locale: const Locale('es'),
      scale: largestText,
      then: (WidgetTester tester) async {
        final Finder count = find.descendant(
          of: find.byType(Badge),
          matching: find.byType(Text),
        );
        expect(count, findsOneWidget);
        // No taller than the tray icon under it.
        expect(tester.getSize(count).height, lessThanOrEqualTo(24));
      },
    );
  });

  testWidgets('the buttons inside the lists are 48 points tall at twice '
      'the text size', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = await example();
      await followLedger(store);
      return store;
    }))!;
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => _now,
      readNative: false,
      market: ExampleMarket(now: () => _now),
    );
    addTearDown(own.dispose);
    await tester.runAsync(own.start);
    await tester.runAsync(() => own.portfolio.refresh());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: tab(AccountsTab(own: own)),
      ),
    );
    await settle(tester);

    Future<double> tall(Finder label, Type type) async {
      await tester.scrollUntilVisible(
        label,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await settle(tester);
      return tester
          .getSize(find.ancestor(of: label, matching: find.byType(type)).first)
          .height;
    }

    expect(
      await tall(find.text('Agregar cuenta'), OutlinedButton),
      greaterThanOrEqualTo(48),
    );
    expect(
      await tall(find.text('Rendimiento y ganancia'), InkWell),
      greaterThanOrEqualTo(48),
    );

    // The sources on the crypto page, rows of a panel now.
    await tester.tap(find.text('Rendimiento y ganancia'));
    await settle(tester);
    expect(find.byType(PortfolioPage), findsOneWidget);
    expect(
      await tall(find.text('Billeteras propias'), InkWell),
      greaterThanOrEqualTo(48),
    );
    expect(
      await tall(find.text('Binance').last, InkWell),
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  // Just set up: one account, nothing paid regularly yet, so the figure is
  // provisional and the first thing to do is to add the fixed payments.
  for (final Brightness brightness in Brightness.values) {
    testWidgets(
      'home, new account, holds at twice the text size, ${brightness.name}',
      (WidgetTester tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final QuincenaStore store = (await tester.runAsync(() async {
          final QuincenaStore store = QuincenaStore(
            QuincenaDatabase(NativeDatabase.memory()),
            now: () => _now,
          );
          await store.ensureCategories();
          await store.saveProfile(
            const Profile(
              name: 'Diego',
              base: Asset.cop,
              schedule: TwiceMonthly(),
            ),
          );
          await store.addAccount(
            name: 'Nequi',
            kind: AccountKind.wallet,
            asset: Asset.cop,
            opening: Decimal.parse('850000'),
          );
          return store;
        }))!;
        addTearDown(() => tester.runAsync(store.close));
        final OwnController own = OwnController(
          store,
          now: () => _now,
          readNative: false,
        );
        addTearDown(own.dispose);
        await tester.runAsync(own.start);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: quincenaTheme(brightness),
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: appLocales,
            home: tab(
              OwnHomeTab(own: own, onSeeAll: () {}, onAsk: ([String? _]) {}),
            ),
          ),
        );
        await settle(tester);

        expect(find.text('Provisional: faltan tus pagos fijos'), findsOne);
        expect(find.text('Agrega tus pagos fijos'), findsOne);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }
}
