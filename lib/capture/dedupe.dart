import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../domain/records.dart';
import '../money/asset.dart';
import 'event.dart';
import 'merchants.dart';

/// A movement already known, from the inbox or from the accounts, in the
/// terms two captures of the same payment share.
@immutable
class Sighting {
  const Sighting({
    required this.id,
    required this.amount,
    required this.kind,
    required this.when,
    this.asset,
    this.merchant,
    this.source,
  });

  final String id;

  /// Positive.
  final Decimal amount;
  final Asset? asset;
  final EntryKind kind;
  final DateTime when;
  final String? merchant;

  /// Null for a movement in the accounts, which may have been entered by
  /// hand at any hour of the day it happened.
  final CaptureSource? source;
}

/// Whether [a] and [b] are the same payment seen twice.
///
/// One Apple Pay purchase can arrive as the Wallet's record, the bank's
/// push, an SMS and an email. They share the amount and the direction, and
/// arrive within minutes of each other, an email within hours. A movement
/// entered by hand, a screenshot or a text the person shares can come any
/// time that day or the next. When both name a merchant, the names have to
/// share a word: two different $20.000 payments a few minutes apart do
/// happen.
bool samePayment(Sighting a, Sighting b) {
  if (a.amount != b.amount || a.kind != b.kind) return false;
  if (a.asset != null && b.asset != null && a.asset != b.asset) return false;
  bool whenever(CaptureSource? s) =>
      s == null || s == CaptureSource.screenshot || s == CaptureSource.paste;
  final Duration window = whenever(a.source) || whenever(b.source)
      ? const Duration(hours: 36)
      : a.source == CaptureSource.email || b.source == CaptureSource.email
      ? const Duration(hours: 6)
      : const Duration(minutes: 30);
  if (a.when.difference(b.when).abs() > window) return false;
  final String? ma = a.merchant;
  final String? mb = b.merchant;
  if (ma == null || mb == null || ma.isEmpty || mb.isEmpty) return true;
  return similarNames(ma, mb);
}

/// Whether two merchant names are likely the same place: one contains the
/// other, or they share a word of three letters or more.
bool similarNames(String a, String b) {
  final String na = merchantKey(a);
  final String nb = merchantKey(b);
  if (na.isEmpty || nb.isEmpty) return true;
  if (na.contains(nb) || nb.contains(na)) return true;
  final Set<String> wa = na
      .split(' ')
      .where((String w) => w.length >= 3)
      .toSet();
  final Set<String> wb = nb
      .split(' ')
      .where((String w) => w.length >= 3)
      .toSet();
  return wa.intersection(wb).isNotEmpty;
}

/// The first of [known] that [s] repeats, or null.
Sighting? duplicateOf(Sighting s, Iterable<Sighting> known) {
  for (final Sighting k in known) {
    if (k.id != s.id && samePayment(s, k)) return k;
  }
  return null;
}
