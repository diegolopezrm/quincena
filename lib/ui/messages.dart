import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';

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

/// How long the way back stays after something is deleted, discarded or
/// archived.
const Duration undoTime = Duration(seconds: 6);

/// Says what was just deleted, discarded or archived, with «Deshacer» for a
/// few seconds, the same way on every screen; [undo] puts it back as it
/// was. [messenger] is taken before the sheet or page that did it closes,
/// so the message shows on what is left. With a screen reader the message
/// stays until it is used or another takes its place: reaching it takes
/// longer than a few seconds.
void showUndo(
  ScaffoldMessengerState messenger,
  String said,
  Future<void> Function() undo,
) {
  final BuildContext context = messenger.context;
  final bool reader =
      context
          .getInheritedWidgetOfExactType<MediaQuery>()
          ?.data
          .accessibleNavigation ??
      false;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(said),
        duration: undoTime,
        persist: reader,
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () => unawaited(undo()),
        ),
      ),
    );
}

/// Asks before what has a big effect and cannot simply be taken back:
/// [title] says what will happen, [body] what goes with it, and [action],
/// in red beside «Cancelar», does it. True only when the person said yes.
Future<bool> confirmDanger(
  BuildContext context, {
  required String title,
  String? body,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
