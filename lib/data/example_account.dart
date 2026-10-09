// Valentina's example account: the whole app on made-up money.
//
// It tells the story lib/data/seed.dart tells the sample conversation, with
// the same movements on the same days, so the screens and the conversation
// say the same figures: what she can spend until payday, what September
// cost, her subscriptions and the trip to Cartagena. On top of it sits what
// the conversation never needed and the app's screens show: the accounts
// the money is in, a credit card with its limit, dollars and crypto with
// what they cost, captures waiting for review, a purchase in instalments,
// a shared expense, a trip, two wishes, variable income and the envelopes
// of the last fortnight. Every person, business and figure is made up.
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show QueryExecutor, driftRuntimeOptions;
import 'package:flutter/services.dart' show rootBundle;

import '../capture/capture_service.dart';
import '../capture/event.dart';
import '../capture/inbox.dart';
import '../domain/commitments.dart';
import '../domain/freelance.dart';
import '../domain/pay_schedule.dart';
import '../domain/plan.dart';
import '../domain/records.dart';
import '../domain/shared.dart';
import '../domain/trips.dart';
import '../money/asset.dart';
import '../money/money.dart';
import '../statements/statement.dart';
import '../statements/tables.dart';
import '../store/database.dart';
import '../store/memory.dart';
import '../store/store.dart';
import 'clock.dart';
import 'example_prices.dart';
import 'ledger.dart';
import 'seed.dart';

/// Whose example account it is.
const String exampleOwner = 'Valentina';

/// When Valentina last used each subscription, by its name, as the story
/// tells it: two of them not in over a month. A list of charges cannot
/// know it; her conversation does.
final Map<String, DateTime> exampleLastUsed = <String, DateTime>{
  for (final Subscription s in demoLedger().subscriptions)
    if (s.lastUsed case final DateTime used) s.name: used,
};

/// Valentina's example account in a database in memory: made afresh each
/// time, gone when it closes, and kept apart from the person's own.
Future<QuincenaStore> openExample() => buildExample(inMemoryDatabase());

/// Writes Valentina's example account into a new database on [executor].
///
/// The store it returns believes it is [exampleNow], and stays there.
Future<QuincenaStore> buildExample(QueryExecutor executor) async {
  // Beside the person's own database on purpose, on an executor of its
  // own: drift's warning about a second database does not apply.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Her accounts were written down the day before April; from then on the
  // movements of the story. Once it is told, the clock stops at the
  // example's own morning.
  var clock = DateTime(2026, 3, 31, 9);
  final QuincenaStore store = QuincenaStore(
    QuincenaDatabase(executor),
    now: () => clock,
  );
  await store.db.transaction(() async {
    await _write(store, (DateTime at) => clock = at);
  });
  clock = exampleNow;
  await store.saveRates(exampleRates(exampleNow));
  // What the phone caught this morning, read as the app reads it.
  await _captures(store);
  return store;
}

Decimal _d(String s) => Decimal.parse(s);
Decimal _n(int pesos) => Decimal.fromInt(pesos);

