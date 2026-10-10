import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../capture/merchants.dart';
import '../data/category.dart';
import '../data/ledger.dart';
import 'categories.dart';
import 'records.dart';

// Subscriptions -------------------------------------------------------------

/// What the person told the app about a recurring charge.
@immutable
class ChargeMemory {
  const ChargeMemory({
    this.trialEnds,
    this.remindDays,
    this.usedAt,
    this.inUse,
  });

  /// When a free trial turns into a charge.
  final DateTime? trialEnds;

  /// How many days before each renewal to remind; null for none.
  final int? remindDays;

  /// When the person last said whether they use it, and what they said.
  final DateTime? usedAt;
  final bool? inUse;

  Map<String, Object?> toJson() => <String, Object?>{
    if (trialEnds != null) 'trialEnds': _iso(trialEnds!),
    if (remindDays != null) 'remindDays': remindDays,
    if (usedAt != null) 'usedAt': _iso(usedAt!),
    if (inUse != null) 'inUse': inUse,
  };

  static ChargeMemory fromJson(Object? json) {
    if (json is! Map) return const ChargeMemory();
    return ChargeMemory(
      trialEnds: DateTime.tryParse('${json['trialEnds']}'),
      remindDays: (json['remindDays'] as num?)?.round(),
      usedAt: DateTime.tryParse('${json['usedAt']}'),
      inUse: json['inUse'] as bool?,
    );
  }

  ChargeMemory copyWith({
    DateTime? trialEnds,
    bool clearTrial = false,
    int? remindDays,
    bool clearRemind = false,
    DateTime? usedAt,
    bool? inUse,
  }) => ChargeMemory(
    trialEnds: clearTrial ? null : trialEnds ?? this.trialEnds,
    remindDays: clearRemind ? null : remindDays ?? this.remindDays,
    usedAt: usedAt ?? this.usedAt,
    inUse: inUse ?? this.inUse,
  );
}

/// The next day [charge] is charged after [today], counting from its
/// recorded next day by its cadence.
/// When [charge] is charged next if it began charging the day its trial
/// ended, [trial]: its cadence on from that day, after [today].
DateTime afterTrial(RecurringCharge charge, DateTime trial, DateTime today) =>
    nextCharge(charge.withNextDate(trial), today);

DateTime nextCharge(RecurringCharge charge, DateTime today) {
  final DateTime day = _day(today);
  DateTime d = _day(charge.nextDate);
  while (!d.isAfter(day)) {
    d = _day(charge.cadence.after(d));
  }
  return d;
}

/// How many times [cadence] charges in a year.
double perYear(Cadence cadence) => switch (cadence) {
  Cadence.monthly => 12,
  Cadence.yearly => 1,
  Cadence.biweekly => 26,
  Cadence.weekly => 52,
};

/// A price that moved between two charges of the same merchant.
@immutable
class PriceChange {
  const PriceChange({required this.from, required this.to, required this.on});

  /// In the ledger's unit.
  final int from;
  final int to;
  final DateTime on;
}

/// The last change in what [name] charged, from the movements whose
/// merchant reads the same; null when it charged the same, or once.
PriceChange? lastPriceChange(Ledger ledger, String name) {
  final String key = merchantKey(name);
  if (key.isEmpty) return null;
  final List<Movement> paid = <Movement>[
    for (final Movement m in ledger.movements)
      if (m.flow == Flow.expense &&
          ledger.settled(m) &&
          merchantKey(m.merchant) == key)
        m,
  ]..sort((Movement a, Movement b) => a.date.compareTo(b.date));
  for (var i = paid.length - 1; i > 0; i--) {
    if (paid[i].amount != paid[i - 1].amount) {
      return PriceChange(
        from: paid[i - 1].amount,
        to: paid[i].amount,
        on: paid[i].date,
      );
    }
  }
  return null;
}

/// The last charge whose merchant reads like [name], or null.
Movement? lastChargeOf(Ledger ledger, String name) {
  final String key = merchantKey(name);
  if (key.isEmpty) return null;
  Movement? last;
  for (final Movement m in ledger.movements) {
    if (m.flow != Flow.expense || !ledger.settled(m)) continue;
    if (merchantKey(m.merchant) != key) continue;
    if (last == null || !m.date.isBefore(last.date)) last = m;
  }
  return last;
}

