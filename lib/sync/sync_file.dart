import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

import 'vault.dart';

/// Why a sealed file could not be opened.
enum SyncFileProblem {
  /// Not a file of the kind asked for.
  notSync,

  /// Made by a newer Quincena.
  newer,

  /// Sealed with another key: made with another code.
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
/// It is a [SealedFile] of the sync kind.
abstract final class SyncFile {
  static const int format = SealedFile.format;

  static Future<Uint8List> seal(
    VaultKey key,
    Map<String, Object?> body, {
    Random? random,
  }) => SealedFile.sync.seal(key, body, random: random);

  /// The body of [file], or a [SyncFileException] and nothing else.
  static Future<Map<String, Object?>> open(VaultKey key, List<int> file) =>
      SealedFile.sync.open(key, file);
}

/// A file sealed with a key the person holds as a code:
///
/// `magic (5) | format (1) | salt (16) | tag (16) | nonce (24) | sealed body`
///
/// The body is its own length, the JSON gzipped, and zeros to a multiple of
/// 16 KiB, sealed with XChaCha20-Poly1305 under a key derived from the
/// person's. The tag, a keyed hash of a salt new in every file, tells a file
/// of another key from a damaged one with nothing common to two files.
/// Every clear byte before the body goes in as associated data, so nothing
/// in the header can change unnoticed.
///
/// Each kind has its own magic and derives its keys under its own labels:
/// a sync code never opens a backup, nor a backup's code a sync file.
final class SealedFile {
  const SealedFile._(this._magicText, this._encryptLabel, this._tagLabel);

  /// What devices pass each other to stay in step.
  static const SealedFile sync = SealedFile._(
    'QSYNC',
    'quincena/sync/encrypt/v1',
    'quincena/sync/file-tag/v1',
  );

  /// Everything at one moment, for the day a phone is lost.
  static const SealedFile backup = SealedFile._(
    'QBACK',
    'quincena/backup/encrypt/v1',
    'quincena/backup/file-tag/v1',
  );

  final String _magicText;
  final String _encryptLabel;
  final String _tagLabel;

  List<int> get _magic => ascii.encode(_magicText);
  static const int format = 1;
  static const int _saltLength = 16;
  static const int _tagLength = 16;
  static const int _nonceLength = 24;
  static const int _macLength = 16;
  static const int _block = 16 * 1024;
  int get _headerLength =>
      _magic.length + 1 + _saltLength + _tagLength + _nonceLength;

  /// What a body may grow to once uncompressed.
  static const int maxBody = 64 * 1024 * 1024;

  static final Xchacha20 _cipher = Xchacha20.poly1305Aead();

  /// Whether [file] says it is of this kind. Only opening it says whether
  /// it is whole.
  bool marks(List<int> file) {
    final List<int> magic = _magic;
    if (file.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (file[i] != magic[i]) return false;
    }
    return true;
  }

  Future<Uint8List> seal(
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
      ...await key.fileTag(salt, _tagLabel),
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
      secretKey: await key.encryptionKey(_encryptLabel),
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
  Future<Map<String, Object?>> open(VaultKey key, List<int> file) async {
    if (file.length < _headerLength + _macLength || !marks(file)) {
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
    if (!_same(tag, await key.fileTag(salt, _tagLabel))) {
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
        secretKey: await key.encryptionKey(_encryptLabel),
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
