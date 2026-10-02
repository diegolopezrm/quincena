import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/portfolio/cost_basis.dart';

Decimal d(String s) => Decimal.parse(s);

final Account bank = Account(
  id: 'bank',
  name: 'Bancolombia',
  kind: AccountKind.bank,
  asset: Asset.cop,
  opening: Decimal.zero,
);

Account crypto(String id, Asset asset, {String opening = '0', Money? cost}) =>
    Account(
      id: id,
      name: asset.code,
      kind: AccountKind.exchange,
      asset: asset,
      opening: d(opening),
      institution: 'Binance',
      spendable: false,
      openingCost: cost,
    );

int _n = 0;

Entry entry(
  String account,
  String amount,
  DateTime date, {
  EntryKind kind = EntryKind.income,
  Money? cost,
  String? transfer,
}) => Entry(
  id: 'e${_n++}',
  accountId: account,
  amount: d(amount),
  date: date,
  kind: transfer == null ? kind : EntryKind.transfer,
  transferId: transfer,
  cost: cost,
);

/// The two legs of a move, newest first as the store gives them.
List<Entry> transfer(
  String from,
  String sent,
  String to,
  String received,
  DateTime date,
) {
  final String id = 't${_n++}';
  return <Entry>[
    entry(to, received, date, transfer: id),
    entry(from, '-$sent', date, transfer: id),
  ];
}

/// The TRM: 4.000 pesos a dollar until June 2026, 3.800 after.
Decimal? trm(DateTime day) =>
    day.isBefore(DateTime(2026, 6)) ? d('4000') : d('3800');

final RateTable today = RateTable(<Rate>[
  Rate(
    asset: 'USD',
    quote: 'COP',
    value: d('3800'),
    asOf: DateTime(2026, 10, 2),
    source: 'trm',
  ),
]);

Position only(List<Position> all, String id) =>
    all.singleWhere((Position p) => p.account.id == id);

