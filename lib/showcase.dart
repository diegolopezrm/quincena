import 'package:flutter/foundation.dart';

/// Whether this build is the showcase for developers: the web demo, where
/// the example's conversation can also be answered by Gemini or by a key of
/// one's own, recorded Gemini sessions play back, and an inspector shows
/// how each answer was built. The phone apps are the product, and have none
/// of that: the example's conversation is the script, and with one's own
/// accounts questions go to Gemini through Quincena.
bool get showcase => debugShowcaseOverride ?? kIsWeb;

/// Plays the showcase on the VM, where [kIsWeb] is always false.
@visibleForTesting
bool? debugShowcaseOverride;
