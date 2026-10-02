import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/exchanges/binance_client.dart';
import 'package:quincena/exchanges/binance_link.dart';
import 'package:quincena/exchanges/binance_sync.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

/// Binance as a test sees it: one answer per path, and every request kept.
class FakeBinance {
  FakeBinance(this.answers);

  final Map<String, Object?> answers;
  final List<http.Request> asked = <http.Request>[];

  MockClient get client => MockClient((http.Request request) async {
    asked.add(request);
    if (request.url.path == '/api/v3/time') {
      return http.Response(
        jsonEncode(<String, Object?>{'serverTime': 1790960000000}),
        200,
      );
    }
    if (!request.headers.containsKey('X-MBX-APIKEY') ||
        !request.url.queryParameters.containsKey('signature')) {
      return http.Response(
        '{"code":-2014,"msg":"API-key format invalid."}',
        401,
      );
    }
    final Object? answer = answers[request.url.path];
    if (answer is http.Response) return answer;
    return http.Response(jsonEncode(answer ?? <Object?>[]), 200);
  });
}

class MemoryVault implements KeyVault {
  (String, String)? keys;

  @override
  Future<(String, String)?> read() async => keys;

  @override
  Future<void> write(String key, String secret) async => keys = (key, secret);

  @override
  Future<void> delete() async => keys = null;
}

final DateTime june = DateTime(2026, 6, 1, 10);
final DateTime july = DateTime(2026, 7, 1, 10);
final DateTime august = DateTime(2026, 8, 1, 10);

Map<String, Object?> account(List<Map<String, String>> balances) =>
    <String, Object?>{'balances': balances};

/// A year of history: tether bought on P2P with pesos, half of it turned
/// into bitcoin, a deposit of solana and a withdrawal of tether.
Map<String, Object?> history() => <String, Object?>{
  '/api/v3/account': account(<Map<String, String>>[
    <String, String>{'asset': 'BTC', 'free': '0.005', 'locked': '0'},
    <String, String>{'asset': 'LDUSDT', 'free': '50', 'locked': '0'},
  ]),
  '/sapi/v1/asset/get-funding-asset': <Object?>[
    <String, String>{
      'asset': 'USDT',
      'free': '440',
      'locked': '0',
      'freeze': '0',
      'withdrawing': '0',
    },
  ],
  '/sapi/v1/simple-earn/flexible/position': <String, Object?>{
    'rows': <Object?>[
      <String, String>{'asset': 'USDT', 'totalAmount': '50'},
    ],
    'total': 1,
  },
  '/sapi/v1/simple-earn/locked/position': <String, Object?>{
    'rows': <Object?>[],
    'total': 0,
  },
  '/sapi/v1/c2c/orderMatch/listUserOrderHistory': <String, Object?>{
    'data': <Object?>[
      <String, Object?>{
        'orderNumber': '111',
        'tradeType': 'BUY',
        'asset': 'USDT',
        'fiat': 'COP',
        'amount': '1000',
        'totalPrice': '4100000',
        'orderStatus': 'COMPLETED',
        'createTime': june.millisecondsSinceEpoch,
      },
      <String, Object?>{
        'orderNumber': '112',
        'tradeType': 'BUY',
        'asset': 'USDT',
        'fiat': 'COP',
        'amount': '10',
        'totalPrice': '41000',
        'orderStatus': 'CANCELLED',
        'createTime': june.millisecondsSinceEpoch,
      },
    ],
  },
  '/sapi/v1/convert/tradeFlow': <String, Object?>{
    'list': <Object?>[
      <String, Object?>{
        'orderId': 940708407462087195,
        'orderStatus': 'SUCCESS',
        'fromAsset': 'USDT',
        'fromAmount': '500',
        'toAsset': 'BTC',
        'toAmount': '0.005',
        'createTime': july.millisecondsSinceEpoch,
      },
    ],
  },
  '/sapi/v1/capital/deposit/hisrec': <Object?>[
    <String, Object?>{
      'id': 'd1',
      'amount': '2',
      'coin': 'SOL',
      'status': 1,
      'insertTime': august.millisecondsSinceEpoch,
    },
  ],
  '/sapi/v1/capital/withdraw/history': <Object?>[
    <String, Object?>{
      'id': 'w1',
      'amount': '9',
      'transactionFee': '1',
      'coin': 'USDT',
      'status': 6,
      'applyTime': '2026-08-15 12:00:00',
    },
  ],
};

