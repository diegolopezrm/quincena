import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/ui/own/amount_input.dart';

/// Types [keys] one at a time, as a keyboard would, and returns the text.
String type(AmountInputFormatter f, String keys) {
  TextEditingValue value = TextEditingValue.empty;
  for (final String key in keys.split('')) {
    final String next = value.text + key;
    value = f.formatEditUpdate(
      value,
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );
  }
  return value.text;
}

void main() {
  test('pesos group as they are typed and take no decimals', () {
    final AmountInputFormatter pesos = AmountInputFormatter(
      maxDecimals: 0,
      english: false,
    );
    expect(type(pesos, '45900'), '45.900');
    expect(type(pesos, '1500000'), '1.500.000');
    // Someone used to typing the dots gets the same amount.
    expect(type(pesos, '1.500.000'), '1.500.000');
    expect(type(pesos, '0045'), '45');
  });

  test('dollars in Spanish take a comma for cents, even from a point key', () {
    final AmountInputFormatter dollars = AmountInputFormatter(
      maxDecimals: 2,
      english: false,
    );
    expect(type(dollars, '1250,5'), '1.250,5');
    expect(type(dollars, '10.99'), '10,99');
    expect(type(dollars, '3,999'), '3,99');
    expect(type(dollars, ',5'), '0,5');
  });

  test('English groups with commas and takes a point', () {
    final AmountInputFormatter en = AmountInputFormatter(
      maxDecimals: 8,
      english: true,
    );
    expect(type(en, '45900'), '45,900');
    expect(type(en, '0.00012345'), '0.00012345');
    expect(type(en, '1250.50'), '1,250.50');
  });
}
