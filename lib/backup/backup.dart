import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../store/store.dart';
import '../sync/sync_file.dart';
import '../sync/vault.dart';

/// Where the backup's key is kept: the device's keychain, apart from the
/// data it seals, and never in an export.
abstract class BackupKeyStore {
  Future<List<int>?> read();
  Future<void> write(List<int> key);
  Future<void> delete();
}

/// The device's keychain or keystore.
class SecureBackupKeyStore implements BackupKeyStore {
  SecureBackupKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _name = 'quincena.backup.key';

  @override
  Future<List<int>?> read() async => switch (await _storage.read(key: _name)) {
    final String text => base64Decode(text),
    null => null,
  };

  @override
  Future<void> write(List<int> key) =>
      _storage.write(key: _name, value: base64Encode(key));

  @override
  Future<void> delete() => _storage.delete(key: _name);
}

/// A key kept in memory, for tests.
class MemoryBackupKeyStore implements BackupKeyStore {
  List<int>? _key;

  @override
  Future<List<int>?> read() async => _key;

  @override
  Future<void> write(List<int> key) async => _key = List<int>.of(key);

  @override
  Future<void> delete() async => _key = null;
}

/// Why a backup could not be opened, beyond what [ImportException] says.
enum BackupProblem {
  /// Sealed with a code this device does not have.
  needsCode,

  /// The code given does not open it.
  wrongCode,

  /// A sync file: it opens in "Varios dispositivos", not here.
  syncFile,
}

class BackupException implements Exception {
  const BackupException(this.problem);

  final BackupProblem problem;

  @override
  String toString() => 'BackupException(${problem.name})';
}

/// A sealed backup, and its code when this device made its first one: the
/// person sees it then and keeps it.
class SealedBackup {
  const SealedBackup(this.file, [this.newCode]);

  final Uint8List file;
  final String? newCode;
}

/// A backup read and ready to replace what is here.
class OpenedBackup {
  const OpenedBackup(this.json, [this.key]);

  final Map<String, Object?> json;

  /// The key a typed code gave.
  final VaultKey? key;

  /// What it holds, to say before it replaces anything.
  BackupContents get contents => BackupContents.of(json);
}

/// What a backup holds, counted the way the person sees it, so they know
/// what they get before it replaces what they have. Any part an older file
/// lacks counts as none.
@immutable
class BackupContents {
  const BackupContents({
    this.made,
    this.accounts = 0,
    this.movements = 0,
    this.goals = 0,
    this.plan = 0,
  });

  /// What [json], an export, holds.
  factory BackupContents.of(Map<String, Object?> json) {
    List<Map<Object?, Object?>> rows(String key) => <Map<Object?, Object?>>[
      if (json[key] case final List<Object?> list)
        for (final Object? row in list)
          if (row is Map<Object?, Object?>) row,
    ];
    // The two legs of a transfer are one movement to the person.
    final Set<String> movements = <String>{
      for (final (int i, Map<Object?, Object?> e) in rows('entries').indexed)
        switch (e['transferId']) {
          final String t when t.isNotEmpty => 'transfer:$t',
          _ => 'entry:${e['id'] ?? i}',
        },
    };
    final Object? settings = json['settings'];
    int listed(String key, [String field = '']) {
      final Object? text = settings is Map ? settings[key] : null;
      if (text is! String || text.isEmpty) return 0;
      try {
        final Object? value = jsonDecode(text);
        final Object? list = field.isEmpty
            ? value
            : (value is Map ? value[field] : null);
        return list is List ? list.length : 0;
      } on FormatException {
        return 0;
      }
    }

    final Object? made = json['exportedAt'];
    return BackupContents(
      made: made is String ? DateTime.tryParse(made)?.toLocal() : null,
      // Archived accounts come back too, but out of sight, as they were.
      accounts: rows(
        'accounts',
      ).where((Map<Object?, Object?> a) => a['archived'] != true).length,
      movements: movements.length,
      goals: rows('goals').length,
      plan:
          rows('recurring').length +
          listed('commitments.instalments') +
          listed('shared.groups') +
          listed('plan.wishes') +
          listed('trips') +
          listed('freelance', 'incomes') +
          listed('plan.envelopes', 'envelopes') +
          listed('plan.scenarios'),
    );
  }

  /// When it was made, when the file says.
  final DateTime? made;

