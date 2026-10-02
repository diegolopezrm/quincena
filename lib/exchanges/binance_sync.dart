import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../store/store.dart';
import 'binance_client.dart';

/// Something that happened in a Binance account, read from its history.
@immutable
sealed class BinanceEvent {
  const BinanceEvent(this.ref, this.at);

  /// Unique across Binance, so a second reading never records it twice.
  final String ref;
  final DateTime at;
}

/// Crypto bought or sold for money on Binance P2P.
class P2pTrade extends BinanceEvent {
  const P2pTrade(
    super.ref,
    super.at, {
    required this.buy,
    required this.asset,
    required this.amount,
    required this.fiat,
    required this.total,
  });

  final bool buy;
  final String asset;
  final Decimal amount;
  final String fiat;
  final Decimal total;
}

/// One asset turned into another inside Binance: a conversion, or a trade
/// on the spot market.
class Swap extends BinanceEvent {
  const Swap(
    super.ref,
    super.at, {
    required this.from,
    required this.sent,
    required this.to,
    required this.received,
    this.fee,
  });

  final String from;
  final Decimal sent;
  final String to;
  final Decimal received;

  /// What Binance charged for it, in whatever asset it charged.
  final (String, Decimal)? fee;
}

/// Crypto that arrived from outside Binance, or left for outside.
class Transfer extends BinanceEvent {
  const Transfer(
    super.ref,
    super.at, {
    required this.deposit,
    required this.asset,
    required this.amount,
  });

  final bool deposit;
  final String asset;

  /// For a withdrawal, the network fee included.
  final Decimal amount;
}

/// Everything read from Binance in one pass.
@immutable
class BinanceReading {
  const BinanceReading({required this.balances, required this.events});

  /// What each asset holds now, every wallet together: spot, funding and
  /// Simple Earn.
  final Map<String, Decimal> balances;

  /// What happened in the window read, oldest first.
  final List<BinanceEvent> events;
}

/// Reads balances and history from a [BinanceClient].
class BinanceReader {
  BinanceReader(this.client, {this.pause = const Duration(milliseconds: 120)});

  final BinanceClient client;

  /// Between requests, to stay well inside Binance's limits.
  final Duration pause;

  Future<Object?> _get(
    String path, [
    Map<String, String> params = const <String, String>{},
    String method = 'GET',
  ]) async {
    final Object? body = await client.signed(
      path,
      params: params,
      method: method,
    );
    if (pause > Duration.zero) await Future<void>.delayed(pause);
    return body;
  }

  /// Every asset held, every wallet together.
  Future<Map<String, Decimal>> balances() async {
    final Map<String, Decimal> out = <String, Decimal>{};
    void add(Object? asset, List<Object?> amounts) {
      final String code = '$asset'.toUpperCase();
      var sum = Decimal.zero;
      for (final Object? a in amounts) {
        sum += Decimal.tryParse('$a') ?? Decimal.zero;
      }
      if (code.isEmpty || sum == Decimal.zero) return;
      out[code] = (out[code] ?? Decimal.zero) + sum;
    }

    final Map<String, Object?> spot =
        await _get('/api/v3/account', <String, String>{
              'omitZeroBalances': 'true',
            })
            as Map<String, Object?>;
    for (final Object? b in (spot['balances'] as List<Object?>?) ?? const []) {
      if (b is! Map) continue;
      // Old Simple Earn positions show in spot as LD-something; they are
      // read below, from Simple Earn itself.
      if ('${b['asset']}'.startsWith('LD')) continue;
      add(b['asset'], <Object?>[b['free'], b['locked']]);
    }
    final Object? funding = await _get(
      '/sapi/v1/asset/get-funding-asset',
      const <String, String>{},
      'POST',
    );
    for (final Object? b in funding is List ? funding : const <Object?>[]) {
      if (b is! Map) continue;
      add(b['asset'], <Object?>[
        b['free'],
        b['locked'],
        b['freeze'],
        b['withdrawing'],
      ]);
    }
    for (final (String path, String field) in <(String, String)>[
      ('/sapi/v1/simple-earn/flexible/position', 'totalAmount'),
      ('/sapi/v1/simple-earn/locked/position', 'amount'),
    ]) {
      try {
        var page = 1;
        while (true) {
          final Map<String, Object?> body =
              await _get(path, <String, String>{
                    'current': '$page',
                    'size': '100',
                  })
                  as Map<String, Object?>;
          final List<Object?> rows =
              (body['rows'] as List<Object?>?) ?? const <Object?>[];
          for (final Object? r in rows) {
            if (r is Map) add(r['asset'], <Object?>[r[field]]);
          }
          final int total = (body['total'] as num?)?.toInt() ?? 0;
          if (rows.isEmpty || page * 100 >= total) break;
          page++;
        }
      } on BinanceException catch (e) {
        // An account without Simple Earn, or a key that cannot see it.
        if (e.badKey || e.limited) rethrow;
      }
    }
    return out;
  }

