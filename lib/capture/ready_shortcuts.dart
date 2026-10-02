import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// The shortcuts Quincena offers ready-made on an iPhone, as iCloud links.
///
/// From iOS 27 a shortcut carries its own trigger, so one link installs the
/// whole automation: it arrives switched off, and one toggle turns it on.
/// iOS 26 shortcuts carry no trigger; there the person makes the automation
/// and has it run one of the trigger-less ones, which already hand Quincena
/// what the trigger gives. A link left empty hides its button, so they can
/// arrive one at a time.
enum ReadyShortcut {
  bankNotifications(
    link: 'https://www.icloud.com/shortcuts/547c9b8651934d6f9ecbc92dd773b16e',
    withTrigger: true,
  ),
  bankMessages(
    link: 'https://www.icloud.com/shortcuts/0f5b3aeedb2146f18548f4a649440382',
    withTrigger: true,
  ),
  applePay(
    link: 'https://www.icloud.com/shortcuts/438195ff59434cf5b1706db1c0c16b17',
    withTrigger: true,
  ),
  screenshots(
    link: 'https://www.icloud.com/shortcuts/d57b944e1be2490e8a49da4e2eb81ff6',
    withTrigger: true,
  ),
  bankMessagesForIos26(link: '', withTrigger: false),
  applePayForIos26(link: '', withTrigger: false);

  const ReadyShortcut({required this.link, required this.withTrigger});

  /// Its iCloud link, empty until it is shared.
  final String link;

  /// Whether it brings its own trigger, which only iOS 27 and later read.
  final bool withTrigger;

  /// The ones this iPhone can add, with a link to add them from.
  static List<ReadyShortcut> forIos(int major) => <ReadyShortcut>[
    for (final ReadyShortcut s in values)
      if (s.link.isNotEmpty && s.withTrigger == (major >= 27)) s,
  ];
}

/// The iOS major version this runs on, or null anywhere else.
int? iosMajorVersion() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  return parseIosMajor(Platform.operatingSystemVersion);
}

/// The major version in what iOS reports, such as "Version 27.0 (Build …)".
@visibleForTesting
int? parseIosMajor(String version) {
  final RegExpMatch? match = RegExp(r'(\d+)\.\d+').firstMatch(version);
  return match == null ? null : int.tryParse(match.group(1)!);
}
