import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the app asks of the platform for automatic capture. Only Android
/// answers: on iOS everything goes through Shortcuts, which needs nothing
/// from the app but its App Intent.
abstract final class CaptureChannel {
  static const MethodChannel _channel = MethodChannel(
    'dev.dlsoft.quincena/capture',
  );

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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

  /// Tells the listener whether to note where the phone was, asking for
  /// the permission when turning it on. Returns whether it is allowed.
  static Future<bool> setUseLocation(bool on) async {
    if (!_android) return on;
    try {
      return await _channel.invokeMethod<bool>('setUseLocation', on) ?? false;
    } on Object {
      return false;
    }
  }
}
