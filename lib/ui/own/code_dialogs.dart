import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../sync/vault.dart';
import '../../theme/tokens.dart';

/// Shows [code] in groups of four that never break in the middle, what it
/// is for in [keep], and a way to copy it.
Future<void> showCode(
  BuildContext context, {
  required String code,
  required String title,
  required String keep,
  String? done,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final AppLocalizations l = context.l10n;
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
            const SizedBox(height: 12),
            Text(keep, style: context.type.bodySmall),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) Navigator.of(context).pop();
              messenger?.showSnackBar(
                SnackBar(content: Text(l.syncCodeCopied)),
              );
            },
            child: Text(l.syncCopyCode),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(done ?? l.syncDone),
          ),
        ],
      );
    },
  );
}

/// Asks for a code until [use] takes it, and says whether it did. [use]
/// answers null when the code worked, or what to tell the person; a code
/// that is not one is caught here.
Future<bool> askForCode(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required Future<String?> Function(String code) use,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          _CodeDialog(title: title, body: body, action: action, use: use),
    ) ??
    false;

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({
    required this.title,
    required this.body,
    required this.action,
    required this.use,
  });

  final String title;
  final String body;
  final String action;
  final Future<String?> Function(String code) use;

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

  Future<void> _submit() async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    String? error;
    try {
      error = await widget.use(_code.text);
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
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              labelText: l.syncCodeField,
              errorText: _error,
              errorMaxLines: 3,
            ),
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
