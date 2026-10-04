import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:decimal/decimal.dart';

import '../agent/tools.dart';
import '../data/ledger.dart';
import '../domain/freelance.dart';
import '../domain/records.dart';
import '../domain/shared.dart';
import '../domain/trips.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
import '../portfolio/cost_basis.dart';
import '../portfolio/portfolio.dart';
import 'own_controller.dart';

/// What a model can ask about the person's own accounts: everything it can
/// ask the sample account, read from the database as it is now, an expense
/// saved for real, and every account in its own currency.
List<Tool> ownTools(OwnController own) => <Tool>[
  ...accountTools(() => own.ledger!, record: own.recordExpense),
  Tool<Map<String, dynamic>>(
    name: 'accounts',
    description:
        'Every account the person has, each in its own currency: banks in '
        'pesos or dollars, cards, cash, digital wallets and crypto on an '
        'exchange. For each, its balance written as it is in its currency '
        '(balanceText, to show as it comes), the same in the base currency '
        'when a rate is known (balanceInBase), and whether it is money to '
        'spend before payday. Then the totals in the base currency and the '
        'rates behind them. Call it for anything about dollars, crypto, one '
        'account, or everything the person has.',
    onCall: (_) => accountsAnswer(own),
  ),
  Tool<Map<String, dynamic>>(
    name: 'portfolio',
    description:
        'The person\'s crypto, priced with Binance\'s market prices of the '
        'moment. Each holding with where it is kept, how much is held '
        '(quantityText, to show as it comes), its price, what it is worth in '
        'the base currency and in dollars, how its price moved in the last '
        '24 hours, what it cost and the unrealized gain or loss against that '
        'cost, which leaves out what came in with no purchase price. The '
        'cost follows the money that went in, Binance fees included: bitcoin '
        'bought with tether bought with pesos cost those pesos. A null '
        'figure is unknown, never zero. Then the totals, how the value '
        'splits between coins, what sales and conversions already gained, '
        'and when the prices were read. Call it for anything about crypto, '
        'an exchange, prices, or gains and losses on investments.',
    onCall: (_) async {
      await own.portfolio.refreshIfOlder(const Duration(minutes: 1));
      return portfolioAnswer(own);
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'owed_and_variable',
    description:
        'What others owe the person and what they owe, from the expenses '
        'they share, by group and person, with the payments that would '
        'settle each group; the payments clients owe them, billed or only '
        'estimated, with the day each is expected and whether it is late; '
        'the reserve they keep from those payments and what counts ahead; '
        'and their trips, each with its budget, what was spent and what is '
        'left in the trip\'s currency. What others owe is not money to spend '
        'until it arrives. No tax is worked out here.',
    onCall: (_) => owedAndVariableAnswer(own),
  ),
];

/// The `owed_and_variable` tool's answer, apart so a test can read it.
Map<String, Object?> owedAndVariableAnswer(OwnController own) {
  final Ledger? ledger = own.ledger;
  if (ledger == null) return <String, Object?>{'available': false};
  num major(int minor) => ledger.major(minor);
  final DateTime today = own.today;
  String day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final (int owed, int owing) = own.sharedBalance;
  final FreelancePlan freelance = own.freelance;
  return <String, Object?>{
    'currency': ledger.currency.code,
    'today': day(today),
    'owedToYou': major(owed),
    'youOwe': major(owing),
    'groups': <Object?>[
      for (final Group g in own.groups)
        <String, Object?>{
          'name': g.name,
          'members': <String>[
            for (final Member m in g.members) m.isMe ? 'you' : m.name,
          ],
          'yourBalance': major(g.balances[meId] ?? 0),
          'toSettle': <Object?>[
            for (final Transfer t in g.plan)
              <String, Object?>{
                'from': g.member(t.from)?.isMe ?? false
                    ? 'you'
                    : g.member(t.from)?.name,
                'to': g.member(t.to)?.isMe ?? false
                    ? 'you'
                    : g.member(t.to)?.name,
                'amount': major(t.amount),
              },
          ],
        },
    ],
    'clientPayments': <Object?>[
      for (final ExpectedIncome i in freelance.incomes)
        if (i.status != IncomeStatus.collected)
          <String, Object?>{
            'client': i.client,
            'amount': major(i.amount),
            'status': i.status.name,
            'expected': day(i.expected),
            if (i.overdue(today)) 'daysLate': i.daysLate(today),
          },
    ],
    'countsAhead': freelance.scenario.name,
    if (freelance.reservePercent > 0) ...<String, Object?>{
      'reservePercent': freelance.reservePercent,
      'reserve': major(ledger.reserved),
    },
    'trips': <Object?>[
      for (final Trip t in own.trips)
        <String, Object?>{
          'name': t.name,
          'from': day(t.from),
          'to': day(t.to),
          'currency': t.currency,
          if (t.budget case final Decimal b) 'budget': b.toDouble(),
          'spent': own.tripSummary(t).spent.toDouble(),
          if (own.tripSummary(t).left case final Decimal left)
            'left': left.toDouble(),
          'daysLeft': t.daysLeft(today),
        },
    ],
  };
}

/// The `portfolio` tool's answer, apart so a test can read it.
Map<String, Object?> portfolioAnswer(OwnController own) {
  final Portfolio? p = own.portfolio.portfolio;
  if (p == null || p.isEmpty) {
    return <String, Object?>{
      'holdings': <Object?>[],
      'note': 'No crypto held.',
    };
  }
  final Asset base = p.base;
  num inBase(Decimal amount) => base.decimals == 0
      ? amount.round().toBigInt().toInt()
      : double.parse(amount.toStringAsFixed(base.decimals));
  num dollars(Decimal amount) => double.parse(amount.toStringAsFixed(2));
  num? percent(double? fraction) => fraction == null
      ? null
      : double.parse((fraction * 100).toStringAsFixed(2));
  final Decimal total = p.value.base;
  // The same 24 hours the screen shows.
  final ({Pair moved, double change})? day = own.portfolio.day;
  return <String, Object?>{
    'baseCurrency': base.code,
    'pricesFrom': 'Binance',
    'pricedAt': p.pricedAt?.toIso8601String().split('.').first,
    'totalValueInBase': inBase(total),
    'totalValueInUsd': dollars(p.value.usd),
    'totalCostInBase': inBase(p.cost.base),
    'gainInBase': p.gain == null ? null : inBase(p.gain!.base),
    'gainPercent': percent(p.gainRatio),
    if (p.uncostedValue.base > Decimal.zero)
      'valueWithoutCostInBase': inBase(p.uncostedValue.base),
    'change24hInBase': day == null ? null : inBase(day.moved.base),
    'change24hPercent': percent(day?.change),
    'realizedInBase': inBase(p.realized.base),
    'holdings': <Object?>[
      for (final Holding h in p.holdings)
        <String, Object?>{
          'asset': h.asset.code,
          'account': h.account.name,
          if (h.account.institution.isNotEmpty) 'place': h.account.institution,
          'quantityText': formatAmount(
            h.position.quantity,
            h.asset,
            base: base,
          ),
          'priceInBase': h.price == null ? null : inBase(h.price!.base),
          'priceInUsd': h.price == null ? null : dollars(h.price!.usd),
          'valueInBase': h.value == null ? null : inBase(h.value!.base),
          'valueInUsd': h.value == null ? null : dollars(h.value!.usd),
          'change24hPercent': percent(h.change24h),
          'costInBase': inBase(h.position.cost.base),
          'averageCostInBase': h.position.averageCost == null
              ? null
              : inBase(h.position.averageCost!.base),
          'gainInBase': h.gain == null ? null : inBase(h.gain!.base),
          'gainPercent': percent(h.gainRatio),
          if (h.position.uncosted > Decimal.zero)
            'heldWithoutCostText': formatAmount(
              h.position.uncosted,
              h.asset,
              base: base,
            ),
        },
    ],
    'allocation': <Object?>[
      for (final (Asset a, Pair v) in p.allocation)
        <String, Object?>{
          'asset': a.code,
          'percent': total == Decimal.zero
              ? 0
              : percent(
                  (v.base / total)
                      .toDecimal(scaleOnInfinitePrecision: 8)
                      .toDouble(),
                ),
        },
    ],
    'withoutPrice': <String>[for (final Asset a in p.unpriced) a.code],
  };
}

/// The `accounts` tool's answer, apart so a test can read it.
Map<String, Object?> accountsAnswer(OwnController own) {
  final Asset base = own.profile?.base ?? Asset.cop;
  final RateTable rates = own.rates;
  num inBase(Decimal amount) => base.decimals == 0
      ? amount.round().toBigInt().toInt()
      : double.parse(amount.toStringAsFixed(base.decimals));
  final Set<Rate> used = <Rate>{};
  return <String, Object?>{
    'baseCurrency': base.code,
    'accounts': <Object?>[
      for (final Account a in own.accounts)
        () {
          final Money balance = own.balances[a.id] ?? a.openingMoney;
          final Money? converted = own.inBase(balance);
          used.addAll(rates.used(a.asset, base));
          return <String, Object?>{
            'name': a.name,
            'kind': a.kind.name,
            if (a.institution.isNotEmpty) 'institution': a.institution,
            'currency': a.asset.code,
            'balanceText': formatAmount(balance.amount, a.asset, base: base),
            'balanceInBase': converted == null
                ? null
                : inBase(converted.amount),
            'spendable': a.spendable,
          };
        }(),
    ],
    'totalInBase': inBase(own.total().amount),
    'spendableInBase': inBase(own.total(spendableOnly: true).amount),
    'withoutRate': <String>[for (final Asset a in own.unconverted) a.code],
    'rates': <Object?>[
      for (final Rate r in used)
        <String, Object?>{
          'from': r.asset,
          'to': r.quote,
          'value': r.value.toString(),
          'asOf': r.asOf.toIso8601String().split('T').first,
        },
    ],
  };
}
