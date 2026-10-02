import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Quincena's Firebase project, through which anyone asks Gemini without a
/// key of their own.
///
/// The project only answers an app App Check vouches for: App Attest on an
/// iPhone or a Mac, Play Integrity on Android. A simulator or an emulator
/// passes with a debug token, given at build time and never committed:
///
///     flutter run --dart-define-from-file=tool/app_check.local.json
///
/// Each person signs in anonymously, which is how the project counts their
/// requests: nothing about them is asked or kept.
abstract final class Cloud {
  static const String _debugToken = String.fromEnvironment(
    'APP_CHECK_DEBUG_TOKEN',
  );

  static Future<bool>? _starting;

  /// Whether this platform has a Firebase app: Android, iOS and macOS.
  static bool get supported => DefaultFirebaseOptions.currentPlatform != null;

  /// Starts Firebase and App Check, once. False where there is no Firebase
  /// app, or it could not start; a later call tries again.
  static Future<bool> start() => _starting ??= _start();

  static Future<bool> _start() async {
    final FirebaseOptions? options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      final bool debug = _debugToken.isNotEmpty;
      await FirebaseAppCheck.instance.activate(
        providerAndroid: debug
            ? const AndroidDebugProvider(debugToken: _debugToken)
            : const AndroidPlayIntegrityProvider(),
        providerApple: debug
            ? const AppleDebugProvider(debugToken: _debugToken)
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      return true;
    } on Object catch (error) {
      debugPrint('Firebase did not start: $error');
      _starting = null;
      return false;
    }
  }

  /// Signs the person in anonymously the first time, so the project can
  /// limit how much each one asks.
  static Future<void> signIn() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return;
    await auth.signInAnonymously();
  }
}
