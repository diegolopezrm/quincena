/// Where a payment went.
///
/// The names are what the model reads and writes, so they are English and
/// stable; what the person sees comes from `categoryLabel`.
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

/// What a person calls each category, in Spanish.
const Map<Category, String> categoryLabel = <Category, String>{
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