  /// P2P orders completed between [from] and [to].
  Future<List<P2pTrade>> p2p(DateTime from, DateTime to) async {
    final List<P2pTrade> out = <P2pTrade>[];
    for (final (DateTime a, DateTime b) in _windows(from, to, 30)) {
      var page = 1;
      while (true) {
        final Map<String, Object?> body =
            await _get(
                  '/sapi/v1/c2c/orderMatch/listUserOrderHistory',
                  <String, String>{
                    'startTimestamp': '${a.millisecondsSinceEpoch}',
                    'endTimestamp': '${b.millisecondsSinceEpoch}',
                    'page': '$page',
                    'rows': '100',
                  },
                )
                as Map<String, Object?>;
        final List<Object?> rows =
            (body['data'] as List<Object?>?) ?? const <Object?>[];
        for (final Object? r in rows) {
          if (r is! Map || r['orderStatus'] != 'COMPLETED') continue;
          final Decimal? amount = Decimal.tryParse('${r['amount']}');
          final Decimal? total = Decimal.tryParse('${r['totalPrice']}');
          final int? time = (r['createTime'] as num?)?.toInt();
          if (amount == null || total == null || time == null) continue;
          out.add(
            P2pTrade(
              'binance:p2p:${r['orderNumber']}',
              DateTime.fromMillisecondsSinceEpoch(time),
              buy: r['tradeType'] == 'BUY',
              asset: '${r['asset']}'.toUpperCase(),
              amount: amount,
              fiat: '${r['fiat']}'.toUpperCase(),
              total: total,
            ),
          );
        }
        if (rows.length < 100) break;
        page++;
      }
    }
    return out;
  }

  /// Conversions made between [from] and [to].
  Future<List<Swap>> conversions(DateTime from, DateTime to) async {
    final List<Swap> out = <Swap>[];
    for (final (DateTime a, DateTime b) in _windows(from, to, 30)) {
      final Map<String, Object?> body =
          await _get('/sapi/v1/convert/tradeFlow', <String, String>{
                'startTime': '${a.millisecondsSinceEpoch}',
                'endTime': '${b.millisecondsSinceEpoch}',
                'limit': '1000',
              })
              as Map<String, Object?>;
      for (final Object? r
          in (body['list'] as List<Object?>?) ?? const <Object?>[]) {
        if (r is! Map || r['orderStatus'] != 'SUCCESS') continue;
        final Decimal? sent = Decimal.tryParse('${r['fromAmount']}');
        final Decimal? received = Decimal.tryParse('${r['toAmount']}');
        final int? time = (r['createTime'] as num?)?.toInt();
        if (sent == null || received == null || time == null) continue;
        out.add(
          Swap(
            'binance:convert:${r['orderId']}',
            DateTime.fromMillisecondsSinceEpoch(time),
            from: '${r['fromAsset']}'.toUpperCase(),
            sent: sent,
            to: '${r['toAsset']}'.toUpperCase(),
            received: received,
          ),
        );
      }
    }
    return out;
  }

  /// Trades of [asset] against tether on the spot market since [from], up
  /// to the last thousand.
  Future<List<Swap>> spotTrades(String asset, DateTime from) async {
    if (asset == 'USDT') return const <Swap>[];
    final String symbol = '${asset}USDT';
    final Object? body;
    try {
      body = await _get('/api/v3/myTrades', <String, String>{
        'symbol': symbol,
        'limit': '1000',
      });
    } on BinanceException catch (e) {
      // A symbol Binance does not list.
      if (e.code == -1121) return const <Swap>[];
      rethrow;
    }
    final List<Swap> out = <Swap>[];
    for (final Object? r in body is List ? body : const <Object?>[]) {
      if (r is! Map) continue;
      final int? time = (r['time'] as num?)?.toInt();
      final Decimal? qty = Decimal.tryParse('${r['qty']}');
      final Decimal? quote = Decimal.tryParse('${r['quoteQty']}');
      final Decimal? fee = Decimal.tryParse('${r['commission']}');
      if (time == null || qty == null || quote == null) continue;
      final DateTime at = DateTime.fromMillisecondsSinceEpoch(time);
      if (at.isBefore(from)) continue;
      final bool buyer = r['isBuyer'] == true;
      out.add(
        Swap(
          'binance:trade:$symbol:${r['id']}',
          at,
          from: buyer ? 'USDT' : asset,
          sent: buyer ? quote : qty,
          to: buyer ? asset : 'USDT',
          received: buyer ? qty : quote,
          fee: fee == null || fee == Decimal.zero
              ? null
              : ('${r['commissionAsset']}'.toUpperCase(), fee),
        ),
      );
    }
    return out;
  }

