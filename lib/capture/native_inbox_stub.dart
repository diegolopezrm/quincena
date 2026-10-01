import 'event.dart';

/// The web has no native side: nothing to take.
Future<List<CaptureEvent>> takeNativeEvents() async => const <CaptureEvent>[];