void main() {
  final DateTime march = DateTime(2026, 3, 10);
  final DateTime july = DateTime(2026, 7, 15);
  final DateTime august = DateTime(2026, 8, 20);

  List<Position> run(List<Account> accounts, List<Entry> entries) => positions(
    accounts: accounts,
    entries: entries,
    base: Asset.cop,
    today: today,
    dollarOn: trm,
  );

  test('an account that is not crypto is not an investment', () {
    expect(run(<Account>[bank], const <Entry>[]), isEmpty);
  });

  test('what an account started with costs what the person said', () {
    final Account btc = crypto(
      'btc',
      Asset.btc,
      opening: '0.02',
      cost: Money(d('8000000'), Asset.cop),
    );
    final Position p = only(
      run(<Account>[btc], <Entry>[entry('btc', '0', march)]),
      'btc',
    );
    expect(p.quantity, d('0.02'));
    expect(p.cost.base, d('8000000'));
    // 8.000.000 pesos at 4.000 a dollar, the TRM of the first movement.
    expect(p.cost.usd, d('2000'));
    expect(p.averageCost!.base, d('400000000'));
    // The day of an opening balance is a guess.
    expect(p.approximate, isTrue);
  });

  test('bitcoin bought with tether costs the pesos the tether cost', () {
    final Account usdt = crypto('usdt', Asset.usdt);
    final Account btc = crypto('btc', Asset.btc);
    final List<Entry> entries = <Entry>[
      // Newest first: the conversion, then the P2P purchase.
      ...transfer('usdt', '500', 'btc', '0.005', july),
      entry('usdt', '1000', march, cost: Money(d('4100000'), Asset.cop)),
    ];
    final List<Position> all = run(<Account>[usdt, btc], entries);
    final Position tether = only(all, 'usdt');
    final Position bitcoin = only(all, 'btc');

    expect(tether.quantity, d('500'));
    expect(tether.cost.base, d('2050000'));
    expect(tether.cost.usd, d('512.5'));
    expect(bitcoin.quantity, d('0.005'));
    expect(bitcoin.cost.base, d('2050000'));
    expect(bitcoin.cost.usd, d('512.5'));
    expect(bitcoin.approximate, isFalse);
  });

  test('a purchase from the bank costs what left the bank', () {
    final Account btc = crypto('btc', Asset.btc);
    final List<Position> all = run(<Account>[
      bank,
      btc,
    ], transfer('bank', '3800000', 'btc', '0.01', july));
    final Position p = only(all, 'btc');
    expect(p.cost.base, d('3800000'));
    expect(p.cost.usd, d('1000'));
  });

  test('selling part takes its share of the cost, and the gain is kept', () {
    final Account btc = crypto('btc', Asset.btc);
    final List<Entry> entries = <Entry>[
      ...transfer('btc', '0.005', 'bank', '2500000', august),
      ...transfer('bank', '3800000', 'btc', '0.01', july),
    ];
    final Position p = only(run(<Account>[bank, btc], entries), 'btc');
    expect(p.quantity, d('0.005'));
    expect(p.cost.base, d('1900000'));
    expect(p.realized.base, d('600000'));
    expect(p.realized.usd.round(scale: 6), d('157.894737'));
  });

  test('a sale outside the accounts gains what it brought less its cost', () {
    final Account eth = crypto('eth', Asset.eth);
    final List<Entry> entries = <Entry>[
      entry(
        'eth',
        '-1',
        august,
        kind: EntryKind.expense,
        cost: Money(d('1200'), Asset.usdt),
      ),
      entry('eth', '2', march, cost: Money(d('2000'), Asset.usdt)),
    ];
    final Position p = only(run(<Account>[eth], entries), 'eth');
    expect(p.quantity, d('1'));
    expect(p.cost.usd, d('1000'));
    expect(p.realized.usd, d('200'));
    // 1.200 dollars at 3.800 against 1.000 dollars bought at 4.000.
    expect(p.realized.base, d('560000'));
  });

  test('rewards come in with no cost and are said apart', () {
    final Account sol = crypto('sol', Asset.sol);
    final List<Entry> entries = <Entry>[
      entry('sol', '0.5', august),
      entry('sol', '10', march, cost: Money(d('1000'), Asset.usdt)),
    ];
    final Position p = only(run(<Account>[sol], entries), 'sol');
    expect(p.quantity, d('10.5'));
    expect(p.uncosted, d('0.5'));
    expect(p.cost.usd, d('1000'));
  });

  test('a conversion carries the part with no cost along', () {
    final Account usdt = crypto('usdt', Asset.usdt);
    final Account btc = crypto('btc', Asset.btc);
    final List<Entry> entries = <Entry>[
      ...transfer('usdt', '200', 'btc', '0.002', august),
      // Half of the tether came from a deposit the app knows nothing of.
      entry('usdt', '100', july),
      entry('usdt', '100', march, cost: Money(d('400000'), Asset.cop)),
    ];
    final List<Position> all = run(<Account>[usdt, btc], entries);
    final Position p = only(all, 'btc');
    expect(p.quantity, d('0.002'));
    expect(p.cost.base, d('400000'));
    expect(p.uncosted, d('0.001'));
    expect(only(all, 'usdt').quantity, d('0'));
  });

  test('selling more than is recorded leaves nothing, not a negative cost', () {
    final Account btc = crypto('btc', Asset.btc);
    final List<Entry> entries = <Entry>[
      ...transfer('btc', '0.02', 'bank', '8000000', august),
      ...transfer('bank', '3800000', 'btc', '0.01', july),
    ];
    final Position p = only(run(<Account>[bank, btc], entries), 'btc');
    expect(p.quantity, d('-0.01'));
    expect(p.cost, Pair.zero);
    expect(p.averageCost, isNull);
    expect(p.realized.base, d('4200000'));
  });

  test('with dollars as the base, both currencies are the same', () {
    final Account btc = crypto('btc', Asset.btc);
    final List<Position> all = positions(
      accounts: <Account>[btc],
      entries: <Entry>[
        entry('btc', '0.01', july, cost: Money(d('950'), Asset.usdt)),
      ],
      base: Asset.usd,
      today: RateTable(const <Rate>[]),
      dollarOn: (_) => null,
    );
    final Position p = only(all, 'btc');
    expect(p.cost, Pair(d('950'), d('950')));
    expect(p.approximate, isFalse);
  });

  test('without the rate of the day, today\'s is used and said', () {
    final Account btc = crypto('btc', Asset.btc);
    final List<Position> all = positions(
      accounts: <Account>[bank, btc],
      entries: transfer('bank', '3800000', 'btc', '0.01', july),
      base: Asset.cop,
      today: today,
      dollarOn: (_) => null,
    );
    final Position p = only(all, 'btc');
    expect(p.cost.usd, d('1000'));
    expect(p.approximate, isTrue);
  });
}
