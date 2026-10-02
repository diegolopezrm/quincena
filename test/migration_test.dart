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
      await verifier.migrateAndValidate(db, 2);
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
    await verifier.migrateAndValidate(db, 2);
    final QuincenaStore store = QuincenaStore(db);
    final Account account = (await store.accounts()).single;
    expect(account.opening, Decimal.parse('0.015'));
    expect(account.openingCost, isNull);
    final Entry entry = (await store.entries()).single;
    expect(entry.amount, Decimal.parse('0.001'));
    expect(entry.cost, isNull);
    await db.close();
  });
}
