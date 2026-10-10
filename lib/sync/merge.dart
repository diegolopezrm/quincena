import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:flutter/foundation.dart' show immutable;

/// One record that syncs, as the store keeps it. [data] is null for a
/// record deleted.
@immutable
class SyncRecord {
  const SyncRecord(this.table, this.id, this.data);

  final String table;
  final String id;
  final Map<String, Object?>? data;

  String get key => '$table/$id';

  bool get deleted => data == null;

  Map<String, Object?> toJson() => <String, Object?>{
    't': table,
    'i': id,
    'd': data,
  };

  static SyncRecord? fromJson(Object? json) {
    if (json is! Map || json['t'] is! String || json['i'] is! String) {
      return null;
    }
    return SyncRecord(
      json['t']! as String,
      json['i']! as String,
      switch (json['d']) {
        final Map<Object?, Object?> d => d.cast<String, Object?>(),
        _ => null,
      },
    );
  }
}

/// When a change was made: the device's clock, a counter for changes in
/// the same millisecond, and the device, which breaks ties. Orders
/// concurrent changes; never says which came from which.
@immutable
class Stamp implements Comparable<Stamp> {
  const Stamp(this.ms, this.n, this.device);

  final int ms;
  final int n;
  final String device;

  @override
  int compareTo(Stamp other) {
    if (ms != other.ms) return ms.compareTo(other.ms);
    if (n != other.n) return n.compareTo(other.n);
    return device.compareTo(other.device);
  }

  bool operator >(Stamp other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is Stamp && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(ms, n, device);

  @override
  String toString() => '$ms.$n.$device';

  static Stamp? parse(Object? text) {
    if (text is! String) return null;
    final List<String> parts = text.split('.');
    if (parts.length != 3) return null;
    final int? ms = int.tryParse(parts[0]);
    final int? n = int.tryParse(parts[1]);
    if (ms == null || n == null || parts[2].isEmpty) return null;
    return Stamp(ms, n, parts[2]);
  }
}

/// A hybrid logical clock: the device's time, never behind anything it
/// has seen, so a change made after reading another device's is stamped
/// after it even when the clocks disagree.
class SyncClock {
  SyncClock(this.device, {Stamp? last, DateTime Function()? now})
    : _last = last ?? Stamp(0, 0, device),
      _now = now ?? DateTime.now;

  final String device;
  Stamp _last;
  final DateTime Function() _now;

  Stamp get last => _last;

  Stamp tick() {
    final int wall = _now().millisecondsSinceEpoch;
    _last = wall > _last.ms
        ? Stamp(wall, 0, device)
        : Stamp(_last.ms, _last.n + 1, device);
    return _last;
  }

  /// Moves past [seen], a stamp from elsewhere.
  void observe(Stamp seen) {
    if (seen.ms > _last.ms || (seen.ms == _last.ms && seen.n > _last.n)) {
      _last = Stamp(seen.ms, seen.n, device);
    }
  }
}

/// How two versions of a record stand.
enum Order { same, before, after, concurrent }

/// Per device, how many changes of a record it made. One version comes
/// before another when it saw no change the other did not.
Order compareClocks(Map<String, int> a, Map<String, int> b) {
  var aAhead = false;
  var bAhead = false;
  for (final String d in <String>{...a.keys, ...b.keys}) {
    final int x = a[d] ?? 0;
    final int y = b[d] ?? 0;
    if (x > y) aAhead = true;
    if (y > x) bAhead = true;
  }
  if (aAhead && bAhead) return Order.concurrent;
  if (aAhead) return Order.after;
  if (bAhead) return Order.before;
  return Order.same;
}

Map<String, int> _join(Map<String, int> a, Map<String, int> b) => <String, int>{
  for (final String d in <String>{...a.keys, ...b.keys})
    d: max(a[d] ?? 0, b[d] ?? 0),
};

/// What a device knows of one record: its version clocks, when it last
/// changed, a hash of its contents, null once deleted, and the version it
/// had right after its last merge, to tell later which fields changed.
@immutable
class RecordMeta {
  const RecordMeta({
    required this.clocks,
    required this.stamp,
    this.hash,
    this.base,
  });

