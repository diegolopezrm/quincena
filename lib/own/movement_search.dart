import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../capture/merchants.dart';
import '../domain/pay_schedule.dart';
import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
import '../store/store.dart';

/// The kinds of movement a list can be narrowed to.
enum MovementType {
  expenses,
  incomes,

  /// Moves between the person's own accounts, and crypto bought or sold:
  /// money that changed place or form, never spending.
  transfers,
}

/// The days a list can be narrowed to: the pay period today is in, this
/// month, the month before, or days the person picks.
enum MovementDays { period, thisMonth, lastMonth, range }

/// What the list of movements is narrowed to. Every part is optional and
/// they add up: Bancolombia's restaurants this month, from $50.000.
@immutable
class MovementFilter {
  const MovementFilter({
    this.accounts = const <String>{},
    this.categories = const <String>{},
    this.type,
    this.days,
    this.from,
    this.to,
    this.min,
    this.max,
  });

  /// Movements in any of these accounts; a transfer by either of its ends.
  final Set<String> accounts;

  /// Movements filed under any of these categories, by key.
  final Set<String> categories;
  final MovementType? type;
  final MovementDays? days;

  /// The first and the last day picked, both included, for
  /// [MovementDays.range].
  final DateTime? from;
  final DateTime? to;

  /// How much at least and at most, in the base currency, as the row's
  /// «≈» says it for another currency: a search across currencies compares
  /// one figure.
  final Decimal? min;
  final Decimal? max;

  bool get isEmpty => active == 0;

  /// How many of the filter's parts narrow the list.
  int get active =>
      (accounts.isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (type == null ? 0 : 1) +
      (days == null ? 0 : 1) +
      (min == null && max == null ? 0 : 1);

  MovementFilter copyWith({
    Set<String>? accounts,
    Set<String>? categories,
    MovementType? type,
    bool clearType = false,
    MovementDays? days,
    DateTime? from,
    DateTime? to,
    bool clearDays = false,
    Decimal? min,
    bool clearMin = false,
    Decimal? max,
    bool clearMax = false,
  }) => MovementFilter(
    accounts: accounts ?? this.accounts,
    categories: categories ?? this.categories,
    type: clearType ? null : (type ?? this.type),
    days: clearDays ? null : (days ?? this.days),
    from: clearDays ? null : (from ?? this.from),
    to: clearDays ? null : (to ?? this.to),
    min: clearMin ? null : (min ?? this.min),
    max: clearMax ? null : (max ?? this.max),
  );

  /// The days [days] covers around [today], with [schedule] for the pay
  /// period: from the first moment of its first day to the first moment
  /// after its last. Null when the filter keeps every day.
  (DateTime, DateTime)? span(DateTime today, PaySchedule schedule) {
    final DateTime day = DateTime(today.year, today.month, today.day);
    return switch (days) {
      null => null,
      // From the payday that started it to the one that starts the next.
      MovementDays.period => (
        _dayOf(schedule.lastOnOrBefore(day)),
        _dayOf(schedule.nextAfter(day)),
      ),
      MovementDays.thisMonth => (
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1),
      ),
      MovementDays.lastMonth => (
        DateTime(day.year, day.month - 1),
        DateTime(day.year, day.month),
      ),
      MovementDays.range => switch ((from, to)) {
        (final DateTime from, final DateTime to) => (
          _dayOf(from),
          DateTime(to.year, to.month, to.day + 1),
        ),
        _ => null,
      },
    };
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  bool operator ==(Object other) =>
      other is MovementFilter &&
      setEquals(other.accounts, accounts) &&
      setEquals(other.categories, categories) &&
      other.type == type &&
      other.days == days &&
      other.from == from &&
      other.to == to &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(accounts),
    Object.hashAllUnordered(categories),
    type,
    days,
    from,
    to,
    min,
    max,
  );
}