void main() {
  test('requests are signed as Binance documents it', () {
    expect(
      BinanceClient.sign(
        'symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1'
            '&price=0.1&recvWindow=5000&timestamp=1499827319559',
        'NhqPtmdSJYdKjVHjA7PZj4Mge3R5YNiP1e3UZjInClVN65XAbvqqM6A7H5fATj0j',
      ),
      'c8db56825ae71d6d79447849e617115f4a920fa2acdcab2b053c4b2838bd6b71',
    );
  });

  test('a key is read-only only when it can do nothing else', () {
    const KeyPermissions reading = KeyPermissions(<String, bool>{
      'ipRestrict': false,
      'enableReading': true,
      'enableWithdrawals': false,
      'enableSpotAndMarginTrading': false,
      'enableFixReadOnly': true,
    });
    expect(reading.readOnly, isTrue);
    const KeyPermissions trading = KeyPermissions(<String, bool>{
      'enableReading': true,
      'enableSpotAndMarginTrading': true,
      'enableWithdrawals': true,
    });
    expect(trading.readOnly, isFalse);
    expect(trading.beyondReading, <String>[
      'enableSpotAndMarginTrading',
      'enableWithdrawals',
    ]);
    expect(const KeyPermissions(<String, bool>{}).readOnly, isFalse);
  });

  test('every wallet adds up, and history becomes events', () async {
    final FakeBinance binance = FakeBinance(history());
    final BinanceReader reader = BinanceReader(
      BinanceClient(key: 'k', secret: 's', client: binance.client),
      pause: Duration.zero,
    );
    final BinanceReading reading = await reader.read(DateTime(2026, 1, 1));
    // Spot, funding and Simple Earn together; the LD position is not
    // counted twice.
    expect(reading.balances, <String, Decimal>{
      'BTC': d('0.005'),
      'USDT': d('490'),
    });
    final List<String> refs = <String>[
      for (final BinanceEvent e in reading.events) e.ref,
    ];
    expect(
      refs,
      containsAllInOrder(<String>[
        'binance:p2p:111',
        'binance:convert:940708407462087195',
        'binance:deposit:d1',
        'binance:withdraw:w1',
      ]),
    );
    expect(refs, isNot(contains('binance:p2p:112')));
    final Transfer out = reading.events.whereType<Transfer>().firstWhere(
      (Transfer t) => !t.deposit,
    );
    expect(out.amount, d('10'));
  });

  group('a sync', () {
    late QuincenaStore store;

    setUp(() async {
      store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => DateTime(2026, 10, 2),
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
      );
    });

    tearDown(() => store.close());

    Future<BinanceReading> read() => BinanceReader(
      BinanceClient(
        key: 'k',
        secret: 's',
        client: FakeBinance(history()).client,
      ),
      pause: Duration.zero,
    ).read(DateTime(2026, 1, 1));

    test('records each event once, in accounts of its own', () async {
      final BinanceSync sync = BinanceSync(
        store,
        now: () => DateTime(2026, 10, 2),
      );
      final SyncReport first = await sync.apply(await read());
      expect(first.accountsCreated, 3);
      expect(first.movementsAdded, 4);

      final List<Account> accounts = await store.accounts();
      expect(accounts.map((Account a) => a.syncRef).toSet(), <String>{
        'binance:USDT',
        'binance:BTC',
        'binance:SOL',
      });
      expect(accounts.every((Account a) => a.institution == 'Binance'), isTrue);

      final List<Entry> entries = await store.entries();
      final Entry p2p = entries.firstWhere(
        (Entry e) => e.sourceRef == 'binance:p2p:111',
      );
      expect(p2p.cost, Money(d('4100000'), Asset.cop));
      expect(p2p.amount, d('1000'));

      final SyncReport again = await sync.apply(await read());
      expect(again.movementsAdded, 0);
      expect((await store.entries()).length, entries.length);
    });

    test('ends with exactly what Binance holds', () async {
      final BinanceSync sync = BinanceSync(
        store,
        now: () => DateTime(2026, 10, 2),
      );
      await sync.apply(await read());
      final List<Account> accounts = await store.accounts();
      final Map<String, Money> balances = balancesOf(
        accounts,
        await store.entries(),
        DateTime(2026, 10, 2),
      );
      Decimal of(String asset) =>
          balances[accounts
                  .firstWhere((Account a) => a.syncRef == 'binance:$asset')
                  .id]!
              .amount;
      expect(of('USDT'), d('490'));
      expect(of('BTC'), d('0.005'));
      // Deposited, then not in any wallet any more.
      expect(of('SOL'), d('0'));
    });

    test('a later difference is an adjustment, not a new opening', () async {
      final BinanceSync sync = BinanceSync(
        store,
        now: () => DateTime(2026, 10, 2),
      );
      await sync.apply(await read());
      final BinanceReading later = await read();
      final SyncReport report = await sync.apply(
        BinanceReading(
          balances: <String, Decimal>{...later.balances, 'USDT': d('491.5')},
          events: later.events,
        ),
      );
      expect(report.adjusted, 1);
      final Entry adjustment = (await store.entries()).firstWhere(
        (Entry e) => e.kind == EntryKind.adjustment,
      );
      expect(adjustment.amount, d('1.5'));
      expect(adjustment.cost, isNull);
    });
  });

  group('linking', () {
    late QuincenaStore store;

    setUp(() async {
      store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => DateTime(2026, 10, 2),
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
      );
    });

    tearDown(() => store.close());

    test('a key that can trade is refused and not kept', () async {
      final MemoryVault vault = MemoryVault();
      final FakeBinance binance = FakeBinance(<String, Object?>{
        '/sapi/v1/account/apiRestrictions': <String, Object?>{
          'enableReading': true,
          'enableSpotAndMarginTrading': true,
        },
      });
      final BinanceLink link = BinanceLink(
        store,
        vault: vault,
        clientFor: (String k, String s) =>
            BinanceClient(key: k, secret: s, client: binance.client),
      );
      expect(await link.connect('key', 'secret'), ConnectOutcome.notReadOnly);
      expect(vault.keys, isNull);
      expect(link.connected, isFalse);
      expect(link.refused, <String>['enableSpotAndMarginTrading']);
    });

    test('a read-only key is kept and the account comes in', () async {
      final MemoryVault vault = MemoryVault();
      final FakeBinance binance = FakeBinance(<String, Object?>{
        ...history(),
        '/sapi/v1/account/apiRestrictions': <String, Object?>{
          'enableReading': true,
          'enableWithdrawals': false,
        },
      });
      final BinanceLink link = BinanceLink(
        store,
        vault: vault,
        clientFor: (String k, String s) =>
            BinanceClient(key: k, secret: s, client: binance.client),
        now: () => DateTime(2026, 10, 2),
      );
      expect(await link.connect(' key ', ' secret '), ConnectOutcome.connected);
      expect(vault.keys, ('key', 'secret'));
      expect(link.problem, isNull);
      expect(link.report!.movementsAdded, 4);
      expect(link.syncedAt, DateTime(2026, 10, 2));
      // The secret travels only as a signature.
      for (final http.Request r in binance.asked) {
        expect(r.url.toString(), isNot(contains('secret')));
      }
    });

    test('a key Binance does not take is said so', () async {
      final BinanceLink link = BinanceLink(
        store,
        vault: MemoryVault(),
        clientFor: (String k, String s) => BinanceClient(
          key: k,
          secret: s,
          client: FakeBinance(<String, Object?>{
            '/sapi/v1/account/apiRestrictions': http.Response(
              '{"code":-2015,"msg":"Invalid API-key, IP, or permissions."}',
              401,
            ),
          }).client,
        ),
      );
      expect(await link.connect('key', 'secret'), ConnectOutcome.badKey);
    });
  });
}