  /// Crypto that came in from outside, and went out, between [from] and
  /// [to].
  Future<List<Transfer>> transfers(DateTime from, DateTime to) async {
    final List<Transfer> out = <Transfer>[];
    for (final (DateTime a, DateTime b) in _windows(from, to, 89)) {
      final Map<String, String> range = <String, String>{
        'startTime': '${a.millisecondsSinceEpoch}',
        'endTime': '${b.millisecondsSinceEpoch}',
        'limit': '1000',
      };
      final Object? deposits = await _get(
        '/sapi/v1/capital/deposit/hisrec',
        range,
      );
      for (final Object? r in deposits is List ? deposits : const <Object?>[]) {
        if (r is! Map) continue;
        // 1 is credited and withdrawable; 6, credited and not yet.
        if (r['status'] != 1 && r['status'] != 6) continue;
        final Decimal? amount = Decimal.tryParse('${r['amount']}');
        final int? time = (r['insertTime'] as num?)?.toInt();
        if (amount == null || time == null) continue;
        out.add(
          Transfer(
            'binance:deposit:${r['id'] ?? r['txId']}',
            DateTime.fromMillisecondsSinceEpoch(time),
            deposit: true,
            asset: '${r['coin']}'.toUpperCase(),
            amount: amount,
          ),
        );
      }
      final Object? withdrawals = await _get(
        '/sapi/v1/capital/withdraw/history',
        range,
      );
      for (final Object? r
          in withdrawals is List ? withdrawals : const <Object?>[]) {
        if (r is! Map || r['status'] != 6) continue;
        final Decimal? amount = Decimal.tryParse('${r['amount']}');
        final Decimal fee =
            Decimal.tryParse('${r['transactionFee']}') ?? Decimal.zero;
        // "2019-10-12 11:12:02", in UTC.
        final DateTime? at = DateTime.tryParse(
          '${'${r['applyTime']}'.replaceFirst(' ', 'T')}Z',
        )?.toLocal();
        if (amount == null || at == null) continue;
        out.add(
          Transfer(
            'binance:withdraw:${r['id']}',
            at,
            deposit: false,
            asset: '${r['coin']}'.toUpperCase(),
            amount: amount + fee,
          ),
        );
      }
    }
    return out;
  }

  /// Everything since [from]: balances now, and what happened since.
  Future<BinanceReading> read(
    DateTime from, {
    void Function(double)? progress,
  }) async {
    final DateTime to = DateTime.now();
    progress?.call(0.05);
    final Map<String, Decimal> held = await balances();
    progress?.call(0.25);
    final List<BinanceEvent> events = <BinanceEvent>[...await p2p(from, to)];
    progress?.call(0.45);
    events.addAll(await conversions(from, to));
    progress?.call(0.6);
    events.addAll(await transfers(from, to));
    progress?.call(0.75);
    final Set<String> traded = <String>{
      ...held.keys,
      for (final BinanceEvent e in events)
        if (e is P2pTrade) e.asset else if (e is Transfer) e.asset,
    };
    for (final String asset in traded) {
      events.addAll(await spotTrades(asset, from));
    }
    progress?.call(0.9);
    events.sort((BinanceEvent a, BinanceEvent b) => a.at.compareTo(b.at));
    return BinanceReading(balances: held, events: events);
  }

  /// [from] to [to] cut into stretches of at most [days] days.
  static Iterable<(DateTime, DateTime)> _windows(
    DateTime from,
    DateTime to,
    int days,
  ) sync* {
    var start = from;
    while (start.isBefore(to)) {
      final DateTime end = start.add(Duration(days: days));
      final DateTime cut = end.isAfter(to) ? to : end;
      yield (start, cut);
      start = cut.add(const Duration(milliseconds: 1));
    }
  }
}

/// The words a sync writes into movements, in the person's language.
@immutable
class BinanceLabels {
  const BinanceLabels({
    required this.p2p,
    required this.conversion,
    required this.deposit,
    required this.withdrawal,
    required this.fee,
    required this.adjustment,
  });

  static const BinanceLabels spanish = BinanceLabels(
    p2p: 'Binance P2P',
    conversion: 'Conversión en Binance',
    deposit: 'Depósito a Binance',
    withdrawal: 'Retiro de Binance',
    fee: 'Comisión de Binance',
    adjustment: 'Ajuste con Binance',
  );

  final String p2p;
  final String conversion;
  final String deposit;
  final String withdrawal;
  final String fee;
  final String adjustment;
}

/// What one sync did.
@immutable
class SyncReport {
  const SyncReport({
    required this.accountsCreated,
    required this.movementsAdded,
    required this.adjusted,
  });

