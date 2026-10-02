import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What Binance said is wrong with a request: a key it does not take, a
/// clock too far off, a limit reached.
class BinanceException implements Exception {
  const BinanceException(this.status, this.code, this.message);

  /// The HTTP status: 401 and 403 for the key, 418 and 429 for limits.
  final int status;

  /// Binance's own code, such as -2015 for a key it does not accept.
  final int? code;
  final String message;

  /// The key is wrong, was deleted, or does not allow this request.
  bool get badKey =>
      status == 401 || code == -2014 || code == -2015 || code == -1022;

  /// Too many requests: wait before asking again.
  bool get limited => status == 418 || status == 429;

  @override
  String toString() => 'Binance $status ($code): $message';
}

/// What a key is allowed to do, as Binance says.
@immutable
class KeyPermissions {
  const KeyPermissions(this.flags);

  final Map<String, bool> flags;

  bool get canRead => flags['enableReading'] ?? false;

  /// Anything beyond reading: trading, withdrawing, moving between
  /// accounts. Quincena only takes keys that can do none of it.
  List<String> get beyondReading => <String>[
    for (final MapEntry<String, bool> f in flags.entries)
      if (f.value && !_readOnly.contains(f.key)) f.key,
  ];

  bool get readOnly => canRead && beyondReading.isEmpty;

  /// Flags that only allow reading.
  static const Set<String> _readOnly = <String>{
    'enableReading',
    'enableFixReadOnly',
    'ipRestrict',
  };
}

/// Binance's API for one person's account, with a key that can only read.
///
/// Every request is signed with HMAC-SHA256, as Binance asks, and stamped
/// with Binance's own clock, so a phone whose clock is off still gets in.
/// The secret never leaves this object, and only travels as a signature.
class BinanceClient {
  BinanceClient({
    required this.key,
    required String secret,
    http.Client? client,
    this.host = 'api.binance.com',
    this.timeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _secret = utf8.encode(secret),
       _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  final String key;
  final List<int> _secret;
  final http.Client _client;
  final String host;
  final Duration timeout;
  final DateTime Function() _now;

  /// How far Binance's clock is ahead of this device's, once asked.
  Duration? _skew;

  /// The signature of [query] with [secret], as Binance computes it.
  @visibleForTesting
  static String sign(String query, String secret) =>
      Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(query)).toString();

  Future<int> _timestamp() async {
    final Duration skew = _skew ??= await _askSkew();
    return _now().add(skew).millisecondsSinceEpoch;
  }

  Future<Duration> _askSkew() async {
    final DateTime before = _now();
    final Map<String, Object?> body =
        await _send('GET', '/api/v3/time', const <String, String>{})
            as Map<String, Object?>;
    final DateTime after = _now();
    final int server = (body['serverTime'] as num).toInt();
    // The request took a while: compare with the moment in its middle.
    final DateTime middle = before.add(after.difference(before) ~/ 2);
    return Duration(milliseconds: server - middle.millisecondsSinceEpoch);
  }

  /// A signed request: the parameters, a timestamp, and their signature.
  Future<Object?> signed(
    String path, {
    Map<String, String> params = const <String, String>{},
    String method = 'GET',
  }) async {
    final Map<String, String> all = <String, String>{
      ...params,
      'recvWindow': '10000',
      'timestamp': '${await _timestamp()}',
    };
    final String query = Uri(queryParameters: all).query;
    final String signature = Hmac(
      sha256,
      _secret,
    ).convert(utf8.encode(query)).toString();
    return _send(method, path, <String, String>{
      ...all,
      'signature': signature,
    }, apiKey: true);
  }

  Future<Object?> _send(
    String method,
    String path,
    Map<String, String> params, {
    bool apiKey = false,
  }) async {
    final Uri uri = Uri.https(host, path, params.isEmpty ? null : params);
    final Map<String, String> headers = <String, String>{
      if (apiKey) 'X-MBX-APIKEY': key,
    };
    final http.Response response =
        await (method == 'POST'
                ? _client.post(uri, headers: headers)
                : _client.get(uri, headers: headers))
            .timeout(timeout);
    final Object? body = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode != 200) {
      final Map<Object?, Object?> error = body is Map
          ? body
          : const <Object?, Object?>{};
      throw BinanceException(
        response.statusCode,
        (error['code'] as num?)?.toInt(),
        '${error['msg'] ?? response.reasonPhrase ?? ''}',
      );
    }
    return body;
  }

  /// What this key may do.
  Future<KeyPermissions> permissions() async {
    final Map<String, Object?> body =
        await signed('/sapi/v1/account/apiRestrictions')
            as Map<String, Object?>;
    return KeyPermissions(<String, bool>{
      for (final MapEntry<String, Object?> e in body.entries)
        if (e.value is bool) e.key: e.value! as bool,
    });
  }

  void close() => _client.close();
}
