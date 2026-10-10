import 'package:flutter/material.dart';

import '../../capture/inbox.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../own/undo.dart';
import '../messages.dart';

/// Who was paid, or who paid, in [item], as its card says it.
String capturePayee(AppLocalizations l, InboxItem item) =>
    item.suggestion.payee ?? item.parsed.merchant ?? l.noMerchant;

/// Sets [item] aside as no movement, and offers to take it back for a few
/// seconds. With [muteApp] its app stops being read, which asks first:
/// what arrives from it meanwhile is never kept, so no way back could
/// bring it. False when the person changed their mind.
Future<bool> discardCapture(
  BuildContext context,
  OwnController own,
  InboxItem item, {
  bool muteApp = false,
}) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String payee = capturePayee(l, item);
  final String app =
      item.parsed.institution ?? item.event.appName ?? item.event.app ?? '';
  if (muteApp &&
      !await confirmDanger(
        context,
        title: l.muteAppTitle(app),
        body: l.muteAppBody(app),
        action: l.muteAppGo,
      )) {
    return false;
  }
  final Undo back = await own.discard(item, muteApp: muteApp);
  showUndo(
    messenger,
    muteApp ? l.captureDiscardedMuted(payee, app) : l.captureDiscarded(payee),
    back,
  );
  return true;
}
