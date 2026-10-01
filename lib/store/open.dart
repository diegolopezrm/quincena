import 'package:drift_flutter/drift_flutter.dart';

import 'database.dart';
import 'store.dart';

/// Whether this build can keep a database of the person's own accounts.
///
/// Every platform can: on the web, SQLite compiled to WebAssembly
/// (`web/sqlite3.wasm`) runs in drift's worker (`web/drift_worker.js`) and
/// keeps the database in the browser's storage.
const bool storageAvailable = true;

/// Opens the database in the app's documents folder, or in the browser's
/// storage on the web.
QuincenaStore openStore() => QuincenaStore(
  QuincenaDatabase(
    driftDatabase(
      name: 'quincena',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  ),
);
