/// Whether the network can be reached, as the phone or the browser can
/// tell: what a question that failed without it waits for.
library;

export 'network_io.dart' if (dart.library.js_interop) 'network_web.dart';
