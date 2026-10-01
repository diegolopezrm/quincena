import 'category.dart';
import 'ledger.dart';

/// Six months of Valentina's account, April to September 2026.
///
/// Valentina is made up: a product designer in Medellín, paid on the 15th and
/// the last day of the month, living alone in a rented flat and saving for a
/// trip to Cartagena in December while she pays off her student loan. Every
/// merchant is made up too.
///
/// The months are generated from her routine with a fixed seed, so they look
/// lived in without being random between runs. On top of the routine sit the
/// few things that make September worth asking about: a birthday dinner and
/// more lunches out, a pair of headphones, a second streaming service that
/// started in August, and two subscriptions nobody has opened in weeks.
Ledger demoLedger() {
  final DateTime today = DateTime(2026, 10, 1);
  final _Dice dice = _Dice(20260930);
  final movements = <Movement>[];
  var serial = 0;

  void add(
    int month,
    int day,
    String merchant,
    int amount,
    Category category, [
    Flow flow = Flow.expense,
  ]) {
    final DateTime last = DateTime(2026, month + 1, 0);
    movements.add(
      Movement(
        id: 'm${++serial}',
        date: DateTime(2026, month, day > last.day ? last.day : day),
        merchant: merchant,
        amount: amount,
        category: category,
        flow: flow,
      ),
    );
  }

  int around(int value, double spread) =>
      _round(value * (1 + (dice.next() * 2 - 1) * spread));

  for (var month = 4; month <= 9; month++) {
    final bool august = month == 8;
    final bool september = month == 9;

    // Paid on the 15th and on the last day of the month.
    add(
      month,
      15,
      'Nómina Estudio Lumen',
      2400000,
      Category.other,
      Flow.income,
    );
    add(
      month,
      31,
      'Nómina Estudio Lumen',
      2400000,
      Category.other,
      Flow.income,
    );

    // What leaves every month, whatever happens.
    add(month, 5, 'Arriendo apartamento', 1650000, Category.housing);
    add(month, 9, 'Energía y agua', around(205000, 0.12), Category.utilities);
    add(month, 12, 'Internet hogar', 109900, Category.utilities);
    add(month, 17, 'Plan celular', 62000, Category.utilities);
    add(month, 2, 'Medicina prepagada', 189000, Category.health);
    add(month, 10, 'Crédito educativo', 312000, Category.debt);
    add(month, 1, 'Fit24 gimnasio', 119000, Category.subscriptions);
    add(month, 3, 'Cineplus', 38900, Category.subscriptions);
    add(month, 8, 'Ritmo', 21900, Category.subscriptions);
    add(month, 14, 'Nube 200 GB', 11900, Category.subscriptions);
    add(month, 20, 'Lingo Pro', 34900, Category.subscriptions);
    if (month >= 8) add(month, 22, 'Pantalla+', 26900, Category.subscriptions);

    // Into the Cartagena pocket, once a month, since June.
    if (month >= 6) {
      add(month, 16, 'Bolsillo Cartagena', 250000, Category.other, Flow.saving);
    }

    // Groceries: a big shop twice a month, the corner shop, the fruit stand.
    // September is a little lighter than August.
    final double groceries = september ? 0.86 : (august ? 1.04 : 1.0);
    for (final int day in <int>[3, 18]) {
      add(
        month,
        day,
        'Supermercado Andino',
        around((228000 * groceries).round(), 0.07),
        Category.groceries,
      );
    }
    for (var i = 0; i < 5; i++) {
      add(
        month,
        4 + i * 6,
        'Tienda Don Pacho',
        around((31000 * groceries).round(), 0.25),
        Category.groceries,
      );
    }
    for (final int day in <int>[11, 25]) {
      add(
        month,
        day,
        'Fruver La 70',
        around((44000 * groceries).round(), 0.12),
        Category.groceries,
      );
    }

    // Restaurants: September is the month that went up.
    final int lunches = september ? 11 : (august ? 8 : 7);
    for (var i = 0; i < lunches; i++) {
      add(
        month,
        2 + (i * 28 ~/ lunches),
        'Almuerzos Doña Rosa',
        around(21000, 0.12),
        Category.restaurants,
      );
    }
    final int coffees = september ? 6 : 5;
    for (var i = 0; i < coffees; i++) {
      add(
        month,
        3 + i * 4,
        'Café Cordillera',
        around(12500, 0.25),
        Category.restaurants,
      );
    }
    add(
      month,
      13,
      'Arepas La Esquina',
      around(46000, 0.2),
      Category.restaurants,
    );
    add(month, 26, 'Pizza Forno', around(78000, 0.2), Category.restaurants);
    if (september) {
      add(9, 19, 'Sushi Nikkei 33', 168000, Category.restaurants);
    }

    // Getting around: the metro card and the odd ride home.
    add(month, 1, 'Recarga Cívica', 50000, Category.transport);
    add(month, 16, 'Recarga Cívica', 50000, Category.transport);
    final int rides = september ? 9 : 6;
    for (var i = 0; i < rides; i++) {
      add(month, 5 + i * 3, 'RutaYa', around(14000, 0.3), Category.transport);
    }

    // The odd thing, different every month.
    add(month, 21, 'Droguería Laureles', around(38000, 0.5), Category.health);
    switch (month) {
      case 4:
        add(4, 12, 'Tienda Urbana', 168000, Category.shopping);
        add(4, 24, 'Cinema Laureles', 32000, Category.leisure);
      case 5:
        add(5, 9, 'Casa y Hogar', 94000, Category.shopping);
        add(5, 30, 'Bar El Patio', 86000, Category.leisure);
      case 6:
        add(6, 14, 'Bar El Patio', 112000, Category.leisure);
        add(6, 27, 'Librería Palabras', 74000, Category.shopping);
      case 7:
        add(7, 18, 'Boletas Festival Ciudad', 180000, Category.leisure);
        add(7, 25, 'Tienda Urbana', 132000, Category.shopping);
      case 8:
        add(8, 10, 'Tienda Urbana', 145000, Category.shopping);
        add(8, 23, 'Cinema Laureles', 36000, Category.leisure);
      case 9:
        add(9, 6, 'TecnoCentro audífonos', 389000, Category.shopping);
        add(9, 27, 'Bar El Patio', 94000, Category.leisure);
    }
  }

  // Already scheduled for the first fortnight of October.
  add(10, 1, 'Fit24 gimnasio', 119000, Category.subscriptions);
  add(10, 2, 'Medicina prepagada', 189000, Category.health);
  add(10, 3, 'Cineplus', 38900, Category.subscriptions);
  add(10, 5, 'Arriendo apartamento', 1650000, Category.housing);
  add(10, 8, 'Ritmo', 21900, Category.subscriptions);
  add(10, 10, 'Crédito educativo', 312000, Category.debt);
  add(10, 12, 'Internet hogar', 109900, Category.utilities);
  add(10, 14, 'Nube 200 GB', 11900, Category.subscriptions);

  return Ledger(
    owner: 'Valentina',
    today: today,
    openingBalance: 1840000,
    movements: movements,
    subscriptions: <Subscription>[
      Subscription(
        id: 'fit24',
        name: 'Fit24 gimnasio',
        price: 119000,
        chargeDay: 1,
        lastUsed: DateTime(2026, 8, 19),
        since: DateTime(2025, 11, 1),
      ),
      Subscription(
        id: 'cineplus',
        name: 'Cineplus',
        price: 38900,
        chargeDay: 3,
        lastUsed: DateTime(2026, 9, 29),
        since: DateTime(2024, 2, 3),
      ),
      Subscription(
        id: 'lingo',
        name: 'Lingo Pro',
        price: 34900,
        chargeDay: 20,
        lastUsed: DateTime(2026, 7, 30),
        since: DateTime(2026, 1, 20),
      ),
      Subscription(
        id: 'pantalla',
        name: 'Pantalla+',
        price: 26900,
        chargeDay: 22,
        lastUsed: DateTime(2026, 9, 12),
        since: DateTime(2026, 8, 22),
      ),
      Subscription(
        id: 'ritmo',
        name: 'Ritmo',
        price: 21900,
        chargeDay: 8,
        lastUsed: DateTime(2026, 9, 30),
        since: DateTime(2023, 5, 8),
      ),
      Subscription(
        id: 'nube',
        name: 'Nube 200 GB',
        price: 11900,
        chargeDay: 14,
        lastUsed: DateTime(2026, 9, 30),
        since: DateTime(2024, 9, 14),
      ),
    ],
    goals: <Goal>[
      Goal(
        id: 'cartagena',
        name: 'Cartagena',
        target: 2800000,
        saved: 1000000,
        monthly: 250000,
        deadline: DateTime(2026, 12, 20),
      ),
    ],
  );
}

/// To the nearest hundred pesos, the way prices are written.
int _round(double value) => (value / 100).round() * 100;

/// A small generator with a fixed sequence on every platform.
///
/// `dart:math`'s `Random` with a seed is not promised to give the same
/// numbers on the web as on the VM, and the demo has to tell the same story
/// on both. This is Park and Miller's minimal standard generator: its largest
/// intermediate value is under 2^47, so it stays exact where integers are
/// doubles with 53 bits of precision, which is what they are on the web.
class _Dice {
  _Dice(int seed) : _state = seed % _modulus;

  static const int _modulus = 2147483647;
  int _state;

  double next() {
    _state = _state * 48271 % _modulus;
    return _state / _modulus;
  }
}
