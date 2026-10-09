import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/compare.dart';
import 'package:quincena/sync/merge.dart';
import 'package:quincena/sync/sync_file.dart';
import 'package:quincena/sync/sync_service.dart';
import 'package:quincena/sync/vault.dart';

Decimal d(String s) => Decimal.parse(s);

/// A device: its own database, keychain and clock.
class Device {
  Device(this.name, DateTime start) : _time = start {
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => _time,
    );
    sync = SyncService(store, keys: MemoryKeyStore(), now: () => _time);
  }

  final String name;
  late final QuincenaStore store;
  late final SyncService sync;
  DateTime _time;

  void later([Duration by = const Duration(minutes: 1)]) =>
      _time = _time.add(by);

  /// What it holds that syncs, comparable with another device's.
  Future<Map<String, Map<String, Object?>?>> contents() async =>
      <String, Map<String, Object?>?>{
        for (final SyncRecord r in await store.syncRecords()) r.key: r.data,
      };

  Future<List<String>> payees() async =>
      <String>[for (final Entry e in await store.entries()) e.payee]..sort();
}

void main() {
  // Each device has its own database, on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('the code', () {
    test('spells the key, catches a typo, forgives how it is typed', () {
      final VaultKey key = VaultKey.generate(Random(7));
      final String code = key.code;
      expect(code.replaceAll('-', ''), hasLength(54));
      expect(VaultKey.fromCode(code).bytes, key.bytes);
      expect(
        VaultKey.fromCode(code.toLowerCase().replaceAll('-', ' ')).bytes,
        key.bytes,
      );
      // One character wrong, anywhere.
      final List<String> chars = code.split('');
      final int at = chars.indexWhere((String c) => c != '-' && c != 'X');
      chars[at] = chars[at] == 'Z' ? 'Y' : 'Z';
      expect(
        () => VaultKey.fromCode(chars.join()),
        throwsA(
          isA<CodeException>().having(
            (CodeException e) => e.problem,
            'problem',
            CodeProblem.check,
          ),
        ),
      );
      // Any one character typed wrong is caught, wherever it is.
      const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final String plain = code.replaceAll('-', '');
      for (var i = 0; i < plain.length; i++) {
        for (final String c in alphabet.split('')) {
          if (c == plain[i]) continue;
          final String typo = plain.replaceRange(i, i + 1, c);
          expect(
            () => VaultKey.fromCode(typo),
            throwsA(isA<CodeException>()),
            reason: 'position $i as $c',
          );
        }
      }
      expect(
        () => VaultKey.fromCode(code.substring(0, 20)),
        throwsA(isA<CodeException>()),
      );
      expect(
        () => VaultKey.fromCode(code.replaceFirst(RegExp('[0-9A-Z]'), 'U')),
        throwsA(isA<CodeException>()),
      );
    });
  });

  group('the file', () {
    test('opens with its key only, and any change breaks it', () async {
      final VaultKey key = VaultKey.generate(Random(1));
      final Uint8List file = await SyncFile.seal(key, <String, Object?>{
        'hola': 'mundo',
      });
      expect(await SyncFile.open(key, file), <String, Object?>{
        'hola': 'mundo',
      });
      Future<SyncFileProblem?> problem(VaultKey k, List<int> bytes) async {
        try {
          await SyncFile.open(k, bytes);
          return null;
        } on SyncFileException catch (e) {
          return e.problem;
        }
      }

      expect(
        await problem(VaultKey.generate(Random(2)), file),
        SyncFileProblem.otherVault,
      );
      for (final int at in <int>[
        5,
        30,
        50,
        file.length ~/ 2,
        file.length - 1,
      ]) {
        final Uint8List changed = Uint8List.fromList(file)..[at] ^= 1;
        expect(await problem(key, changed), isNotNull, reason: 'byte $at');
      }
      expect(
        await problem(key, file.sublist(0, file.length - 10)),
        SyncFileProblem.damaged,
      );
      expect(
        await problem(key, Uint8List.fromList(<int>[...file]..[5] = 9)),
        SyncFileProblem.newer,
      );
      expect(await problem(key, <int>[1, 2, 3]), SyncFileProblem.notSync);
      // Nothing in the clear says what is inside, nor ties two files of a
      // vault together, and the size says little of how much is in it.
      expect(String.fromCharCodes(file), isNot(contains('hola')));
      final Uint8List again = await SyncFile.seal(key, <String, Object?>{
        'hola': 'mundo',
      });
      expect(again.sublist(6, 38), isNot(file.sublist(6, 38)));
      expect(file.length, again.length);
      expect((file.length - 78) % (16 * 1024), 0);
    });
  });

  group('two versions, field by field', () {
    SyncRecord lunch(Map<String, Object?> data) =>
        SyncRecord('entries', 'e1', <String, Object?>{
          'id': 'e1',
          'accountId': 'a1',
          'amount': '-30000',
          'kind': 'expense',
          'category': 'restaurants',
          'payee': 'Almuerzo',
          'note': '',
          'date': 1790000000000,
          ...data,
        });

    test('say which fields differ, an amount with its kind and account', () {
      final List<FieldDiff> diffs = compareVersions(
        lunch(<String, Object?>{'note': 'Con factura'}),
        lunch(<String, Object?>{'payee': 'Almuerzo con Juan'}),
      );
      expect(
        <String, bool>{
          for (final FieldDiff f in diffs) f.field.name: f.differs,
        },
        <String, bool>{
          'payee': true,
          'money': false,
          'category': false,
          'date': false,
          'note': true,
        },
      );
      expect(
        compareVersions(
          lunch({}),
          lunch(<String, Object?>{'accountId': 'a2'}),
        ).firstWhere((FieldDiff f) => f.field.name == 'money').differs,
        isTrue,
      );
      // A leg of a transfer cannot take its amount or date alone.
      final List<FieldDiff> leg = compareVersions(
        lunch(<String, Object?>{'transferId': 't1'}),
        lunch(<String, Object?>{'transferId': 't1', 'note': 'x'}),
      );
      expect(
        <String>[
          for (final FieldDiff f in leg)
            if (!f.free) f.field.name,
        ],
        <String>['money', 'date'],
      );
      // Records known by name are not compared this way.
      expect(fieldsOf('settings'), isEmpty);
    });

    test('combining takes only the fields chosen', () {
      final SyncRecord kept = lunch(<String, Object?>{'note': 'Con factura'});
      final SyncRecord waiting = lunch(<String, Object?>{
        'payee': 'Almuerzo con Juan',
        'amount': '-32000',
      });
      final Map<String, Object?> both = combineVersions(
        kept,
        waiting,
        <SyncField>[
          fieldsOf('entries').firstWhere((SyncField f) => f.name == 'payee'),
        ],
      );
      expect(both['payee'], 'Almuerzo con Juan');
      expect(both['note'], 'Con factura');
      expect(both['amount'], '-30000');
    });
  });

  group('two devices', () {
    late Device phone;
    late Device laptop;
    final DateTime start = DateTime(2026, 10, 3, 9);

    setUp(() async {
      phone = Device('phone', start);
      laptop = Device('laptop', start.add(const Duration(seconds: 30)));
      for (final Device device in <Device>[phone, laptop]) {
        await device.store.ensureCategories();
      }
      await phone.store.saveProfile(
        const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await phone.store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1000000'),
      );
      final String code = await phone.sync.start();
      // The laptop went through onboarding on its own first.
      await laptop.store.saveProfile(
        const Profile(name: 'Nuevo', base: Asset.cop, schedule: TwiceMonthly()),
      );
      await laptop.sync.join(code);
    });

    tearDown(() async {
      await phone.store.close();
      await laptop.store.close();
    });

    Future<SyncReport> send(Device from, Device to) async =>
        to.sync.import(await from.sync.export());

    Future<String> bank(Device d) async => (await d.store.accounts()).first.id;

    test('a device that joins gets everything, and keeps the vault\'s '
        'profile over its own', () async {
      await send(phone, laptop);
      expect(await laptop.contents(), await phone.contents());
      expect((await laptop.store.profile())!.name, 'Ana');
      expect(
        jsonEncode((await laptop.sync.conflicts()).single.record.data),
        contains('Nuevo'),
      );
    });

    test('edits made apart, offline, end the same on both, in either '
        'order', () async {
      await send(phone, laptop);
      phone.later();
      laptop.later();
      await phone.store.addEntry(
        accountId: await bank(phone),
        amount: d('20000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'transport',
        payee: 'Uber',
      );
      await laptop.store.addEntry(
        accountId: await bank(laptop),
        amount: d('60000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'groceries',
        payee: 'D1',
      );
      await laptop.store.addGoal(
        name: 'Cartagena',
        target: Money(d('2000000'), Asset.cop),
        saved: Money(d('0'), Asset.cop),
        monthly: Money(d('300000'), Asset.cop),
      );
      // The laptop's file reaches the phone first this time.
      final Uint8List fromLaptop = await laptop.sync.export();
      final Uint8List fromPhone = await phone.sync.export();
      await phone.sync.import(fromLaptop);
      await laptop.sync.import(fromPhone);
      await send(phone, laptop);
      expect(await phone.payees(), <String>['D1', 'Uber']);
      expect(await laptop.contents(), await phone.contents());
      expect(await phone.sync.conflicts(), isEmpty);
      // The same file again changes nothing.
      expect((await phone.sync.import(fromLaptop)).applied, 0);
      expect((await laptop.sync.import(fromPhone)).applied, 0);
      expect(await laptop.contents(), await phone.contents());
    });

    test('the same thing changed on both: the later shows, the other '
        'waits, and restoring it carries over', () async {
      await send(phone, laptop);
      final Entry lunch = await phone.store.addEntry(
        accountId: await bank(phone),
        amount: d('30000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'restaurants',
        payee: 'Almuerzo',
      );
      await send(phone, laptop);
      phone.later();
      await phone.store.updateEntry(lunch.copyWith(payee: 'Almuerzo con Juan'));
      laptop.later(const Duration(minutes: 5));
      final Entry there = (await laptop.store.entries()).single;
      await laptop.store.updateEntry(there.copyWith(amount: d('-32000')));
      await send(laptop, phone);
      await send(phone, laptop);
      // The laptop's edit came later.
      for (final Device x in <Device>[phone, laptop]) {
        final Entry e = (await x.store.entries()).single;
        expect(e.amount, d('-32000'));
        expect(e.payee, 'Almuerzo');
      }
      final SyncConflict waiting = (await phone.sync.conflicts()).single;
      expect(waiting.reason, ConflictReason.editedBoth);
      expect(waiting.record.data!['payee'], 'Almuerzo con Juan');

      phone.later();
      await phone.sync.restore(waiting);
      // What it replaced waits in its place.
      expect(
        (await phone.sync.conflicts()).single.reason,
        ConflictReason.replaced,
      );
      await send(phone, laptop);
      expect((await laptop.store.entries()).single.payee, 'Almuerzo con Juan');
      expect(await laptop.contents(), await phone.contents());
    });

    // The limit docs/SYNC.md describes under "Whole records": versions are
    // of the whole movement, so edits to two of its fields are two
    // versions, and only one of them can stay. A merge field by field would
    // keep both and turn this test around.
    test('a name changed on one and a note added on the other are two '
        'versions: keeping one lets the other go', () async {
      await send(phone, laptop);
      final Entry lunch = await phone.store.addEntry(
        accountId: await bank(phone),
        amount: d('30000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'restaurants',
        payee: 'Almuerzo',
      );
      await send(phone, laptop);
      phone.later();
      await phone.store.updateEntry(lunch.copyWith(payee: 'Almuerzo con Juan'));
      laptop.later(const Duration(minutes: 5));
      final Entry there = (await laptop.store.entries()).single;
      await laptop.store.updateEntry(there.copyWith(note: 'Pagó la mitad'));
      await send(laptop, phone);

      // The later one shows; the other waits whole, with its old note.
      Entry shown = (await phone.store.entries()).single;
      expect(shown.payee, 'Almuerzo');
      expect(shown.note, 'Pagó la mitad');
      final SyncConflict waiting = (await phone.sync.conflicts()).single;
      expect(waiting.record.data!['payee'], 'Almuerzo con Juan');
      expect(waiting.record.data!['note'], isNot('Pagó la mitad'));

      // Traer de vuelta, then Descartar on what it replaced: the name stays
      // and the note is gone, on both devices.
      phone.later();
      await phone.sync.restore(waiting);
      final SyncConflict replaced = (await phone.sync.conflicts()).single;
      expect(replaced.record.data!['note'], 'Pagó la mitad');
      await phone.sync.dismiss(replaced);
      await send(phone, laptop);
      for (final Device x in <Device>[phone, laptop]) {
        shown = (await x.store.entries()).single;
        expect(shown.payee, 'Almuerzo con Juan');
        expect(shown.note, isNot('Pagó la mitad'));
      }
      expect(await phone.sync.conflicts(), isEmpty);
    });

    test('a file says what it brought: movements with a transfer once, '
        'accounts, the Plan and the rest', () async {
      await send(phone, laptop);
      laptop.later();
      final String bankId = await bank(laptop);
      final Account cash = await laptop.store.addAccount(
        name: 'Efectivo',
        kind: AccountKind.cash,
        asset: Asset.cop,
        opening: d('0'),
      );
      Future<Entry> spend(String payee, String amount) => laptop.store.addEntry(
        accountId: bankId,
        amount: d(amount),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'transport',
        payee: payee,
      );
      final Entry uber = await spend('Uber', '20000');
      await spend('D1', '60000');
      await laptop.store.addTransfer(
        fromAccountId: bankId,
        toAccountId: cash.id,
        sent: d('50000'),
        date: DateTime(2026, 10, 3),
      );
      await laptop.store.addGoal(
        name: 'Cartagena',
        target: Money(d('2000000'), Asset.cop),
      );
      await laptop.store.setSetting(
        'plan.wishes',
        jsonEncode(<Object?>[
          <String, Object?>{'id': 'w1', 'name': 'Silla', 'price': 650000},
        ]),
      );
      final Profile ana = (await laptop.store.profile())!;
      await laptop.store.saveProfile(ana.copyWith(name: 'Ana María'));

      SyncChanges changes = (await send(laptop, phone)).changes;
      expect(changes.movements, 3);
      expect(changes.accounts, 1);
      expect(changes.plan, 2);
      expect(changes.settings, 1);
      expect(changes.movementsGone, 0);

      // The same file again brings nothing.
      expect((await send(laptop, phone)).changes.movements, 0);

      laptop.later();
      await laptop.store.deleteEntry(uber);
      changes = (await send(laptop, phone)).changes;
      expect(changes.movements, 0);
      expect(changes.movementsGone, 1);
    });

    test('deleted on one, edited on the other: it stays deleted, the edit '
        'is kept, and an old file brings nothing back', () async {
      final Entry gym = await phone.store.addEntry(
        accountId: await bank(phone),
        amount: d('119000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 1),
        category: 'leisure',
        payee: 'Fit24',
      );
      final Uint8List old = await phone.sync.export();
      await laptop.sync.import(old);
      phone.later();
      await phone.store.deleteEntry(gym);
      laptop.later();
      final Entry there = (await laptop.store.entries()).single;
      await laptop.store.updateEntry(there.copyWith(note: 'Plan anual'));
      await send(phone, laptop);
      await send(laptop, phone);
      for (final Device x in <Device>[phone, laptop]) {
        expect(await x.store.entries(), isEmpty, reason: x.name);
      }
      // The laptop's own profile from before joining waits there too.
      final SyncConflict kept = (await laptop.sync.conflicts()).singleWhere(
        (SyncConflict c) => c.record.table == 'entries',
      );
      expect(kept.reason, ConflictReason.deletedElsewhere);
      expect(kept.record.data!['note'], 'Plan anual');
      // The phone never saw the edit as its own version: nothing waits there.
      expect(await phone.sync.conflicts(), isEmpty);
      // A file from before the deletion is older than it.
      await laptop.sync.import(old);
      await phone.sync.import(old);
      expect(await laptop.store.entries(), isEmpty);
      expect(await phone.store.entries(), isEmpty);
    });

    test('an account deleted on one takes its movements, and one added '
        'meanwhile on the other is kept to restore', () async {
      await send(phone, laptop);
      final String id = await bank(phone);
      phone.later();
      final Account account = (await phone.store.accounts()).single;
      await phone.store.deleteAccount(account.id);
      laptop.later();
      await laptop.store.addEntry(
        accountId: id,
        amount: d('9000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'transport',
        payee: 'Metro',
      );
      await send(phone, laptop);
      await send(laptop, phone);
      for (final Device x in <Device>[phone, laptop]) {
        expect(await x.store.accounts(), isEmpty, reason: x.name);
        expect(await x.store.entries(), isEmpty, reason: x.name);
      }
      final SyncConflict metro = (await laptop.sync.conflicts()).singleWhere(
        (SyncConflict c) => c.record.table == 'entries',
      );
      expect(metro.reason, ConflictReason.withAccount);
      expect(metro.needs.single.table, 'accounts');

      laptop.later();
      await laptop.sync.restore(metro);
      await send(laptop, phone);
      expect(await phone.payees(), <String>['Metro']);
      expect((await phone.store.accounts()).single.name, 'Bancolombia');
      expect(await phone.contents(), await laptop.contents());
    });

    test('a new code leaves the old one, and its devices, out', () async {
      await send(phone, laptop);
      final String newCode = await phone.sync.changeCode();
      await expectLater(
        () async => laptop.sync.import(await phone.sync.export()),
        throwsA(
          isA<SyncFileException>().having(
            (SyncFileException e) => e.problem,
            'problem',
            SyncFileProblem.otherVault,
          ),
        ),
      );
      final Device tablet = Device('tablet', start);
      addTearDown(tablet.store.close);
      await tablet.store.ensureCategories();
      await tablet.sync.join(newCode);
      await send(phone, tablet);
      expect(await tablet.contents(), await phone.contents());
    });

    test('deleted and brought back on one, edited on the other: the same '
        'end whatever the order', () async {
      final Entry r = await phone.store.addEntry(
        accountId: await bank(phone),
        amount: d('50000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2),
        category: 'shopping',
        payee: 'Falabella',
      );
      await send(phone, laptop);
      phone.later();
      await phone.store.deleteEntry(r);
      final Uint8List deleted = await phone.sync.export();
      // Brought back from what waits: a new movement, not the old one.
      final Entry there = (await laptop.store.entries()).single;
      laptop.later(const Duration(minutes: 9));
      await laptop.store.updateEntry(there.copyWith(note: 'Regalo'));
      await laptop.sync.import(deleted);
      await phone.sync.restore(
        SyncConflict(
          record: SyncRecord('entries', r.id, <String, Object?>{
            ...(await laptop.sync.conflicts())
                .singleWhere((SyncConflict c) => c.record.table == 'entries')
                .record
                .data!,
          }),
          reason: ConflictReason.deletedElsewhere,
          at: DateTime(2026, 10, 3),
        ),
      );
      final Uint8List restored = await phone.sync.export();
      final Uint8List edited = await laptop.sync.export();
      final Device tablet = Device('tablet', start);
      addTearDown(tablet.store.close);
      await tablet.store.ensureCategories();
      await tablet.sync.join((await phone.sync.code())!);
      await tablet.sync.import(edited);
      await tablet.sync.import(restored);
      await laptop.sync.import(restored);
      await phone.sync.import(edited);
      final Map<String, Map<String, Object?>?> want = await phone.contents();
      expect(await laptop.contents(), want);
      expect(await tablet.contents(), want);
      final List<Entry> left = await phone.store.entries();
      expect(left.single.id, isNot(r.id));
      expect(left.single.note, 'Regalo');
    });

    test('a backup that brought another device\'s versions starts again '
        'as a new device, and still agrees', () async {
      await send(phone, laptop);
      // The laptop's database comes back on a third device, its keychain
      // does not: same versions, another device.
      final Device copy = Device('copy', start);
      addTearDown(copy.store.close);
      await copy.store.importJson(await laptop.store.exportJson());
      await copy.store.setSetting(
        'sync.state',
        (await laptop.store.setting('sync.state'))!,
      );
      await copy.sync.join((await phone.sync.code())!);
      copy.later();
      await copy.store.addEntry(
        accountId: await bank(copy),
        amount: d('7000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'transport',
        payee: 'Bus',
      );
      laptop.later();
      await laptop.store.addEntry(
        accountId: await bank(laptop),
        amount: d('8000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'transport',
        payee: 'Taxi',
      );
      await send(copy, laptop);
      await send(laptop, copy);
      await send(laptop, phone);
      expect(await phone.payees(), <String>['Bus', 'Taxi']);
      expect(await copy.contents(), await laptop.contents());
    });

    test('things in one list, changed on two devices, both stay', () async {
      await send(phone, laptop);
      await phone.store.setSetting(
        'shared.groups',
        '[{"id":"g1","name":"Paseo","members":[{"id":"me","name":""}]}]',
      );
      await laptop.store.setSetting(
        'shared.groups',
        '[{"id":"g2","name":"Cena","members":[{"id":"me","name":""}]}]',
      );
      await send(phone, laptop);
      await send(laptop, phone);
      for (final Device x in <Device>[phone, laptop]) {
        expect(
          await x.store.setting('shared.groups'),
          allOf(contains('Paseo'), contains('Cena')),
          reason: x.name,
        );
      }
      expect(await phone.sync.conflicts(), isEmpty);
    });

    test('the same statement line imported on both stays once', () async {
      await send(phone, laptop);
      for (final Device x in <Device>[phone, laptop]) {
        await x.store.addEntry(
          accountId: await bank(x),
          amount: d('63200'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 2),
          category: 'groceries',
          payee: 'EXITO',
          source: 'statement',
          sourceRef: 'statement:${await bank(x)}:abc#1',
        );
      }
      await send(phone, laptop);
      await send(laptop, phone);
      expect(await phone.payees(), <String>['EXITO']);
      expect(await laptop.contents(), await phone.contents());
    });

    test('something written again under a deleted id moves to one derived '
        'from it, the same everywhere', () async {
      final Entry gone = await phone.store.addEntry(
        accountId: await bank(phone),
        amount: d('12000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2),
        category: 'transport',
        payee: 'Taxi',
      );
      await send(phone, laptop);
      final Map<String, Object?> row = (await phone.store.syncRecords())
          .firstWhere((SyncRecord r) => r.key == 'entries/${gone.id}')
          .data!;
      phone.later();
      await phone.store.deleteEntry(gone);
      await send(phone, laptop);
      // The same id, written again.
      await phone.store.applySync(
        upserts: <SyncRecord>[
          SyncRecord('entries', gone.id, <String, Object?>{
            ...row,
            'payee': 'Taxi otra vez',
          }),
        ],
        deletes: const <SyncRecord>[],
      );
      await send(phone, laptop);
      await send(laptop, phone);
      for (final Device x in <Device>[phone, laptop]) {
        final Entry e = (await x.store.entries()).single;
        expect(e.id, renewedId(gone.id), reason: x.name);
        expect(e.payee, 'Taxi otra vez');
      }
      expect(await laptop.contents(), await phone.contents());
    });

    test('brought back on two devices, it is still one; two movements of '
        'one deleted account bring back one account', () async {
      final Entry gym = await phone.store.addEntry(
        accountId: await bank(phone),
        amount: d('119000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 1),
        category: 'leisure',
        payee: 'Fit24',
      );
      await send(phone, laptop);
      phone.later();
      await phone.store.updateEntry(gym.copyWith(note: 'Anual'));
      laptop.later();
      await laptop.store.deleteEntry((await laptop.store.entries()).single);
      final Uint8List edited = await phone.sync.export();
      await send(laptop, phone);
      await laptop.sync.import(edited);
      SyncConflict entryConflict(List<SyncConflict> all) =>
          all.singleWhere((SyncConflict c) => c.record.table == 'entries');
      await phone.sync.restore(entryConflict(await phone.sync.conflicts()));
      await laptop.sync.restore(entryConflict(await laptop.sync.conflicts()));
      await send(phone, laptop);
      await send(laptop, phone);
      expect(await phone.payees(), <String>['Fit24']);
      expect(await laptop.contents(), await phone.contents());

      // An account deleted on the laptop while the phone added two movements.
      final String id = await bank(phone);
      laptop.later();
      await laptop.store.deleteAccount(id);
      phone.later();
      for (final String payee in <String>['Metro', 'Bus']) {
        await phone.store.addEntry(
          accountId: id,
          amount: d('3000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 3),
          category: 'transport',
          payee: payee,
        );
      }
      await send(laptop, phone);
      for (final SyncConflict c in <SyncConflict>[
        for (final SyncConflict c in await phone.sync.conflicts())
          if (c.reason == ConflictReason.withAccount) c,
      ]) {
        await phone.sync.restore(c);
      }
      expect((await phone.store.accounts()).single.id, renewedId(id));
      await send(phone, laptop);
      expect(await laptop.payees(), <String>['Bus', 'Metro']);
      expect((await laptop.store.accounts()).single.id, renewedId(id));
    });

    test('a device that just joined keeps its own order across two files '
        'before it merges one', () async {
      final Account mine = await laptop.store.addAccount(
        name: 'Efectivo',
        kind: AccountKind.cash,
        asset: Asset.cop,
        opening: d('50000'),
      );
      final Uint8List first = await laptop.sync.export();
      laptop.later();
      await laptop.store.updateAccount(mine.copyWith(name: 'Billetera'));
      final Uint8List second = await laptop.sync.export();
      await phone.sync.import(second);
      await phone.sync.import(first);
      expect(
        (await phone.store.accounts()).map((Account a) => a.name),
        contains('Billetera'),
      );
      expect(
        (await phone.store.accounts()).map((Account a) => a.name),
        isNot(contains('Efectivo')),
      );
    });

    test('a database older than its keychain starts again as one that just '
        'joined, and loses nothing', () async {
      await send(phone, laptop);
      final String older = (await laptop.store.setting('sync.state'))!;
      laptop.later();
      await laptop.store.addEntry(
        accountId: await bank(laptop),
        amount: d('5000'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'restaurants',
        payee: 'Pan',
      );
      await send(laptop, phone);
      // The laptop's database comes back from an older backup of itself.
      await laptop.store.setSetting('sync.state', older);
      laptop.later();
      final Entry pan = (await laptop.store.entries()).single;
      await laptop.store.updateEntry(pan.copyWith(payee: 'Pan y café'));
      await send(laptop, phone);
      await send(phone, laptop);
      // What came back from the backup cannot tell its old records from
      // its new edit: the vault's version shows, and the edit waits on the
      // phone to be brought back, never lost.
      expect(await phone.payees(), <String>['Pan']);
      expect(<Object?>[
        for (final SyncConflict c in await phone.sync.conflicts())
          c.record.data?['payee'],
      ], contains('Pan y café'));
      expect(await laptop.contents(), await phone.contents());
    });

    test('a scenario whose id has a slash arrives whole', () async {
      await phone.store.setSetting(
        'plan.scenarios',
        '[{"id":"charge-Netflix/HBO-5000","kind":"charge"}]',
      );
      await send(phone, laptop);
      expect(
        await laptop.store.setting('plan.scenarios'),
        contains('charge-Netflix/HBO-5000'),
      );
      await send(laptop, phone);
      expect(
        await phone.store.setting('plan.scenarios'),
        contains('charge-Netflix/HBO-5000'),
      );
    });

    test('a wallet followed on both devices ends one account with one '
        'adjustment', () async {
      Future<(Account, Entry)> follow(Device x) async {
        final Account w = await x.store.addAccount(
          name: 'Bitcoin',
          kind: AccountKind.wallet,
          asset: Asset.btc,
          opening: d('0.01'),
          spendable: false,
          syncRef: 'wallet:bitcoin:bc1qexample:BTC',
        );
        final Entry e = await x.store.addEntry(
          accountId: w.id,
          amount: d('0.002'),
          kind: EntryKind.adjustment,
          date: DateTime(2026, 10, 3),
          payee: 'Ajuste con la billetera',
          source: 'wallet',
          sourceRef: 'wallet:bitcoin:bc1qexample:BTC:adjust:1',
        );
        return (w, e);
      }

      var (Account wallet, Entry line) = await follow(laptop);
      var (Account phoneWallet, Entry phoneLine) = await follow(phone);
      // Ids are random: draw them again until they fall the way that once
      // lost the line. The laptop keeps its own account and the
      // phone's line, moved to it; offered that line under the version it
      // had, the phone would keep its own copy, by hash.
      Future<bool> worst() async {
        if (phoneWallet.id.compareTo(wallet.id) < 0 ||
            phoneLine.id.compareTo(line.id) > 0) {
          return false;
        }
        final Map<String, Object?> data = (await phone
            .contents())['entries/${phoneLine.id}']!;
        final Map<String, Object?> moved = <String, Object?>{
          ...data,
          'accountId': wallet.id,
        };
        return contentHash(data).compareTo(contentHash(moved)) > 0;
      }

      for (var tries = 0; tries < 200 && !await worst(); tries++) {
        await laptop.store.deleteAccount(wallet.id);
        await phone.store.deleteAccount(phoneWallet.id);
        (wallet, line) = await follow(laptop);
        (phoneWallet, phoneLine) = await follow(phone);
      }
      expect(await worst(), isTrue);

      await send(phone, laptop);
      await send(laptop, phone);
      await send(phone, laptop);
      for (final Device x in <Device>[phone, laptop]) {
        expect(
          <String>[
            for (final Account a in await x.store.accounts())
              if (a.syncRef != null) a.id,
          ],
          <String>[wallet.id],
          reason: x.name,
        );
        expect(
          <String>[
            for (final Entry e in await x.store.entries())
              if (e.accountId == wallet.id) e.id,
          ],
          <String>[phoneLine.id],
          reason: x.name,
        );
      }
      expect(await laptop.contents(), await phone.contents());
    });

    test('a card\'s limit given on one reaches the other, and taken away '
        'it goes on both', () async {
      await send(phone, laptop);
      phone.later();
      final Account visa = await phone.store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: d('-300000'),
        creditLimit: d('2000000'),
      );
      // An account with no limit reads as it did before limits existed:
      // a device on either version takes it for the same one.
      final String bankId = await bank(phone);
      final Map<String, Object?> bankRecord = (await phone.store.syncRecords())
          .firstWhere((SyncRecord r) => r.id == bankId)
          .data!;
      expect(bankRecord.containsKey('creditLimit'), isFalse);

      await send(phone, laptop);
      Account there = (await laptop.store.accounts()).firstWhere(
        (Account a) => a.id == visa.id,
      );
      expect(there.creditLimit, d('2000000'));
      expect(await laptop.contents(), await phone.contents());

      laptop.later();
      await laptop.store.updateAccount(there.copyWith(clearCreditLimit: true));
      await send(laptop, phone);
      there = (await phone.store.accounts()).firstWhere(
        (Account a) => a.id == visa.id,
      );
      expect(there.creditLimit, isNull);
      expect(await laptop.contents(), await phone.contents());
      expect(await phone.sync.conflicts(), isEmpty);
    });

    test('an account archived on one, with what was paid from it moved, '
        'arrives archived on the other and comes back on both', () async {
      final String bankId = await bank(phone);
      final Account visa = await phone.store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: d('-42900'),
      );
      await phone.store.addRecurring(
        name: 'Netflix',
        amount: Money(d('26900'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 12),
        accountId: visa.id,
      );
      await send(phone, laptop);
      // The laptop's own profile, from before it joined, waits apart.
      final int waiting = (await laptop.sync.conflicts()).length;

      phone.later();
      await phone.store.moveRecurring(<String>{visa.id}, bankId);
      await phone.store.updateAccount(visa.copyWith(archived: true));
      await send(phone, laptop);
      final Account there = (await laptop.store.accounts(
        archived: true,
      )).firstWhere((Account a) => a.id == visa.id);
      expect(there.archived, isTrue);
      expect(await laptop.store.accounts(), hasLength(1));
      expect((await laptop.store.recurring()).single.accountId, bankId);
      expect(await laptop.contents(), await phone.contents());
      expect(await laptop.sync.conflicts(), hasLength(waiting));

      laptop.later();
      await laptop.store.updateAccount(there.copyWith(archived: false));
      await send(laptop, phone);
      expect(await phone.store.accounts(), hasLength(2));
      expect(await laptop.contents(), await phone.contents());
      expect(await phone.sync.conflicts(), isEmpty);
    });

    test('stopping forgets the key and keeps the data', () async {
      await send(phone, laptop);
      await laptop.sync.stop();
      expect(await laptop.sync.linked, isFalse);
      expect(await laptop.sync.code(), isNull);
      expect((await laptop.store.accounts()).single.name, 'Bancolombia');
    });
  });

  test('three devices converge whatever the order of files', () async {
    final DateTime start = DateTime(2026, 10, 3, 9);
    final List<Device> devices = <Device>[
      for (final String n in <String>['a', 'b', 'c']) Device(n, start),
    ];
    for (final Device x in devices) {
      await x.store.ensureCategories();
    }
    final String code = await devices[0].sync.start();
    await devices[1].sync.join(code);
    await devices[2].sync.join(code);
    final Account bank = await devices[0].store.addAccount(
      name: 'Nequi',
      kind: AccountKind.wallet,
      asset: Asset.cop,
      opening: d('100000'),
    );
    final Uint8List first = await devices[0].sync.export();
    await devices[1].sync.import(first);
    await devices[2].sync.import(first);
    for (var i = 0; i < 3; i++) {
      devices[i].later(Duration(minutes: i + 1));
      await devices[i].store.addEntry(
        accountId: bank.id,
        amount: d('${(i + 1) * 1000}'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 3),
        category: 'other',
        payee: 'gasto ${devices[i].name}',
      );
      // The same setting changed on every device.
      await devices[i].store.setSetting('plan.cushion', '{"days":${i + 10}}');
    }
    final List<Uint8List> files = <Uint8List>[
      for (final Device x in devices) await x.sync.export(),
    ];
    // Each device gets the others' files in its own order.
    await devices[0].sync.import(files[2]);
    await devices[0].sync.import(files[1]);
    await devices[1].sync.import(files[0]);
    await devices[1].sync.import(files[2]);
    await devices[2].sync.import(files[1]);
    await devices[2].sync.import(files[0]);
    // One more round so every merge is seen everywhere.
    final List<Uint8List> again = <Uint8List>[
      for (final Device x in devices) await x.sync.export(),
    ];
    for (final Device x in devices) {
      for (final Uint8List f in again) {
        await x.sync.import(f);
      }
    }
    final Map<String, Map<String, Object?>?> first0 = await devices[0]
        .contents();
    expect(await devices[0].payees(), <String>[
      'gasto a',
      'gasto b',
      'gasto c',
    ]);
    expect(await devices[1].contents(), first0);
    expect(await devices[2].contents(), first0);
    // The latest change of the setting won everywhere: c's.
    expect(first0['settings/plan.cushion']!['json'], <String, Object?>{
      'days': 12,
    });
    for (final Device x in devices) {
      await x.store.close();
    }
  });
}
