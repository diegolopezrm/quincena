import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/exchanges/wallets.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

// Every address here is made up; only its shape is real.
const WalletAddress btc = WalletAddress(
  chain: Chain.bitcoin,
  address: 'bc1qexampqe2wa77etq9yxz8c2kdu3ts6hrv0lmg5w',
  label: 'Ledger',
);
const WalletAddress eth = WalletAddress(
  chain: Chain.ethereum,
  address: '0x5a7c3e2f9d1b8a6c4e0f2a9b7d5c3e1f0a8b6c4d',
  label: 'MetaMask',
);
const WalletAddress tron = WalletAddress(
  chain: Chain.tron,
  address: 'TQuincenaExampLeWa11etAddr3sZq8Kxy',
  label: 'Trust Wallet',
);

/// The chains as a test sees them: [sats] on Bitcoin, half an ether and
/// some dollars on Ethereum, tether on TRON.
http.Client chains({int sats = 150000}) => MockClient((
  http.Request request,
) async {
  final String host = request.url.host;
  if (host == 'mempool.space') {
    return http.Response(
      jsonEncode(<String, Object?>{
        'chain_stats': <String, int>{
          'funded_txo_sum': sats + 50000,
          'spent_txo_sum': 50000,
        },
        'mempool_stats': <String, int>{'funded_txo_sum': 0, 'spent_txo_sum': 0},
      }),
      200,
    );
  }
  if (host == 'ethereum-rpc.publicnode.com') {
    final Map<String, Object?> body =
        jsonDecode(request.body) as Map<String, Object?>;
    final String result = body['method'] == 'eth_getBalance'
        // Half an ether, in wei.
        ? '0x6f05b59d3b20000'
        : ((body['params']! as List<Object?>).first! as Map)['to'] ==
              '0xdAC17F958D2ee523a2206206994597C13D831ec7'
        // 250 tether, in millionths.
        ? '0x${250000000.toRadixString(16)}'
        : '0x0';
    return http.Response(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 1,
        'result': result,
      }),
      200,
    );
  }
  if (host == 'api.trongrid.io') {
    return http.Response(
      jsonEncode(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'balance': 12000000,
            'trc20': <Object?>[
              <String, String>{
                'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': '1500000000',
              },
            ],
          },
        ],
      }),
      200,
    );
  }
  return http.Response('not found', 404);
});

void main() {
  test('addresses are checked against each chain\'s shape', () {
    expect(Chain.bitcoin.accepts(btc.address), isTrue);
    expect(Chain.bitcoin.accepts('1QuincenaExampLeAddress2x9ZkRwT'), isTrue);
    expect(Chain.ethereum.accepts(eth.address), isTrue);
    expect(Chain.tron.accepts(tron.address), isTrue);
    expect(Chain.ethereum.accepts(tron.address), isFalse);
    expect(Chain.bitcoin.accepts('mi billetera'), isFalse);
    expect(btc.short, 'bc1qexa…0lmg5w');
  });

  test('each chain\'s coin and its dollar tokens are read', () async {
    final ChainReader reader = ChainReader(client: chains());
    expect(await reader.balances(btc), <String, Decimal>{'BTC': d('0.0015')});
    expect(await reader.balances(eth), <String, Decimal>{
      'ETH': d('0.5'),
      'USDT': d('250'),
    });
    expect(await reader.balances(tron), <String, Decimal>{
      'TRX': d('12'),
      'USDT': d('1500'),
    });
  });

  group('following a wallet', () {
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

    test('gives each asset an account under the wallet\'s name', () async {
      final WalletLink link = WalletLink(
        store,
        readerFor: () => ChainReader(client: chains()),
        now: () => DateTime(2026, 10, 2),
      );
      expect(await link.add(eth), isTrue);
      final List<Account> accounts = await store.accounts();
      expect(accounts.map((Account a) => a.asset.code).toSet(), <String>{
        'ETH',
        'USDT',
      });
      expect(
        accounts.every((Account a) => a.institution == 'MetaMask'),
        isTrue,
      );
      expect(
        accounts.firstWhere((Account a) => a.asset == Asset.eth).opening,
        d('0.5'),
      );
      expect(link.wallets, <WalletAddress>[eth]);
    });

    test('a change on the chain becomes an adjustment', () async {
      var sats = 150000;
      final WalletLink link = WalletLink(
        store,
        readerFor: () => ChainReader(client: chains(sats: sats)),
        now: () => DateTime(2026, 10, 2),
      );
      await link.add(btc);
      sats = 200000;
      await link.sync();
      final Account account = (await store.accounts()).single;
      final Map<String, Money> balances = balancesOf(
        <Account>[account],
        await store.entries(),
        DateTime(2026, 10, 2),
      );
      expect(balances[account.id]!.amount, d('0.002'));
      final Entry adjustment = (await store.entries()).single;
      expect(adjustment.kind, EntryKind.adjustment);
      expect(adjustment.amount, d('0.0005'));
      // Read again with nothing new: nothing changes.
      await link.sync();
      expect((await store.entries()).length, 1);
    });

    test('a wallet that cannot be read is not followed', () async {
      final WalletLink link = WalletLink(
        store,
        readerFor: () => ChainReader(
          client: MockClient((_) async => http.Response('down', 503)),
        ),
      );
      expect(await link.add(btc), isFalse);
      expect(link.wallets, isEmpty);
      expect(await store.accounts(), isEmpty);
    });

    test('the wallets followed are remembered', () async {
      final WalletLink first = WalletLink(
        store,
        readerFor: () => ChainReader(client: chains()),
      );
      await first.add(tron);
      final WalletLink again = WalletLink(store);
      await again.load();
      expect(again.wallets.single.label, 'Trust Wallet');
    });
  });
}
