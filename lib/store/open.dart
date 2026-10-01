import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import 'database.dart';
import 'store.dart';

/// Whether this build can keep a database of the person's own accounts.
///
/// The web needs SQLite compiled to WebAssembly served next to the page;
/// until it is, the web build offers the demo only.
const bool storageAvailable = !kIsWeb;

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
