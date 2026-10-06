/// A database that lives in memory and is gone when it closes: what the
/// example account is kept in, apart from the person's own.
library;

export 'memory_io.dart' if (dart.library.js_interop) 'memory_web.dart';
