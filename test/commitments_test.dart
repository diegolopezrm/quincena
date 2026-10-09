import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/ledger_builder.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/reminders/reminders.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  late QuincenaStore store;
  late Account bank;
  final DateTime today = DateTime(2026, 10, 3);

  setUp(() async {
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => today,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Ana', base: Asset.cop, schedule: TwiceMonthly()),
    );
    bank = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      opening: d('5000000'),
    );
  });

  tearDown(() => store.close());

  setUpAll(() async {
    Intl.defaultLocale = 'es_CO';
    await initializeDateFormatting('es');
  });

  Future<Ledger> ledger() async =>
      buildLedger((await store.snapshot())!, today: today).ledger;

  Future<Entry> spend(
    String amount,
    DateTime on,
    String payee, {
    String category = 'subscriptions',
    String source = 'manual',
  }) => store.addEntry(
    accountId: bank.id,
    amount: d(amount),
    kind: EntryKind.expense,
    date: on,
    category: category,
    payee: payee,
    source: source,
  );

  group('subscriptions', () {
    test('the next charge counts on from a day long past', () {
      final RecurringCharge netflix = RecurringCharge(
        id: 'n',
        name: 'Netflix',
        amount: Money(d('26900'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 7, 12),
      );
      expect(nextCharge(netflix, today), DateTime(2026, 10, 12));
      expect(perYear(Cadence.biweekly), 26);
    });

    test('after a trial it charges from the day the trial ended', () {
      // Saved a month after it was added, with a trial to the 28th.
      final RecurringCharge max = RecurringCharge(
        id: 'm',
        name: 'Max',
        amount: Money(d('19900'), Asset.cop),
        cadence: Cadence.monthly,
        nextDate: DateTime(2026, 11, 3),
      );
      expect(nextCharge(max, today), DateTime(2026, 11, 3));
      expect(
        afterTrial(max, DateTime(2026, 9, 28), today),
        DateTime(2026, 10, 28),
      );
      expect(
        nextCharge(max.withNextDate(DateTime(2026, 10, 28)), today),
        DateTime(2026, 10, 28),
      );
    });

    test('a price that moved is told, with when', () async {
      await spend('26900', DateTime(2026, 7, 12), 'Netflix');
      await spend('26900', DateTime(2026, 8, 12), 'NETFLIX.COM');
      await spend('33900', DateTime(2026, 9, 12), 'Netflix');
      final PriceChange change = lastPriceChange(await ledger(), 'Netflix')!;
      expect(change.from, 26900);
      expect(change.to, 33900);
      expect(change.on, DateTime(2026, 9, 12));
    });

    test('monthly charges not yet recurring are offered', () async {
      for (final int m in <int>[7, 8, 9]) {
        await spend('16900', DateTime(2026, m, 5), 'Spotify');
        await spend('26900', DateTime(2026, m, 12), 'Netflix');
      }
      // Irregular: not offered.
      await spend(
        '50000',
        DateTime(2026, 8, 1),
        'Rappi',
        category: 'restaurants',
      );
      await spend(
        '20000',
        DateTime(2026, 8, 20),
        'Rappi',
        category: 'restaurants',
      );
      final List<RecurringGuess> guesses = guessRecurring(
        await ledger(),
        known: const <String>['Netflix'],
      );
      expect(guesses.single.name, 'Spotify');
      expect(guesses.single.next, DateTime(2026, 10, 5));
      expect(guesses.single.evidence, hasLength(3));
    });
  });

  group('instalments', () {
    test('a rate E.A. becomes a monthly one and an instalment', () {
      final Instalments tv = Instalments(
        id: 't',
        name: 'Televisor',
        principal: 2400000,
        count: 12,
        firstDue: DateTime(2026, 11, 5),
        rate: 26.82,
        fee: 0,
        cashPrice: 2400000,
      );
      expect(tv.monthlyRate, closeTo(0.0200, 0.0001));
      expect(tv.payment, closeTo(226900, 200));
      final List<InstalmentRow> rows = tv.schedule;
      expect(rows, hasLength(12));
      expect(rows.last.balance, 0);
      expect(
        rows.fold<int>(0, (int s, InstalmentRow r) => s + r.principal),
        2400000,
      );
      expect(rows.last.due, DateTime(2027, 10, 5));
      expect(tv.totalKnown, isTrue);
      expect(tv.total! - tv.cashPrice!, greaterThan(0));
    });

    test(
      'without the fee the total is only estimated, without both unknown',
      () {
        final Instalments phone = Instalments(
          id: 'p',
          name: 'Celular',
          principal: 1200000,
          count: 6,
          firstDue: DateTime(2026, 11, 1),
          instalment: 215000,
        );
        expect(phone.paymentStated, isTrue);
        expect(phone.total, 6 * 215000);
        expect(phone.totalKnown, isFalse);
        final Instalments blind = Instalments(
          id: 'b',
          name: 'Nevera',
          principal: 1800000,
          count: 12,
          firstDue: DateTime(2026, 11, 1),
        );
        expect(blind.payment, isNull);
        expect(blind.total, isNull);
        expect(blind.schedule, isEmpty);
      },
    );

    test('a partial payment covers what it can and leaves the rest owing', () {
      final Instalments zero = Instalments(
        id: 'z',
        name: 'Bicicleta',
        principal: 900000,
        count: 3,
        firstDue: DateTime(2026, 11, 1),
        rate: 0,
        fee: 10000,
      );
      expect(zero.due, 310000);
      final Instalments paid = zero
          .withPayment(DateTime(2026, 11, 1), 310000)
          .withPayment(DateTime(2026, 12, 1), 200000);
      expect(paid.progress, (1, 110000));
      expect(paid.remaining, 3 * 310000 - 510000);
      expect(paid.next!.number, 2);
      expect(Instalments.fromJson(paid.toJson())!.paid, 510000);
    });
  });

  group('the charge detective', () {
    test('the same charge twice, from two sources or one', () async {
      await spend(
        '63200',
        DateTime(2026, 10, 2, 9),
        'Exito',
        category: 'groceries',
        source: 'notification',
      );
      await spend(
        '63200',
        DateTime(2026, 10, 2, 18),
        'EXITO',
        category: 'groceries',
        source: 'statement:abc',
      );
      await spend(
        '9900',
        DateTime(2026, 10, 1, 8),
        'Uber',
        category: 'transport',
        source: 'statement:abc',
      );
      await spend(
        '9900',
        DateTime(2026, 10, 1, 8),
        'Uber',
        category: 'transport',
        source: 'statement:abc',
      );
      final List<ChargeAlert> alerts = detectCharges(
        await store.entries(),
        today: today,
      );
      final List<ChargeAlert> twice = <ChargeAlert>[
        for (final ChargeAlert a in alerts)
          if (a.kind == AlertKind.twice) a,
      ];
      expect(twice, hasLength(2));
      expect(
        twice
            .firstWhere((ChargeAlert a) => a.evidence.first.payee == 'Exito')
            .seenTwice,
        isTrue,
      );
      expect(
        twice
            .firstWhere((ChargeAlert a) => a.evidence.first.payee == 'Uber')
            .seenTwice,
        isFalse,
      );
    });

    test('a price going up and a charge far over the usual', () async {
      await spend('119000', DateTime(2026, 6, 1), 'Fit24');
      await spend('119000', DateTime(2026, 7, 1), 'Fit24');
      await spend('119000', DateTime(2026, 8, 1), 'Fit24');
      await spend('139000', DateTime(2026, 9, 1), 'Fit24');
      for (final int day in <int>[2, 6, 10, 14, 18, 22]) {
        await spend(
          '100000',
          DateTime(2026, 9, day),
          'D1',
          category: 'groceries',
        );
      }
      await spend(
        '480000',
        DateTime(2026, 9, 28),
        'Jumbo',
        category: 'groceries',
      );
      final List<ChargeAlert> alerts = detectCharges(
        await store.entries(),
        today: today,
      );
      final ChargeAlert up = alerts.firstWhere(
        (ChargeAlert a) => a.kind == AlertKind.priceUp,
      );
      expect(up.before, d('119000'));
      expect(up.evidence.last.payee, 'Fit24');
      final ChargeAlert big = alerts.firstWhere(
        (ChargeAlert a) => a.kind == AlertKind.unusual,
      );
      expect(big.evidence.single.payee, 'Jumbo');
      expect(big.times, closeTo(4.8, 0.01));
    });

    test('ordinary spending raises nothing', () async {
      for (final int day in <int>[2, 9, 16, 23]) {
        await spend(
          '100000',
          DateTime(2026, 9, day),
          'D1',
          category: 'groceries',
        );
      }
      expect(detectCharges(await store.entries(), today: today), isEmpty);
    });

    test('three purchases the same day, one seen twice, are no price going '
        'up', () async {
      for (final (String payee, String source) in <(String, String)>[
        ('Exito', 'notification'),
        ('EXITO', 'statement:abc'),
      ]) {
        await spend(
          '63200',
          DateTime(2026, 10, 2, 9, 40),
          payee,
          category: 'groceries',
          source: source,
        );
      }
      await spend(
        '187400',
        DateTime(2026, 10, 2, 12),
        'Exito',
        category: 'groceries',
      );
      final List<ChargeAlert> alerts = detectCharges(
        await store.entries(),
        today: today,
      );
      expect(alerts.map((ChargeAlert a) => a.kind), <AlertKind>[
        AlertKind.twice,
      ]);
    });

    test('a shop whose every purchase differs has no price to go up', () async {
      for (final (int day, String amount) in <(int, String)>[
        (5, '82000'),
        (12, '64000'),
        (19, '95000'),
      ]) {
        await spend(
          amount,
          DateTime(2026, 9, day),
          'D1',
          category: 'groceries',
        );
      }
      await spend('120000', DateTime(2026, 9, 26), 'D1', category: 'groceries');
      expect(
        detectCharges(
          await store.entries(),
          today: today,
        ).where((ChargeAlert a) => a.kind == AlertKind.priceUp),
        isEmpty,
      );
    });
  });

  group('what is committed', () {
    Instalments tv({String? accountId, List<(DateTime, int)>? payments}) =>
        Instalments(
          id: 'tv',
          name: 'Televisor',
          principal: 1200000,
          count: 6,
          firstDue: DateTime(2026, 10, 10),
          rate: 0,
          fee: 0,
          accountId: accountId,
          payments: payments ?? const <(DateTime, int)>[],
        );

    Future<Ledger> withPlans(List<Instalments> plans) async => buildLedger(
      (await store.snapshot())!,
      today: today,
      instalments: plans,
    ).ledger;

    test('an instalment owed outside counts as committed', () async {
      final Ledger before = await ledger();
      final Ledger after = await withPlans(<Instalments>[tv()]);
      // 200.000 due on the 10th, before the payday on the 15th.
      expect(after.committedUntilPayday - before.committedUntilPayday, 200000);
      expect(after.freeUntilPayday, before.freeUntilPayday - 200000);
      expect(
        after.committed.single.id,
        'instalment:tv#1',
        reason: 'only the first one falls before payday',
      );
      expect(after.upcoming.where((m) => m.merchant == 'Televisor').length, 2);
    });

    test(
      'one bought with a card in the app is counted once, on the card',
      () async {
        final Account card = await store.addAccount(
          name: 'Visa',
          kind: AccountKind.card,
          asset: Asset.cop,
          opening: d('0'),
        );
        await store.addEntry(
          accountId: card.id,
          amount: d('1200000'),
          kind: EntryKind.expense,
          date: DateTime(2026, 10, 1),
          category: 'shopping',
          payee: 'Televisor',
        );
        final Ledger before = await ledger();
        final Ledger after = await withPlans(<Instalments>[
          tv(accountId: card.id),
        ]);
        expect(after.freeUntilPayday, before.freeUntilPayday);
        expect(after.upcoming.where((m) => m.merchant == 'Televisor'), isEmpty);
      },
    );

    test('one paid from an account that is not a card still counts as '
        'committed: the purchase is not in its balance', () async {
      final Ledger before = await ledger();
      final Ledger after = await withPlans(<Instalments>[
        tv(accountId: bank.id),
      ]);
      expect(after.freeUntilPayday, before.freeUntilPayday - 200000);
      expect(after.upcoming.where((m) => m.merchant == 'Televisor').length, 2);
    });

    test('a partial payment leaves the rest of that one committed', () async {
      final Ledger after = await withPlans(<Instalments>[
        tv(payments: <(DateTime, int)>[(DateTime(2026, 10, 2), 150000)]),
      ]);
      expect(after.committed.single.amount, 50000);
    });

    test('paying a card is no expense: it moves between accounts', () async {
      final Account card = await store.addAccount(
        name: 'Visa',
        kind: AccountKind.card,
        asset: Asset.cop,
        opening: d('-300000'),
      );
      final Ledger before = await ledger();
      await store.addTransfer(
        fromAccountId: bank.id,
        toAccountId: card.id,
        sent: d('300000'),
        received: d('300000'),
        date: DateTime(2026, 10, 2),
      );
      final Ledger after = await ledger();
      expect(after.balance, before.balance);
      expect(after.spentIn(2026, 10), before.spentIn(2026, 10));
    });
  });

  group('reminders', () {
    final DateTime now = DateTime(2026, 10, 3, 10);
    RecurringCharge charge(String name, {String category = 'subscriptions'}) =>
        RecurringCharge(
          id: name,
          name: name,
          amount: Money(d('26900'), Asset.cop),
          cadence: Cadence.monthly,
          nextDate: DateTime(2026, 10, 12),
          category: category,
        );

    test('days before each renewal, at nine, with no amount', () {
      final List<Reminder> all = renewalReminders(
        <RecurringCharge>[charge('Netflix')],
        <String, ChargeMemory>{'Netflix': const ChargeMemory(remindDays: 3)},
        now: now,
      );
      expect(all.first.at, DateTime(2026, 10, 9, 9));
      expect(all.first.title, 'Netflix se renueva el 12 de octubre');
      expect(all.map((Reminder r) => r.at), <DateTime>[
        DateTime(2026, 10, 9, 9),
        DateTime(2026, 11, 9, 9),
        DateTime(2026, 12, 9, 9),
      ]);
      for (final Reminder r in all) {
        expect('${r.title} ${r.body}', isNot(contains(RegExp(r'26|\$'))));
      }
    });

    test('a trial is reminded the day before, and speaks for its charge', () {
      final List<Reminder> all = renewalReminders(
        <RecurringCharge>[charge('Max')],
        <String, ChargeMemory>{
          'Max': ChargeMemory(trialEnds: DateTime(2026, 10, 12), remindDays: 1),
        },
        now: now,
      );
      expect(all.first.at, DateTime(2026, 10, 11, 9));
      expect(
        all.first.title,
        'La prueba gratis de Max termina el 12 de octubre',
      );
      // No second reminder for the charge the trial turns into.
      expect(all[1].at, DateTime(2026, 11, 11, 9));
    });

    test('paused charges and those without a choice remind nothing', () {
      final RecurringCharge rent = charge('Arriendo', category: 'housing');
      expect(
        renewalReminders(
          <RecurringCharge>[
            RecurringCharge(
              id: 'p',
              name: 'Pausada',
              amount: Money(d('10000'), Asset.cop),
              cadence: Cadence.monthly,
              nextDate: DateTime(2026, 10, 12),
              active: false,
            ),
            rent,
          ],
          <String, ChargeMemory>{'p': const ChargeMemory(remindDays: 1)},
          now: now,
        ),
        isEmpty,
      );
      expect(
        renewalReminders(
          <RecurringCharge>[rent],
          <String, ChargeMemory>{'Arriendo': const ChargeMemory(remindDays: 0)},
          now: now,
        ).first.title,
        'Arriendo se cobra el 12 de octubre',
      );
    });
  });

  group('the answers to the detective', () {
    test('are kept, let go when the alert is gone, and silence by kind', () {
      final ChargeAlert twice = ChargeAlert(
        id: 'twice:a:b',
        kind: AlertKind.twice,
        evidence: const <Entry>[],
      );
      final ChargeAlert up = ChargeAlert(
        id: 'priceUp:c',
        kind: AlertKind.priceUp,
        evidence: const <Entry>[],
      );
      DetectiveState state = const DetectiveState()
          .withAnswer('old', AlertAnswer.dismissed)
          .withAnswer('twice:a:b', AlertAnswer.review);
      expect(state.shown(<ChargeAlert>[twice, up]), hasLength(2));
      state = state.withAnswer(
        'priceUp:c',
        AlertAnswer.expected,
        current: <String>['twice:a:b', 'priceUp:c'],
      );
      expect(
        state.answers.keys,
        unorderedEquals(<String>['twice:a:b', 'priceUp:c']),
      );
      expect(state.shown(<ChargeAlert>[twice, up]), <ChargeAlert>[twice]);
      state = state
          .withMuted(AlertKind.twice, muted: true)
          .withNotRecurring('NETFLIX.COM');
      expect(state.shown(<ChargeAlert>[twice, up]), isEmpty);
      final DetectiveState back = DetectiveState.fromJson(state.toJson());
      expect(back.answers, state.answers);
      expect(back.muted, <AlertKind>{AlertKind.twice});
      expect(back.notRecurring, <String>{'netflix'});
    });
  });
}
