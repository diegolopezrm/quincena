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
/// changed, and a hash of its contents, null once deleted.
@immutable
class RecordMeta {
  const RecordMeta({required this.clocks, required this.stamp, this.hash});

  final Map<String, int> clocks;
  final Stamp stamp;
  final String? hash;

  bool get deleted => hash == null;

  /// This record changed here: one more change by [device].
  RecordMeta changed(String device, Stamp stamp, String? hash) => RecordMeta(
    clocks: <String, int>{...clocks, device: (clocks[device] ?? 0) + 1},
    stamp: stamp,
    hash: hash,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'c': clocks,
    's': '$stamp',
    if (hash != null) 'h': hash,
  };

  static RecordMeta? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? clocks = json['c'];
    final Stamp? stamp = Stamp.parse(json['s']);
    if (clocks is! Map || stamp == null) return null;
    return RecordMeta(
      clocks: <String, int>{
        for (final MapEntry<Object?, Object?> e in clocks.entries)
          if (e.value is int) '${e.key}': e.value! as int,
      },
      stamp: stamp,
      hash: json['h'] as String?,
    );
  }
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
  });

  final SyncRecord record;
  final Map<String, int> clocks;
  final Stamp stamp;

  Map<String, Object?> toJson() => <String, Object?>{
    'k': record.toJson(),
    'c': clocks,
    's': '$stamp',
  };

  static IncomingRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final SyncRecord? record = SyncRecord.fromJson(json['k']);
    final Object? clocks = json['c'];
    final Stamp? stamp = Stamp.parse(json['s']);
    if (record == null || clocks is! Map || stamp == null) return null;
    return IncomingRecord(
      record: record,
      clocks: <String, int>{
        for (final MapEntry<Object?, Object?> e in clocks.entries)
          if (e.value is int) '${e.key}': e.value! as int,
      },
      stamp: stamp,
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
  });

  final Map<String, RecordMeta> metas;

  /// Records to write, as they came.
  final List<SyncRecord> upserts;

  /// Records to delete here.
  final List<SyncRecord> deletes;

  /// Versions that lost, to show the person.
  final List<SyncConflict> conflicts;

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
  );
}
