import 'package:drift/drift.dart';

part 'database.g.dart';

// Amounts are stored as decimal text in the account's own asset, signed:
// negative when money leaves the account. Text, because a crypto balance
// needs more precision than a double keeps and SQLite has no decimal type.

/// Where money is kept: a bank account, a card, cash, a wallet, an exchange.
@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `bank`, `card`, `cash`, `wallet`, `exchange`, `investment`, `other`.
  TextColumn get kind => text()();

  /// The asset it holds: `COP`, `USD`, `USDT`.
  TextColumn get asset => text()();
  TextColumn get institution => text().withDefault(const Constant(''))();
  TextColumn get openingBalance => text().withDefault(const Constant('0'))();

  /// What the opening balance cost, in [openingCostAsset], when it is known:
  /// the pesos paid for the bitcoin an account started with. Null when the
  /// person did not say, and for money that is not an investment.
  TextColumn get openingCost => text().nullable()();
  TextColumn get openingCostAsset => text().nullable()();

  /// What keeps the account in sync, such as `binance:BTC`; null for the
  /// accounts the person keeps by hand.
  TextColumn get syncRef => text().nullable()();

  /// A credit card's limit, in its asset, when the person gave it; null
  /// otherwise, and for every account that is not a card.
  TextColumn get creditLimit => text().nullable()();

  /// Whether its money counts as available to spend before payday. Savings,
  /// investments and crypto usually do not.
  BoolColumn get spendable => boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Where a payment went or where income came from.
///
/// The built-in categories keep the stable English keys the agent reads and
/// writes (`groceries`, `restaurants`), with names from the app's
/// translations. A category the person adds gets a key of its own and a name.
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get key => text()();

  /// Null for a built-in category, which is named by the app.
  TextColumn get name => text().nullable()();

  /// `expense` or `income`.
  TextColumn get kind => text()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// One line of an account: a payment, an income, one leg of a transfer.
@DataClassName('EntryRow')
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// Signed, in the account's asset.
  TextColumn get amount => text()();
  DateTimeColumn get date => dateTime()();

  /// `expense`, `income`, `transfer` or `adjustment`.
  TextColumn get kind => text()();
  TextColumn get category => text().nullable()();
  TextColumn get payee => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Shared by both legs of a transfer between the person's own accounts.
  TextColumn get transferId => text().nullable()();

  /// How it got here: `manual`, `wallet`, `notification`, `sms`, `email`,
  /// `statement`, `binance`, `import`.
  TextColumn get source => text().withDefault(const Constant('manual'))();

  /// The inbox item or external id it came from, to never import it twice.
  TextColumn get sourceRef => text().nullable()();

  /// What was paid for what came in, or received for what went out, in
  /// [costAsset], when the other side is not one of the person's accounts:
  /// the pesos a bitcoin bought on Binance P2P cost. Null otherwise; a
  /// transfer's cost is its other leg.
  TextColumn get cost => text().nullable()();
  TextColumn get costAsset => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A charge that repeats: rent, a subscription, a loan installment.
@DataClassName('RecurringRow')
class Recurrings extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get accountId => text().nullable()();

  /// Positive, in [asset].
  TextColumn get amount => text()();
  TextColumn get asset => text()();
  TextColumn get category => text().nullable()();

  /// `monthly`, `biweekly`, `weekly` or `yearly`.
  TextColumn get cadence => text()();

  /// The next day it is charged.
  DateTimeColumn get nextDate => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Money being put aside for one thing.
@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get asset => text()();
  TextColumn get target => text()();
  TextColumn get saved => text().withDefault(const Constant('0'))();

  /// What goes into it every month today.
  TextColumn get monthly => text().withDefault(const Constant('0'))();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A monthly limit for a category, in the base currency.
@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get category => text()();
  TextColumn get amount => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{category};
}

/// Something that arrived from outside and may be a movement: an Apple Pay
/// payment, a bank's notification, an SMS, a line of a statement.
@DataClassName('InboxRow')
class InboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()();
  DateTimeColumn get receivedAt => dateTime()();

  /// Everything the source sent, as JSON. The source of truth: a better
  /// parser can read it again.
  TextColumn get raw => text()();

  /// What the parser read from it, as JSON, or null when it read nothing.
  TextColumn get parsed => text().nullable()();

  /// `new`, `accepted`, `dismissed` or `duplicate`.
  TextColumn get status => text().withDefault(const Constant('new'))();
  TextColumn get entryId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The latest known value of one unit of [asset] in [quote].
@DataClassName('RateRow')
class Rates extends Table {
  TextColumn get asset => text()();
  TextColumn get quote => text()();
  TextColumn get value => text()();
  DateTimeColumn get asOf => dateTime()();
  TextColumn get source => text()();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{asset, quote};
}

/// What one unit of [asset] was worth in [quote] on a past [day]: the TRM of
/// the day a bitcoin was bought, to know what it cost in dollars too.
@DataClassName('DailyRateRow')
class DailyRates extends Table {
  TextColumn get asset => text()();
  TextColumn get quote => text()();

  /// Midnight, local time, of the day the rate was in force.
  DateTimeColumn get day => dateTime()();
  TextColumn get value => text()();
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{asset, quote, day};
}

/// The person's choices: name, base currency, pay schedule.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DriftDatabase(
  tables: <Type>[
    Accounts,
    Categories,
    Entries,
    Recurrings,
    Goals,
    Budgets,
    InboxItems,
    Rates,
    DailyRates,
    Settings,
  ],
)
class QuincenaDatabase extends _$QuincenaDatabase {
  QuincenaDatabase(super.executor);

  /// 2 adds what investments cost (an account's opening cost, a movement's
  /// cost), the accounts kept in sync, and past daily rates. 3 adds a
  /// credit card's limit.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(accounts, accounts.openingCost);
        await m.addColumn(accounts, accounts.openingCostAsset);
        await m.addColumn(accounts, accounts.syncRef);
        await m.addColumn(entries, entries.cost);
        await m.addColumn(entries, entries.costAsset);
        await m.createTable(dailyRates);
      }
      if (from < 3) {
        await m.addColumn(accounts, accounts.creditLimit);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