  /// The accounts Cuentas will show.
  final int accounts;

  /// Movements, a transfer between two accounts counted once.
  final int movements;
  final int goals;

  /// What else the Plan keeps: fixed payments, purchases in instalments,
  /// shared expenses, wishes, trips, variable income, envelopes and
  /// scenarios.
  final int plan;
}

/// A copy of everything, kept somewhere else for the day a phone is lost:
/// sealed with a code of its own, or as JSON any app reads if the person
/// chooses that.
class Backups {
  Backups(this.store, {BackupKeyStore? keys, this.random})
    : keys = keys ?? SecureBackupKeyStore();

  final QuincenaStore store;
  final BackupKeyStore keys;

  /// The system's secure generator unless a test says otherwise.
  final Random? random;

  Future<VaultKey?> _key() async {
    try {
      final List<int>? bytes = await keys.read();
      if (bytes == null || bytes.length != VaultKey.length) return null;
      return VaultKey(bytes);
    } on Object {
      // No keychain here: no key either.
      return null;
    }
  }

  Future<void> _keep(VaultKey key) async {
    try {
      await keys.write(key.bytes);
    } on Object {
      // No keychain here: the code is shown with every backup instead.
    }
  }

  /// The code that opens this device's sealed backups, once it has one.
  Future<String?> code() async => (await _key())?.code;

  /// Everything, sealed. The first time, the key is made here and its code
  /// comes back with the file.
  Future<SealedBackup> seal() async {
    VaultKey? key = await _key();
    String? newCode;
    if (key == null) {
      key = VaultKey.generate(random);
      newCode = key.code;
      await _keep(key);
    }
    final Uint8List file = await SealedFile.backup.seal(
      key,
      await store.exportJson(),
      random: random,
    );
    return SealedBackup(file, newCode);
  }

  /// A new key for the backups to come, and its code to show. Those made
  /// before still open with the code they were made with.
  Future<String> changeCode() async {
    final VaultKey key = VaultKey.generate(random);
    await _keep(key);
    return key.code;
  }

  /// Everything as JSON, readable by anyone who has the file.
  Future<Uint8List> plain() async => Uint8List.fromList(
    utf8.encode(
      const JsonEncoder.withIndent('  ').convert(await store.exportJson()),
    ),
  );

  /// What [file] holds: a sealed backup, with this device's key or the
  /// [code] typed, or an export in JSON. Throws a [CodeException] for a
  /// code that is not one, a [BackupException], or an [ImportException];
  /// nothing changes here until [restore].
  Future<OpenedBackup> open(List<int> file, {String? code}) async {
    if (SealedFile.backup.marks(file)) {
      final VaultKey? typed = code == null ? null : VaultKey.fromCode(code);
      final VaultKey? key = typed ?? await _key();
      if (key == null) throw const BackupException(BackupProblem.needsCode);
      final Map<String, Object?> json;
      try {
        json = await SealedFile.backup.open(key, file);
      } on SyncFileException catch (e) {
        throw switch (e.problem) {
          SyncFileProblem.otherVault => BackupException(
            typed == null ? BackupProblem.needsCode : BackupProblem.wrongCode,
          ),
          SyncFileProblem.newer => const ImportException(ImportProblem.newer),
          _ => const ImportException(ImportProblem.damaged),
        };
      }
      QuincenaStore.checkExport(json);
      return OpenedBackup(json, typed);
    }
    if (SealedFile.sync.marks(file)) {
      throw const BackupException(BackupProblem.syncFile);
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(file));
    } on FormatException {
      throw const ImportException(ImportProblem.notQuincena);
    }
    if (json is! Map<String, Object?>) {
      throw const ImportException(ImportProblem.notQuincena);
    }
    QuincenaStore.checkExport(json);
    return OpenedBackup(json);
  }

  /// Replaces everything with [backup], or changes nothing. A code typed
  /// on a device that had none stays, so the next backup opens with it.
  Future<void> restore(OpenedBackup backup) async {
    await store.importJson(backup.json);
    final VaultKey? key = backup.key;
    if (key != null && await _key() == null) await _keep(key);
  }

  /// Forgets the key, as when everything is deleted. Backups made with it
  /// still open with its code.
  Future<void> forget() async {
    try {
      await keys.delete();
    } on Object {
      // No keychain here: nothing to forget.
    }
  }
}
