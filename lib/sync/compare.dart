import 'package:flutter/foundation.dart' show immutable;

import 'merge.dart';

/// Something a person reads in a record, made of the data's [keys], which
/// are taken together when two versions are combined: an amount means
/// nothing without its kind and its account's currency.
@immutable
class SyncField {
  const SyncField(this.name, this.keys);

  /// What it is: `payee`, `money`, `category`, `date`, `note`, `name`,
  /// `institution`, `opening`, `limit`, `cadence`, `next`, `account`,
  /// `state`, `target`, `saved`, `monthly` or `deadline`.
  final String name;
  final List<String> keys;
}

/// The fields of a record of [table] that a person reads, in the order a
/// screen shows them. Empty for what is not compared field by field: the
/// settings, the items of a list, categories and rates.
List<SyncField> fieldsOf(String table) => switch (table) {
  'entries' => const <SyncField>[
    SyncField('payee', <String>['payee']),
    SyncField('money', <String>['amount', 'kind', 'accountId']),
    SyncField('category', <String>['category']),
    SyncField('date', <String>['date']),
    SyncField('note', <String>['note']),
  ],
  'accounts' => const <SyncField>[
    SyncField('name', <String>['name']),
    SyncField('institution', <String>['institution']),
    SyncField('opening', <String>['openingBalance']),
    SyncField('limit', <String>['creditLimit']),
  ],
  'recurring' => const <SyncField>[
    SyncField('name', <String>['name']),
    SyncField('money', <String>['amount', 'asset']),
    SyncField('cadence', <String>['cadence']),
    SyncField('next', <String>['nextDate']),
    SyncField('account', <String>['accountId']),
    SyncField('state', <String>['active']),
  ],
  'goals' => const <SyncField>[
    SyncField('name', <String>['name']),
    SyncField('target', <String>['target', 'asset']),
    SyncField('saved', <String>['saved']),
    SyncField('monthly', <String>['monthly']),
    SyncField('deadline', <String>['deadline']),
  ],
  _ => const <SyncField>[],
};

/// How a [field] stands in two versions of one record.
@immutable
class FieldDiff {
  const FieldDiff(this.field, {required this.differs, required this.free});

  final SyncField field;
  final bool differs;

  /// Whether it can be taken from one version alone: one leg of a transfer
  /// cannot change its amount, account or date without the other.
  final bool free;
}

/// The version that stayed, [kept], beside the one that waits, [waiting],
/// field by field. Empty for a record not compared that way.
List<FieldDiff> compareVersions(SyncRecord kept, SyncRecord waiting) {
  final bool leg =
      kept.data?['transferId'] != null || waiting.data?['transferId'] != null;
  return <FieldDiff>[
    for (final SyncField f in fieldsOf(kept.table))
      FieldDiff(
        f,
        differs: f.keys.any(
          (String k) => '${kept.data?[k]}' != '${waiting.data?[k]}',
        ),
        free: !(leg && (f.name == 'money' || f.name == 'date')),
      ),
  ];
}

/// What combining writes: [kept] with the fields in [take] as [waiting]
/// has them, and the rest as it was.
Map<String, Object?> combineVersions(
  SyncRecord kept,
  SyncRecord waiting,
  Iterable<SyncField> take,
) => <String, Object?>{
  ...?kept.data,
  for (final SyncField f in take)
    for (final String k in f.keys) k: waiting.data?[k],
};
