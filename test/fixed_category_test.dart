// A fixed payment typed by hand takes its category from its name, not from
// a default: a gym or a loan is not a subscription.
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/merchants.dart';

void main() {
  test('the words people name their fixed payments with', () {
    expect(fixedCategoryFor('Arriendo'), 'housing');
    expect(fixedCategoryFor('Renta del apartamento'), 'housing');
    expect(fixedCategoryFor('Crédito del carro'), 'debt');
    expect(fixedCategoryFor('Cuota de la moto'), 'debt');
    expect(fixedCategoryFor('Luz'), 'utilities');
    expect(fixedCategoryFor('Plan del celular'), 'utilities');
    expect(fixedCategoryFor('Gimnasio'), 'health');
    expect(fixedCategoryFor('Parqueadero'), 'transport');
  });

  test('a well-known name first, with or without its plus', () {
    expect(fixedCategoryFor('Disney+'), 'subscriptions');
    expect(fixedCategoryFor('Netflix'), 'subscriptions');
    expect(fixedCategoryFor('EPM'), 'utilities');
  });

  test('a name that says nothing has no category', () {
    expect(fixedCategoryFor('Clases de inglés'), isNull);
    expect(fixedCategoryFor(''), isNull);
    // Part of a word is no word: «gasto» is no gas bill.
    expect(fixedCategoryFor('Gastos del perro'), isNull);
  });
}
