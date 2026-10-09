// Finding a movement in Movimientos: by an amount written the way people
// write it, and by account, category, type, dates and amount, alone or
// together with a search. What it finds adds up per currency.
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/categories.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/movement_search.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

final Account _bank = Account(
  id: 'bank',
  name: 'Bancolombia',
  kind: AccountKind.bank,
  asset: Asset.cop,
  opening: Decimal.zero,
);
final Account _nequi = Account(
  id: 'nequi',
  name: 'Nequi',
  kind: AccountKind.wallet,
  asset: Asset.cop,
  opening: Decimal.zero,
);
final Account _dollars = Account(
  id: 'dollars',
  name: 'Cuenta en dólares',
  kind: AccountKind.bank,
  asset: Asset.usd,
  opening: Decimal.zero,
);
final Account _bitcoin = Account(
  id: 'btc',
  name: 'Bitcoin',
  kind: AccountKind.exchange,
  asset: Asset.btc,
  opening: Decimal.zero,
);

/// Euros with no rate to pesos.
final Account _euros = Account(
  id: 'eur',
  name: 'Cuenta en euros',
  kind: AccountKind.bank,
  asset: Asset.eur,
  opening: Decimal.zero,
);

Entry _spend(
  String id,
  Account a,
  String amount,
  DateTime on,
  String category,
  String payee,
) => Entry(
  id: id,
  accountId: a.id,
  amount: -d(amount),
  date: on,
  kind: EntryKind.expense,
  category: category,
  payee: payee,
);

final Entry market = _spend(
  'market',
  _bank,
  '187400',
  DateTime(2026, 10, 2, 12),
  'groceries',
  'Éxito Laureles',
);
final Entry crepes = _spend(
  'crepes',
  _nequi,
  '23500',
  DateTime(2026, 10, 3, 12),
  'restaurants',
  'Crepes & Waffles',
);
final Entry pay = Entry(
  id: 'pay',
  accountId: _bank.id,
  amount: d('2400000'),
  date: DateTime(2026, 9, 30, 8),
  kind: EntryKind.income,
  category: 'salary',
  payee: 'Nómina',
);
final Entry rent = _spend(
  'rent',
  _bank,
  '1650000',
  DateTime(2026, 9, 5, 12),
  'housing',
  'Arriendo',
);

/// Pesos to dollars: 331.300 left, 98,50 arrived.
final Entry sent = Entry(
  id: 'sent',
  accountId: _bank.id,
  amount: d('-331300'),
  date: DateTime(2026, 10, 1, 18),
  kind: EntryKind.transfer,
  transferId: 'move',
);
final Entry arrived = Entry(
  id: 'arrived',
  accountId: _dollars.id,
  amount: d('98.5'),
  date: DateTime(2026, 10, 1, 18),
  kind: EntryKind.transfer,
  transferId: 'move',
);
final Entry spotify = _spend(
  'spotify',
  _dollars,
  '10.99',
  DateTime(2026, 10, 2, 9),
  'subscriptions',
  'Spotify',
);

/// Bitcoin bought on Binance P2P for 400.000 pesos.
final Entry bought = Entry(
  id: 'bought',
  accountId: _bitcoin.id,
  amount: d('0.001'),
  date: DateTime(2026, 10, 1, 10),
  kind: EntryKind.income,
  payee: 'Compra P2P',
  cost: Money(d('400000'), Asset.cop),
);
final Entry august = _spend(
  'august',
  _bank,
  '50000',
  DateTime(2026, 8, 20, 20),
  'restaurants',
  'Crepes',
);
final Entry rappi = _spend(
  'rappi',
  _bank,
  '80000',
  DateTime(2026, 9, 20, 20),
  'restaurants',
  'Rappi',
);
final Entry zara = _spend(
  'zara',
  _euros,
  '20',
  DateTime(2026, 10, 1, 15),
  'shopping',
  'Zara',
);

final List<Entry> _all = <Entry>[
  crepes,
  market,
  spotify,
  sent,
  arrived,
  bought,
  zara,
  pay,
  rappi,
  rent,
  august,
];

/// What Movimientos lists: each transfer once, by the leg that left.
final List<Entry> shown = <Entry>[
  for (final Entry e in _all)
    if (e.transferId == null || e.amount < Decimal.zero) e,
];

