// Phase 33: Ajustes in the order a person looks for things, each section
// under its title, the theme and the language each under their own, the
// rules learned as a row of their own and «Borrar todo» apart at the end.
// What goes wrong says what is missing, with a way to fix it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/ui/own/capture_rules_page.dart';
import 'package:quincena/ui/own/look.dart';
import 'package:quincena/ui/own/own_settings_page.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  Widget settingsOf(OwnController own) => OwnSettingsPage(
    own: own,
    modes: AppModeController(store: own.store, now: () => pageNow),
    settings: AppSettings(),
  );

  testWidgets('Ajustes goes from the profile to deleting everything, one '
      'section after another', (tester) async {
    await openPage(tester, settingsOf);
    // Tall enough for the list to build every row at once.
    tester.view.physicalSize = const Size(1170, 15000);
    await settle(tester);

    const List<String> order = <String>[
      'TU PERFIL',
      'Nombre',
      'Moneda de los totales',
      'Cómo te pagan',
      'Lo que te pagan',
      'Colchón',
      'AUTOMATIZACIÓN',
      'Captura automática',
      'Reglas aprendidas',
      'Avisarme el día de pago',
      'CUENTAS CONECTADAS',
      'Binance',
      'Billeteras propias',
      'APARIENCIA',
      'Tema',
      'Idioma',
      'Widget de inicio',
      'Ocultar montos en el widget',
      'Agregar a la pantalla de inicio',
      'TUS DATOS',
      'Importar extracto',
      'Varios dispositivos',
      'Exportar mis datos',
      'Exportar movimientos en CSV',
      'Restaurar un respaldo',
      'Ver los datos de ejemplo',
      'AYUDA Y PRIVACIDAD',
      'Soporte',
      'Política de privacidad',
      'Licencias y créditos',
      'Borrar todo',
    ];
    final List<double> tops = <double>[
      for (final String text in order) tester.getTopLeft(find.text(text)).dy,
    ];
    for (var i = 1; i < order.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: order[i]);
    }
    // The old titles are gone: no capture section holding the wallets, no
    // section of reminders or of privacy alone.
    for (final String gone in <String>[
      'PERFIL',
      'AVISOS',
      'CAPTURA AUTOMÁTICA',
      'WIDGET DE INICIO',
      'PRIVACIDAD',
      'Importar un archivo',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }

    // Each row of choices under its own title: the two «Sistema» read
    // apart.
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      top(find.text('Tema')),
      lessThan(top(find.byType(SegmentedButton<ThemeMode>))),
    );
    expect(
      top(find.byType(SegmentedButton<ThemeMode>)),
      lessThan(top(find.text('Idioma'))),
    );
    expect(
      top(find.text('Idioma')),
      lessThan(top(find.byType(SegmentedButton<String>))),
    );

    // «Borrar todo» is alone in its panel, under no title.
    final Finder deleting = find.ancestor(
      of: find.text('Borrar todo'),
      matching: find.byType(Panel),
    );
    expect(
      find.descendant(of: deleting, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      top(find.text('Borrar todo')) - top(find.text('Licencias y créditos')),
      lessThan(120),
    );

    // Restoring says what it does, and the rules say how many there are.
    expect(
      find.text('Reemplaza todo lo de ahora por lo del respaldo'),
      findsOneWidget,
    );
    expect(find.text('Ninguna todavía'), findsOneWidget);
  });

  testWidgets('the rules learned open from their own row', (tester) async {
    await openPage(tester, settingsOf);
    await tapText(tester, 'Reglas aprendidas');
    expect(find.byType(CaptureRulesPage), findsOneWidget);
  });

  testWidgets('a blank name is not saved, and the dialog says why until it '
      'is written', (tester) async {
    final OwnController own = await openPage(tester, settingsOf);
    await tapText(tester, 'Nombre');
    await tester.enterText(find.byType(TextField), '  ');
    await tapText(tester, 'Guardar');
    expect(find.text('Escribe tu nombre.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(own.profile!.name, 'Ana');

    await tester.enterText(find.byType(TextField), 'Ana María');
    await tester.pump();
    expect(find.text('Escribe tu nombre.'), findsNothing);
    await tapText(tester, 'Guardar');
    expect(find.byType(AlertDialog), findsNothing);
    expect(own.profile!.name, 'Ana María');
  });

  testWidgets('a reminder the phone turns down offers its settings', (
    tester,
  ) async {
    await openPage(tester, settingsOf);
    final List<MethodCall> capture = <MethodCall>[];
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    // The phone says no to notifications.
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.dlsoft.quincena/reminders'),
      (MethodCall call) async => call.method == 'ask' ? false : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.dlsoft.quincena/capture'),
      (MethodCall call) async {
        capture.add(call);
        return null;
      },
    );
    addTearDown(() {
      for (final String channel in <String>[
        'dev.dlsoft.quincena/reminders',
        'dev.dlsoft.quincena/capture',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channel), null);
      }
    });

    await tapText(tester, 'Avisarme el día de pago');
    expect(
      find.textContaining('permite las notificaciones de Quincena'),
      findsOneWidget,
    );
    // On Android, the same page the location sends the person to.
    await tester.tap(find.text('Abrir ajustes'));
    await settle(tester);
    expect(capture.map((MethodCall c) => c.method), <String>[
      'openAppSettings',
    ]);
  });
}
