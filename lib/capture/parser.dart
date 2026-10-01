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

  /// The last four digits of the card or account, when the message says.
  final String? card;
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
  r'\b(recibiste|recibio|recibimos (un|una)|te (envio|envia|transfirio|transfirieron|consigno|consignaron|pago|llego)|abon\w*|consignacion|deposito|nomina|reembolso|devolucion|reintegro|ingreso de|received|you got|deposited|credited|refund)\b',
);
final RegExp _expense = RegExp(
  r'\b(compr\w*|pagaste|pago|pagos|retir\w*|debit\w*|cargo|transferiste|enviaste|envio de|avance|purchase|you paid|you sent|spent|charged|withdraw\w*|recibimos tu pago)\b',
);

/// Words before an amount that make it a balance or a limit, not the
/// movement.
final RegExp _notTheMovement = RegExp(
  r'(saldo|disponible|cupo|limite|balance)\W*\w*\W*$',
  caseSensitive: false,
);

final RegExp _card = RegExp(
  r'(?:\*\s?|terminad[ao]\s+en\s+|(?:tarjeta|cuenta|t\.?\s?cred|t\.?\s?deb)\D{0,14})(\d{4})\b',
  caseSensitive: false,
);

final RegExp _date = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b');
final RegExp _time = RegExp(r'\b(\d{1,2}):(\d{2})\b');

// Where a merchant's name stops.
// A notification's title and body arrive joined by ` · `.
const String _stop =
    r'(?=\s+(?:con|el|a las|desde|por|tarjeta|t\.?\s?cred|t\.?\s?deb|cuenta|en tu|a tu|via|mediante|aprobad\w*)\b|\s+\d{1,2}:\d{2}|\s+\d{1,2}/\d{1,2}|\s+\*|\s*·|[.,;!]\s|[.,;!]?$)';
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
final RegExp _merchantBefore = RegExp(
  r'^(?:[^:·]*[:·]\s*)?(.+?)\s+te\s+(?:envi[oó]|transfiri[oó]|pag[oó]|consign[oó])(?![a-z])',
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
      card: _cardIn(event.card ?? ''),
      institution: findInstitution(<String?>[event.card]) ?? institution,
      when: event.at,
      confidence: found.isNotEmpty || bare != null ? 0.95 : 0.3,
    );
  }

  final FoundAmount? amount = _movementAmount(text);
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

  final String? merchant = _merchant(text, kind);
  var confidence = 0.2;
  if (amount != null) confidence += 0.35;
  if (kind != null) confidence += 0.3;
  if (merchant != null) confidence += 0.1;
  if (institution != null) confidence += 0.05;

  return ParsedCapture(
    amount: amount?.value,
    asset: amount?.asset,
    kind: kind,
    merchant: merchant,
    card: _cardIn(text),
    institution: institution,
    when: _whenIn(text) ?? event.at,
    confidence: confidence.clamp(0, 1),
  );
}

/// Both verbs appear ("recibiste el pago"): the one said first decides.
EntryKind _firstOf(String plain) {
  final int i = _income.firstMatch(plain)?.start ?? plain.length;
  final int e = _expense.firstMatch(plain)?.start ?? plain.length;
  return i < e ? EntryKind.income : EntryKind.expense;
}

FoundAmount? _movementAmount(String text) {
  for (final FoundAmount a in findAmounts(text)) {
    final String before = text.substring(0, a.start);
    if (_notTheMovement.hasMatch(before)) continue;
    return a;
  }
  return null;
}

String? _cardIn(String text) => _card.firstMatch(text)?.group(1);

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
  for (final RegExp r in order) {
    final RegExpMatch? m = r.firstMatch(tail);
    if (m == null) continue;
    final String name = _clean(m.group(1)!);
    if (name.isEmpty || findAmounts(name).isNotEmpty) continue;
    if (RegExp(r'^\W*\d').hasMatch(name)) continue;
    return prettyMerchant(name);
  }
  return null;
}

String _clean(String raw) => raw
    .replaceAll(RegExp(r'\s+(?:por|de)\s*$', caseSensitive: false), '')
    .replaceAll(RegExp(r'[¡!¿?"“”]'), '')
    .trim();

DateTime? _whenIn(String text) {
  final RegExpMatch? d = _date.firstMatch(text);
  if (d == null) return null;
  final int day = int.parse(d.group(1)!);
  final int month = int.parse(d.group(2)!);
  int year = int.parse(d.group(3)!);
  if (year < 100) year += 2000;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final RegExpMatch? t = _time.firstMatch(text);
  final int hour = t == null ? 12 : int.parse(t.group(1)!).clamp(0, 23);
  final int minute = t == null ? 0 : int.parse(t.group(2)!).clamp(0, 59);
  return DateTime(year, month, day, hour, minute);
}
