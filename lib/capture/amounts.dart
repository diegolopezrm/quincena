import 'package:decimal/decimal.dart';

import '../money/asset.dart';

/// An amount found in a message, and the asset it is in when the message
/// says.
class FoundAmount {
  const FoundAmount(this.value, this.asset, this.start, this.end);

  final Decimal value;

  /// Null when the message wrote only a bare `$`, which in Colombia means
  /// pesos but on a dollar card means dollars.
  final Asset? asset;
  final int start;
  final int end;
}

const Map<String, String> _markers = <String, String>{
  r'US$': 'USD',
  'USD': 'USD',
  'U\$S': 'USD',
  'COP': 'COP',
  r'COL$': 'COP',
  'EUR': 'EUR',
  '€': 'EUR',
  r'MX$': 'MXN',
  'MXN': 'MXN',
  'USDT': 'USDT',
  'USDC': 'USDC',
  'BTC': 'BTC',
  'ETH': 'ETH',
  'BNB': 'BNB',
  'SOL': 'SOL',
};

final RegExp _number = RegExp(
  r'\d{1,3}(?:[.,\s]\d{3})+(?:[.,]\d{1,8})?|\d+(?:[.,]\d{1,8})?',
);

final RegExp _amount = RegExp(
  r'(US\$|U\$S|COL\$|MX\$|USD|COP|EUR|MXN|€|\$)\s?(' +
      _number.pattern +
      r')|(' +
      _number.pattern +
      r')\s?(USDT|USDC|USD|COP|EUR|MXN|BTC|ETH|BNB|SOL)\b',
  caseSensitive: false,
);

/// Every amount in [text] that carries a currency marker, in order.
///
/// A number with no `$` and no code next to it is a date, a time or a card,
/// not an amount, and is left out.
List<FoundAmount> findAmounts(String text) => <FoundAmount>[
  for (final RegExpMatch m in _amount.allMatches(text))
    if (_read(m) case final FoundAmount found) found,
];

FoundAmount? _read(RegExpMatch m) {
  final String marker = (m.group(1) ?? m.group(4) ?? '').toUpperCase();
  final String digits = m.group(2) ?? m.group(3) ?? '';
  final String? code = marker == r'$' ? null : _markers[marker];
  final Asset? asset = code == null ? null : Asset.of(code);
  final Decimal? value = parseLooseNumber(
    digits,
    crypto: asset?.isCrypto ?? false,
  );
  if (value == null || value <= Decimal.zero) return null;
  return FoundAmount(value, asset, m.start, m.end);
}

/// Reads a number the way banks and apps write them, whichever convention
/// they follow: `45.900,00` and `45,900.00` are both forty-five thousand nine
/// hundred, `10,99` and `10.99` both ten ninety-nine.
///
/// With one kind of separator, three digits after it mean thousands for
/// money (`45.900`) and decimals for crypto, where `0,001 BTC` is a
/// thousandth. A leading zero always means decimals.
Decimal? parseLooseNumber(String raw, {bool crypto = false}) {
  final String s = raw.replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return null;
  final int lastDot = s.lastIndexOf('.');
  final int lastComma = s.lastIndexOf(',');
  String normalized;
  if (lastDot >= 0 && lastComma >= 0) {
    // Both: the last one is the decimal point.
    final String point = lastDot > lastComma ? '.' : ',';
    final String group = point == '.' ? ',' : '.';
    normalized = s.replaceAll(group, '').replaceAll(point, '.');
  } else if (lastDot >= 0 || lastComma >= 0) {
    final String sep = lastDot >= 0 ? '.' : ',';
    final List<String> parts = s.split(sep);
    final bool grouped =
        parts.length > 2 ||
        (parts.last.length == 3 && !crypto && parts.first != '0');
    normalized = grouped ? parts.join() : parts.join('.');
  } else {
    normalized = s;
  }
  return Decimal.tryParse(normalized);
}