/// A merchant charged about the same each month, not yet a recurring
/// charge: offered, never added on its own.
@immutable
class RecurringGuess {
  const RecurringGuess({
    required this.name,
    required this.amount,
    required this.next,
    required this.category,
    required this.evidence,
  });

  final String name;

  /// The last charge, in the ledger's unit.
  final int amount;
  final DateTime next;
  final Category category;
  final List<Movement> evidence;
}

/// What is paid every month even when the app has seen it once: rent,
/// utilities and loans.
const Set<Category> monthlyKinds = <Category>{
  Category.housing,
  Category.utilities,
  Category.debt,
};

/// Merchants charged two or more times, about a month apart and for about
/// the same, over the last [days] days; and rent, utilities and loans paid
/// once in the last [once] days, which come every month all the same. A
/// payment's month in its name («Arriendo octubre») is left out of it.
List<RecurringGuess> guessRecurring(
  Ledger ledger, {
  required Iterable<String> known,
  int days = 130,
  int once = 45,
}) {
  final DateTime today = _day(ledger.today);
  final DateTime since = today.subtract(Duration(days: days));
  final Set<String> skip = <String>{
    for (final String k in known) merchantKey(plainChargeName(k)),
  };
  final Map<String, List<Movement>> by = <String, List<Movement>>{};
  for (final Movement m in ledger.movements) {
    if (m.flow != Flow.expense || !ledger.settled(m)) continue;
    if (_day(m.date).isBefore(since)) continue;
    final String key = merchantKey(plainChargeName(m.merchant));
    if (key.isEmpty || skip.contains(key)) continue;
    by.putIfAbsent(key, () => <Movement>[]).add(m);
  }
  final List<RecurringGuess> out = <RecurringGuess>[];
  for (final List<Movement> group in by.values) {
    group.sort((Movement a, Movement b) => a.date.compareTo(b.date));
    final Movement last = group.last;
    var monthly = group.length >= 2;
    for (var i = 1; monthly && i < group.length; i++) {
      final int gap = _day(
        group[i].date,
      ).difference(_day(group[i - 1].date)).inDays;
      final double ratio = group[i].amount / math.max(1, group[i - 1].amount);
      if (gap < 26 || gap > 35 || ratio < 0.85 || ratio > 1.15) {
        monthly = false;
      }
    }
    // Seen once, what is paid every month by its kind, while it is recent.
    final bool essential =
        group.length == 1 &&
        monthlyKinds.contains(last.category) &&
        today.difference(_day(last.date)).inDays <= once;
    if (!monthly && !essential) continue;
    DateTime next = DateTime(
      last.date.year,
      last.date.month + 1,
      last.date.day,
    );
    while (!next.isAfter(today)) {
      next = DateTime(next.year, next.month + 1, next.day);
    }
    out.add(
      RecurringGuess(
        name: plainChargeName(last.merchant),
        amount: last.amount,
        next: next,
        category: last.category,
        evidence: List<Movement>.unmodifiable(group),
      ),
    );
  }
  out.sort(
    (RecurringGuess a, RecurringGuess b) => b.amount.compareTo(a.amount),
  );
  return out;
}

/// [name] without the month or the year a payment's name often carries:
/// «Arriendo octubre» is «Arriendo», «Cuota 2026» is «Cuota».
String plainChargeName(String name) {
  final String plain = name
      .split(RegExp(r'\s+'))
      .where(
        (String w) =>
            !_monthWords.contains(normalize(w)) &&
            !RegExp(r'^(19|20)\d\d$').hasMatch(w),
      )
      .join(' ')
      .trim();
  return plain.isEmpty ? name : plain;
}

const Set<String> _monthWords = <String>{
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'setiembre',
  'octubre',
  'noviembre',
  'diciembre',
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
};

// Installments --------------------------------------------------------------

/// How a lender states a rate.
enum RateKind {
  /// Efectiva anual, E.A.
  effectiveAnnual,

  /// Nominal anual paid monthly, M.V.
  nominalMonthly,

  /// Already per month.
  monthly,
}

