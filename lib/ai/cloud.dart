import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Quincena's Firebase project, through which anyone asks Gemini without a
/// key of their own.
///
/// The project only answers an app App Check vouches for: App Attest on an
/// iPhone or a Mac, Play Integrity on Android, reCAPTCHA Enterprise on the
/// web. A simulator, an emulator or a local web build passes with a debug
/// token, given at build time and never committed:
///
///     flutter run --dart-define-from-file=tool/app_check.local.json
///
/// Never for a build that is published: on the web, the token would travel
/// in the page's JavaScript for anyone to take.
///
/// Each person signs in anonymously, which is how the project counts their
/// requests: nothing about them is asked or kept.
abstract final class Cloud {
  static const String _debugToken = String.fromEnvironment(
    'APP_CHECK_DEBUG_TOKEN',
  );

  /// The reCAPTCHA Enterprise key the web app is scored with. Like the
  /// Firebase options, it names the site and is public by design: it only
  /// works on the domains it was created for.
  static const String _recaptchaKey =
      '6LfnhdotAAAAAOoxeOz5WDL0i0nqImek33BD79CA';

  static Future<bool>? _starting;

  /// Whether this platform has a Firebase app: Android, iOS, macOS and the
  /// web.
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
        providerWeb: debug
            ? WebDebugProvider(debugToken: _debugToken)
            : ReCaptchaEnterpriseProvider(_recaptchaKey),
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
  ///
  /// Where that fails the question still goes, vouched for by App Check, only
  /// without a user: a Mac build not signed with the team, for one, is
  /// refused the keychain the account lives in.
  static Future<void> signIn() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    if (auth.currentUser != null || _keychainRefused) return;
    try {
      await auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      // Asked again while the app runs, the keychain would only refuse again.
      _keychainRefused = error.code == 'keychain-error';
      debugPrint('Anonymous sign-in failed: ${error.code}');
    }
  }

  static bool _keychainRefused = false;
}
