import 'package:web/web.dart' as web;

/// Tells FlutterFire which App Check provider the web app is about to use.
///
/// FlutterFire stores the provider it was last activated with and starts App
/// Check with it on the next load, as Firebase starts, before the app says
/// which one it wants. If they differ, because the reCAPTCHA key changed or a
/// local build switched to the debug token, activating fails and Gemini is
/// gone until the site's data is cleared. Written first, they match. The
/// names are FlutterFire's own, from firebase_app_check_web.
void rememberWebProvider({required bool debug, required String key}) {
  const String app = '[DEFAULT]';
  web.window.localStorage
    ..setItem('FlutterFire-$app-recaptchaType', debug ? 'debug' : 'enterprise')
    ..setItem('FlutterFire-$app-recaptchaSiteKey', key);
}