  final int accountsCreated;
  final int movementsAdded;

  /// Accounts whose balance did not match Binance's and got an adjustment.
  final int adjusted;
}

/// Brings what Binance holds and did into the person's accounts.
///
/// Each asset gets an account of its own under "Binance", kept in sync.
/// What happened is recorded once, each movement marked with Binance's id
/// for it. After that, every account holds exactly what Binance says: the
/// first time, what it held before the history read becomes its opening
/// balance; later, any difference (rewards, dust conversions, fees) is an
/// adjustment, with no cost.
class BinanceSync {
  BinanceSync(
    this.store, {
    this.labels = BinanceLabels.spanish,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final QuincenaStore store;
  final BinanceLabels labels;
  final DateTime Function() _now;

  static const String prefix = 'binance:';

  Future<SyncReport> apply(BinanceReading reading) async {
    final List<Account> accounts = await store.accounts(archived: true);
    final Map<String, Account> synced = <String, Account>{
      for (final Account a in accounts)
        if (a.syncRef?.startsWith(prefix) ?? false)
          a.syncRef!.substring(prefix.length): a,
    };
    final Set<String> created = <String>{};

    Future<Account> account(String asset) async {
      final Account? known = synced[asset];
      if (known != null) return known;
      final Asset a = Asset.of(asset);
      final Account made = await store.addAccount(
        name: a.name('es') == a.code ? a.code : a.name('es'),
        kind: AccountKind.exchange,
        asset: a,
        institution: 'Binance',
        spendable: false,
        syncRef: '$prefix$asset',
      );
      created.add(asset);
      return synced[asset] = made;
    }

    final Set<String> known = <String>{
      for (final Entry e in await store.entries())
        if (e.sourceRef?.startsWith(prefix) ?? false) e.sourceRef!,
    };
    var added = 0;
    for (final BinanceEvent e in reading.events) {
      if (known.contains(e.ref)) continue;
      switch (e) {
        case P2pTrade():
          final Account a = await account(e.asset);
          await store.addEntry(
            accountId: a.id,
            amount: e.amount,
            kind: e.buy ? EntryKind.income : EntryKind.expense,
            date: e.at,
            payee: labels.p2p,
            source: 'binance',
            sourceRef: e.ref,
            cost: Money(e.total, Asset.of(e.fiat)),
          );
          added++;
        case Swap():
          final Account from = await account(e.from);
          final Account to = await account(e.to);
          await store.addTransfer(
            fromAccountId: from.id,
            toAccountId: to.id,
            sent: e.sent,
            received: e.received,
            date: e.at,
            note: labels.conversion,
            source: 'binance',
            sourceRef: e.ref,
          );
          added++;
          final (String, Decimal)? fee = e.fee;
          if (fee != null) {
            final Account charged = await account(fee.$1);
            await store.addEntry(
              accountId: charged.id,
              amount: fee.$2,
              kind: EntryKind.expense,
              date: e.at,
              payee: labels.fee,
              source: 'binance',
              sourceRef: '${e.ref}:fee',
            );
          }
        case Transfer():
          final Account a = await account(e.asset);
          await store.addEntry(
            accountId: a.id,
            amount: e.amount,
            kind: e.deposit ? EntryKind.income : EntryKind.expense,
            date: e.at,
            payee: e.deposit ? labels.deposit : labels.withdrawal,
            source: 'binance',
            sourceRef: e.ref,
          );
          added++;
      }
      known.add(e.ref);
    }

    // Every asset Binance holds has an account, even with no history read.
    for (final String asset in reading.balances.keys) {
      await account(asset);
    }

    // Every account ends holding what Binance says.
    var adjusted = 0;
    final List<Entry> entries = await store.entries();
    final DateTime now = _now();
    final Map<String, Money> balances = balancesOf(synced.values, entries, now);
    for (final MapEntry<String, Account> s in synced.entries) {
      final Account a = s.value;
      final Decimal real = reading.balances[s.key] ?? Decimal.zero;
      final Decimal kept = balances[a.id]?.amount ?? a.opening;
      final Decimal gap = real - kept;
      if (gap == Decimal.zero) continue;
      if (created.contains(s.key)) {
        // What it held before the history read.
        await store.updateAccount(a.copyWith(opening: a.opening + gap));
      } else {
        await store.addEntry(
          accountId: a.id,
          amount: gap,
          kind: EntryKind.adjustment,
          date: now,
          payee: labels.adjustment,
          source: 'binance',
          sourceRef: '${prefix}balance:${s.key}:${now.millisecondsSinceEpoch}',
        );
        adjusted++;
      }
    }
    return SyncReport(
      accountsCreated: created.length,
      movementsAdded: added,
      adjusted: adjusted,
    );
  }
}
