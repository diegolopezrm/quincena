import 'package:flutter/foundation.dart';

import 'event.dart';
import 'parser.dart';
import 'places.dart';

/// Where an item in the inbox stands.
enum InboxStatus {
  /// Waiting for the person.
  pending,

  /// Recorded as a movement, by the person or automatically.
  accepted,

  /// Not a movement, or not one the person wants.
  dismissed,

  /// The same payment as another capture or an existing movement.
  duplicate;

  /// How it is stored. `new` reads better in the database than `pending`.
  String get stored => this == InboxStatus.pending ? 'new' : name;

  static InboxStatus parse(String value) => switch (value) {
    'accepted' => InboxStatus.accepted,
    'dismissed' => InboxStatus.dismissed,
    'duplicate' => InboxStatus.duplicate,
    _ => InboxStatus.pending,
  };
}

/// What the app proposes to record for a capture.
@immutable
class Suggestion {
  const Suggestion({
    this.accountId,
    this.category,
    this.payee,
    this.place,
    this.why = const <String>[],
  });

  final String? accountId;
  final String? category;
  final String? payee;

  /// The place nearest to where the phone was, when the location was on.
  final NearbyPlace? place;

  /// Short reasons: `card`, `account` (the account's last digits),
  /// `institution`, `currency`, `only` (the single account in the base
  /// currency), `learned`, `merchant`, `words`, `place`.
  final List<String> why;

  Map<String, Object?> toJson() => <String, Object?>{
    if (accountId != null) 'accountId': accountId,
    if (category != null) 'category': category,
    if (payee != null) 'payee': payee,
    if (place != null) 'place': place!.toJson(),
    if (why.isNotEmpty) 'why': why,
  };

  static Suggestion fromJson(Map<String, Object?> json) => Suggestion(
    accountId: json['accountId'] as String?,
    category: json['category'] as String?,
    payee: json['payee'] as String?,
    place: json['place'] is Map
        ? NearbyPlace.fromJson((json['place']! as Map).cast<String, Object?>())
        : null,
    why: <String>[
      for (final Object? w
          in json['why'] as List<Object?>? ?? const <Object?>[])
        '$w',
    ],
  );
}

/// One capture waiting in, or gone through, the inbox.
@immutable
class InboxItem {
  const InboxItem({
    required this.id,
    required this.event,
    required this.parsed,
    required this.suggestion,
    required this.status,
    this.entryId,
    this.duplicateOf,
    this.automatic = false,
  });

  final String id;
  final CaptureEvent event;
  final ParsedCapture parsed;
  final Suggestion suggestion;
  final InboxStatus status;

  /// The movement it became.
  final String? entryId;

  /// The inbox item or the movement it repeats.
  final String? duplicateOf;

  /// Recorded without the person, because everything about it was clear.
  final bool automatic;

  /// What the parsed column holds: the reading and the proposal.
  Map<String, Object?> parsedJson() => <String, Object?>{
    ...parsed.toJson(),
    'suggestion': suggestion.toJson(),
    if (duplicateOf != null) 'duplicateOf': duplicateOf,
    if (automatic) 'automatic': true,
  };

  InboxItem copyWith({
    InboxStatus? status,
    String? entryId,
    String? duplicateOf,
    Suggestion? suggestion,
    bool? automatic,
  }) => InboxItem(
    id: id,
    event: event,
    parsed: parsed,
    suggestion: suggestion ?? this.suggestion,
    status: status ?? this.status,
    entryId: entryId ?? this.entryId,
    duplicateOf: duplicateOf ?? this.duplicateOf,
    automatic: automatic ?? this.automatic,
  );
}

/// What the person set up for automatic capture, and what the app learned
/// from what they confirmed.
@immutable
class CaptureSettings {
  const CaptureSettings({
    this.autoRecord = false,
    this.useLocation = false,
    this.mutedApps = const <String>{},
    this.appNames = const <String, String>{},
    this.merchantCategories = const <String, String>{},
    this.merchantNames = const <String, String>{},
    this.cardAccounts = const <String, String>{},
    this.accountNumbers = const <String, String>{},
    this.institutionAccounts = const <String, String>{},
    this.disabledRules = const <String>{},
  });

  /// Record without asking what is clear: a known account, a known
  /// category, no possible duplicate.
  final bool autoRecord;

  /// Keep where the phone was when a payment arrived, and look up the shops
  /// near it.
  final bool useLocation;

  /// Apps whose notifications are not read.
  final Set<String> mutedApps;

