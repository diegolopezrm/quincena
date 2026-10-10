import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../domain/records.dart';
import '../money/asset.dart';
import 'amounts.dart';
import 'event.dart';
import 'merchants.dart';

/// What a capture says, as far as the parser can tell.
@immutable
class ParsedCapture {
  const ParsedCapture({
    this.amount,
    this.asset,
    this.kind,
    this.merchant,
    this.card,
    this.account,
    this.institution,
    this.when,
    this.confidence = 0,
    this.ignored,
  });

  final Decimal? amount;

  /// Null when the message wrote only `$`: the account decides.
  final Asset? asset;

  /// Expense or income. A transfer between the person's own accounts looks
  /// like one of the two from either side; the person can say otherwise.
  final EntryKind? kind;
  final String? merchant;

  /// The last four digits of the card, when the message says.
  final String? card;

  /// The last four digits of the account, when the message names one
  /// ("en tu cuenta *5678", "Ahorros *5678"): not a card's.
  final String? account;
  final String? institution;

  /// When it happened, if the message says; otherwise when it arrived.
  final DateTime? when;

  /// From 0 to 1: how sure the parser is that this is a movement and that
  /// it read it right.
  final double confidence;

  /// Why this is not a movement at all: a security code, an ad. Null for a
  /// movement.
  final String? ignored;

  bool get isMovement => ignored == null && amount != null && kind != null;

  Map<String, Object?> toJson() => <String, Object?>{
    if (amount != null) 'amount': amount.toString(),
    if (asset != null) 'asset': asset!.code,
    if (kind != null) 'kind': kind!.name,
    if (merchant != null) 'merchant': merchant,
    if (card != null) 'card': card,
    if (account != null) 'account': account,
    if (institution != null) 'institution': institution,
    if (when != null) 'when': when!.toIso8601String(),
    'confidence': confidence,
    if (ignored != null) 'ignored': ignored,
  };

  static ParsedCapture fromJson(Map<String, Object?> json) => ParsedCapture(
    amount: Decimal.tryParse('${json['amount']}'),
    asset: json['asset'] is String ? Asset.of(json['asset']! as String) : null,
    kind: json['kind'] is String
        ? EntryKind.parse(json['kind']! as String)
        : null,
    merchant: json['merchant'] as String?,
    card: json['card'] as String?,
    account: json['account'] as String?,
    institution: json['institution'] as String?,
    when: DateTime.tryParse('${json['when']}'),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    ignored: json['ignored'] as String?,
  );
}

// Matched against the normalized text: lowercase, no accents.
final RegExp _securityCode = RegExp(
  r'\b(clave|codigo|otp|token|contrasena|password|verification|verificacion)\b',
);
final RegExp _securityDigits = RegExp(r'\b\d{4,8}\b');
final RegExp _advert = RegExp(
  r'\b(gana|ganate|descuento|promo|promocion|oferta|aprovecha|preaprobad\w*|cupo aprobado|participa|sorteo|beneficio exclusivo|te regalamos|hasta el \d)',
);

final RegExp _income = RegExp(
  r'\b(recibiste|recibio|recibid[oa]s?|recibimos (un|una)|te (envio|envia|enviaron|mando|mandaron|transfirio|transfirieron|consigno|consignaron|giro|giraron|pago|pagaron|llego|llegaron|depositaron|devolvieron)|llegaron(?: \S+){0,4} a (?:tu|su)|transferencia entrante|pago recibido de (?!tu |su )|abon\w*|consignacion|deposito|nomina|reembolso|devolucion|reintegro|ingreso (?:de|por|a)|received|you got|deposited|credited|refund)\b',
);
final RegExp _expense = RegExp(
  r'\b(compr\w*|pagaste|pago|pagos|retir\w*|debit\w*|cargo|transferiste|enviaste|envio de|envio (?:exitoso|realizado)|transferencia (?:exitosa|realizada|enviada)|pasaste|avance|purchase|you paid|you sent|spent|charged|withdraw\w*|recibimos tu pago)\b',
);

/// Words before an amount that make it a balance or a limit, not the
/// movement.
final RegExp _notTheMovement = RegExp(
  r'(saldo|disponible|cupo|limite|balance)\W*\w*\W*$',
  caseSensitive: false,
);

