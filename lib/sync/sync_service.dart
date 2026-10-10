import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../store/store.dart';
import 'compare.dart';
import 'merge.dart';
import 'sync_file.dart';
import 'vault.dart';

/// Where the vault's key, this device's name in it and the mark of its last
/// save are kept.
abstract class KeyStore {
  Future<List<int>?> read();
  Future<void> write(List<int> key);
  Future<void> delete();

  /// The device's identifier. It must not travel with a backup to another
  /// device, or two would sign their changes as one.
  Future<String?> device();
  Future<void> setDevice(String id);

  /// A mark that changes with every save of the versions: a database older
  /// than its keychain, as after restoring a backup, does not match it.
  Future<String?> mark();
  Future<void> setMark(String mark);
}

/// The device's keychain or keystore: never the database or an export.
class SecureKeyStore implements KeyStore {
  SecureKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _name = 'quincena.sync.key';
  static const String _deviceName = 'quincena.sync.device';
  static const String _markName = 'quincena.sync.mark';

  /// Kept on this device only: no backup carries it to another.
  static const IOSOptions _thisDevice = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );
  static const MacOsOptions _thisMac = MacOsOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

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

  @override
  Future<String?> device() => _storage.read(
    key: _deviceName,
    iOptions: _thisDevice,
    mOptions: _thisMac,
  );

  @override
  Future<void> setDevice(String id) => _storage.write(
    key: _deviceName,
    value: id,
    iOptions: _thisDevice,
    mOptions: _thisMac,
  );

  @override
  Future<String?> mark() =>
      _storage.read(key: _markName, iOptions: _thisDevice, mOptions: _thisMac);

  @override
  Future<void> setMark(String mark) => _storage.write(
    key: _markName,
    value: mark,
    iOptions: _thisDevice,
    mOptions: _thisMac,
  );
}

/// A key kept in memory, for tests.
class MemoryKeyStore implements KeyStore {
  List<int>? _key;
  String? _device;
  String? _mark;

  @override
  Future<List<int>?> read() async => _key;

  @override
  Future<void> write(List<int> key) async => _key = List<int>.of(key);

  @override
  Future<void> delete() async => _key = null;

  @override
  Future<String?> device() async => _device;

  @override
  Future<void> setDevice(String id) async => _device = id;

  @override
  Future<String?> mark() async => _mark;

  @override
  Future<void> setMark(String mark) async => _mark = mark;
}

/// What merging a file did.
class SyncReport {
  const SyncReport({
    required this.applied,
    required this.conflicts,
    this.changes = const SyncChanges(),
    this.joined = 0,
  });

  /// Records changed on this device.
  final int applied;

  /// Versions that lost and wait for the person.
  final int conflicts;

  /// Records changed on both devices, joined field by field.
  final int joined;

  /// What changed here, by what the person calls it.
  final SyncChanges changes;
}

/// What a file changed on this device, counted the way the person sees it:
/// a transfer is one movement, and a list of the Plan changes item by item.
@immutable
class SyncChanges {
  const SyncChanges({
    this.movements = 0,
    this.accounts = 0,
    this.plan = 0,
    this.settings = 0,
    this.movementsGone = 0,
    this.accountsGone = 0,
  });

  /// What changed between [before] and [after], this device's records
  /// around a merge.
  factory SyncChanges.between(
    Map<String, SyncRecord> before,
    Map<String, SyncRecord> after,
  ) {
    final Set<String> movements = <String>{};
    final Set<String> movementsGone = <String>{};
    var accounts = 0;
    var accountsGone = 0;
    var plan = 0;
    var settings = 0;
    // Both legs of a transfer are one movement.
    String movement(SyncRecord r) => switch (r.data?['transferId']) {
      final String t when t.isNotEmpty => 'transfer/$t',
      _ => r.key,
    };
    void count(SyncRecord r, {required bool gone}) {
      switch (r.table) {
        case 'entries':
          (gone ? movementsGone : movements).add(movement(r));
        case 'accounts':
          gone ? accountsGone++ : accounts++;
        case _ when _ofPlan(r):
          plan++;
        default:
          settings++;
      }
    }

    for (final MapEntry<String, SyncRecord> e in after.entries) {
      final SyncRecord? was = before[e.key];
      if (was != null && contentHash(was.data!) == contentHash(e.value.data!)) {
        continue;
      }
      count(e.value, gone: false);
    }
    for (final MapEntry<String, SyncRecord> e in before.entries) {
      if (!after.containsKey(e.key)) count(e.value, gone: true);
    }
    return SyncChanges(
      movements: movements.length,
      accounts: accounts,
      plan: plan,
      settings: settings,
      movementsGone: movementsGone.length,
      accountsGone: accountsGone,
    );
  }

