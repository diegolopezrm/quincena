import 'dart:convert';

import 'package:crypto/crypto.dart';

// The checksums a blockchain address carries, so one copied with a
// character changed or left out is caught before any service is asked
// about it: Bech32 for Bitcoin's bc1 addresses, Base58Check for its older
// ones and for TRON's, and Ethereum's mixed case. BigInt and small ints
// only, so the web build checks the same.

/// Whether [address], a Bitcoin address starting with `bc1`, carries its
/// checksum: Bech32 for a version 0 program of 20 or 32 bytes, Bech32m for
/// the later versions, such as Taproot's.
bool bech32Intact(String address, {String hrp = 'bc'}) {
  final String a = address.toLowerCase();
  if (a != address && address.toUpperCase() != address) return false;
  final int separator = a.lastIndexOf('1');
  if (separator != hrp.length || !a.startsWith(hrp)) return false;
  final List<int> data = <int>[];
  for (final String c in a.substring(separator + 1).split('')) {
    final int value = _bech32.indexOf(c);
    if (value < 0) return false;
    data.add(value);
  }
  if (data.length < 7) return false;
  final int version = data.first;
  final List<int>? program = _regroup(data.sublist(1, data.length - 6));
  if (version > 16 || program == null) return false;
  if (program.length < 2 || program.length > 40) return false;
  if (version == 0 && program.length != 20 && program.length != 32) {
    return false;
  }
  final int check = _polymod(<int>[..._expand(hrp), ...data]);
  return check == (version == 0 ? 1 : 0x2bc830a3);
}

const String _bech32 = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

int _polymod(List<int> values) {
  const List<int> generator = <int>[
    0x3b6a57b2,
    0x26508e6d,
    0x1ea119fa,
    0x3d4233dd,
    0x2a1462b3,
  ];
  var check = 1;
  for (final int value in values) {
    final int top = check >> 25;
    check = ((check & 0x1ffffff) << 5) ^ value;
    for (var i = 0; i < 5; i++) {
      if ((top >> i) & 1 == 1) check ^= generator[i];
    }
  }
  return check;
}

List<int> _expand(String hrp) => <int>[
  for (final int c in hrp.codeUnits) c >> 5,
  0,
  for (final int c in hrp.codeUnits) c & 31,
];

/// Five-bit groups as bytes, or null when what is left over is not the
/// padding of zeros an address ends with.
List<int>? _regroup(List<int> data) {
  var bits = 0;
  var acc = 0;
  final List<int> out = <int>[];
  for (final int value in data) {
    acc = ((acc << 5) | value) & 0xfff;
    bits += 5;
    while (bits >= 8) {
      bits -= 8;
      out.add((acc >> bits) & 0xff);
    }
  }
  if (bits >= 5 || ((acc << (8 - bits)) & 0xff) != 0) return null;
  return out;
}

/// What a Base58Check string carries, its version byte first, or null when
/// its last four bytes are not the checksum of the rest.
List<int>? base58Check(String text) {
  var n = BigInt.zero;
  for (final String c in text.split('')) {
    final int digit = _base58.indexOf(c);
    if (digit < 0) return null;
    n = n * _fiftyEight + BigInt.from(digit);
  }
  final List<int> bytes = <int>[];
  while (n > BigInt.zero) {
    bytes.add((n & _byte).toInt());
    n = n >> 8;
  }
  // Each leading 1 is a leading zero byte.
  for (final String c in text.split('')) {
    if (c != '1') break;
    bytes.add(0);
  }
  final List<int> all = bytes.reversed.toList();
  if (all.length < 5) return null;
  final List<int> payload = all.sublist(0, all.length - 4);
  final List<int> check = sha256.convert(sha256.convert(payload).bytes).bytes;
  for (var i = 0; i < 4; i++) {
    if (all[payload.length + i] != check[i]) return null;
  }
  return payload;
}

const String _base58 =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
final BigInt _fiftyEight = BigInt.from(58);
final BigInt _byte = BigInt.from(0xff);

