import '../l10n/l10n.dart';

/// Where a payment went.
///
/// The names are what the model reads and writes, so they are English and
/// stable; what the person sees comes from [CategoryName.label].
enum Category {
  housing,
  groceries,
  restaurants,
  transport,
  utilities,
  subscriptions,
  health,
  shopping,
  leisure,
  debt,
  other,
}

const Map<Category, String> _spanish = <Category, String>{
  Category.housing: 'Arriendo',
  Category.groceries: 'Mercado',
  Category.restaurants: 'Restaurantes',
  Category.transport: 'Transporte',
  Category.utilities: 'Servicios',
  Category.subscriptions: 'Suscripciones',
  Category.health: 'Salud',
  Category.shopping: 'Compras',
  Category.leisure: 'Salidas',
  Category.debt: 'Créditos',
  Category.other: 'Otros',
};

const Map<Category, String> _english = <Category, String>{
  Category.housing: 'Rent',
  Category.groceries: 'Groceries',
  Category.restaurants: 'Eating out',
  Category.transport: 'Transport',
  Category.utilities: 'Bills',
  Category.subscriptions: 'Subscriptions',
  Category.health: 'Health',
  Category.shopping: 'Shopping',
  Category.leisure: 'Going out',
  Category.debt: 'Loans',
  Category.other: 'Other',
};

extension CategoryName on Category {
  /// What a person calls the category, in the interface language.
  String get label => labelIn(englishFormatting ? 'en' : 'es');

  /// What a person calls the category in [languageCode].
  String labelIn(String languageCode) =>
      (languageCode == 'en' ? _english : _spanish)[this]!;
}
