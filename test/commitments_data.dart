// Commitments for the example people in tests and review screens: two
// purchases in instalments, a subscription with a reminder, a charge seen
// twice, a price that went up, and a monthly charge not yet fixed.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/store/store.dart';

/// The purchase in instalments [addCommitments] pays outside the app.
const String televisor = 'instalments-tv';

Future<void> addCommitments(QuincenaStore store) async {
  final List<Account> accounts = await store.accounts();
  final Account bank = accounts.firstWhere(
    (Account a) => a.kind == AccountKind.bank && a.spendable,
  );
  final Account? card = accounts
      .where((Account a) => a.kind == AccountKind.card)
      .firstOrNull;

  final Instalments tv = Instalments(
    id: televisor,
    name: 'Televisor',
    principal: 2400000,
    count: 12,
    firstDue: DateTime(2026, 9, 5),
    rate: 26.82,
    fee: 0,
    cashPrice: 2299000,
  );
  await store.setSetting(
    'commitments.instalments',
    jsonEncode(<Object?>[
      tv.withPayment(DateTime(2026, 9, 5), tv.payment!).toJson(),
      Instalments(
        id: 'instalments-phone',
        name: 'Celular',
        principal: 1200000,
        count: 6,
        firstDue: DateTime(2026, 10, 20),
        instalment: 215000,
        accountId: card?.id,
      ).toJson(),
    ]),
  );

  final RecurringCharge? netflix = (await store.recurring())
      .where((RecurringCharge r) => r.name == 'Netflix')
      .firstOrNull;
  if (netflix != null) {
    await store.setSetting(
      'commitments.memories',
      jsonEncode(<String, Object?>{
        netflix.id: ChargeMemory(
          remindDays: 3,
          usedAt: DateTime(2026, 10, 1),
          inUse: false,
        ).toJson(),
      }),
    );
  }

  Future<void> spend(
    String amount,
    DateTime on,
    String payee,
    String category, {
    String source = 'manual',
  }) => store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse(amount),
    kind: EntryKind.expense,
    date: on,
    category: category,
    payee: payee,
    source: source,
  );
  // One payment, from the notification and again from the statement.
  await spend(
    '63200',
    DateTime(2026, 10, 2, 9, 40),
    'Éxito Laureles',
    'groceries',
    source: 'notification',
  );
  await spend(
    '63200',
    DateTime(2026, 10, 2, 9, 40),
    'EXITO LAURELES',
    'groceries',
    source: 'statement',
  );
  for (final int month in <int>[7, 8, 9]) {
    await spend('99000', DateTime(2026, month, 1, 7), 'Fit24', 'leisure');
    await spend(
      '16900',
      DateTime(2026, month, 5, 7),
      'Spotify',
      'subscriptions',
    );
  }
  await spend('119000', DateTime(2026, 10, 1, 7), 'Fit24', 'leisure');
}
