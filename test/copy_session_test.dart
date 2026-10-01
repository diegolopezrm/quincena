import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/scripted_agent.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';

import 'fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('a copied session leaves out what the person typed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();

    final Future<void> answered = session.ask(ScriptedAgent.starters[4]);
    await tester.pumpAndSettle();
    await answered;

    // The note is the field the person types freely into.
    await tester.enterText(find.byType(TextField).at(1), 'Regalo para mamá');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo desarrollador'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copiar la sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar la sesión'));
    await tester.pumpAndSettle();

    expect(copied, isNotNull);
    expect(copied, contains('"draft"'));
    expect(copied, isNot(contains('Regalo para mamá')));
    expect(copied, contains('[redacted]'));
  });
}
