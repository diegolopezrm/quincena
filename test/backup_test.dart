// Phase 19: a backup is sealed with a code of its own, like a sync file,
// unless the person chooses JSON. It opens on the same phone with nothing
// to type and on another with its code; no other code, file or damage gets
// past it, and nothing changes until the person says to replace.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/backup/backup.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/sync_file.dart';
import 'package:quincena/sync/sync_service.dart' show MemoryKeyStore;
import 'package:quincena/sync/vault.dart';
import 'package:quincena/ui/own/backup_flow.dart';

import 'page_harness.dart';

QuincenaStore emptyStore() => QuincenaStore(
  QuincenaDatabase(NativeDatabase.memory()),
  now: () => DateTime(2026, 10, 3, 9),
);

Future<QuincenaStore> phoneWithData() async {
  final QuincenaStore store = emptyStore();
  await store.ensureCategories();
  await store.saveProfile(
    const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
  );
  final Account bank = await store.addAccount(
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: Decimal.parse('1000000'),
  );
  await store.addEntry(
    accountId: bank.id,
    amount: Decimal.parse('45900'),
    kind: EntryKind.expense,
    date: DateTime(2026, 10, 1, 12),
    payee: 'Éxito',
  );
  return store;
}

/// What a store holds, apart from when it was asked.
Future<Map<String, Object?>> contents(QuincenaStore store) async =>
    (await store.exportJson())..remove('exportedAt');

Future<Object?> failure(Future<Object?> Function() open) async {
  try {
    await open();
    return null;
  } on Object catch (e) {
    return e;
  }
}

Matcher backupProblem(BackupProblem p) => isA<BackupException>().having(
  (BackupException e) => e.problem,
  'problem',
  p,
);

Matcher importProblem(ImportProblem p) => isA<ImportException>().having(
  (ImportException e) => e.problem,
  'problem',
  p,
);

/// A device whose keychain does not answer.
class NoKeychain implements BackupKeyStore {
  @override
  Future<List<int>?> read() => throw UnsupportedError('no keychain');

  @override
  Future<void> write(List<int> key) => throw UnsupportedError('no keychain');