  final Map<String, int> clocks;
  final Stamp stamp;
  final String? hash;
  final RecordBase? base;

  bool get deleted => hash == null;

  /// This record changed here: one more change by [device].
  RecordMeta changed(String device, Stamp stamp, String? hash) => RecordMeta(
    clocks: <String, int>{...clocks, device: (clocks[device] ?? 0) + 1},
    stamp: stamp,
    hash: hash,
    base: base,
  );

  RecordMeta withBase(RecordBase? base) =>
      RecordMeta(clocks: clocks, stamp: stamp, hash: hash, base: base);

  Map<String, Object?> toJson() => <String, Object?>{
    'c': clocks,
    's': '$stamp',
    if (hash != null) 'h': hash,
    if (base != null) 'b': base!.toJson(),
  };

  static RecordMeta? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? clocks = json['c'];
    final Stamp? stamp = Stamp.parse(json['s']);
    if (clocks is! Map || stamp == null) return null;
    return RecordMeta(
      clocks: _clocks(clocks),
      stamp: stamp,
      hash: json['h'] as String?,
      base: RecordBase.fromJson(json['b']),
    );
  }
}

Map<String, int> _clocks(Map<Object?, Object?> json) => <String, int>{
  for (final MapEntry<Object?, Object?> e in json.entries)
    if (e.value is int) '${e.key}': e.value! as int,
};

/// A version of a record as a device had it right after merging: its
/// clocks, and a short hash of each field. Two devices whose changes both
/// came from it can be joined field by field: a field only one of them
/// changed takes that one's value. Its contents are not kept, only enough
/// to tell which fields moved.
@immutable
class RecordBase {
  const RecordBase(this.clocks, this.fields);

  /// [data] as it is under [clocks].
  factory RecordBase.of(Map<String, int> clocks, Map<String, Object?> data) =>
      RecordBase(clocks, fieldHashes(data));

  final Map<String, int> clocks;
  final Map<String, String> fields;

  Map<String, Object?> toJson() => <String, Object?>{'c': clocks, 'f': fields};

  static RecordBase? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? clocks = json['c'];
    final Object? fields = json['f'];
    if (clocks is! Map || fields is! Map) return null;
    return RecordBase(_clocks(clocks), <String, String>{
      for (final MapEntry<Object?, Object?> e in fields.entries)
        if (e.value is String) '${e.key}': e.value! as String,
    });
  }
}

/// A short hash of each field of [data], the same on every device.
Map<String, String> fieldHashes(Map<String, Object?> data) => <String, String>{
  for (final MapEntry<String, Object?> e in data.entries)
    e.key: _fieldHash(e.value),
};

String _fieldHash(Object? value) => hash.sha256
    .convert(utf8.encode(jsonEncode(_canonical(value))))
    .toString()
    .substring(0, 12);

/// The fields of a table that only mean something together, and so join
/// as one: an amount with its kind, its account and what it cost; a fixed
/// payment's amount with its currency and account, and its cadence with its
/// next date; a goal's figures with its date; an account's money with its
/// kind and currency.
const Map<String, List<Set<String>>> _together = <String, List<Set<String>>>{
  'entries': <Set<String>>[
    <String>{'amount', 'kind', 'accountId', 'cost', 'costAsset'},
  ],
  'recurring': <Set<String>>[
    <String>{'amount', 'asset', 'accountId'},
    <String>{'cadence', 'nextDate'},
  ],
  'goals': <Set<String>>[
    <String>{'asset', 'target', 'saved', 'monthly', 'deadline'},
  ],
  'accounts': <Set<String>>[
    <String>{'kind', 'asset', 'opening', 'creditLimit'},
  ],
};

