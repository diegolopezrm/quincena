// ignore_for_file: avoid_print
// Prints the demo account month by month, to check the story it tells.
import 'package:quincena/data/category.dart';
import 'package:quincena/data/ledger.dart';
import 'package:quincena/data/seed.dart';

void main() {
  final Ledger l = demoLedger();
  String k(int v) => '${(v / 1000).round()}k'.padLeft(7);
  for (var m = 4; m <= 9; m++) {
    final Map<Category, int> by = Map<Category, int>.fromEntries(
      l.byCategory(2026, m),
    );
    print(
      '2026-$m  spent ${k(l.spentIn(2026, m))}  income ${k(l.incomeIn(2026, m))}  '
      '${Category.values.map((c) => '${c.name.substring(0, 4)} ${k(by[c] ?? 0)}').join(' ')}',
    );
  }
  print(
    'balance ${l.balance}  committed ${l.committedUntilPayday}  free ${l.freeUntilPayday}  payday ${l.nextPayday}',
  );
  print(
    'restaurants sep ${l.spentOn(Category.restaurants, 2026, 9)} aug ${l.spentOn(Category.restaurants, 2026, 8)}  '
    'lunches sep ${l.inCategory(Category.restaurants, 2026, 9).where((m) => m.merchant.startsWith('Almuerzos')).length}',
  );
  print(
    'groceries sep ${l.spentOn(Category.groceries, 2026, 9)} aug ${l.spentOn(Category.groceries, 2026, 8)}',
  );
  print('subs monthly ${l.subscriptionsMonthly}');
  print(
    'largest sep: ${l.largestIn(2026, 9).map((m) => '${m.merchant} ${m.amount}').join(' | ')}',
  );
}