Future<void> _write(
  QuincenaStore store,
  void Function(DateTime at) setClock,
) async {
  await store.ensureCategories();
  await store.saveProfile(
    Profile(
      name: exampleOwner,
      base: Asset.cop,
      // The 15th and the last day of the month, as the story has it.
      schedule: const TwiceMonthly(first: 15, second: 31),
      pay: _n(2400000),
    ),
  );
  // What was in each account the day the story starts: together, the
  // 1.840.000 pesos the conversation's account opens with.
  final Account bank = await store.addAccount(
    name: 'Cuenta de nómina',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: _n(_openings.bank),
  );
  final Account wallet = await store.addAccount(
    name: 'Billetera',
    kind: AccountKind.wallet,
    asset: Asset.cop,
    opening: _n(_openings.wallet),
  );
  final Account cash = await store.addAccount(
    name: 'Efectivo',
    kind: AccountKind.cash,
    asset: Asset.cop,
    opening: _n(_openings.cash),
  );
  final Account card = await store.addAccount(
    name: 'Tarjeta de crédito',
    kind: AccountKind.card,
    asset: Asset.cop,
    opening: _n(_openings.card),
    creditLimit: _n(4000000),
  );
  final Account pocket = await store.addAccount(
    name: 'Bolsillo Cartagena',
    kind: AccountKind.bank,
    asset: Asset.cop,
    spendable: false,
  );
  await store.addAccount(
    name: 'Cuenta en dólares',
    kind: AccountKind.bank,
    asset: Asset.usd,
    opening: _d('420'),
    spendable: false,
  );
  await store.addAccount(
    name: 'Tether',
    kind: AccountKind.exchange,
    asset: Asset.usdt,
    opening: _d('320'),
    openingCost: Money(_n(1000000), Asset.cop),
  );
  await store.addAccount(
    name: 'Bitcoin',
    kind: AccountKind.exchange,
    asset: Asset.btc,
    opening: _d('0.0042'),
    openingCost: Money(_n(1050000), Asset.cop),
  );
  await store.addAccount(
    name: 'Ether',
    kind: AccountKind.exchange,
    asset: Asset.eth,
    opening: _d('0.12'),
    openingCost: Money(_n(1100000), Asset.cop),
  );

  // The story's movements, each from the account it would be paid from.
  // The wallet and the cash are topped up from the bank when they run
  // short, and the card is paid on the 16th for what it owed when the
  // month started: moves between her own accounts, which change nothing
  // of what she can spend.
  final Ledger story = demoLedger();
  final Map<String, int> held = <String, int>{
    bank.id: _openings.bank,
    wallet.id: _openings.wallet,
    cash.id: _openings.cash,
    card.id: _openings.card,
  };

  Future<void> move(
    Account from,
    Account to,
    int amount,
    DateTime on,
    String note,
  ) async {
    await store.addTransfer(
      fromAccountId: from.id,
      toAccountId: to.id,
      sent: _n(amount),
      date: on,
      note: note,
    );
    held[from.id] = held[from.id]! - amount;
    held[to.id] = (held[to.id] ?? 0) + amount;
  }

  var month = 0;
  var statement = 0;
  var paid = true;
  for (final Movement m in story.movements) {
    if (!story.settled(m)) continue;
    // A month closed: what the card owed then is paid on the 16th, the
    // day after the first pay.
    if (m.date.month != month) {
      month = m.date.month;
      statement = -held[card.id]!;
      paid = false;
    }
    if (!paid && m.date.day >= 16) {
      paid = true;
      if (statement > 0) {
        await move(
          bank,
          card,
          statement,
          DateTime(m.date.year, month, 16),
          'Pago de la tarjeta',
        );
      }
    }
    if (m.flow == Flow.saving) {
      await move(bank, pocket, m.amount, m.date, m.merchant);
      continue;
    }
    final bool income = m.flow == Flow.income;
    final Account from = switch (_paidFrom(m.merchant)) {
      _From.bank => bank,
      _From.wallet => wallet,
      _From.cash => cash,
      _From.card => card,
    };
    if (!income && from == wallet && held[wallet.id]! < m.amount) {
      await move(bank, wallet, 200000, m.date, 'Recarga de la billetera');
    }
    if (!income && from == cash && held[cash.id]! < m.amount) {
      await move(bank, cash, 200000, m.date, 'Retiro en cajero');
    }
    await store.addEntry(
      accountId: from.id,
      amount: _n(m.amount),
      kind: income ? EntryKind.income : EntryKind.expense,
      date: m.date,
      category: income ? 'salary' : m.category.name,
      payee: m.merchant,
    );
    held[from.id] = held[from.id]! + (income ? m.amount : -m.amount);
  }

  // What she pays every month from here on. The October charges the story
  // already counts as committed, and the next of each one.
  for (final _Fixed f in _fixed) {
    setClock(f.since);
    await store.addRecurring(
      name: f.name,
      amount: Money(_n(f.price), Asset.cop),
      cadence: Cadence.monthly,
      nextDate: f.next,
      accountId: f.onCard ? card.id : bank.id,
      category: f.category,
    );
  }
  setClock(DateTime(2026, 3, 31, 9));
  final List<RecurringCharge> charges = await store.recurring();
  String chargeId(String name) =>
      charges.firstWhere((RecurringCharge r) => r.name == name).id;

  // Two subscriptions she has not opened in weeks, and a reminder before
  // the cloud storage renews.
  await store.setSetting(
    'commitments.memories',
    jsonEncode(<String, Object?>{
      chargeId('Fit24 gimnasio'): ChargeMemory(
        usedAt: DateTime(2026, 8, 19),
        inUse: false,
      ).toJson(),
      chargeId('Lingo Pro'): ChargeMemory(
        usedAt: DateTime(2026, 7, 30),
        inUse: false,
      ).toJson(),
      chargeId('Nube 200 GB'): const ChargeMemory(remindDays: 3).toJson(),
    }),
  );

  // The headphones of September, in three instalments with no interest on
  // the card. The card's balance already holds them.
  await store.setSetting(
    'commitments.instalments',
    jsonEncode(<Object?>[
      Instalments(
        id: 'example-headphones',
        name: 'TecnoCentro audífonos',
        principal: 389000,
        count: 3,
        firstDue: DateTime(2026, 10, 6),
        rate: 0,
        fee: 0,
        cashPrice: 389000,
        accountId: card.id,
      ).toJson(),
    ]),
  );

  // The trip she saves for, as a goal, with its own pocket.
  final SavingsGoal goal = await store.addGoal(
    name: 'Cartagena',
    target: Money(_n(2800000), Asset.cop),
    saved: Money(_n(1000000), Asset.cop),
    monthly: Money(_n(250000), Asset.cop),
    deadline: DateTime(2026, 12, 20),
  );

  // The envelopes of the fortnight before: this one's pay arrived and is
  // still to split.
  await store.setSetting(
    'plan.envelopes',
    jsonEncode(
      EnvelopePlan(
        period: DateTime(2026, 9, 15),
        envelopes: <Envelope>[
          const Envelope(
            id: 'example-daily',
            kind: EnvelopeKind.daily,
            name: 'Día a día',
            amount: 900000,
          ),
          Envelope(
            id: 'example-cartagena',
            kind: EnvelopeKind.goal,
            name: goal.name,
            amount: 125000,
            goalId: goal.id,
          ),
        ],
      ).toJson(),
    ),
  );

  await store.setSetting(
    'plan.wishes',
    jsonEncode(<Object?>[
      const Wish(
        id: 'example-chair',
        name: 'Silla de escritorio',
        price: 650000,
        priority: 1,
      ).toJson(),
      Wish(
        id: 'example-camera',
        name: 'Cámara instantánea',
        price: 420000,
        waitUntil: DateTime(2026, 11, 15),
      ).toJson(),
    ]),
  );

  // A weekend with two friends: they paid the cabin and the groceries, and
  // she owes them her part.
  await store.setSetting(
    'shared.groups',
    jsonEncode(<Object?>[
      Group(
        id: 'example-santa-elena',
        name: 'Paseo a Santa Elena',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'laura', name: 'Laura'),
          Member(id: 'mateo', name: 'Mateo'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'example-cabin',
            label: 'Cabaña',
            date: DateTime(2026, 9, 26),
            paidBy: 'mateo',
            shares: const <String, int>{
              meId: 180000,
              'laura': 180000,
              'mateo': 180000,
            },
          ),
          SharedExpense(
            id: 'example-groceries',
            label: 'Mercado del paseo',
            date: DateTime(2026, 9, 26),
            paidBy: 'laura',
            shares: const <String, int>{
              meId: 42000,
              'laura': 42000,
              'mateo': 42000,
            },
          ),
        ],
      ).toJson(),
    ]),
  );

  // The trip itself, in December, with what she plans to spend there.
  await store.setSetting(
    'trips',
    jsonEncode(<Object?>[
      Trip(
        id: 'example-cartagena',
        name: 'Cartagena',
        from: DateTime(2026, 12, 18),
        to: DateTime(2026, 12, 22),
        currency: 'COP',
        budget: _n(2800000),
      ).toJson(),
    ]),
  );

  // Illustration on the side: a logo billed and waiting, and a magazine
  // that may commission more. A share of what arrives is kept apart.
  await store.setSetting(
    'freelance',
    jsonEncode(
      FreelancePlan(
        incomes: <ExpectedIncome>[
          ExpectedIncome(
            id: 'example-logo',
            client: 'Panadería La Espiga',
            amount: 600000,
            expected: DateTime(2026, 10, 20),
            note: 'Logo y empaques',
          ),
          ExpectedIncome(
            id: 'example-magazine',
            client: 'Revista Ladera',
            amount: 450000,
            expected: DateTime(2026, 11, 5),
            status: IncomeStatus.estimated,
            note: 'Ilustraciones de noviembre',
          ),
        ],
        reservePercent: 15,
        reserveSince: DateTime(2026, 10, 1),
      ).toJson(),
    ),
  );

  // What she taught the app from earlier captures: her card's digits and
  // the shops' categories.
  await store.saveCaptureSettings(
    CaptureSettings(
      cardAccounts: <String, String>{'4821': card.id, '7310': bank.id},
      merchantCategories: const <String, String>{
        'supermercado andino': 'groceries',
        'almuerzos dona rosa': 'restaurants',
        'fit24 gimnasio': 'subscriptions',
      },
    ),
  );
}