  /// The names of [mutedApps], for the list where they can be read again.
  final Map<String, String> appNames;

  /// Merchant key to category, learned from what the person confirmed.
  final Map<String, String> merchantCategories;

  /// Merchant key to the name as the person last saw it, with its accents:
  /// a key is plain lowercase, «Éxito Laureles» reads `exito laureles`.
  final Map<String, String> merchantNames;

  /// A card's last digits to account id. Before the app told cards and
  /// accounts apart, an account's digits were learned here too.
  final Map<String, String> cardAccounts;

  /// An account's last digits, as its bank's alerts write them ("en tu
  /// cuenta *5678"), to account id.
  final Map<String, String> accountNumbers;

  /// Institution name to account id, for alerts that name no card.
  final Map<String, String> institutionAccounts;

  /// The rules the person turned off, by [CaptureRule.id]: kept, but not
  /// used.
  final Set<String> disabledRules;

  Map<String, Object?> toJson() => <String, Object?>{
    'autoRecord': autoRecord,
    'useLocation': useLocation,
    'mutedApps': mutedApps.toList()..sort(),
    'appNames': appNames,
    'merchantCategories': merchantCategories,
    'merchantNames': merchantNames,
    'cardAccounts': cardAccounts,
    'accountNumbers': accountNumbers,
    'institutionAccounts': institutionAccounts,
    'disabledRules': disabledRules.toList()..sort(),
  };

  static CaptureSettings fromJson(Map<String, Object?> json) {
    Map<String, String> map(String key) => <String, String>{
      for (final MapEntry<Object?, Object?> e
          in ((json[key] as Map?) ?? const <Object?, Object?>{}).entries)
        '${e.key}': '${e.value}',
    };
    return CaptureSettings(
      autoRecord: json['autoRecord'] == true,
      useLocation: json['useLocation'] == true,
      mutedApps: <String>{
        for (final Object? a
            in json['mutedApps'] as List<Object?>? ?? const <Object?>[])
          '$a',
      },
      appNames: map('appNames'),
      merchantCategories: map('merchantCategories'),
      merchantNames: map('merchantNames'),
      cardAccounts: map('cardAccounts'),
      accountNumbers: map('accountNumbers'),
      institutionAccounts: map('institutionAccounts'),
      disabledRules: <String>{
        for (final Object? r
            in json['disabledRules'] as List<Object?>? ?? const <Object?>[])
          '$r',
      },
    );
  }

  CaptureSettings copyWith({
    bool? autoRecord,
    bool? useLocation,
    Set<String>? mutedApps,
    Map<String, String>? appNames,
    Map<String, String>? merchantCategories,
    Map<String, String>? merchantNames,
    Map<String, String>? cardAccounts,
    Map<String, String>? accountNumbers,
    Map<String, String>? institutionAccounts,
    Set<String>? disabledRules,
  }) => CaptureSettings(
    autoRecord: autoRecord ?? this.autoRecord,
    useLocation: useLocation ?? this.useLocation,
    mutedApps: mutedApps ?? this.mutedApps,
    appNames: appNames ?? this.appNames,
    merchantCategories: merchantCategories ?? this.merchantCategories,
    merchantNames: merchantNames ?? this.merchantNames,
    cardAccounts: cardAccounts ?? this.cardAccounts,
    accountNumbers: accountNumbers ?? this.accountNumbers,
    institutionAccounts: institutionAccounts ?? this.institutionAccounts,
    disabledRules: disabledRules ?? this.disabledRules,
  );

  /// Everything learned, as rules a person can read.
  List<CaptureRule> get rules => <CaptureRule>[
    for (final MapEntry<String, String> e in merchantCategories.entries)
      _rule(RuleKind.merchant, e),
    for (final MapEntry<String, String> e in cardAccounts.entries)
      _rule(RuleKind.card, e),
    for (final MapEntry<String, String> e in accountNumbers.entries)
      _rule(RuleKind.account, e),
    for (final MapEntry<String, String> e in institutionAccounts.entries)
      _rule(RuleKind.institution, e),
  ];

  CaptureRule _rule(RuleKind kind, MapEntry<String, String> e) => CaptureRule(
    kind: kind,
    key: e.key,
    target: e.value,
    enabled: !disabledRules.contains(CaptureRule.idOf(kind, e.key)),
  );

  /// The target of the rule for [key], or null when there is none or it is
  /// turned off.
  String? use(RuleKind kind, String key) =>
      disabledRules.contains(CaptureRule.idOf(kind, key))
      ? null
      : _map(kind)[key];

