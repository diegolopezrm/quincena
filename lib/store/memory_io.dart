import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// SQLite in memory: nothing is written to the device.
QueryExecutor inMemoryDatabase() => NativeDatabase.memory();
