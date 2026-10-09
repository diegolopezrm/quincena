import 'package:flutter/material.dart';

import '../../domain/commitments.dart';
import '../../domain/records.dart';
import '../../domain/shared.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../own/repeats.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'entry_origin.dart';
import 'look.dart';

/// Shows the two movements of [pair] one over the other, with when, how
/// much and where each came from, and lets the person take the repeat
/// away, with a moment to undo it, or say they are two payments, which is
/// remembered.
Future<void> showRepeatSheet(
  BuildContext context, {
  required OwnController own,
  required PossibleRepeat pair,
}) {
  // The message with «Deshacer» outlives the sheet.
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext context) =>
        _RepeatSheet(own: own, pair: pair, messenger: messenger),
  );
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({
    required this.own,
    required this.pair,
    required this.messenger,
  });

  final OwnController own;
  final PossibleRepeat pair;
  final ScaffoldMessengerState messenger;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  bool _busy = false;

  OwnController get own => widget.own;

  /// Deletes the one recorded last, and its split with it, as deleting it
  /// from its form does; «Deshacer» puts both back as they were.
  Future<void> _remove() async {
    final AppLocalizations l = context.l10n;
    setState(() => _busy = true);
    final Entry gone = widget.pair.repeat;
    final (Group, SharedExpense)? split = own.splitOf(gone.id);
    await own.store.deleteEntry(gone);
    if (split case (final Group group, final SharedExpense expense)) {
      await own.saveGroup(group.withoutExpense(expense.id));
    }
    if (mounted) Navigator.of(context).pop();
    widget.messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.repeatRemoved),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () async {
              await own.store.restoreEntry(gone);
              if (split case (final Group group, _)) {
                await own.saveGroup(group);
              }
            },
          ),
        ),
      );
  }

  /// Remembers the two are two payments. When the charge detective saw the
  /// same two as charged twice, it hears the same answer, so «Cargos para
  /// revisar» does not ask again what Movimientos was told.
  Future<void> _keep() async {
    setState(() => _busy = true);
    final PossibleRepeat pair = widget.pair;
    await own.sayNotRepeated(pair);
    for (final ChargeAlert alert in own.allAlerts) {
      if (alert.kind == AlertKind.twice &&
          alert.evidence.any((Entry e) => e.id == pair.kept.id) &&
          alert.evidence.any((Entry e) => e.id == pair.repeat.id)) {
        await own.answerAlert(alert.id, AlertAnswer.expected);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final PossibleRepeat pair = widget.pair;
    final String account =
        own.snapshot?.account(pair.kept.accountId)?.name ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l.repeatTitle, style: context.type.headlineMedium),
          const SizedBox(height: 8),
          Text(l.repeatBody(account), style: context.type.bodyMedium),
          const SizedBox(height: 16),
          Panel(
            indent: 16,
            children: <Widget>[
              _Side(own: own, entry: pair.kept),
              _Side(own: own, entry: pair.repeat, newer: true),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _remove,
            icon: const Icon(Glyph.trash, size: 18),
            label: Text(l.repeatRemove),
          ),
          const SizedBox(height: 6),
          Text(
            l.repeatRemoveWhich,
            style: context.type.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _keep,
            child: Text(l.repeatKeep),
          ),
        ],
      ),
    );
  }
}

/// One of the two: what it was, how much, when, and where it came from;
/// the one recorded last says so.
class _Side extends StatelessWidget {
  const _Side({required this.own, required this.entry, this.newer = false});

  final OwnController own;
  final Entry entry;
  final bool newer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Account? account = own.snapshot?.account(entry.accountId);
    final String? category = entry.category;
    final String title = entry.payee.isNotEmpty
        ? entry.payee
        : category == null
        ? l.kindExpense
        : categoryNameFor(context, category, own.categories);
    final Widget name = Text(title, style: context.type.titleSmall);
    final Widget amount = Figures(
      account == null
          ? ''
          : moneyText(
              Money(entry.amount, account.asset),
              base: own.profile?.base,
              signed: true,
            ),
      style: context.type.titleSmall,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // With large text the amount goes under the name, each whole.
          if (largeText(context)) ...<Widget>[name, amount] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: name),
                const SizedBox(width: 12),
                amount,
              ],
            ),
          Text(dayAndTime(entry.date), style: context.type.bodySmall),
          EntryOrigin(own: own, entry: entry),
          if (newer)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.cautionSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l.repeatNewer,
                  style: context.type.labelMedium?.copyWith(
                    color: context.colors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
