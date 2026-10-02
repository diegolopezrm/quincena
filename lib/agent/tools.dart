import 'package:dartantic_ai/dartantic_ai.dart';

import '../data/category.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../functions/money_functions.dart';

/// An expense the person confirmed, on its way to being saved.
class ExpenseToRecord {
  const ExpenseToRecord({
    required this.amount,
    required this.category,
    required this.note,
    this.account,
  });

  /// In the smallest unit of the ledger's currency.
  final int amount;
  final Category category;

  /// Where it was spent, or empty.
  final String note;

  /// The account the person named, if they did.
  final String? account;
}

/// Saves an expense: in the sample account's memory, or in the person's
/// own database.
typedef RecordExpense = Future<void> Function(ExpenseToRecord expense);

/// The questions a model can ask the sample account. An expense it records
/// goes into the account's memory and is gone on restart.
List<Tool> ledgerTools(Ledger ledger) => accountTools(
  () => ledger,
  record: (ExpenseToRecord e) async => ledger.record(
    Movement(
      id: 'manual-${ledger.movements.length}',
      date: appToday,
      merchant: e.note.isEmpty ? e.category.label : e.note,
      amount: e.amount,
      category: e.category,
    ),
  ),
);

/// The questions a model can ask an account.
///
/// Every number a model shows has to come from one of these. They answer in
/// plain JSON with whole units of the account's currency and ISO dates,
/// which is what the catalog's data shapes and functions take, so a result
/// can go into the data model as it is.
///
/// [current] is read on every call, so after the person records something
/// the next answer counts it.
List<Tool> accountTools(
  Ledger Function() current, {
  required RecordExpense record,
}) => <Tool>[
  Tool<Map<String, dynamic>>(
    name: 'account_overview',
    description:
        'The account today: the balance, what is already committed until the '
        'next payday, what is free to spend until then, the next payday and '
        'the monthly income. Call it before talking about what is left.',
    onCall: (_) {
      final Ledger ledger = current();
      return <String, Object?>{
        'owner': ledger.owner,
        'today': _day(appToday),
        'currency': ledger.currency.code,
        'balance': ledger.major(ledger.balance),
        'committedUntilPayday': ledger.major(ledger.committedUntilPayday),
        'freeUntilPayday': ledger.major(ledger.freeUntilPayday),
        'nextPayday': _day(ledger.nextPayday),
        'monthlyIncome': ledger.major(
          ledger.incomeIn(_lastMonth.year, _lastMonth.month),
        ),
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'month_spending',
    description:
        'Spending in one month: the total, the income, every category with '
        'its amount and number of payments, the same for the month before so '
        'the two can be compared, and the five largest payments.',
    inputSchema: S.object(
      properties: <String, Schema>{
        'month': S.string(
          description: 'The month, written as YYYY-MM. September is 2026-09.',
        ),
      },
      required: <String>['month'],
    ),
    onCall: (Map<String, dynamic> args) {
      final Ledger ledger = current();
      final DateTime? month = _month(args['month']);
      if (month == null) return _error('month must be written as YYYY-MM');
      final DateTime before = DateTime(month.year, month.month - 1);
      final int spent = ledger.spentIn(month.year, month.month);
      final int spentBefore = ledger.spentIn(before.year, before.month);
      final int income = ledger.incomeIn(month.year, month.month);
      Map<String, Object?> categories(DateTime m, {bool compare = false}) =>
          <String, Object?>{
            for (final MapEntry<Category, int> e in ledger.byCategory(
              m.year,
              m.month,
            ))
              e.key.name: () {
                final int previous = ledger.spentOn(
                  e.key,
                  before.year,
                  before.month,
                );
                return <String, Object?>{
                  'amount': ledger.major(e.value),
                  'payments': ledger.countIn(e.key, m.year, m.month),
                  if (compare) ...<String, Object?>{
                    'previousAmount': ledger.major(previous),
                    'previousPayments': ledger.countIn(
                      e.key,
                      before.year,
                      before.month,
                    ),
                    'difference': ledger.major(e.value - previous),
                    'changePercent': _percent(e.value, previous),
                  },
                };
              }(),
          };
      return <String, Object?>{
        'month': _monthKey(month),
        'spent': ledger.major(spent),
        'income': ledger.major(income),
        'spentShareOfIncomePercent': income == 0
            ? null
            : (spent / income * 100).round(),
        'spentDifference': ledger.major(spent - spentBefore),
        'spentChangePercent': _percent(spent, spentBefore),
        'categories': categories(month, compare: true),
        'previousMonth': <String, Object?>{
          'month': _monthKey(before),
          'spent': ledger.major(spentBefore),
        },
        'largest': <Object?>[
          for (final Movement m in ledger.largestIn(month.year, month.month))
            _movement(ledger, m),
        ],
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'category_payments',
    description:
        'Every payment in one category in one month, largest first. Use it to '
        'show what is behind a category that moved.',
    inputSchema: S.object(
      properties: <String, Schema>{
        'category': S.string(
          description: 'The category.',
          enumValues: <String>[
            for (final Category c in Category.values) c.name,
          ],
        ),
        'month': S.string(description: 'The month, written as YYYY-MM.'),
      },
      required: <String>['category', 'month'],
    ),
    onCall: (Map<String, dynamic> args) {
      final Ledger ledger = current();
      final Category? category = Category.values
          .where((Category c) => c.name == args['category'])
          .firstOrNull;
      final DateTime? month = _month(args['month']);
      if (category == null || month == null) {
        return _error(
          'category must be one of the listed values, and month '
          'written as YYYY-MM',
        );
      }
      final List<Movement> payments = ledger.inCategory(
        category,
        month.year,
        month.month,
      )..sort((Movement a, Movement b) => b.amount.compareTo(a.amount));
      return <String, Object?>{
        'category': category.name,
        'month': _monthKey(month),
        'total': ledger.major(
          ledger.spentOn(category, month.year, month.month),
        ),
        'payments': <Object?>[
          for (final Movement m in payments) _movement(ledger, m),
        ],
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'monthly_totals',
    description:
        'What was spent in each of the last six complete months, oldest '
        'first, and the monthly income, for a chart over time.',
    onCall: (_) {
      final Ledger ledger = current();
      final DateTime last = _lastMonth;
      return <String, Object?>{
        'months': <Object?>[
          for (var i = 5; i >= 0; i--)
            () {
              final DateTime m = DateTime(last.year, last.month - i);
              return <String, Object?>{
                'month': _monthKey(m),
                'amount': ledger.major(ledger.spentIn(m.year, m.month)),
              };
            }(),
        ],
        'monthlyIncome': ledger.major(ledger.incomeIn(last.year, last.month)),
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'subscriptions',
    description:
        'Every subscription charged each month, with its price, the day it '
        'started and the last day it was used.',
    onCall: (_) {
      final Ledger ledger = current();
      return <String, Object?>{
        'monthlyTotal': ledger.major(ledger.subscriptionsMonthly),
        'unusedMonthlyTotal': ledger.major(
          ledger.subscriptions
              .where((Subscription s) => s.unusedAsOf(appToday))
              .fold<int>(0, (int sum, Subscription s) => sum + s.price),
        ),
        'subscriptions': <Object?>[
          for (final Subscription s in ledger.subscriptions)
            <String, Object?>{
              'name': s.name,
              'price': ledger.major(s.price),
              'since': _day(s.since),
              'lastUsed': s.lastUsed == null ? null : _day(s.lastUsed!),
              'daysSinceUsed': s.daysSinceUsed(appToday),
              'unused': s.unusedAsOf(appToday),
            },
        ],
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'savings_goal',
    description:
        'The savings goal: what it is for, the target, what is saved, what '
        'goes into it each month today, and the deadline. Says so when there '
        'is none.',
    onCall: (_) {
      final Ledger ledger = current();
      if (ledger.goals.isEmpty) {
        return <String, Object?>{
          'goal': null,
          'note': 'There is no savings goal yet.',
        };
      }
      final Goal goal = ledger.goals.first;
      final num target = ledger.major(goal.target);
      final num saved = ledger.major(goal.saved);
      final num monthly = ledger.major(goal.monthly);
      return <String, Object?>{
        'name': goal.name,
        'target': target,
        'saved': saved,
        'missing': ledger.major(goal.missing),
        'monthly': monthly,
        'monthlyNeeded': monthlyNeeded(
          target.toDouble(),
          saved.toDouble(),
          _day(goal.deadline),
        ).round(),
        'arrivalAtCurrentPace': arrivalMonth(
          target.toDouble(),
          saved.toDouble(),
          monthly.toDouble(),
        ),
        'deadline': _day(goal.deadline),
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'record_expense',
    description:
        'Records an expense the person confirmed, dated today. Call it only '
        'after a save_expense event arrives, never on the first request. '
        'Returns what is free until payday afterwards and the month so far '
        'in that category.',
    inputSchema: S.object(
      properties: <String, Schema>{
        'amount': S.number(
          description:
              'In whole units of the account currency, positive: pesos '
              'are whole numbers.',
        ),
        'category': S.string(
          description: 'The category.',
          enumValues: <String>[
            for (final Category c in Category.values) c.name,
          ],
        ),
        'note': S.string(
          description: 'Where it was spent, if the person said.',
        ),
        'account': S.string(
          description:
              'The account it was paid from, if the person named one. Left '
              'out, it goes to the main account to spend from.',
        ),
      },
      required: <String>['amount', 'category'],
    ),
    onCall: (Map<String, dynamic> args) async {
      final Ledger ledger = current();
      final Object? amount = args['amount'];
      final Category? category = Category.values
          .where((Category c) => c.name == args['category'])
          .firstOrNull;
      if (amount is! num || amount <= 0 || category == null) {
        return _error(
          'amount must be a positive number and category one of '
          'the listed values',
        );
      }
      final String note = (args['note'] as String?)?.trim() ?? '';
      final String? account = (args['account'] as String?)?.trim();
      await record(
        ExpenseToRecord(
          amount: ledger.minor(amount),
          category: category,
          note: note,
          account: account == null || account.isEmpty ? null : account,
        ),
      );
      final Ledger after = current();
      return <String, Object?>{
        'recorded': true,
        'freeUntilPayday': after.major(after.freeUntilPayday),
        'nextPayday': _day(after.nextPayday),
        'categoryThisMonth': after.major(
          after.spentOn(category, appToday.year, appToday.month),
        ),
        'categoryLastMonth': after.major(
          after.spentOn(category, _lastMonth.year, _lastMonth.month),
        ),
      };
    },
  ),
];

DateTime get _lastMonth => DateTime(appToday.year, appToday.month - 1);

/// The change from [before] to [now] as a whole percentage, or null when
/// there was nothing before to compare with.
int? _percent(int now, int before) =>
    before == 0 ? null : ((now - before) / before * 100).round();

Map<String, Object?> _error(String message) => <String, Object?>{
  'error': message,
};

DateTime? _month(Object? value) {
  if (value is! String) return null;
  final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final int month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(match.group(1)!), month);
}

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

String _day(DateTime d) =>
    '${_monthKey(d)}-${d.day.toString().padLeft(2, '0')}';

Map<String, Object?> _movement(Ledger ledger, Movement m) => <String, Object?>{
  'merchant': m.merchant,
  'category': m.category.name,
  'amount': ledger.major(m.amount),
  'date': _day(m.date),
};
