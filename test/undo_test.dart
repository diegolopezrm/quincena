// Whatever is deleted, discarded or archived comes back exactly as it was
// with its way back: the same ids and dates, and what pointed at it, a
// split, an envelope, a payment's movement, pointing at it again. Each
// test compares everything that syncs before the action and after taking
// it back.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/data/example_prices.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/freelance.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/plan.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/domain/trips.dart';
import 'package:quincena/exchanges/wallets.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/undo.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/sync/merge.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  final DateTime now = DateTime(2026, 10, 3, 10);

  /// The store's clock, which a test can move on.
  late DateTime clock;
  late QuincenaStore store;
  late OwnController own;
  late Account bank;
  late Account nequi;

  /// Waits for the controller to read what the store now holds.
  Future<void> reread(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // And for the read a last write started.
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  /// Everything that syncs, by record.
  Future<Map<String, Object?>> everything() async => <String, Object?>{
    for (final SyncRecord r in await store.syncRecords()) r.key: r.data,
  };

  Entry entry(String payee) =>
      own.snapshot!.entries.firstWhere((Entry e) => e.payee == payee);

  bool has(String id) => own.snapshot!.entries.any((Entry e) => e.id == id);

  setUp(() async {
    clock = now;
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => clock,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
    );
    bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('1000000'),
    );
    nequi = await store.addAccount(
      name: 'Nequi',
      kind: AccountKind.wallet,
      asset: Asset.cop,
      opening: d('200000'),
    );
    for (final (String payee, String amount) in <(String, String)>[
      ('Crepes & Waffles', '47000'),
      ('Rappi', '23500'),
    ]) {
      await store.addEntry(
        accountId: nequi.id,
        amount: d(amount),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, 12),
        category: 'restaurants',
        payee: payee,
      );
    }
    await store.addTransfer(
      fromAccountId: bank.id,
      toAccountId: nequi.id,
      sent: d('50000'),
      date: DateTime(2026, 10, 1, 9),
    );
    // Rates from the example's fixed ones: no network.
    own = OwnController(
      store,
      now: () => now,
      readNative: false,
      fetcher: ExampleRates(now: () => now),
    );
    await own.start();
    await reread(() => own.snapshot != null && !own.refreshingRates);
  });

  tearDown(() async {
    await reread(() => !own.refreshingRates);
    own.dispose();
    await store.close();
  });

  test('a movement comes back with its id, its dates and its split', () async {
    final Entry crepes = entry('Crepes & Waffles');
    await own.saveGroup(
      Group(
        id: 'g-ana',
        name: 'Ana y yo',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'p-ana', name: 'Ana'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'x-crepes',
            label: 'Crepes & Waffles',
            date: crepes.date,
            paidBy: meId,
            shares: const <String, int>{meId: 23500, 'p-ana': 23500},
            entryId: crepes.id,
          ),
        ],
      ),
    );
    await reread(() => own.splitOf(crepes.id) != null);
    final Map<String, Object?> before = await everything();

    final Undo back = await own.deleteMovement(crepes);
    await reread(() => !has(crepes.id));
    expect(has(crepes.id), isFalse);
    expect(own.splitOf(crepes.id), isNull);

    await back();
    await reread(() => has(crepes.id));
    expect(own.splitOf(crepes.id)!.$2.id, 'x-crepes');
    expect(await everything(), before);
  });

  test('a transfer comes back with both legs', () async {
    final Entry leg = own.snapshot!.entries.firstWhere(
      (Entry e) => e.transferId != null,
    );
    final Map<String, Object?> before = await everything();

    final Undo back = await own.deleteMovement(leg);
    await reread(
      () => !own.snapshot!.entries.any((Entry e) => e.transferId != null),
    );
    expect(
      own.snapshot!.entries.where((Entry e) => e.transferId != null),
      isEmpty,
    );

    await back();
    await reread(
      () =>
          own.snapshot!.entries
              .where((Entry e) => e.transferId != null)
              .length ==
          2,
    );
    expect(await everything(), before);
  });

  test('a deleted account comes back with its movements, the other leg of '
      'its transfers and what was paid from it', () async {
    await store.addRecurring(
      name: 'Spotify',
      amount: Money(d('16900'), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 20),
      accountId: nequi.id,
    );
    await own.saveInstalments(
      Instalments(
        id: 'i-phone',
        name: 'Celular',
        principal: 600000,
        count: 6,
        firstDue: DateTime(2026, 10, 25),
        accountId: nequi.id,
      ),
    );
    await reread(() => own.instalments.isNotEmpty && own.recurring.isNotEmpty);
    final Map<String, Object?> before = await everything();

    final Undo back = await own.leave(
      <Account>[nequi],
      delete: true,
      movedTo: bank.id,
    );
    await reread(() => own.snapshot!.account(nequi.id) == null);
    expect(own.snapshot!.account(nequi.id), isNull);
    final Entry left = own.snapshot!.entries.firstWhere(
      (Entry e) => e.accountId == bank.id && e.amount == d('-50000'),
    );
    expect(left.transferId, isNull);
    expect(left.kind, EntryKind.expense);
    expect(own.recurring.single.accountId, bank.id);
    expect(own.instalments.single.accountId, bank.id);

    await back();
    await reread(() => own.snapshot!.account(nequi.id) != null);
    expect(own.instalments.single.accountId, nequi.id);
    expect(await everything(), before);
  });

  test('an archived account comes back with what was paid from it', () async {
    await store.addRecurring(
      name: 'Spotify',
      amount: Money(d('16900'), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: DateTime(2026, 10, 20),
      accountId: nequi.id,
    );
    await reread(() => own.recurring.isNotEmpty);
    final Map<String, Object?> before = await everything();

    final Undo back = await own.leave(<Account>[nequi], delete: false);
    await reread(() => own.archivedAccounts.isNotEmpty);
    expect(own.archivedAccounts.single.id, nequi.id);
    expect(own.recurring.single.accountId, isNull);

    await back();
    await reread(() => own.archivedAccounts.isEmpty);
    expect(await everything(), before);
  });

  test('a goal comes back with its envelope where it was', () async {
    final SavingsGoal goal = await store.addGoal(
      name: 'Moto',
      target: Money(d('8000000'), Asset.cop),
      saved: Money(d('1200000'), Asset.cop),
    );
    // Made a minute later: put back, the first goes back first.
    clock = now.add(const Duration(minutes: 1));
    await store.addGoal(name: 'Viaje', target: Money(d('3000000'), Asset.cop));
    await own.savePlan(
      EnvelopePlan(
        period: DateTime(2026, 10),
        envelopes: <Envelope>[
          const Envelope(
            id: 'daily',
            kind: EnvelopeKind.daily,
            name: '',
            amount: 300000,
          ),
          Envelope(
            id: 'goal-${goal.id}',
            kind: EnvelopeKind.goal,
            name: 'Moto',
            amount: 200000,
            goalId: goal.id,
          ),
          const Envelope(
            id: 'aside',
            kind: EnvelopeKind.aside,
            name: 'Regalo',
            amount: 50000,
          ),
        ],
      ),
    );
    await reread(() => own.snapshot!.goals.length == 2 && own.lastPlan != null);
    final Map<String, Object?> before = await everything();

    final Undo back = await own.removeGoal(goal);
    await reread(() => own.snapshot!.goals.length == 1);
    expect(own.lastPlan!.envelopes.map((Envelope e) => e.id), <String>[
      'daily',
      'aside',
    ]);

    await back();
    await reread(() => own.snapshot!.goals.length == 2);
    expect(own.snapshot!.goals.map((SavingsGoal g) => g.name), <String>[
      'Moto',
      'Viaje',
    ]);
    expect(await everything(), before);
  });

  test(
    'a fixed payment comes back with what the person told about it',
    () async {
      final RecurringCharge max = await store.addRecurring(
        name: 'Max',
        amount: Money(d('19900'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 10, 15),
        accountId: bank.id,
        category: 'subscriptions',
      );
      await own.saveMemory(
        max.id,
        ChargeMemory(trialEnds: DateTime(2026, 10, 15), remindDays: 2),
      );
      await reread(() => own.recurring.isNotEmpty);
      final Map<String, Object?> before = await everything();

      final Undo back = await own.removeCharge(max);
      await reread(() => own.recurring.isEmpty);
      expect(own.memoryOf(max.id).trialEnds, isNull);

      await back();
      await reread(() => own.recurring.isNotEmpty);
      expect(own.memoryOf(max.id).remindDays, 2);
      expect(await everything(), before);
    },
  );

  test('a payment of a purchase in instalments comes back with the movement '
      'it went out with', () async {
    await own.saveInstalments(
      Instalments(
        id: 'i-phone',
        name: 'Celular',
        principal: 600000,
        count: 6,
        firstDue: DateTime(2026, 10, 1),
        instalment: 100000,
      ),
    );
    await reread(() => own.instalments.isNotEmpty);
    await own.payInstalment(
      own.instalments.single,
      DateTime(2026, 10, 1),
      100000,
      accountId: bank.id,
    );
    await reread(() => own.instalments.single.payments.isNotEmpty);
    final String made = own.instalments.single.entryOf(0)!;
    final Map<String, Object?> before = await everything();

    final Undo back = await own.removePayment(own.instalments.single, 0);
    await reread(() => !has(made));
    expect(own.instalments.single.payments, isEmpty);

    await back();
    await reread(() => has(made));
    expect(own.instalments.single.entryOf(0), made);
    expect(await everything(), before);
  });

  test('a payment in a group and an expense split from it come back with '
      'the movements the Plan wrote', () async {
    const Group group = Group(
      id: 'g-trip',
      name: 'Paseo',
      members: <Member>[
        Member(id: meId, name: ''),
        Member(id: 'p-juan', name: 'Juan'),
      ],
    );
    final String paid = await own.payGroupExpense(
      accountId: bank.id,
      amount: 90000,
      date: DateTime(2026, 10, 2),
      label: 'Hotel',
      group: group.name,
    );
    await own.saveGroup(
      group.withExpense(
        SharedExpense(
          id: 'x-hotel',
          label: 'Hotel',
          date: DateTime(2026, 10, 2),
          paidBy: meId,
          shares: const <String, int>{meId: 45000, 'p-juan': 45000},
          entryId: paid,
        ),
      ),
    );
    await reread(() => own.group('g-trip') != null);
    await own.settle(
      own.group('g-trip')!,
      Settlement(
        id: 's-juan',
        from: 'p-juan',
        to: meId,
        amount: 45000,
        date: DateTime(2026, 10, 3),
      ),
      accountId: bank.id,
    );
    await reread(() => own.group('g-trip')!.settlements.isNotEmpty);
    final Settlement settled = own.group('g-trip')!.settlements.single;
    final Map<String, Object?> before = await everything();

    Undo back = await own.removeSettlement(own.group('g-trip')!, settled);
    await reread(() => !has(settled.entryId!));
    expect(own.group('g-trip')!.settlements, isEmpty);
    await back();
    await reread(() => has(settled.entryId!));
    expect(await everything(), before);

    final SharedExpense hotel = own.group('g-trip')!.expenses.single;
    back = await own.removeSplit(own.group('g-trip')!, hotel, dropEntry: true);
    await reread(() => !has(paid));
    expect(own.group('g-trip')!.expenses, isEmpty);
    await back();
    await reread(() => has(paid));
    expect(await everything(), before);
  });

  test('what is deleted from the Plan comes back as it was', () async {
    await own.saveGroup(
      const Group(
        id: 'g-ana',
        name: 'Ana y yo',
        members: <Member>[
          Member(id: meId, name: ''),
          Member(id: 'p-ana', name: 'Ana'),
        ],
      ),
    );
    await own.saveTrip(
      Trip(
        id: 'trip-ny',
        name: 'Nueva York',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 8),
        currency: 'USD',
      ),
    );
    await own.saveInstalments(
      Instalments(
        id: 'i-tv',
        name: 'Televisor',
        principal: 1200000,
        count: 12,
        firstDue: DateTime(2026, 11, 1),
      ),
    );
    await own.saveWishes(const <Wish>[
      Wish(id: 'w-bici', name: 'Bicicleta', price: 900000),
      Wish(id: 'w-libro', name: 'Libro', price: 60000, priority: 3),
    ]);
    await own.saveScenarios(const <Scenario>[
      Scenario(id: 'save-100', kind: ScenarioKind.saveMore, amount: 100000),
    ]);
    await own.saveFreelance(
      FreelancePlan(
        incomes: <ExpectedIncome>[
          ExpectedIncome(
            id: 'inc-1',
            client: 'Agencia Uno',
            amount: 700000,
            expected: DateTime(2026, 10, 10),
          ),
          ExpectedIncome(
            id: 'inc-2',
            client: 'Taller de marca',
            amount: 300000,
            expected: DateTime(2026, 10, 20),
          ),
        ],
        reservePercent: 15,
      ),
    );
    await reread(
      () =>
          own.groups.isNotEmpty &&
          own.trips.isNotEmpty &&
          own.instalments.isNotEmpty &&
          own.wishes.length == 2 &&
          own.scenarios.isNotEmpty &&
          own.freelance.incomes.length == 2,
    );
    final Map<String, Object?> before = await everything();

    Future<void> takeBack(
      Future<Undo> Function() action,
      bool Function() gone,
    ) async {
      final Undo back = await action();
      await reread(gone);
      expect(gone(), isTrue);
      await back();
      await reread(() => !gone());
      expect(await everything(), before);
    }

    await takeBack(
      () => own.removeGroup(own.group('g-ana')!),
      () => own.groups.isEmpty,
    );
    await takeBack(
      () => own.removeTrip(own.trip('trip-ny')!),
      () => own.trips.isEmpty,
    );
    await takeBack(
      () => own.removeInstalments(own.instalments.single),
      () => own.instalments.isEmpty,
    );
    await takeBack(
      () => own.removeWish(own.wishes.first),
      () => own.wishes.length == 1,
    );
    expect(own.wishes.map((Wish w) => w.id), <String>['w-bici', 'w-libro']);
    await takeBack(
      () => own.removeScenario(own.scenarios.single),
      () => own.scenarios.isEmpty,
    );
    await takeBack(
      () => own.removeIncome(own.freelance.incomes.first),
      () => own.freelance.incomes.length == 1,
    );
    expect(own.freelance.incomes.map((ExpectedIncome i) => i.id), <String>[
      'inc-1',
      'inc-2',
    ]);
  });

  test('an expense taken out of a trip counts in it again, one from before '
      'its days among them', () async {
    final Entry flight = await store.addEntry(
      accountId: bank.id,
      amount: d('1800000'),
      kind: EntryKind.expense,
      date: DateTime(2026, 9, 10, 9),
      category: 'travel',
      payee: 'Avianca',
    );
    final Entry rappi = entry('Rappi');
    await own.saveTrip(
      Trip(
        id: 'trip-ny',
        name: 'Nueva York',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 8),
        currency: 'COP',
        included: <String>{flight.id},
      ),
    );
    await reread(() => own.trips.isNotEmpty && has(flight.id));
    final Map<String, Object?> before = await everything();

    final Undo back = await own.leaveOutOfTrip(own.trip('trip-ny')!, flight);
    await reread(() => own.trip('trip-ny')!.excluded.isNotEmpty);
    expect(own.trip('trip-ny')!.covers(flight), isFalse);
    await back();
    await reread(() => own.trip('trip-ny')!.excluded.isEmpty);
    expect(await everything(), before);

    // From the list of what was taken out, later: in its days it is simply
    // counted again, and the flight is kept as one of the trip's.
    await own.leaveOutOfTrip(own.trip('trip-ny')!, rappi);
    await reread(() => own.trip('trip-ny')!.excluded.isNotEmpty);
    await own.leaveOutOfTrip(own.trip('trip-ny')!, flight);
    await reread(() => own.trip('trip-ny')!.excluded.length == 2);
    await own.backInTrip(own.trip('trip-ny')!, rappi);
    await reread(() => own.trip('trip-ny')!.excluded.length == 1);
    await own.backInTrip(own.trip('trip-ny')!, flight);
    await reread(() => own.trip('trip-ny')!.excluded.isEmpty);
    expect(own.trip('trip-ny')!.covers(flight), isTrue);
    expect(own.trip('trip-ny')!.covers(rappi), isTrue);
    expect(await everything(), before);
  });

  group('captures', () {
    CaptureEvent bancolombia(String text, int minute) => CaptureEvent(
      source: CaptureSource.notification,
      at: DateTime(2026, 10, 3, 9, minute),
      app: 'com.todo1.mobile',
      appName: 'Bancolombia',
      title: 'Bancolombia',
      text: 'Bancolombia · $text',
    );

    Future<InboxItem> stored(String id) async => (await store.inboxItem(id))!;

    test('a discarded capture waits again as it did, and its app is read '
        'again', () async {
      await own.capture.ingest(<CaptureEvent>[
        bancolombia(r'Compra por $63.200 en EXITO LAURELES T.Deb *1234', 40),
      ]);
      await reread(() => own.pendingInbox.isNotEmpty);
      final InboxItem item = own.pendingInbox.single;
      final InboxItem waiting = await stored(item.id);

      final Undo back = await own.discard(item, muteApp: true);
      await reread(() => own.pendingInbox.isEmpty);
      expect((await stored(item.id)).status, InboxStatus.dismissed);
      expect(own.captureSettings.mutedApps, <String>{'com.todo1.mobile'});
      expect(own.discardedInbox.single.id, item.id);

      await back();
      await reread(() => own.pendingInbox.isNotEmpty);
      final InboxItem again = await stored(item.id);
      expect(again.status, InboxStatus.pending);
      expect(again.parsedJson(), waiting.parsedJson());
      expect(own.captureSettings.mutedApps, isEmpty);
      expect(own.captureSettings.appNames, isEmpty);
      expect(own.discardedInbox, isEmpty);
    });

    test('a possible repeat discarded comes back as one, also from the list '
        'of what was discarded', () async {
      const String text = r'Compra por $63.200 en EXITO LAURELES T.Deb *1234';
      await own.capture.ingest(<CaptureEvent>[bancolombia(text, 40)]);
      await own.capture.ingest(<CaptureEvent>[bancolombia(text, 41)]);
      await reread(
        () => own.inbox.any((InboxItem i) => i.status == InboxStatus.duplicate),
      );
      final InboxItem repeat = own.inbox.firstWhere(
        (InboxItem i) => i.status == InboxStatus.duplicate,
      );

      final Undo back = await own.discard(repeat);
      await reread(() => own.discardedInbox.isNotEmpty);
      await back();
      await reread(() => own.discardedInbox.isEmpty);
      expect((await stored(repeat.id)).status, InboxStatus.duplicate);

      await own.discard(repeat);
      await reread(() => own.discardedInbox.isNotEmpty);
      await own.bringBack(own.discardedInbox.single);
      await reread(() => own.discardedInbox.isEmpty);
      final InboxItem again = await stored(repeat.id);
      expect(again.status, InboxStatus.duplicate);
      expect(again.duplicateOf, repeat.duplicateOf);
    });

    test('a deleted rule comes back as it was, off when it was off', () async {
      await store.saveCaptureSettings(
        const CaptureSettings(
          merchantCategories: <String, String>{'exito laureles': 'groceries'},
          disabledRules: <String>{'merchant:exito laureles'},
        ),
      );
      await reread(() => own.captureSettings.rules.isNotEmpty);
      final Map<String, Object?> before = await everything();
      final CaptureRule rule = own.captureSettings.rules.single;
      expect(rule.enabled, isFalse);

      final Undo back = await own.deleteRule(rule);
      await reread(() => own.captureSettings.rules.isEmpty);
      await back();
      await reread(() => own.captureSettings.rules.isNotEmpty);
      expect(own.captureSettings.rules.single, rule);
      expect(await everything(), before);
    });

    test('an app read again from the list stops being muted', () async {
      await store.saveCaptureSettings(
        const CaptureSettings(
          mutedApps: <String>{'com.todo1.mobile', 'com.nequi.app'},
          appNames: <String, String>{
            'com.todo1.mobile': 'Bancolombia',
            'com.nequi.app': 'Nequi',
          },
        ),
      );
      await reread(() => own.captureSettings.mutedApps.isNotEmpty);
      await own.readAgain('com.todo1.mobile');
      await reread(() => own.captureSettings.mutedApps.length == 1);
      expect(own.captureSettings.mutedApps, <String>{'com.nequi.app'});
      expect(own.captureSettings.appNames, <String, String>{
        'com.nequi.app': 'Nequi',
      });
    });
  });

  test('an alert put away and a merchant said not to be a fixed payment come '
      'back', () async {
    for (final int hour in <int>[9, 10]) {
      await store.addEntry(
        accountId: bank.id,
        amount: d('63200'),
        kind: EntryKind.expense,
        date: DateTime(2026, 10, 2, hour),
        category: 'groceries',
        payee: 'Éxito Laureles',
      );
    }
    // What the person told the detective is kept, if only that nothing.
    await own.muteAlerts(AlertKind.priceUp, muted: false);
    await reread(() => own.allAlerts.isNotEmpty);
    final ChargeAlert twice = own.allAlerts.firstWhere(
      (ChargeAlert a) => a.kind == AlertKind.twice,
    );
    final Map<String, Object?> before = await everything();

    Undo back = await own.putAlertAway(twice.id, AlertAnswer.dismissed);
    await reread(() => own.detective.answers.isNotEmpty);
    expect(own.alerts.map((ChargeAlert a) => a.id), isNot(contains(twice.id)));
    await back();
    await reread(() => own.detective.answers.isEmpty);
    expect(own.alerts.map((ChargeAlert a) => a.id), contains(twice.id));

    back = await own.sayNotRecurring('Netflix');
    await reread(() => own.detective.notRecurring.isNotEmpty);
    await back();
    await reread(() => own.detective.notRecurring.isEmpty);
    expect(await everything(), before);
  });

  test('a wallet no longer followed is followed again where it was', () async {
    const WalletAddress ledger = WalletAddress(
      chain: Chain.bitcoin,
      address: 'bc1qexampleaddress0000000000000000000lmg5w',
      label: 'Ledger',
    );
    const WalletAddress metamask = WalletAddress(
      chain: Chain.ethereum,
      address: '0x1111111111111111111111111111111111111111',
      label: 'MetaMask',
    );
    await store.setSetting(
      'wallets',
      jsonEncode(<String, Object?>{
        'wallets': <Object?>[ledger.toJson(), metamask.toJson()],
        'syncedAt': null,
      }),
    );
    await own.wallets.load();
    final Map<String, Object?> before = await everything();

    final Undo back = await own.stopFollowing(ledger);
    expect(own.wallets.wallets, <WalletAddress>[metamask]);
    await back();
    expect(own.wallets.wallets, <WalletAddress>[ledger, metamask]);
    await reread(() => true);
    expect(await everything(), before);
  });
}
