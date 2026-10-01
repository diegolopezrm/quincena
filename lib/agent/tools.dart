import 'package:dartantic_ai/dartantic_ai.dart';

import '../data/category.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../functions/money_functions.dart';

/// The questions a model can ask the account.
///
/// Every number a model shows has to come from one of these. They answer in
/// plain JSON with whole pesos and ISO dates, which is what the catalog's
/// data shapes and functions take, so a result can go into the data model as
/// it is.
List<Tool> ledgerTools(Ledger ledger) => <Tool>[
  Tool<Map<String, dynamic>>(
    name: 'account_overview',
    description:
        'The account today: the balance, what is already committed until the '
        'next payday, what is free to spend until then, the next payday and '
        'the monthly income. Call it before talking about what is left.',
    onCall: (_) => <String, Object?>{
      'owner': ledger.owner,
      'today': _day(appToday),
      'balance': ledger.balance,
      'committedUntilPayday': ledger.committedUntilPayday,
      'freeUntilPayday': ledger.freeUntilPayday,
      'nextPayday': _day(ledger.nextPayday),
      'monthlyIncome': ledger.incomeIn(_lastMonth.year, _lastMonth.month),
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
                  'amount': e.value,
                  'payments': ledger.countIn(e.key, m.year, m.month),
                  if (compare) ...<String, Object?>{
                    'previousAmount': previous,
                    'previousPayments': ledger.countIn(
                      e.key,
                      before.year,
                      before.month,
                    ),
                    'difference': e.value - previous,
                    'changePercent': _percent(e.value, previous),
                  },
                };
              }(),
          };
      return <String, Object?>{
        'month': _monthKey(month),
        'spent': spent,
        'income': income,
        'spentShareOfIncomePercent': income == 0
            ? null
            : (spent / income * 100).round(),
        'spentDifference': spent - spentBefore,
        'spentChangePercent': _percent(spent, spentBefore),
        'categories': categories(month, compare: true),
        'previousMonth': <String, Object?>{
          'month': _monthKey(before),
          'spent': spentBefore,
        },
        'largest': <Object?>[
          for (final Movement m in ledger.largestIn(month.year, month.month))
            _movement(m),
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
        'total': ledger.spentOn(category, month.year, month.month),
        'payments': <Object?>[for (final Movement m in payments) _movement(m)],
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'monthly_totals',
    description:
        'What was spent in each of the last six complete months, oldest '
        'first, and the monthly income, for a chart over time.',
    onCall: (_) {
      final DateTime last = _lastMonth;
      return <String, Object?>{
        'months': <Object?>[
          for (var i = 5; i >= 0; i--)
            () {
              final DateTime m = DateTime(last.year, last.month - i);
              return <String, Object?>{
                'month': _monthKey(m),
                'amount': ledger.spentIn(m.year, m.month),
              };
            }(),
        ],
        'monthlyIncome': ledger.incomeIn(last.year, last.month),
      };
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'subscriptions',
    description:
        'Every subscription charged each month, with its price, the day it '
        'started and the last day it was used.',
    onCall: (_) => <String, Object?>{
      'monthlyTotal': ledger.subscriptionsMonthly,
      'unusedMonthlyTotal': ledger.subscriptions
          .where((Subscription s) => s.unusedAsOf(appToday))
          .fold<int>(0, (int sum, Subscription s) => sum + s.price),
      'subscriptions': <Object?>[
        for (final Subscription s in ledger.subscriptions)
          <String, Object?>{
            'name': s.name,
            'price': s.price,
            'since': _day(s.since),
            'lastUsed': s.lastUsed == null ? null : _day(s.lastUsed!),
            'daysSinceUsed': s.daysSinceUsed(appToday),
            'unused': s.unusedAsOf(appToday),
          },
      ],
    },
  ),
  Tool<Map<String, dynamic>>(
    name: 'savings_goal',
    description:
        'The savings goal: what it is for, the target, what is saved, what '
        'goes into it each month today, and the deadline.',
    onCall: (_) {
      final Goal goal = ledger.goals.first;
      return <String, Object?>{
        'name': goal.name,
        'target': goal.target,
        'saved': goal.saved,
        'missing': goal.missing,
        'monthly': goal.monthly,
        'monthlyNeeded': monthlyNeeded(
          goal.target.toDouble(),
          goal.saved.toDouble(),
          _day(goal.deadline),
        ).round(),
        'arrivalAtCurrentPace': arrivalMonth(
          goal.target.toDouble(),
          goal.saved.toDouble(),
          goal.monthly.toDouble(),
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
        'amount': S.integer(description: 'Pesos, a whole positive number.'),
        'category': S.string(
          description: 'The category.',
          enumValues: <String>[
            for (final Category c in Category.values) c.name,
          ],
        ),
        'note': S.string(
          description: 'Where it was spent, if the person said.',
        ),
      },
      required: <String>['amount', 'category'],
    ),
    onCall: (Map<String, dynamic> args) {
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
      ledger.record(
        Movement(
          id: 'manual-${ledger.movements.length}',
          date: appToday,
          merchant: note.isEmpty ? category.label : note,
          amount: amount.round(),
          category: category,
        ),
      );
      return <String, Object?>{
        'recorded': true,
        'freeUntilPayday': ledger.freeUntilPayday,
        'nextPayday': _day(ledger.nextPayday),
        'categoryThisMonth': ledger.spentOn(
          category,
          appToday.year,
          appToday.month,
        ),
        'categoryLastMonth': ledger.spentOn(
          category,
          _lastMonth.year,
          _lastMonth.month,
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

Map<String, Object?> _movement(Movement m) => <String, Object?>{
  'merchant': m.merchant,
  'category': m.category.name,
  'amount': m.amount,
  'date': _day(m.date),
};
