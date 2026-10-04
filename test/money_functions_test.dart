// What a goal needs and when it arrives count the same contributions, on
// any day of the month.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/format/dates.dart';
import 'package:quincena/functions/money_functions.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en_US');
  });

  setUp(() {
    Intl.defaultLocale = 'es_CO';
    appToday = DateTime(2026, 10, 1);
  });

  tearDown(() {
    Intl.defaultLocale = 'es_CO';
    appToday = DateTime(2026, 10, 1);
  });

  group('contributions', () {
    test('land on the 16th, from this month while it has not passed', () {
      expect(contributionDays(until: DateTime(2026, 12, 20)), <DateTime>[
        DateTime(2026, 10, 16),
        DateTime(2026, 11, 16),
        DateTime(2026, 12, 16),
      ]);
      appToday = DateTime(2026, 10, 16);
      expect(contributionOn(0), DateTime(2026, 10, 16));
      appToday = DateTime(2026, 10, 17);
      expect(contributionOn(0), DateTime(2026, 11, 16));
    });

    test('count across the year, and stop at a count', () {
      expect(contributionDays(count: 4).last, DateTime(2027, 1, 16));
      expect(contributionOn(7), DateTime(2027, 5, 16));
      expect(
        contributionDays(count: 2, until: DateTime(2027, 6, 1)),
        <DateTime>[DateTime(2026, 10, 16), DateTime(2026, 11, 16)],
      );
    });

    test('fall on a shorter month\'s last day', () {
      expect(contributionDays(count: 3, day: 31), <DateTime>[
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 31),
      ]);
    });
  });

  test('after the 16th, what it takes is what arrives in time', () {
    // Today's 16th has passed: November and December are all that fit.
    appToday = DateTime(2026, 10, 20);
    expect(monthlyNeeded(2800000, 1000000, '2026-12-20'), 900000);
    expect(arrivesBy(2800000, 1000000, 900000, '2026-12-20'), isTrue);
    expect(arrivesBy(2800000, 1000000, 600000, '2026-12-20'), isFalse);
    expect(arrivalMonth(2800000, 1000000, 900000), 'diciembre de 2026');
  });

  test('before it, the 16th of this month counts', () {
    expect(monthlyNeeded(2800000, 1000000, '2026-12-20'), 600000);
    expect(arrivesBy(2800000, 1000000, 600000, '2026-12-20'), isTrue);
    expect(arrivalMonth(2800000, 1000000, 250000), 'mayo de 2027');
  });

  test('a goal that never arrives says so in the interface language', () {
    expect(arrivalMonth(2800000, 1000000, 0), 'nunca');
    Intl.defaultLocale = 'en_US';
    expect(arrivalMonth(2800000, 1000000, 0), 'never');
    expect(arrivalMonth(2800000, 1000000, 250000), 'May 2027');
  });

  test('dates and lists read as a sentence', () {
    expect(dayMonthAhead(DateTime(2026, 12, 16)), '16 de diciembre');
    expect(dayMonthAhead(DateTime(2027, 5, 16)), '16 de mayo de 2027');
    expect(listed(<String>['a', 'b', 'c']), 'a, b y c');
    expect(listed(<String>['a']), 'a');
    Intl.defaultLocale = 'en_US';
    expect(dayMonthAhead(DateTime(2027, 5, 16)), 'May 16, 2027');
    expect(listed(<String>['a', 'b', 'c']), 'a, b and c');
  });
}
