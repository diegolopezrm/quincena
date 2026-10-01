import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/native_inbox_io.dart';

void main() {
  test('takes what the native side wrote, once, and skips broken lines', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'quincena-capture',
    );
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/$captureFileName').writeAsString(
      '${jsonEncode(<String, Object>{'source': 'wallet', 'at': '2026-10-01T13:45:00-05:00', 'merchant': 'Éxito', 'amount': r'$45.900', 'card': 'Visa'})}\n'
      'not json\n'
      '\n'
      '${jsonEncode(<String, Object>{'source': 'notification', 'app': 'com.nequi.MobileApp', 'title': 'Nequi', 'body': r'Pagaste $23.500 en CREPES', 'lat': 6.2445, 'lng': -75.5905})}\n',
    );
    final List<CaptureEvent> events = await takeNativeEvents(directory: dir);
    expect(events, hasLength(2));
    expect(events.first.source, CaptureSource.wallet);
    expect(events.last.text, contains('Pagaste'));
    expect(events.last.hasLocation, isTrue);
    expect(await takeNativeEvents(directory: dir), isEmpty);
  });
}
