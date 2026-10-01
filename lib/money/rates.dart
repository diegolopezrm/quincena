import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'asset.dart';
import 'money.dart';

/// What one unit of [asset] is worth in [quote]: `USD/COP 3312.84` is one
/// dollar in pesos, `BTC/USDT 84616.92` one bitcoin in tether.
@immutable
class Rate {
  const Rate({
    required this.asset,
    required this.quote,
    required this.value,
    required this.asOf,
    required this.source,
    this.manual = false,
  });

  final String asset;
  final String quote;
  final Decimal value;

  /// The day the source says the rate applies to.
  final DateTime asOf;

  /// Where it came from: `trm`, `binance`, `ecb`, or `manual`.
  final String source;

  /// Typed by the person. A manual rate is never replaced by a fetched one.
  final bool manual;

  String get pair => '$asset/$quote';
}

/// The rates the app knows, and conversions through them.
///
/// A conversion takes the shortest path through known rates, in either
/// direction: crypto goes to tether on Binance, tether to dollars, dollars to
/// pesos with the TRM. Stablecoins count as one dollar when no rate says
/// otherwise, which is close enough for a total and is said where it shows.
class RateTable {
  RateTable(Iterable<Rate> rates) {
    for (final Rate r in rates) {
      if (r.value <= Decimal.zero) continue;
      _edges.putIfAbsent(r.asset, () => <String, _Edge>{})[r.quote] = _Edge(
        r.value,
        r,
      );
      _edges.putIfAbsent(r.quote, () => <String, _Edge>{})[r.asset] = _Edge(
        _inverse(r.value),
        r,
      );
    }
    for (final String stable in _stablecoins) {
      _edges
          .putIfAbsent(stable, () => <String, _Edge>{})
          .putIfAbsent('USD', () => _Edge(Decimal.one, null));
      _edges
          .putIfAbsent('USD', () => <String, _Edge>{})
          .putIfAbsent(stable, () => _Edge(Decimal.one, null));
    }
  }

  static const List<String> _stablecoins = <String>['USDT', 'USDC'];

  final Map<String, Map<String, _Edge>> _edges = <String, Map<String, _Edge>>{};

  static Decimal _inverse(Decimal value) =>
      (Decimal.one / value).toDecimal(scaleOnInfinitePrecision: 18);

  /// What one unit of [from] is worth in [to], or null when no chain of
  /// known rates connects them.
  Decimal? rate(Asset from, Asset to) {
    if (from == to) return Decimal.one;
    final List<_Edge>? path = _path(from.code, to.code);
    if (path == null) return null;
    return path.fold<Decimal>(Decimal.one, (Decimal v, _Edge e) => v * e.value);
  }

  /// [money] in [to], or null when it cannot be converted.
  Money? convert(Money money, Asset to) {
    final Decimal? r = rate(money.asset, to);
    if (r == null) return null;
    return Money(money.amount * r, to);
  }

  /// The rates a conversion from [from] to [to] went through, oldest first,
  /// so a screen can say how current a total is.
  List<Rate> used(Asset from, Asset to) => <Rate>[
    for (final _Edge e in _path(from.code, to.code) ?? const <_Edge>[])
      if (e.rate != null) e.rate!,
  ]..sort((Rate a, Rate b) => a.asOf.compareTo(b.asOf));

  List<_Edge>? _path(String from, String to) {
    final Map<String, (String, _Edge)> came = <String, (String, _Edge)>{};
    final Queue<String> queue = Queue<String>()..add(from);
    final Set<String> seen = <String>{from};
    while (queue.isNotEmpty) {
      final String at = queue.removeFirst();
      if (at == to) break;
      for (final MapEntry<String, _Edge> next
          in (_edges[at] ?? const <String, _Edge>{}).entries) {
        if (!seen.add(next.key)) continue;
        came[next.key] = (at, next.value);
        queue.add(next.key);
      }
    }
    if (!came.containsKey(to)) return null;
    final List<_Edge> path = <_Edge>[];
    for (var at = to; at != from; at = came[at]!.$1) {
      path.add(came[at]!.$2);
    }
    return path.reversed.toList();
  }
}

class _Edge {
  const _Edge(this.value, this.rate);

  final Decimal value;

  /// The rate this edge comes from; null for a stablecoin's dollar peg.
  final Rate? rate;
}
