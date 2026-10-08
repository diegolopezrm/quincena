import 'package:flutter/material.dart';

/// Where the app's messages at the bottom show, one at a time: the newest.
///
/// Every message in the app answers something the person just did. Queued,
/// as a [ScaffoldMessenger] does by default, a message waits for the one
/// before it to run out, and the person reads about the earlier action
/// after doing the next one: «Código copiado» while the file they just
/// saved goes unmentioned. Here a new message takes the place of the one
/// showing and of any still waiting.
class LatestMessenger extends ScaffoldMessenger {
  const LatestMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _LatestMessengerState();
}

class _LatestMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    clearSnackBars();
    return super.showSnackBar(
      snackBar,
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}