/// Last digits as alerts write them: `*1234`, `terminada en 1234`, `T.Deb
/// *1234`, `cuenta de ahorros *1234`.
final RegExp _digits = RegExp(
  r'(?:\*\s?|terminad[ao]\s+en\s+|(?:tarjeta|cuenta|cta|ahorros|corriente|t\.?\s?cred|t\.?\s?deb)\D{0,14})(\d{4})\b',
  caseSensitive: false,
);

// What the last digits belong to, by the word before them, matched
// against the folded text.
final RegExp _cardWord = RegExp(
  r'\b(?:tarjeta|tarj|t\.?\s?(?:cred|deb)\w*|tc|tdc|visa|mastercard|amex)\b',
);
final RegExp _accountWord = RegExp(r'\b(?:cuenta|cta|ahorros|corriente)\b');

// The account money went to ("a la cuenta *9999") and, for money in, the
// one it came from ("de la cuenta *1111"): someone else's, or another of
// the person's, not the one the alert is about; a card's own account
// ("asociada a la cuenta") is the one. Matched against the folded text
// right before the digits.
final RegExp _accountTo = RegExp(
  r'(?<!(?:asociad|vinculad)[ao]\s)\b(?:a|hacia|para)\s+(?:la|una|otra)\s+(?:cuenta|cta)\b\D*$',
);
final RegExp _accountFrom = RegExp(
  r'\bde(?:sde)?\s+(?:la|una|otra)\s+(?:cuenta|cta)\b\D*$',
);

// Dates as banks write them, matched against the normalized text:
// `01/10/2026`, `1 de octubre de 2026`, `01 Oct 2026`, `2026-10-01` and
// `Oct 1, 2026`.
final RegExp _date = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b');
final RegExp _dateWords = RegExp(
  r'\b(\d{1,2})\s*(?:de\s+)?(ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic|jan|apr|aug|dec)[a-z]*\.?,?\s*(?:de\s+|del\s+)?(\d{4})\b',
);
final RegExp _dateIso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
final RegExp _dateMonthFirst = RegExp(
  r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b',
);
const Map<String, int> _months = <String, int>{
  'ene': 1,
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'abr': 4,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'ago': 8,
  'aug': 8,
  'sep': 9,
  'set': 9,
  'oct': 10,
  'nov': 11,
  'dic': 12,
  'dec': 12,
};

/// `18:30`, `6:30 p. m.`, `06:30 PM`, `18:30:12`.
final RegExp _time = RegExp(
  r'\b(\d{1,2}):(\d{2})(?::\d{2})?(?:\s*([ap])\.?\s?m\b\.?)?',
  caseSensitive: false,
);

// Where a merchant's name stops.
// A notification's title and body arrive joined by ` · `, and a screenshot
// read on the phone comes in lines.
const String _stop =
    r'(?=\s+(?:con|el|a las|desde|por|tarjeta|t\.?\s?cred|t\.?\s?deb|cuenta|en tu|a tu|via|mediante|aprobad\w*)\b|\s+\d{1,2}:\d{2}|\s+\d{1,2}/\d{1,2}|\s+\*|\s*·|\s*\n|[.,;!]\s|[.,;!]?$)';
final List<RegExp> _merchantAfter = <RegExp>[
  RegExp(
    r'\ben\s+(?!tu\b|su\b|el cajero\b)(.+?)' + _stop,
    caseSensitive: false,
  ),
  RegExp(
    r'\ba\s+(?!tu\b|su\b|la cuenta\b|las\b)(.+?)' + _stop,
    caseSensitive: false,
  ),
  RegExp(r'\bde\s+(?!tu\b|su\b|\$)(.+?)' + _stop, caseSensitive: false),
];

/// Who sent money in, when the alert names them before the amount.
final RegExp _senderBefore = RegExp(
  r'\brecibid[oa]s?\s+de\s+(?!tu\b|su\b|\$)(.+?)' + _stop,
  caseSensitive: false,
);

