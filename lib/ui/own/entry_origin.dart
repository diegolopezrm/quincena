import 'package:flutter/material.dart';

import '../../capture/inbox.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';

/// Where [entry] came from, with its icon, said the way a person would:
/// «Anotado a mano», «De una notificación de Bancolombia», «De un
/// extracto», «De Binance». [from] is the bank or app a capture came from,
/// when it is known. Null for a source the app has no words for.
(IconData, String)? entryOrigin(
  AppLocalizations l,
  Entry entry, {
  String? from,
}) => switch (entry.source.split(':').first) {
  'manual' => (Glyph.pencilSimple, l.originManual),
  'statement' => (Glyph.fileText, l.originStatement),
  'binance' => (Glyph.currencyBtc, l.originBinance),
  // A wallet followed by its address writes its own reference; Apple Pay's
  // payments, through the Wallet, the id of their capture.
  'wallet' when entry.sourceRef?.startsWith('wallet:') ?? false => (
    Glyph.wallet,
    l.originWallet,
  ),
  'wallet' => (Glyph.creditCard, l.originApplePay),
  'notification' => (
    Glyph.bell,
    from == null ? l.originNotification : l.originNotificationOf(from),
  ),
  'sms' => (
    Glyph.chatCircleDots,
    from == null ? l.originSms : l.originSmsOf(from),
  ),
  'email' => (
    Glyph.envelope,
    from == null ? l.originEmail : l.originEmailOf(from),
  ),
  'screenshot' => (Glyph.camera, l.originScreenshot),
  'paste' => (Glyph.clipboardText, l.originPaste),
  'gemini' => (Glyph.sparkle, l.originGemini),
  'script' => (Glyph.sparkle, l.originExample),
  _ => null,
};

/// The sources whose movements came through the inbox, and keep the id of
/// the capture they came from.
const Set<String> _captured = <String>{'notification', 'sms', 'email'};

/// A small line that says where [entry] came from, under the title of the
/// form that changes it: knowing it was typed by hand or came from the
/// bank helps tell a repeat. A capture names its bank while this device
/// keeps it; on another one it says only what kind it was, as captures do
/// not travel.
class EntryOrigin extends StatefulWidget {
  const EntryOrigin({super.key, required this.own, required this.entry});

  final OwnController own;
  final Entry entry;

  @override
  State<EntryOrigin> createState() => _EntryOriginState();
}

class _EntryOriginState extends State<EntryOrigin> {
  /// The bank or the app the capture came from, once read.
  String? _from;

  @override
  void initState() {
    super.initState();
    _readCapture();
  }

  Future<void> _readCapture() async {
    final String? ref = widget.entry.sourceRef;
    if (ref == null || !_captured.contains(widget.entry.source)) return;
    final InboxItem? item = await widget.own.store.inboxItem(ref);
    final String? from = item?.parsed.institution ?? item?.event.appName;
    if (!mounted || from == null || from.trim().isEmpty) return;
    setState(() => _from = from.trim());
  }

  @override
  Widget build(BuildContext context) {
    final (IconData, String)? origin = entryOrigin(
      context.l10n,
      widget.entry,
      from: _from,
    );
    if (origin == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(origin.$1, size: 16, color: context.colors.inkSoft),
          const SizedBox(width: 6),
          Expanded(child: Text(origin.$2, style: context.type.bodySmall)),
        ],
      ),
    );
  }
}