/// [ours] and [theirs], two versions of a record of [table] changed apart
/// from [base], joined field by field: a field only one of them changed
/// takes its value, and one both changed alike stays. Fields that mean
/// something together join as one. Null when something changed on both
/// sides to different values, or for what stays whole: settings, the
/// items of a list, and the legs of a transfer, whose amounts must stay
/// the same. Then they are two versions, as before.
Map<String, Object?>? joinFields(
  String table,
  Map<String, Object?> ours,
  Map<String, Object?> theirs,
  RecordBase base,
) {
  final List<Set<String>>? groups = _together[table];
  if (groups == null) return null;
  bool transfer(Map<String, Object?> data) => switch (data['transferId']) {
    final String t => t.isNotEmpty,
    _ => false,
  };
  if (transfer(ours) || transfer(theirs)) return null;
  final Set<String> fields = <String>{
    ...ours.keys,
    ...theirs.keys,
    ...base.fields.keys,
  };
  // Each group, then each field left, as one unit.
  final List<List<String>> units = <List<String>>[
    for (final Set<String> g in groups) g.toList()..sort(),
    for (final String f in fields.toList()..sort())
      if (!groups.any((Set<String> g) => g.contains(f))) <String>[f],
  ];
  String? hashOf(Map<String, Object?> data, List<String> unit) =>
      unit.every((String f) => !data.containsKey(f))
      ? null
      : <String>[
          for (final String f in unit)
            data.containsKey(f) ? _fieldHash(data[f]) : '-',
        ].join('/');
  String? baseOf(List<String> unit) =>
      unit.every((String f) => !base.fields.containsKey(f))
      ? null
      : <String>[for (final String f in unit) base.fields[f] ?? '-'].join('/');
  final Map<String, Object?> out = <String, Object?>{};
  for (final List<String> unit in units) {
    // When it was last changed says nothing of what changed: the later.
    if (unit.length == 1 && unit.single == 'updatedAt') {
      out['updatedAt'] = _latest(ours['updatedAt'], theirs['updatedAt']);
      continue;
    }
    final String? o = hashOf(ours, unit);
    final String? t = hashOf(theirs, unit);
    final String? b = baseOf(unit);
    // Alike, or changed only here: ours. Changed only there: theirs.
    final Map<String, Object?>? from = o == t || t == b
        ? ours
        : o == b
        ? theirs
        : null;
    if (from == null) return null;
    for (final String f in unit) {
      if (from.containsKey(f)) out[f] = from[f];
    }
  }
  return out;
}

Object? _latest(Object? a, Object? b) => switch ((a, b)) {
  (final num x, final num y) => x > y ? x : y,
  (final String x, final String y) => x.compareTo(y) > 0 ? x : y,
  _ => a ?? b,
};

/// The version both [ours] and [theirs] came from, of the two bases the
/// devices kept: one each has seen all of, the later when both have.
RecordBase? commonBase(
  RecordBase? a,
  RecordBase? b, {
  required Map<String, int> ours,
  required Map<String, int> theirs,
}) {
  bool fits(RecordBase? x) =>
      x != null && _sawAll(ours, x.clocks) && _sawAll(theirs, x.clocks);
  final RecordBase? first = fits(a) ? a : null;
  final RecordBase? second = fits(b) ? b : null;
  if (first == null || second == null) return first ?? second;
  // The later; between two neither of which came first, the same one on
  // both devices, which each hold the pair the other way round.
  return switch (compareClocks(first.clocks, second.clocks)) {
    Order.before => second,
    Order.after => first,
    _ =>
      jsonEncode(
                _canonical(first.toJson()),
              ).compareTo(jsonEncode(_canonical(second.toJson()))) <=
              0
          ? first
          : second,
  };
}

/// A hash of [data] that two devices agree on: the same contents give the
/// same hash whatever order the fields came in.
String contentHash(Map<String, Object?> data) => hash.sha256
    .convert(utf8.encode(jsonEncode(_canonical(data))))
    .toString()
    .substring(0, 24);

Object? _canonical(Object? value) => switch (value) {
  final Map<Object?, Object?> m => <String, Object?>{
    for (final String k in m.keys.map((Object? k) => '$k').toList()..sort())
      k: _canonical(m[k]),
  },
  final List<Object?> l => <Object?>[for (final Object? v in l) _canonical(v)],
  _ => value,
};

/// Records with ids made at random: once deleted, a record stays deleted
/// on every device, and bringing it back makes a new one. The rest are
/// known by name, a setting or a category, and the latest change wins,
/// deletions included. Either way the outcome is the same in any order.
bool deletionIsFinal(String table) => const <String>{
  'accounts',
  'entries',
  'recurring',
  'goals',
  'list',
}.contains(table);

