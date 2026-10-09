// Plays the flows of flows/flows.dart on a simulator or phone, and asks the
// Mac for a picture of the screen at every step: tool/flows/run.sh watches
// for the file this leaves, takes the simulator's own screenshot, keeps the
// line written in the file beside it, and deletes the file to say it is
// done. At the end of each flow, what its checks found goes in a file of
// its own for the Mac to collect.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'flows/flow.dart';
import 'flows/flows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory asks;

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
    asks = Directory('${(await getApplicationDocumentsDirectory()).path}/tour')
      ..createSync(recursive: true);
  });

  for (final AppFlow flow in flows) {
    testWidgets('flow ${flow.id}', (tester) async {
      // A keychain of its own for every flow, as without a phone: the
      // phone's would keep the sync and backup keys one flow left behind.
      final Map<String, String> keychain = <String, String>{};
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _keychain,
        (MethodCall call) async {
          final Map<Object?, Object?> args =
              (call.arguments as Map<Object?, Object?>?) ?? const {};
          final String? key = args['key'] as String?;
          return switch (call.method) {
            'read' => keychain[key],
            'write' => keychain[key!] = args['value']! as String,
            'delete' => keychain.remove(key),
            'containsKey' => keychain.containsKey(key),
            'readAll' => keychain,
            'deleteAll' => keychain.clear(),
            _ => null,
          };
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _keychain,
          null,
        ),
      );
      final FlowRun run = await playFlow(tester, flow, (
        String name,
        String caption,
      ) async {
        final File ask = File('${asks.path}/$name.ready');
        await ask.writeAsString(caption);
        final Stopwatch watch = Stopwatch()..start();
        while (ask.existsSync() &&
            watch.elapsed < const Duration(seconds: 20)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      File(
        '${asks.path}/${flow.id}.result.json',
      ).writeAsStringSync(jsonEncode(run.toJson()));
      expect(run.error, isNull, reason: 'the flow broke on the way');
    });
  }
}

const MethodChannel _keychain = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
