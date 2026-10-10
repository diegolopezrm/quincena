import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../platform/share_text.dart';
import '../../sync/vault.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'qr_code.dart';
import 'scan_code.dart';

/// Shows [code] in groups of four that never break in the middle, what it
/// is for in [keep], and ways to keep it: copied, or handed to the share
/// sheet as [share], a line that says which code it is, so a note or a
/// chat with oneself tells the two codes apart later. With [qr], a code
/// another phone reads with its camera goes first, said by [qr].
Future<void> showCode(
  BuildContext context, {
  required String code,
  required String title,
  required String keep,
  required String share,
  String? done,
  String? qr,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final AppLocalizations l = context.l10n;
      void copied() {
        if (context.mounted) Navigator.of(context).pop();
        messenger?.showSnackBar(SnackBar(content: Text(l.syncCodeCopied)));
      }

      return AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (qr != null) ...<Widget>[
              Center(
                child: Semantics(
                  image: true,
                  label: qr,
                  child: QrCodeView(data: code),
                ),
              ),
              const SizedBox(height: 8),
              Text(qr, style: context.type.bodySmall),
              const SizedBox(height: 12),
            ],
            Semantics(
              label: code,
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final String group in code.split('-'))
                      Text(
                        group,
                        style: context.type.titleMedium?.copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                          letterSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    copied();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Glyph.clipboardText, size: 18),
                  label: Text(l.syncCopyCode),
                ),
                TextButton.icon(
                  // The sheet goes over the code and comes back to it; where
                  // there is none, the code is copied instead, and said so.
                  onPressed: () async {
                    if (!await ShareText.share(share)) copied();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Glyph.shareNetwork, size: 18),
                  label: Text(l.syncShareCode),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(keep, style: context.type.bodySmall),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(done ?? l.syncDone),
          ),
        ],
      );
    },
  );
}

/// Whether [code] spells the key that [read] gives, when it gives one: how
/// the app tells the person which of their two codes they typed. Anything
/// that is not a code, or a keychain that does not answer, is no.
Future<bool> codeIsKey(String code, Future<List<int>?> Function() read) async {
  try {
    final List<int>? key = await read();
    return key != null && listEquals(VaultKey.fromCode(code).bytes, key);
  } on Object {
    return false;
  }
}

/// Asks for a code until [use] takes it, and says whether it did. [use]
/// answers null when the code worked, or what to tell the person; a code
/// that is not one is caught here. With [scan], on a phone the code is read
/// from the other device's QR; otherwise it is pasted with «Pegar», or
/// typed as a last resort.
Future<bool> askForCode(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required Future<String?> Function(String code) use,
  bool scan = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _CodeDialog(
        title: title,
        body: body,
        action: action,
        use: use,
        scan: scan && canScanCodes,
      ),
    ) ??
    false;

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({
    required this.title,
    required this.body,
    required this.action,
    required this.use,
    this.scan = false,
  });

  final String title;
  final String body;
  final String action;
  final Future<String?> Function(String code) use;
  final bool scan;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final TextEditingController _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// What was copied: the code alone when it came with words around it,
  /// otherwise all of it, so the check below says what is wrong with it.
  Future<void> _paste() async {
    String copied;
    try {
      copied =
          (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    } on Object {
      // A clipboard that cannot be read holds nothing to paste.
      copied = '';
    }
    if (!mounted) return;
    setState(() {
      if (copied.isEmpty) {
        _error = context.l10n.codeNothingCopied;
        return;
      }
      _code.text = VaultKey.codeIn(copied) ?? copied;
      _error = null;
    });
  }

  /// What the camera read, used at once: a code read whole needs no
  /// second look.
  Future<void> _scan() async {
    final String? read = await scanCode(context);
    if (read == null || !mounted) return;
    setState(() {
      _code.text = read;
      _error = null;
    });
    await _submit();
  }

  Future<void> _submit() async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    String? error;
    try {
      error = await widget.use(VaultKey.codeIn(_code.text) ?? _code.text);
    } on CodeException catch (e) {
      error = switch (e.problem) {
        CodeProblem.length => l.syncCodeLength,
        CodeProblem.character => l.syncCodeCharacter,
        CodeProblem.check => l.syncCodeCheck,
      };
    }
    if (!mounted) return;
    if (error == null) {
      navigator.pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.body, style: context.type.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            // A pasted code shows whole: its fourteen groups take four
            // lines, and a field that scrolls hides where it is wrong.
            maxLines: 5,
            minLines: 2,
            decoration: InputDecoration(
              labelText: l.syncCodeField,
              errorText: _error,
              errorMaxLines: 4,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          Wrap(
            spacing: 4,
            children: <Widget>[
              if (widget.scan)
                TextButton.icon(
                  onPressed: _busy ? null : _scan,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Glyph.scan, size: 18),
                  label: Text(l.codeScan),
                ),
              TextButton.icon(
                onPressed: _busy ? null : _paste,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(Glyph.clipboardText, size: 18),
                label: Text(l.codePaste),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
