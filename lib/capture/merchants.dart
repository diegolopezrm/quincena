/// What the app knows about merchants and banks in Colombia without asking:
/// which category a known name belongs to, and which institution a message
/// or an app is from.
library;

/// [text] lowercase, without accents or punctuation, single-spaced.
String normalize(String text) {
  const Map<String, String> plain = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
  };
  final StringBuffer out = StringBuffer();
  for (final String ch in text.toLowerCase().split('')) {
    out.write(plain[ch] ?? ch);
  }
  return out
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9&+ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// The part of a merchant's name that stays the same from one payment to
/// the next: no store numbers, no terminal codes. What learned rules are
/// keyed by.
String merchantKey(String merchant) => normalize(merchant)
    .split(' ')
    .where((String w) => w.isNotEmpty && !RegExp(r'^\d+$').hasMatch(w))
    .where((String w) => !_noise.contains(w))
    .take(3)
    .join(' ');

const Set<String> _noise = <String>{
  'pos',
  'ptm',
  'sas',
  's',
  'a',
  'ltda',
  'sa',
  'co',
  'col',
  'colombia',
  'bog',
  'med',
  'mde',
  'cali',
  'bta',
  'www',
  'com',
  'tienda',
  'pago',
  'compra',
};

/// A merchant's name as people write it: `EXITO LAURELES` becomes
/// `Exito Laureles`, and short all-caps names (`D1`, `KFC`) stay as they are.
String prettyMerchant(String raw) {
  final String trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  final bool shouting =
      trimmed == trimmed.toUpperCase() &&
      trimmed.contains(RegExp('[A-ZÁÉÍÓÚÑ]'));
  if (!shouting) return trimmed;
  return trimmed
      .split(' ')
      .map((String w) {
        if (w.length <= 3 && !_lowerWords.contains(w.toLowerCase())) return w;
        final String lower = w.toLowerCase();
        if (_lowerWords.contains(lower)) return lower;
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ')
      .replaceFirstMapped(RegExp('^[a-z]'), (Match m) => m[0]!.toUpperCase());
}

const Set<String> _lowerWords = <String>{
  'de',
  'del',
  'la',
  'las',
  'el',
  'los',
  'y',
};

/// Known names and the category their payments go to. Matched as whole
/// words against the normalized merchant, first match wins, so the longer,
/// more specific names come first.
const List<(String, String)> _known = <(String, String)>[
  // Transport first: "metro de medellin" is a train, not the Metro store.
  ('metro de medellin', 'transport'),
  ('metro medellin', 'transport'),
  ('tullave', 'transport'),
  ('transmilenio', 'transport'),
  ('civica', 'transport'),
  ('uber', 'transport'),
  ('didi', 'transport'),
  ('cabify', 'transport'),
  ('indrive', 'transport'),
  ('indriver', 'transport'),
  ('terpel', 'transport'),
  ('primax', 'transport'),
  ('texaco', 'transport'),
  ('biomax', 'transport'),
  ('mobil', 'transport'),
  ('peaje', 'transport'),
  ('parqueadero', 'transport'),
  ('avianca', 'transport'),
  ('latam', 'transport'),
  ('viva air', 'transport'),
  ('wingo', 'transport'),
  // Groceries.
  ('exito', 'groceries'),
  ('carulla', 'groceries'),
  ('jumbo', 'groceries'),
  ('d1', 'groceries'),
  ('ara', 'groceries'),
  ('olimpica', 'groceries'),
  ('makro', 'groceries'),
  ('pricesmart', 'groceries'),
  ('surtimax', 'groceries'),
  ('super inter', 'groceries'),
  ('supermercado', 'groceries'),
  ('mercado', 'groceries'),
  ('isimo', 'groceries'),
  ('oxxo', 'groceries'),
  ('metro', 'groceries'),
  ('euro supermercados', 'groceries'),
  ('consumo', 'groceries'),
  // Eating out.
  ('rappi', 'restaurants'),
  ('ifood', 'restaurants'),
  ('crepes', 'restaurants'),
  ('frisby', 'restaurants'),
  ('el corral', 'restaurants'),
  ('mcdonalds', 'restaurants'),
  ('kfc', 'restaurants'),
  ('burger king', 'restaurants'),
  ('juan valdez', 'restaurants'),
  ('starbucks', 'restaurants'),
  ('tostao', 'restaurants'),
  ('oma', 'restaurants'),
  ('presto', 'restaurants'),
  ('subway', 'restaurants'),
  ('dominos', 'restaurants'),
  ('pizza', 'restaurants'),
  ('restaurante', 'restaurants'),
  ('cafe', 'restaurants'),
  ('panaderia', 'restaurants'),
  // Subscriptions.
  ('netflix', 'subscriptions'),
  ('spotify', 'subscriptions'),
  ('disney', 'subscriptions'),
  ('hbo', 'subscriptions'),
  ('max', 'subscriptions'),
  ('prime video', 'subscriptions'),
  ('amazon prime', 'subscriptions'),
  ('youtube', 'subscriptions'),
  ('apple com bill', 'subscriptions'),
  ('icloud', 'subscriptions'),
  ('google one', 'subscriptions'),
  ('openai', 'subscriptions'),
  ('chatgpt', 'subscriptions'),
  ('anthropic', 'subscriptions'),
  ('claude ai', 'subscriptions'),
  ('crunchyroll', 'subscriptions'),
  ('paramount', 'subscriptions'),
  ('deezer', 'subscriptions'),
  ('playstation', 'subscriptions'),
  ('xbox', 'subscriptions'),
  ('smart fit', 'subscriptions'),
  ('bodytech', 'subscriptions'),
  ('fit24', 'subscriptions'),
  // Bills.
  ('epm', 'utilities'),
  ('enel', 'utilities'),
  ('codensa', 'utilities'),
  ('vanti', 'utilities'),
  ('gas natural', 'utilities'),
  ('emcali', 'utilities'),
  ('acueducto', 'utilities'),
  ('air e', 'utilities'),
  ('claro', 'utilities'),
  ('movistar', 'utilities'),
  ('tigo', 'utilities'),
  ('wom', 'utilities'),
  ('etb', 'utilities'),
  ('directv', 'utilities'),
  // Health.
  ('farmatodo', 'health'),
  ('cruz verde', 'health'),
  ('la rebaja', 'health'),
  ('locatel', 'health'),
  ('pasteur', 'health'),
  ('drogueria', 'health'),
  ('colsanitas', 'health'),
  ('sura', 'health'),
  ('compensar', 'health'),
  ('odontologia', 'health'),
  // Shopping.
  ('falabella', 'shopping'),
  ('mercadolibre', 'shopping'),
  ('mercado libre', 'shopping'),
  ('amazon', 'shopping'),
  ('alkosto', 'shopping'),
  ('ktronix', 'shopping'),
  ('homecenter', 'shopping'),
  ('zara', 'shopping'),
  ('h&m', 'shopping'),
  ('arturo calle', 'shopping'),
  ('studio f', 'shopping'),
  ('koaj', 'shopping'),
  ('tennis', 'shopping'),
  ('adidas', 'shopping'),
  ('nike', 'shopping'),
  ('temu', 'shopping'),
  ('shein', 'shopping'),
  // Going out.
  ('cine colombia', 'leisure'),
  ('cinemark', 'leisure'),
  ('procinal', 'leisure'),
  ('cinepolis', 'leisure'),
  ('tuboleta', 'leisure'),
  ('eticket', 'leisure'),
  ('ticketmaster', 'leisure'),
  ('bar', 'leisure'),
  // Housing and loans.
  ('arriendo', 'housing'),
  ('administracion', 'housing'),
  ('icetex', 'debt'),
  ('credito', 'debt'),
  ('cuota', 'debt'),
  ('prestamo', 'debt'),
];

/// The category a merchant with a well-known name usually belongs to, or
/// null.
String? knownCategory(String merchant) {
  final String m = ' ${normalize(merchant)} ';
  for (final (String name, String category) in _known) {
    if (m.contains(' $name ')) return category;
  }
  return null;
}

/// Institutions, and the words or app ids that give them away.
const Map<String, List<String>> institutions = <String, List<String>>{
  'Bancolombia': <String>['bancolombia', 'com.todo1.mobile'],
  'Nequi': <String>['nequi'],
  'Davivienda': <String>['davivienda'],
  'Daviplata': <String>['daviplata'],
  'BBVA': <String>['bbva'],
  'Banco de Bogotá': <String>['banco de bogota', 'bancodebogota'],
  'Nu': <String>[
    'nu colombia',
    'nubank',
    'com.nu.production',
    'tarjeta nu',
    'cuenta nu',
  ],
  'RappiPay': <String>['rappipay', 'rappicard', 'rappi pay'],
  'Lulo Bank': <String>['lulo bank', 'lulobank'],
  'Banco Falabella': <String>['banco falabella', 'cmr'],
  'Scotiabank Colpatria': <String>['colpatria', 'scotiabank'],
  'AV Villas': <String>['av villas', 'avvillas'],
  'Banco Popular': <String>['banco popular'],
  'Banco de Occidente': <String>['banco de occidente'],
  'Banco Caja Social': <String>['caja social'],
  'Itaú': <String>['itau'],
  'Binance': <String>['binance'],
  'PayPal': <String>['paypal'],
  'Global66': <String>['global66'],
};

/// The institution a document is from: the one it names first, as a
/// statement names its bank at the top and others only in its movements.
String? firstInstitution(String text) {
  final String n = ' ${normalize(text)} ';
  String? best;
  var at = n.length;
  for (final MapEntry<String, List<String>> e in institutions.entries) {
    for (final String marker in e.value) {
      if (marker.contains('.')) continue;
      final int i = n.indexOf(' $marker ');
      if (i >= 0 && i < at) {
        at = i;
        best = e.key;
      }
    }
  }
  return best;
}

/// The institution [texts] point to: the app that posted, the sender, the
/// message. Null when none says.
String? findInstitution(Iterable<String?> texts) {
  for (final String? t in texts) {
    if (t == null) continue;
    final String n = ' ${normalize(t.replaceAll('.', ' dot '))} ';
    final String raw = ' ${t.toLowerCase()} ';
    for (final MapEntry<String, List<String>> e in institutions.entries) {
      for (final String marker in e.value) {
        if (marker.contains('.')) {
          if (raw.contains(marker)) return e.key;
        } else if (n.contains(' $marker ')) {
          return e.key;
        }
      }
    }
  }
  return null;
}
