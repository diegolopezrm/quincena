// Starting without learning Quincena: with no account, Inicio leads to the
// first one instead of showing $0.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/messages.dart';
import 'package:quincena/ui/own/own_shell.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('with no account, Inicio leads to the first one, and with it '
      'shows the figure', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => pageNow,
    );
    addTearDown(() => tester.runAsync(store.close));
    final OwnController own = OwnController(
      store,
      now: () => pageNow,
      readNative: false,
    );
    addTearDown(own.dispose);
    final AppModeController modes = AppModeController(
      store: store,
      now: () => pageNow,
    );
    addTearDown(modes.dispose);
    await tester.runAsync(() async {
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await own.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        builder: (BuildContext context, Widget? child) =>
            LatestMessenger(child: child!),
        home: OwnShell(own: own, modes: modes, settings: AppSettings()),
      ),
    );
    await settle(tester);

    expect(find.text('Agrega dónde tienes tu plata'), findsOneWidget);
    expect(find.text('Puedes gastar'), findsNothing);
    expect(find.text('Próximos días'), findsNothing);
    // Fixed payments wait for an account to pay them from.
    expect(find.text('Agrega tus pagos fijos'), findsNothing);
    // «Tus cuentas» is not an empty title: it has its way to add one.
    expect(find.text('Agregar cuenta'), findsOneWidget);
    expect(
      find.text(
        'Con una cuenta, aquí registras lo que gastas y lo que te entra.',
      ),
      findsOneWidget,
    );

    await tapText(tester, 'Agregar mi primera cuenta');
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Nequi');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuánto tiene hoy?'),
      '150000',
    );
    await tapText(tester, 'Guardar');
    expect(find.text('Puedes gastar'), findsOneWidget);
    expect(find.text('Agrega dónde tienes tu plata'), findsNothing);
    expect(own.accounts.single.name, 'Nequi');
  });
}