/// One instalment due, as the schedule works it out.
@immutable
class InstalmentRow {
  const InstalmentRow({
    required this.number,
    required this.due,
    required this.payment,
    required this.interest,
    required this.principal,
    required this.balance,
  });

  final int number;
  final DateTime due;

  /// What is due: interest, principal and the fee when known.
  final int payment;
  final int interest;
  final int principal;

  /// What is left owed after it.
  final int balance;
}

/// A purchase in instalments, as the person typed it from the bank: the
/// amount financed, how many instalments, and the rate, the instalment or
/// both, with any monthly fee. What the bank did not say stays unknown,
/// and nothing built on it is called final.
@immutable
class Instalments {
  const Instalments({
    required this.id,
    required this.name,
    required this.principal,
    required this.count,
    required this.firstDue,
    this.rate,
    this.rateKind = RateKind.effectiveAnnual,
    this.instalment,
    this.fee,
    this.cashPrice,
    this.accountId,
    this.payments = const <(DateTime, int)>[],
    this.paymentEntries = const <String?>[],
  });

  final String id;
  final String name;

  /// What was financed, in the ledger's unit.
  final int principal;
  final int count;
  final DateTime firstDue;

  /// In percent, as the bank states it; null when unknown. Zero is known.
  final double? rate;
  final RateKind rateKind;

  /// The instalment the bank says, without the fee; null when unknown.
  final int? instalment;

  /// A monthly fee or insurance per instalment; null when unknown, zero
  /// when there is none.
  final int? fee;

  /// What it cost paying at once, to compare.
  final int? cashPrice;
  final String? accountId;

  /// What the person paid towards it: partial payments included.
  final List<(DateTime, int)> payments;

  /// The movement each of [payments] went out with, in the same order:
  /// null for one paid from no account in Quincena, or recorded before
  /// payments had movements.
  final List<String?> paymentEntries;

  /// The movement the [index]th payment went out with, if any.
  String? entryOf(int index) =>
      index < paymentEntries.length ? paymentEntries[index] : null;

  /// The rate per month, or null when unknown.
  double? get monthlyRate {
    final double? r = rate;
    if (r == null) return null;
    final double x = r / 100;
    return switch (rateKind) {
      RateKind.effectiveAnnual => math.pow(1 + x, 1 / 12) - 1,
      RateKind.nominalMonthly => x / 12,
      RateKind.monthly => x,
    }.toDouble();
  }

