import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/conversation.dart';

import 'fonts.dart';
import 'gemini_test.dart' show OverviewFirstModel;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('an answer says what was worked out on the phone for it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final Session session = Session(
      mode: AgentMode.gemini,
      clientFor: OverviewFirstModel.new,
      errorWindow: Duration.zero,
    );
    addTearDown(session.dispose);
    var explained = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: session,
              builder: (BuildContext context, _) => Conversation(
                session: session,
                onExplainFree: () => explained++,
              ),
            ),
          ),
        ),
      ),
    );
    final Future<void> asked = session.ask('¿Cuánto me queda libre?');
    await tester.pumpAndSettle();
    await asked;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calculado en tu teléfono'));
    await tester.pumpAndSettle();
    expect(find.text('Cómo se calculó'), findsOneWidget);
    expect(
      find.text(
        'Tus saldos, lo comprometido, el colchón y lo que puedes gastar '
        'hasta el pago',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Gemini solo los explica'), findsOneWidget);

    await tester.tap(find.text('Ver cómo se calcula lo que puedes gastar'));
    await tester.pumpAndSettle();
    expect(explained, 1);
    expect(tester.takeException(), isNull);
  });
}