  /// Movements and accounts that arrived, new or changed.
  final int movements;
  final int accounts;

  /// Goals, fixed payments and the rest of the Plan, added, changed or
  /// deleted.
  final int plan;

  /// The profile, categories, rates typed by hand and what the app learned.
  final int settings;

  /// Movements and accounts deleted here because they were elsewhere.
  final int movementsGone;
  final int accountsGone;

  /// The settings that are the Plan's: what syncs of them is the Plan.
  static const Set<String> _planSettings = <String>{
    'plan.envelopes',
    'plan.wishes',
    'plan.cushion',
    'plan.scenarios',
    'commitments.memories',
    'commitments.instalments',
    'commitments.detective',
    'shared.groups',
    'freelance',
    'trips',
    'setup.noFixed',
  };

  static bool _ofPlan(SyncRecord r) => switch (r.table) {
    'recurring' || 'goals' || 'budgets' => true,
    'settings' => _planSettings.contains(r.id),
    'list' ||
    'item' ||
    'map' => _planSettings.contains(QuincenaStore.settingOfItem(r.id)),
    _ => false,
  };
}

/// A version that waits for the person, and the one that stayed in its
/// place, when there is one to set beside it.
@immutable
class Waiting {
  const Waiting(this.conflict, this.kept);

  final SyncConflict conflict;

  /// The version shown now: under the same id or, for a line that arrived
  /// twice, the copy that stayed. Null when it is gone.
  final SyncRecord? kept;
}

/// The id something deleted for good comes back under: the same on every
/// device for the same old id, so bringing it back twice, or two movements
/// of the same account, make one record and not copies.
String renewedId(String old) =>
    'r${hash.sha256.convert(utf8.encode('quincena/sync/renew/$old')).toString().substring(0, 24)}';