/// The amounts [query] may be, when it is written as an amount and nothing
/// else: «187400», «187.400», «$187.400», «−$187.400», «US$10,99» or
/// «0,0042 BTC». A separator reads either way, as Spanish and English
/// write it, and each reading that makes sense counts: «187.400» is
/// $187.400 in Spanish and 187,4 in English, «10.99» only ten and
/// ninety-nine. Empty for words, even with a figure in them: «D1» is a
/// shop, not one peso, and «Fit24» a gym.
List<Decimal> amountsIn(String query) {
  String s = query.trim();
  // A sign, then a currency's symbol: $, US$, COL$, R$, €, £.
  s = s.replaceFirst(RegExp(r'^[+\-−]\s*'), '');
  s = s.replaceFirst(RegExp(r'^[A-Za-z]{0,3}[$€£]\s*'), '');
  s = s.replaceFirst(RegExp(r'^[+\-−]\s*'), '');
  // Or a currency's code after it: COP, USD, BTC, USDT.
  final RegExpMatch? code = RegExp(r'\s*([A-Za-z]{3,5})$').firstMatch(s);
  if (code != null) {
    if (!_codes.contains(code[1]!.toUpperCase())) return const <Decimal>[];
    s = s.substring(0, code.start);
  }
  if (!RegExp(r'^\d[\d.,]*$').hasMatch(s)) return const <Decimal>[];
  return <Decimal>{
    ?_read(s, group: '.', point: ','),
    ?_read(s, group: ',', point: '.'),
  }.toList();
}

/// The codes of the currencies and coins the app knows.
final Set<String> _codes = <String>{
  for (final Asset a in <Asset>[...Asset.fiat, ...Asset.crypto]) a.code,
};

/// [s] read with [group] between thousands and [point] before the
/// decimals, or null when it is not written that way: groups after the
/// first have three digits, and the decimals come after all of them.
Decimal? _read(String s, {required String group, required String point}) {
  final int at = s.indexOf(point);
  if (at != s.lastIndexOf(point)) return null;
  final String whole = at < 0 ? s : s.substring(0, at);
  final String decimals = at < 0 ? '' : s.substring(at + 1);
  if (whole.isEmpty || decimals.contains(group)) return null;
  final List<String> groups = whole.split(group);
  if (groups.length > 1 &&
      (groups.first.isEmpty ||
          groups.first.length > 3 ||
          groups.skip(1).any((String g) => g.length != 3))) {
    return null;
  }
  final String digits = groups.join();
  return Decimal.tryParse(decimals.isEmpty ? digits : '$digits.$decimals');
}

/// Finds movements by what a person types and the filter they chose.
///
/// Made once for a list: it knows each transfer's two legs and each
/// account's and category's name as a search compares them, so one search
/// is one pass over the movements, however many there are.
class MovementFinder {
  MovementFinder({
    required this.snapshot,
    required this.categoryName,
    required this.today,
    required this.schedule,
  }) : _table = RateTable(snapshot.rates) {
    for (final Account a in snapshot.accounts) {
      _accounts[a.id] = a;
      _accountWords[a.id] = normalize(a.name);
    }
    for (final Entry e in snapshot.entries) {
      if (e.transferId case final String t) {
        (_legs[t] ??= <Entry>[]).add(e);
      }
    }
  }

  final StoreSnapshot snapshot;

  /// What the person calls the category with a key, in the interface's
  /// language.
  final String Function(String key) categoryName;
  final DateTime today;

  /// How the person is paid, for the days of the pay period.
  final PaySchedule schedule;

  final RateTable _table;
  final Map<String, Account> _accounts = <String, Account>{};
  final Map<String, String> _accountWords = <String, String>{};
  final Map<String, String> _categoryWords = <String, String>{};
  final Map<String, List<Entry>> _legs = <String, List<Entry>>{};
  final Map<Asset, Decimal?> _toBase = <Asset, Decimal?>{};

  Asset get _base => snapshot.profile.base;

  /// The account [id], archived ones included.
  Account? account(String id) => _accounts[id];

  /// The other leg of [e], when it is one side of a transfer.
  Entry? otherLeg(Entry e) {
    final String? transfer = e.transferId;
    if (transfer == null) return null;
    for (final Entry leg in _legs[transfer] ?? const <Entry>[]) {
      if (leg.id != e.id) return leg;
    }
    return null;
  }

  /// Those of [entries] that have what [query] says and pass [filter], in
  /// the order they came.
  List<Entry> find(
    Iterable<Entry> entries, {
    String query = '',
    MovementFilter filter = const MovementFilter(),
  }) {
    final String words = normalize(query);
    final List<Decimal> amounts = amountsIn(query);
    final (DateTime, DateTime)? span = filter.span(today, schedule);
    return <Entry>[
      for (final Entry e in entries)
        if ((words.isEmpty && amounts.isEmpty) || _says(e, words, amounts))
          if (_passes(e, filter, span)) e,
    ];
  }