/// An account's kind, where a merchant's name would be: a shop called
/// "Depósito …" is still a shop.
final RegExp _accountKind = RegExp(
  r'^(?:ahorros|corriente|cuenta|tarjeta|producto)\b',
);
final RegExp _merchantBefore = RegExp(
  r'^(?:[^:·]*[:·]\s*)?(.+?)\s+te\s+(?:envi[oó]|mand[oó]|gir[oó]|transfiri[oó]|pag[oó]|consign[oó])(?![a-z])',
  caseSensitive: false,
);

/// Reads a capture.
///
/// Built for the alerts Colombian banks and wallets send, without depending
/// on one bank's exact wording, which changes: an amount with a currency
/// marker, a verb that says which way the money went, and, when they are
/// there, the merchant, the card's last digits and the date. Security codes
/// and ads are recognized and set aside, so neither becomes a movement.
ParsedCapture parseCapture(CaptureEvent event) {
  final String text = event.text;
  final String plain = normalize(text);
  final String? institution = findInstitution(<String?>[
    event.app,
    event.sender,
    event.title,
    text,
  ]);

  if (_securityCode.hasMatch(plain) && _securityDigits.hasMatch(plain)) {
    return ParsedCapture(institution: institution, ignored: 'security');
  }
  if (_advert.hasMatch(plain) && !_income.hasMatch(plain)) {
    return ParsedCapture(institution: institution, ignored: 'advert');
  }

  // Apple Pay hands over the merchant and the amount already apart.
  if (event.source == CaptureSource.wallet) {
    final List<FoundAmount> found = findAmounts(event.amount ?? text);
    final Decimal? bare = parseLooseNumber(
      (event.amount ?? '').replaceAll(RegExp(r'[^\d.,]'), ''),
    );
    return ParsedCapture(
      amount: found.isNotEmpty ? found.first.value : bare,
      asset: found.isNotEmpty ? found.first.asset : null,
      kind: EntryKind.expense,
      merchant: event.merchant == null ? null : prettyMerchant(event.merchant!),
      // Apple Pay pays with a card, whatever its name says.
      card: _digits.firstMatch(event.card ?? '')?.group(1),
      institution: findInstitution(<String?>[event.card]) ?? institution,
      when: event.at,
      confidence: found.isNotEmpty || bare != null ? 0.95 : 0.3,
    );
  }

  // A receipt or a bank app's screen says what each figure is.
  final ({FoundAmount? amount, String? payee}) receipt = text.contains('\n')
      ? _receipt(text)
      : (amount: null, payee: null);
  final FoundAmount? amount = receipt.amount ?? _movementAmount(text);
  final bool income = _income.hasMatch(plain);
  final bool expense = _expense.hasMatch(plain);
  final EntryKind? kind = plain.contains('recibimos tu pago')
      ? EntryKind.expense
      : income && !expense
      ? EntryKind.income
      : expense && !income
      ? EntryKind.expense
      : income && expense
      ? _firstOf(plain)
      : null;

  final String? merchant = receipt.payee != null
      ? prettyMerchant(receipt.payee!)
      : _merchant(text, kind);
  final ({String? card, String? account}) digits = _digitsIn(text, kind);
  var confidence = 0.2;
  if (amount != null) confidence += 0.35;
  if (kind != null) confidence += 0.3;
  if (merchant != null) confidence += 0.1;
  if (institution != null) confidence += 0.05;
  // Text read from an image can misread a digit: it always waits for the
  // person, however clear the rest is.
  if (event.source == CaptureSource.screenshot) {
    confidence = math.min(confidence, 0.7);
  }

  return ParsedCapture(
    amount: amount?.value,
    asset: amount?.asset,
    kind: kind,
    merchant: merchant,
    card: digits.card,
    account: digits.account,
    institution: institution,
    when: _whenIn(text, event.at) ?? event.at,
    confidence: confidence.clamp(0, 1),
  );
}

/// Both verbs appear ("recibiste el pago"): the one said first decides,
/// and from the same word the longer saying ("pago recibido de", not
/// "pago").
EntryKind _firstOf(String plain) {
  final int i = _income.firstMatch(plain)?.start ?? plain.length;
  final int e = _expense.firstMatch(plain)?.start ?? plain.length;
  return i <= e ? EntryKind.income : EntryKind.expense;
}

