import 'package:web/web.dart' as web;

/// Whether the browser says it is online.
Future<bool> networkReachable() async => web.window.navigator.onLine;
