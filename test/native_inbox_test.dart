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

  test('reads the lines the App Intent and the listener write', () async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'quincena-capture',
    );
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/$captureFileName').writeAsString(
      // RecordMovementIntent.swift: sorted keys, the time in UTC.
      '{"accuracy":35,"amount":"\$45.900,00","at":"2026-10-01T18:45:12Z","card":"Bancolombia Visa","lat":6.2446,"lng":-75.5905,"merchant":"Éxito Laureles","source":"wallet"}\n'
      '{"at":"2026-10-01T18:46:00Z","sender":"85784","source":"sms","text":"Bancolombia le informa Compra por \$45.900,00 en EXITO LAURELES"}\n'
      // CaptureListener.kt: the title and the body apart, the app's name.
      '{"source":"notification","at":"2026-10-01T18:45:13.120Z","app":"com.todo1.mobile","appName":"Bancolombia","title":"Bancolombia","body":"Compraste \$45.900,00 en EXITO LAURELES con tu T.Deb *1234","lat":6.2445,"lng":-75.5905,"accuracy":12.5}\n',
    );
    final List<CaptureEvent> events = await takeNativeEvents(directory: dir);
    expect(events.map((CaptureEvent e) => e.source), <CaptureSource>[
      CaptureSource.wallet,
      CaptureSource.sms,
      CaptureSource.notification,
    ]);
    expect(events[0].at, DateTime.utc(2026, 10, 1, 18, 45, 12).toLocal());
    expect(events[0].accuracy, 35);
    expect(events[0].text, r'Éxito Laureles · $45.900,00 · Bancolombia Visa');
    expect(events[1].sender, '85784');
    expect(events[2].appName, 'Bancolombia');
    expect(
      events[2].text,
      r'Bancolombia · Compraste $45.900,00 en EXITO LAURELES con tu T.Deb *1234',
    );
  });
}
