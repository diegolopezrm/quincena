// Which movements Movimientos marks as possible repeats: the same account
// and amount, a day or two apart, paid to names alike.
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/repeats.dart';

Entry _entry(
  String id,
  String amount,
  DateTime on, {
  String account = 'bank',
  String payee = '',
  EntryKind kind = EntryKind.expense,
  String source = 'manual',
  String? transferId,
  Money? cost,
}) => Entry(
  id: id,
  accountId: account,
  amount: kind == EntryKind.income
      ? Decimal.parse(amount)
      : -Decimal.parse(amount),
  date: on,
  kind: kind,
  payee: payee,
  source: source,
  transferId: transferId,
  cost: cost,
);

/// The ids of the movements marked, each with the id of the other one in
/// its pair.
Map<String, String> marked(
  List<Entry> entries, {
  Set<String> notRepeated = const <String>{},
}) => <String, String>{
  for (final MapEntry<String, PossibleRepeat> p in possibleRepeats(
    entries,
    notRepeated: notRepeated,
  ).entries)
    p.key: p.value.kept.id == p.key ? p.value.repeat.id : p.value.kept.id,
};

void main() {
  final DateTime morning = DateTime(2026, 10, 2, 9, 40);

  test('a notification and the statement of the same purchase are a '
      'possible repeat, the one recorded last the repeat', () {
    // Newest first, as the store lists them: the statement came after.
    final Entry statement = _entry(
      'statement',
      '63200',
      morning,
      payee: 'EXITO LAURELES',
      source: 'statement',
    );
    final Entry notified = _entry(
      'notified',
      '63200',
      morning,
      payee: 'Éxito Laureles',
      source: 'notification',
    );
    final Map<String, PossibleRepeat> pairs = possibleRepeats(<Entry>[
      statement,
      notified,
    ]);
    expect(pairs.keys, unorderedEquals(<String>['statement', 'notified']));
    final PossibleRepeat pair = pairs['notified']!;
    expect(identical(pair, pairs['statement']), isTrue);
    expect(pair.kept.id, 'notified');
    expect(pair.repeat.id, 'statement');
    expect(pair.key, repeatKey('statement', 'notified'));
    expect(repeatKey('a', 'b'), repeatKey('b', 'a'));
    // At the same moment the statement is the later record, whatever the
    // order they come in.
    expect(
      possibleRepeats(<Entry>[notified, statement])['notified']!.repeat.id,
      'statement',
    );
  });

  test('of two at the same moment from one source, the first listed is the '
      'newer', () {
    final List<Entry> entries = <Entry>[
      _entry('second', '18000', morning, payee: 'Uber'),
      _entry('first', '18000', morning, payee: 'Uber'),
    ];
    expect(possibleRepeats(entries)['first']!.repeat.id, 'second');
  });

  test('the later date is the repeat, whatever the order', () {
    final Entry first = _entry('first', '119000', morning, payee: 'Fit24');
    final Entry later = _entry(
      'later',
      '119000',
      morning.add(const Duration(hours: 30)),
      payee: 'Fit24 gimnasio',
    );
    for (final List<Entry> order in <List<Entry>>[
      <Entry>[first, later],
      <Entry>[later, first],
    ]) {
      final PossibleRepeat pair = possibleRepeats(order)['first']!;
      expect(pair.kept.id, 'first');
      expect(pair.repeat.id, 'later');
    }
  });

  test('two days apart still count, three do not', () {
    final Entry a = _entry('a', '50000', DateTime(2026, 10, 1, 23));
    final Entry b = _entry('b', '50000', DateTime(2026, 10, 3, 7));
    final Entry c = _entry('c', '50000', DateTime(2026, 10, 6, 7));
    expect(marked(<Entry>[c, b, a]), <String, String>{'a': 'b', 'b': 'a'});
  });

  test('another account, another amount or another name is no repeat', () {
    expect(
      marked(<Entry>[
        _entry('a', '50000', morning, payee: 'Rappi'),
        _entry('b', '50000', morning, payee: 'Rappi', account: 'nequi'),
        _entry('c', '50001', morning, payee: 'Rappi'),
        _entry('d', '50000', morning, payee: 'Uber'),
        _entry('e', '50000', morning, payee: 'Rappi', kind: EntryKind.income),
      ]),
      isEmpty,
    );
  });

  test('a movement with no name can repeat one that has it', () {
    expect(
      marked(<Entry>[
        _entry('a', '18000', morning, payee: 'Uber'),
        _entry('b', '18000', morning.add(const Duration(hours: 2))),
      ]),
      <String, String>{'a': 'b', 'b': 'a'},
    );
  });

  test('incomes repeat too', () {
    expect(
      marked(<Entry>[
        _entry(
          'a',
          '2400000',
          morning,
          payee: 'Nómina',
          kind: EntryKind.income,
        ),
        _entry(
          'b',
          '2400000',
          morning,
          payee: 'NOMINA',
          kind: EntryKind.income,
        ),
      ]),
      hasLength(2),
    );
  });

  test('transfers and crypto trades are left alone', () {
    expect(
      marked(<Entry>[
        _entry('a', '50000', morning, transferId: 't1'),
        _entry('b', '50000', morning, transferId: 't2'),
        _entry(
          'c',
          '0.001',
          morning,
          account: 'btc',
          kind: EntryKind.income,
          cost: Money(Decimal.parse('400000'), Asset.cop),
        ),
        _entry(
          'd',
          '0.001',
          morning,
          account: 'btc',
          kind: EntryKind.income,
          cost: Money(Decimal.parse('400000'), Asset.cop),
        ),
      ]),
      isEmpty,
    );
  });

  test('a pair the person said is two is not marked again', () {
    final List<Entry> entries = <Entry>[
      _entry('a', '9800', morning, payee: 'Metro'),
      _entry(
        'b',
        '9800',
        morning.add(const Duration(hours: 9)),
        payee: 'Metro',
      ),
    ];
    expect(marked(entries), hasLength(2));
    expect(
      marked(entries, notRepeated: <String>{repeatKey('a', 'b')}),
      isEmpty,
    );
  });

  test('of three alike, each is paired with the closest', () {
    final List<Entry> entries = <Entry>[
      _entry('c', '9800', morning.add(const Duration(hours: 30))),
      _entry('b', '9800', morning.add(const Duration(hours: 1))),
      _entry('a', '9800', morning),
    ];
    expect(marked(entries), <String, String>{'a': 'b', 'b': 'a', 'c': 'b'});
    // Once a and b are said to be two, c still pairs with the closest.
    expect(
      marked(entries, notRepeated: <String>{repeatKey('a', 'b')}),
      <String, String>{'a': 'c', 'b': 'c', 'c': 'b'},
    );
  });
}
