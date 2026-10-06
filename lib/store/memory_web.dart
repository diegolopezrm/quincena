import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// SQLite compiled to WebAssembly, in memory: nothing is written to the
/// browser's storage, where the person's own accounts are.
QueryExecutor inMemoryDatabase() => DatabaseConnection.delayed(
  Future<DatabaseConnection>(() async {
    final WasmSqlite3 sqlite = await WasmSqlite3.loadFromUrl(
      Uri.parse('sqlite3.wasm'),
    );
    sqlite.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
    return DatabaseConnection(WasmDatabase.inMemory(sqlite));
  }),
);
