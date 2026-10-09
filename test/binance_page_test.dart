import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/exchanges/binance_client.dart';
import 'package:quincena/exchanges/binance_link.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/binance_page.dart';

class MemoryVault implements KeyVault {
  MemoryVault([this.keys]);

  (String, String)? keys;

  @override
  Future<(String, String)?> read() async => keys;

  @override
  Future<void> write(String key, String secret) async => keys = (key, secret);

  @override
  Future<void> delete() async => keys = null;
}

/// Binance with nothing in it, behind a key that may trade.
http.Client binance({bool trading = false}) =>
    MockClient((http.Request request) async {
      final Object body = switch (request.url.path) {
        '/api/v3/time' => <String, Object?>{'serverTime': 1790960000000},
        '/sapi/v1/account/apiRestrictions' => <String, Object?>{
          'enableReading': true,
          'enableSpotAndMarginTrading': trading,
        },
        '/api/v3/account' => <String, Object?>{'balances': <Object?>[]},
        '/sapi/v1/simple-earn/flexible/position' ||
        '/sapi/v1/simple-earn/locked/position' => <String, Object?>{
          'rows': <Object?>[],
          'total': 0,
        },
        '/sapi/v1/c2c/orderMatch/listUserOrderHistory' => <String, Object?>{
          'data': <Object?>[],
        },
        '/sapi/v1/convert/tradeFlow' => <String, Object?>{'list': <Object?>[]},
        _ => <Object?>[],
      };
      return http.Response(jsonEncode(body), 200);
    });

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  Future<(OwnController, MemoryVault)> open(
    WidgetTester tester, {
    (String, String)? keys,
    bool trading = false,
    Future<void> Function(QuincenaStore store)? data,
    http.Client? client,
    Widget Function(OwnController own)? page,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final DateTime now = DateTime(2026, 10, 2, 10);
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    addTearDown(() => tester.runAsync(store.close));
    final MemoryVault vault = MemoryVault(keys);
    final OwnController own = OwnController(
      store,
      now: () => now,
      readNative: false,
      binance: BinanceLink(
        store,
        vault: vault,
        clientFor: (String k, String s) => BinanceClient(
          key: k,
          secret: s,
          client: client ?? binance(trading: trading),
        ),
        now: () => now,
      ),
    );
    addTearDown(own.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await data?.call(store);
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: page?.call(own) ?? BinancePage(own: own),
      ),
    );
    await settle(tester);
    return (own, vault);
  }

  testWidgets('the form says what it reads, what it never does, and how', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Tu cuenta de Binance, sola'), findsOneWidget);
    expect(find.text('Solo lectura'), findsOneWidget);
    expect(find.text('Solo en este dispositivo'), findsOneWidget);
    expect(find.textContaining('Gestión de API'), findsOneWidget);
    await reach(tester, find.text('Conectar'));
    expect(find.widgetWithText(TextField, 'API Key'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Secret Key'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connecting without a key says which one is missing, until it '
      'is written', (tester) async {
    final (OwnController own, MemoryVault vault) = await open(tester);
    await reach(tester, find.text('Conectar'));
    await tester.tap(find.text('Conectar'));
    await settle(tester);
    expect(find.text('Escribe tu API Key'), findsOneWidget);
    expect(find.text('Escribe tu Secret Key'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'API Key'), 'key');
    await tester.pump();
    expect(find.text('Escribe tu API Key'), findsNothing);
    expect(find.text('Escribe tu Secret Key'), findsOneWidget);
    await tester.ensureVisible(find.text('Conectar'));
    await tester.tap(find.text('Conectar'));
    await settle(tester);
    expect(find.text('Escribe tu API Key'), findsNothing);
    expect(find.text('Escribe tu Secret Key'), findsOneWidget);
    expect(own.binance.connected, isFalse);

    await tester.enterText(
      find.widgetWithText(TextField, 'Secret Key'),
      'secret',
    );
    await tester.pump();
    expect(find.text('Escribe tu Secret Key'), findsNothing);
    expect(vault.keys, isNull);
  });

  testWidgets('the Secret Key shows and hides with an eye that says which '
      'it does', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);
    await reach(tester, find.text('Conectar'));
    bool hidden() => tester
        .widget<TextField>(find.widgetWithText(TextField, 'Secret Key'))
        .obscureText;

    expect(hidden(), isTrue);
    // A screen reader says it too, as the eye's own button.
    expect(
      tester.getSemantics(find.byTooltip('Mostrar la Secret Key')),
      isSemantics(tooltip: 'Mostrar la Secret Key', isButton: true),
    );
    await tester.tap(find.byTooltip('Mostrar la Secret Key'));
    await tester.pump();
    expect(hidden(), isFalse);
    expect(find.byTooltip('Ocultar la Secret Key'), findsOneWidget);
    await tester.tap(find.byTooltip('Ocultar la Secret Key'));
    await tester.pump();
    expect(hidden(), isTrue);
    semantics.dispose();
  });

  testWidgets('a key that can trade is turned away, and said why', (
    tester,
  ) async {
    final (OwnController _, MemoryVault vault) = await open(
      tester,
      trading: true,
    );
    await reach(tester, find.text('Conectar'));
    await tester.enterText(find.widgetWithText(TextField, 'API Key'), 'key');
    await tester.enterText(
      find.widgetWithText(TextField, 'Secret Key'),
      'secret',
    );
    await tester.ensureVisible(find.text('Conectar'));
    await tester.tap(find.text('Conectar'));
    await settle(tester);
    expect(find.textContaining('Spot & Margin'), findsOneWidget);
    expect(vault.keys, isNull);
  });

  testWidgets('a read-only key connects, reads, and can be read again', (
    tester,
  ) async {
    final (OwnController own, MemoryVault vault) = await open(tester);
    await reach(tester, find.text('Conectar'));
    await tester.enterText(find.widgetWithText(TextField, 'API Key'), 'key');
    await tester.enterText(
      find.widgetWithText(TextField, 'Secret Key'),
      'secret',
    );
    await tester.ensureVisible(find.text('Conectar'));
    await tester.tap(find.text('Conectar'));
    await settle(tester);
    // Reading Binance paces its requests: wait until it is done.
    for (var i = 0; i < 100 && own.binance.syncing; i++) {
      await settle(tester);
    }
    expect(vault.keys, ('key', 'secret'));
    expect(own.binance.connected, isTrue);
    expect(
      find.text('Conectada con una llave de solo lectura'),
      findsOneWidget,
    );
    expect(find.text('Listo: nada nuevo.'), findsOneWidget);
    expect(find.text('Leer ahora'), findsOneWidget);
    expect(find.text('Desconectar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('balances kept by hand are offered to archive only once '
      'Binance brought its own', (tester) async {
    Future<void> handKept(QuincenaStore store) async {
      await store.addAccount(
        name: 'Mi USDT',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: Decimal.fromInt(500),
        institution: 'Binance',
        spendable: false,
      );
    }

    // Connected, but nothing read yet: archiving would only take the
    // balance off every total.
    final (OwnController own, MemoryVault _) = await open(
      tester,
      keys: ('key', 'secret'),
      data: handKept,
    );
    expect(own.binance.connected, isTrue);
    expect(find.text('Archivarlas'), findsNothing);
    expect(find.textContaining('llevabas a mano'), findsNothing);

    // Once Binance brought the same coin, it would count twice.
    await tester.runAsync(
      () => own.store.addAccount(
        name: 'Tether (USDT)',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: Decimal.fromInt(500),
        institution: 'Binance',
        spendable: false,
        syncRef: 'binance:USDT',
      ),
    );
    await settle(tester);
    expect(find.textContaining('llevabas a mano: Mi USDT'), findsOneWidget);
    expect(find.text('Archivarlas'), findsOneWidget);
  });

  testWidgets('archiving the balances kept by hand asks first, says what it '
      'does, and they can be brought back', (tester) async {
    Future<void> both(QuincenaStore store) async {
      await store.addAccount(
        name: 'Mi USDT',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: Decimal.fromInt(500),
        institution: 'Binance',
        spendable: false,
      );
      await store.addAccount(
        name: 'Tether (USDT)',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: Decimal.fromInt(500),
        institution: 'Binance',
        spendable: false,
        syncRef: 'binance:USDT',
      );
    }

    final (OwnController own, MemoryVault _) = await open(
      tester,
      keys: ('key', 'secret'),
      data: both,
    );
    Account? manual() => own.snapshot!.accounts
        .where((Account a) => a.name == 'Mi USDT')
        .firstOrNull;
    await reach(tester, find.text('Archivarlas'));
    await tester.tap(find.text('Archivarlas'));
    await settle(tester);
    expect(find.text('¿Archivar Mi USDT?'), findsOneWidget);
    expect(find.textContaining('evita contarlos dos veces'), findsOneWidget);
    expect(find.textContaining('«Cuentas archivadas»'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(manual()!.archived, isFalse);

    await tester.tap(find.text('Archivarlas'));
    await settle(tester);
    await tester.tap(find.text('Archivar').last);
    await settle(tester);
    expect(manual()!.archived, isTrue);
    expect(own.archivedAccounts.map((Account a) => a.name), <String>[
      'Mi USDT',
    ]);
    await tester.runAsync(() => own.restoreAccount(manual()!.id));
    await settle(tester);
    expect(manual()!.archived, isFalse);
  });

  testWidgets('the row among the sources says a read failed, not only the '
      'page', (tester) async {
    // Binance stopped taking the key since the last good read.
    final http.Client refused = MockClient(
      (http.Request request) async => request.url.path == '/api/v3/time'
          ? http.Response(jsonEncode(<String, Object?>{'serverTime': 1}), 200)
          : http.Response(
              '{"code":-2015,"msg":"Invalid API-key, IP, or permissions."}',
              401,
            ),
    );
    Future<void> readBefore(QuincenaStore store) => store.setSetting(
      'binance',
      jsonEncode(<String, Object?>{
        'syncedAt': DateTime(2026, 10, 2, 9, 40).toIso8601String(),
      }),
    );
    final (OwnController own, MemoryVault _) = await open(
      tester,
      keys: ('key', 'secret'),
      data: readBefore,
      client: refused,
      page: (OwnController own) =>
          Scaffold(body: BinanceCard(own: own, compact: true)),
    );
    await tester.runAsync(own.binance.load);
    await settle(tester);
    expect(find.textContaining('Leída 2 oct · 9:40'), findsOneWidget);

    await tester.runAsync(own.binance.sync);
    await settle(tester);
    expect(own.binance.problem, isNotNull);
    expect(find.textContaining('Leída 2 oct'), findsNothing);
    expect(
      find.textContaining('No se pudo leer. Última lectura: 2 oct · 9:40'),
      findsOneWidget,
    );
  });

  testWidgets('the row says Binance could not be read even once', (
    tester,
  ) async {
    final (OwnController own, MemoryVault _) = await open(
      tester,
      keys: ('key', 'secret'),
      client: MockClient((_) async => http.Response('', 500)),
      page: (OwnController own) =>
          Scaffold(body: BinanceCard(own: own, compact: true)),
    );
    // As opening the crypto page does: never read, so it reads now.
    await tester.runAsync(
      () => own.binance.syncIfOlder(const Duration(minutes: 30)),
    );
    await settle(tester);
    expect(own.binance.problem, isNotNull);
    expect(find.text('Aún sin leer'), findsNothing);
    expect(find.text('No se ha podido leer todavía'), findsOneWidget);
  });
}

/// Scrolls the page until [target] shows.
Future<void> reach(WidgetTester tester, Finder target) => tester
    .scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }
}
