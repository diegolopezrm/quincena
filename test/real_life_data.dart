// Shared expenses, variable income and a trip for the example people in
// tests and review screens. Every name and amount is made up.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/store/store.dart';

/// The group [addRealLife] makes.
const String guatape = 'group-guatape';

/// The trip [addRealLife] makes.
const String newYork = 'trip-ny';

Future<void> addRealLife(QuincenaStore store) async {
  final List<Account> accounts = await store.accounts();
  final Account bank = accounts.firstWhere(
    (Account a) => a.kind == AccountKind.bank && a.spendable,
  );
  final Account card = accounts.firstWhere(
    (Account a) => a.kind == AccountKind.card,
    orElse: () => bank,
  );
  Decimal d(String s) => Decimal.parse(s);

  final Entry lunch = await store.addEntry(
    accountId: bank.id,
    amount: d('90000'),
    kind: EntryKind.expense,
    date: DateTime(2026, 9, 27, 14),
    category: 'restaurants',
    payee: 'Almuerzo en Guatapé',
  );
  final Entry back = await store.addEntry(
    accountId: bank.id,
    amount: d('30000'),
    kind: EntryKind.income,
    date: DateTime(2026, 9, 29, 10),
    category: 'other_income',
    payee: 'Laura te envió',
  );
  await store.setSetting(
    'shared.groups',
    jsonEncode(<Object?>[
      Group(
        id: guatape,
        name: 'Paseo a Guatapé',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'laura', name: 'Laura'),
          Member(id: 'camilo', name: 'Camilo'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'hotel',
            label: 'Hotel',
            date: DateTime(2026, 9, 26),
            paidBy: 'camilo',
            shares: const <String, int>{
              meId: 200000,
              'laura': 200000,
              'camilo': 200000,
            },
          ),
          SharedExpense(
            id: 'lunch',
            label: 'Almuerzo',
            date: lunch.date,
            paidBy: meId,
            shares: const <String, int>{
              meId: 30000,
              'laura': 30000,
              'camilo': 30000,
            },
            entryId: lunch.id,
          ),
        ],
        settlements: <Settlement>[
          Settlement(
            id: 'laura-back',
            from: 'laura',
            to: meId,
            amount: 30000,
            date: back.date,
            entryId: back.id,
          ),
        ],
      ).toJson(),
    ]),
  );

  await store.addEntry(
    accountId: bank.id,
    amount: d('1000000'),
    kind: EntryKind.income,
    date: DateTime(2026, 10, 2, 9),
    category: 'freelance',
    payee: 'Estudio Sur',
  );
  await store.setSetting(
    'freelance',
    jsonEncode(
      FreelancePlan(
        incomes: <ExpectedIncome>[
          ExpectedIncome(
            id: 'norte',
            client: 'Estudio Norte',
            amount: 1500000,
            expected: DateTime(2026, 10, 18),
          ),
          ExpectedIncome(
            id: 'uno',
            client: 'Agencia Uno',
            amount: 700000,
            expected: DateTime(2026, 9, 28),
          ),
          ExpectedIncome(
            id: 'taller',
            client: 'Taller de marca',
            amount: 900000,
            expected: DateTime(2026, 10, 25),
            status: IncomeStatus.estimated,
          ),
        ],
        reservePercent: 15,
        reserveSince: DateTime(2026, 10, 1),
      ).toJson(),
    ),
  );

  final Entry dinner = await store.addEntry(
    accountId: card.id,
    amount: d('214900'),
    kind: EntryKind.expense,
    date: DateTime(2026, 10, 2, 20),
    category: 'restaurants',
    payee: 'Joe\'s Pizza',
  );
  final Entry museum = await store.addEntry(
    accountId: card.id,
    amount: d('107000'),
    kind: EntryKind.expense,
    date: DateTime(2026, 10, 3, 11),
    category: 'leisure',
    payee: 'MoMA',
  );
  ForeignCharge abroad(String amount) => ForeignCharge(
    amount: d(amount),
    rate: d('4150.30'),
    rateOn: DateTime(2026, 10, 2),
    rateSource: 'trm',
    fee: 3,
  );
  await store.setSetting(
    'trips',
    jsonEncode(<Object?>[
      Trip(
        id: newYork,
        name: 'Nueva York',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 9),
        currency: 'USD',
        budget: d('1500'),
        fee: 3,
        foreign: <String, ForeignCharge>{
          dinner.id: abroad('50'),
          museum.id: abroad('25'),
        },
        adjusted: <String, Decimal>{dinner.id: d('213740')},
      ).toJson(),
    ]),
  );
}