  /// Whether [e] has [words], already normalized, in what it was, its
  /// note, its category or either of its accounts, or is for one of
  /// [amounts]: what left or arrived, or what a trade cost.
  bool _says(Entry e, String words, List<Decimal> amounts) {
    final Entry? other = otherLeg(e);
    if (amounts.isNotEmpty) {
      final List<Decimal> its = <Decimal>[
        e.amount.abs(),
        ?other?.amount.abs(),
        ?e.cost?.amount.abs(),
      ];
      if (its.any((Decimal a) => amounts.any((Decimal b) => a == b))) {
        return true;
      }
    }
    if (words.isEmpty) return false;
    final String? category = e.category;
    return <String>[
      normalize(e.payee),
      normalize(e.note),
      _accountWords[e.accountId] ?? '',
      if (other != null) _accountWords[other.accountId] ?? '',
      if (category != null)
        _categoryWords[category] ??= normalize(categoryName(category)),
    ].any((String s) => s.contains(words));
  }

  bool _passes(Entry e, MovementFilter f, (DateTime, DateTime)? span) {
    if (f.isEmpty) return true;
    if (f.accounts.isNotEmpty &&
        !f.accounts.contains(e.accountId) &&
        !f.accounts.contains(otherLeg(e)?.accountId)) {
      return false;
    }
    if (f.categories.isNotEmpty && !f.categories.contains(e.category)) {
      return false;
    }
    if (f.type case final MovementType type when !_isOf(e, type)) {
      return false;
    }
    if (span != null &&
        (e.date.isBefore(span.$1) || !e.date.isBefore(span.$2))) {
      return false;
    }
    if (f.min != null || f.max != null) {
      final Decimal? amount = _inBase(e);
      if (amount == null) return false;
      if (f.min case final Decimal min when amount < min) return false;
      if (f.max case final Decimal max when amount > max) return false;
    }
    return true;
  }

  static bool _isOf(Entry e, MovementType type) => switch (type) {
    MovementType.expenses =>
      !e.isTransfer && !e.isTrade && e.kind == EntryKind.expense,
    MovementType.incomes =>
      !e.isTransfer && !e.isTrade && e.kind == EntryKind.income,
    MovementType.transfers => e.isTransfer || e.isTrade,
  };

  /// How much [e] moved in the base currency, without its sign; null with
  /// no rate to it.
  Decimal? _inBase(Entry e) {
    final Asset? asset = _accounts[e.accountId]?.asset;
    if (asset == null) return null;
    if (asset == _base) return e.amount.abs();
    final Decimal? rate = _toBase.putIfAbsent(
      asset,
      () => _table.rate(asset, _base),
    );
    return rate == null ? null : e.amount.abs() * rate;
  }

  /// What [entries] add up to in each currency, the base currency first,
  /// without the moves between the person's own accounts.
  List<Money> totals(Iterable<Entry> entries) => totalsOf(
    entries,
    assetOf: (String id) => _accounts[id]?.asset,
    base: _base,
  );
}

/// What [entries] add up to in each currency they are in, [base] first:
/// each one signed, as its row shows it. Moves between the person's own
/// accounts count only with [transfers], as in one account's list, where
/// they move its money; among all the movements they leave what the person
/// has the same. [assetOf] says what each account holds.
List<Money> totalsOf(
  Iterable<Entry> entries, {
  required Asset? Function(String accountId) assetOf,
  Asset? base,
  bool transfers = false,
}) {
  final Map<Asset, Decimal> sums = <Asset, Decimal>{};
  for (final Entry e in entries) {
    if (e.isTransfer && !transfers) continue;
    final Asset? asset = assetOf(e.accountId);
    if (asset == null) continue;
    sums[asset] = (sums[asset] ?? Decimal.zero) + e.amount;
  }
  final List<Asset> order = sums.keys.toList()
    ..sort(
      (Asset a, Asset b) => a == base
          ? -1
          : b == base
          ? 1
          : a.code.compareTo(b.code),
    );
  return <Money>[for (final Asset a in order) Money(sums[a]!, a)];
}
