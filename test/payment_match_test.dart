// Money that came in, said to be what a client or a friend owed the
// person, when their own records say so.
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/payment_match.dart';
import 'package:quincena/domain/shared.dart';

void main() {
  final FreelancePlan plan = FreelancePlan(
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
        id: 'paid',
        client: 'Taller',
        amount: 300000,
        expected: DateTime(2026, 9, 20),
        status: IncomeStatus.collected,
      ),
    ],
  );
  const Group camilo = Group(
    id: 'g-camilo',
    name: 'Camilo',
    members: <Member>[
      Member(id: meId, name: ''),
      Member(id: 'camilo', name: 'Camilo'),
    ],
    expenses: <SharedExpense>[],
  );
  final Group lent = camilo.withExpense(
    SharedExpense(
      id: 'loan',
      label: 'Préstamo',
      date: DateTime(2026, 9, 20),
      paidBy: meId,
      shares: const <String, int>{'camilo': 100000},
    ),
  );

  test('a name is the sender\'s when every word of it is there', () {
    expect(namesMatch('Agencia Uno', 'AGENCIA UNO SAS'), isTrue);
    expect(namesMatch('Laura', 'Laura Gómez'), isTrue);
    expect(namesMatch('Estudio Norte', 'Estudio Sur'), isFalse);
    expect(namesMatch('', 'Laura Gómez'), isFalse);
  });

  test('a client\'s payment is the one expected, also with what they '
      'withheld', () {
    PaymentMatch? match(String from, int amount) => matchPayment(
      from: from,
      amount: amount,
      freelance: plan,
      groups: const <Group>[],
    );
    expect(match('AGENCIA UNO SAS', 700000)?.income?.id, 'uno');
    expect(match('Agencia Uno', 623000)?.income?.id, 'uno');
    // Too far from what was billed, or already collected, is not it.
    expect(match('Agencia Uno', 300000), isNull);
    expect(match('Taller', 300000), isNull);
    // Another studio is another client.
    expect(match('Estudio Sur', 1500000), isNull);
  });

  test('what a friend owed is paid, all or part of it', () {
    PaymentMatch? match(String from, int amount) => matchPayment(
      from: from,
      amount: amount,
      freelance: const FreelancePlan(),
      groups: <Group>[lent],
    );
    final PaymentMatch? part = match('CAMILO RUIZ', 60000);
    expect(part?.group?.id, 'g-camilo');
    expect(part?.member?.id, 'camilo');
    expect(part?.owed, 100000);
    expect(match('Camilo Ruiz', 100000)?.owed, 100000);
    // More than what is owed, or someone who owes nothing, is not it.
    expect(match('Camilo Ruiz', 250000), isNull);
    expect(
      matchPayment(
        from: 'Camilo Ruiz',
        amount: 60000,
        freelance: const FreelancePlan(),
        groups: <Group>[camilo],
      ),
      isNull,
    );
    expect(match('Laura Gómez', 60000), isNull);
  });
}