/// This device's part in syncing with the person's others: the vault's key,
/// the versions of every record, and the files that carry them. See
/// `docs/SYNC.md`.
class SyncService {
  SyncService(this.store, {required this.keys, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final QuincenaStore store;
  final KeyStore keys;
  final DateTime Function() _now;

  static const String _stateKey = 'sync.state';
  static const String _conflictsKey = 'sync.conflicts';
  static const int _format = 1;

  /// Whether this device is in a vault.
  Future<bool> get linked async => await keys.read() != null;

  /// Starts a vault with this device and returns its code.
  Future<String> start() async {
    final VaultKey key = VaultKey.generate();
    await keys.write(key.bytes);
    if (await _stored() == null) {
      await _save(_State(device: await _identity(fresh: true), joining: false));
    }
    return key.code;
  }

  /// Joins the vault [code] spells, or throws a [CodeException].
  ///
  /// A device new to syncing counts what it has as older than the vault's:
  /// where both changed the same thing, the vault's version shows and this
  /// one waits. One that synced before, joining with a new code, keeps its
  /// versions, so nothing it deleted comes back.
  Future<void> join(String code) async {
    final VaultKey key = VaultKey.fromCode(code);
    await keys.write(key.bytes);
    if (await _stored() == null) {
      await _save(_State(device: await _identity(fresh: true), joining: true));
    }
  }

  /// The vault's code, to link another device.
  Future<String?> code() async => switch (await keys.read()) {
    final List<int> bytes => VaultKey(bytes).code,
    null => null,
  };

  /// A new code. Files made from now on cannot be opened with the old one;
  /// the devices to keep join again with the new one. The versions stay.
  Future<String> changeCode() async {
    final VaultKey key = VaultKey.generate();
    await keys.write(key.bytes);
    return key.code;
  }

  /// Stops syncing on this device: the key and the versions go; the data
  /// stays, and so does what waits to be reviewed.
  Future<void> stop() async {
    await keys.delete();
    await store.setSetting(_stateKey, '');
  }

  /// Everything this device has, with its versions, sealed for another.
  Future<Uint8List> export() async {
    final VaultKey key = await _key();
    _State state = await _load();
    await _moveRecreated(state);
    final Map<String, SyncRecord> here = await _here();
    final SyncClock clock = state.clock(_now);
    final Stamp Function() tick = state.joining
        ? state.olderTick()
        : clock.tick;
    final Map<String, RecordMeta> metas = scan(
      state.metas,
      here,
      device: state.device,
      tick: tick,
    );
    state = state.copyWith(
      metas: metas,
      last: clock.last,
      older: state.olderCount,
    );
    await _save(state);
    return SyncFile.seal(key, <String, Object?>{
      'app': 'quincena',
      'format': _format,
      'records': <Object?>[
        for (final MapEntry<String, RecordMeta> e in metas.entries)
          IncomingRecord(
            // A deletion travels as one, whatever is here under its id.
            record: e.value.deleted
                ? _tombstone(e.key)
                : here[e.key] ?? _tombstone(e.key),
            clocks: e.value.clocks,
            stamp: e.value.stamp,
            base: e.value.base,
          ).toJson(),
      ],
    });
  }

  /// Merges a file from another device of the vault. A file that does not
  /// open, or does not merge, changes nothing.
  Future<SyncReport> import(List<int> file) async {
    final VaultKey key = await _key();
    final Map<String, Object?> body = await SyncFile.open(key, file);
    final Object? format = body['format'];
    if (body['app'] != 'quincena' || format is! int) {
      throw const SyncFileException(SyncFileProblem.damaged);
    }
    if (format > _format) {
      throw const SyncFileException(SyncFileProblem.newer);
    }
    final List<IncomingRecord> incoming = <IncomingRecord>[
      if (body['records'] case final List<Object?> records)
        for (final Object? r in records) ?IncomingRecord.fromJson(r),
    ];
    _State state = await _load();
    await _moveRecreated(state);
    final Map<String, SyncRecord> here = await _here();
    final SyncClock clock = state.clock(_now);
    final Map<String, RecordMeta> scanned = scan(
      state.metas,
      here,
      device: state.device,
      tick: state.joining ? state.olderTick() : clock.tick,
    );
    for (final IncomingRecord i in incoming) {
      clock.observe(i.stamp);
    }
    final MergeResult result = merge(
      metas: scanned,
      here: here,
      incoming: incoming,
      device: state.device,
      tick: clock.tick,
      now: _now(),
    );
    state = state.copyWith(
      metas: result.metas,
      last: clock.last,
      older: state.olderCount,
    );
    // What changed, the versions and what waits go in together, or not at
    // all.
    final String mark = _newMark();
    await store.applySync(
      upserts: result.upserts,
      deletes: result.deletes,
      settings: <String, String>{
        _stateKey: jsonEncode(state.copyWith(mark: mark).toJson()),
        _conflictsKey: _conflictsJson(<SyncConflict>[
          ...await conflicts(),
          ...result.conflicts,
        ]),
      },
    );
    await keys.setMark(mark);
    // A row can read back a little different from how it came; hash what
    // the merge wrote as stored, so the next look does not take it for a
    // change.
    final Set<String> written = <String>{
      for (final SyncRecord r in result.upserts) r.key,
    };
    final _State merged = (await _stored())!;
    final Map<String, SyncRecord> stored = await _here();
    // Each record as it is now is what the next change here, and the next
    // one on another device that had this, both come from.
    RecordBase? base(String key, RecordMeta m) => switch (stored[key]) {
      final SyncRecord r when !m.deleted => RecordBase.of(m.clocks, r.data!),
      _ => null,
    };
    await _save(
      merged.copyWith(
        joining: false,
        metas: <String, RecordMeta>{
          for (final MapEntry<String, RecordMeta> e in merged.metas.entries)
            e.key: switch (stored[e.key]) {
              final SyncRecord r
                  when written.contains(e.key) && !e.value.deleted =>
                RecordMeta(
                  clocks: e.value.clocks,
                  stamp: e.value.stamp,
                  hash: contentHash(r.data!),
                ).withBase(base(e.key, e.value)),
              _ => e.value.withBase(base(e.key, e.value)),
            },
        },
      ),
    );
    // Only then: what joining copies changes is this device's own change,
    // and the next look gives it a version of its own. Hashed as stored
    // above, a movement moved to the kept account would travel with its old
    // version and new contents, and another device could keep it where it
    // was, on an account that is gone.
    final int twice = await _dropDuplicates();
    return SyncReport(
      applied: result.applied + twice,
      conflicts: result.conflicts.length,
      changes: SyncChanges.between(here, await _here()),
      joined: result.joined,
    );
  }

  /// Something written again under an id deleted for good cannot come back
  /// under it: it moves to the id derived from the old one, the same on
  /// every device, and what points to it follows.
  Future<void> _moveRecreated(_State state) async {
    final Map<String, SyncRecord> here = await _here();
    final Map<String, SyncRecord> moved = <String, SyncRecord>{};
    final List<SyncRecord> gone = <SyncRecord>[];
    final Map<String, String> accounts = <String, String>{};
    for (final SyncRecord r in here.values) {
      final RecordMeta? m = state.metas[r.key];
      if (m == null || !m.deleted || !deletionIsFinal(r.table)) continue;
      final SyncRecord renewed = _renewed(r, state.metas, here);
      moved[renewed.key] = renewed;
      gone.add(SyncRecord(r.table, r.id, null));
      if (r.table == 'accounts') accounts[r.id] = renewed.id;
    }
    if (gone.isEmpty) return;
    // Movements and fixed payments of a moved account point to its new id.
    final Set<String> leaving = <String>{
      for (final SyncRecord g in gone) g.key,
    };
    for (final SyncRecord r in <SyncRecord>[...here.values, ...moved.values]) {
      if (r.table != 'entries' && r.table != 'recurring') continue;
      if (leaving.contains(r.key) && !moved.containsKey(r.key)) continue;
      final String? to = accounts[r.data?['accountId']];
      if (to == null) continue;
      final SyncRecord current = moved[r.key] ?? r;
      moved[current.key] = SyncRecord(
        current.table,
        current.id,
        <String, Object?>{...current.data!, 'accountId': to},
      );
    }
    await store.applySync(upserts: moved.values.toList(), deletes: gone);
  }

  /// [r] under the id derived from its own, or from that one when it too
  /// was deleted for good.
  SyncRecord _renewed(
    SyncRecord r,
    Map<String, RecordMeta> metas,
    Map<String, SyncRecord> here,
  ) {
    String id = _itemId(r);
    String key;
    do {
      id = renewedId(id);
      key = r.table == 'list' ? '${_settingOf(r)}/$id' : '${r.table}/$id';
    } while (metas[key]?.deleted ?? false);
    final Map<String, Object?> data = <String, Object?>{...?r.data};
    if (data.containsKey('id')) data['id'] = id;
    return SyncRecord(
      r.table,
      r.table == 'list' ? '${_settingOf(r)}/$id' : id,
      data,
    );
  }

  /// The setting an item belongs to.
  static String _settingOf(SyncRecord r) => QuincenaStore.settingOfItem(r.id)!;

  /// The id of [r] itself: for an item, after its setting's name.
  static String _itemId(SyncRecord r) => r.table == 'list' || r.table == 'item'
      ? r.id.substring(_settingOf(r).length + 1)
      : r.id;

  /// Copies of the same thing that arrive from two devices: accounts that
  /// follow the same wallet or exchange asset become one, the one with the
  /// smaller id, and the same line of a statement or of Binance stays once.
  /// Every device picks the same, so they agree; a copy of a movement that
  /// differs in what the person may have changed waits to be reviewed.
  Future<int> _dropDuplicates() async {
    var dropped = 0;
    final Map<String, List<SyncRecord>> bySync = <String, List<SyncRecord>>{};
    for (final SyncRecord r in await store.syncRecords()) {
      if (r.table != 'accounts') continue;
      final Object? ref = r.data?['syncRef'];
      if (ref is! String || ref.isEmpty) continue;
      bySync.putIfAbsent(ref, () => <SyncRecord>[]).add(r);
    }
    final Map<String, String> into = <String, String>{};
    final List<SyncRecord> extraAccounts = <SyncRecord>[];
    for (final List<SyncRecord> same in bySync.values) {
      if (same.length < 2) continue;
      same.sort((SyncRecord a, SyncRecord b) => a.id.compareTo(b.id));
      for (final SyncRecord extra in same.skip(1)) {
        into[extra.id] = same.first.id;
        extraAccounts.add(SyncRecord(extra.table, extra.id, null));
      }
    }
    if (into.isNotEmpty) {
      await store.applySync(
        upserts: <SyncRecord>[
          for (final SyncRecord r in await store.syncRecords())
            if ((r.table == 'entries' || r.table == 'recurring') &&
                into.containsKey(r.data?['accountId']))
              SyncRecord(r.table, r.id, <String, Object?>{
                ...r.data!,
                'accountId': into[r.data!['accountId']],
              }),
        ],
        deletes: extraAccounts,
      );
      dropped += extraAccounts.length;
    }

    final Map<String, List<SyncRecord>> byRef = <String, List<SyncRecord>>{};
    for (final SyncRecord r in await store.syncRecords()) {
      if (r.table != 'entries') continue;
      final Object? ref = r.data?['sourceRef'];
      if (ref is! String || ref.isEmpty) continue;
      byRef
          .putIfAbsent('${r.data!['accountId']}|$ref', () => <SyncRecord>[])
          .add(r);
    }
    final List<SyncRecord> drop = <SyncRecord>[];
    final List<SyncConflict> waiting = <SyncConflict>[];
    for (final List<SyncRecord> same in byRef.values) {
      if (same.length < 2) continue;
      same.sort((SyncRecord a, SyncRecord b) => a.id.compareTo(b.id));
      for (final SyncRecord extra in same.skip(1)) {
        drop.add(SyncRecord(extra.table, extra.id, null));
        if (_personal(extra) != _personal(same.first)) {
          waiting.add(
            SyncConflict(
              record: extra,
              reason: ConflictReason.duplicate,
              at: _now(),
            ),
          );
        }
      }
    }
    if (drop.isEmpty) return dropped;
    await store.applySync(
      upserts: const <SyncRecord>[],
      deletes: drop,
      settings: <String, String>{
        if (waiting.isNotEmpty)
          _conflictsKey: _conflictsJson(<SyncConflict>[
            ...await conflicts(),
            ...waiting,
          ]),
      },
    );
    return dropped + drop.length;
  }

  /// What the person can change in a movement, to tell two copies apart.
  static String _personal(SyncRecord r) => jsonEncode(<Object?>[
    for (final String k in <String>['amount', 'category', 'payee', 'note'])
      r.data?[k],
  ]);

  /// The versions that lost, oldest first.
  Future<List<SyncConflict>> conflicts() async {
    final String? text = await store.setting(_conflictsKey);
    if (text == null || text.isEmpty) return const <SyncConflict>[];
    try {
      return <SyncConflict>[
        for (final Object? c in jsonDecode(text) as List<Object?>)
          ?SyncConflict.fromJson(c),
      ];
    } on FormatException {
      return const <SyncConflict>[];
    }
  }

  /// Brings [conflict] back as it was, with what it needs. Written here, it
  /// is the newest change, and the next file carries it to the others.
  ///
  /// Something deleted for good comes back under an id derived from its
  /// own, its account too when that is gone, so doing it twice or on two
  /// devices makes one record. What it replaces waits in its place, so
  /// bringing a version back loses nothing either.
  Future<void> restore(SyncConflict conflict) async {
    final Map<String, SyncRecord> present = await _here();
    final Map<String, RecordMeta> metas =
        (await _stored())?.metas ?? const <String, RecordMeta>{};
    final List<SyncRecord> upserts = <SyncRecord>[];
    final List<SyncConflict> replaced = <SyncConflict>[];
    SyncRecord record = conflict.record;
    if (record.table == 'entries') {
      // Not a statement's or Binance's line any more: the person's own, so
      // a later merge never takes it for a copy.
      record = SyncRecord(record.table, record.id, <String, Object?>{
        ...record.data!,
        'sourceRef': null,
      });
    }
    final bool gone =
        deletionIsFinal(record.table) &&
        (!present.containsKey(record.key) ||
            (metas[record.key]?.deleted ?? false));
    if (gone) {
      record = _renewed(record, metas, present);
      final String? account = record.data?['accountId'] as String?;
      if (record.table == 'entries' &&
          account != null &&
          !present.containsKey('accounts/$account')) {
        final SyncRecord? owner = conflict.needs
            .where((SyncRecord n) => n.key == 'accounts/$account')
            .firstOrNull;
        if (owner != null && !owner.deleted) {
          final SyncRecord again = _renewed(owner, metas, present);
          if (!present.containsKey(again.key)) upserts.add(again);
          record = SyncRecord(record.table, record.id, <String, Object?>{
            ...record.data!,
            'accountId': again.id,
          });
        }
      }
    } else if (present[record.key] case final SyncRecord current
        when contentHash(current.data!) != contentHash(record.data!)) {
      replaced.add(
        SyncConflict(
          record: current,
          reason: ConflictReason.replaced,
          at: _now(),
        ),
      );
    }
    upserts.add(record);
    await store.applySync(
      upserts: upserts,
      deletes: const <SyncRecord>[],
      settings: <String, String>{
        _conflictsKey: _conflictsJson(<SyncConflict>[
          for (final SyncConflict c in await conflicts())
            if (!_same(c, conflict)) c,
          ...replaced,
        ]),
      },
    );
  }

  /// What waits, oldest first, each beside the version that stayed.
  Future<List<Waiting>> waiting() async {
    final List<SyncConflict> all = await conflicts();
    if (all.isEmpty) return const <Waiting>[];
    final Map<String, SyncRecord> present = await _here();
    SyncRecord? kept(SyncRecord waits, ConflictReason reason) {
      if (present[waits.key] case final SyncRecord same) return same;
      if (reason != ConflictReason.duplicate || waits.table != 'entries') {
        return null;
      }
      // Of a line that arrived twice, the copy that stayed has another id.
      for (final SyncRecord r in present.values) {
        if (r.table == 'entries' &&
            r.data?['sourceRef'] == waits.data?['sourceRef'] &&
            r.data?['accountId'] == waits.data?['accountId']) {
          return r;
        }
      }
      return null;
    }

    return <Waiting>[
      for (final SyncConflict c in all) Waiting(c, kept(c.record, c.reason)),
    ];
  }

  /// Takes from [conflict]'s waiting version the fields in [take] into
  /// [kept], the version that stayed, and writes the result here as an
  /// edit made on this device: the next file carries it like any other.
  /// What waited goes with it; nothing else changes.
  ///
  /// The merge itself stays a merge of whole records: the person does the
  /// combining, seeing both versions, so nothing goes without them
  /// choosing it.
  Future<void> combine(
    SyncConflict conflict,
    SyncRecord kept,
    Iterable<SyncField> take,
  ) async {
    final Map<String, Object?> data = combineVersions(
      kept,
      conflict.record,
      take,
    );
    final bool changed = contentHash(data) != contentHash(kept.data!);
    await store.applySync(
      upserts: <SyncRecord>[
        if (changed)
          SyncRecord(kept.table, kept.id, <String, Object?>{
            ...data,
            // Edited now, as an edit in the movement's sheet would say.
            if (kept.table == 'entries')
              'updatedAt': _now().millisecondsSinceEpoch,
          }),
      ],
      deletes: const <SyncRecord>[],
      settings: <String, String>{
        _conflictsKey: _conflictsJson(<SyncConflict>[
          for (final SyncConflict c in await conflicts())
            if (!_same(c, conflict)) c,
        ]),
      },
    );
  }

  /// Puts [conflict] back among what waits, in its place by when it came:
  /// «Deshacer» after «Descartar».
  Future<void> keepWaiting(SyncConflict conflict) async {
    final List<SyncConflict> all = await conflicts();
    if (all.any((SyncConflict c) => _same(c, conflict))) return;
    final int at = all.indexWhere(
      (SyncConflict c) => c.at.isAfter(conflict.at),
    );
    await store.setSetting(
      _conflictsKey,
      _conflictsJson(
        <SyncConflict>[...all]..insert(at < 0 ? all.length : at, conflict),
      ),
    );
  }

  /// Lets [conflict] go: the version that won stays.
  Future<void> dismiss(SyncConflict conflict) async {
    final List<SyncConflict> all = await conflicts();
    await store.setSetting(
      _conflictsKey,
      _conflictsJson(<SyncConflict>[
        for (final SyncConflict c in all)
          if (!_same(c, conflict)) c,
      ]),
    );
  }

  static bool _same(SyncConflict a, SyncConflict b) =>
      a.record.key == b.record.key && a.at == b.at && a.reason == b.reason;

  static String _conflictsJson(List<SyncConflict> list) =>
      jsonEncode(<Object?>[for (final SyncConflict c in list) c.toJson()]);

  Future<VaultKey> _key() async => switch (await keys.read()) {
    final List<int> bytes => VaultKey(bytes),
    null => throw StateError('Not in a vault.'),
  };

  Future<Map<String, SyncRecord>> _here() async => <String, SyncRecord>{
    for (final SyncRecord r in await store.syncRecords()) r.key: r,
  };

  static SyncRecord _tombstone(String key) {
    final int slash = key.indexOf('/');
    return SyncRecord(key.substring(0, slash), key.substring(slash + 1), null);
  }

  static String _random(int length) {
    const String alphabet = '0123456789abcdefghjkmnpqrstvwxyz';
    final Random r = Random.secure();
    return <String>[
      for (var i = 0; i < length; i++) alphabet[r.nextInt(alphabet.length)],
    ].join();
  }

  static String _newMark() => _random(16);

  Future<_State?> _stored() async {
    final String? text = await store.setting(_stateKey);
    if (text == null || text.isEmpty) return null;
    try {
      return _State.fromJson(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }

  /// This device's identifier, from its keychain; a new one when there is
  /// none or [fresh] asks for one.
  Future<String> _identity({bool fresh = false}) async {
    final String? kept = fresh ? null : await keys.device();
    if (kept != null) return kept;
    final String id = _random(10);
    await keys.setDevice(id);
    return id;
  }

  /// The versions this device keeps, when they are its own and its latest.
  /// Versions a backup brought from another device, or an older copy of
  /// this one's, could sign two different changes alike: the device starts
  /// again as one that just joined.
  Future<_State> _load() async {
    final _State? state = await _stored();
    final String? device = await keys.device();
    final String? mark = await keys.mark();
    if (state != null &&
        device != null &&
        state.device == device &&
        state.mark == mark) {
      return state;
    }
    return _State(device: await _identity(fresh: true), joining: true);
  }

  Future<void> _save(_State state) async {
    final String mark = _newMark();
    await store.setSetting(
      _stateKey,
      jsonEncode(state.copyWith(mark: mark).toJson()),
    );
    await keys.setMark(mark);
  }
}

/// What this device keeps to sync: its identifier, its clock, the versions
/// of every record, whether it just joined, and the mark of the save.
class _State {
  _State({
    required this.device,
    required this.joining,
    this.metas = const <String, RecordMeta>{},
    this.older = 0,
    this.mark,
    Stamp? last,
  }) : last = last ?? Stamp(0, 0, device);

  final String device;

  /// Joined and not yet merged a file: what it has counts as older.
  final bool joining;
  final Map<String, RecordMeta> metas;
  final Stamp last;

  /// How many older stamps were handed out, so a later one stays later.
  final int older;
  int _olderNext = -1;

  /// What the keychain holds when these versions are the latest saved.
  final String? mark;

  SyncClock clock(DateTime Function() now) =>
      SyncClock(device, last: last, now: now);

  /// Stamps from the start of time: a joining device's own records lose to
  /// the vault's where both changed the same thing. They keep counting from
  /// one export to the next, so a newer edit is still stamped after.
  Stamp Function() olderTick() {
    if (_olderNext < 0) _olderNext = older;
    return () => Stamp(0, _olderNext++, device);
  }

  /// How many older stamps there are now.
  int get olderCount => _olderNext < 0 ? older : _olderNext;

  _State copyWith({
    Map<String, RecordMeta>? metas,
    Stamp? last,
    bool? joining,
    int? older,
    String? mark,
  }) => _State(
    device: device,
    joining: joining ?? this.joining,
    metas: metas ?? this.metas,
    last: last ?? this.last,
    older: older ?? olderCount,
    mark: mark ?? this.mark,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'device': device,
    'joining': joining,
    'last': '$last',
    'older': olderCount,
    if (mark != null) 'mark': mark,
    'records': <String, Object?>{
      for (final MapEntry<String, RecordMeta> e in metas.entries)
        e.key: e.value.toJson(),
    },
  };

  static _State? fromJson(Object? json) {
    if (json is! Map || json['device'] is! String) return null;
    final String device = json['device']! as String;
    return _State(
      device: device,
      joining: json['joining'] == true,
      last: Stamp.parse(json['last']),
      older: (json['older'] as num?)?.round() ?? 0,
      mark: json['mark'] as String?,
      metas: <String, RecordMeta>{
        if (json['records'] case final Map<Object?, Object?> records)
          for (final MapEntry<Object?, Object?> e in records.entries)
            if (RecordMeta.fromJson(e.value) case final RecordMeta m)
              '${e.key}': m,
      },
    );
  }
}
