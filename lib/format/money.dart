import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

final NumberFormat _oneDecimalEs = NumberFormat('#,##0.#', 'es_CO');
final NumberFormat _wholeEs = NumberFormat('#,##0', 'es_CO');
final NumberFormat _oneDecimalEn = NumberFormat('#,##0.#', 'en_US');
final NumberFormat _wholeEn = NumberFormat('#,##0', 'en_US');

NumberFormat get _whole => englishFormatting ? _wholeEn : _wholeEs;
NumberFormat get _oneDecimal =>
    englishFormatting ? _oneDecimalEn : _oneDecimalEs;

/// Pesos as they are written in the interface language: `$ 1.650.000` in
/// Spanish, `$1,650,000` in English.
///
/// Built by hand rather than with `NumberFormat.currency`, whose `es_CO`
/// pattern puts the symbol after the number.
String pesos(num amount) {
  final String digits = _whole.format(amount.abs().round());
  final String sign = amount < 0 ? '−' : '';
  return englishFormatting ? '$sign\$$digits' : '$sign\$ $digits';
}

/// Pesos in the short form people say out loud: `$ 4,7 M` and `$ 589 mil` in
/// Spanish, `$4.7M` and `$589K` in English.
String pesosShort(num amount) {
  final num value = amount.abs();
  final String sign = amount < 0 ? '−' : '';
  final bool en = englishFormatting;
  if (value >= 1000000) {
    final String n = _oneDecimal.format(value / 1000000);
    return en ? '$sign\$${n}M' : '$sign\$ $n M';
  }
  if (value >= 1000) {
    final String n = _whole.format((value / 1000).round());
    return en ? '$sign\$${n}K' : '$sign\$ $n mil';
  }
  return '$sign${pesos(value)}';
}

/// A change as a signed percentage: `+67 %` in Spanish, `+67%` in English.
String signedPercent(num current, num previous) {
  if (previous == 0) return '—';
  final double change = (current - previous) / previous * 100;
  final String space = englishFormatting ? '' : ' ';
  if (change.round() == 0) return '0$space%';
  final String rounded = _whole.format(change.abs().round());
  return '${change > 0 ? '+' : '−'}$rounded$space%';
}
