import '../data/category.dart';

/// What the scripted agent recognizes in a question.
enum Intent { spending, goal, record, subscriptions, compare }

/// Lowercase, without accents, so "Qué" and "que" match the same way.
String plain(String text) {
  const String from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const String to = 'aeiouunAEIOUUN';
  final buffer = StringBuffer();
  for (final int rune in text.runes) {
    final String char = String.fromCharCode(rune);
    final int index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString().toLowerCase();
}

/// Which of the demo's questions [text] is closest to, if any, in Spanish
/// or in English.
Intent? intentOf(String text) {
  final String t = plain(text);
  bool any(List<String> words) => words.any(t.contains);
  if (any(<String>[
    'registra', 'anota', 'apunta', 'guarda un gasto', //
    'log ', 'record', 'add an expense', 'i spent',
  ])) {
    return Intent.record;
  }
  if (any(<String>['suscrip', 'cancel', 'streaming', 'subscription'])) {
    return Intent.subscriptions;
  }
  if (any(<String>[
    'cartagena', 'viaje', 'meta', 'me alcanza', 'ahorr', //
    'trip', 'afford', 'goal', 'saving',
  ])) {
    return Intent.goal;
  }
  if (any(<String>[
    'contra', 'compar', 'como voy', 'mes pasado', 'agosto', //
    'against', 'how am i doing', 'last month', 'august',
  ])) {
    return Intent.compare;
  }
  if (any(<String>[
    'en que', 'se me fue', 'gaste', 'gasto', 'plata', //
    'where did', 'money go', 'spend', 'spent',
  ])) {
    return Intent.spending;
  }
  return null;
}

/// An amount written the way people say it: "45 mil", "45.000", "45k",
/// "1,2 millones".
int? amountIn(String text) {
  final String t = plain(text);
  final RegExpMatch? match = RegExp(
    r'(\d+(?:[.,]\d+)*)\s*(millones|millon|mil|k|m\b)?',
  ).firstMatch(t);
  if (match == null) return null;
  final String digits = match.group(1)!;
  final String? unit = match.group(2);
  if (unit == null) {
    return int.tryParse(digits.replaceAll(RegExp('[.,]'), ''));
  }
  final double? value = double.tryParse(digits.replaceAll(',', '.'));
  if (value == null) return null;
  return switch (unit) {
    'mil' || 'k' => (value * 1000).round(),
    _ => (value * 1000000).round(),
  };
}

/// The category a sentence names, such as "en el mercado" or "at the
/// grocery store".
Category? categoryIn(String text) {
  final String t = plain(text);
  const Map<String, Category> words = <String, Category>{
    'mercado': Category.groceries,
    'super': Category.groceries,
    'tienda': Category.groceries,
    'almuerzo': Category.restaurants,
    'restaurante': Category.restaurants,
    'cafe': Category.restaurants,
    'comida': Category.restaurants,
    'taxi': Category.transport,
    'bus': Category.transport,
    'metro': Category.transport,
    'gasolina': Category.transport,
    'farmacia': Category.health,
    'drogueria': Category.health,
    'medic': Category.health,
    'ropa': Category.shopping,
    'compra': Category.shopping,
    'cine': Category.leisure,
    'bar': Category.leisure,
    'concierto': Category.leisure,
    'grocer': Category.groceries,
    'lunch': Category.restaurants,
    'restaurant': Category.restaurants,
    'coffee': Category.restaurants,
    'cab': Category.transport,
    'pharmacy': Category.health,
    'clothes': Category.shopping,
    'cinema': Category.leisure,
    'movie': Category.leisure,
  };
  for (final MapEntry<String, Category> entry in words.entries) {
    if (t.contains(entry.key)) return entry.value;
  }
  return null;
}
