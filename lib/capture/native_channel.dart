import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'inbox.dart';

/// How much of the location the platform lets Quincena see.
enum LocationAccess {
  /// Not at all.
  none,

  /// Only while the app is open, which on Android leaves out most payments.
  foreground,

  /// Also while it is closed, or handed over by a shortcut on iOS.
  always;

  static LocationAccess parse(String? value) => switch (value) {
    'always' => LocationAccess.always,
    'foreground' => LocationAccess.foreground,
    _ => LocationAccess.none,
  };
}

/// What the app and the platform tell each other about automatic capture.
///
/// Both platforms say when something arrived while the app was open. Only
/// Android answers the rest: on iOS everything goes through Shortcuts,
/// which needs nothing from the app but its App Intent.
///
/// The same channel as `MainActivity.kt` and `AppDelegate.swift`.
abstract final class CaptureChannel {
  static const MethodChannel _channel = MethodChannel(
    'dev.dlsoft.quincena/capture',
  );

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether this device reads the text in an image or a PDF: Vision on
  /// iOS and macOS, ML Kit on Android.
  static bool get readsImages =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// The text in a screenshot, a photo or a PDF, read on the device, with
  /// a receipt's label and value on one line. Null when it could not be
  /// read.
  static Future<String?> readText(Uint8List bytes) async {
    if (!readsImages) return null;
    try {
      return await _channel.invokeMethod<String>('readText', bytes);
    } on Object {
      return null;
    }
  }

  /// Every page of a statement's PDF, read on the device row by row as it
  /// is printed. Null when it could not be read, and on the web.
  static Future<String?> readStatement(Uint8List bytes) async {
    if (!readsImages) return null;
    try {
      return await _channel.invokeMethod<String>('readStatement', bytes);
    } on Object {
      return null;
    }
  }

  /// Whether the person shared something with Quincena from another app and
  /// asked to see it, since the last time this was asked. Android only.
  static Future<bool> takeOpenInbox() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('takeOpenInbox') ?? false;
    } on Object {
      return false;
    }
  }

  static Object? _listener;

  /// Calls [onCaptured] each time the platform leaves a new event while the
  /// app is open, until [stop] is called with the same [owner]. The last
  /// owner to listen is the one called.
  static void listen(Object owner, Future<void> Function() onCaptured) {
    if (!_native) return;
    _listener = owner;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'captured') await onCaptured();
    });
  }

  /// Stops calling [owner], unless another one listens now.
  static void stop(Object owner) {
    if (!_native || !identical(_listener, owner)) return;
    _listener = null;
    _channel.setMethodCallHandler(null);
  }

  /// Whether Quincena may read notifications.
  static Future<bool> notificationAccess() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('notificationAccess') ?? false;
    } on Object {
      return false;
    }
  }

  /// Opens the system screen where notification access is granted.
  static Future<void> openNotificationAccess() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('openNotificationAccess');
    } on Object {
      // Nothing to open on this device.
    }
  }

  /// Whether the notification listener can know where a payment happened.
  /// iOS needs nothing: the shortcut gets the location and hands it over.
  static Future<LocationAccess> locationAccess() => _location('locationAccess');

  /// Asks for the location while the app is in use.
  static Future<LocationAccess> askForLocation() => _location('askForLocation');

  /// Asks for the location all the time, which Android needs to know where
  /// a payment happened while the app was closed. From Android 11 this is
  /// the system settings page, not a dialog.
  static Future<LocationAccess> askForBackgroundLocation() =>
      _location('askForBackgroundLocation');

  static Future<LocationAccess> _location(String method) async {
    if (!_android) {
      return _native ? LocationAccess.always : LocationAccess.none;
    }
    try {
      return LocationAccess.parse(await _channel.invokeMethod<String>(method));
    } on Object {
      return LocationAccess.none;
    }
  }

  /// Opens Quincena's page in the system settings, where a permission the
  /// person denied for good can be given again.
  static Future<void> openAppSettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on Object {
      // Nothing to open on this device.
    }
  }

  /// Tells the notification listener what the person chose, so a muted
  /// app is not even written down and the location is noted only when on.
  static Future<void> configure(CaptureSettings settings) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('configure', <String, Object>{
        'useLocation': settings.useLocation,
        'mutedApps': settings.mutedApps.toList()..sort(),
      });
    } on Object {
      // An older build without the listener.
    }
  }
}
