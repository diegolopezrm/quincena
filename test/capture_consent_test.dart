// Before Quincena asks the phone for the location or for reading
// notifications, it says in the app what it uses, when and where it goes,
// and only «Aceptar» goes on to the phone's request. «Ahora no», going back
// and a tap outside never ask for anything.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/ui/own/capture_settings_page.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

/// Android, as the capture channel answers it: what the app may use, what
/// it answers when asked, and every request the app made of it.
class _FakePhone {
  _FakePhone(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      _answer,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
  }

  static const MethodChannel _channel = MethodChannel(
    'dev.dlsoft.quincena/capture',
  );

  final WidgetTester tester;

  /// 'none', 'foreground' or 'always'.
  String location = 'none';
  String locationAnswer = 'foreground';
  String alwaysAnswer = 'always';

  /// What the app asked of Android, in order: only what shows the person
  /// a system prompt or screen, not the questions about what it may use.
  final List<String> requests = <String>[];

  Future<Object?> _answer(MethodCall call) async {
    switch (call.method) {
      case 'notificationAccess':
        return false;
      case 'locationAccess':
        return location;
      case 'askForLocation':
        requests.add(call.method);
        return location = locationAnswer;
      case 'askForBackgroundLocation':
        requests.add(call.method);
        return location = alwaysAnswer;
      case 'openNotificationAccess' || 'openAppSettings':
        requests.add(call.method);
    }
    return null;
  }
}

const String _switch = 'Usar la ubicación del pago';
const String _locationTitle = 'Ubicación de tus pagos';
const String _alwaysTitle = 'Ubicación con la app cerrada';
const String _notificationsTitle = 'Leer tus notificaciones de pagos';

Finder get _locationSwitch => find.widgetWithText(SwitchListTile, _switch);

bool _on(WidgetTester tester) =>
    tester.widget<SwitchListTile>(_locationSwitch).value;

Future<OwnController> _open(WidgetTester tester) =>
    openPage(tester, (OwnController own) => CaptureSettingsPage(own: own));

Future<CaptureSettings> _saved(WidgetTester tester, OwnController own) async =>
    (await tester.runAsync(() => own.store.captureSettings()))!;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder.last);
  await settle(tester);
}

/// The phone's back button, as Android sends it.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  await settle(tester);
}

/// A tap on the dimmed screen around the dialog.
Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(8, 8));
  await settle(tester);
}

