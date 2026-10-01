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

  /// Short reasons, for the screen: `card`, `merchant`, `learned`, `place`.
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
    this.merchantCategories = const <String, String>{},
    this.cardAccounts = const <String, String>{},
    this.institutionAccounts = const <String, String>{},
  });

  /// Record without asking what is clear: a known account, a known
  /// category, no possible duplicate.
  final bool autoRecord;

  /// Keep where the phone was when a payment arrived, and look up the shops
  /// near it.
  final bool useLocation;

  /// Apps whose notifications are not read.
  final Set<String> mutedApps;

  /// Merchant key to category, learned from what the person confirmed.
  final Map<String, String> merchantCategories;

  /// Card or account last digits to account id.
  final Map<String, String> cardAccounts;

  /// Institution name to account id, for alerts that name no card.
  final Map<String, String> institutionAccounts;

  Map<String, Object?> toJson() => <String, Object?>{
    'autoRecord': autoRecord,
    'useLocation': useLocation,
    'mutedApps': mutedApps.toList()..sort(),
    'merchantCategories': merchantCategories,
    'cardAccounts': cardAccounts,
    'institutionAccounts': institutionAccounts,
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
      merchantCategories: map('merchantCategories'),
      cardAccounts: map('cardAccounts'),
      institutionAccounts: map('institutionAccounts'),
    );
  }

  CaptureSettings copyWith({
    bool? autoRecord,
    bool? useLocation,
    Set<String>? mutedApps,
    Map<String, String>? merchantCategories,
    Map<String, String>? cardAccounts,
    Map<String, String>? institutionAccounts,
  }) => CaptureSettings(
    autoRecord: autoRecord ?? this.autoRecord,
    useLocation: useLocation ?? this.useLocation,
    mutedApps: mutedApps ?? this.mutedApps,
    merchantCategories: merchantCategories ?? this.merchantCategories,
    cardAccounts: cardAccounts ?? this.cardAccounts,
    institutionAccounts: institutionAccounts ?? this.institutionAccounts,
  );
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