/// The morning's captures: a purchase ready to record, a payment whose
/// account the message does not say, and the gym again, already entered
/// by hand.
Future<void> _captures(QuincenaStore store) =>
    CaptureService(store, now: () => exampleNow).ingest(<CaptureEvent>[
      CaptureEvent(
        source: CaptureSource.notification,
        at: DateTime(2026, 10, 1, 7, 5),
        app: 'co.ejemplo.bancamovil',
        appName: 'Banca móvil',
        text: r'Compra por $119.000 en FIT24 GIMNASIO con tu cuenta *7310',
      ),
      CaptureEvent(
        source: CaptureSource.notification,
        at: DateTime(2026, 10, 1, 8, 40),
        app: 'co.ejemplo.bancamovil',
        appName: 'Banca móvil',
        text: r'Compraste $86.400 en SUPERMERCADO ANDINO con tu tarjeta *4821',
      ),
      CaptureEvent(
        source: CaptureSource.notification,
        at: DateTime(2026, 10, 1, 9, 15),
        app: 'co.ejemplo.billetera',
        appName: 'Billetera',
        text: r'Pagaste $23.500 en ALMUERZOS DOÑA ROSA',
      ),
    ]);

/// What each spendable account held when the story starts: together the
/// conversation's opening balance, with what the card owed from March,
/// which carries her through the first fortnight of April.
const ({int bank, int wallet, int cash, int card}) _openings = (
  bank: 3400000,
  wallet: 120000,
  cash: 80000,
  card: -1760000,
);

