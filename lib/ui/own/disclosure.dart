import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';

/// One thing a disclosure says: what is used, when, or where it goes.
typedef DisclosureRow = ({IconData icon, String label, String text});

/// Says, in the app and before the system asks for anything, what personal
/// data Quincena is about to use, what for, when and where it goes, and
/// what the phone will ask next. True only when the person taps «Aceptar»:
/// «Ahora no» and going back are a no, and a tap outside does nothing.
Future<bool> askConsent(
  BuildContext context, {
  required String title,
  required String lead,
  List<DisclosureRow> rows = const <DisclosureRow>[],
  String? next,
}) async {
  final AppLocalizations l = context.l10n;
  final bool? accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(lead, style: context.type.bodyMedium),
          for (final DisclosureRow row in rows) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(row.icon, size: 20, color: context.colors.inkSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(row.label, style: context.type.titleSmall),
                      const SizedBox(height: 2),
                      Text(row.text, style: context.type.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (next != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(next, style: context.type.titleSmall),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.acceptLabel),
        ),
      ],
    ),
  );
  return accepted ?? false;
}
