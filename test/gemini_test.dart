import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:firebase_ai/firebase_ai.dart' as ai;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/firebase_client.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/agent/tools.dart';
import 'package:quincena/ai/allowance.dart';
import 'package:quincena/data/seed.dart';
import 'package:quincena/domain/commitments.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/own/own_tools.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

Decimal d(String s) => Decimal.parse(s);

/// A model that answers every question with one small surface.
class OneSurfaceModel implements ModelClient {
  int asked = 0;

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    asked++;
    yield '```json\n{"version": "v0.9", "createSurface": '
        '{"surfaceId": "answer-$asked", "catalogId": "dev.dlsoft.quincena"}}\n```\n';
    yield '```json\n{"version": "v0.9", "updateComponents": '
        '{"surfaceId": "answer-$asked", "components": ['
        '{"id": "root", "component": "Answer", "children": ["head"]}, '
        '{"id": "head", "component": "Headline", "title": "Listo"}]}}\n```\n';
  }
}

/// A model that asks the account for its overview before answering, as
/// Gemini does before talking about what is left.
class OverviewFirstModel implements ModelClient {
  OverviewFirstModel(this.tools);

  final List<dartantic.Tool> tools;

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    await tools
        .firstWhere((dartantic.Tool t) => t.name == 'account_overview')
        .call(<String, dynamic>{});
    yield* OneSurfaceModel().send(prompt, history: history);
  }
}

