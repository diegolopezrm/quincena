import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

/// Why a code could not be read.
enum CodeProblem {
  /// Not 54 letters and digits once the dashes are gone.
  length,

  /// A character Crockford's base32 does not use.
  character,

  /// The last two characters do not match the rest: a typo.
  check,
}

class CodeException implements Exception {
  const CodeException(this.problem);

  final CodeProblem problem;

  @override
  String toString() => 'CodeException(${problem.name})';
}

/// The key a person's devices share. Everything that crosses between them
/// is sealed with keys derived from it, and it never leaves a device but
/// as the code the person types on another.
///
/// A backup's key has the same shape and its own code: 256 bits the person
/// keeps, under labels of its own so neither key opens the other's files.
class VaultKey {
  VaultKey(List<int> bytes) : bytes = Uint8List.fromList(bytes) {
    if (bytes.length != length) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must be $length');
    }
  }

  /// A new key from the system's secure generator.
  factory VaultKey.generate([Random? random]) {
    final Random r = random ?? Random.secure();
    return VaultKey(<int>[for (var i = 0; i < length; i++) r.nextInt(256)]);
  }

  /// The key a [code] spells, or a [CodeException] saying what is wrong.
  factory VaultKey.fromCode(String code) {
    final String clean = _normalize(code);
    if (clean.length != _codeLength) {
      throw const CodeException(CodeProblem.length);
    }
    final List<int> values = <int>[];
    for (final int c in clean.codeUnits) {
      final int v = _alphabet.indexOf(String.fromCharCode(c));
      if (v < 0) throw const CodeException(CodeProblem.character);
      values.add(v);
    }
    final Uint8List key = _fromBase32(values.sublist(0, _keyChars), length);
    // The last character holds one bit of the key and four of padding: a
    // typo there could spell the same key, so only the code as it was
    // written out counts.
    if (_toBase32(key, _keyChars) != clean.substring(0, _keyChars) ||
        _check(key) != clean.substring(_keyChars)) {
      throw const CodeException(CodeProblem.check);
    }
    return VaultKey(key);
  }

  static const int length = 32;
  final Uint8List bytes;

  /// Crockford's base32: no I, L, O or U, so nothing reads as another.
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// 256 bits in fives, rounded up, and two characters of check.
  static const int _keyChars = 52;
  static const int _codeLength = _keyChars + 2;

  /// The code to type on another device: 54 characters in groups of four.
  String get code {
    final String all = _toBase32(bytes, _keyChars) + _check(bytes);
    return <String>[
      for (var i = 0; i < all.length; i += 4)
        all.substring(i, min(i + 4, all.length)),
    ].join('-');
  }

  /// The code in [text] as it was copied or shared, perhaps with words
  /// around it, as in a note that names what the code is for: 54 letters
  /// and digits in groups of four, with or without what separates them.
  /// Null when there is none; the text as typed then says what is wrong.
  static String? codeIn(String text) => _inText.firstMatch(text)?[0];

  static final RegExp _inText = RegExp(
    r'(?<![0-9A-Za-z])[0-9A-Za-z]{4}(?:[ \-]?[0-9A-Za-z]{4}){12}'
    r'[ \-]?[0-9A-Za-z]{2}(?![0-9A-Za-z])',
  );

  /// What the person typed, as the alphabet spells it: dashes and spaces
  /// out, and the letters people mix up read the way Crockford says.
  static String _normalize(String code) => code
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');

  /// Two characters of check: Luhn mod 32 over the code, which catches
  /// any one character typed wrong and most two swapped, and five bits of
  /// a hash of the key under its own label, for the rest.
  static String _check(Uint8List key) {
    final String body = _toBase32(key, _keyChars);
    var factor = 2;
    var sum = 0;
    for (var i = body.length - 1; i >= 0; i--) {
      var addend = factor * _alphabet.indexOf(body[i]);
      factor = factor == 2 ? 1 : 2;
      addend = addend ~/ 32 + addend % 32;
      sum += addend;
    }
    final int luhn = (32 - sum % 32) % 32;
    final List<int> digest = hash.sha256.convert(<int>[
      ...utf8.encode('quincena/sync/check/v1'),
      ...key,
    ]).bytes;
    return _alphabet[luhn] + _alphabet[digest[0] & 31];
  }

  static String _toBase32(Uint8List data, int chars) {
    final StringBuffer out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final int byte in data) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return out.toString().padRight(chars, '0');
  }

  static Uint8List _fromBase32(List<int> values, int bytes) {
    final Uint8List out = Uint8List(bytes);
    var buffer = 0;
    var bits = 0;
    var i = 0;
    for (final int v in values) {
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        if (i < bytes) out[i++] = (buffer >> (bits - 8)) & 0xff;
        bits -= 8;
        buffer &= (1 << bits) - 1;
      }
    }
    return out;
  }

  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<Uint8List> _derive(String label, int length) async {
    final SecretKeyData key = await _hkdf.deriveKey(
      secretKey: SecretKeyData(bytes),
      info: utf8.encode(label),
    );
    return Uint8List.fromList(key.bytes.sublist(0, length));
  }

  /// The key files are sealed with, derived under [label].
  Future<SecretKey> encryptionKey([
    String label = 'quincena/sync/encrypt/v1',
  ]) async => SecretKeyData(await _derive(label, 32));

  /// What a file's header carries to say which vault made it, without
  /// naming the vault: a keyed hash of a salt new in every file, so no two
  /// files of a vault look alike.
  Future<Uint8List> fileTag(
    List<int> salt, [
    String label = 'quincena/sync/file-tag/v1',
  ]) async {
    final Mac mac = await Hmac.sha256().calculateMac(
      salt,
      secretKey: SecretKeyData(await _derive(label, 32)),
    );
    return Uint8List.fromList(mac.bytes.sublist(0, 16));
  }
}