  Map<String, String> _map(RuleKind kind) => switch (kind) {
    RuleKind.merchant => merchantCategories,
    RuleKind.card => cardAccounts,
    RuleKind.account => accountNumbers,
    RuleKind.institution => institutionAccounts,
  };

  /// With [rule] in place of whatever rule had its key.
  CaptureSettings withRule(CaptureRule rule) {
    final Map<String, String> map = <String, String>{
      ..._map(rule.kind),
      rule.key: rule.target,
    };
    final Set<String> off = <String>{
      for (final String id in disabledRules)
        if (id != rule.id) id,
      if (!rule.enabled) rule.id,
    };
    return switch (rule.kind) {
      RuleKind.merchant => copyWith(
        merchantCategories: map,
        disabledRules: off,
      ),
      RuleKind.card => copyWith(cardAccounts: map, disabledRules: off),
      RuleKind.account => copyWith(accountNumbers: map, disabledRules: off),
      RuleKind.institution => copyWith(
        institutionAccounts: map,
        disabledRules: off,
      ),
    };
  }

  /// Without the rule for [rule]'s key.
  CaptureSettings withoutRule(CaptureRule rule) {
    final Map<String, String> map = <String, String>{
      for (final MapEntry<String, String> e in _map(rule.kind).entries)
        if (e.key != rule.key) e.key: e.value,
    };
    final Set<String> off = <String>{
      for (final String id in disabledRules)
        if (id != rule.id) id,
    };
    return switch (rule.kind) {
      RuleKind.merchant => copyWith(
        merchantCategories: map,
        merchantNames: <String, String>{
          for (final MapEntry<String, String> e in merchantNames.entries)
            if (e.key != rule.key) e.key: e.value,
        },
        disabledRules: off,
      ),
      RuleKind.card => copyWith(cardAccounts: map, disabledRules: off),
      RuleKind.account => copyWith(accountNumbers: map, disabledRules: off),
      RuleKind.institution => copyWith(
        institutionAccounts: map,
        disabledRules: off,
      ),
    };
  }

  /// With [name] as how the merchant with [key] is shown.
  CaptureSettings withMerchantName(String key, String name) =>
      copyWith(merchantNames: <String, String>{...merchantNames, key: name});
}

/// What a rule matches on.
enum RuleKind {
  /// A merchant's name, to a category.
  merchant,

  /// A card's last digits, to an account.
  card,

  /// An account's last digits, to that account.
  account,

  /// A bank or a wallet whose alerts name no card, to an account.
  institution,
}

/// Something the app learned from what the person confirmed, as a rule
/// they can read, change or turn off. A rule shapes what arrives after it
/// and what still waits for its account: nothing already recorded changes
/// with it.
@immutable
class CaptureRule {
  const CaptureRule({
    required this.kind,
    required this.key,
    required this.target,
    this.enabled = true,
  });

  final RuleKind kind;

  /// What it matches: a merchant's key, a card's or an account's last
  /// digits, an institution.
  final String key;

  /// A category for a merchant, an account id otherwise.
  final String target;

  final bool enabled;

  String get id => idOf(kind, key);

  static String idOf(RuleKind kind, String key) => '${kind.name}:$key';

  CaptureRule copyWith({String? target, bool? enabled}) => CaptureRule(
    kind: kind,
    key: key,
    target: target ?? this.target,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      other is CaptureRule &&
      other.kind == kind &&
      other.key == key &&
      other.target == target &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(kind, key, target, enabled);
}

/// A rule a confirmation created or changed, and what it said before.
@immutable
class RuleChange {
  const RuleChange(this.rule, {this.previous, this.name});

  final CaptureRule rule;

  /// The target the rule had before, or null when it is new.
  final String? previous;

  /// A merchant's name as the card showed it, accents and all.
  final String? name;
}

/// Reads an inbox row's parsed column back into its parts.
({
  ParsedCapture parsed,
  Suggestion suggestion,
  String? duplicateOf,
  bool automatic,
})
readParsedColumn(Map<String, Object?> json) => (
  parsed: ParsedCapture.fromJson(json),
  suggestion: json['suggestion'] is Map
      ? Suggestion.fromJson(
          (json['suggestion']! as Map).cast<String, Object?>(),
        )
      : const Suggestion(),
  duplicateOf: json['duplicateOf'] as String?,
  automatic: json['automatic'] == true,
);