FoundAmount? _movementAmount(String text) {
  for (final FoundAmount a in findAmounts(text)) {
    final String before = text.substring(0, a.start);
    if (_notTheMovement.hasMatch(before)) continue;
    return a;
  }
  return null;
}

/// The last digits [text] gives of a card and of an account. They are an
/// account's when the word closest before them names one ("en tu cuenta
/// *5678", "Ahorros *5678"), and a card's otherwise, as a bare `*1234` is.
/// Someone else's account, the one money of [kind] went to or came from,
/// is neither.
({String? card, String? account}) _digitsIn(String text, EntryKind? kind) {
  final RegExp? elsewhere = switch (kind) {
    EntryKind.expense => _accountTo,
    EntryKind.income => _accountFrom,
    _ => null,
  };
  String? card;
  String? account;
  var from = 0;
  for (final RegExpMatch m in _digits.allMatches(text)) {
    final String found = m.group(1)!;
    final String before = _fold(
      text.substring(math.max(from, m.start - 30), m.end - found.length),
    );
    from = m.end;
    int last(RegExp word) =>
        word.allMatches(before).map((RegExpMatch w) => w.start).lastOrNull ??
        -1;
    if (last(_accountWord) > last(_cardWord)) {
      if (elsewhere?.hasMatch(before) ?? false) continue;
      account ??= found;
    } else {
      card ??= found;
    }
  }
  return (card: card, account: account);
}

String? _merchant(String text, EntryKind? kind) {
  // Someone sent money: their name comes before the verb.
  final RegExpMatch? before = _merchantBefore.firstMatch(text);
  if (before != null && kind == EntryKind.income) {
    final String name = _clean(before.group(1)!);
    if (name.isNotEmpty && findAmounts(name).isEmpty) {
      return prettyMerchant(name);
    }
  }
  // Past the amount: "en EXITO", "a FIT24", "de EMPRESA SAS".
  final List<FoundAmount> amounts = findAmounts(text);
  final String tail = amounts.isEmpty
      ? text
      : text.substring(amounts.first.end);
  final List<RegExp> order = kind == EntryKind.income
      ? <RegExp>[_merchantAfter[2], _merchantAfter[0], _merchantAfter[1]]
      : _merchantAfter;
  String? named(String place, List<RegExp> patterns) {
    for (final RegExp r in patterns) {
      final RegExpMatch? m = r.firstMatch(place);
      if (m == null) continue;
      final String name = _clean(m.group(1)!);
      if (name.isEmpty || findAmounts(name).isNotEmpty) continue;
      if (RegExp(r'^\W*\d').hasMatch(name)) continue;
      if (_isDate(name)) continue;
      // An account's kind is not who got the money: "en tu cuenta de
      // ahorros".
      if (_accountKind.hasMatch(_fold(name))) continue;
      return prettyMerchant(name);
    }
    return null;
  }

  return named(tail, order) ??
      // Money in can name who sent it before the amount, after the word
      // that says it was received: "Pago recibido de CAMILO RUIZ por
      // $40.000". Not "Abono de nómina por", which names no one.
      (kind == EntryKind.income && amounts.isNotEmpty
          ? named(text.substring(0, amounts.first.start), <RegExp>[
              _senderBefore,
            ])
          : null);
}

/// Lowercase and without accents, every other character kept where it is,
/// so a match in it lines up with the original and `13:45`, `01/10` and a
/// line break survive. `normalize` makes them spaces.
String _fold(String text) {
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
  return out.toString();
}

/// Whether [text] is a date, or starts with a month: its name or its
/// abbreviation, not a name that starts like one ("Maria", "Julian").
bool _isDate(String text) {
  final String plain = _fold(text);
  return _dateWords.hasMatch(plain) ||
      _dateMonthFirst.hasMatch(plain) ||
      _month.hasMatch(plain);
}

final RegExp _month = RegExp(
  r'^(?:ene(?:ro)?|feb(?:rero)?|mar(?:zo)?|abr(?:il)?|mayo?|jun(?:io)?|jul(?:io)?|ago(?:sto)?|sep(?:tiembre)?|set(?:iembre)?|oct(?:ubre)?|nov(?:iembre)?|dic(?:iembre)?)\b',
);