/// A model the phone cannot reach.
class UnreachableModel implements ModelClient {
  @override
  Stream<String> send(String prompt, {required List<ChatMessage> history}) =>
      Stream<String>.error(
        const SocketException(
          'Failed host lookup: firebasevertexai.googleapis.com',
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime(2026, 10, 3, 10);

  group('the tools, as Firebase AI Logic declares them', () {
    final List<ai.FunctionDeclaration> declarations = <ai.FunctionDeclaration>[
      for (final dartantic.Tool t in ledgerTools(demoLedger()))
        declarationFor(t),
    ];
    Map<String, Object?> json(String name) => declarations
        .firstWhere((ai.FunctionDeclaration f) => f.name == name)
        .toJson();

    test('keep their names and descriptions', () {
      expect(
        declarations.map((ai.FunctionDeclaration f) => f.name),
        containsAll(<String>[
          'account_overview',
          'month_spending',
          'record_expense',
        ]),
      );
      expect(json('month_spending')['description'], contains('one month'));
    });

    test('say which parameters are needed and which values are allowed', () {
      final Map<String, Object?> record =
          json('record_expense')['parameters']! as Map<String, Object?>;
      expect(record['required'], <String>['amount', 'category']);
      final Map<String, Object?> properties =
          record['properties']! as Map<String, Object?>;
      expect((properties['amount']! as Map)['type'], 'NUMBER');
      expect((properties['category']! as Map)['enum'], contains('groceries'));
      expect(
        (json('account_overview')['parameters']! as Map)['properties'],
        isEmpty,
      );
    });
  });

  group('the day\'s questions', () {
    late QuincenaStore store;
    var today = now;
    setUp(() {
      store = QuincenaStore(QuincenaDatabase(NativeDatabase.memory()));
      today = now;
    });
    tearDown(() => store.close());

    test('run out, and are back the next day', () async {
      final Allowance allowance = Allowance(store, perDay: 3, now: () => today);
      await allowance.load();
      for (var i = 0; i < 3; i++) {
        expect(await allowance.take(), isTrue);
      }
      expect(allowance.left, 0);
      expect(await allowance.take(), isFalse);

      // Counted on the device: a new start reads what was used.
      final Allowance again = Allowance(store, perDay: 3, now: () => today);
      await again.load();
      expect(again.left, 0);

      today = now.add(const Duration(days: 1));
      expect(again.left, 3);
      expect(await again.take(), isTrue);
      expect(again.left, 2);
    });
  });

  group('the person\'s own accounts', () {
    late QuincenaStore store;
    late OwnController own;
    late Account bank;

    setUp(() async {
      Intl.defaultLocale = 'es_CO';
      store = QuincenaStore(
        QuincenaDatabase(NativeDatabase.memory()),
        now: () => now,
      );
      await store.ensureCategories();
      await store.saveProfile(
        const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
      );
      bank = await store.addAccount(
        name: 'Bancolombia',
        kind: AccountKind.bank,
        asset: Asset.cop,
        opening: d('1000000'),
        institution: 'Bancolombia',
      );
      await store.addAccount(
        name: 'Binance',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        opening: d('100'),
        institution: 'Binance',
        spendable: false,
      );
      await store.saveRates(<Rate>[
        Rate(
          asset: 'USD',
          quote: 'COP',
          value: d('4000'),
          asOf: now,
          source: 'trm',
        ),
      ]);
      own = OwnController(store, now: () => now, readNative: false);
      await own.start();
    });

    tearDown(() async {
      own.dispose();
      await store.close();
    });

    test('accounts answers each one in its own currency and in pesos', () {
      final Map<String, Object?> answer = accountsAnswer(own);
      expect(answer['baseCurrency'], 'COP');
      final List<Object?> accounts = answer['accounts']! as List<Object?>;
      final Map<Object?, Object?> binance = accounts
          .cast<Map<Object?, Object?>>()
          .firstWhere((Map<Object?, Object?> a) => a['name'] == 'Binance');
      expect(binance['currency'], 'USDT');
      expect(binance['balanceText'], '100\u00a0USDT');
      expect(binance['balanceInBase'], 400000);
      expect(binance['spendable'], isFalse);
      expect(answer['netWorthInBase'], 1400000);
      expect(answer.containsKey('totalInBase'), isFalse);
      expect(answer['spendableInBase'], 1000000);
    });

    test('the net worth sent is defined, with what is owed outside the '
        'accounts', () async {
      await store.setSetting(
        'shared.groups',
        jsonEncode(<Object?>[
          const Group(
                id: 'arriendo',
                name: 'Arriendo',
                members: <Member>[
                  Member(id: meId, name: ''),
                  Member(id: 'sofia', name: 'Sofía'),
                ],
              )
              .withExpense(
                SharedExpense(
                  id: 'luz',
                  label: 'Luz',
                  date: now,
                  paidBy: 'sofia',
                  shares: const <String, int>{meId: 60000, 'sofia': 60000},
                ),
              )
              .toJson(),
        ]),
      );
      await store.setSetting(
        'commitments.instalments',
        jsonEncode(<Object?>[
          Instalments(
            id: 'nevera',
            name: 'Nevera',
            principal: 240000,
            count: 2,
            firstDue: now.add(const Duration(days: 30)),
            rate: 0,
            fee: 0,
          ).toJson(),
        ]),
      );
      final OwnController fresh = OwnController(
        store,
        now: () => now,
        readNative: false,
      );
      addTearDown(fresh.dispose);
      await fresh.start();
      final Map<String, Object?> answer = accountsAnswer(fresh);
      // 1.400.000 in the accounts, less 60.000 owed to Sofía and the
      // 240.000 left on the fridge.
      expect(answer['netWorthInBase'], 1100000);
      expect(answer['youOweOthersInBase'], 60000);
      expect(answer['installmentsLeftInBase'], 240000);
      expect(answer.containsKey('owedToYouInBase'), isFalse);
      expect(answer.containsKey('netWorthIsEstimate'), isFalse);
      final dartantic.Tool accounts = ownTools(
        fresh,
      ).firstWhere((dartantic.Tool t) => t.name == 'accounts');
      expect(accounts.description, contains('netWorthInBase'));
      expect(
        accounts.description,
        isNot(contains('everything the person has')),
      );
    });

    test('an expense confirmed in a conversation is saved for real', () async {
      final dartantic.Tool record = ownTools(
        own,
      ).firstWhere((dartantic.Tool t) => t.name == 'record_expense');
      final Object? result = await record.call(<String, dynamic>{
        'amount': 45900,
        'category': 'groceries',
        'note': 'Éxito',
      });
      expect((result! as Map)['recorded'], isTrue);
      expect((result as Map)['freeUntilPayday'], 954100);
      final List<Entry> entries = await store.entries();
      expect(entries.single.accountId, bank.id);
      expect(entries.single.amount, d('-45900'));
      expect(entries.single.payee, 'Éxito');
    });

    test('through Quincena, a question needs one left for the day', () async {
      final Allowance allowance = Allowance(store, perDay: 1, now: () => now);
      await allowance.load();
      final OneSurfaceModel model = OneSurfaceModel();
      final Session session = Session(
        mode: AgentMode.gemini,
        client: model,
        errorWindow: Duration.zero,
        ledgerOf: () => own.ledger!,
        toolsFor: (_) => ownTools(own),
        own: true,
        allowance: allowance,
      );
      addTearDown(session.dispose);

      await session.ask('¿Cuánto me queda libre?');
      expect(session.turns.last.error, isNull);
      expect(session.turns.last.surfaceIds, isNotEmpty);
      expect(model.asked, 1);

      await session.ask('¿Y en qué se me fue?');
      expect(session.turns.last.error, AnswerProblem.limit);
      expect(model.asked, 1);
    });
  });
  test('can I buy it, what comes and the close, as tools', () async {
    final List<dartantic.Tool> tools = ledgerTools(demoLedger());
    Future<Map<String, Object?>> call(
      String name, [
      Map<String, dynamic> args = const <String, dynamic>{},
    ]) async =>
        (await tools.firstWhere((dartantic.Tool t) => t.name == name).call(args)
                as Map)
            .cast<String, Object?>();

    final Map<String, Object?> buy = await call('can_i_buy', <String, dynamic>{
      'amount': 350000,
    });
    final Map<String, Object?> asked = (buy['asked']! as Map)
        .cast<String, Object?>();
    expect(asked['verdict'], isIn(<String>['fits', 'belowCushion', 'short']));
    expect(buy['afterPayday'], isA<Map<Object?, Object?>>());
    expect(
      (await call('can_i_buy', <String, dynamic>{'amount': -1}))['error'],
      isNotNull,
    );

    final Map<String, Object?> coming = await call('coming_days');
    expect(coming['lowestBeforePayday'], isA<num>());
    expect(coming['events'], isA<List<Object?>>());

    final Map<String, Object?> close = await call('fortnight_close');
    expect(close['available'], isA<bool>());
  });

  test('an answer keeps what the phone computed for it', () async {
    final Session session = Session(
      mode: AgentMode.gemini,
      clientFor: OverviewFirstModel.new,
      errorWindow: Duration.zero,
    );
    addTearDown(session.dispose);

    await session.ask('¿Cuánto me queda libre?');
    final Turn turn = session.turns.last;
    expect(turn.error, isNull);
    expect(turn.surfaceIds, isNotEmpty);
    expect(
      <String>[for (final Computed c in turn.computed) c.tool],
      <String>['account_overview'],
    );
  });

  group('when the answer cannot arrive', () {
    test('without a connection it says so, not that something broke', () async {
      final Session session = Session(
        mode: AgentMode.gemini,
        client: UnreachableModel(),
        errorWindow: Duration.zero,
      );
      addTearDown(session.dispose);

      await session.ask('¿Cuánto me queda libre?');
      expect(session.turns.last.error, AnswerProblem.offline);
    });

    test('a missing connection, the way each platform words it', () {
      expect(
        Session.offline('SocketException: Failed host lookup: example.com'),
        isTrue,
      );
      expect(
        Session.offline('ClientException: XMLHttpRequest error., uri=x'),
        isTrue,
      );
      expect(
        Session.offline('The Internet connection appears to be offline.'),
        isTrue,
      );
      expect(Session.offline('429 RESOURCE_EXHAUSTED'), isFalse);
    });
  });
}
