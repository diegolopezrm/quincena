// "Borrar todo" leaves nothing of the person on the phone: not the data,
// not the reminders the phone keeps, which name their payments, not the
// keys in the keychain, and not the look they chose, which went with the
// rest.
import 'dart:convert';
import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/app.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/vault.dart';
import 'package:quincena/ui/own/own_settings_page.dart';

import 'own_flow_test.dart' show fakeRates, settle;
import 'page_harness.dart';

const MethodChannel _reminders = MethodChannel('dev.dlsoft.quincena/reminders');
const MethodChannel _keychain = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  tearDown(() {
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });

  testWidgets('it cancels the reminders, forgets the Binance key and goes '
      'back to the phone\'s look', (tester) async {
    final List<String> reminders = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_reminders, (
      MethodCall call,
    ) async {
      reminders.add(call.method);
      return call.method == 'ask' ? true : null;
    });
    final Map<String, String> keychain = <String, String>{
      'binance.key': 'llave',
      'binance.secret': 'secreto',
    };
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_keychain, (
      MethodCall call,
    ) async {
      final Map<Object?, Object?> args =
          (call.arguments as Map<Object?, Object?>?) ?? const {};
      final String? key = args['key'] as String?;
      return switch (call.method) {
        'read' => keychain[key],
        'write' => keychain[key!] = args['value']! as String,
        'delete' => keychain.remove(key),
        'containsKey' => keychain.containsKey(key),
        _ => null,
      };
    });
    addTearDown(() {
      for (final MethodChannel c in <MethodChannel>[_reminders, _keychain]) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(c, null);
      }
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final QuincenaStore store = (await tester.runAsync(() async {
      final QuincenaStore store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => now,
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await store.setSetting('app.mode', 'own');
      await store.setSetting('app.theme', 'dark');
      // The app in English on a phone in Spanish.
      await store.setSetting('app.language', 'en');
      await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: Decimal.parse('900000'),
      );
      return store;
    }))!;
    addTearDown(() => tester.runAsync(store.close));
    await tester.pumpWidget(
      QuincenaApp(
        store: store,
        startInDemo: false,
        fetcher: fakeRates(),
        now: () => now,
      ),
    );
    await settle(tester);
    ThemeMode theme() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(theme(), ThemeMode.dark);
    Locale? language() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale;
    expect(language(), const Locale('en'));

    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    // The payday reminder on: the phone keeps reminders that name nothing
    // but are the person's.
    await tester.ensureVisible(find.text('Remind me on payday'));
    await tester.tap(find.text('Remind me on payday'));
    await settle(tester);
    expect(reminders.last, 'schedule');

    await tester.scrollUntilVisible(
      find.text('Delete everything'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Delete everything'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await settle(tester);
    await tester.tap(find.text('Delete everything').last);
    await settle(tester);

    // At once, in the phone's language: nothing waits for the next launch.
    expect(find.text('¿Cómo quieres empezar?'), findsOneWidget);
    expect(language(), isNull);
    expect(await tester.runAsync(() => store.setting('app.language')), isNull);
    expect(tester.takeException(), isNull);
    expect(reminders.last, 'cancel');
    expect(keychain.keys, isNot(contains('binance.key')));
    expect(keychain.keys, isNot(contains('binance.secret')));
    expect(theme(), ThemeMode.system);
    expect(await tester.runAsync(() => store.setting('app.theme')), isNull);
  });

  testWidgets('before it deletes, it says what brings the data back, shows '
      'the backup code it is about to forget and can save a backup first', (
    tester,
  ) async {
    final VaultKey key = VaultKey.generate(Random(5));
    final Map<String, String> keychain = <String, String>{
      'quincena.backup.key': base64Encode(key.bytes),
    };
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_keychain, (
      MethodCall call,
    ) async {
      final Map<Object?, Object?> args =
          (call.arguments as Map<Object?, Object?>?) ?? const {};
      final String? name = args['key'] as String?;
      return switch (call.method) {
        'read' => keychain[name],
        'write' => keychain[name!] = args['value']! as String,
        'delete' => keychain.remove(name),
        'containsKey' => keychain.containsKey(name),
        _ => null,
      };
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _keychain,
        null,
      ),
    );
    final List<String> saved = <String>[];
    final FilePickerPlatform picker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _Saver(saved);
    addTearDown(() => FilePickerPlatform.instance = picker);
    final OwnController own = await openPage(
      tester,
      (OwnController own) => OwnSettingsPage(
        own: own,
        modes: AppModeController(store: own.store, now: () => pageNow),
        settings: AppSettings(),
      ),
    );

    await tapText(tester, 'Borrar todo');
    expect(find.text('¿Borrar todos tus datos?'), findsOneWidget);
    expect(
      find.textContaining('un respaldo guardado fuera de este teléfono'),
      findsOneWidget,
    );
    expect(find.textContaining('olvida tu código de respaldo'), findsOneWidget);
    await tapText(tester, 'Ver mi código de respaldo');
    for (final String group in key.code.split('-')) {
      expect(find.text(group), findsWidgets);
    }
    await tapText(tester, 'Listo');
    expect(find.text('¿Borrar todos tus datos?'), findsOneWidget);

    // A backup first, through the same export, and the question again.
    await tapText(tester, 'Guardar un respaldo primero');
    await tapText(tester, 'Exportar');
    expect(saved, <String>['quincena-2026-10-03.qbackup']);
    expect(find.text('¿Borrar todos tus datos?'), findsOneWidget);
    await tapText(tester, 'Cancelar');
    expect(find.text('¿Borrar todos tus datos?'), findsNothing);
    expect(await tester.runAsync(own.store.profile), isNotNull);
    expect(keychain.keys, contains('quincena.backup.key'));
  });
}

/// The system's save dialog, saving whatever it is handed.
class _Saver extends FilePickerPlatform {
  _Saver(this.saved);

  final List<String> saved;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saved.add(fileName);
    return Uri.file('/Archivos/$fileName');
  }
}