enum _From { bank, wallet, cash, card }

/// The account the story's [merchant] is paid from.
_From _paidFrom(String merchant) => switch (merchant) {
  'Nómina Estudio Lumen' ||
  'Arriendo apartamento' ||
  'Energía y agua' ||
  'Internet hogar' ||
  'Plan celular' ||
  'Medicina prepagada' ||
  'Crédito educativo' ||
  'Fit24 gimnasio' => _From.bank,
  'Almuerzos Doña Rosa' ||
  'Fruver La 70' ||
  'Recarga Cívica' ||
  'RutaYa' => _From.wallet,
  'Tienda Don Pacho' || 'Café Cordillera' || 'Arepas La Esquina' => _From.cash,
  _ => _From.card,
};

/// A charge that repeats every month.
class _Fixed {
  const _Fixed(
    this.name,
    this.price,
    this.next,
    this.category,
    this.since, {
    this.onCard = false,
  });

  final String name;
  final int price;
  final DateTime next;
  final String category;
  final DateTime since;
  final bool onCard;
}

/// Her fixed payments, next due after the example's morning: the ones due
/// before the 15th are what the story commits, the others come after it.
/// The subscriptions go in the order the story lists them, the dearest
/// first, which is how her conversation lists them too.
final List<_Fixed> _fixed = <_Fixed>[
  _Fixed(
    'Arriendo apartamento',
    1650000,
    DateTime(2026, 10, 5),
    'housing',
    DateTime(2025, 2, 5),
  ),
  _Fixed(
    'Medicina prepagada',
    189000,
    DateTime(2026, 10, 2),
    'health',
    DateTime(2024, 6, 2),
  ),
  _Fixed(
    'Crédito educativo',
    312000,
    DateTime(2026, 10, 10),
    'debt',
    DateTime(2023, 2, 10),
  ),
  _Fixed(
    'Internet hogar',
    109900,
    DateTime(2026, 10, 12),
    'utilities',
    DateTime(2025, 2, 12),
  ),
  _Fixed(
    'Plan celular',
    62000,
    DateTime(2026, 10, 17),
    'utilities',
    DateTime(2024, 3, 17),
  ),
  _Fixed(
    'Fit24 gimnasio',
    119000,
    DateTime(2026, 11, 1),
    'subscriptions',
    DateTime(2025, 11, 1),
  ),
  _Fixed(
    'Cineplus',
    38900,
    DateTime(2026, 10, 3),
    'subscriptions',
    DateTime(2024, 2, 3),
    onCard: true,
  ),
  _Fixed(
    'Lingo Pro',
    34900,
    DateTime(2026, 10, 20),
    'subscriptions',
    DateTime(2026, 1, 20),
    onCard: true,
  ),
  _Fixed(
    'Pantalla+',
    26900,
    DateTime(2026, 10, 22),
    'subscriptions',
    DateTime(2026, 8, 22),
    onCard: true,
  ),
  _Fixed(
    'Ritmo',
    21900,
    DateTime(2026, 10, 8),
    'subscriptions',
    DateTime(2023, 5, 8),
    onCard: true,
  ),
  _Fixed(
    'Nube 200 GB',
    11900,
    DateTime(2026, 10, 14),
    'subscriptions',
    DateTime(2024, 9, 14),
    onCard: true,
  ),
];

/// The account [exampleStatement] is of.
const String exampleStatementAccount = 'Cuenta de nómina';

/// A made-up statement of her payroll account, as the bank would export it:
/// what «Importar extracto» offers to try in the example, without a file.
/// September's last pay is already in the account, a card payment moves
/// money to the card, two charges are new, and a purchase from March is
/// older than the balance she wrote down.
Future<StatementRead> exampleStatement() async {
  final StatementRead read = readTable(
    // Read afresh each time: it is small, and a read left half done in
    // the cache would never finish.
    parseCsv(await rootBundle.loadString(exampleStatementAsset, cache: false)),
  );
  return StatementRead(
    lines: read.lines,
    source: read.source,
    institution: exampleStatementAccount,
  );
}

/// Where [exampleStatement] is kept.
const String exampleStatementAsset =
    'assets/statements/extracto-de-ejemplo.csv';

/// A message a bank sends, to try «Leer un pago» in the example without
/// one of the person's own.
const String exampleMessage =
    r'Compraste $54.900 en DROGUERIA LAURELES con tu cuenta *7310';
