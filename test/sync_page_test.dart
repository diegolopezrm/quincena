import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/backup/backup.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/sync_service.dart';
import 'package:quincena/sync/vault.dart';
import 'package:quincena/ui/own/qr_code.dart';
import 'package:quincena/ui/own/scan_code.dart';
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
    // The other phone reads it with its camera.
    expect(tester.widget<QrCodeView>(find.byType(QrCodeView)).data, code);
    expect(
      find.text(
        'En el otro teléfono, toca «Escanear el código» y apunta aquí.',
      ),
      findsOneWidget,
    );
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

  testWidgets('joining reads the other phone\'s QR with the camera, and '
      'uses it at once', (tester) async {
    final MemoryKeyStore keys = MemoryKeyStore();
    await openPage(
      tester,
      (OwnController own) => SyncPage(own: own, keys: keys),
    );
    final String code = VaultKey.generate(Random(5)).code;
    debugScanCode = () async => code;
    addTearDown(() => debugScanCode = null);
    await tapText(tester, 'Unir este dispositivo');
    await tapText(tester, 'Escanear el código');
    expect(find.textContaining('Ahora abre un archivo'), findsOneWidget);
    expect(
      VaultKey((await tester.runAsync<List<int>?>(keys.read))!).code,
      code,
    );
  });

  testWidgets('a backup code pasted to join is named for what it is', (
    tester,
  ) async {
    final MemoryKeyStore keys = MemoryKeyStore();
    final MemoryBackupKeyStore backups = MemoryBackupKeyStore();
    final VaultKey backup = VaultKey.generate(Random(8));
    await tester.runAsync(() => backups.write(backup.bytes));
    await openPage(
      tester,
      (OwnController own) =>
          SyncPage(own: own, keys: keys, backupKeys: backups),
    );
    await tapText(tester, 'Unir este dispositivo');
    expect(find.text('Pegar'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Código de respaldo de Quincena: ${backup.code}',
    );
    await tapText(tester, 'Unir');
    expect(
      find.textContaining('Ese es tu código de respaldo, no el de sincronizar'),
      findsOneWidget,
    );
    expect(await tester.runAsync<List<int>?>(keys.read), isNull);

    // The vault's own code, with the words it was shared with, joins.
    final String code = VaultKey.generate(Random(9)).code;
    await tester.enterText(
      find.byType(TextField),
      'Código de Quincena para unir tus dispositivos: $code',
    );
    await tapText(tester, 'Unir');
    expect(
      VaultKey((await tester.runAsync<List<int>?>(keys.read))!).code,
      code,
    );
  });

  /// The page over a phone where a lunch was renamed while the other
  /// device, an hour ahead, named it otherwise and added it a note: the
  /// name changed on both, so the other's version shows whole and this one
  /// waits. [other] is the other device's store, closed after.
  Future<(OwnController, QuincenaStore, SyncService)> lunchChangedOnBoth(
    WidgetTester tester,
    MemoryKeyStore keys,
  ) async {
    late QuincenaStore other;
    late SyncService there;
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
        there = SyncService(
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
        await other.updateEntry(
          theirs.copyWith(payee: 'Almuerzo de trabajo', note: 'Con factura'),
        );
        await here.import(await there.export());
      },
    );
    addTearDown(() => tester.runAsync(other.close));
    return (own, other, there);
  }

  Entry lunchOf(OwnController own) => own.snapshot!.entries.firstWhere(
    (Entry e) => e.category == 'restaurants',
  );

  testWidgets('a change that lost waits beside the one that stayed, field by '
      'field, and comes back with a touch', (tester) async {
    final (OwnController own, _, _) = await lunchChangedOnBoth(
      tester,
      MemoryKeyStore(),
    );
    expect(find.text('PARA REVISAR'), findsOneWidget);
    await reveal(tester, find.text('Traer de vuelta'));
    // Named as it shows now, with both versions side by side.
    expect(
      find.text('Almuerzo de trabajo · −$signJoiner\$30.000'),
      findsOneWidget,
    );
    expect(find.text('Lo que quedó'), findsOneWidget);
    expect(find.text('Lo que espera'), findsOneWidget);
    final Table table = tester.widget<Table>(find.byType(Table));
    List<String> row(int i) => <String>[
      for (final Widget cell in table.children[i].children)
        if (cell is Padding) (cell.child! as Text).data!,
    ];
    expect(row(1), <String>[
      'Nombre',
      'Almuerzo de trabajo',
      'Almuerzo con Juan',
    ]);
    expect(row(5), <String>['Nota', 'Con factura', '—']);
    expect(row(3), <String>['Categoría', 'Restaurantes', 'Restaurantes']);
    // What differs is marked; what is the same is not.
    expect(
      <bool>[
        for (final TableRow r in table.children.skip(1)) r.decoration != null,
      ],
      <bool>[true, false, false, false, true],
    );
    expect(find.text('Combinar'), findsOneWidget);
    expect(lunchOf(own).payee, 'Almuerzo de trabajo');

    await tapText(tester, 'Traer de vuelta');
    await settle(tester);
    expect(lunchOf(own).payee, 'Almuerzo con Juan');
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

  testWidgets('combining keeps the name of one and the note of the other, '
      'as an edit the other device gets', (tester) async {
    final MemoryKeyStore keys = MemoryKeyStore();
    final (OwnController own, QuincenaStore other, SyncService there) =
        await lunchChangedOnBoth(tester, keys);
    await tapText(tester, 'Combinar');
    expect(find.text('Combinar los dos cambios'), findsOneWidget);
    // Only what differs is asked; the note starts on the version that has
    // one, the name on the one that stayed.
    expect(find.text('NOMBRE'), findsOneWidget);
    expect(find.text('NOTA'), findsOneWidget);
    expect(find.text('CATEGORÍA'), findsNothing);
    bool chosen(String text) {
      final Finder tile = find.ancestor(
        of: find.text(text),
        matching: find.byType(RadioListTile<bool>),
      );
      final RadioGroup<bool> group = tester.widget<RadioGroup<bool>>(
        find.ancestor(of: tile, matching: find.byType(RadioGroup<bool>)),
      );
      return group.groupValue == tester.widget<RadioListTile<bool>>(tile).value;
    }

    expect(chosen('Almuerzo de trabajo'), isTrue);
    expect(chosen('Con factura'), isTrue);
    await tapText(tester, 'Almuerzo con Juan');
    expect(chosen('Almuerzo con Juan'), isTrue);
    await tapText(tester, 'Guardar');

    expect(lunchOf(own).payee, 'Almuerzo con Juan');
    expect(lunchOf(own).note, 'Con factura');
    expect(find.text('PARA REVISAR'), findsNothing);
    expect(find.textContaining('Combinado.'), findsOneWidget);

    // An edit like any other: the other device takes it, with nothing to
    // review there.
    final SyncReport report = (await tester.runAsync(() async {
      final SyncService here = SyncService(
        own.store,
        keys: keys,
        now: () => pageNow.add(const Duration(hours: 2)),
      );
      return there.import(await here.export());
    }))!;
    expect(report.conflicts, 0);
    final Entry theirs = (await tester.runAsync(
      other.entries,
    ))!.firstWhere((Entry e) => e.category == 'restaurants');
    expect(theirs.payee, 'Almuerzo con Juan');
    expect(theirs.note, 'Con factura');
  });

  testWidgets('with large text the two versions go one under the other', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await lunchChangedOnBoth(tester, MemoryKeyStore());
    await reveal(tester, find.text('Lo que espera: Almuerzo con Juan'));
    expect(find.byType(Table), findsNothing);
    expect(find.text('Lo que quedó: Almuerzo de trabajo'), findsOneWidget);
    expect(find.text('Lo que quedó: Con factura'), findsOneWidget);
    expect(find.text('Lo que espera: \u2014'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('what is dismissed can come back right after', (tester) async {
    final (OwnController own, _, _) = await lunchChangedOnBoth(
      tester,
      MemoryKeyStore(),
    );
    await tapText(tester, 'Descartar');
    expect(find.text('PARA REVISAR'), findsNothing);
    expect(find.text('Descartado.'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(find.text('PARA REVISAR'), findsOneWidget);
    expect(find.text('Almuerzo con Juan'), findsOneWidget);
    expect(lunchOf(own).payee, 'Almuerzo de trabajo');
  });
}
