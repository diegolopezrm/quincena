import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../store/store.dart';
import 'binance_client.dart';
import 'binance_sync.dart';
import 'p2p_match.dart';

/// Where a Binance key is kept: the device's keychain, never the database
/// and never an export.
abstract class KeyVault {
  Future<(String, String)?> read();
  Future<void> write(String key, String secret);
  Future<void> delete();
}

/// The keychain on Apple devices, the Keystore on Android. Kept on this
/// device only: not in iCloud, not in a backup restored elsewhere.
class SecureKeyVault implements KeyVault {
  SecureKeyVault()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  static const String _key = 'binance.key';
  static const String _secret = 'binance.secret';

  @override
  Future<(String, String)?> read() async {
    final String? key = await _storage.read(key: _key);
    final String? secret = await _storage.read(key: _secret);
    return key == null || secret == null ? null : (key, secret);
  }

  @override
  Future<void> write(String key, String secret) async {
    await _storage.write(key: _key, value: key);
    await _storage.write(key: _secret, value: secret);
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _secret);
  }
}

/// How connecting a key went.
enum ConnectOutcome {
  connected,

  /// The key can do more than read: Quincena does not keep it.
  notReadOnly,
  badKey,
  offline,
  limited,
  failed,
}

/// What went wrong in the last sync, if anything.
enum SyncProblem { badKey, offline, limited, failed }

/// The person's Binance account, linked with a key that can only read.
///
/// Not on the web: Binance does not answer a browser's signed requests,
/// and a browser has no keychain to keep the key in.
class BinanceLink extends ChangeNotifier {
  BinanceLink(
    this.store, {
    KeyVault? vault,
    BinanceClient Function(String key, String secret)? clientFor,
    this.labels = BinanceLabels.spanish,
    this.firstYears = 1,
    DateTime Function()? now,
  }) : _vault = vault ?? SecureKeyVault(),
       _clientFor =
           clientFor ??
           ((String key, String secret) =>
               BinanceClient(key: key, secret: secret)),
       _now = now ?? DateTime.now;

  final QuincenaStore store;
  final KeyVault _vault;
  final BinanceClient Function(String key, String secret) _clientFor;
  final DateTime Function() _now;

  /// The words the movements it records are written with.
  BinanceLabels labels;

  /// How far back the first sync reads.
  final int firstYears;

  static const String _setting = 'binance';

  bool _connected = false;
  bool _loaded = false;
  bool _syncing = false;
  double _progress = 0;
  DateTime? _syncedAt;
  SyncProblem? _problem;
  SyncReport? _report;
  List<String> _refused = const <String>[];

  /// Whether this build can link Binance at all.
  static bool get available => !kIsWeb;

  bool get connected => _connected;
  bool get syncing => _syncing;
  double get progress => _progress;
  DateTime? get syncedAt => _syncedAt;
  SyncProblem? get problem => _problem;
  SyncReport? get report => _report;

  /// What a refused key could do besides reading.
  List<String> get refused => _refused;

  /// Reads whether a key is kept and when it last synced.
  Future<void> load() async {
    if (_loaded || !available) return;
    _loaded = true;
    try {
      _connected = await _vault.read() != null;
    } on Object {
      _connected = false;
    }
    final String? saved = await store.setting(_setting);
    if (saved != null) {
      final Object? json = jsonDecode(saved);
      if (json is Map) {
        _syncedAt = DateTime.tryParse('${json['syncedAt']}');
      }
    }
    notifyListeners();
  }

  /// Checks [key] with Binance, keeps it only if it can do nothing but
  /// read, and brings the account in.
  Future<ConnectOutcome> connect(String key, String secret) async {
    final String k = key.trim();
    final String s = secret.trim();
    final BinanceClient client = _clientFor(k, s);
    try {
      final KeyPermissions can = await client.permissions();
      if (!can.readOnly) {
        _refused = can.canRead ? can.beyondReading : <String>['enableReading'];
        notifyListeners();
        return ConnectOutcome.notReadOnly;
      }
      _refused = const <String>[];
      await _vault.write(k, s);
      _connected = true;
      notifyListeners();
    } on BinanceException catch (e) {
      return e.badKey
          ? ConnectOutcome.badKey
          : e.limited
          ? ConnectOutcome.limited
          : ConnectOutcome.failed;
    } on Object catch (e) {
      return _offline(e) ? ConnectOutcome.offline : ConnectOutcome.failed;
    } finally {
      client.close();
    }
    await sync();
    return ConnectOutcome.connected;
  }

  /// Reads Binance again, unless it was read within [age].
  Future<void> syncIfOlder(Duration age) async {
    await load();
    final DateTime? at = _syncedAt;
    if (!_connected || (at != null && _now().difference(at) < age)) return;
    await sync();
  }

  /// Reads what changed since the last sync, or the last [firstYears]
  /// the first time, and records it.
  Future<void> sync() async {
    if (_syncing || !available) return;
    final (String, String)? keys = await _vault.read();
    if (keys == null) {
      _connected = false;
      notifyListeners();
      return;
    }
    _syncing = true;
    _progress = 0;
    _problem = null;
    notifyListeners();
    final DateTime started = _now();
    final DateTime? last = _syncedAt;
    // A day of overlap: Binance can take a while to list an order.
    final DateTime from = last == null
        ? DateTime(started.year - firstYears, started.month, started.day)
        : last.subtract(const Duration(days: 1));
    final BinanceClient client = _clientFor(keys.$1, keys.$2);
    try {
      final BinanceReading reading = await BinanceReader(client).read(
        from,
        progress: (double p) {
          _progress = p;
          notifyListeners();
        },
      );
      _report = await BinanceSync(
        store,
        labels: labels,
        now: _now,
      ).apply(reading);
      // A P2P order and the bank's payment for it become one transfer.
      await linkP2pPayments(store);
      _syncedAt = started;
      await store.setSetting(
        _setting,
        jsonEncode(<String, Object?>{'syncedAt': started.toIso8601String()}),
      );
    } on BinanceException catch (e) {
      _problem = e.badKey
          ? SyncProblem.badKey
          : e.limited
          ? SyncProblem.limited
          : SyncProblem.failed;
    } on Object catch (e) {
      _problem = _offline(e) ? SyncProblem.offline : SyncProblem.failed;
      debugPrint('Binance sync failed: $e');
    } finally {
      client.close();
      _syncing = false;
      _progress = 1;
      notifyListeners();
    }
  }

  /// Forgets the key. What it brought stays, as the person's own.
  Future<void> disconnect() async {
    await _vault.delete();
    await store.setSetting(_setting, jsonEncode(<String, Object?>{}));
    _connected = false;
    _syncedAt = null;
    _report = null;
    _problem = null;
    notifyListeners();
  }

  static bool _offline(Object e) =>
      e is TimeoutException ||
      e is http.ClientException ||
      (!kIsWeb && e is SocketException);
}
