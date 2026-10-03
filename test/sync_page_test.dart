import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/sync_service.dart';
import 'package:quincena/sync/vault.dart';
import 'package:quincena/ui/own/sync_page.dart';

import 'own_flow_test.dart' show settle;
import 'page_harness.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  testWidgets('starting shows the code, and stopping forgets it', (
    tester,
  ) async {
    final MemoryKeyStore keys = MemoryKeyStore();
    await openPage(
      tester,
      (OwnController own) => SyncPage(own: own, keys: keys),
    );
    expect(find.textContaining('Quincena no lo recibe'), findsOneWidget);
    expect(find.textContaining('no es un respaldo'), findsOneWidget);

    await tapText(tester, 'Empezar en este dispositivo');
    final String code = VaultKey(
      (await tester.runAsync<List<int>?>(keys.read))!,
    ).code;
    for (final String group in code.split('-')) {
      expect(find.text(group), findsWidgets);
    }
    expect(find.textContaining('ni siquiera Quincena'), findsOneWidget);
    await tapText(tester, 'Listo');
    expect(find.text('Guardar mis cambios en un archivo'), findsOneWidget);

    await tapText(tester, 'Dejar de sincronizar');
    await tapText(tester, 'Dejar de sincronizar');
    expect(await tester.runAsync<List<int>?>(keys.read), isNull);
    expect(find.text('Empezar en este dispositivo'), findsOneWidget);
  });

  testWidgets('joining checks the code before trusting it', (tester) async {
    final MemoryKeyStore keys = MemoryKeyStore();
    await openPage(
      tester,
      (OwnController own) => SyncPage(own: own, keys: keys),
    );
    final String code = VaultKey.generate(Random(3)).code;
    await tapText(tester, 'Unir este dispositivo');
    // One character changed.
    final String typo =
        '${code.substring(0, 2)}${code[2] == 'A' ? 'B' : 'A'}${code.substring(3)}';
    await tester.enterText(find.byType(TextField), typo);
    await tapText(tester, 'Unir');
    expect(find.textContaining('El código no cuadra'), findsOneWidget);
    expect(await tester.runAsync<List<int>?>(keys.read), isNull);

    await tester.enterText(find.byType(TextField), code.toLowerCase());
    await tapText(tester, 'Unir');
    expect(find.textContaining('Ahora abre un archivo'), findsOneWidget);
    expect(
      VaultKey((await tester.runAsync<List<int>?>(keys.read))!).code,
      code,
    );
  });

  testWidgets('a change that lost waits, and comes back with a touch', (
    tester,
  ) async {
    final MemoryKeyStore keys = MemoryKeyStore();
    late QuincenaStore other;
    final OwnController own = await openPage(
      tester,
      (OwnController own) => SyncPage(own: own, keys: keys),
      data: (QuincenaStore store, Account bank, _) async {
        final SyncService here = SyncService(
          store,
          keys: keys,
          now: () => pageNow,
        );
        other = QuincenaStore(
          QuincenaDatabase(NativeDatabase.memory()),
          now: () => pageNow.add(const Duration(hours: 1)),
        );
        final SyncService there = SyncService(
          other,
          keys: MemoryKeyStore(),
          now: () => pageNow.add(const Duration(hours: 1)),
        );
        await other.ensureCategories();
        await there.join(await here.start());
        final Entry lunch = await store.addEntry(
          accountId: bank.id,
          amount: Decimal.parse('30000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 3),
          category: 'restaurants',
          payee: 'Almuerzo',
        );
        await there.import(await here.export());
        // Changed on both; the other device's change is the later one.
        await store.updateEntry(lunch.copyWith(payee: 'Almuerzo con Juan'));
        final Entry theirs = (await other.entries()).firstWhere(
          (Entry e) => e.id == lunch.id,
        );
        await other.updateEntry(theirs.copyWith(note: 'Con factura'));
        await here.import(await there.export());
      },
    );
    addTearDown(() => tester.runAsync(other.close));
    expect(find.text('PARA REVISAR'), findsOneWidget);
    await reveal(tester, find.text('Traer de vuelta'));
    expect(find.text('Almuerzo con Juan · −\$30.000'), findsOneWidget);
    Entry lunch() => own.snapshot!.entries.firstWhere(
      (Entry e) => e.category == 'restaurants',
    );
    expect(lunch().payee, 'Almuerzo');

    await tapText(tester, 'Traer de vuelta');
    await settle(tester);
    expect(lunch().payee, 'Almuerzo con Juan');
    // What it replaced now waits in its place: nothing is lost either way.
    await reveal(
      tester,
      find.textContaining('Lo que había antes de traer de vuelta'),
    );
    expect(
      find.textContaining('Lo que había antes de traer de vuelta'),
      findsOneWidget,
    );
  });
}
