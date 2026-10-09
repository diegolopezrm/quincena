import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../capture/native_channel.dart';

/// Quincena's own page in the phone's settings, where a permission the
/// person turned down can be given again.
abstract final class AppSettingsPage {
  /// Phones only: elsewhere there is no such page to send the person to.
  static bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Opens the page: on Android through the same call the location uses, on
  /// iOS through the link the system keeps for it, which needs no code of
  /// the app's own.
  static Future<void> open() async {
    if (!available) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return CaptureChannel.openAppSettings();
    }
    try {
      // UIApplication.openSettingsURLString.
      await launchUrl(
        Uri.parse('app-settings:'),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      // Nothing to open on this device.
    }
  }
}
