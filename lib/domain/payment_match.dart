import 'package:flutter/foundation.dart' show immutable;

import '../capture/merchants.dart';
import 'freelance.dart';
import 'shared.dart';

/// What money that came in settles, as far as the person's own records
/// tell: a client's payment they were waiting for, or what someone in a
/// group owed them.
@immutable
class PaymentMatch {
  const PaymentMatch.client(ExpectedIncome this.income)
    : group = null,
      member = null,
      owed = 0;

  const PaymentMatch.friend(Group this.group, Member this.member, this.owed)
    : income = null;

  /// The client's payment it is, with what was expected.
  final ExpectedIncome? income;

  /// The group where [member] owes the person, and [owed], what they owe
  /// there, in the ledger's unit.
  final Group? group;
  final Member? member;
  final int owed;
}

/// What a payment of [amount], in the ledger's unit, sent by [from]
/// settles: a client's payment not yet collected from someone of that name,
/// for about that much, as clients withhold part of it; or else what a
/// person of that name owes the person in a group, up to all of it. Null
/// when nothing the person wrote down is it.
PaymentMatch? matchPayment({
  required String from,
  required int amount,
  required FreelancePlan freelance,
  required Iterable<Group> groups,
}) {
  if (from.trim().isEmpty || amount <= 0) return null;
  final List<ExpectedIncome> clients =
      <ExpectedIncome>[
        for (final ExpectedIncome i in freelance.incomes)
          if (i.status != IncomeStatus.collected &&
              namesMatch(i.client, from) &&
              amount <= i.amount * 1.05 &&
              amount >= i.amount * 0.8)
            i,
      ]..sort(
        (ExpectedIncome a, ExpectedIncome b) =>
            (a.amount - amount).abs().compareTo((b.amount - amount).abs()),
      );
  if (clients.isNotEmpty) return PaymentMatch.client(clients.first);
  PaymentMatch? best;
  for (final Group g in groups) {
    for (final Transfer t in g.plan) {
      if (t.to != meId) continue;
      final Member? m = g.member(t.from);
      if (m == null || !namesMatch(m.name, from)) continue;
      if (amount > t.amount * 1.05) continue;
      if (best == null || t.amount > best.owed) {
        best = PaymentMatch.friend(g, m, t.amount);
      }
    }
  }
  return best;
}

/// Whether [expected], a name the person wrote, is [sender], as a bank
/// writes it: every word of it is one of the sender's. «Agencia Uno» is
/// «AGENCIA UNO SAS» and «Laura» is «Laura Gómez», but «Estudio Norte» is
/// not «Estudio Sur».
bool namesMatch(String expected, String sender) {
  final List<String> mine = normalize(
    expected,
  ).split(' ').where((String w) => w.isNotEmpty).toList();
  final Set<String> theirs = normalize(sender).split(' ').toSet();
  return mine.isNotEmpty && mine.every(theirs.contains);
}
