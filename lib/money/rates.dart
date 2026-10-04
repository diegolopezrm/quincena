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

/// What one leg of a conversion is, for a person reading it.
enum RateStepKind {
  /// What a coin trades at on an exchange: bitcoin in tether.
  price,

  /// A stablecoin counted as one dollar, with no rate behind it.
  peg,

  /// One currency in another, from an official source: the TRM.
  conversion,

  /// A rate the person typed.
  manual,
}

/// One leg of a conversion: what one [from] is worth in [to], and the rate
/// behind it.
@immutable
class RateStep {
  const RateStep({
    required this.from,
    required this.to,
    required this.value,
    this.rate,
  });

  final String from;
  final String to;

  /// One [from] in [to], in the direction the conversion goes.
  final Decimal value;

  /// The rate this leg comes from; null for a stablecoin's dollar peg.
  final Rate? rate;

  RateStepKind get kind => switch (rate) {
    null => RateStepKind.peg,
    Rate(manual: true) => RateStepKind.manual,
    Rate(:final String asset) when Asset.of(asset).isCrypto =>
      RateStepKind.price,
    _ => RateStepKind.conversion,
  };
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
    final List<RateStep>? path = _path(from.code, to.code);
    if (path == null) return null;
    return path.fold<Decimal>(
      Decimal.one,
      (Decimal v, RateStep s) => v * s.value,
    );
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
    for (final RateStep s in steps(from, to))
      if (s.rate != null) s.rate!,
  ]..sort((Rate a, Rate b) => a.asOf.compareTo(b.asOf));

  /// The legs of a conversion from [from] to [to], in the order it goes:
  /// for bitcoin in pesos, its price in tether, tether as a dollar, and the
  /// dollar in pesos. Empty when they are the same or nothing connects them.
  List<RateStep> steps(Asset from, Asset to) =>
      _path(from.code, to.code) ?? const <RateStep>[];

  List<RateStep>? _path(String from, String to) {
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
    final List<RateStep> path = <RateStep>[];
    for (var at = to; at != from; at = came[at]!.$1) {
      final (String before, _Edge e) = came[at]!;
      path.add(RateStep(from: before, to: at, value: e.value, rate: e.rate));
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