  @override
  Future<void> delete() => throw UnsupportedError('no keychain');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('a sealed backup', () {
    late QuincenaStore phone;
    late Backups backups;

    setUp(() async {
      phone = await phoneWithData();
      backups = Backups(phone, keys: MemoryBackupKeyStore(), random: Random(1));
    });
    tearDown(() => phone.close());

    test('opens on the same phone with nothing to type', () async {
      expect(await backups.code(), isNull);
      final SealedBackup first = await backups.seal();
      expect(first.newCode, isNotNull);
      expect(await backups.code(), first.newCode);
      expect(SealedFile.backup.marks(first.file), isTrue);
      // Nothing of what is inside reads from outside.
      final String clear = latin1.decode(first.file);
      expect(clear, isNot(contains('Bancolombia')));
      expect(clear, isNot(contains('quincena')));
      // One code for every backup: shown once.
      expect((await backups.seal()).newCode, isNull);

      final Map<String, Object?> before = await contents(phone);
      await phone.addEntry(
        accountId: (await phone.snapshot())!.accounts.first.id,
        amount: Decimal.parse('12000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2),
        payee: 'Después del respaldo',
      );
      final OpenedBackup opened = await backups.open(first.file);
      expect(opened.key, isNull);
      await backups.restore(opened);
      expect(await contents(phone), before);
    });

    test('on another phone it takes its code, and keeps it', () async {
      final SealedBackup sealed = await backups.seal();
      final String code = sealed.newCode!;
      final QuincenaStore other = emptyStore();
      addTearDown(other.close);
      await other.ensureCategories();
      final Backups there = Backups(other, keys: MemoryBackupKeyStore());

      expect(
        await failure(() => there.open(sealed.file)),
        backupProblem(BackupProblem.needsCode),
      );
      expect(
        await failure(
          () =>
              there.open(sealed.file, code: VaultKey.generate(Random(9)).code),
        ),
        backupProblem(BackupProblem.wrongCode),
      );
      expect(
        await failure(() => there.open(sealed.file, code: 'ABCD-EFGH')),
        isA<CodeException>(),
      );
      // Typed the way people type it.
      final OpenedBackup opened = await there.open(
        sealed.file,
        code: code.toLowerCase().replaceAll('-', ' '),
      );
      await there.restore(opened);
      expect(await contents(other), await contents(phone));
      // The next backup there opens with the same code.
      expect(await there.code(), code);
    });

    test('neither code opens the other kind of file', () async {
      final VaultKey key = VaultKey.generate(Random(5));
      final Map<String, Object?> body = <String, Object?>{'hola': 'mundo'};
      final Uint8List backup = await SealedFile.backup.seal(key, body);
      final Uint8List sync = await SealedFile.sync.seal(key, body);
      expect(
        await failure(() => SealedFile.sync.open(key, backup)),
        isA<SyncFileException>().having(
          (SyncFileException e) => e.problem,
          'problem',
          SyncFileProblem.notSync,
        ),
      );
      // Relabelled, it still does not open: its keys come from other labels.
      final Uint8List relabelled = Uint8List.fromList(<int>[
        ...ascii.encode('QSYNC'),
        ...backup.sublist(5),
      ]);
      expect(
        await failure(() => SealedFile.sync.open(key, relabelled)),
        isA<SyncFileException>().having(
          (SyncFileException e) => e.problem,
          'problem',
          SyncFileProblem.otherVault,
        ),
      );
      expect(
        await failure(() => backups.open(sync)),
        backupProblem(BackupProblem.syncFile),
      );
    });

    test('a damaged or strange file changes nothing', () async {
      final Uint8List file = (await backups.seal()).file;
      final Map<String, Object?> before = await contents(phone);
      final List<List<int>> strange = <List<int>>[
        file.sublist(0, file.length - 10),
        Uint8List.fromList(file)..[file.length ~/ 2] ^= 1,
      ];
      for (final List<int> bytes in strange) {
        expect(
          await failure(() => backups.open(bytes)),
          importProblem(ImportProblem.damaged),
        );
      }
      expect(
        await failure(
          () => backups.open(Uint8List.fromList(<int>[...file]..[5] = 9)),
        ),
        importProblem(ImportProblem.newer),
      );
      expect(
        await failure(
          () => backups.open(<int>[0xff, 0xfe, 0x00, 0x13, 0x88, 0x01]),
        ),
        importProblem(ImportProblem.notQuincena),
      );
      expect(
        await failure(
          () => backups.open(utf8.encode('{"app": "otra", "version": 1}')),
        ),
        importProblem(ImportProblem.notQuincena),
      );
      expect(
        await failure(
          () => backups.open(utf8.encode('{"app": "quincena", "version": 99}')),
        ),
        importProblem(ImportProblem.newer),
      );
      expect(await contents(phone), before);
    });

    test('JSON still goes both ways, readable', () async {
      final Uint8List plain = await backups.plain();
      expect(utf8.decode(plain), contains('Bancolombia'));
      final QuincenaStore other = emptyStore();
      addTearDown(other.close);
      final Backups there = Backups(other, keys: MemoryBackupKeyStore());
      await there.restore(await there.open(plain));
      expect(await contents(other), await contents(phone));
      // Nothing sealed happened: no code was made.
      expect(await there.code(), isNull);
    });

    test('replacing the data keeps how this phone opens and what it '
        'shows outside the app', () async {
      final QuincenaStore other = emptyStore();
      addTearDown(other.close);
      await other.setSetting('app.mode', 'own');
      await other.setSetting('app.theme', 'dark');
      await other.setSetting('reminders.close', 'yes');
      await other.setSetting('widget.hideAmounts', 'yes');
      await other.setSetting('sync.state', '{"device":"x"}');
      final Backups there = Backups(other, keys: MemoryBackupKeyStore());
      await there.restore(await there.open(await backups.plain()));

      expect((await other.profile())?.name, 'Ana');
      // Without it the app would open on its first screen next time.
      expect(await other.setting('app.mode'), 'own');
      expect(await other.setting('app.theme'), 'dark');
      expect(await other.setting('reminders.close'), 'yes');
      expect(await other.setting('widget.hideAmounts'), 'yes');
      // What syncing knew was about the data that left: it starts again.
      expect(await other.setting('sync.state'), isNull);
      // And none of it travels in a file.
      final Map<String, Object?> export = await other.exportJson();
      expect(
        (export['settings']! as Map<String, Object?>).keys,
        isNot(contains(anyOf(QuincenaStore.deviceSettings))),
      );
    });

    test('a card\'s limit comes back from another phone\'s backup', () async {
      await phone.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: Decimal.parse('-300000'),
        creditLimit: Decimal.parse('2000000'),
      );
      final SealedBackup sealed = await backups.seal();
      final QuincenaStore other = emptyStore();
      addTearDown(other.close);
      final Backups there = Backups(other, keys: MemoryBackupKeyStore());
      await there.restore(await there.open(sealed.file, code: sealed.newCode));
      final Account visa = (await other.accounts()).firstWhere(
        (Account a) => a.kind == AccountKind.card,
      );
      expect(visa.creditLimit, Decimal.parse('2000000'));
      expect(await contents(other), await contents(phone));
    });

    test('with no keychain, every backup brings its own code', () async {
      final Backups bare = Backups(phone, keys: NoKeychain());
      final SealedBackup a = await bare.seal();
      final SealedBackup b = await bare.seal();
      expect(a.newCode, isNotNull);
      expect(b.newCode, isNotNull);
      expect(a.newCode, isNot(b.newCode));
      expect(
        await failure(() => bare.open(a.file)),
        backupProblem(BackupProblem.needsCode),
      );
      expect(
        (await bare.open(a.file, code: a.newCode)).json['app'],
        'quincena',
      );
      await bare.forget();
    });

    test('a new code is for the backups to come', () async {
      final SealedBackup old = await backups.seal();
      final String code = await backups.changeCode();
      expect(code, isNot(old.newCode));
      expect(await backups.code(), code);
      // The old one now needs the code it was made with.
      expect(
        await failure(() => backups.open(old.file)),
        backupProblem(BackupProblem.needsCode),
      );
      expect(
        (await backups.open(old.file, code: old.newCode)).json['app'],
        'quincena',
      );
      final SealedBackup next = await backups.seal();
      expect(next.newCode, isNull);
      expect(
        await failure(() => backups.open(next.file, code: old.newCode)),
        backupProblem(BackupProblem.wrongCode),
      );
      expect((await backups.open(next.file)).json['app'], 'quincena');
    });

    test('forgetting the key leaves its backups to their code', () async {
      final SealedBackup sealed = await backups.seal();
      await backups.forget();
      expect(await backups.code(), isNull);
      expect(
        await failure(() => backups.open(sealed.file)),
        backupProblem(BackupProblem.needsCode),
      );
      expect(
        (await backups.open(sealed.file, code: sealed.newCode)).json['app'],
        'quincena',
      );
    });
  });

