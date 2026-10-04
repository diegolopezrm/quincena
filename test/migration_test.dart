import 'package:decimal/decimal.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

import 'generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every version upgrades to the schema the app declares', () async {
    for (final int from in GeneratedHelper.versions) {
      final QuincenaDatabase db = QuincenaDatabase(
        await verifier.startAt(from),
      );
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    }
  });

  test('upgrading from 1 keeps accounts and movements as they were', () async {
    final InitializedSchema schema = await verifier.schemaAt(1);
    // Written as version 1 wrote them: dates in seconds since the epoch.
    const int created = 1790000000;
    schema.rawDatabase
      ..execute(
        'INSERT INTO accounts (id, name, kind, asset, institution, '
        'opening_balance, spendable, archived, sort_order, created_at) '
        "VALUES ('btc', 'Bitcoin', 'exchange', 'BTC', 'Binance', '0.015', 0, "
        '0, 0, $created)',
      )
      ..execute(
        'INSERT INTO entries (id, account_id, amount, date, kind, payee, '
        "note, source, created_at, updated_at) VALUES ('e1', 'btc', '0.001', "
        "$created, 'income', '', '', 'manual', $created, $created)",
      );

    final QuincenaDatabase db = QuincenaDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final QuincenaStore store = QuincenaStore(db);
    final Account account = (await store.accounts()).single;
    expect(account.opening, Decimal.parse('0.015'));
    expect(account.openingCost, isNull);
    expect(account.creditLimit, isNull);
    final Entry entry = (await store.entries()).single;
    expect(entry.amount, Decimal.parse('0.001'));
    expect(entry.cost, isNull);
    await db.close();
  });
  test('upgrading from 2 keeps a card as it was, with no limit until one is '
      'given', () async {
    final InitializedSchema schema = await verifier.schemaAt(2);
    const int created = 1790000000;
    schema.rawDatabase.execute(
      'INSERT INTO accounts (id, name, kind, asset, institution, '
      'opening_balance, sync_ref, spendable, archived, sort_order, '
      "created_at) VALUES ('visa', 'Visa', 'card', 'COP', 'Bancolombia', "
      "'-300000', NULL, 1, 0, 0, $created)",
    );

    final QuincenaDatabase db = QuincenaDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final QuincenaStore store = QuincenaStore(db);
    final Account card = (await store.accounts()).single;
    expect(card.kind, AccountKind.card);
    expect(card.opening, Decimal.parse('-300000'));
    expect(card.spendable, isTrue);
    expect(card.creditLimit, isNull);

    // The new column takes a limit, and keeps it.
    await store.updateAccount(
      card.copyWith(creditLimit: Decimal.fromInt(2000000)),
    );
    expect(
      (await store.accounts()).single.creditLimit,
      Decimal.fromInt(2000000),
    );
    await db.close();
  });
}
