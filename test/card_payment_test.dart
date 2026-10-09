import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/card_payment.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';

Account _account(
  String id,
  String name,
  AccountKind kind, {
  String institution = '',
}) => Account(
  id: id,
  name: name,
  kind: kind,
  asset: Asset.cop,
  opening: Decimal.zero,
  institution: institution,
);

void main() {
  final Account bank = _account(
    'bank',
    'Bancolombia',
    AccountKind.bank,
    institution: 'Bancolombia',
  );
  final Account visa = _account(
    'visa',
    'Visa',
    AccountKind.card,
    institution: 'Bancolombia',
  );
  final Account master = _account(
    'master',
    'Mastercard Davivienda',
    AccountKind.card,
    institution: 'Davivienda',
  );
  final List<Account> accounts = <Account>[bank, visa, master];
  // The Mastercard owes the most.
  const Map<String, num> owed = <String, num>{'visa': 300000, 'master': 900000};

  Account? paid(String text, {String? category}) =>
      cardPaidBy(text, category, accounts: accounts, owed: owed);

  test('a card named with a payment is that card', () {
    expect(paid('Pago Visa'), visa);
    expect(paid('pagué la mastercard'), master);
    expect(paid('Abono tarjeta Davivienda'), master);
  });

  test('a card filed under loans is that card when said as a card', () {
    expect(paid('Visa', category: 'debt'), visa);
    // A loan from the same bank is a loan, not the card.
    expect(paid('Crédito Bancolombia', category: 'debt'), isNull);
  });

  test('a card said in general is the one that owes the most', () {
    expect(paid('Pago tarjeta'), master);
    expect(paid('abono TC'), master);
  });

  test('a payment that names no card is an expense', () {
    expect(paid('Pago arriendo'), isNull);
    expect(paid('Pago Claro'), isNull);
    expect(paid('Éxito Laureles'), isNull);
    expect(paid(''), isNull);
  });

  test('with no card there is nothing to ask', () {
    expect(
      cardPaidBy('Pago tarjeta', null, accounts: <Account>[bank], owed: owed),
      isNull,
    );
  });
}
