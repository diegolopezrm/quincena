import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../store/store.dart';
import 'address_checks.dart';

/// The blockchains whose addresses Quincena reads.
enum Chain {
  bitcoin('Bitcoin'),
  ethereum('Ethereum'),
  tron('TRON');

  const Chain(this.label);

  final String label;

  static Chain? parse(String value) {
    for (final Chain c in values) {
      if (c.name == value) return c;
    }
    return null;
  }

  /// Whether [address] has the shape of one of this chain's addresses.
  bool accepts(String address) {
    final String a = address.trim();
    return switch (this) {
      Chain.bitcoin => RegExp(
        r'^(bc1[ac-hj-np-z02-9]{11,71}|[13][a-km-zA-HJ-NP-Z1-9]{25,34})$',
      ).hasMatch(a),
      Chain.ethereum => RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(a),
      Chain.tron => RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(a),
    };
  }

  /// Whether [address], of this chain's shape, also carries its checksum:
  /// a character changed or left out in copying it breaks it. An Ethereum
  /// address in one case has none to check.
  bool intact(String address) {
    final String a = address.trim();
    return switch (this) {
      Chain.bitcoin =>
        a.toLowerCase().startsWith('bc1')
            ? bech32Intact(a)
            : switch (base58Check(a)) {
                final List<int> p => p.length == 21 && (p[0] == 0 || p[0] == 5),
                null => false,
              },
      Chain.ethereum => eip55Intact(a),
      Chain.tron => switch (base58Check(a)) {
        final List<int> p => p.length == 21 && p[0] == 0x41,
        null => false,
      },
    };
  }

  /// The chain [address] is on by how it starts: `bc1`, `1` or `3` for
  /// Bitcoin, `0x` for Ethereum, `T` for TRON. Null while it says none.
  static Chain? guess(String address) {
    final String a = address.trim();
    if (a.startsWith('0x') || a.startsWith('0X')) return Chain.ethereum;
    if (a.startsWith('T')) return Chain.tron;
    if (a.toLowerCase().startsWith('bc1') ||
        a.startsWith('1') ||
        a.startsWith('3')) {
      return Chain.bitcoin;
    }
    return null;
  }
}

/// What became of following a wallet.
enum Follow {
  /// It was read, and is followed from now on.
  done,

  /// Its chain's service said there is no such address.
  unknownAddress,

  /// Its chain's service could not be reached: no connection, or no answer
  /// in time.
  offline,

  /// Its chain's service answered with an error of its own.
  failed,
}

/// A chain's service answered, and said no.
class ChainRefused implements Exception {
  const ChainRefused(this.status, this.uri);

  /// The HTTP status; 400 too for a node that found the address invalid.
  final int status;
  final Uri uri;

  /// The address itself was refused: there is no such one on the chain.
  bool get address => status == 400 || status == 422;

  @override
  String toString() => 'Refused, $status: $uri';
}

/// A wallet the person holds the keys to, read by its public address.
@immutable
class WalletAddress {
  const WalletAddress({
    required this.chain,
    required this.address,
    required this.label,
  });

  factory WalletAddress.fromJson(Map<String, Object?> json) => WalletAddress(
    chain: Chain.parse('${json['chain']}') ?? Chain.bitcoin,
    address: '${json['address']}',
    label: '${json['label'] ?? ''}',
  );

  final Chain chain;
  final String address;

  /// What the person calls it: Ledger, Trust Wallet, MetaMask.
  final String label;

  Map<String, Object?> toJson() => <String, Object?>{
    'chain': chain.name,
    'address': address,
    'label': label,
  };

  /// The address shortened for a screen: `bc1qexa…0lmg5w`.
  String get short => address.length <= 14
      ? address
      : '${address.substring(0, 7)}…${address.substring(address.length - 6)}';

  /// What marks the account that holds [asset] at this address.
  String syncRef(String asset) => 'wallet:${chain.name}:$address:$asset';

  @override
  bool operator ==(Object other) =>
      other is WalletAddress &&
      other.chain == chain &&
      other.address == address;

  @override
  int get hashCode => Object.hash(chain, address);
}