  /// The rate a month that the stated [instalment] implies for [principal]
  /// over [count] months, when the rate itself was not said: what the bank
  /// charges, worked back. Null without an instalment or with a rate; zero
  /// when the instalments add up to no more than what was financed.
  double? get impliedMonthlyRate {
    final int? p = instalment;
    if (rate != null || p == null || count < 1 || principal <= 0) return null;
    if (p * count <= principal) return 0;
    double paymentAt(double i) =>
        principal * i / (1 - math.pow(1 + i, -count).toDouble());
    var low = 0.0;
    var high = 1.0;
    for (var k = 0; k < 60; k++) {
      final double mid = (low + high) / 2;
      if (paymentAt(mid) > p) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return (low + high) / 2;
  }

  /// The instalment before any fee: the bank's when it said one, else
  /// worked out from the rate; null when neither is known.
  int? get payment {
    if (instalment != null) return instalment;
    final double? i = monthlyRate;
    if (i == null) return null;
    if (i == 0) return (principal / count).ceil();
    return (principal * i / (1 - math.pow(1 + i, -count))).round();
  }

  /// Whether [payment] came from the bank rather than the rate.
  bool get paymentStated => instalment != null;

  /// What each instalment asks, the fee included when known.
  int? get due {
    final int? p = payment;
    return p == null ? null : p + (fee ?? 0);
  }

  /// The schedule, when the instalment is known. Interest is split out
  /// only when the rate is known too.
  List<InstalmentRow> get schedule {
    final int? p = payment;
    if (p == null) return const <InstalmentRow>[];
    final double? i = monthlyRate;
    DateTime dueOn(int k) =>
        DateTime(firstDue.year, firstDue.month + k - 1, firstDue.day);
    if (i == null) {
      // The bank's instalment with no rate to split it: interest is in
      // there but unknown, so what is owed is counted in instalments.
      return <InstalmentRow>[
        for (var k = 1; k <= count; k++)
          InstalmentRow(
            number: k,
            due: dueOn(k),
            payment: p + (fee ?? 0),
            interest: 0,
            principal: p,
            balance: (count - k) * p,
          ),
      ];
    }
    final List<InstalmentRow> rows = <InstalmentRow>[];
    var balance = principal;
    for (var k = 1; k <= count; k++) {
      final int interest = (balance * i).round();
      // The last one settles whatever rounding left.
      final int toPrincipal = k == count
          ? balance
          : math.min(balance, p - interest);
      balance -= toPrincipal;
      rows.add(
        InstalmentRow(
          number: k,
          due: dueOn(k),
          payment: (k == count ? toPrincipal + interest : p) + (fee ?? 0),
          interest: interest,
          principal: toPrincipal,
          balance: balance,
        ),
      );
    }
    return rows;
  }

  /// What all instalments add up to, and whether that is known or only
  /// estimated: estimated when the fee is unknown, unknown without the
  /// instalment.
  int? get total {
    final List<InstalmentRow> rows = schedule;
    if (rows.isEmpty) return null;
    return rows.fold<int>(0, (int s, InstalmentRow r) => s + r.payment);
  }

  /// The total is the bank's figures, with nothing left unknown.
  bool get totalKnown => total != null && fee != null;

  int get paid => payments.fold(0, (int s, (DateTime, int) p) => s + p.$2);

  /// How many instalments the payments cover whole, and what the last
  /// partial payment left owing on the next one.
  (int covered, int owing) get progress {
    final List<InstalmentRow> rows = schedule;
    if (rows.isEmpty) return (0, 0);
    var left = paid;
    var covered = 0;
    for (final InstalmentRow r in rows) {
      if (left >= r.payment) {
        left -= r.payment;
        covered++;
      } else {
        return (covered, left == 0 ? 0 : r.payment - left);
      }
    }
    return (covered, 0);
  }

  /// What is left to pay, from the schedule; null when unknown.
  int? get remaining {
    final int? t = total;
    if (t == null) return null;
    return math.max(0, t - paid);
  }

  /// The next instalment not yet covered, or null when all are.
  InstalmentRow? get next {
    final List<InstalmentRow> rows = schedule;
    final int covered = progress.$1;
    return covered < rows.length ? rows[covered] : null;
  }

  /// The same purchase, paid from [account] from now on, or from no
  /// account in Quincena when null.
  Instalments withAccount(String? account) => Instalments(
    id: id,
    name: name,
    principal: principal,
    count: count,
    firstDue: firstDue,
    rate: rate,
    rateKind: rateKind,
    instalment: instalment,
    fee: fee,
    cashPrice: cashPrice,
    accountId: account,
    payments: payments,
    paymentEntries: paymentEntries,
  );

  /// One more payment, with the movement it went out with when it did.
  Instalments withPayment(DateTime on, int amount, {String? entryId}) =>
      withPayments(
        <(DateTime, int)>[...payments, (on, amount)],
        entries: <String?>[
          for (var i = 0; i < payments.length; i++) entryOf(i),
          entryId,
        ],
      );

  /// Without the [index]th payment and its movement.
  Instalments withoutPayment(int index) => withPayments(
    <(DateTime, int)>[
      for (final (int i, (DateTime, int) p) in payments.indexed)
        if (i != index) p,
    ],
    entries: <String?>[
      for (var i = 0; i < payments.length; i++)
        if (i != index) entryOf(i),
    ],
  );

  /// The same purchase with [payments]; [entries] are their movements, in
  /// the same order, kept as they were when not given.
  Instalments withPayments(
    List<(DateTime, int)> payments, {
    List<String?>? entries,
  }) => Instalments(
    id: id,
    name: name,
    principal: principal,
    count: count,
    firstDue: firstDue,
    rate: rate,
    rateKind: rateKind,
    instalment: instalment,
    fee: fee,
    cashPrice: cashPrice,
    accountId: accountId,
    payments: payments,
    paymentEntries: entries ?? paymentEntries,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'principal': principal,
    'count': count,
    'firstDue': _iso(firstDue),
    if (rate != null) 'rate': rate,
    'rateKind': rateKind.name,
    if (instalment != null) 'instalment': instalment,
    if (fee != null) 'fee': fee,
    if (cashPrice != null) 'cashPrice': cashPrice,
    if (accountId != null) 'accountId': accountId,
    'payments': <Object?>[
      for (final (int i, (DateTime on, int amount)) in payments.indexed)
        <String, Object?>{
          'on': _iso(on),
          'amount': amount,
          if (entryOf(i) case final String entry) 'entryId': entry,
        },
    ],
  };

  static Instalments? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? principal = json['principal'];
    final Object? count = json['count'];
    final DateTime? first = DateTime.tryParse('${json['firstDue']}');
    if (principal is! num || count is! num || first == null || count < 1) {
      return null;
    }
    // Each payment, and the movement it went out with when it says.
    final List<(DateTime, int)> payments = <(DateTime, int)>[];
    final List<String?> entries = <String?>[];
    for (final Object? p
        in json['payments'] as List<Object?>? ?? const <Object?>[]) {
      if (p is! Map || p['amount'] is! num) continue;
      final DateTime? on = DateTime.tryParse('${p['on']}');
      if (on == null) continue;
      payments.add((on, (p['amount']! as num).round()));
      entries.add(p['entryId'] as String?);
    }
    return Instalments(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      principal: principal.round(),
      count: count.round(),
      firstDue: first,
      rate: (json['rate'] as num?)?.toDouble(),
      rateKind:
          RateKind.values
              .where((RateKind k) => k.name == json['rateKind'])
              .firstOrNull ??
          RateKind.effectiveAnnual,
      instalment: (json['instalment'] as num?)?.round(),
      fee: (json['fee'] as num?)?.round(),
      cashPrice: (json['cashPrice'] as num?)?.round(),
      accountId: json['accountId'] as String?,
      payments: payments,
      paymentEntries: entries,
    );
  }
}