  group('what a backup holds', () {
    test('counts what the person sees: accounts in sight, a transfer once, '
        'goals and the rest of the Plan', () async {
      final QuincenaStore phone = await phoneWithData();
      addTearDown(phone.close);
      final Account bank = (await phone.accounts()).single;
      final Account savings = await phone.addAccount(
        name: 'Ahorros',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: Decimal.zero,
      );
      final Account old = await phone.addAccount(
        name: 'Cuenta vieja',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: Decimal.zero,
      );
      await phone.updateAccount(old.copyWith(archived: true));
      await phone.addTransfer(
        fromAccountId: bank.id,
        toAccountId: savings.id,
        sent: Decimal.parse('100000'),
        date: DateTime(2026, 10, 2),
      );
      await phone.addGoal(
        name: 'Cartagena',
        target: Money(Decimal.parse('2000000'), Asset.cop),
      );
      await phone.addRecurring(
        name: 'Arriendo',
        amount: Money(Decimal.parse('1200000'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 11, 1),
      );
      await phone.setSetting(
        'plan.wishes',
        jsonEncode(<Object?>[
          <String, Object?>{'id': 'w1', 'name': 'Silla', 'price': 650000},
          <String, Object?>{'id': 'w2', 'name': 'Cámara', 'price': 420000},
        ]),
      );
      await phone.setSetting(
        'freelance',
        jsonEncode(<String, Object?>{
          'incomes': <Object?>[
            <String, Object?>{'id': 'f1'},
          ],
        }),
      );

      final BackupContents held = BackupContents.of(await phone.exportJson());
      expect(held.made, DateTime(2026, 10, 3, 9));
      // Bancolombia and Ahorros; the archived one comes back out of sight.
      expect(held.accounts, 2);
      // Éxito, and the transfer's two legs as one.
      expect(held.movements, 2);
      expect(held.goals, 1);
      // The rent, two wishes and one variable income.
      expect(held.plan, 4);
    });

    test('an older or odd file counts what it has and nothing it lacks', () {
      final BackupContents bare = BackupContents.of(<String, Object?>{
        'app': 'quincena',
        'version': 1,
      });
      expect(bare.made, isNull);
      expect(
        <int>[bare.accounts, bare.movements, bare.goals, bare.plan],
        <int>[0, 0, 0, 0],
      );
      final BackupContents odd = BackupContents.of(<String, Object?>{
        'app': 'quincena',
        'version': 3,
        'exportedAt': 'ayer',
        'accounts': 'ninguna',
        'entries': <Object?>[
          1,
          null,
          <String, Object?>{'id': 'e1'},
        ],
        'settings': <String, Object?>{
          'plan.wishes': '{roto',
          'trips': '[{"id": "t1"}]',
          'freelance': '[]',
        },
      });
      expect(odd.made, isNull);
      expect(odd.accounts, 0);
      expect(odd.movements, 1);
      expect(odd.plan, 1);
    });
  });

  group('on screen', () {
    setUpAll(() async {
      Intl.defaultLocale = 'es_CO';
      await initializeDateFormatting('es');
    });

    /// Settings' two rows, over [backups].
    Widget buttons(
      OwnController own,
      Backups Function(OwnController own) backups, {
      required SaveFile save,
      required PickFile pick,
    }) => Scaffold(
      body: Builder(
        builder: (BuildContext context) => Column(
          children: <Widget>[
            TextButton(
              onPressed: () => exportData(
                context,
                backups: backups(own),
                today: own.today,
                save: save,
              ),
              child: const Text('Exportar ahora'),
            ),
            TextButton(
              onPressed: () => restoreBackup(
                context,
                backups: backups(own),
                today: own.today,
                pick: pick,
                save: save,
              ),
              child: const Text('Importar ahora'),
            ),
          ],
        ),
      ),
    );

    testWidgets('exporting seals by default and shows the code once', (
      tester,
    ) async {
      final MemoryBackupKeyStore keys = MemoryBackupKeyStore();
      final List<(String, Uint8List, String)> saved =
          <(String, Uint8List, String)>[];
      Future<bool> save(
        String name,
        Uint8List bytes, {
        required String mimeType,
        List<String>? extensions,
      }) async {
        saved.add((name, bytes, mimeType));
        return true;
      }

      await openPage(
        tester,
        (OwnController own) => buttons(
          own,
          (OwnController own) => Backups(own.store, keys: keys),
          save: save,
          pick: () async => null,
        ),
      );
      await tapText(tester, 'Exportar ahora');
      expect(find.text('Cifrado (recomendado)'), findsOneWidget);
      expect(find.text('Sin cifrar (JSON)'), findsOneWidget);
      expect(find.text('Ver mi código de respaldo'), findsNothing);
      await tapText(tester, 'Exportar');
      // The code first, then where to keep the file.
      expect(find.text('Tu código de respaldo'), findsOneWidget);
      expect(find.textContaining('ni siquiera Quincena'), findsOneWidget);
      final String code = VaultKey(
        (await tester.runAsync<List<int>?>(keys.read))!,
      ).code;
      for (final String group in code.split('-')) {
        expect(find.text(group), findsWidgets);
      }
      expect(saved, isEmpty);
      await tapText(tester, 'Ya lo guardé');
      expect(saved, hasLength(1));
      expect(saved.single.$1, 'quincena-2026-10-03.qbackup');
      expect(SealedFile.backup.marks(saved.single.$2), isTrue);
      expect(find.text('Archivo guardado.'), findsOneWidget);

      // The next one keeps the same code, and the code is at hand.
      await tapText(tester, 'Exportar ahora');
      expect(find.text('Ver mi código de respaldo'), findsOneWidget);
      await tapText(tester, 'Exportar');
      expect(find.text('Tu código de respaldo'), findsNothing);
      expect(saved, hasLength(2));

      // JSON, when the person chooses it.
      await tapText(tester, 'Exportar ahora');
      await tapText(tester, 'Sin cifrar (JSON)');
      await tapText(tester, 'Exportar');
      expect(saved, hasLength(3));
      expect(saved.last.$1, 'quincena-2026-10-03.json');
      expect(saved.last.$3, 'application/json');
      expect(utf8.decode(saved.last.$2), contains('Bancolombia'));

      // A new code, said before it changes, for the backups to come.
      await tapText(tester, 'Exportar ahora');
      await tapText(tester, 'Cambiar el código');
      expect(find.textContaining('se siguen abriendo'), findsOneWidget);
      await tapText(tester, 'Cambiar');
      expect(find.text('Tu nuevo código de respaldo'), findsOneWidget);
      final String changed = VaultKey(
        (await tester.runAsync<List<int>?>(keys.read))!,
      ).code;
      expect(changed, isNot(code));
      await tapText(tester, 'Ya lo guardé');
      await tapText(tester, 'Exportar');
      expect(saved, hasLength(4));
      expect(find.text('Tu código de respaldo'), findsNothing);
    });

    testWidgets('a backup from another phone takes its code before asking', (
      tester,
    ) async {
      // Made on another phone, with its own code.
      late SealedBackup sealed;
      await tester.runAsync(() async {
        final QuincenaStore before = await phoneWithData();
        sealed = await Backups(before, keys: MemoryBackupKeyStore()).seal();
        await before.close();
      });
      final MemoryBackupKeyStore keys = MemoryBackupKeyStore();
      final OwnController own = await openPage(
        tester,
        (OwnController own) => buttons(
          own,
          (OwnController own) => Backups(own.store, keys: keys),
          save:
              (
                _,
                _, {
                required String mimeType,
                List<String>? extensions,
              }) async => false,
          pick: () async => sealed.file,
        ),
      );
      await tapText(tester, 'Importar ahora');
      expect(find.text('Respaldo cifrado'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        VaultKey.generate(Random(4)).code,
      );
      await tapText(tester, 'Abrir');
      expect(
        find.textContaining('Ese código no abre este respaldo'),
        findsOneWidget,
      );
      expect(find.text('¿Restaurar este respaldo?'), findsNothing);

      await tester.enterText(find.byType(TextField), sealed.newCode!);
      await tapText(tester, 'Abrir');
      expect(find.text('¿Restaurar este respaldo?'), findsOneWidget);
      await tapText(tester, 'Restaurar');
      expect(find.text('Respaldo restaurado.'), findsOneWidget);
      final List<Entry> entries = (await tester.runAsync(own.store.entries))!;
      expect(entries.map((Entry e) => e.payee), contains('Éxito'));
      expect(
        await tester.runAsync(Backups(own.store, keys: keys).code),
        sealed.newCode,
      );
    });

    testWidgets('restoring says what the backup brings, and can keep what '
        'is here first', (tester) async {
      late Uint8List file;
      await tester.runAsync(() async {
        final QuincenaStore before = await phoneWithData();
        file = await Backups(before, keys: MemoryBackupKeyStore()).plain();
        await before.close();
      });
      final List<String> saved = <String>[];
      final OwnController own = await openPage(
        tester,
        (OwnController own) => buttons(
          own,
          (OwnController own) =>
              Backups(own.store, keys: MemoryBackupKeyStore()),
          save:
              (
                String name,
                _, {
                required String mimeType,
                List<String>? extensions,
              }) async {
                saved.add(name);
                return true;
              },
          pick: () async => file,
        ),
      );
      Future<List<String>> payees() async => <String>[
        for (final Entry e in (await tester.runAsync(own.store.entries))!)
          e.payee,
      ];

      await tapText(tester, 'Importar ahora');
      expect(find.text('¿Restaurar este respaldo?'), findsOneWidget);
      expect(find.text('Respaldo del 3 de octubre de 2026:'), findsOneWidget);
      for (final String line in <String>[
        'Una cuenta',
        'Un movimiento',
        'Ninguna meta',
        'Nada más del Plan',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(find.textContaining('se borra y queda lo del'), findsOneWidget);

      // What is here first, through the same export, and the same question
      // again.
      await tapText(tester, 'Guardar lo de ahora primero');
      expect(find.text('Cifrado (recomendado)'), findsOneWidget);
      await tapText(tester, 'Sin cifrar (JSON)');
      await tapText(tester, 'Exportar');
      expect(saved, <String>['quincena-2026-10-03.json']);
      expect(find.text('¿Restaurar este respaldo?'), findsOneWidget);
      expect(await payees(), contains('Nómina'));

      await tapText(tester, 'Cancelar');
      expect(find.text('¿Restaurar este respaldo?'), findsNothing);
      expect(await payees(), contains('Nómina'));

      await tapText(tester, 'Importar ahora');
      await tapText(tester, 'Restaurar');
      expect(find.text('Respaldo restaurado.'), findsOneWidget);
      expect(await payees(), <String>['Éxito']);
    });

    testWidgets('of the person\'s two codes, the one this device knows is '
        'named when it does not open the backup', (tester) async {
      // Made on another phone, with its own code.
      late SealedBackup sealed;
      await tester.runAsync(() async {
        final QuincenaStore before = await phoneWithData();
        sealed = await Backups(before, keys: MemoryBackupKeyStore()).seal();
        await before.close();
      });
      // This phone syncs, and has a backup code of its own.
      final VaultKey vault = VaultKey.generate(Random(21));
      final MemoryKeyStore syncKeys = MemoryKeyStore();
      final VaultKey mine = VaultKey.generate(Random(22));
      final MemoryBackupKeyStore keys = MemoryBackupKeyStore();
      await tester.runAsync(() async {
        await syncKeys.write(vault.bytes);
        await keys.write(mine.bytes);
      });
      await openPage(
        tester,
        (OwnController own) => Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => restoreBackup(
                context,
                backups: Backups(own.store, keys: keys),
                today: own.today,
                pick: () async => sealed.file,
                syncKeys: syncKeys,
              ),
              child: const Text('Importar ahora'),
            ),
          ),
        ),
      );
      await tapText(tester, 'Importar ahora');
      await tester.enterText(find.byType(TextField), vault.code);
      await tapText(tester, 'Abrir');
      expect(
        find.textContaining(
          'Ese es tu código para sincronizar, no el de respaldo',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), mine.code);
      await tapText(tester, 'Abrir');
      expect(
        find.textContaining('Ese es tu código de respaldo de ahora'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextField),
        VaultKey.generate(Random(23)).code,
      );
      await tapText(tester, 'Abrir');
      expect(
        find.textContaining('Ese código no abre este respaldo'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), sealed.newCode!);
      await tapText(tester, 'Abrir');
      expect(find.text('¿Restaurar este respaldo?'), findsOneWidget);
    });

    testWidgets('a sync file is sent where it opens, with nothing asked', (
      tester,
    ) async {
      final Uint8List sync = (await tester.runAsync(
        () => SealedFile.sync.seal(
          VaultKey.generate(Random(6)),
          <String, Object?>{'records': <Object?>[]},
        ),
      ))!;
      await openPage(
        tester,
        (OwnController own) => buttons(
          own,
          (OwnController own) =>
              Backups(own.store, keys: MemoryBackupKeyStore()),
          save:
              (
                _,
                _, {
                required String mimeType,
                List<String>? extensions,
              }) async => false,
          pick: () async => sync,
        ),
      );
      await tapText(tester, 'Importar ahora');
      expect(
        find.textContaining('Ese es un archivo de sincronización'),
        findsOneWidget,
      );
      expect(find.text('¿Restaurar este respaldo?'), findsNothing);
    });
  });
}
