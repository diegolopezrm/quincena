// Material's own words, as the app speaks them: every calendar accepts
// with «Aceptar» beside «Cancelar», not «ACEPTAR», and the rest is
// Flutter's Spanish as it was.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/l10n/material_es.dart';

void main() {
  for (final (Locale locale, String ok, String cancel, String help)
      in <(Locale, String, String, String)>[
        (const Locale('es'), 'Aceptar', 'Cancelar', 'Seleccionar fecha'),
        (const Locale('en'), 'OK', 'Cancel', 'Select date'),
      ]) {
    testWidgets('a calendar in ${locale.languageCode} accepts with «$ok» '
        'beside «$cancel»', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appLocales,
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 10, 3),
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
              ),
              child: const Text('Fecha'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Fecha'));
      await tester.pumpAndSettle();

      expect(find.text(ok), findsOneWidget);
      expect(find.text(cancel), findsOneWidget);
      expect(find.text('ACEPTAR'), findsNothing);
      expect(find.text(help), findsOneWidget);
      // The app's own words are there too.
      expect(
        AppLocalizations.of(tester.element(find.text(ok)))!.localeName,
        locale.languageCode,
      );

      await tester.tap(find.text(ok));
      await tester.pumpAndSettle();
      expect(find.text(ok), findsNothing);
    });
  }
}
