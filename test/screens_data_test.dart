// The example the tour of the app shows: one total in Spanish and in
// English, whatever Binance says the day the pictures are taken; a gain on
// what the coins cost, not on coins with no purchase price; a card with its
// limit; and a statement whose card payment goes in as a move between
// accounts.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/l10n/l10n.dart';

import '../integration_test/tour.dart';
import 'fonts.dart';
import 'own_flow_test.dart' show screen;

void main() {
  // One example in each language, open side by side, on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  /// What Cuentas and the Cripto page say in [language], as the tour
  /// opens them.
  Future<(String, String)> accounts(
    WidgetTester tester,
    String language,
  ) async {
    final AppLocalizations l = lookupAppLocalizations(Locale(language));
    late String accounts;
    late String crypto;
    await playScene(
      tester,
      Scene('cuentas', data: fullAccount, english: language == 'en', (
        Tour t,
      ) async {
        await t.tap(l.tabAccounts);
        accounts = screen(tester);
        await t.tap(l.cryptoPerformanceRow);
        crypto = screen(tester);
        await t.back();
      }),
      (String name) async {},
      size: const Size(402, 874),
    );
    return (accounts, crypto);
  }

  /// The figures of [text], digits only, so both languages compare.
  List<String> figures(String text) => <String>[
    for (final Match m in RegExp(r'\$[\d.,]+').allMatches(text))
      m[0]!.replaceAll(RegExp(r'[^\d]'), ''),
  ];

  testWidgets('both languages show the same figures, from the example\'s '
      'fixed prices, and the gain is on what the coins cost', (tester) async {
    final (String accountsEs, String cryptoEs) = await accounts(tester, 'es');
    final (String accountsEn, String cryptoEn) = await accounts(tester, 'en');

    expect(accountsEs, contains('Patrimonio\n\$10.726.827'));
    expect(figures(accountsEn), figures(accountsEs));
    expect(figures(cryptoEn), figures(cryptoEs));

    // The day's move comes from the example's prices: a market that could
    // not be read would leave it without data.
    expect(cryptoEs, matches(RegExp(r'En 24 horas\n\+\W?\$111\.979')));
    expect(cryptoEs, isNot(contains('Sin dato')));

    // Every coin has what it cost: the gain is a gain, and nothing is left
    // out of it for coming in with no purchase price.
    expect(
      accountsEs,
      matches(RegExp(r'Ganancia no realizada \+\$[\d.]+ · \+6,95 %')),
    );
    expect(cryptoEs, isNot(contains('sin precio de compra')));

    // The card says how much of its limit is left.
    expect(accountsEs, contains('Cupo libre \$2.155.200'));
  });

  testWidgets('the tour\'s statement brings the card\'s payment in as a move '
      'to the Visa, not as a purchase', (tester) async {
    final Map<String, String> seen = <String, String>{};
    await playScene(
      tester,
      scenes.firstWhere((Scene s) => s.name == '10-importar-extracto'),
      (String name) async => seen[name] = screen(tester),
      size: const Size(402, 874),
    );

    final String review = seen['10-importar-extracto-02-revisar-extracto']!;
    expect(review, contains('6 nuevos · ninguno repetido'));
    expect(review, contains('1 entre tus cuentas'));
    expect(
      review,
      matches(
        RegExp(
          r'Tarjeta Visa\n−\W?\$480\.000\n6 sept · Pago de tu tarjeta Visa',
        ),
      ),
    );
    expect(review, contains('Importar 6 movimientos'));
    expect(
      seen['10-importar-extracto-04-extracto-importado'],
      contains('Uno quedó como movimiento entre tus cuentas'),
    );
  });
}
