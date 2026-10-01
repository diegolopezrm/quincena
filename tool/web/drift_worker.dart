// The worker drift runs the web database in, so it can be shared between
// tabs. Compiled to web/drift_worker.js with:
//
//   dart compile js -O4 --no-source-maps tool/web/drift_worker.dart -o web/drift_worker.js
//
// Recompile after upgrading drift: the worker and the app must match.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