/// Tokens read on each chain besides its own coin, with their contract and
/// how many decimals they count in.
const Map<Chain, List<(String, String, int)>> _tokens =
    <Chain, List<(String, String, int)>>{
      Chain.ethereum: <(String, String, int)>[
        ('USDT', '0xdAC17F958D2ee523a2206206994597C13D831ec7', 6),
        ('USDC', '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', 6),
      ],
      Chain.tron: <(String, String, int)>[
        ('USDT', 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t', 6),
        ('USDC', 'TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8', 6),
      ],
    };

/// Reads balances from public block explorers and nodes that need no key
/// and answer a browser too: mempool.space for Bitcoin, a public Ethereum
/// node, and TronGrid.
class ChainReader {
  ChainReader({http.Client? client, this.timeout = const Duration(seconds: 12)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static final Uri _ethereum = Uri.https('ethereum-rpc.publicnode.com', '/');

  /// What [wallet] holds of each asset: its chain's coin and the dollar
  /// stablecoins on it. An asset it holds none of is left out.
  Future<Map<String, Decimal>> balances(WalletAddress wallet) async {
    final Map<String, Decimal> out = switch (wallet.chain) {
      Chain.bitcoin => await _bitcoin(wallet.address),
      Chain.ethereum => await _ethereumBalances(wallet.address),
      Chain.tron => await _tron(wallet.address),
    };
    out.removeWhere((String _, Decimal v) => v == Decimal.zero);
    return out;
  }

  Future<Map<String, Decimal>> _bitcoin(String address) async {
    final Map<String, Object?> body =
        await _get(Uri.https('mempool.space', '/api/address/$address'))
            as Map<String, Object?>;
    int sats(String key) {
      final Map<Object?, Object?> stats =
          (body[key] as Map<Object?, Object?>?) ?? const <Object?, Object?>{};
      return ((stats['funded_txo_sum'] as num?) ?? 0).toInt() -
          ((stats['spent_txo_sum'] as num?) ?? 0).toInt();
    }

    return <String, Decimal>{
      'BTC': _scaled(
        BigInt.from(sats('chain_stats') + sats('mempool_stats')),
        8,
      ),
    };
  }

  Future<Map<String, Decimal>> _ethereumBalances(String address) async {
    final String padded = address.substring(2).toLowerCase().padLeft(64, '0');
    final Map<String, Decimal> out = <String, Decimal>{
      'ETH': _scaled(
        _hex(await _rpc('eth_getBalance', <Object?>[address, 'latest'])),
        18,
      ),
    };
    for (final (String asset, String contract, int decimals)
        in _tokens[Chain.ethereum]!) {
      out[asset] = _scaled(
        _hex(
          await _rpc('eth_call', <Object?>[
            <String, String>{'to': contract, 'data': '0x70a08231$padded'},
            'latest',
          ]),
        ),
        decimals,
      );
    }
    return out;
  }

  Future<Object?> _rpc(String method, List<Object?> params) async {
    final http.Response response = await _client
        .post(
          _ethereum,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ChainRefused(response.statusCode, _ethereum);
    }
    final Object? body = jsonDecode(response.body);
    if (body is! Map || body['error'] != null) {
      // Invalid params: the node found the address wrong.
      final Object? error = body is Map ? body['error'] : null;
      throw ChainRefused(
        error is Map && error['code'] == -32602 ? 400 : 502,
        _ethereum,
      );
    }
    return body['result'];
  }

  Future<Map<String, Decimal>> _tron(String address) async {
    final Map<String, Object?> body =
        await _get(Uri.https('api.trongrid.io', '/v1/accounts/$address'))
            as Map<String, Object?>;
    final List<Object?> data =
        (body['data'] as List<Object?>?) ?? const <Object?>[];
    // An address that never received anything has no account yet.
    if (data.isEmpty) return <String, Decimal>{};
    final Map<Object?, Object?> account = data.first! as Map<Object?, Object?>;
    final Map<String, String> trc20 = <String, String>{
      for (final Object? t
          in (account['trc20'] as List<Object?>?) ?? const <Object?>[])
        if (t is Map)
          for (final MapEntry<Object?, Object?> e in t.entries)
            '${e.key}': '${e.value}',
    };
    return <String, Decimal>{
      'TRX': _scaled(BigInt.from((account['balance'] as num?) ?? 0), 6),
      for (final (String asset, String contract, int decimals)
          in _tokens[Chain.tron]!)
        asset: _scaled(
          BigInt.tryParse(trc20[contract] ?? '0') ?? BigInt.zero,
          decimals,
        ),
    };
  }

  static BigInt _hex(Object? value) {
    final String s = '$value';
    if (!s.startsWith('0x') || s.length <= 2) return BigInt.zero;
    return BigInt.parse(s.substring(2), radix: 16);
  }

  static Decimal _scaled(BigInt units, int decimals) =>
      (Decimal.fromBigInt(units) / Decimal.ten.pow(decimals).toDecimal())
          .toDecimal(scaleOnInfinitePrecision: decimals);

  Future<Object?> _get(Uri uri) async {
    final http.Response response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw ChainRefused(response.statusCode, uri);
    }
    return jsonDecode(response.body);
  }

  void close() => _client.close();
}

/// Brings what each wallet holds into the person's accounts: one account
/// per asset, under the wallet's name, kept at exactly what the chain says.
/// The first time, that is its opening balance; after that, a change the
/// app has no movement for is an adjustment with no cost.
class WalletSync {
  WalletSync(
    this.store, {
    this.adjustment = 'Ajuste con la billetera',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final QuincenaStore store;

  /// What an adjustment says it is, in the person's language.
  final String adjustment;
  final DateTime Function() _now;

  /// Returns how many accounts were created.
  Future<int> apply(WalletAddress wallet, Map<String, Decimal> held) async {
    final List<Account> accounts = await store.accounts(archived: true);
    final Map<String, Account> synced = <String, Account>{
      for (final Account a in accounts)
        if (a.syncRef != null) a.syncRef!: a,
    };
    var created = 0;
    final DateTime now = _now();
    final List<Entry> entries = await store.entries();
    // Assets it held before and holds no more are adjusted to zero too.
    final Set<String> assets = <String>{
      ...held.keys,
      for (final String ref in synced.keys)
        if (ref.startsWith('wallet:${wallet.chain.name}:${wallet.address}:'))
          ref.split(':').last,
    };
    for (final String asset in assets) {
      final Decimal real = held[asset] ?? Decimal.zero;
      final Account? known = synced[wallet.syncRef(asset)];
      if (known == null) {
        if (real == Decimal.zero) continue;
        final Asset a = Asset.of(asset);
        await store.addAccount(
          name: a.name('es') == a.code ? a.code : a.name('es'),
          kind: AccountKind.wallet,
          asset: a,
          opening: real,
          institution: wallet.label.isEmpty ? wallet.chain.label : wallet.label,
          spendable: false,
          syncRef: wallet.syncRef(asset),
        );
        created++;
        continue;
      }
      final Money kept = balancesOf(<Account>[known], entries, now)[known.id]!;
      final Decimal gap = real - kept.amount;
      if (gap == Decimal.zero) continue;
      // Numbered, not timed: two devices that see the same change number
      // it alike, and syncing keeps one.
      final int made = entries
          .where(
            (Entry e) =>
                e.accountId == known.id && e.kind == EntryKind.adjustment,
          )
          .length;
      await store.addEntry(
        accountId: known.id,
        amount: gap,
        kind: EntryKind.adjustment,
        date: now,
        payee: adjustment,
        source: 'wallet',
        sourceRef: '${wallet.syncRef(asset)}:adjust:${made + 1}',
      );
    }
    return created;
  }
}

/// The wallets the person follows, read when the crypto screens open.
class WalletLink extends ChangeNotifier {
  WalletLink(
    this.store, {
    ChainReader Function()? readerFor,
    DateTime Function()? now,
  }) : _readerFor = readerFor ?? ChainReader.new,
       _now = now ?? DateTime.now;

  final QuincenaStore store;
  final ChainReader Function() _readerFor;
  final DateTime Function() _now;

  /// What adjustments say they are, in the person's language.
  String adjustment = 'Ajuste con la billetera';

  static const String _setting = 'wallets';

  List<WalletAddress> _wallets = const <WalletAddress>[];
  DateTime? _syncedAt;
  bool _syncing = false;
  bool _loaded = false;
  bool _read = false;
  String? _failed;

  List<WalletAddress> get wallets => _wallets;
  DateTime? get syncedAt => _syncedAt;
  bool get syncing => _syncing;

  /// Whether [wallets] was read from the device yet: until then it is
  /// empty whatever the device keeps.
  bool get loaded => _read;

  /// Whether [account] holds a coin of an address still followed, rather
  /// than one stopped, whose account stays as the person's own.
  bool follows(Account account) => _wallets.any(
    (WalletAddress w) =>
        account.syncRef?.startsWith('wallet:${w.chain.name}:${w.address}:') ??
        false,
  );

  /// The address of the last wallet that could not be read, if any.
  String? get failed => _failed;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final String? saved = await store.setting(_setting);
    if (saved != null) {
      final Object? json = jsonDecode(saved);
      if (json is Map) {
        _wallets = <WalletAddress>[
          for (final Object? w
              in (json['wallets'] as List<Object?>?) ?? const <Object?>[])
            if (w is Map) WalletAddress.fromJson(w.cast<String, Object?>()),
        ];
        _syncedAt = DateTime.tryParse('${json['syncedAt']}');
      }
    }
    _read = true;
    notifyListeners();
  }

  Future<void> _save() => store.setSetting(
    _setting,
    jsonEncode(<String, Object?>{
      'wallets': <Object?>[for (final WalletAddress w in _wallets) w.toJson()],
      'syncedAt': _syncedAt?.toIso8601String(),
    }),
  );

  /// Follows [wallet] and reads it now. When it could not be read it is not
  /// followed, and what is returned says why: the address, the connection
  /// or the service.
  Future<Follow> add(WalletAddress wallet) async {
    await load();
    if (_wallets.contains(wallet)) return Follow.done;
    final ChainReader reader = _readerFor();
    try {
      final Map<String, Decimal> held = await reader.balances(wallet);
      await WalletSync(
        store,
        adjustment: adjustment,
        now: _now,
      ).apply(wallet, held);
    } on Object catch (e) {
      // An error can quote what it failed on; a release build keeps it
      // out of the device's logs.
      if (kDebugMode) debugPrint('Wallet could not be read: $e');
      return switch (e) {
        ChainRefused(address: true) => Follow.unknownAddress,
        ChainRefused() => Follow.failed,
        TimeoutException() || http.ClientException() => Follow.offline,
        _ => Follow.failed,
      };
    } finally {
      reader.close();
    }
    _wallets = <WalletAddress>[..._wallets, wallet];
    await _save();
    notifyListeners();
    return Follow.done;
  }

  /// Stops following [wallet]. Its accounts stay, as the person's own.
  Future<void> remove(WalletAddress wallet) async {
    _wallets = <WalletAddress>[
      for (final WalletAddress w in _wallets)
        if (w != wallet) w,
    ];
    // What could not be read of it is no news once it is not followed.
    if (!_wallets.any((WalletAddress w) => w.address == _failed)) {
      _failed = null;
    }
    await _save();
    notifyListeners();
  }

  /// Follows [wallet] again at [index], without reading it: how stopping
  /// is taken back. Its accounts stayed, and the next read updates them.
  Future<void> followAgain(WalletAddress wallet, int index) async {
    if (_wallets.contains(wallet)) return;
    _wallets = <WalletAddress>[..._wallets]
      ..insert(index.clamp(0, _wallets.length), wallet);
    await _save();
    notifyListeners();
  }

  /// Reads every wallet again, unless they were read within [age].
  Future<void> syncIfOlder(Duration age) async {
    await load();
    final DateTime? at = _syncedAt;
    if (_wallets.isEmpty || (at != null && _now().difference(at) < age)) return;
    await sync();
  }

  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    _failed = null;
    notifyListeners();
    final ChainReader reader = _readerFor();
    try {
      for (final WalletAddress w in _wallets) {
        try {
          await WalletSync(
            store,
            adjustment: adjustment,
            now: _now,
          ).apply(w, await reader.balances(w));
        } on Object catch (e) {
          if (kDebugMode) debugPrint('Wallet ${w.short} could not be read: $e');
          _failed = w.address;
        }
      }
      // When they were read is when every one of them was: a read that
      // failed leaves the last good one, and the balances it brought.
      if (_failed == null) _syncedAt = _now();
      await _save();
    } finally {
      reader.close();
      _syncing = false;
      notifyListeners();
    }
  }
}