// The charge detective ------------------------------------------------------

/// What made a charge stand out.
enum AlertKind {
  /// Two charges alike in amount, merchant and account, a day apart.
  twice,

  /// A merchant charging more than it used to.
  priceUp,

  /// Far more than the category usually takes.
  unusual,
}

/// Something worth a look, with the movements that make it.
@immutable
class ChargeAlert {
  const ChargeAlert({
    required this.id,
    required this.kind,
    required this.evidence,
    this.before,
    this.times,
    this.seenTwice = false,
  });

  /// Stable while the movements stay: the person's answer sticks to it.
  final String id;
  final AlertKind kind;
  final List<Entry> evidence;

  /// For [AlertKind.priceUp], what it charged before, in the evidence's
  /// currency.
  final Decimal? before;

  /// For [AlertKind.unusual], how many times the category's usual.
  final double? times;

  /// For [AlertKind.twice], the two came from different sources, which
  /// more often means one payment seen twice than two charges.
  final bool seenTwice;
}

/// Looks through the last [days] days of expenses for what is worth a
/// look. It never deletes a movement or calls anything fraud.
List<ChargeAlert> detectCharges(
  List<Entry> entries, {
  required DateTime today,
  int days = 60,
}) {
  final DateTime since = _day(today).subtract(Duration(days: days));
  final List<Entry> spent = <Entry>[
    for (final Entry e in entries)
      if (e.kind == EntryKind.expense &&
          !e.isTrade &&
          e.amount < Decimal.zero &&
          !e.date.isAfter(today))
        e,
  ]..sort((Entry a, Entry b) => a.date.compareTo(b.date));
  final List<ChargeAlert> out = <ChargeAlert>[];

  // Twice: same account, same amount, the same merchant (or none), a day
  // apart at most.
  final List<Entry> recent = <Entry>[
    for (final Entry e in spent)
      if (!_day(e.date).isBefore(since)) e,
  ];
  for (var i = 0; i < recent.length; i++) {
    for (var j = i + 1; j < recent.length; j++) {
      final Entry a = recent[i];
      final Entry b = recent[j];
      if (b.date.difference(a.date).inHours > 36) break;
      if (a.accountId != b.accountId || a.amount != b.amount) continue;
      if (merchantKey(a.payee) != merchantKey(b.payee)) continue;
      out.add(
        ChargeAlert(
          id: 'twice:${a.id}:${b.id}',
          kind: AlertKind.twice,
          evidence: <Entry>[a, b],
          seenTwice: _source(a) != _source(b),
        ),
      );
    }
  }

  // Price up: a merchant that charged the same on two days or more in half
  // a year, and whose last charge, on a later day, is at least 5 % over
  // it. Charges of the last one's day do not count before it, and charges
  // that differ say nothing of a price: a shop's every purchase is
  // different, and one bigger purchase is no rise.
  final DateTime half = _day(today).subtract(const Duration(days: 183));
  final Map<String, List<Entry>> byMerchant = <String, List<Entry>>{};
  for (final Entry e in spent) {
    final String key = merchantKey(e.payee);
    if (key.isEmpty || _day(e.date).isBefore(half)) continue;
    byMerchant.putIfAbsent('${e.accountId}|$key', () => <Entry>[]).add(e);
  }
  for (final List<Entry> group in byMerchant.values) {
    final Entry last = group.last;
    if (_day(last.date).isBefore(since)) continue;
    final List<Entry> earlier = <Entry>[
      for (final Entry e in group)
        if (_day(e.date).isBefore(_day(last.date))) e,
    ];
    final Set<DateTime> days = <DateTime>{
      for (final Entry e in earlier) _day(e.date),
    };
    if (days.length < 2) continue;
    final List<Decimal> prices = <Decimal>[
      for (final Entry e in earlier) -e.amount,
    ];
    final Decimal usual = _median(prices);
    final bool steady = prices.every(
      (Decimal p) =>
          (p - usual).abs() * Decimal.fromInt(100) <=
          usual * Decimal.fromInt(5),
    );
    final Decimal now = -last.amount;
    if (steady &&
        usual > Decimal.zero &&
        now * Decimal.fromInt(100) >= usual * Decimal.fromInt(105)) {
      out.add(
        ChargeAlert(
          id: 'priceUp:${last.id}',
          kind: AlertKind.priceUp,
          evidence: group,
          before: usual,
        ),
      );
    }
  }

  // Unusual: in the last 30 days, three times or more what the category
  // usually takes in that account, with five charges before to judge by.
  final DateTime month = _day(today).subtract(const Duration(days: 30));
  for (final Entry e in spent) {
    if (_day(e.date).isBefore(month)) continue;
    final List<Decimal> before = <Decimal>[
      for (final Entry x in spent)
        if (x.accountId == e.accountId &&
            ledgerCategory(x.category) == ledgerCategory(e.category) &&
            x.date.isBefore(e.date) &&
            !_day(
              x.date,
            ).isBefore(_day(e.date).subtract(const Duration(days: 120))))
          -x.amount,
    ];
    if (before.length < 5) continue;
    final Decimal usual = _median(before);
    if (usual <= Decimal.zero) continue;
    final double times = (-e.amount).toDouble() / usual.toDouble();
    if (times >= 3) {
      out.add(
        ChargeAlert(
          id: 'unusual:${e.id}',
          kind: AlertKind.unusual,
          evidence: <Entry>[e],
          times: times,
        ),
      );
    }
  }
  return out;
}