/// Why a change waits for the person instead of being applied.
enum ConflictReason {
  /// Changed here and elsewhere since the devices last agreed: the later
  /// change shows, this one waits.
  editedBoth,

  /// Changed here, deleted elsewhere: the deletion holds.
  deletedElsewhere,

  /// Deleted here, changed elsewhere: the deletion holds.
  deletedHere,

  /// Its account was deleted on one side and it was added or kept on the
  /// other.
  withAccount,

  /// What was there before the person brought another version back.
  replaced,

  /// The same line of a statement or of Binance arrived on two devices;
  /// one stayed.
  duplicate,
}

/// A version that did not win, kept so nothing is lost without a trace:
/// the person can bring it back, which makes it the newest change.
@immutable
class SyncConflict {
  const SyncConflict({
    required this.record,
    required this.reason,
    required this.at,
    this.needs = const <SyncRecord>[],
  });

  /// The version that lost, as it was.
  final SyncRecord record;
  final ConflictReason reason;
  final DateTime at;

  /// What bringing it back needs too: the account of a movement.
  final List<SyncRecord> needs;

  Map<String, Object?> toJson() => <String, Object?>{
    'r': record.toJson(),
    'why': reason.name,
    'at': at.toIso8601String(),
    if (needs.isNotEmpty)
      'needs': <Object?>[for (final SyncRecord n in needs) n.toJson()],
  };

  static SyncConflict? fromJson(Object? json) {
    if (json is! Map) return null;
    final SyncRecord? record = SyncRecord.fromJson(json['r']);
    final DateTime? at = DateTime.tryParse('${json['at']}');
    final ConflictReason? reason = ConflictReason.values
        .where((ConflictReason r) => r.name == json['why'])
        .firstOrNull;
    if (record == null || at == null || reason == null) return null;
    return SyncConflict(
      record: record,
      reason: reason,
      at: at,
      needs: <SyncRecord>[
        if (json['needs'] case final List<Object?> needs)
          for (final Object? n in needs) ?SyncRecord.fromJson(n),
      ],
    );
  }
}

/// A record as another device sent it: its version and its contents.
@immutable
class IncomingRecord {
  const IncomingRecord({
    required this.record,
    required this.clocks,
    required this.stamp,
    this.base,
  });

  final SyncRecord record;
  final Map<String, int> clocks;
  final Stamp stamp;

  /// The version the sending device had after its last merge, when it
  /// kept one: what a change made here and one made there may both come
  /// from.
  final RecordBase? base;

  Map<String, Object?> toJson() => <String, Object?>{
    'k': record.toJson(),
    'c': clocks,
    's': '$stamp',
    if (base != null) 'b': base!.toJson(),
  };

  static IncomingRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final SyncRecord? record = SyncRecord.fromJson(json['k']);
    final Object? clocks = json['c'];
    final Stamp? stamp = Stamp.parse(json['s']);
    if (record == null || clocks is! Map || stamp == null) return null;
    return IncomingRecord(
      record: record,
      clocks: _clocks(clocks),
      stamp: stamp,
      base: RecordBase.fromJson(json['b']),
    );
  }
}

/// Gives a new version to every record that changed here since [metas]
/// were last updated: a new one, a changed one, and a tombstone for one
/// deleted. A record whose id was deleted for good is left to the merge:
/// it cannot come back under that id.
Map<String, RecordMeta> scan(
  Map<String, RecordMeta> metas,
  Map<String, SyncRecord> here, {
  required String device,
  required Stamp Function() tick,
}) {
  final Map<String, RecordMeta> out = Map<String, RecordMeta>.of(metas);
  for (final SyncRecord r in here.values) {
    final String h = contentHash(r.data!);
    final RecordMeta? m = metas[r.key];
    if (m == null) {
      out[r.key] = RecordMeta(
        clocks: <String, int>{device: 1},
        stamp: tick(),
        hash: h,
      );
    } else if (m.hash != h && !(m.deleted && deletionIsFinal(r.table))) {
      out[r.key] = m.changed(device, tick(), h);
    }
  }
  for (final MapEntry<String, RecordMeta> e in metas.entries) {
    if (!e.value.deleted && !here.containsKey(e.key)) {
      out[e.key] = e.value.changed(device, tick(), null);
    }
  }
  return out;
}

