// Plays the tour of tour.dart on a simulator or phone, and asks the Mac for
// a picture of the screen at every stop: tool/tour/run.sh watches for the
// file this leaves, takes the simulator's own screenshot, status bar and
// all, and deletes the file to say it is done.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'tour.dart';

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

  for (final Scene scene in scenes) {
    testWidgets(scene.name, (tester) async {
      await playScene(tester, scene, (String name) async {
        final File ask = File('${asks.path}/$name.ready');
        await ask.writeAsString(name);
        final Stopwatch watch = Stopwatch()..start();
        while (ask.existsSync() &&
            watch.elapsed < const Duration(seconds: 20)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
    });
  }
}
