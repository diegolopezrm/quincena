/// The file the native side of each platform appends captured events to:
/// the App Intent on iOS, the notification listener on Android.
library;

export 'native_inbox_stub.dart' if (dart.library.io) 'native_inbox_io.dart';
