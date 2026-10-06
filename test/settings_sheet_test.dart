// The sample's settings sheet is where the theme is chosen, so it changes
// with it while it is open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/theme/theme.dart';

import 'fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('picking dark in the open sheet turns the sheet dark too, not '
      'only what is on it', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final Session session = Session(thinking: Duration.zero);
    addTearDown(session.dispose);
    await tester.pumpWidget(QuincenaApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();

    Color sheet() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;
    final Color light = quincenaTheme(Brightness.light).colorScheme.surface;
    final Color dark = quincenaTheme(Brightness.dark).colorScheme.surface;
    expect(sheet(), light);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(sheet(), dark);
  });
}
