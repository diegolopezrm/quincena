// What a movement written by hand starts with: the account and the category
// of the last time the same name was used, or else the account of the last
// time, or else the one used most; and the names offered before typing.
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/merchants.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/entry_guess.dart';

final DateTime today = DateTime(2026, 10, 3);

Account account(String id, {bool archived = false}) => Account(
  id: id,
  name: id,
  kind: AccountKind.bank,
  asset: Asset.cop,
  opening: Decimal.zero,
  archived: archived,
);

int _ids = 0;

Entry entry(
  String accountId,
  String payee,
  DateTime date, {
  EntryKind kind = EntryKind.expense,
  String? category = 'restaurants',
  String source = 'manual',
  String? transferId,
  Money? cost,
}) => Entry(
  id: 'e${_ids++}',
  accountId: accountId,
  amount: Decimal.fromInt(kind == EntryKind.income ? 1000 : -1000),
  date: date,
  kind: kind,
  category: category,
  payee: payee,
  source: source,
  transferId: transferId,
  cost: cost,
);

void main() {
  final List<Account> accounts = <Account>[
    account('bank'),
    account('nequi'),
    account('cash'),
  ];

  EntryGuess guess(
    List<Entry> entries, {
    String payee = '',
    EntryKind kind = EntryKind.expense,
    Map<String, String> learned = const <String, String>{},
    List<Account>? among,
  }) => guessEntry(
    entries: entries,
    accounts: among ?? accounts,
    kind: kind,
    payee: payee,
    today: today,
    learned: learned,
  );

  test('a name seen before brings the account and the category of its last '
      'time, whatever the case and the accents', () {
    final List<Entry> entries = <Entry>[
      entry('bank', 'Crepes & Waffles', DateTime(2026, 9, 1)),
      entry(
        'nequi',
        'Crepes & Waffles',
        DateTime(2026, 9, 20),
        category: 'leisure',
      ),
      entry('cash', 'Tinto', DateTime(2026, 10, 2), category: 'groceries'),
    ];
    final EntryGuess g = guess(entries, payee: 'CREPES & WAFFLES');
    expect(g.accountId, 'nequi');
    expect(g.category, 'leisure');
    expect(g.like?.payee, 'Crepes & Waffles');

    final EntryGuess accents = guess(<Entry>[
      entry(
        'cash',
        'Éxito Laureles',
        DateTime(2026, 9, 1),
        category: 'groceries',
      ),
    ], payee: 'exito laureles');
    expect(accents.accountId, 'cash');
    expect(accents.category, 'groceries');
  });

  test('without the name, the account of the last movement written by hand, '
      'not of one a bank or a statement wrote', () {
    final List<Entry> entries = <Entry>[
      entry('nequi', 'Tinto', DateTime(2026, 10, 1)),
      entry(
        'bank',
        'EXITO',
        DateTime(2026, 10, 2),
        source: 'statement',
        category: 'groceries',
      ),
      entry('bank', 'Uber', DateTime(2026, 10, 2), source: 'notification'),
    ];
    final EntryGuess g = guess(entries, payee: 'Almuerzo');
    expect(g.accountId, 'nequi');
    expect(g.category, isNull);
    expect(g.like, isNull);
  });

  test('with nothing written by hand, the account used most these two '
      'months; on a tie, the one used last', () {
    final List<Entry> entries = <Entry>[
      for (final int day in <int>[1, 2, 3])
        entry('cash', 'Bus', DateTime(2026, 9, day), source: 'statement'),
      entry('bank', 'Uber', DateTime(2026, 9, 28), source: 'notification'),
      // Long ago, and many: years of statements are no habit of now.
      for (var i = 0; i < 9; i++)
        entry('nequi', 'Rappi', DateTime(2025, 1, i + 1), source: 'statement'),
    ];
    expect(guess(entries).accountId, 'cash');
    final List<Entry> tied = <Entry>[
      entry('cash', 'Bus', DateTime(2026, 9, 2), source: 'statement'),
      entry('bank', 'Uber', DateTime(2026, 9, 28), source: 'notification'),
    ];
    expect(guess(tied).accountId, 'bank');
    expect(guess(const <Entry>[]).accountId, isNull);
  });

  test('an archived account, a movement dated ahead, a transfer or a trade '
      'say nothing of where the next one is paid from', () {
    final List<Entry> entries = <Entry>[
      entry('cash', 'Tinto', DateTime(2026, 9, 1)),
      entry('old', 'Tinto', DateTime(2026, 9, 30)),
      entry('nequi', 'Matrícula', DateTime(2026, 10, 20)),
      entry('bank', '', DateTime(2026, 10, 2), transferId: 't1'),
      entry(
        'bank',
        'BTC',
        DateTime(2026, 10, 2),
        cost: Money(Decimal.fromInt(100), Asset.cop),
      ),
    ];
    final EntryGuess g = guess(
      entries,
      among: <Account>[...accounts, account('old', archived: true)],
    );
    expect(g.accountId, 'cash');
    // The same name, last in an account that is no longer open: the
    // category still holds, the account comes from the last time.
    final EntryGuess tinto = guess(
      <Entry>[
        entry('nequi', 'Pan', DateTime(2026, 10, 1)),
        entry('old', 'Tinto', DateTime(2026, 9, 30), category: 'groceries'),
      ],
      payee: 'Tinto',
      among: accounts,
    );
    expect(tinto.category, 'groceries');
    expect(tinto.accountId, 'nequi');
  });

  test('a new name takes the category the app learned from a capture, or the '
      'one a well-known name has', () {
    expect(
      guess(
        const <Entry>[],
        payee: 'Panadería La 80',
        learned: <String, String>{merchantKey('Panadería La 80'): 'groceries'},
      ).category,
      'groceries',
    );
    expect(guess(const <Entry>[], payee: 'Uber').category, 'transport');
    expect(guess(const <Entry>[], payee: 'Cosas varias').category, isNull);
  });

  test('money that came in goes by what came in: its name, the last income '
      'written by hand, and the words of a pay or a refund', () {
    final List<Entry> entries = <Entry>[
      entry(
        'bank',
        'Nómina',
        DateTime(2026, 9, 30),
        kind: EntryKind.income,
        category: 'salary',
      ),
      entry(
        'nequi',
        'Cliente Acme',
        DateTime(2026, 9, 20),
        kind: EntryKind.income,
        category: 'freelance',
      ),
      // An expense in another account says nothing of where money comes.
      entry('cash', 'Tinto', DateTime(2026, 10, 2)),
    ];
    final EntryGuess acme = guess(
      entries,
      payee: 'Cliente Acme',
      kind: EntryKind.income,
    );
    expect(acme.accountId, 'nequi');
    expect(acme.category, 'freelance');
    final EntryGuess other = guess(entries, kind: EntryKind.income);
    expect(other.accountId, 'bank');
    expect(other.category, isNull);
    expect(
      guess(
        const <Entry>[],
        payee: 'Pago nómina DL Soft',
        kind: EntryKind.income,
      ).category,
      'salary',
    );
    expect(
      guess(
        const <Entry>[],
        payee: 'Devolución Falabella',
        kind: EntryKind.income,
      ).category,
      'refund',
    );
  });

  group('the usual names', () {
    final List<Entry> entries = <Entry>[
      for (final int day in <int>[1, 8, 15])
        entry('nequi', 'Crepes & Waffles', DateTime(2026, 9, day)),
      entry('bank', 'Uber', DateTime(2026, 9, 2)),
      entry('bank', 'UBER TRIP', DateTime(2026, 9, 3), source: 'statement'),
      entry(
        'bank',
        'EXITO LAURELES',
        DateTime(2026, 9, 4),
        source: 'statement',
      ),
      entry('bank', 'Éxito Laureles', DateTime(2026, 9, 5)),
      entry(
        'bank',
        'EXITO LAURELES',
        DateTime(2026, 9, 6),
        source: 'statement',
      ),
      entry('cash', 'Tinto', DateTime(2026, 10, 2)),
      entry('cash', 'Matrícula', DateTime(2026, 10, 20)),
      entry('cash', 'Hace mucho', DateTime(2026, 1, 2)),
      entry(
        'bank',
        'Nómina',
        DateTime(2026, 9, 30),
        kind: EntryKind.income,
        category: 'salary',
      ),
    ];

    test('come most used first, as the person wrote them; one dated ahead '
        'or months old is not usual', () {
      expect(
        usualPayees(entries: entries, kind: EntryKind.expense, today: today),
        <String>[
          'Crepes & Waffles',
          'Éxito Laureles',
          'Tinto',
          'Uber Trip',
          'Uber',
        ],
      );
      expect(
        usualPayees(entries: entries, kind: EntryKind.income, today: today),
        <String>['Nómina'],
      );
    });

    test('narrow to those that contain what is typed, and leave out the one '
        'already typed whole', () {
      expect(
        usualPayees(
          entries: entries,
          kind: EntryKind.expense,
          today: today,
          typed: 'exi',
        ),
        <String>['Éxito Laureles'],
      );
      expect(
        usualPayees(
          entries: entries,
          kind: EntryKind.expense,
          today: today,
          typed: 'Éxito Laureles',
        ),
        isEmpty,
      );
      expect(
        usualPayees(
          entries: entries,
          kind: EntryKind.expense,
          today: today,
          most: 2,
        ),
        hasLength(2),
      );
    });
  });
}
