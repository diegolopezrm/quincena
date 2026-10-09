import '../capture/merchants.dart';
import 'records.dart';

/// Words that say money went to a card rather than to a shop.
final RegExp _paying = RegExp(r'\b(pago|pague|abono|abone|payment|paid)\b');
final RegExp _card = RegExp(
  r'\b(tarjeta|tc|tdc|visa|master|mastercard|amex|american express|diners|'
  r'card|credit card)\b',
);

/// The card among [accounts] that an expense written as [text], in
/// [category], most likely paid: «Pago Visa», «abono TC», «Pago tarjeta
/// Bancolombia», or a card's own name filed under loans. Paying a card
/// moves money between the person's accounts, so counting it as an
/// expense would count the purchases on the card twice.
///
/// A card named in the text is the one; a card only said in general goes
/// to the one that owes the most. Null when nothing points to a card.
Account? cardPaidBy(
  String text,
  String? category, {
  required List<Account> accounts,
  required Map<String, num> owed,
}) {
  final List<Account> cards = <Account>[
    for (final Account a in accounts)
      if (a.kind == AccountKind.card && !a.archived) a,
  ];
  if (cards.isEmpty) return null;
  final String said = normalize(text);
  if (said.isEmpty) return null;
  bool names(Account a) {
    final List<String> words = <String>[
      for (final String w in normalize('${a.name} ${a.institution}').split(' '))
        if (w.length > 2) w,
    ];
    return words.isNotEmpty && words.any((String w) => said.contains(w));
  }

  final bool paying = _paying.hasMatch(said);
  final bool loans = category == 'debt';
  final Account? named = cards.where(names).firstOrNull;
  // A card by its name: paid, or filed under loans and said as a card.
  if (named != null && (paying || (loans && _card.hasMatch(said)))) {
    return named;
  }
  if (paying && _card.hasMatch(said)) {
    // Said in general: the card that owes the most.
    final List<Account> owing = <Account>[...cards]
      ..sort(
        (Account a, Account b) => (owed[b.id] ?? 0).compareTo(owed[a.id] ?? 0),
      );
    return owing.first;
  }
  return null;
}