/// Where a movement came from, broadly: by hand, a notification or text, a
/// statement, an exchange.
String _source(Entry e) => e.source.split(':').first;

/// What the person made of an alert.
enum AlertAnswer {
  /// It was meant: the alert goes away.
  expected,

  /// They will look into it: the alert stays, marked.
  review,

  /// Not worth a look: the alert goes away.
  dismissed,
}

/// The person's answers to the charge detective, the kinds of alert they
/// silenced, and the merchants they said are not a fixed payment.
@immutable
class DetectiveState {
  const DetectiveState({
    this.answers = const <String, AlertAnswer>{},
    this.muted = const <AlertKind>{},
    this.notRecurring = const <String>{},
  });

  final Map<String, AlertAnswer> answers;
  final Set<AlertKind> muted;

  /// By merchant key.
  final Set<String> notRecurring;

  /// The [alerts] still to show: none of a silenced kind, nor any the
  /// person said was expected or dismissed.
  List<ChargeAlert> shown(List<ChargeAlert> alerts) => <ChargeAlert>[
    for (final ChargeAlert a in alerts)
      if (!muted.contains(a.kind) &&
          (answers[a.id] == null || answers[a.id] == AlertAnswer.review))
        a,
  ];

  /// With [answer] to the alert [id], or without one when null. Answers to
  /// alerts no longer in [current] are let go.
  DetectiveState withAnswer(
    String id,
    AlertAnswer? answer, {
    Iterable<String>? current,
  }) {
    final Set<String>? keep = current?.toSet();
    return DetectiveState(
      answers: <String, AlertAnswer>{
        for (final MapEntry<String, AlertAnswer> e in answers.entries)
          if (e.key != id && (keep == null || keep.contains(e.key)))
            e.key: e.value,
        id: ?answer,
      },
      muted: muted,
      notRecurring: notRecurring,
    );
  }

