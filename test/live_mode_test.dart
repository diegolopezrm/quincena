import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/theme/tokens.dart';

import 'fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  testWidgets('the badge says LIVE whenever a model answers, key or not', (
    tester,
  ) async {
    phone(tester);
    final session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('DEMO'), findsOneWidget);

    // Gemini through Quincena, with no key: nothing is asked yet.
    session.use(AgentMode.gemini);
    await tester.pumpAndSettle();
    expect(find.text('EN VIVO'), findsOneWidget);
    expect(find.text('DEMO'), findsNothing);

    session.use(AgentMode.live, apiKey: 'una-key-de-prueba');
    await tester.pumpAndSettle();
    expect(find.text('EN VIVO'), findsOneWidget);

    session.use(AgentMode.demo);
    await tester.pumpAndSettle();
    expect(find.text('DEMO'), findsOneWidget);
  });

  testWidgets('a key that is in use can be replaced in Settings', (
    tester,
  ) async {
    phone(tester);
    final session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    final Finder key = find.widgetWithText(TextField, 'Key de Gemini');

    Future<void> connect(String value) async {
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tu key'));
      await tester.pumpAndSettle();
      // Where "La key no funcionó. Revísala en Ajustes." sends the person.
      expect(key, findsOneWidget);
      await tester.enterText(key, value);
      await tester.tap(find.text('Conectar'));
      await tester.pumpAndSettle();
    }

    await connect('una-key-de-prueba');
    expect(session.mode, AgentMode.live);
    await connect('otra-key-de-prueba');
    expect(session.mode, AgentMode.live);
    expect(find.text('EN VIVO'), findsOneWidget);
  });

  testWidgets('Settings turns dark or light with the appearance picked in it', (
    tester,
  ) async {
    phone(tester);
    final session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    Color? sheet() =>
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor;

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(sheet(), QuincenaColors.light.surface);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(sheet(), QuincenaColors.dark.surface);
  });
}
