import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hands a message to the system's share sheet, where the person picks who
/// gets it and sends it themselves. Nothing is sent from the app.
abstract final class ShareText {
  static const MethodChannel _channel = MethodChannel(
    'dev.dlsoft.quincena/share',
  );

  /// Opens the share sheet on a phone; elsewhere copies [text] for the
  /// person to paste. True when the sheet opened, false when copied.
  static Future<bool> share(String text) async {
    final bool phone =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    if (phone) {
      try {
        if (await _channel.invokeMethod<bool>('text', text) ?? false) {
          return true;
        }
      } on Object {
        // Without the sheet, the clipboard still works.
      }
    }
    await Clipboard.setData(ClipboardData(text: text));
    return false;
  }
}
