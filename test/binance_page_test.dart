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
          client: binance(trading: trading),
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
        home: BinancePage(own: own),
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
