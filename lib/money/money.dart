import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import 'asset.dart';

/// An amount of one asset.
///
/// Decimal, never a float: a balance of 0.00012345 BTC or of 4.719.400 pesos
/// is stored and added exactly, and only rounded where it is shown.
@immutable
class Money {
  const Money(this.amount, this.asset);

  Money.zero(this.asset) : amount = Decimal.zero;

  /// Parses the plain decimal form the database stores, such as `-45900` or
  /// `0.00012345`.
  factory Money.parse(String amount, Asset asset) =>
      Money(Decimal.parse(amount), asset);

  final Decimal amount;
  final Asset asset;

  bool get isNegative => amount < Decimal.zero;
  bool get isZero => amount == Decimal.zero;

  Money operator +(Money other) {
    _check(other);
    return Money(amount + other.amount, asset);
  }

  Money operator -(Money other) {
    _check(other);
    return Money(amount - other.amount, asset);
  }

  Money operator -() => Money(-amount, asset);

  Money abs() => Money(amount.abs(), asset);

  void _check(Money other) {
    if (other.asset != asset) {
      throw ArgumentError('Cannot combine ${other.asset} with $asset');
    }
  }

  /// As the interface writes it; see [formatAmount].
  String format({Asset? base, bool signed = false}) =>
      formatAmount(amount, asset, base: base, signed: signed);

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.asset == asset;

  @override
  int get hashCode => Object.hash(amount, asset);

  @override
  String toString() => '$amount $asset';
}

const String _nbsp = ' ';

/// [amount] of [asset] as the interface language writes it.
///
/// Spanish: `$ 45.900`, `US$ 1.250,00`, `0,0042 BTC`. English: `$45,900`,
/// `US$1,250.00`, `0.0042 BTC`. The bare local symbol (`$`) is kept for
/// [base], the person's own currency; every other currency carries one that
/// cannot be mistaken for it, so pesos and dollars side by side stay apart.
/// Crypto is written with its ticker after the number and no trailing zeros.
String formatAmount(
  Decimal amount,
  Asset asset, {
  Asset? base,
  bool signed = false,
  int? decimals,
}) {
  final bool en = englishFormatting;
  final String sign = amount < Decimal.zero
      ? '−'
      : (signed && amount > Decimal.zero ? '+' : '');
  final String digits = formatDecimal(
    amount.abs(),
    decimals: decimals ?? asset.decimals,
    trim: asset.isCrypto || decimals != null,
  );
  if (asset.isCrypto) return '$sign$digits$_nbsp${asset.code}';
  final String symbol =
      (asset == (base ?? asset) ? asset.localSymbol : asset.symbol) ??
      asset.code;
  return en ? '$sign$symbol$digits' : '$sign$symbol$_nbsp$digits';
}

/// [value] with the interface language's separators: `1.250,5` in Spanish,
/// `1,250.5` in English.
///
/// Built from the decimal's own digits rather than through a double, so a
/// crypto amount keeps every one of its decimals. [trim] drops trailing zeros.
String formatDecimal(
  Decimal value, {
  required int decimals,
  bool trim = false,
}) {
  final bool en = englishFormatting;
  String fixed = value.round(scale: decimals).toStringAsFixed(decimals);
  if (trim && fixed.contains('.')) {
    fixed = fixed.replaceFirst(RegExp(r'0+$'), '');
    if (fixed.endsWith('.')) fixed = fixed.substring(0, fixed.length - 1);
  }
  final bool negative = fixed.startsWith('-');
  if (negative) fixed = fixed.substring(1);
  final List<String> parts = fixed.split('.');
  final String whole = _group(parts.first, en ? ',' : '.');
  final String sign = negative ? '-' : '';
  if (parts.length == 1) return '$sign$whole';
  return '$sign$whole${en ? '.' : ','}${parts[1]}';
}

String _group(String digits, String separator) {
  final StringBuffer out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(separator);
    out.write(digits[i]);
  }
  return out.toString();
}

/// Reads an amount the way a person types it, or null if it is not one.
///
/// Spanish writes `45.900` and `1.250,50`; English `45,900` and `1,250.50`.
/// A single separator followed by one or two digits at the end is read as
/// the decimal point in either language, since `0.5` typed on a Spanish
/// keyboard means half, not five hundred.
Decimal? parseAmount(String text, {bool? english}) {
  final bool en = english ?? englishFormatting;
  String s = text.trim().replaceAll(RegExp(r'[^0-9.,\-]'), '');
  if (s.isEmpty || s == '-') return null;
  final bool negative = s.startsWith('-');
  s = s.replaceAll('-', '');
  final String group = en ? ',' : '.';
  final String point = en ? '.' : ',';
  final int groups = group.allMatches(s).length;
  final int points = point.allMatches(s).length;
  if (points == 0 && groups == 1 && RegExp('\\$group\\d{1,2}\$').hasMatch(s)) {
    // `0.5` in Spanish, `0,5` in English: one separator, a short tail.
    s = s.replaceAll(group, '.');
  } else {
    if (points > 1) return null;
    s = s.replaceAll(group, '').replaceAll(point, '.');
  }
  final Decimal? value = Decimal.tryParse(s);
  if (value == null) return null;
  return negative ? -value : value;
}
