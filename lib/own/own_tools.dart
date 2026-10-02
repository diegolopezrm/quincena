import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:decimal/decimal.dart';

import '../agent/tools.dart';
import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
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
];

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
