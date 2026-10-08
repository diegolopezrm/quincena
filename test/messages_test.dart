import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/ui/home_page.dart';

import 'fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  Future<ScaffoldMessengerState> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final Session session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    return ScaffoldMessenger.of(tester.element(find.byType(HomePage)));
  }

  testWidgets('a message about what was just done takes the place of the '
      'one before', (tester) async {
    final ScaffoldMessengerState messenger = await open(tester);
    messenger.showSnackBar(const SnackBar(content: Text('Código copiado.')));
    await tester.pumpAndSettle();
    expect(find.text('Código copiado.'), findsOneWidget);

    // Saved a moment later: what shows is that it was saved.
    messenger.showSnackBar(const SnackBar(content: Text('Archivo guardado.')));
    await tester.pumpAndSettle();
    expect(find.text('Archivo guardado.'), findsOneWidget);
    expect(find.text('Código copiado.'), findsNothing);

    // Two more in a row: only the last one shows, and nothing older comes
    // back after it.
    messenger
      ..showSnackBar(const SnackBar(content: Text('Listo: un cambio.')))
      ..showSnackBar(const SnackBar(content: Text('Ya estaba todo al día.')));
    await tester.pumpAndSettle();
    expect(find.text('Ya estaba todo al día.'), findsOneWidget);
    expect(find.text('Listo: un cambio.'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
