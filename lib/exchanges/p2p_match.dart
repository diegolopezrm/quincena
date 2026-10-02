import 'package:decimal/decimal.dart';

import '../domain/records.dart';
import '../money/money.dart';
import '../store/store.dart';

/// How far apart a P2P order and the bank's payment for it can be. An
/// order completes within minutes; a statement can date it the next day.
const Duration p2pWindow = Duration(days: 1);

/// Joins each Binance P2P order with the bank movement that paid for it,
/// or received its money, into one transfer.
///
/// Buying tether on P2P leaves two traces: the order in Binance, with what
/// it cost in pesos, and a payment to the seller in the bank, caught from a
/// notification or a statement. Apart, the payment counts as spending and
/// the order as a purchase from outside. Joined, the pesos moved from the
/// bank to Binance, and the tether cost exactly what left the bank.
///
/// A pair is joined only when it is the only one: the same amount, in the
/// bank's currency, in a spendable account, within [p2pWindow]. Returns how
/// many pairs were joined.
Future<int> linkP2pPayments(QuincenaStore store) async {
  final List<Account> accounts = await store.accounts(archived: true);
  final Map<String, Account> byId = <String, Account>{
    for (final Account a in accounts) a.id: a,
  };
  final List<Entry> entries = await store.entries();
  final List<Entry> orders = <Entry>[
    for (final Entry e in entries)
      if (e.transferId == null &&
          e.cost != null &&
          (e.sourceRef?.startsWith('binance:p2p:') ?? false))
        e,
  ];
  if (orders.isEmpty) return 0;

  final Set<String> taken = <String>{};
  var joined = 0;
  for (final Entry order in orders) {
    final Money cost = order.cost!;
    final bool buy = order.amount > Decimal.zero;
    // A purchase was paid from the bank; a sale's money arrived there.
    final Decimal wanted = buy ? -cost.amount.abs() : cost.amount.abs();
    final List<Entry> candidates = <Entry>[
      for (final Entry e in entries)
        if (e.transferId == null &&
            e.cost == null &&
            !taken.contains(e.id) &&
            e.amount == wanted &&
            byId[e.accountId]?.asset == cost.asset &&
            (byId[e.accountId]?.spendable ?? false) &&
            e.date.difference(order.date).abs() <= p2pWindow)
          e,
    ];
    if (candidates.length != 1) continue;
    final Entry bank = candidates.single;
    taken.add(bank.id);
    await store.linkAsTransfer(
      out: buy ? bank : order,
      into: buy ? order : bank,
    );
    joined++;
  }
  return joined;
}