final MovementFinder finder = MovementFinder(
  snapshot: StoreSnapshot(
    profile: const Profile(
      name: 'Ana',
      base: Asset.cop,
      schedule: TwiceMonthly(),
    ),
    accounts: <Account>[_bank, _nequi, _dollars, _bitcoin, _euros],
    entries: _all,
    recurring: const <RecurringCharge>[],
    goals: const <SavingsGoal>[],
    rates: <Rate>[
      Rate(
        asset: 'USD',
        quote: 'COP',
        value: d('4000'),
        asOf: DateTime(2026, 10, 3),
        source: 'trm',
      ),
      Rate(
        asset: 'BTC',
        quote: 'USDT',
        value: d('100000'),
        asOf: DateTime(2026, 10, 3),
        source: 'binance',
      ),
    ],
    categories: const <CategoryItem>[],
  ),
  categoryName: (String key) => categoryLabel(key, 'es'),
  today: DateTime(2026, 10, 3),
  schedule: const TwiceMonthly(),
);

/// The ids of what [query] and [filter] find among [shown].
Set<String> found([
  String query = '',
  MovementFilter filter = const MovementFilter(),
]) => <String>{
  for (final Entry e in finder.find(shown, query: query, filter: filter)) e.id,
};

void main() {
  group('an amount in a search', () {
    test('reads the ways people write it', () {
      expect(amountsIn('187400'), <Decimal>[d('187400')]);
      expect(amountsIn('187.400'), containsAll(<Decimal>[d('187400')]));
      expect(amountsIn(r'$187.400'), contains(d('187400')));
      expect(amountsIn(r'−$187.400'), contains(d('187400')));
      expect(amountsIn(r'- $ 187.400'), contains(d('187400')));
      expect(amountsIn('63.200 COP'), contains(d('63200')));
      expect(amountsIn(r'US$10,99'), <Decimal>[d('10.99')]);
      expect(amountsIn('10.99'), <Decimal>[d('10.99')]);
      expect(amountsIn('1.234.567'), <Decimal>[d('1234567')]);
      expect(amountsIn('1.234,5'), <Decimal>[d('1234.5')]);
      expect(amountsIn('0,0042 btc'), <Decimal>[d('0.0042')]);
    });

    test('keeps both readings of a separator that has two', () {
      // 187.400 in Spanish, 187,4 in English.
      expect(amountsIn('187.400').toSet(), <Decimal>{d('187400'), d('187.4')});
      expect(amountsIn('187,400').toSet(), <Decimal>{d('187.4'), d('187400')});
    });

    test('is not read in words, even with a figure in them', () {
      for (final String words in <String>[
        '',
        r' $ ',
        'D1',
        'Fit24',
        'uber',
        '50 mil',
        '24 horas',
        '187.40.0',
        '1,2,3',
      ]) {
        expect(amountsIn(words), isEmpty, reason: words);
      }
    });
  });

  group('a search', () {
    test('finds an amount however it is written', () {
      for (final String typed in <String>[
        '187400',
        '187.400',
        r'$187.400',
        r'-$187.400',
      ]) {
        expect(found(typed), <String>{'market'}, reason: typed);
      }
    });

    test('finds a transfer by what arrived and a purchase by what it '
        'cost', () {
      expect(found('98,5'), <String>{'sent'});
      expect(found('331.300'), <String>{'sent'});
      expect(found('400.000'), <String>{'bought'});
      expect(found(r'US$10,99'), <String>{'spotify'});
    });

    test('finds words in names, notes, categories and accounts, without '
        'accents', () {
      expect(found('exito'), <String>{'market'});
      expect(found('restaurantes'), <String>{'crepes', 'august', 'rappi'});
      expect(found('dolares'), <String>{'sent', 'spotify'});
      expect(found('zapatos'), isEmpty);
    });

    test('finds what has the figure as words or as its amount', () {
      // «50.000» is August's crepes; nothing is named with it.
      expect(found('50.000'), <String>{'august'});
    });
  });

  group('a filter', () {
    test('by account takes a transfer by either end', () {
      expect(
        found('', const MovementFilter(accounts: <String>{'nequi'})),
        <String>{'crepes'},
      );
      expect(
        found('', const MovementFilter(accounts: <String>{'dollars'})),
        <String>{'sent', 'spotify'},
      );
      expect(
        found('', const MovementFilter(accounts: <String>{'nequi', 'eur'})),
        <String>{'crepes', 'zara'},
      );
    });

    test('by category', () {
      expect(
        found('', const MovementFilter(categories: <String>{'restaurants'})),
        <String>{'crepes', 'august', 'rappi'},
      );
      expect(
        found(
          '',
          const MovementFilter(categories: <String>{'salary', 'housing'}),
        ),
        <String>{'pay', 'rent'},
      );
    });

    test('by type: crypto bought counts with the transfers', () {
      expect(
        found('', const MovementFilter(type: MovementType.expenses)),
        <String>{
          'market',
          'crepes',
          'rent',
          'spotify',
          'august',
          'rappi',
          'zara',
        },
      );
      expect(
        found('', const MovementFilter(type: MovementType.incomes)),
        <String>{'pay'},
      );
      expect(
        found('', const MovementFilter(type: MovementType.transfers)),
        <String>{'sent', 'bought'},
      );
    });

    test('by dates: this pay period, this month, last month and days '
        'picked', () {
      // Paid on the 15th and the 30th: the period started on 30 September.
      expect(
        found('', const MovementFilter(days: MovementDays.period)),
        <String>{
          'pay',
          'market',
          'crepes',
          'sent',
          'spotify',
          'bought',
          'zara',
        },
      );
      expect(
        found('', const MovementFilter(days: MovementDays.thisMonth)),
        <String>{'market', 'crepes', 'sent', 'spotify', 'bought', 'zara'},
      );
      expect(
        found('', const MovementFilter(days: MovementDays.lastMonth)),
        <String>{'pay', 'rent', 'rappi'},
      );
      expect(
        found(
          '',
          MovementFilter(
            days: MovementDays.range,
            from: DateTime(2026, 9, 20),
            to: DateTime(2026, 9, 30),
          ),
        ),
        <String>{'rappi', 'pay'},
      );
    });

    test('by amount compares what the row says in pesos, both ends '
        'included', () {
      expect(
        found('', MovementFilter(min: d('50000'), max: d('200000'))),
        <String>{'market', 'august', 'rappi'},
      );
      // US$10,99 at 4.000 is $43.960.
      expect(
        found('', MovementFilter(min: d('40000'), max: d('50000'))),
        <String>{'spotify', 'august'},
      );
      expect(found('', MovementFilter(min: d('1000000'))), <String>{
        'pay',
        'rent',
      });
      // Euros without a rate are no amount in pesos.
      expect(found('', MovementFilter(max: d('100'))), isEmpty);
    });

    test('adds up with the others and with the search', () {
      expect(
        found('crepes', const MovementFilter(days: MovementDays.thisMonth)),
        <String>{'crepes'},
      );
      expect(
        found('crepes', const MovementFilter(days: MovementDays.lastMonth)),
        isEmpty,
      );
      expect(
        found(
          '',
          MovementFilter(
            accounts: const <String>{'bank'},
            categories: const <String>{'restaurants'},
            type: MovementType.expenses,
            days: MovementDays.lastMonth,
            min: d('50000'),
          ),
        ),
        <String>{'rappi'},
      );
    });

    test('says how many of its parts narrow the list, and lets go of '
        'each', () {
      final MovementFilter f = MovementFilter(
        accounts: const <String>{'bank'},
        type: MovementType.expenses,
        days: MovementDays.range,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        min: d('1000'),
        max: d('9000'),
      );
      expect(f.active, 4);
      expect(f.isEmpty, isFalse);
      expect(const MovementFilter().isEmpty, isTrue);
      final MovementFilter without = f.copyWith(
        clearType: true,
        clearDays: true,
        clearMin: true,
        clearMax: true,
        accounts: const <String>{},
      );
      expect(without, const MovementFilter());
      expect(without.from, isNull);
    });
  });

  test('what is found adds up per currency, pesos first, without the '
      'transfers', () {
    expect(finder.totals(<Entry>[spotify, market, crepes, sent, pay]), <Money>[
      Money(d('2189100'), Asset.cop),
      Money(d('-10.99'), Asset.usd),
    ]);
    expect(finder.totals(<Entry>[sent]), isEmpty);
  });
}
