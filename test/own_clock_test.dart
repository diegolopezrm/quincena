// What reads the outside world does it on the app's clock: the rates it
// fetches and the Binance reads are dated by the day the app believes it
// is, not by the device's, so a test or a screenshot on another day sees
// the same thing.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rate_sources.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

void main() {
  // A day that is not the device's, whatever day the test runs on.
  final DateTime now = DateTime(2026, 10, 3, 10);

  Future<QuincenaStore> diego() async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
    return store;
  }

  test('fetched rates carry the day the app believes it is', () async {
    final List<Uri> asked = <Uri>[];
    final RateFetcher fetcher = RateFetcher(
      client: MockClient((http.Request request) async {
        asked.add(request.url);
        return switch (request.url.host) {
          'www.datos.gov.co' => http.Response(
            jsonEncode(<Object>[
              <String, String>{
                'valor': '4000',
                'vigenciadesde': '2026-10-03T00:00:00.000',
              },
            ]),
            200,
          ),
          'data-api.binance.vision' => http.Response(
            jsonEncode(<String, String>{'price': '80000'}),
            200,
          ),
          'api.frankfurter.dev' => http.Response(
            jsonEncode(<String, Object>{
              'rates': <String, double>{'EUR': 0.9},
            }),
            200,
          ),
          _ => http.Response('{}', 404),
        };
      }),
    );
    final QuincenaStore store = await diego();
    addTearDown(store.close);
    await store.addAccount(
      name: 'Bitcoin',
      kind: AccountKind.exchange,
      asset: Asset.btc,
    );
    await store.addAccount(
      name: 'Euros',
      kind: AccountKind.bank,
      asset: Asset.eur,
    );
    final OwnController own = OwnController(
      store,
      fetcher: fetcher,
      now: () => now,
      readNative: false,
    );
    // Saving the rates reloads the controller: what is still reading the
    // store finishes before the store closes.
    addTearDown(() async {
      own.dispose();
      await pumpEventQueue(times: 50);
    });
    // Opening the app fetches the rates of what is held.
    await own.start();
    while (own.refreshingRates || own.ratesFetchedAt == null) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // The TRM in force on the app's day, not the device's.
    final Uri trm = asked.firstWhere((Uri u) => u.host == 'www.datos.gov.co');
    expect(trm.queryParameters[r'$where'], contains("'2026-10-03T23:59:59'"));
    final Rate btc = own.rates
        .used(Asset.btc, Asset.cop)
        .firstWhere((Rate r) => r.asset == 'BTC');
    expect(btc.asOf, now);
    expect(own.ratesFetchedAt, now);
  });

  test('a source that gives no day is dated by the app', () async {
    final RateFetcher fetcher = RateFetcher(
      client: MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, Object>{
            'rates': <String, double>{'EUR': 0.9},
          }),
          200,
        ),
      ),
    );
    final List<Rate> rates = await fetcher.ecb(<String>['EUR'], at: now);
    expect(rates.single.asOf, now);
  });

  testWidgets('Binance read on the app\'s clock is not read again within '
      'the half hour', (tester) async {
    // The keychain, as a map, with a key in it: Binance is connected.
    final Map<String, String> keychain = <String, String>{
      'binance.key': 'llave',
      'binance.secret': 'secreto',
    };
    const MethodChannel channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall call,
    ) async {
      final Map<Object?, Object?> args =
          (call.arguments as Map<Object?, Object?>?) ?? const {};
      return switch (call.method) {
        'read' => keychain[args['key']],
        _ => null,
      };
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final QuincenaStore store = (await tester.runAsync(diego))!;
    addTearDown(() => tester.runAsync(store.close));
    // Read twenty minutes ago, by the app's clock.
    await tester.runAsync(
      () => store.setSetting(
        'binance',
        jsonEncode(<String, Object?>{
          'syncedAt': now
              .subtract(const Duration(minutes: 20))
              .toIso8601String(),
        }),
      ),
    );
    final OwnController own = OwnController(
      store,
      now: () => now,
      readNative: false,
    );
    addTearDown(own.dispose);
    var reads = 0;
    own.binance.addListener(() {
      if (own.binance.syncing) reads++;
    });
    await tester.runAsync(
      () => own.binance.syncIfOlder(const Duration(minutes: 30)),
    );
    expect(own.binance.connected, isTrue);
    expect(reads, 0);
    expect(own.binance.problem, isNull);
    expect(own.binance.syncedAt, now.subtract(const Duration(minutes: 20)));
  });
}
