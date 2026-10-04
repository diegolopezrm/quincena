import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/format/dates.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en_US');
  });

  group('a range of days says the month and the year once', () {
    String es(DateTime from, DateTime to) =>
        Intl.withLocale('es_CO', () => dayRange(from, to)) as String;
    String en(DateTime from, DateTime to) =>
        Intl.withLocale('en_US', () => dayRange(from, to)) as String;

    test('in Spanish', () {
      expect(es(DateTime(2026, 9, 1), DateTime(2026, 9, 5)), '1–5 sept 2026');
      expect(
        es(DateTime(2026, 8, 28), DateTime(2026, 9, 5)),
        '28 ago – 5 sept 2026',
      );
      expect(
        es(DateTime(2025, 12, 28), DateTime(2026, 1, 3)),
        '28 dic 2025 – 3 ene 2026',
      );
      expect(es(DateTime(2026, 9, 5), DateTime(2026, 9, 5)), '5 sept 2026');
    });

    test('in English', () {
      expect(en(DateTime(2026, 9, 1), DateTime(2026, 9, 5)), 'Sep 1–5, 2026');
      expect(
        en(DateTime(2026, 8, 28), DateTime(2026, 9, 5)),
        'Aug 28 – Sep 5, 2026',
      );
      expect(
        en(DateTime(2025, 12, 28), DateTime(2026, 1, 3)),
        'Dec 28, 2025 – Jan 3, 2026',
      );
      expect(en(DateTime(2026, 9, 5), DateTime(2026, 9, 5)), 'Sep 5, 2026');
    });
  });

  test('a day of the month is an ordinal in English, a number in Spanish', () {
    const Map<int, String> said = <int, String>{
      1: '1st',
      2: '2nd',
      3: '3rd',
      4: '4th',
      11: '11th',
      12: '12th',
      13: '13th',
      15: '15th',
      21: '21st',
      22: '22nd',
      23: '23rd',
      30: '30th',
      31: '31st',
    };
    for (final MapEntry<int, String> day in said.entries) {
      expect(ordinal(day.key), day.value);
    }
    expect(Intl.withLocale('en_US', () => dayOfMonth(15)), '15th');
    expect(Intl.withLocale('es_CO', () => dayOfMonth(15)), '15');
  });

  test('an hour never parts from its a. m.', () {
    final DateTime ten = DateTime(2026, 10, 3, 10);
    expect(
      Intl.withLocale('es_CO', () => timeOfDay(ten)),
      '10:00\u00a0a.\u202fm.',
    );
    expect(Intl.withLocale('en_US', () => timeOfDay(ten)), '10:00\u00a0AM');
  });
}
