// The checksums of blockchain addresses, against the examples their own
// standards publish: one character changed is caught before anyone is
// asked about the address.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/exchanges/address_checks.dart';
import 'package:quincena/exchanges/wallets.dart';

String hex(List<int> bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

/// [address] with the character at [at] swapped for another its alphabet
/// has.
String typo(String address, int at) {
  final String c = address[at];
  final String other = c == 'q' ? 'p' : (c == '7' ? '8' : 'q');
  return address.replaceRange(at, at + 1, other);
}

void main() {
  test('Keccak-256 hashes as Ethereum does', () {
    expect(
      hex(keccak256(const <int>[])),
      'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
    );
    expect(
      hex(keccak256(utf8.encode('abc'))),
      '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45',
    );
    // Longer than one block: 200 bytes of 0xa3; and at the block's edge,
    // where the padding takes one byte, or a block of its own.
    expect(
      hex(keccak256(List<int>.filled(200, 0xa3))),
      '3a57666b048777f2c953dc4456f45a2588e1cb6f2da760122d530ac2ce607d4a',
    );
    expect(
      hex(keccak256(List<int>.filled(135, 0xa3))),
      '3d28d08c3dacab77392064a939f3e7f8d03f2e02e2c664ac08a05f63ac652626',
    );
    expect(
      hex(keccak256(List<int>.filled(136, 0xa3))),
      'b82d89d96e5575d11a9e1f4cabb2a45e60899e69a19a724cd796bdcf13511018',
    );
  });

  test('Bitcoin addresses carry their checksum', () {
    const List<String> good = <String>[
      // BIP-173 and BIP-350.
      'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
      'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4',
      'bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3',
      'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0',
      // The older ones, pay to a key and to a script.
      '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2',
      '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
      '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy',
    ];
    for (final String address in good) {
      expect(Chain.bitcoin.intact(address), isTrue, reason: address);
    }
    for (final String address in good) {
      expect(
        Chain.bitcoin.intact(typo(address, address.length - 9)),
        isFalse,
        reason: address,
      );
    }
    // Version 0 written with the checksum of the later ones, and mixed case.
    expect(
      Chain.bitcoin.intact(
        'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'.replaceFirst(
          'kv8f3t4',
          '',
        ),
      ),
      isFalse,
    );
    expect(
      Chain.bitcoin.intact('bc1qW508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'),
      isFalse,
    );
    // The made-up one some screens follow: right shape, wrong checksum.
    expect(
      Chain.bitcoin.intact('bc1qexampleexampleexampleexample0lmg5w'),
      isFalse,
    );
  });

  test('TRON addresses carry their checksum and version', () {
    expect(Chain.tron.intact('TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'), isTrue);
    expect(Chain.tron.intact('TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8'), isTrue);
    expect(Chain.tron.intact('TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6u'), isFalse);
    // A Bitcoin address checks out as Base58, not as TRON's.
    expect(base58Check('1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2'), isNotNull);
    expect(Chain.tron.intact('1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2'), isFalse);
  });

  test('Ethereum addresses in mixed case carry their checksum; in one case, '
      'none', () {
    const List<String> good = <String>[
      // EIP-55.
      '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
      '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
      '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb',
      '0x52908400098527886E0F7030069857D2E4169EE7',
      '0xde709f2102306220921060314715629080e2fb77',
    ];
    for (final String address in good) {
      expect(Chain.ethereum.intact(address), isTrue, reason: address);
    }
    // One letter in the other case.
    expect(
      Chain.ethereum.intact('0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeD'),
      isFalse,
    );
    expect(
      Chain.ethereum.intact('0xfb6916095ca1df60bB79Ce92cE3Ea74c37c5d359'),
      isFalse,
    );
  });

  test('an address says its chain by how it starts', () {
    expect(Chain.guess('bc1qw508d6'), Chain.bitcoin);
    expect(Chain.guess('1BvBMSEY'), Chain.bitcoin);
    expect(Chain.guess('3J98t1Wp'), Chain.bitcoin);
    expect(Chain.guess('0x5aAeb605'), Chain.ethereum);
    expect(Chain.guess('TR7NHqje'), Chain.tron);
    expect(Chain.guess(' TR7NHqje'), Chain.tron);
    expect(Chain.guess('mi-ledger'), isNull);
    expect(Chain.guess(''), isNull);
  });
}