/// What a merge decided.
@immutable
class MergeResult {
  const MergeResult({
    required this.metas,
    required this.upserts,
    required this.deletes,
    required this.conflicts,
    this.joined = 0,
  });

  final Map<String, RecordMeta> metas;

  /// Records to write, as they came.
  final List<SyncRecord> upserts;

  /// Records to delete here.
  final List<SyncRecord> deletes;

  /// Versions that lost, to show the person.
  final List<SyncConflict> conflicts;

  /// Records changed on both devices that were joined field by field,
  /// with nothing left to show.
  final int joined;

  /// How many records change here.
  int get applied => upserts.length + deletes.length;
}

/// The later of two versions: by stamp, then by contents, so two devices
/// pick the same one even when their stamps tie.
bool _later(Stamp a, String? aHash, Stamp b, String? bHash) {
  final int byStamp = a.compareTo(b);
  if (byStamp != 0) return byStamp > 0;
  return (aHash ?? '').compareTo(bHash ?? '') > 0;
}

/// Whether [winner] had seen everything [loser] had: then nothing of the
/// loser is lost and there is nothing to show.
bool _sawAll(Map<String, int> winner, Map<String, int> loser) =>
    switch (compareClocks(winner, loser)) {
      Order.same || Order.after => true,
      _ => false,
    };

