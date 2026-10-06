// Valentina's example account: the same story the sample conversation
// tells, so the screens and the conversation say the same figures, and
// something for every part of the app to show.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/data/clock.dart';
import 'package:quincena/data/example_account.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/format/money.dart' as format;
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/store/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuincenaStore store;
  late OwnController own;

  setUp(() async {
    store = await buildExample(NativeDatabase.memory());
    own = OwnController(
      store,
      example: true,
      now: () => exampleNow,
      readNative: false,
    );
    await own.start();
  });

  tearDown(() async {
    own.dispose();
    await store.close();
    appToday = DateTime(2026, 10, 1);
    format.baseCurrency = Asset.cop;
  });

  test('the screens and the conversation tell the same figures', () {
    final Ledger screens = own.ledger!;
    final Ledger story = demoLedger();
    expect(screens.owner, story.owner);
    expect(screens.today, story.today);
    expect(screens.nextPayday, story.nextPayday);
    expect(screens.balance, story.balance);
    expect(screens.committedUntilPayday, story.committedUntilPayday);
    expect(screens.freeUntilPayday, story.freeUntilPayday);
    for (var month = 4; month <= 9; month++) {
      expect(screens.spentIn(2026, month), story.spentIn(2026, month));
      expect(screens.incomeIn(2026, month), story.incomeIn(2026, month));
      expect(
        <String>[
          for (final MapEntry<Object, int> e in screens.byCategory(2026, month))
            '${e.key} ${e.value}',
        ],
        <String>[
          for (final MapEntry<Object, int> e in story.byCategory(2026, month))
            '${e.key} ${e.value}',
        ],
      );
    }
    expect(
      <String>{
        for (final Subscription s in screens.subscriptions)
          '${s.name} ${s.price}',
      },
      <String>{
        for (final Subscription s in story.subscriptions)
          '${s.name} ${s.price}',
      },
    );
    final Goal goal = screens.goals.single;
    final Goal told = story.goals.single;
    expect(goal.name, told.name);
    expect(goal.target, told.target);
    expect(goal.saved, told.saved);
    expect(goal.monthly, told.monthly);
    expect(goal.deadline, told.deadline);
  });

  test('every part of the app has something to show', () {
    expect(own.profile!.name, 'Valentina');
    expect(<AccountKind>{
      for (final Account a in own.accounts) a.kind,
    }, containsAll(AccountKind.values.take(5)));
    final Account card = own.accounts.singleWhere(
      (Account a) => a.kind == AccountKind.card,
    );
    expect(card.creditLimit, isNotNull);
    expect(own.balances[card.id]!.isNegative, isTrue);
    expect(<Asset>{
      for (final Account a in own.accounts) a.asset,
    }, containsAll(<Asset>[Asset.cop, Asset.usd, Asset.btc, Asset.eth]));
    // Every one with what it cost, so the gain is the gain.
    for (final Account a in own.accounts) {
      if (a.asset.isCrypto) expect(a.openingCost, isNotNull, reason: a.name);
    }
    expect(own.unconverted, isEmpty);

    expect(own.pendingInbox, hasLength(2));
    expect(
      own.inbox.where((InboxItem i) => i.status == InboxStatus.duplicate),
      hasLength(1),
    );
    expect(own.recurring.where((RecurringCharge r) => r.active), isNotEmpty);
    expect(own.instalments, hasLength(1));
    expect(own.groups, hasLength(1));
    expect(own.sharedBalance.$2, greaterThan(0));
    expect(own.trips, hasLength(1));
    expect(own.wishes, hasLength(2));
    expect(own.freelance.incomes, hasLength(2));
    expect(own.lastPlan, isNotNull);
    // This fortnight's pay arrived and waits to be split.
    expect(own.paidWithoutPlan, isTrue);
    expect(own.provisional, isFalse);
  });

  test('no everyday account runs dry, and the card is paid each month', () {
    final StoreSnapshot s = own.snapshot!;
    final List<Account> everyday = <Account>[
      for (final Account a in s.accounts)
        if (a.spendable && a.kind != AccountKind.card) a,
    ];
    for (
      var day = DateTime(2026, 4, 1);
      !day.isAfter(exampleNow);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final Map<String, Money> held = balancesOf(s.accounts, s.entries, day);
      for (final Account a in everyday) {
        expect(
          held[a.id]!.isNegative,
          isFalse,
          reason: '${a.name} on $day: ${held[a.id]!.amount}',
        );
      }
    }
    final Account card = s.accounts.singleWhere(
      (Account a) => a.kind == AccountKind.card,
    );
    final Money owed = own.balances[card.id]!;
    expect(owed.amount.abs() < card.creditLimit!, isTrue);
  });
}
