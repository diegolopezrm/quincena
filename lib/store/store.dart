import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/categories.dart';
import '../domain/records.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
import 'database.dart';

/// Everything known about a person's money at one moment, for the screens
/// and the agent to compute from.
class StoreSnapshot {
  const StoreSnapshot({
    required this.profile,
    required this.accounts,
    required this.entries,
    required this.recurring,
    required this.goals,
    required this.rates,
    required this.categories,
  });

  final Profile profile;
  final List<Account> accounts;
  final List<Entry> entries;
  final List<RecurringCharge> recurring;
  final List<SavingsGoal> goals;
  final List<Rate> rates;
  final List<CategoryItem> categories;

  Account? account(String id) {
    for (final Account a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// The end of [day]: a movement dated any time that day is in its balance.
DateTime endOfDay(DateTime day) => DateTime(
  day.year,
  day.month,
  day.day + 1,
).subtract(const Duration(microseconds: 1));

/// What each account holds at the end of [asOf], in its own asset.
Map<String, Money> balancesOf(
  Iterable<Account> accounts,
  Iterable<Entry> entries,
  DateTime asOf,
) {
  final DateTime until = endOfDay(asOf);
  final Map<String, Decimal> totals = <String, Decimal>{
    for (final Account a in accounts) a.id: a.opening,
  };
  for (final Entry e in entries) {
    if (e.date.isAfter(until)) continue;
    final Decimal? total = totals[e.accountId];
    if (total != null) totals[e.accountId] = total + e.amount;
  }
  return <String, Money>{
    for (final Account a in accounts) a.id: Money(totals[a.id]!, a.asset),
  };
}

/// Reads and writes a person's money in the local database.
///
/// Nothing here leaves the device. The screens watch the streams, so a
/// movement saved anywhere shows everywhere.
class QuincenaStore {
  QuincenaStore(this.db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final QuincenaDatabase db;
  final DateTime Function() _now;

  static const Uuid _uuid = Uuid();
  String _newId() => _uuid.v4();

  static const String _profileKey = 'profile';

  /// The format [exportJson] writes. An import refuses a newer one.
  static const int exportVersion = 1;

  // Profile ------------------------------------------------------------------

  /// The person, or null before onboarding finished.
  Future<Profile?> profile() async {
    final String? json = await setting(_profileKey);
    return json == null ? null : _profileFrom(json);
  }

  Stream<Profile?> watchProfile() =>
      (db.select(
        db.settings,
      )..where((s) => s.key.equals(_profileKey))).watchSingleOrNull().map(
        (SettingRow? row) => row == null ? null : _profileFrom(row.value),
      );

  Profile _profileFrom(String json) =>
      Profile.fromJson(jsonDecode(json) as Map<String, Object?>);

  Future<void> saveProfile(Profile profile) =>
      setSetting(_profileKey, jsonEncode(profile.toJson()));

  Future<String?> setting(String key) async => (await (db.select(
    db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  // Categories ----------------------------------------------------------------

  /// Adds the built-in categories that are not there yet. Safe to call on
  /// every start.
  Future<void> ensureCategories() async {
    final List<String> keys = builtInCategoryKeys;
    await db.batch((Batch batch) {
      batch.insertAll(db.categories, <CategoriesCompanion>[
        for (var i = 0; i < keys.length; i++)
          CategoriesCompanion.insert(
            key: keys[i],
            kind: isIncomeCategory(keys[i]) ? 'income' : 'expense',
            sortOrder: Value(i),
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  Stream<List<CategoryItem>> watchCategories() =>
      (db.select(db.categories)
            ..orderBy(<OrderClauseGenerator<$CategoriesTable>>[
              (c) => OrderingTerm(expression: c.sortOrder),
            ]))
          .watch()
          .map((List<CategoryRow> rows) => rows.map(_category).toList());

  Future<List<CategoryItem>> categories() async =>
      (await (db.select(db.categories)
                ..orderBy(<OrderClauseGenerator<$CategoriesTable>>[
                  (c) => OrderingTerm(expression: c.sortOrder),
                ]))
              .get())
          .map(_category)
          .toList();

  CategoryItem _category(CategoryRow r) => CategoryItem(
    key: r.key,
    name: r.name,
    income: r.kind == 'income',
    archived: r.archived,
    sortOrder: r.sortOrder,
  );

  /// A category of the person's own.
  Future<CategoryItem> addCategory(String name, {bool income = false}) async {
    final String key = 'custom-${_newId().substring(0, 8)}';
    final int order = (await categories()).length;
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            key: key,
            name: Value(name.trim()),
            kind: income ? 'income' : 'expense',
            sortOrder: Value(order),
          ),
        );
    return CategoryItem(
      key: key,
      name: name.trim(),
      income: income,
      sortOrder: order,
    );
  }

  Future<void> renameCategory(String key, String name) =>
      (db.update(db.categories)..where((c) => c.key.equals(key))).write(
        CategoriesCompanion(name: Value(name.trim())),
      );

  Future<void> archiveCategory(String key, {bool archived = true}) =>
      (db.update(db.categories)..where((c) => c.key.equals(key))).write(
        CategoriesCompanion(archived: Value(archived)),
      );

  // Accounts ------------------------------------------------------------------

  Stream<List<Account>> watchAccounts({bool archived = false}) =>
      _accountsQuery(
        archived,
      ).watch().map((List<AccountRow> rows) => rows.map(_account).toList());

  Future<List<Account>> accounts({bool archived = false}) async =>
      (await _accountsQuery(archived).get()).map(_account).toList();

  SimpleSelectStatement<$AccountsTable, AccountRow> _accountsQuery(
    bool archived,
  ) {
    final SimpleSelectStatement<$AccountsTable, AccountRow> q =
        db.select(db.accounts)..orderBy(<OrderClauseGenerator<$AccountsTable>>[
          (a) => OrderingTerm(expression: a.sortOrder),
          (a) => OrderingTerm(expression: a.createdAt),
        ]);
    if (!archived) q.where((a) => a.archived.equals(false));
    return q;
  }

  Account _account(AccountRow r) => Account(
    id: r.id,
    name: r.name,
    kind: AccountKind.parse(r.kind),
    asset: Asset.of(r.asset),
    opening: Decimal.parse(r.openingBalance),
    institution: r.institution,
    spendable: r.spendable,
    archived: r.archived,
    sortOrder: r.sortOrder,
  );

  Future<Account> addAccount({
    required String name,
    required AccountKind kind,
    required Asset asset,
    Decimal? opening,
    String institution = '',
    bool? spendable,
  }) async {
    final String id = _newId();
    final int order = (await accounts(archived: true)).length;
    final Account account = Account(
      id: id,
      name: name.trim(),
      kind: kind,
      asset: asset,
      opening: opening ?? Decimal.zero,
      institution: institution.trim(),
      spendable: spendable ?? kind.spendableByDefault,
      sortOrder: order,
    );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            name: account.name,
            kind: kind.name,
            asset: asset.code,
            institution: Value(account.institution),
            openingBalance: Value(account.opening.toString()),
            spendable: Value(account.spendable),
            sortOrder: Value(order),
            createdAt: _now(),
          ),
        );
    return account;
  }

  /// Saves what can change about an account. Its asset cannot: the
  /// movements in it are written in that asset.
  Future<void> updateAccount(Account account) =>
      (db.update(db.accounts)..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(
          name: Value(account.name.trim()),
          kind: Value(account.kind.name),
          institution: Value(account.institution.trim()),
          openingBalance: Value(account.opening.toString()),
          spendable: Value(account.spendable),
          archived: Value(account.archived),
          sortOrder: Value(account.sortOrder),
        ),
      );

  /// Deletes the account and every movement in it. A transfer loses the leg
  /// in this account and keeps the other, now an ordinary movement.
  Future<void> deleteAccount(String id) => db.transaction(() async {
    final List<EntryRow> legs = await (db.select(
      db.entries,
    )..where((e) => e.accountId.equals(id) & e.transferId.isNotNull())).get();
    for (final EntryRow leg in legs) {
      await (db.update(db.entries)..where(
            (e) =>
                e.transferId.equals(leg.transferId!) &
                e.accountId.equals(id).not(),
          ))
          .write(
            EntriesCompanion(
              transferId: const Value(null),
              kind: Value(
                Decimal.parse(leg.amount) < Decimal.zero ? 'income' : 'expense',
              ),
            ),
          );
    }
    await (db.delete(db.entries)..where((e) => e.accountId.equals(id))).go();
    await (db.delete(db.accounts)..where((a) => a.id.equals(id))).go();
  });

  // Entries -------------------------------------------------------------------

  Stream<List<Entry>> watchEntries({String? accountId, int? limit}) =>
      _entriesQuery(
        accountId: accountId,
        limit: limit,
      ).watch().map((List<EntryRow> rows) => rows.map(_entry).toList());

  Future<List<Entry>> entries({String? accountId}) async =>
      (await _entriesQuery(accountId: accountId).get()).map(_entry).toList();

  SimpleSelectStatement<$EntriesTable, EntryRow> _entriesQuery({
    String? accountId,
    int? limit,
  }) {
    final SimpleSelectStatement<$EntriesTable, EntryRow> q =
        db.select(db.entries)..orderBy(<OrderClauseGenerator<$EntriesTable>>[
          (e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc),
          (e) => OrderingTerm(expression: e.createdAt, mode: OrderingMode.desc),
        ]);
    if (accountId != null) q.where((e) => e.accountId.equals(accountId));
    if (limit != null) q.limit(limit);
    return q;
  }

  Entry _entry(EntryRow r) => Entry(
    id: r.id,
    accountId: r.accountId,
    amount: Decimal.parse(r.amount),
    date: r.date,
    kind: EntryKind.parse(r.kind),
    category: r.category,
    payee: r.payee,
    note: r.note,
    transferId: r.transferId,
    source: r.source,
    sourceRef: r.sourceRef,
  );

  /// Records an expense or an income. [amount] is how much, positive; the
  /// sign comes from [kind].
  Future<Entry> addEntry({
    required String accountId,
    required Decimal amount,
    required EntryKind kind,
    required DateTime date,
    String? category,
    String payee = '',
    String note = '',
    String source = 'manual',
    String? sourceRef,
  }) async {
    assert(kind != EntryKind.transfer, 'Use addTransfer for transfers');
    final Decimal signed = kind == EntryKind.expense
        ? -amount.abs()
        : (kind == EntryKind.income ? amount.abs() : amount);
    final Entry entry = Entry(
      id: _newId(),
      accountId: accountId,
      amount: signed,
      date: date,
      kind: kind,
      category: category,
      payee: payee.trim(),
      note: note.trim(),
      source: source,
      sourceRef: sourceRef,
    );
    await db.into(db.entries).insert(_companion(entry));
    return entry;
  }

  EntriesCompanion _companion(Entry e) {
    final DateTime now = _now();
    return EntriesCompanion.insert(
      id: e.id,
      accountId: e.accountId,
      amount: e.amount.toString(),
      date: e.date,
      kind: e.kind.name,
      category: Value(e.category),
      payee: Value(e.payee),
      note: Value(e.note),
      transferId: Value(e.transferId),
      source: Value(e.source),
      sourceRef: Value(e.sourceRef),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Moves money between two of the person's accounts. When they hold
  /// different assets, [received] is what arrived: dollars sold at the
  /// bank's rate, not the TRM.
  Future<String> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required Decimal sent,
    Decimal? received,
    required DateTime date,
    String note = '',
  }) async {
    final String transferId = _newId();
    await db.transaction(() async {
      await db
          .into(db.entries)
          .insert(
            _companion(
              Entry(
                id: _newId(),
                accountId: fromAccountId,
                amount: -sent.abs(),
                date: date,
                kind: EntryKind.transfer,
                note: note.trim(),
                transferId: transferId,
              ),
            ),
          );
      await db
          .into(db.entries)
          .insert(
            _companion(
              Entry(
                id: _newId(),
                accountId: toAccountId,
                amount: (received ?? sent).abs(),
                date: date,
                kind: EntryKind.transfer,
                note: note.trim(),
                transferId: transferId,
              ),
            ),
          );
    });
    return transferId;
  }

  /// Rewrites both legs of the transfer [transferId] as one move from
  /// [fromAccountId] to [toAccountId].
  Future<void> updateTransfer(
    String transferId, {
    required String fromAccountId,
    required String toAccountId,
    required Decimal sent,
    Decimal? received,
    required DateTime date,
    String note = '',
  }) => db.transaction(() async {
    await (db.delete(
      db.entries,
    )..where((e) => e.transferId.equals(transferId))).go();
    for (final (String account, Decimal amount) in <(String, Decimal)>[
      (fromAccountId, -sent.abs()),
      (toAccountId, (received ?? sent).abs()),
    ]) {
      await db
          .into(db.entries)
          .insert(
            _companion(
              Entry(
                id: _newId(),
                accountId: account,
                amount: amount,
                date: date,
                kind: EntryKind.transfer,
                note: note.trim(),
                transferId: transferId,
              ),
            ),
          );
    }
  });

  Future<void> updateEntry(Entry entry) =>
      (db.update(db.entries)..where((e) => e.id.equals(entry.id))).write(
        EntriesCompanion(
          accountId: Value(entry.accountId),
          amount: Value(entry.amount.toString()),
          date: Value(entry.date),
          kind: Value(entry.kind.name),
          category: Value(entry.category),
          payee: Value(entry.payee.trim()),
          note: Value(entry.note.trim()),
          updatedAt: Value(_now()),
        ),
      );

  /// Deletes a movement; for a transfer, both of its legs.
  Future<void> deleteEntry(Entry entry) async {
    if (entry.transferId != null) {
      await (db.delete(
        db.entries,
      )..where((e) => e.transferId.equals(entry.transferId!))).go();
    } else {
      await (db.delete(db.entries)..where((e) => e.id.equals(entry.id))).go();
    }
  }

  // Balances ------------------------------------------------------------------

  /// What each account holds today, in its own asset, kept current.
  Stream<Map<String, Money>> watchBalances() {
    late StreamController<Map<String, Money>> out;
    List<Account>? accounts;
    List<Entry>? entries;
    final List<StreamSubscription<Object?>> subs =
        <StreamSubscription<Object?>>[];
    void emit() {
      if (accounts != null && entries != null) {
        out.add(balancesOf(accounts!, entries!, _now()));
      }
    }

    out = StreamController<Map<String, Money>>(
      onListen: () {
        subs
          ..add(
            watchAccounts(archived: true).listen((List<Account> a) {
              accounts = a;
              emit();
            }),
          )
          ..add(
            watchEntries().listen((List<Entry> e) {
              entries = e;
              emit();
            }),
          );
      },
      onCancel: () async {
        for (final StreamSubscription<Object?> s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }

  // Recurring charges and goals --------------------------------------------------

  Future<List<RecurringCharge>> recurring() async =>
      (await db.select(db.recurrings).get()).map(_recurring).toList();

  Stream<List<RecurringCharge>> watchRecurring() => db
      .select(db.recurrings)
      .watch()
      .map((List<RecurringRow> rows) => rows.map(_recurring).toList());

  RecurringCharge _recurring(RecurringRow r) => RecurringCharge(
    id: r.id,
    name: r.name,
    amount: Money.parse(r.amount, Asset.of(r.asset)),
    cadence: Cadence.parse(r.cadence),
    nextDate: r.nextDate,
    accountId: r.accountId,
    category: r.category,
    active: r.active,
    since: r.createdAt,
  );

  Future<RecurringCharge> addRecurring({
    required String name,
    required Money amount,
    required Cadence cadence,
    required DateTime nextDate,
    String? accountId,
    String? category,
  }) async {
    final String id = _newId();
    await db
        .into(db.recurrings)
        .insert(
          RecurringsCompanion.insert(
            id: id,
            name: name.trim(),
            amount: amount.amount.abs().toString(),
            asset: amount.asset.code,
            cadence: cadence.name,
            nextDate: nextDate,
            accountId: Value(accountId),
            category: Value(category),
            createdAt: _now(),
          ),
        );
    return RecurringCharge(
      id: id,
      name: name.trim(),
      amount: amount.abs(),
      cadence: cadence,
      nextDate: nextDate,
      accountId: accountId,
      category: category,
      since: _now(),
    );
  }

  Future<void> deleteRecurring(String id) =>
      (db.delete(db.recurrings)..where((r) => r.id.equals(id))).go();

  Future<List<SavingsGoal>> goals() async =>
      (await db.select(db.goals).get()).map(_goal).toList();

  SavingsGoal _goal(GoalRow r) {
    final Asset asset = Asset.of(r.asset);
    return SavingsGoal(
      id: r.id,
      name: r.name,
      target: Money.parse(r.target, asset),
      saved: Money.parse(r.saved, asset),
      monthly: Money.parse(r.monthly, asset),
      deadline: r.deadline,
    );
  }

  Future<SavingsGoal> addGoal({
    required String name,
    required Money target,
    Money? saved,
    Money? monthly,
    DateTime? deadline,
  }) async {
    final String id = _newId();
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            id: id,
            name: name.trim(),
            asset: target.asset.code,
            target: target.amount.toString(),
            saved: Value((saved?.amount ?? Decimal.zero).toString()),
            monthly: Value((monthly?.amount ?? Decimal.zero).toString()),
            deadline: Value(deadline),
            createdAt: _now(),
          ),
        );
    return SavingsGoal(
      id: id,
      name: name.trim(),
      target: target,
      saved: saved ?? Money.zero(target.asset),
      monthly: monthly ?? Money.zero(target.asset),
      deadline: deadline,
    );
  }

  // Rates ---------------------------------------------------------------------

  Future<List<Rate>> rates() async =>
      (await db.select(db.rates).get()).map(_rate).toList();

  Stream<List<Rate>> watchRates() => db
      .select(db.rates)
      .watch()
      .map((List<RateRow> rows) => rows.map(_rate).toList());

  Rate _rate(RateRow r) => Rate(
    asset: r.asset,
    quote: r.quote,
    value: Decimal.parse(r.value),
    asOf: r.asOf,
    source: r.source,
    manual: r.manual,
  );

  /// Saves fetched rates, except over a pair the person set by hand.
  Future<void> saveRates(Iterable<Rate> rates) async {
    final Set<String> manual = <String>{
      for (final Rate r in await this.rates())
        if (r.manual) r.pair,
    };
    final DateTime now = _now();
    await db.batch((Batch batch) {
      for (final Rate r in rates) {
        if (manual.contains(r.pair)) continue;
        batch.insert(
          db.rates,
          RatesCompanion.insert(
            asset: r.asset,
            quote: r.quote,
            value: r.value.toString(),
            asOf: r.asOf,
            source: r.source,
            fetchedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// A rate the person typed, which fetched ones never replace. Null clears
  /// it, so the next fetch fills the pair again.
  Future<void> setManualRate(String asset, String quote, Decimal? value) async {
    if (value == null) {
      await (db.delete(
        db.rates,
      )..where((r) => r.asset.equals(asset) & r.quote.equals(quote))).go();
      return;
    }
    final DateTime now = _now();
    await db
        .into(db.rates)
        .insertOnConflictUpdate(
          RatesCompanion.insert(
            asset: asset,
            quote: quote,
            value: value.toString(),
            asOf: DateTime(now.year, now.month, now.day),
            source: 'manual',
            manual: const Value(true),
            fetchedAt: now,
          ),
        );
  }

  /// When rates were last fetched, or null if never.
  Future<DateTime?> ratesFetchedAt() async {
    final List<RateRow> rows =
        await (db.select(db.rates)
              ..where((r) => r.manual.equals(false))
              ..orderBy(<OrderClauseGenerator<$RatesTable>>[
                (r) => OrderingTerm(
                  expression: r.fetchedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.fetchedAt;
  }

  // Snapshot ------------------------------------------------------------------

  /// Everything at once, for building the ledger the screens and the agent
  /// read. Null before onboarding.
  Future<StoreSnapshot?> snapshot() async {
    final Profile? profile = await this.profile();
    if (profile == null) return null;
    return StoreSnapshot(
      profile: profile,
      accounts: await accounts(archived: true),
      entries: await entries(),
      recurring: await recurring(),
      goals: await goals(),
      rates: await rates(),
      categories: await categories(),
    );
  }

  /// Fires whenever anything the snapshot reads changes.
  Stream<void> watchChanges() => db.tableUpdates().map((_) {});

  // Export, import, delete -------------------------------------------------------

  /// Everything the person entered, as one JSON document they can keep.
  Future<Map<String, Object?>> exportJson() async {
    final StoreSnapshot? s = await snapshot();
    return <String, Object?>{
      'app': 'quincena',
      'version': exportVersion,
      'exportedAt': _now().toIso8601String(),
      'profile': s?.profile.toJson(),
      'accounts': <Object?>[
        for (final AccountRow r in await db.select(db.accounts).get())
          r.toJson(),
      ],
      'categories': <Object?>[
        for (final CategoryRow r in await db.select(db.categories).get())
          if (r.name != null) r.toJson(),
      ],
      'entries': <Object?>[
        for (final EntryRow r in await db.select(db.entries).get()) r.toJson(),
      ],
      'recurring': <Object?>[
        for (final RecurringRow r in await db.select(db.recurrings).get())
          r.toJson(),
      ],
      'goals': <Object?>[
        for (final GoalRow r in await db.select(db.goals).get()) r.toJson(),
      ],
      'budgets': <Object?>[
        for (final BudgetRow r in await db.select(db.budgets).get()) r.toJson(),
      ],
      'rates': <Object?>[
        for (final RateRow r in await db.select(db.rates).get())
          if (r.manual) r.toJson(),
      ],
    };
  }

  /// Replaces everything with what [exportJson] wrote, or throws a
  /// [FormatException] and changes nothing.
  Future<void> importJson(Map<String, Object?> json) async {
    if (json['app'] != 'quincena') {
      throw const FormatException('This file was not exported by Quincena.');
    }
    final int version = (json['version'] as int?) ?? 0;
    if (version < 1 || version > exportVersion) {
      throw FormatException('Unsupported export version $version.');
    }
    List<Map<String, Object?>> rows(String key) => <Map<String, Object?>>[
      for (final Object? r
          in (json[key] as List<Object?>?) ?? const <Object?>[])
        (r! as Map).cast<String, Object?>(),
    ];
    await db.transaction(() async {
      await _wipeTables();
      await ensureCategories();
      final Object? profile = json['profile'];
      if (profile is Map) {
        await saveProfile(Profile.fromJson(profile.cast<String, Object?>()));
      }
      await db.batch((Batch batch) {
        batch
          ..insertAll(db.accounts, rows('accounts').map(AccountRow.fromJson))
          ..insertAll(
            db.categories,
            rows('categories').map(CategoryRow.fromJson),
            mode: InsertMode.insertOrReplace,
          )
          ..insertAll(db.entries, rows('entries').map(EntryRow.fromJson))
          ..insertAll(
            db.recurrings,
            rows('recurring').map(RecurringRow.fromJson),
          )
          ..insertAll(db.goals, rows('goals').map(GoalRow.fromJson))
          ..insertAll(db.budgets, rows('budgets').map(BudgetRow.fromJson))
          ..insertAll(db.rates, rows('rates').map(RateRow.fromJson));
      });
    });
  }

  /// Deletes everything, profile included: the app starts over.
  Future<void> wipe() => db.transaction(_wipeTables);

  Future<void> _wipeTables() async {
    for (final TableInfo<Table, Object?> table
        in db.allTables.toList().reversed) {
      await db.delete(table).go();
    }
  }

  Future<void> close() => db.close();
}