/// Merges [incoming] into what this device has: [metas] after a [scan],
/// and [here], its records as they are.
///
/// Every rule is a join, so devices end the same whatever order files come
/// in, and a file merged again changes nothing:
///
/// - a record with a random id that either side deleted stays deleted;
/// - a record changed on both sides from a version both had is joined
///   field by field, when no field changed on both to different values;
/// - otherwise the later version wins, by its stamp, which the clocks keep
///   after anything a device had seen when it made the change;
/// - clocks are joined, to tell what each side had seen.
///
/// A version that loses with something the winner never saw becomes a
/// [SyncConflict]. A movement whose account is gone goes with it, kept
/// here as a conflict when it was not deleted on both sides.
MergeResult merge({
  required Map<String, RecordMeta> metas,
  required Map<String, SyncRecord> here,
  required List<IncomingRecord> incoming,
  required String device,
  required Stamp Function() tick,
  required DateTime now,
}) {
  final Map<String, RecordMeta> out = Map<String, RecordMeta>.of(metas);
  final Map<String, SyncRecord> upserts = <String, SyncRecord>{};
  final Map<String, SyncRecord> deletes = <String, SyncRecord>{};
  final List<SyncConflict> conflicts = <SyncConflict>[];
  var joined = 0;
  final Map<String, SyncRecord> sent = <String, SyncRecord>{
    for (final IncomingRecord i in incoming) i.record.key: i.record,
  };

  void lost(SyncRecord? record, ConflictReason reason) {
    if (record == null || record.deleted) return;
    conflicts.add(SyncConflict(record: record, reason: reason, at: now));
  }

  for (final IncomingRecord i in incoming) {
    final SyncRecord theirs = i.record;
    final String key = theirs.key;
    final RecordMeta? local = metas[key];
    final String? theirHash = theirs.deleted ? null : contentHash(theirs.data!);
    if (local == null) {
      out[key] = RecordMeta(clocks: i.clocks, stamp: i.stamp, hash: theirHash);
      if (!theirs.deleted) upserts[key] = theirs;
      continue;
    }
    final Map<String, int> clocks = _join(local.clocks, i.clocks);
    if (deletionIsFinal(theirs.table) && (local.deleted || theirs.deleted)) {
      // Deleted for good: the tombstone with the latest stamp names it.
      final Stamp stamp = local.deleted && theirs.deleted
          ? (i.stamp > local.stamp ? i.stamp : local.stamp)
          : (local.deleted ? local.stamp : i.stamp);
      out[key] = RecordMeta(clocks: clocks, stamp: stamp, hash: null);
      if (!local.deleted) {
        deletes[key] = SyncRecord(theirs.table, theirs.id, null);
        if (!_sawAll(i.clocks, local.clocks)) {
          lost(here[key], ConflictReason.deletedElsewhere);
        }
      } else if (!theirs.deleted && !_sawAll(local.clocks, i.clocks)) {
        lost(theirs, ConflictReason.deletedHere);
      }
      continue;
    }
    // Changed on both sides from a version both had: joined field by
    // field, as a change of this device's, when no field changed on both.
    final SyncRecord? mine = here[key];
    if (!theirs.deleted &&
        !local.deleted &&
        mine != null &&
        theirHash != local.hash &&
        compareClocks(local.clocks, i.clocks) == Order.concurrent) {
      final RecordBase? base = commonBase(
        local.base,
        i.base,
        ours: local.clocks,
        theirs: i.clocks,
      );
      final Map<String, Object?>? both = base == null
          ? null
          : joinFields(theirs.table, mine.data!, theirs.data!, base);
      if (both != null) {
        final SyncRecord record = SyncRecord(theirs.table, theirs.id, both);
        final String h = contentHash(both);
        out[key] = RecordMeta(
          clocks: clocks,
          stamp: local.stamp,
          hash: local.hash,
        ).changed(device, tick(), h);
        if (h != local.hash) upserts[key] = record;
        joined++;
        continue;
      }
    }
    final bool theyWin = _later(i.stamp, theirHash, local.stamp, local.hash);
    final bool same = theirHash == local.hash;
    out[key] = theyWin
        ? RecordMeta(clocks: clocks, stamp: i.stamp, hash: theirHash)
        : RecordMeta(clocks: clocks, stamp: local.stamp, hash: local.hash);
    if (same) continue;
    if (theyWin) {
      if (theirs.deleted) {
        deletes[key] = SyncRecord(theirs.table, theirs.id, null);
      } else {
        upserts[key] = theirs;
      }
      if (!_sawAll(i.clocks, local.clocks)) {
        lost(
          here[key],
          theirs.deleted
              ? ConflictReason.deletedElsewhere
              : ConflictReason.editedBoth,
        );
      }
    } else if (!_sawAll(local.clocks, i.clocks)) {
      lost(
        theirs,
        local.deleted ? ConflictReason.deletedHere : ConflictReason.editedBoth,
      );
    }
  }

  // Movements go with their account. Those that would be left without one
  // are deleted everywhere and kept here, with the account, to restore.
  bool accountGone(String? id) {
    if (id == null) return false;
    final String key = 'accounts/$id';
    if (upserts.containsKey(key)) return false;
    if (deletes.containsKey(key)) return true;
    final RecordMeta? m = out[key];
    return m == null || m.deleted;
  }

  final List<SyncRecord> entries = <SyncRecord>[
    for (final SyncRecord r in here.values)
      if (r.table == 'entries' &&
          !deletes.containsKey(r.key) &&
          !upserts.containsKey(r.key))
        r,
    for (final SyncRecord r in upserts.values)
      if (r.table == 'entries') r,
  ];
  for (final SyncRecord e in entries) {
    final String? account = e.data?['accountId'] as String?;
    if (!accountGone(account)) continue;
    final SyncRecord? owner = account == null
        ? null
        : here['accounts/$account'] ?? sent['accounts/$account'];
    conflicts.add(
      SyncConflict(
        record: e,
        reason: ConflictReason.withAccount,
        at: now,
        needs: <SyncRecord>[?owner],
      ),
    );
    upserts.remove(e.key);
    final RecordMeta base =
        out[e.key] ??
        RecordMeta(clocks: const <String, int>{}, stamp: tick(), hash: null);
    out[e.key] = base.changed(device, tick(), null);
    if (here.containsKey(e.key)) {
      deletes[e.key] = SyncRecord(e.table, e.id, null);
    }
  }

  return MergeResult(
    metas: out,
    upserts: upserts.values.toList(),
    deletes: deletes.values.toList(),
    conflicts: conflicts,
    joined: joined,
  );
}
