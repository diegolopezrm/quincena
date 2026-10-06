import 'package:decimal/decimal.dart';

import '../data/ledger.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
import '../store/store.dart';
import 'categories.dart';
import 'commitments.dart';
import 'records.dart';
import 'shared.dart';

/// The ledger the screens and the agent read, built from the person's own
/// accounts.
///
/// Only spendable accounts make up the money "until payday": a transfer into
/// savings or an exchange leaves it, and one back from there returns to it,
/// without counting as spending or income. Every amount is converted to the
/// base currency with the latest rates; one that cannot be converted is left
/// out, and [LedgerBuild.unconverted] says which assets those were.
///
/// [setAside] is what this period's envelopes keep apart, in the base
/// currency's smallest unit. The [instalments] still to pay join the
/// charges to come, unless their debt is already in a card counted here.
///
/// [shared] says what of each movement others owe, or paid back: of an
/// expense paid for others, only the person's part is spending and the
/// rest is money lent; a repayment is money back, not income. [expected]
/// are payments from clients still to come, and [reserved] what the person
/// keeps apart of those that came.
LedgerBuild buildLedger(
  StoreSnapshot s, {
  required DateTime today,
  int setAside = 0,
  List<Instalments> instalments = const <Instalments>[],
  SharedLinks shared = const SharedLinks(),
  List<Movement> expected = const <Movement>[],
  int reserved = 0,
}) {
  final Asset base = s.profile.base;
  final RateTable rates = RateTable(s.rates);
  final Set<Asset> unconverted = <Asset>{};
  final Decimal unit = Decimal.ten.pow(base.decimals).toDecimal();

  int inBase(Money money) {
    final Money? converted = rates.convert(money, base);
    if (converted == null) {
      unconverted.add(money.asset);
      return 0;
    }
    return (converted.amount * unit).round().toBigInt().toInt();
  }

  final Map<String, Account> accounts = <String, Account>{
    for (final Account a in s.accounts) a.id: a,
  };
  bool spendable(String? id) {
    final Account? a = accounts[id];
    return a != null && a.spendable && !a.archived;
  }

  final Map<String, String> otherLeg = <String, String>{};
  final Map<String, List<Entry>> byTransfer = <String, List<Entry>>{};
  for (final Entry e in s.entries) {
    if (e.transferId != null) {
      byTransfer.putIfAbsent(e.transferId!, () => <Entry>[]).add(e);
    }
  }
  for (final List<Entry> legs in byTransfer.values) {
    if (legs.length != 2) continue;
    otherLeg[legs[0].id] = legs[1].accountId;
    otherLeg[legs[1].id] = legs[0].accountId;
  }

  String label(Entry e) {
    if (e.payee.isNotEmpty) return e.payee;
    if (e.note.isNotEmpty) return e.note;
    return e.category == null ? '' : categoryLabel(e.category!, 'es');
  }

  final List<Movement> movements = <Movement>[];
  final Map<String, String> accountOf = <String, String>{};
  for (final Entry e in s.entries) {
    if (!spendable(e.accountId)) continue;
    final bool out = e.amount < Decimal.zero;
    final Flow flow;
    if (e.isTrade) {
      // Buying or selling what the account holds is neither spending nor
      // income: money changed form.
      flow = out ? Flow.saving : Flow.transferIn;
    } else {
      switch (e.kind) {
        case EntryKind.expense:
          flow = Flow.expense;
        case EntryKind.income:
          flow = Flow.income;
        case EntryKind.transfer:
          // Between two spendable accounts nothing left the money to spend.
          if (spendable(otherLeg[e.id])) continue;
          flow = out ? Flow.saving : Flow.transferIn;
        case EntryKind.adjustment:
          flow = out ? Flow.saving : Flow.transferIn;
      }
    }
    final int amount = inBase(
      Money(e.amount.abs(), accounts[e.accountId]!.asset),
    );
    // What of it others owe, or paid back, goes apart.
    final (int apart, Flow apartFlow) = switch (flow) {
      Flow.expense => (shared.lent[e.id] ?? 0, Flow.saving),
      Flow.income => (shared.repaid[e.id] ?? 0, Flow.transferIn),
      _ => (0, flow),
    };
    final int other = apart.clamp(0, amount);
    if (amount - other > 0 || other == 0) {
      movements.add(
        Movement(
          id: e.id,
          date: e.date,
          merchant: label(e),
          amount: amount - other,
          category: ledgerCategory(e.category),
          flow: flow,
        ),
      );
      accountOf[e.id] = e.accountId;
    }
    if (other > 0) {
      final String id = '${e.id}#shared';
      movements.add(
        Movement(
          id: id,
          date: e.date,
          merchant: label(e),
          amount: other,
          category: ledgerCategory(e.category),
          flow: apartFlow,
        ),
      );
      accountOf[id] = e.accountId;
    }
  }

  // Two months of charges ahead: those by payday are committed, the rest
  // are for projections.
  final DateTime horizon = today.add(const Duration(days: 62));
  // A charge whose account was deleted is still the person's to pay, from
  // some account: it counts, as one with no account does. Only an account
  // kept apart from spending, or archived, takes it out.
  bool charged(String? id) =>
      id == null || !accounts.containsKey(id) || spendable(id);
  final List<Movement> upcoming = <Movement>[
    for (final RecurringCharge r in s.recurring)
      if (r.active && charged(r.accountId))
        for (final DateTime d in r.datesUntil(horizon))
          if (d.isAfter(today))
            Movement(
              id: '${r.id}@${d.toIso8601String()}',
              date: d,
              merchant: r.name,
              amount: inBase(r.amount),
              category: ledgerCategory(r.category),
            ),
    ...instalmentsDue(
      instalments,
      today: today,
      until: horizon,
      // Only a card holds what was bought on it: from any other account
      // the instalments are still to come out of it.
      counted: (String id) =>
          spendable(id) && accounts[id]!.kind == AccountKind.card,
    ),
  ];

  final Map<String, int> openings = <String, int>{
    for (final Account a in s.accounts)
      if (spendable(a.id)) a.id: inBase(a.openingMoney),
  };
  // The first balance written down: a pay before it was already in it.
  DateTime? since;
  for (final Account a in s.accounts) {
    final DateTime? written = a.balanceSince;
    if (!spendable(a.id) || written == null) continue;
    if (since == null || written.isBefore(since)) since = written;
  }
  final Ledger ledger = Ledger(
    owner: s.profile.name,
    today: today,
    openingBalance: openings.values.fold(0, (int sum, int v) => sum + v),
    movements: movements,
    upcoming: upcoming,
    subscriptions: <Subscription>[
      for (final RecurringCharge r in s.recurring)
        if (r.active && r.category == 'subscriptions')
          Subscription(
            id: r.id,
            name: r.name,
            price: inBase(_monthly(r)),
            chargeDay: r.nextDate.day,
            next: nextCharge(r, today),
            since: r.since ?? today,
          ),
    ],
    goals: <Goal>[
      for (final SavingsGoal g in s.goals)
        Goal(
          id: g.id,
          name: g.name,
          target: inBase(g.target),
          saved: inBase(g.saved),
          monthly: inBase(g.monthly),
          deadline: g.deadline ?? DateTime(today.year, 12, 31),
        ),
    ],
    schedule: s.profile.schedule,
    currency: base,
    cushion: switch (s.profile.cushion) {
      final Decimal c when c > Decimal.zero => inBase(Money(c, base)),
      _ => 0,
    },
    setAside: setAside,
    reserved: reserved,
    expected: expected,
    pay: switch (s.profile.pay) {
      final Decimal p when p > Decimal.zero => inBase(Money(p, base)),
      _ => null,
    },
    since: since,
  );
  // What each spendable account adds to the balance, worked out with the
  // ledger's own arithmetic, so the parts always add up to the whole.
  final Map<String, int> parts = Map<String, int>.of(openings);
  for (final Movement m in ledger.movements) {
    final String? account = accountOf[m.id];
    if (account == null || !ledger.settled(m)) continue;
    parts[account] = (parts[account] ?? 0) + Ledger.effect(m);
  }
  // A transfer between two of them, as paying a card from the bank, takes
  // nothing from the money to spend but moves it from one part to the
  // other: what left the one is what the other gets, so they still add up.
  for (final List<Entry> legs in byTransfer.values) {
    if (legs.length != 2 || legs.any((Entry e) => e.isTrade)) continue;
    final Entry from = legs[0].amount < Decimal.zero ? legs[0] : legs[1];
    final Entry to = identical(from, legs[0]) ? legs[1] : legs[0];
    if (!spendable(from.accountId) || !spendable(to.accountId)) continue;
    final DateTime day = DateTime(
      from.date.year,
      from.date.month,
      from.date.day,
    );
    if (day.isAfter(today)) continue;
    final int moved = inBase(
      Money(from.amount.abs(), accounts[from.accountId]!.asset),
    );
    parts[from.accountId] = (parts[from.accountId] ?? 0) - moved;
    parts[to.accountId] = (parts[to.accountId] ?? 0) + moved;
  }
  return LedgerBuild(ledger, unconverted, parts);
}

/// What [r] costs in a month, whatever its cadence.
Money _monthly(RecurringCharge r) => switch (r.cadence) {
  Cadence.monthly => r.amount,
  Cadence.yearly => Money(
    (r.amount.amount / Decimal.fromInt(12)).toDecimal(
      scaleOnInfinitePrecision: 8,
    ),
    r.amount.asset,
  ),
  Cadence.biweekly => Money(
    r.amount.amount * Decimal.parse('2.1667'),
    r.amount.asset,
  ),
  Cadence.weekly => Money(
    r.amount.amount * Decimal.parse('4.3333'),
    r.amount.asset,
  ),
};

/// A built ledger, and the assets it could not convert to the base currency.
class LedgerBuild {
  const LedgerBuild(this.ledger, this.unconverted, [this.parts = const {}]);

  final Ledger ledger;

  /// What each spendable account, by id, adds to [Ledger.balance], in the
  /// ledger's smallest unit. They add up to it exactly.
  final Map<String, int> parts;

  /// Held in some account but missing a rate: their amounts count as zero
  /// until one is fetched or typed.
  final Set<Asset> unconverted;
}