// A receipt's labels, matched against a normalized line without its
// leading punctuation: "¿Cuánto?" reads as `cuanto?`.
final RegExp _amountLabel = RegExp(r'^(?:valor|monto|total|cuanto|importe)\b');
final RegExp _notTheAmount = RegExp(
  r'\b(?:costo|comision|cuota|iva|subtotal|saldo|disponible|cupo|impuesto|4x1000|gmf)\b',
);
final RegExp _payeeLabel = RegExp(
  r'^(?:para|destinatario|beneficiario|nombre del (?:destinatario|beneficiario|comercio)|a nombre de|producto destino|cuenta destino|destino|comercio|establecimiento|empresa|convenio|pagaste a|enviaste a)(?:\s*:\s*|\s{2,}|$)',
);
// A line that is only the kind of movement, with the merchant under it.
final RegExp _kindLine = RegExp(r'^(?:compra|compra con tarjeta|pago|retiro)$');
// An account's kind is not who got the money.
final RegExp _productWord = RegExp(
  r'^(?:ahorros|corriente|cuenta|deposito|tarjeta|producto)\b',
);
final RegExp _leadingMarks = RegExp(r'^[^\p{L}\p{N}]*', unicode: true);

/// What a receipt or a bank app's screen says, read line by line: the
/// amount after its label ("Valor", "¿Cuánto?", "Total") and who got it
/// after theirs ("Para", "Comercio", "Empresa"), on the same line or the
/// next. A screenshot read on the phone arrives like this.
({FoundAmount? amount, String? payee}) _receipt(String text) {
  final List<String> lines = <String>[
    for (final String l in text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  FoundAmount? amount;
  String? payee;
  for (var i = 0; i < lines.length; i++) {
    final String line = lines[i];
    final int lead = _leadingMarks.firstMatch(line)!.end;
    final String plain = _fold(line.substring(lead));
    if (amount == null &&
        _amountLabel.hasMatch(plain) &&
        !_notTheAmount.hasMatch(plain)) {
      amount = _amountNear(lines, i);
    }
    if (payee != null) continue;
    final RegExpMatch? label = _payeeLabel.firstMatch(plain);
    if (label != null) {
      payee =
          _name(line.substring(lead + label.end)) ??
          (i + 1 < lines.length ? _name(lines[i + 1]) : null);
    } else if (_kindLine.hasMatch(plain) && i + 1 < lines.length) {
      payee = _name(lines[i + 1]);
    }
  }
  return (amount: amount, payee: payee);
}

/// What an alert says about money moving between the person's own
/// accounts, which is neither spending nor income.
@immutable
class MoveHint {
  const MoveHint({this.own, this.withdrawal = false, this.cardPayment = false});

  /// Another bank or wallet the alert names as the person's own, where the
  /// money went («a tu Nequi») or came from («desde tu Bancolombia»).
  final String? own;

  /// Cash taken out at an ATM or a correspondent.
  final bool withdrawal;

  /// The payment of a credit card.
  final bool cardPayment;
}

// Matched against the folded text. What follows «a tu», «desde tu» and
// their kin names the person's other account, when it names a bank.
final RegExp _yourTo = RegExp(r'\b(?:a|hacia|para)\s+(?:tu|su)\s+');
final RegExp _yourFrom = RegExp(r'\b(?:desde|de)\s+(?:tu|su)\s+');
final RegExp _withdrew = RegExp(r'\bretir\w*\b');
final RegExp _atm = RegExp(r'\b(?:cajero|atm|corresponsal)\b');
final RegExp _paysCard = RegExp(
  r'\b(?:pago|pagaste|abono|abonaste)\b.{0,40}?\b(?:a|de|para)\s+'
  r'(?:la\s+|tu\s+|su\s+)?(?:tarjeta|tc|tdc)\b|\brecibimos tu pago\b',
);

/// Reads in [text], an alert from [institution] about money of [kind],
/// what says it moved between the person's own accounts.
MoveHint readMove(String text, {String? institution, EntryKind? kind}) {
  final String plain = _fold(text);
  String? own;
  final RegExp? your = switch (kind) {
    EntryKind.expense => _yourTo,
    EntryKind.income => _yourFrom,
    _ => null,
  };
  for (final RegExpMatch m in your?.allMatches(plain) ?? <RegExpMatch>[]) {
    final String after = plain.substring(
      m.end,
      math.min(plain.length, m.end + 30),
    );
    final String? named = findInstitution(<String>[after]);
    if (named != null && named != institution) {
      own = named;
      break;
    }
  }
  return MoveHint(
    own: own,
    withdrawal:
        kind == EntryKind.expense &&
        _withdrew.hasMatch(plain) &&
        _atm.hasMatch(plain),
    cardPayment: kind == EntryKind.expense && _paysCard.hasMatch(plain),
  );
}

/// The first amount on a label's line or the two under it, unless a line
/// about a cost or a balance comes first.
FoundAmount? _amountNear(List<String> lines, int i) {
  for (var j = i; j < lines.length && j <= i + 2; j++) {
    if (j > i && _notTheAmount.hasMatch(_fold(lines[j]))) return null;
    final List<FoundAmount> found = findAmounts(lines[j]);
    if (found.isNotEmpty) return found.first;
  }
  return null;
}

/// [line] when it reads as a name: letters, and not an amount, a date,
/// another label or the kind of an account.
String? _name(String line) {
  final String value = _clean(line.replaceFirst(RegExp(r'^[:\-–]\s*'), ''));
  if (value.isEmpty || findAmounts(value).isNotEmpty || _isDate(value)) {
    return null;
  }
  if (!RegExp(r'\p{L}{2}', unicode: true).hasMatch(value)) return null;
  final String plain = _fold(value);
  if (_amountLabel.hasMatch(plain) ||
      _payeeLabel.hasMatch(plain) ||
      _productWord.hasMatch(plain)) {
    return null;
  }
  return value;
}

String _clean(String raw) => raw
    .replaceAll(RegExp(r'\s+(?:por|de)\s*$', caseSensitive: false), '')
    .replaceAll(RegExp(r'[¡!¿?"“”]'), '')
    .trim();

/// The date and time [text] gives. Without a time, the hour it [arrived]
/// when that was the same day, or else noon.
DateTime? _whenIn(String text, DateTime arrived) {
  final String plain = _fold(text);
  // The first date in the text, in whichever form it came.
  final List<(RegExpMatch, int, int, int)> found =
      <(RegExpMatch, int, int, int)>[
        if (_date.firstMatch(plain) case final RegExpMatch m)
          (
            m,
            int.parse(m.group(3)!),
            int.parse(m.group(2)!),
            int.parse(m.group(1)!),
          ),
        if (_dateWords.firstMatch(plain) case final RegExpMatch m)
          (
            m,
            int.parse(m.group(3)!),
            _months[m.group(2)!] ?? 0,
            int.parse(m.group(1)!),
          ),
        if (_dateIso.firstMatch(plain) case final RegExpMatch m)
          (
            m,
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            int.parse(m.group(3)!),
          ),
        if (_dateMonthFirst.firstMatch(plain) case final RegExpMatch m)
          (
            m,
            int.parse(m.group(3)!),
            _months[m.group(1)!] ?? 0,
            int.parse(m.group(2)!),
          ),
      ]..sort((a, b) => a.$1.start.compareTo(b.$1.start));
  if (found.isEmpty) return null;
  final (RegExpMatch at, int y, int month, int day) = found.first;
  final int year = y < 100 ? y + 2000 : y;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // The time that goes with the date: the first one after it, which skips
  // the clock at the top of a screenshot, or else any.
  final RegExpMatch? t =
      _time
          .allMatches(plain)
          .where((RegExpMatch m) => m.start >= at.start)
          .firstOrNull ??
      _time.firstMatch(plain);
  final bool sameDay =
      arrived.year == year && arrived.month == month && arrived.day == day;
  if (t == null && sameDay) return arrived;
  var hour = t == null ? 12 : int.parse(t.group(1)!).clamp(0, 23);
  final int minute = t == null ? 0 : int.parse(t.group(2)!).clamp(0, 59);
  final String? half = t?.group(3)?.toLowerCase();
  if (half == 'p' && hour < 12) hour += 12;
  if (half == 'a' && hour == 12) hour = 0;
  return DateTime(year, month, day, hour, minute);
}
