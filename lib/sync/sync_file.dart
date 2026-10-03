import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

import 'vault.dart';

/// Why a sync file could not be opened.
enum SyncFileProblem {
  /// Not a Quincena sync file.
  notSync,

  /// Made by a newer Quincena.
  newer,

  /// From another vault: made with another code.
  otherVault,

  /// Changed or cut since it was made.
  damaged,
}

class SyncFileException implements Exception {
  const SyncFileException(this.problem);

  final SyncFileProblem problem;

  @override
  String toString() => 'SyncFileException(${problem.name})';
}

/// The file devices pass each other:
///
/// `"QSYNC" | format (1) | salt (16) | tag (16) | nonce (24) | sealed body`
///
/// The body is its own length, the JSON gzipped, and zeros to a multiple of
/// 16 KiB, sealed with XChaCha20-Poly1305 under a key derived from the
/// vault's. The tag, a keyed hash of a salt new in every file, tells a file
/// of another vault from a damaged one with nothing common to two files.
/// Every clear byte before the body goes in as associated data, so nothing
/// in the header can change unnoticed.
abstract final class SyncFile {
  static final List<int> _magic = ascii.encode('QSYNC');
  static const int format = 1;
  static const int _saltLength = 16;
  static const int _tagLength = 16;
  static const int _nonceLength = 24;
  static const int _macLength = 16;
  static const int _block = 16 * 1024;
  static int get _headerLength =>
      _magic.length + 1 + _saltLength + _tagLength + _nonceLength;

  /// What a body may grow to once uncompressed.
  static const int maxBody = 64 * 1024 * 1024;

  static final Xchacha20 _cipher = Xchacha20.poly1305Aead();

  static Future<Uint8List> seal(
    VaultKey key,
    Map<String, Object?> body, {
    Random? random,
  }) async {
    final Random r = random ?? Random.secure();
    List<int> bytes(int n) => <int>[for (var i = 0; i < n; i++) r.nextInt(256)];
    final List<int> salt = bytes(_saltLength);
    final List<int> nonce = bytes(_nonceLength);
    final Uint8List header = Uint8List.fromList(<int>[
      ..._magic,
      format,
      ...salt,
      ...await key.fileTag(salt),
      ...nonce,
    ]);
    final List<int> packed = GZipEncoder().encodeBytes(
      utf8.encode(jsonEncode(body)),
    );
    // Its length, then zeros to a whole number of blocks: the size says
    // little of how much is inside.
    final int size = 4 + packed.length;
    final Uint8List padded = Uint8List((size + _block - 1) ~/ _block * _block)
      ..buffer.asByteData().setUint32(0, packed.length)
      ..setRange(4, size, packed);
    final SecretBox box = await _cipher.encrypt(
      padded,
      secretKey: await key.encryptionKey(),
      nonce: nonce,
      aad: header,
    );
    return Uint8List.fromList(<int>[
      ...header,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// The body of [file], or a [SyncFileException] and nothing else.
  static Future<Map<String, Object?>> open(VaultKey key, List<int> file) async {
    if (file.length < _headerLength + _macLength || !_startsWithMagic(file)) {
      throw const SyncFileException(SyncFileProblem.notSync);
    }
    final int version = file[_magic.length];
    if (version > format) {
      throw const SyncFileException(SyncFileProblem.newer);
    }
    if (version != format) {
      throw const SyncFileException(SyncFileProblem.damaged);
    }
    final int at = _magic.length + 1;
    final List<int> salt = file.sublist(at, at + _saltLength);
    final List<int> tag = file.sublist(
      at + _saltLength,
      at + _saltLength + _tagLength,
    );
    if (!_same(tag, await key.fileTag(salt))) {
      throw const SyncFileException(SyncFileProblem.otherVault);
    }
    final List<int> header = file.sublist(0, _headerLength);
    final List<int> nonce = file.sublist(
      _headerLength - _nonceLength,
      _headerLength,
    );
    final List<int> sealed = file.sublist(
      _headerLength,
      file.length - _macLength,
    );
    final List<int> mac = file.sublist(file.length - _macLength);
    final List<int> padded;
    try {
      padded = await _cipher.decrypt(
        SecretBox(sealed, nonce: nonce, mac: Mac(mac)),
        secretKey: await key.encryptionKey(),
        aad: header,
      );
    } on SecretBoxAuthenticationError {
      throw const SyncFileException(SyncFileProblem.damaged);
    }
    if (padded.length < 8) {
      throw const SyncFileException(SyncFileProblem.damaged);
    }
    final int length = ByteData.sublistView(
      Uint8List.fromList(padded.sublist(0, 4)),
    ).getUint32(0);
    if (length < 4 || 4 + length > padded.length) {
      throw const SyncFileException(SyncFileProblem.damaged);
    }
    final List<int> packed = padded.sublist(4, 4 + length);
    // Sealed, so only a device with the key could have made it; still, a
    // body is never inflated past what any person's data needs, by what
    // gzip says it holds.
    if (_inflatedSize(packed) > maxBody) {
      throw const SyncFileException(SyncFileProblem.damaged);
    }
    try {
      final Object? body = jsonDecode(
        utf8.decode(GZipDecoder().decodeBytes(packed)),
      );
      if (body is! Map<String, Object?>) {
        throw const SyncFileException(SyncFileProblem.damaged);
      }
      return body;
    } on SyncFileException {
      rethrow;
    } on Object {
      throw const SyncFileException(SyncFileProblem.damaged);
    }
  }

  static bool _startsWithMagic(List<int> file) {
    for (var i = 0; i < _magic.length; i++) {
      if (file[i] != _magic[i]) return false;
    }
    return true;
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// The size gzip says the body inflates to, from its last four bytes.
  static int _inflatedSize(List<int> packed) {
    final int n = packed.length;
    return packed[n - 4] |
        (packed[n - 3] << 8) |
        (packed[n - 2] << 16) |
        (packed[n - 1] << 24);
  }
}