/// Runs [body] as on [platform], putting it back after.
Future<void> _as(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  group('the location', () {
    testWidgets('turning it on says what it uses, when and where it goes '
        'before Android asks for anything', (WidgetTester tester) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester);
        await _open(tester);
        await _tap(tester, _locationSwitch);
        expect(find.text(_locationTitle), findsOneWidget);
        expect(
          find.text(
            'Quincena recoge datos de ubicación para sugerir el comercio de '
            'un pago, incluso cuando la app está cerrada o no se usa.',
          ),
          findsOneWidget,
        );
        expect(find.text('Qué usa'), findsOneWidget);
        expect(find.text('La ubicación precisa del teléfono.'), findsOneWidget);
        expect(find.text('Cuándo'), findsOneWidget);
        expect(find.text('Dónde queda'), findsOneWidget);
        expect(
          find.text(
            'En este teléfono. Para encontrar el comercio, solo las '
            'coordenadas van a OpenStreetMap a través de Photon: nada más, y a '
            'nadie más.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Si aceptas, Android te pedirá permiso para usar la ubicación.',
          ),
          findsOneWidget,
        );
        expect(find.text('Aceptar'), findsOneWidget);
        expect(find.text('Ahora no'), findsOneWidget);
        expect(phone.requests, isEmpty);
        expect(_on(tester), isFalse);
      });
    });

    testWidgets('«Ahora no» asks for nothing and leaves it off', (
      WidgetTester tester,
    ) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester);
        final OwnController own = await _open(tester);
        await _tap(tester, _locationSwitch);
        await _tap(tester, find.text('Ahora no'));
        expect(find.text(_locationTitle), findsNothing);
        expect(phone.requests, isEmpty);
        expect(_on(tester), isFalse);
        expect((await _saved(tester, own)).useLocation, isFalse);
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    testWidgets('a tap outside does nothing and going back is a no', (
      WidgetTester tester,
    ) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester);
        final OwnController own = await _open(tester);
        await _tap(tester, _locationSwitch);
        await _tapOutside(tester);
        expect(find.text(_locationTitle), findsOneWidget);
        expect(phone.requests, isEmpty);
        await _systemBack(tester);
        expect(find.text(_locationTitle), findsNothing);
        expect(find.byType(CaptureSettingsPage), findsOneWidget);
        expect(phone.requests, isEmpty);
        expect(_on(tester), isFalse);
        expect((await _saved(tester, own)).useLocation, isFalse);
      });
    });

    testWidgets('«Aceptar» asks for it right away, then explains all the '
        'time before Android asks for that', (WidgetTester tester) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester);
        final OwnController own = await _open(tester);
        await _tap(tester, _locationSwitch);
        await _tap(tester, find.text('Aceptar'));
        expect(phone.requests, <String>['askForLocation']);
        expect(find.text(_alwaysTitle), findsOneWidget);
        expect(
          find.textContaining('incluso cuando la app está cerrada o no se usa'),
          findsOneWidget,
        );
        expect(
          find.textContaining('«Permitir todo el tiempo»'),
          findsOneWidget,
        );
        await _tapOutside(tester);
        expect(find.text(_alwaysTitle), findsOneWidget);
        expect(phone.requests, <String>['askForLocation']);
        await _tap(tester, find.text('Aceptar'));
        expect(phone.requests, <String>[
          'askForLocation',
          'askForBackgroundLocation',
        ]);
        expect(_on(tester), isTrue);
        expect((await _saved(tester, own)).useLocation, isTrue);
        expect(find.text('Permitir todo el tiempo'), findsNothing);
      });
    });

    testWidgets('already allowed, it still explains first and Android asks '
        'only for all the time', (WidgetTester tester) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester)..location = 'foreground';
        await _open(tester);
        await _tap(tester, _locationSwitch);
        expect(find.text(_locationTitle), findsOneWidget);
        expect(phone.requests, isEmpty);
        await _tap(tester, find.text('Aceptar'));
        expect(find.text(_alwaysTitle), findsOneWidget);
        expect(phone.requests, isEmpty);
        await _tap(tester, find.text('Aceptar'));
        expect(phone.requests, <String>['askForBackgroundLocation']);
      });
    });

    testWidgets('«Permitir todo el tiempo» explains before Android asks, and '
        'a no there asks for nothing', (WidgetTester tester) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester);
        final OwnController own = await _open(tester);
        await _tap(tester, _locationSwitch);
        await _tap(tester, find.text('Aceptar'));
        await _tap(tester, find.text('Ahora no'));
        // On with the app open only.
        expect(phone.requests, <String>['askForLocation']);
        expect(_on(tester), isTrue);
        expect((await _saved(tester, own)).useLocation, isTrue);

        await _tap(tester, find.text('Permitir todo el tiempo'));
        expect(find.text(_alwaysTitle), findsOneWidget);
        expect(phone.requests, <String>['askForLocation']);
        await _systemBack(tester);
        expect(find.text(_alwaysTitle), findsNothing);
        expect(phone.requests, <String>['askForLocation']);
        await _tap(tester, find.text('Permitir todo el tiempo'));
        await _tap(tester, find.text('Ahora no'));
        expect(phone.requests, <String>['askForLocation']);
        expect(find.text('Permitir todo el tiempo'), findsOneWidget);

        await _tap(tester, find.text('Permitir todo el tiempo'));
        await _tap(tester, find.text('Aceptar'));
        expect(phone.requests, <String>[
          'askForLocation',
          'askForBackgroundLocation',
        ]);
        expect(find.text('Permitir todo el tiempo'), findsNothing);
      });
    });

    testWidgets('with Android saying no, it stays off and offers the '
        'settings', (WidgetTester tester) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester)..locationAnswer = 'none';
        final OwnController own = await _open(tester);
        await _tap(tester, _locationSwitch);
        await _tap(tester, find.text('Aceptar'));
        expect(phone.requests, <String>['askForLocation']);
        expect(find.text(_alwaysTitle), findsNothing);
        expect(_on(tester), isFalse);
        expect((await _saved(tester, own)).useLocation, isFalse);
        expect(find.text('Abrir ajustes'), findsOneWidget);
      });
    });

    testWidgets('on the iPhone it explains first too, and asks the phone '
        'for nothing', (WidgetTester tester) async {
      await _as(TargetPlatform.iOS, () async {
        final _FakePhone phone = _FakePhone(tester);
        final OwnController own = await _open(tester);
        await _tap(tester, _locationSwitch);
        expect(find.text(_locationTitle), findsOneWidget);
        expect(
          find.text(
            'Si aceptas, Quincena usará la ubicación que tu atajo le pase con '
            'cada pago.',
          ),
          findsOneWidget,
        );
        await _tap(tester, find.text('Aceptar'));
        expect(find.text(_alwaysTitle), findsNothing);
        expect(phone.requests, isEmpty);
        expect(_on(tester), isTrue);
        expect((await _saved(tester, own)).useLocation, isTrue);
      });
    });

    testWidgets('turning it off asks nothing', (WidgetTester tester) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester)..location = 'always';
        final OwnController own = await _open(tester);
        await tester.runAsync(
          () => own.store.saveCaptureSettings(
            own.captureSettings.copyWith(useLocation: true),
          ),
        );
        await settle(tester);
        await reveal(tester, _locationSwitch);
        expect(_on(tester), isTrue);
        await _tap(tester, _locationSwitch);
        expect(find.byType(AlertDialog), findsNothing);
        expect(phone.requests, isEmpty);
        expect(_on(tester), isFalse);
      });
    });
  });

  group('reading notifications', () {
    testWidgets('says what it reads before opening Android\'s screen, and '
        'only «Aceptar» opens it', (WidgetTester tester) async {
      await _as(TargetPlatform.android, () async {
        final _FakePhone phone = _FakePhone(tester);
        await _open(tester);
        final Finder grant = find.text('Permitir acceso a notificaciones');
        await _tap(tester, grant);
        expect(find.text(_notificationsTitle), findsOneWidget);
        expect(find.text('Qué lee'), findsOneWidget);
        expect(find.textContaining('bancos y billeteras'), findsOneWidget);
        expect(find.text('Cuándo'), findsOneWidget);
        expect(
          find.text(
            'En este teléfono. Quincena no envía su texto a ningún servidor '
            'ni a nadie.',
          ),
          findsOneWidget,
        );
        expect(phone.requests, isEmpty);

        await _tapOutside(tester);
        expect(find.text(_notificationsTitle), findsOneWidget);
        await _tap(tester, find.text('Ahora no'));
        expect(phone.requests, isEmpty);

        await _tap(tester, grant);
        await _systemBack(tester);
        expect(find.text(_notificationsTitle), findsNothing);
        expect(find.byType(CaptureSettingsPage), findsOneWidget);
        expect(phone.requests, isEmpty);

        await _tap(tester, grant);
        await _tap(tester, find.text('Aceptar'));
        expect(phone.requests, <String>['openNotificationAccess']);
      });
    });
  });
}
