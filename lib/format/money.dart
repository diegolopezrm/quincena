import 'package:intl/intl.dart';

final NumberFormat _oneDecimal = NumberFormat('#,##0.#', 'es_CO');
final NumberFormat _whole = NumberFormat('#,##0', 'es_CO');

/// Pesos the way they are written in Colombia: `$ 1.650.000`.
///
/// Built by hand rather than with `NumberFormat.currency`, whose `es_CO`
/// pattern puts the symbol after the number.
String pesos(num amount) {
  final String digits = _whole.format(amount.abs().round());
  return '${amount < 0 ? '−' : ''}\$\u00a0$digits';
}

/// Pesos in the short form people say out loud: `$ 4,7 M`, `$ 589 mil`.
String pesosShort(num amount) {
  final num value = amount.abs();
  final String sign = amount < 0 ? '−' : '';
  if (value >= 1000000) {
    return '$sign\$ ${_oneDecimal.format(value / 1000000)} M';
  }
  if (value >= 1000) {
    return '$sign\$ ${_whole.format((value / 1000).round())} mil';
  }
  return '$sign${pesos(value)}';
}

/// A change as a signed percentage: `+67 %`, `−13 %`.
String signedPercent(num current, num previous) {
  if (previous == 0) return '—';
  final double change = (current - previous) / previous * 100;
  final String rounded = _whole.format(change.abs().round());
  if (change.round() == 0) return '0 %';
  return '${change > 0 ? '+' : '−'}$rounded %';
}
