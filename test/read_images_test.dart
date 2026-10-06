// Reading screenshots says what it found as soon as it has, even right
// after another reading whose answer is still on screen.
// The picker hands over files as cross_file's, and its fake must too.
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/ui/own/read_images.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('a second reading right after the first says what it found '
      'at once, not a minute later', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final FilePickerPlatform picker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _Picker();
    addTearDown(() => FilePickerPlatform.instance = picker);
    final List<String> texts = <String>[
      r'Bancolombia le informa Compra por $45.900 en RAPPI. 03/10/2026 09:30',
      'Foto del perro',
    ];
    const MethodChannel capture = MethodChannel('dev.dlsoft.quincena/capture');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      capture,
      (MethodCall call) async =>
          call.method == 'readText' ? texts.removeAt(0) : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        capture,
        null,
      ),
    );
    try {
      await openPage(
        tester,
        (OwnController own) => Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => readImages(context, own),
              child: const Text('Leer'),
            ),
          ),
        ),
      );
      Future<void> read() async {
        await tester.tap(find.text('Leer'));
        await settle(tester);
        await tester.tap(find.text('Capturas o fotos'));
        await settle(tester);
      }

      await read();
      expect(find.text('Leí un pago. Quedó en Por revisar.'), findsOneWidget);
      await read();
      expect(find.text('Leyendo…'), findsNothing);
      expect(
        find.textContaining('No encontré un monto con su moneda'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _Picker extends FilePickerPlatform {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => <PlatformFile>[_Picked()];
}

final class _Picked extends PlatformFile {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);

  @override
  String get name => 'captura.png';

  @override
  Uri get uri => Uri.file('/captura.png');

  @override
  XFile get xFile => XFile.fromData(bytes, name: name);

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(bytes);
}