/// Whether an Ethereum address, `0x` and forty hexadecimal digits, carries
/// the checksum its mixed case writes (EIP-55). One in a single case has
/// none to check, and passes.
bool eip55Intact(String address) {
  final String hex = address.substring(2);
  if (hex == hex.toLowerCase() || hex == hex.toUpperCase()) return true;
  final List<int> hash = keccak256(utf8.encode(hex.toLowerCase()));
  for (var i = 0; i < hex.length; i++) {
    final String c = hex[i];
    if (c.toLowerCase() == c.toUpperCase()) continue;
    final int nibble = (hash[i ~/ 2] >> (i.isEven ? 4 : 0)) & 0xf;
    if ((nibble >= 8) != (c == c.toUpperCase())) return false;
  }
  return true;
}

/// Keccak-256, as Ethereum hashes: the original padding, not SHA-3's.
List<int> keccak256(List<int> message) {
  const int rate = 136;
  final List<int> padded = <int>[...message, 0x01];
  while (padded.length % rate != 0) {
    padded.add(0);
  }
  padded[padded.length - 1] |= 0x80;
  final List<BigInt> state = List<BigInt>.filled(25, BigInt.zero);
  for (var block = 0; block < padded.length; block += rate) {
    for (var lane = 0; lane < rate ~/ 8; lane++) {
      var value = BigInt.zero;
      for (var b = 7; b >= 0; b--) {
        value = (value << 8) | BigInt.from(padded[block + lane * 8 + b]);
      }
      state[lane] ^= value;
    }
    _keccakF(state);
  }
  return <int>[
    for (var lane = 0; lane < 4; lane++)
      for (var b = 0; b < 8; b++) ((state[lane] >> (8 * b)) & _byte).toInt(),
  ];
}

final BigInt _lane = (BigInt.one << 64) - BigInt.one;

BigInt _rotate(BigInt x, int n) =>
    n == 0 ? x : ((x << n) | (x >> (64 - n))) & _lane;

/// How far each lane turns, by x + 5y.
const List<int> _turns = <int>[
  0, 1, 62, 28, 27, //
  36, 44, 6, 55, 20, //
  3, 10, 43, 25, 39, //
  41, 45, 15, 21, 8, //
  18, 2, 61, 56, 14, //
];

final List<BigInt> _rounds = <String>[
  '0000000000000001',
  '0000000000008082',
  '800000000000808A',
  '8000000080008000',
  '000000000000808B',
  '0000000080000001',
  '8000000080008081',
  '8000000000008009',
  '000000000000008A',
  '0000000000000088',
  '0000000080008009',
  '000000008000000A',
  '000000008000808B',
  '800000000000008B',
  '8000000000008089',
  '8000000000008003',
  '8000000000008002',
  '8000000000000080',
  '000000000000800A',
  '800000008000000A',
  '8000000080008081',
  '8000000000008080',
  '0000000080000001',
  '8000000080008008',
].map((String hex) => BigInt.parse(hex, radix: 16)).toList();

void _keccakF(List<BigInt> a) {
  for (final BigInt constant in _rounds) {
    final List<BigInt> column = <BigInt>[
      for (var x = 0; x < 5; x++)
        a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20],
    ];
    for (var x = 0; x < 5; x++) {
      final BigInt d = column[(x + 4) % 5] ^ _rotate(column[(x + 1) % 5], 1);
      for (var y = 0; y < 25; y += 5) {
        a[x + y] ^= d;
      }
    }
    final List<BigInt> b = List<BigInt>.filled(25, BigInt.zero);
    for (var x = 0; x < 5; x++) {
      for (var y = 0; y < 5; y++) {
        b[y + 5 * ((2 * x + 3 * y) % 5)] = _rotate(
          a[x + 5 * y],
          _turns[x + 5 * y],
        );
      }
    }
    for (var x = 0; x < 5; x++) {
      for (var y = 0; y < 25; y += 5) {
        a[x + y] =
            b[x + y] ^ ((~b[(x + 1) % 5 + y] & _lane) & b[(x + 2) % 5 + y]);
      }
    }
    a[0] ^= constant;
  }
}
