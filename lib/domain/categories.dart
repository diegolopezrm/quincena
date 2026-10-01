import '../data/category.dart';

/// The categories income goes into. The demo never needed them: its only
/// income was a salary, which the ledger reads by direction, not category.
const List<String> incomeCategoryKeys = <String>[
  'salary',
  'freelance',
  'interest',
  'refund',
  'gift',
  'other_income',
];

const Map<String, String> _incomeEs = <String, String>{
  'salary': 'Salario',
  'freelance': 'Trabajos independientes',
  'interest': 'Intereses y rendimientos',
  'refund': 'Reembolsos',
  'gift': 'Regalos',
  'other_income': 'Otros ingresos',
};

const Map<String, String> _incomeEn = <String, String>{
  'salary': 'Salary',
  'freelance': 'Freelance work',
  'interest': 'Interest and returns',
  'refund': 'Refunds',
  'gift': 'Gifts',
  'other_income': 'Other income',
};

/// Whether [key] names an income category.
bool isIncomeCategory(String key) => incomeCategoryKeys.contains(key);

/// The built-in expense category with [key], or null for any other key.
Category? expenseCategory(String? key) =>
    key == null ? null : Category.values.asNameMap()[key];

/// The category the ledger files a movement under. Income and categories the
/// person created count as [Category.other] there, which only the demo's
/// scripted answers read by category.
Category ledgerCategory(String? key) => expenseCategory(key) ?? Category.other;

/// What a person calls the category with [key] in [languageCode]. A name the
/// person gave it wins over the app's own.
String categoryLabel(String key, String languageCode, {String? custom}) {
  if (custom != null && custom.trim().isNotEmpty) return custom;
  final Category? expense = expenseCategory(key);
  if (expense != null) return expense.labelIn(languageCode);
  final Map<String, String> names = languageCode == 'en'
      ? _incomeEn
      : _incomeEs;
  return names[key] ?? key;
}

/// The keys of every built-in category, expenses first.
List<String> get builtInCategoryKeys => <String>[
  for (final Category c in Category.values) c.name,
  ...incomeCategoryKeys,
];
