// Phase 33: a code is copied or shared, never only read off the screen, and
// pasted where it is asked for; typing it stays as the last resort. Of the
// person's two codes, the one this device knows is named when it is typed
// in the other's place.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/sync/vault.dart';
import 'package:quincena/ui/messages.dart';
import 'package:quincena/ui/own/code_dialogs.dart';

import 'own_flow_test.dart' show settle;

const MethodChannel _share = MethodChannel('dev.dlsoft.quincena/share');

void main() {
  final String code = VaultKey.generate(Random(11)).code;

  /// A page with one button that runs [open], with the phone's clipboard in
  /// [clipboard] and what reaches the share sheet in [shared], which opens
  /// when [sheet].
  Future<void> openWith(
    WidgetTester tester,
    void Function(BuildContext context) open, {
    required Map<String, String?> clipboard,
    List<String>? shared,
    bool sheet = true,
  }) async {
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        clipboard['text'] =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      if (call.method == 'Clipboard.getData') {
        final String? text = clipboard['text'];
        return text == null ? null : <String, Object?>{'text': text};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(_share, (MethodCall call) async {
      shared?.add('${call.arguments}');
      return sheet;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(_share, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        builder: (BuildContext context, Widget? child) =>
            LatestMessenger(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => open(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await settle(tester);
  }

  group('a code shown', () {
    void show(BuildContext context) => showCode(
      context,
      code: code,
      title: 'Tu código para sincronizar',
      keep: 'Guárdalo.',
      share: 'Código de Quincena para unir tus dispositivos: $code',
    );

    testWidgets('is shared with a line that says which code it is, and the '
        'dialog stays', (tester) async {
      final List<String> shared = <String>[];
      final Map<String, String?> clipboard = <String, String?>{};
      await openWith(tester, show, clipboard: clipboard, shared: shared);
      await tester.tap(find.text('Compartir el código'));
      await settle(tester);
      expect(shared, <String>[
        'Código de Quincena para unir tus dispositivos: $code',
      ]);
      expect(find.text('Tu código para sincronizar'), findsOneWidget);
      expect(clipboard['text'], isNull);

      await tester.tap(find.text('Copiar el código'));
      await settle(tester);
      expect(clipboard['text'], code);
      expect(find.text('Tu código para sincronizar'), findsNothing);
      expect(find.text('Código copiado.'), findsOneWidget);
    });

    testWidgets('with no share sheet, as on the web, it is copied and said', (
      tester,
    ) async {
      final Map<String, String?> clipboard = <String, String?>{};
      await openWith(tester, show, clipboard: clipboard, sheet: false);
      await tester.tap(find.text('Compartir el código'));
      await settle(tester);
      expect(
        clipboard['text'],
        'Código de Quincena para unir tus dispositivos: $code',
      );
      expect(find.text('Tu código para sincronizar'), findsNothing);
      expect(find.text('Código copiado.'), findsOneWidget);
    });
  });

  group('a code asked for', () {
    late List<String> used;
    void ask(BuildContext context) => askForCode(
      context,
      title: 'Unir este dispositivo',
      body: 'Pega el código.',
      action: 'Unir',
      use: (String typed) async {
        used.add(typed);
        VaultKey.fromCode(typed);
        return null;
      },
    );

    setUp(() => used = <String>[]);

    testWidgets('is pasted alone, out of the words it was shared with', (
      tester,
    ) async {
      final Map<String, String?> clipboard = <String, String?>{};
      await openWith(tester, ask, clipboard: clipboard);
      expect(find.text('Pegar'), findsOneWidget);

      // Nothing copied: it says so, and typing takes the notice away.
      await tester.tap(find.text('Pegar'));
      await settle(tester);
      expect(find.textContaining('No hay nada copiado'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      expect(find.textContaining('No hay nada copiado'), findsNothing);

      clipboard['text'] =
          'Código de Quincena para unir tus dispositivos: $code\n';
      await tester.tap(find.text('Pegar'));
      await settle(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        code,
      );
      await tester.tap(find.text('Unir'));
      await settle(tester);
      expect(used, <String>[code]);
      expect(find.text('Unir este dispositivo'), findsNothing);
    });

    testWidgets('typed by hand it still works, and what is wrong is said', (
      tester,
    ) async {
      await openWith(tester, ask, clipboard: <String, String?>{});
      await tester.enterText(find.byType(TextField), 'ABCD-EFGH');
      await tester.tap(find.text('Unir'));
      await settle(tester);
      expect(
        find.text('Al código le sobran o le faltan caracteres: son 54.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextField),
        code.toLowerCase().replaceAll('-', ' '),
      );
      await tester.tap(find.text('Unir'));
      await settle(tester);
      expect(used.last, code.toLowerCase().replaceAll('-', ' '));
      expect(find.text('Unir este dispositivo'), findsNothing);
    });
  });

  group('the code in a text', () {
    test('is found with words around it, in any case, grouped or not', () {
      expect(VaultKey.codeIn('Código de respaldo de Quincena: $code'), code);
      expect(VaultKey.codeIn('$code.'), code);
      final String lower = code.toLowerCase().replaceAll('-', ' ');
      expect(VaultKey.codeIn('mi código: $lower'), lower);
      final String bare = code.replaceAll('-', '');
      expect(VaultKey.codeIn(bare), bare);
      expect(VaultKey.fromCode(VaultKey.codeIn(bare)!).code, code);
    });

    test('is not found where there is none, or one cut short', () {
      expect(VaultKey.codeIn(''), isNull);
      expect(VaultKey.codeIn('Hola, ¿nos vemos a las 5?'), isNull);
      expect(VaultKey.codeIn(code.substring(0, code.length - 1)), isNull);
      // Part of a longer run of letters and digits is not a code.
      expect(VaultKey.codeIn('X${code.replaceAll('-', '')}'), isNull);
    });
  });

  group('which code it is', () {
    test('is told only by the key this device keeps', () async {
      final VaultKey key = VaultKey.fromCode(code);
      expect(await codeIsKey(code, () async => key.bytes), isTrue);
      expect(
        await codeIsKey(code.toLowerCase(), () async => key.bytes),
        isTrue,
      );
      expect(
        await codeIsKey(
          VaultKey.generate(Random(12)).code,
          () async => key.bytes,
        ),
        isFalse,
      );
      expect(await codeIsKey(code, () async => null), isFalse);
      expect(await codeIsKey('ABCD', () async => key.bytes), isFalse);
      expect(
        await codeIsKey(code, () => throw PlatformException(code: 'none')),
        isFalse,
      );
    });
  });
}
