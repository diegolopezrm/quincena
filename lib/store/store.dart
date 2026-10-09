import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../capture/event.dart';
import '../capture/inbox.dart';
import '../domain/categories.dart';
import '../domain/records.dart';
import '../sync/merge.dart' show SyncRecord;
import '../money/asset.dart';
import '../money/money.dart';
import '../money/rates.dart';
import '../capture/parser.dart';
import 'database.dart';

/// Why a file could not be imported. Nothing was changed.
enum ImportProblem {
  /// Not a file Quincena exported.
  notQuincena,

  /// Exported by a newer version than this one.
  newer,

  /// Cut short, edited by hand, or otherwise unreadable.
  damaged,
}

/// An import that was refused, or rolled back halfway; the data the app
/// had is still there.
class ImportException extends FormatException {
  const ImportException(this.problem, [super.message]);

  final ImportProblem problem;
}

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
  ///
  /// 2 adds what investments cost; a file of version 1 reads as before,
  /// with no costs. 3 adds a credit card's limit; a file of version 2 reads
  /// as before, with no limits.
  static const int exportVersion = 3;

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
    openingCost: _money(r.openingCost, r.openingCostAsset),
    syncRef: r.syncRef,
    balanceSince: r.createdAt,
    creditLimit: switch (r.creditLimit) {
      final String limit => Decimal.parse(limit),
      null => null,
    },
  );

  /// The amount stored as [amount] in [asset], when both are there.
  static Money? _money(String? amount, String? asset) =>
      amount == null || asset == null
      ? null
      : Money.parse(amount, Asset.of(asset));

  Future<Account> addAccount({
    required String name,
    required AccountKind kind,
    required Asset asset,
    Decimal? opening,
    String institution = '',
    bool? spendable,
    Money? openingCost,
    String? syncRef,
    Decimal? creditLimit,
  }) async {
    final String id = _newId();
    final int order = (await accounts(archived: true)).length;
    final DateTime now = _now();
    final Account account = Account(
      id: id,
      name: name.trim(),
      kind: kind,
      asset: asset,
      opening: opening ?? Decimal.zero,
      institution: institution.trim(),
      spendable: spendable ?? kind.spendableByDefault,
      sortOrder: order,
      openingCost: openingCost,
      syncRef: syncRef,
      balanceSince: now,
      creditLimit: creditLimit,
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
            openingCost: Value(openingCost?.amount.toString()),
            openingCostAsset: Value(openingCost?.asset.code),
            syncRef: Value(syncRef),
            creditLimit: Value(creditLimit?.toString()),
            createdAt: now,
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
          openingCost: Value(account.openingCost?.amount.toString()),
          openingCostAsset: Value(account.openingCost?.asset.code),
          creditLimit: Value(account.creditLimit?.toString()),
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
    cost: _money(r.cost, r.costAsset),
  );

  /// Records an expense or an income. [amount] is how much, positive; the
  /// sign comes from [kind].
  ///
  /// [cost] makes it a purchase (an income) or a sale (an expense) of what
  /// the account holds: what was paid for it, or received.
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
    Money? cost,
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
      cost: cost?.abs(),
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
      cost: Value(e.cost?.amount.toString()),
      costAsset: Value(e.cost?.asset.code),
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
    String source = 'manual',
    String? sourceRef,
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
                source: source,
                sourceRef: sourceRef,
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
                source: source,
                sourceRef: sourceRef,
              ),
            ),
          );
    });
    return transferId;
  }

  /// Makes two movements already recorded the two legs of one transfer:
  /// [out] the money that left, [into] what arrived. Both keep their ids,
  /// dates and where they came from; neither keeps a category or a cost, as
  /// a transfer is neither spending nor a purchase from outside.
  Future<String> linkAsTransfer({
    required Entry out,
    required Entry into,
  }) async {
    final String transferId = _newId();
    await db.transaction(() async {
      for (final Entry e in <Entry>[out, into]) {
        await (db.update(db.entries)..where((r) => r.id.equals(e.id))).write(
          EntriesCompanion(
            kind: Value(EntryKind.transfer.name),
            transferId: Value(transferId),
            category: const Value(null),
            cost: const Value(null),
            costAsset: const Value(null),
            updatedAt: Value(_now()),
          ),
        );
      }
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
          cost: Value(entry.cost?.amount.toString()),
          costAsset: Value(entry.cost?.asset.code),
          updatedAt: Value(_now()),
        ),
      );

  /// Puts [entry] back as it was before it was deleted, its id included,
  /// so what pointed at it points at it again: how a deletion is undone
  /// while the person can still take it back.
  Future<void> restoreEntry(Entry entry) =>
      db.into(db.entries).insertOnConflictUpdate(_companion(entry));

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

  /// Saves [charge] over the one with its id: what it costs, how often, its
  /// next day, its account and category, and whether it is still on. What
  /// it already charged is not touched.
  Future<void> saveRecurring(RecurringCharge charge) =>
      (db.update(db.recurrings)..where((r) => r.id.equals(charge.id))).write(
        RecurringsCompanion(
          name: Value(charge.name.trim()),
          amount: Value(charge.amount.amount.abs().toString()),
          asset: Value(charge.amount.asset.code),
          cadence: Value(charge.cadence.name),
          nextDate: Value(charge.nextDate),
          accountId: Value(charge.accountId),
          category: Value(charge.category),
          active: Value(charge.active),
        ),
      );

  /// Moves the recurring charges paid from any of [from] to [to], or to
  /// no account in particular when null.
  Future<void> moveRecurring(Set<String> from, String? to) =>
      (db.update(db.recurrings)..where((r) => r.accountId.isIn(from))).write(
        RecurringsCompanion(accountId: Value(to)),
      );

  /// Changes what a recurring charge costs from now on.
  Future<void> updateRecurring(String id, {required Money amount}) =>
      (db.update(db.recurrings)..where((r) => r.id.equals(id))).write(
        RecurringsCompanion(
          amount: Value(amount.amount.toString()),
          asset: Value(amount.asset.code),
        ),
      );

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

  /// Saves [goal] over the one with its id.
  Future<void> updateGoal(SavingsGoal goal) async {
    await (db.update(db.goals)..where((g) => g.id.equals(goal.id))).write(
      GoalsCompanion(
        name: Value(goal.name.trim()),
        asset: Value(goal.target.asset.code),
        target: Value(goal.target.amount.toString()),
        saved: Value(goal.saved.amount.toString()),
        monthly: Value(goal.monthly.amount.toString()),
        deadline: Value(goal.deadline),
      ),
    );
  }

  Future<void> deleteGoal(String id) =>
      (db.delete(db.goals)..where((g) => g.id.equals(id))).go();

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

  /// Drops the rate the person typed for [asset] in [quote] and saves
  /// [fetched] in the same transaction, so the pair is never left without
  /// a rate in between.
  Future<void> restoreRate(
    String asset,
    String quote,
    Iterable<Rate> fetched,
  ) => db.transaction(() async {
    await setManualRate(asset, quote, null);
    await saveRates(fetched);
  });

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

  /// Past daily rates of [asset] in [quote], oldest first, from [from] on
  /// when given.
  Future<List<Rate>> dailyRates(
    String asset,
    String quote, {
    DateTime? from,
  }) async {
    final SimpleSelectStatement<$DailyRatesTable, DailyRateRow> q =
        db.select(db.dailyRates)
          ..where((r) => r.asset.equals(asset) & r.quote.equals(quote))
          ..orderBy(<OrderClauseGenerator<$DailyRatesTable>>[
            (r) => OrderingTerm(expression: r.day),
          ]);
    if (from != null) q.where((r) => r.day.isBiggerOrEqualValue(from));
    return <Rate>[
      for (final DailyRateRow r in await q.get())
        Rate(
          asset: r.asset,
          quote: r.quote,
          value: Decimal.parse(r.value),
          asOf: r.day,
          source: r.source,
        ),
    ];
  }

  /// Keeps past daily rates, each over what was there for its day.
  Future<void> saveDailyRates(Iterable<Rate> rates) => db.batch((Batch batch) {
    batch.insertAll(db.dailyRates, <DailyRatesCompanion>[
      for (final Rate r in rates)
        DailyRatesCompanion.insert(
          asset: r.asset,
          quote: r.quote,
          day: DateTime(r.asOf.year, r.asOf.month, r.asOf.day),
          value: r.value.toString(),
          source: r.source,
        ),
    ], mode: InsertMode.insertOrReplace);
  });

  // Capture -------------------------------------------------------------------

  static const String _captureKey = 'capture';

  Future<CaptureSettings> captureSettings() async {
    final String? json = await setting(_captureKey);
    return json == null
        ? const CaptureSettings()
        : CaptureSettings.fromJson(jsonDecode(json) as Map<String, Object?>);
  }

  Stream<CaptureSettings> watchCaptureSettings() =>
      (db.select(
        db.settings,
      )..where((s) => s.key.equals(_captureKey))).watchSingleOrNull().map(
        (SettingRow? row) => row == null
            ? const CaptureSettings()
            : CaptureSettings.fromJson(
                jsonDecode(row.value) as Map<String, Object?>,
              ),
      );

  Future<void> saveCaptureSettings(CaptureSettings settings) =>
      setSetting(_captureKey, jsonEncode(settings.toJson()));

  InboxItem _inbox(InboxRow r) {
    final ({
      ParsedCapture parsed,
      Suggestion suggestion,
      String? duplicateOf,
      bool automatic,
    })
    read = readParsedColumn(
      r.parsed == null
          ? const <String, Object?>{}
          : jsonDecode(r.parsed!) as Map<String, Object?>,
    );
    return InboxItem(
      id: r.id,
      event: CaptureEvent.fromJson(jsonDecode(r.raw) as Map<String, Object?>),
      parsed: read.parsed,
      suggestion: read.suggestion,
      status: InboxStatus.parse(r.status),
      entryId: r.entryId,
      duplicateOf: read.duplicateOf,
      automatic: read.automatic,
    );
  }

  /// A new id for an inbox item.
  String newInboxId() => _newId();

  Future<void> saveInboxItem(InboxItem item) => db
      .into(db.inboxItems)
      .insertOnConflictUpdate(
        InboxItemsCompanion.insert(
          id: item.id,
          source: item.event.source.name,
          receivedAt: item.event.at,
          raw: jsonEncode(item.event.toJson()),
          parsed: Value(jsonEncode(item.parsedJson())),
          status: Value(item.status.stored),
          entryId: Value(item.entryId),
        ),
      );

  /// Items in the inbox, newest first; only those in [statuses] when given.
  Stream<List<InboxItem>> watchInbox({Set<InboxStatus>? statuses}) =>
      _inboxQuery(
        statuses,
      ).watch().map((List<InboxRow> rows) => rows.map(_inbox).toList());

  Future<List<InboxItem>> inbox({
    Set<InboxStatus>? statuses,
    DateTime? since,
  }) async =>
      (await _inboxQuery(statuses, since: since).get()).map(_inbox).toList();

  SimpleSelectStatement<$InboxItemsTable, InboxRow> _inboxQuery(
    Set<InboxStatus>? statuses, {
    DateTime? since,
  }) {
    final SimpleSelectStatement<$InboxItemsTable, InboxRow> q =
        db.select(db.inboxItems)
          ..orderBy(<OrderClauseGenerator<$InboxItemsTable>>[
            (i) =>
                OrderingTerm(expression: i.receivedAt, mode: OrderingMode.desc),
          ]);
    if (statuses != null) {
      q.where((i) => i.status.isIn(statuses.map((InboxStatus s) => s.stored)));
    }
    if (since != null) q.where((i) => i.receivedAt.isBiggerOrEqualValue(since));
    return q;
  }

  Future<InboxItem?> inboxItem(String id) async {
    final InboxRow? row = await (db.select(
      db.inboxItems,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
    return row == null ? null : _inbox(row);
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
      // What the app learned and what the person follows; never a key,
      // which lives in the device's keychain.
      'settings': <String, Object?>{
        for (final String key in _exportedSettings)
          if (await setting(key) case final String value) key: value,
      },
    };
  }

  // Sync between devices ----------------------------------------------------

  /// The settings that sync: the profile and what an export carries.
  static const List<String> syncedSettings = <String>[
    _profileKey,
    ..._exportedSettings,
  ];

  /// Settings that hold a list of things with ids made at random, and the
  /// field the list is in ('' when the setting is the list). Each thing
  /// syncs apart, so changes to two of them on two devices both stay; one
  /// deleted stays deleted.
  static const Map<String, String> listSettings = <String, String>{
    'shared.groups': '',
    'trips': '',
    'commitments.instalments': '',
    'plan.wishes': '',
    'freelance': 'incomes',
  };

  /// Lists whose things are named by what they are, a scenario by its
  /// change: one saved again after being removed is the same thing, so the
  /// latest of them wins.
  static const Map<String, String> namedListSettings = <String, String>{
    'plan.scenarios': '',
  };

  /// Where the list of [key] is, if it is one.
  static String? listField(String key) =>
      listSettings[key] ?? namedListSettings[key];

  /// The setting a synced item belongs to, by the start of its id.
  static String? settingOfItem(String id) {
    for (final String key in syncedSettings) {
      if (id.startsWith('$key/')) return key;
    }
    return null;
  }

  /// Settings that map an id to something: each entry syncs apart.
  static const Set<String> mapSettings = <String>{
    'commitments.memories',
    'movements.notRepeated',
  };

  /// Every record that syncs between the person's devices, as stored.
  /// Captures waiting for review, fetched rates and what belongs to this
  /// device stay out.
  Future<List<SyncRecord>> syncRecords() async => <SyncRecord>[
    for (final AccountRow r in await db.select(db.accounts).get())
      SyncRecord('accounts', r.id, _accountRecord(r)),
    for (final CategoryRow r in await db.select(db.categories).get())
      SyncRecord('categories', r.key, r.toJson()),
    for (final EntryRow r in await db.select(db.entries).get())
      SyncRecord('entries', r.id, r.toJson()),
    for (final RecurringRow r in await db.select(db.recurrings).get())
      SyncRecord('recurring', r.id, r.toJson()),
    for (final GoalRow r in await db.select(db.goals).get())
      SyncRecord('goals', r.id, r.toJson()),
    for (final BudgetRow r in await db.select(db.budgets).get())
      SyncRecord('budgets', r.category, r.toJson()),
    for (final RateRow r in await db.select(db.rates).get())
      if (r.manual) SyncRecord('rates', '${r.asset}/${r.quote}', r.toJson()),
    for (final String key in syncedSettings)
      ..._settingRecords(key, await setting(key)),
  ];

  /// An account as it syncs. Without a credit limit it reads as it did
  /// before limits existed, so a device on either version takes it for
  /// the same account rather than a change.
  static Map<String, Object?> _accountRecord(AccountRow r) => <String, Object?>{
    for (final MapEntry<String, Object?> e in r.toJson().entries)
      if (e.key != 'creditLimit' || e.value != null) e.key: e.value,
  };

  /// A setting as records: the whole of it, or one per thing it lists, and
  /// what is left apart from the list.
  static List<SyncRecord> _settingRecords(String key, String? value) {
    if (value == null || value.isEmpty) return const <SyncRecord>[];
    final Object? json;
    try {
      json = jsonDecode(value);
    } on FormatException {
      return <SyncRecord>[
        SyncRecord('settings', key, <String, Object?>{'value': value}),
      ];
    }
    if (listField(key) case final String field) {
      final Object? list = field.isEmpty
          ? json
          : (json is Map ? json[field] : null);
      final String table = listSettings.containsKey(key) ? 'list' : 'item';
      return <SyncRecord>[
        if (list is List)
          for (final Object? item in list)
            if (item is Map && item['id'] is String)
              SyncRecord(
                table,
                '$key/${item['id']}',
                item.cast<String, Object?>(),
              ),
        if (field.isNotEmpty && json is Map)
          SyncRecord('settings', key, <String, Object?>{
            'json': <String, Object?>{
              for (final MapEntry<Object?, Object?> e in json.entries)
                if (e.key != field) '${e.key}': e.value,
            },
          }),
      ];
    }
    if (mapSettings.contains(key) && json is Map) {
      return <SyncRecord>[
        for (final MapEntry<Object?, Object?> e in json.entries)
          SyncRecord('map', '$key/${e.key}', <String, Object?>{'v': e.value}),
      ];
    }
    return <SyncRecord>[
      SyncRecord('settings', key, <String, Object?>{'json': json}),
    ];
  }

  /// Writes what a sync merge decided and [settings] alongside, all of it or
  /// nothing: deletions first, movements before their accounts; then the
  /// rest, accounts before their movements.
  Future<void> applySync({
    required List<SyncRecord> upserts,
    required List<SyncRecord> deletes,
    Map<String, String> settings = const <String, String>{},
  }) => db.transaction(() async {
    Iterable<SyncRecord> of(List<SyncRecord> list, String table) =>
        list.where((SyncRecord r) => r.table == table);
    for (final String table in <String>[
      'entries',
      'recurring',
      'goals',
      'budgets',
      'rates',
      'categories',
      'accounts',
    ]) {
      for (final SyncRecord r in of(deletes, table)) {
        await _deleteSynced(r);
      }
    }
    for (final String table in <String>[
      'categories',
      'accounts',
      'recurring',
      'goals',
      'budgets',
      'rates',
      'entries',
    ]) {
      for (final SyncRecord r in of(upserts, table)) {
        await _upsertSynced(r);
      }
    }
    bool aSetting(SyncRecord r) =>
        const <String>{'settings', 'list', 'item', 'map'}.contains(r.table);
    await _applySettings(
      upserts: <SyncRecord>[
        for (final SyncRecord r in upserts)
          if (aSetting(r)) r,
      ],
      deletes: <SyncRecord>[
        for (final SyncRecord r in deletes)
          if (aSetting(r)) r,
      ],
    );
    for (final MapEntry<String, String> e in settings.entries) {
      await setSetting(e.key, e.value);
    }
  });

  Future<void> _applySettings({
    required List<SyncRecord> upserts,
    required List<SyncRecord> deletes,
  }) async {
    final Set<String> touched = <String>{
      for (final SyncRecord r in <SyncRecord>[...upserts, ...deletes])
        if (r.table == 'settings') r.id else ?settingOfItem(r.id),
    };
    for (final String key in touched) {
      if (!syncedSettings.contains(key)) continue;
      SyncRecord? whole;
      final Map<String, SyncRecord?> items = <String, SyncRecord?>{};
      var dropWhole = false;
      for (final SyncRecord r in deletes) {
        if (r.table == 'settings' && r.id == key) dropWhole = true;
        if (r.table != 'settings' && r.id.startsWith('$key/')) {
          items[r.id.substring(key.length + 1)] = null;
        }
      }
      for (final SyncRecord r in upserts) {
        if (r.table == 'settings' && r.id == key) whole = r;
        if (r.table != 'settings' && r.id.startsWith('$key/')) {
          items[r.id.substring(key.length + 1)] = r;
        }
      }
      final String? current = await setting(key);
      Object? json;
      try {
        json = current == null || current.isEmpty ? null : jsonDecode(current);
      } on FormatException {
        json = null;
      }
      if (listField(key) case final String field) {
        final List<Object?> list = <Object?>[
          if ((field.isEmpty ? json : (json is Map ? json[field] : null))
              case final List<Object?> l)
            ...l,
        ];
        final Map<String, int> at = <String, int>{
          for (var i = 0; i < list.length; i++)
            if (list[i] case final Map<Object?, Object?> m
                when m['id'] is String)
              m['id']! as String: i,
        };
        final List<Object?> next = <Object?>[
          for (final Object? item in list)
            if (!(item is Map && items.containsKey(item['id'])))
              item
            else if (items[item['id']] case final SyncRecord r)
              r.data,
          for (final MapEntry<String, SyncRecord?> e in items.entries)
            if (!at.containsKey(e.key) && e.value != null) e.value!.data,
        ];
        if (field.isEmpty) {
          await setSetting(key, jsonEncode(next));
        } else {
          final Map<String, Object?> rest = switch (whole?.data?['json']) {
            final Map<Object?, Object?> m => m.cast<String, Object?>(),
            _ =>
              json is Map ? json.cast<String, Object?>() : <String, Object?>{},
          };
          await setSetting(
            key,
            jsonEncode(<String, Object?>{
              for (final MapEntry<String, Object?> e in rest.entries)
                if (e.key != field) e.key: e.value,
              field: next,
            }),
          );
        }
        continue;
      }
      if (mapSettings.contains(key)) {
        final Map<String, Object?> map = <String, Object?>{
          if (json is Map)
            for (final MapEntry<Object?, Object?> e in json.entries)
              '${e.key}': e.value,
        };
        for (final MapEntry<String, SyncRecord?> e in items.entries) {
          if (e.value == null) {
            map.remove(e.key);
          } else {
            map[e.key] = e.value!.data!['v'];
          }
        }
        await setSetting(key, jsonEncode(map));
        continue;
      }
      if (dropWhole && whole == null) {
        await (db.delete(db.settings)..where((t) => t.key.equals(key))).go();
      } else if (whole?.data case final Map<String, Object?> d) {
        await setSetting(
          key,
          d.containsKey('json') ? jsonEncode(d['json']) : '${d['value']}',
        );
      }
    }
  }

  Future<void> _deleteSynced(SyncRecord r) async {
    switch (r.table) {
      case 'accounts':
        await (db.delete(db.accounts)..where((t) => t.id.equals(r.id))).go();
      case 'categories':
        await (db.delete(db.categories)..where((t) => t.key.equals(r.id))).go();
      case 'entries':
        await (db.delete(db.entries)..where((t) => t.id.equals(r.id))).go();
      case 'recurring':
        await (db.delete(db.recurrings)..where((t) => t.id.equals(r.id))).go();
      case 'goals':
        await (db.delete(db.goals)..where((t) => t.id.equals(r.id))).go();
      case 'budgets':
        await (db.delete(
          db.budgets,
        )..where((t) => t.category.equals(r.id))).go();
      case 'rates':
        final List<String> pair = r.id.split('/');
        if (pair.length != 2) return;
        await (db.delete(db.rates)
              ..where((t) => t.asset.equals(pair[0]) & t.quote.equals(pair[1])))
            .go();
    }
  }

  /// Writes [r] whole, empty values included: what another device took
  /// away, such as a card's limit, goes here too. An upsert of the row as
  /// it reads would leave the old value wherever the new one is empty.
  Future<void> _upsertSynced(SyncRecord r) async {
    final Map<String, Object?>? d = r.data;
    if (d == null) return;
    switch (r.table) {
      case 'accounts':
        await db
            .into(db.accounts)
            .insertOnConflictUpdate(AccountRow.fromJson(d).toCompanion(false));
      case 'categories':
        await db
            .into(db.categories)
            .insertOnConflictUpdate(CategoryRow.fromJson(d).toCompanion(false));
      case 'entries':
        await db
            .into(db.entries)
            .insertOnConflictUpdate(EntryRow.fromJson(d).toCompanion(false));
      case 'recurring':
        await db
            .into(db.recurrings)
            .insertOnConflictUpdate(
              RecurringRow.fromJson(d).toCompanion(false),
            );
      case 'goals':
        await db
            .into(db.goals)
            .insertOnConflictUpdate(GoalRow.fromJson(d).toCompanion(false));
      case 'budgets':
        await db
            .into(db.budgets)
            .insertOnConflictUpdate(BudgetRow.fromJson(d).toCompanion(false));
      case 'rates':
        await db
            .into(db.rates)
            .insertOnConflictUpdate(RateRow.fromJson(d).toCompanion(false));
    }
  }

  /// How this device opens and what it shows outside the app: kept when an
  /// import replaces the data, never exported, never synced.
  static const List<String> deviceSettings = <String>[
    'app.mode',
    'app.theme',
    'app.language',
    'reminders.close',
    'widget.hideAmounts',
  ];

  /// The settings an export carries.
  static const List<String> _exportedSettings = <String>[
    _captureKey,
    'wallets',
    'plan.envelopes',
    'plan.wishes',
    'plan.cushion',
    'plan.scenarios',
    'commitments.memories',
    'commitments.instalments',
    'commitments.detective',
    // The pairs of movements the person said are not a repeat: they go
    // where the movements go.
    'movements.notRepeated',
    'shared.groups',
    'freelance',
    'trips',
    'setup.noFixed',
  ];

  /// Replaces everything with what [exportJson] wrote, or throws an
  /// [ImportException] and changes nothing: a file that breaks halfway is
  /// rolled back with the rest.
  Future<void> importJson(Map<String, Object?> json) async {
    checkExport(json);
    try {
      await _replaceWith(json);
    } on Object catch (e) {
      throw ImportException(ImportProblem.damaged, '$e');
    }
  }

  /// Throws an [ImportException] when [json] is not an export this app can
  /// read, before anyone is asked whether to replace what is here.
  static void checkExport(Map<String, Object?> json) {
    if (json['app'] != 'quincena') {
      throw const ImportException(
        ImportProblem.notQuincena,
        'This file was not exported by Quincena.',
      );
    }
    final Object? version = json['version'];
    if (version is! int || version < 1) {
      throw const ImportException(ImportProblem.damaged, 'No export version.');
    }
    if (version > exportVersion) {
      throw ImportException(
        ImportProblem.newer,
        'Export version $version is newer than this app.',
      );
    }
  }

  Future<void> _replaceWith(Map<String, Object?> json) async {
    List<Map<String, Object?>> rows(String key) => <Map<String, Object?>>[
      for (final Object? r
          in (json[key] as List<Object?>?) ?? const <Object?>[])
        (r! as Map).cast<String, Object?>(),
    ];
    await db.transaction(() async {
      // What belongs to this device and not to the data stays: no file
      // carries it.
      final Map<String, String> device = <String, String>{
        for (final String key in deviceSettings)
          if (await setting(key) case final String value) key: value,
      };
      await _wipeTables();
      for (final MapEntry<String, String> e in device.entries) {
        await setSetting(e.key, e.value);
      }
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
      final Object? settings = json['settings'];
      if (settings is Map) {
        for (final String key in _exportedSettings) {
          final Object? value = settings[key];
          if (value is String) await setSetting(key, value);
        }
      }
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