  DetectiveState withMuted(AlertKind kind, {required bool muted}) =>
      DetectiveState(
        answers: answers,
        muted: <AlertKind>{
          for (final AlertKind k in this.muted)
            if (k != kind) k,
          if (muted) kind,
        },
        notRecurring: notRecurring,
      );

  DetectiveState withNotRecurring(String name) => DetectiveState(
    answers: answers,
    muted: muted,
    notRecurring: <String>{...notRecurring, merchantKey(name)},
  );

  /// Without the merchant [key] among those that are not fixed payments.
  DetectiveState withoutNotRecurring(String key) => DetectiveState(
    answers: answers,
    muted: muted,
    notRecurring: <String>{
      for (final String k in notRecurring)
        if (k != key) k,
    },
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'answers': <String, String>{
      for (final MapEntry<String, AlertAnswer> e in answers.entries)
        e.key: e.value.name,
    },
    'muted': <String>[for (final AlertKind k in muted) k.name],
    'notRecurring': notRecurring.toList()..sort(),
  };

  static DetectiveState fromJson(Object? json) {
    if (json is! Map) return const DetectiveState();
    T? named<T extends Enum>(List<T> values, Object? name) =>
        values.where((T v) => v.name == name).firstOrNull;
    return DetectiveState(
      answers: <String, AlertAnswer>{
        if (json['answers'] case final Map<Object?, Object?> answers)
          for (final MapEntry<Object?, Object?> e in answers.entries)
            if (named(AlertAnswer.values, e.value) case final AlertAnswer a)
              '${e.key}': a,
      },
      muted: <AlertKind>{
        if (json['muted'] case final List<Object?> muted)
          for (final Object? k in muted) ?named(AlertKind.values, k),
      },
      notRecurring: <String>{
        if (json['notRecurring'] case final List<Object?> keys)
          for (final Object? k in keys)
            if (k is String && k.isNotEmpty) k,
      },
    );
  }
}

/// The instalments of [plans] still to pay after [today] and up to
/// [until], as charges to come.
///
/// One whose debt sits in an account the ledger already counts, a card in
/// Quincena, is left out: the purchase was counted on the card the day it
/// was made, and paying the card moves money between accounts. Counting
/// its instalments too would take the same money twice.
List<Movement> instalmentsDue(
  List<Instalments> plans, {
  required DateTime today,
  required DateTime until,
  required bool Function(String accountId) counted,
}) {
  final DateTime day = _day(today);
  final List<Movement> out = <Movement>[];
  for (final Instalments p in plans) {
    if (p.accountId case final String account when counted(account)) {
      continue;
    }
    final List<InstalmentRow> rows = p.schedule;
    final (int covered, int owing) = p.progress;
    for (var i = covered; i < rows.length; i++) {
      final InstalmentRow row = rows[i];
      final DateTime due = _day(row.due);
      if (!due.isAfter(day)) continue;
      if (due.isAfter(until)) break;
      out.add(
        Movement(
          id: 'instalment:${p.id}#${row.number}',
          date: row.due,
          merchant: p.name,
          // What a partial payment left on the first one still owed.
          amount: i == covered && owing > 0 ? owing : row.payment,
          category: Category.debt,
        ),
      );
    }
  }
  return out;
}

Decimal _median(List<Decimal> values) {
  if (values.isEmpty) return Decimal.zero;
  final List<Decimal> sorted = <Decimal>[...values]..sort();
  return sorted[sorted.length ~/ 2];
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
