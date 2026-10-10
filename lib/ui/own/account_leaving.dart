import 'package:flutter/material.dart';

import '../../domain/commitments.dart';
import '../../domain/net_worth.dart';
import '../../domain/records.dart';
import '../../format/dates.dart' show listed;
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../own/undo.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import '../messages.dart';
import 'accounts_tab.dart' show AccountRow;
import 'look.dart';

/// What became of an account the person put away.
enum Leaving { archived, deleted }

/// Asks before [accounts] go, archived or, with [delete], deleted, and does
/// it. Says what goes with them and what stays: their movements, the
/// transfers left in other accounts, what is paid from them and where it
/// is paid from now on, and the net worth before and after, with why it
/// changes. Deleting offers to archive instead, unless [archive] is false.
/// [why] goes first, when something else asked for it. Once done, a way
/// back stays for a few seconds. Null when the person changed their mind.
Future<Leaving?> confirmLeaving(
  BuildContext context,
  OwnController own,
  List<Account> accounts, {
  bool delete = false,
  bool archive = true,
  String? why,
}) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final (Leaving, String?)? choice = await showDialog<(Leaving, String?)>(
    context: context,
    builder: (BuildContext context) => _LeavingDialog(
      own: own,
      accounts: accounts,
      delete: delete,
      archive: archive,
      why: why,
    ),
  );
  if (choice == null) return null;
  final (Leaving leaving, String? movedTo) = choice;
  final Set<String> ids = <String>{for (final Account a in accounts) a.id};
  final int movements = (own.snapshot?.entries ?? const <Entry>[])
      .where((Entry e) => ids.contains(e.accountId))
      .length;
  final String names = listed(<String>[
    for (final Account a in accounts) a.name,
  ]);
  final Undo back = await own.leave(
    accounts,
    delete: leaving == Leaving.deleted,
    movedTo: movedTo,
  );
  showUndo(
    messenger,
    leaving == Leaving.deleted
        ? l.accountDeleted(names, movements)
        : l.accountsArchived(names, accounts.length),
    back,
  );
  return leaving;
}

class _LeavingDialog extends StatefulWidget {
  const _LeavingDialog({
    required this.own,
    required this.accounts,
    required this.delete,
    required this.archive,
    this.why,
  });

  final OwnController own;
  final List<Account> accounts;
  final bool delete;
  final bool archive;
  final String? why;

  @override
  State<_LeavingDialog> createState() => _LeavingDialogState();
}

class _LeavingDialogState extends State<_LeavingDialog> {
  /// Where what is paid from the accounts goes; null, no account.
  String? _movedTo;

  late final Set<String> _ids = <String>{
    for (final Account a in widget.accounts) a.id,
  };

  /// How many movements the accounts have, and how many of them are legs
  /// of a transfer whose other leg stays in another account.
  (int, int) _movements() {
    final List<Entry> entries = widget.own.snapshot?.entries ?? const <Entry>[];
    final Map<String, int> elsewhere = <String, int>{};
    for (final Entry e in entries) {
      if (e.transferId case final String t when !_ids.contains(e.accountId)) {
        elsewhere[t] = (elsewhere[t] ?? 0) + 1;
      }
    }
    var movements = 0;
    var transfers = 0;
    for (final Entry e in entries) {
      if (!_ids.contains(e.accountId)) continue;
      movements++;
      if (elsewhere.containsKey(e.transferId)) transfers++;
    }
    return (movements, transfers);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final OwnController own = widget.own;
    final Asset base = own.profile?.base ?? Asset.cop;
    String money(Money m) => moneyText(m, base: base);
    final int count = widget.accounts.length;
    final (int movements, int transfers) = _movements();
    final (List<RecurringCharge> charges, List<Instalments> plans) = own
        .paidFrom(_ids);
    final List<String> paid = <String>[
      for (final RecurringCharge r in charges) r.name,
      for (final Instalments p in plans) p.name,
    ];
    final List<Account> others = <Account>[
      for (final Account a in own.accounts)
        if (!_ids.contains(a.id)) a,
    ];
    // The net worth now and once they go, and why it would change: what
    // they hold or owe leaves it, and instalments that were in a card's
    // debt count on their own, or the other way round.
    final NetWorth before = own.netWorth();
    final NetWorth after = own.netWorth(without: _ids, movedTo: _movedTo);
    var held = Money.zero(base);
    // Whether it also leaves the money to spend: each of them that holds
    // or owes something is for everyday use.
    var everyday = true;
    for (final Account a in widget.accounts) {
      if (a.archived) continue;
      if (own.partOfTotal(a) case final Money part) {
        held += part;
        if (!part.isZero && !a.spendable) everyday = false;
      }
    }
    final Money apart = after.instalments - before.instalments;
    final TextStyle? body = context.type.bodyMedium;
    final List<String> lines = <String>[
      ?widget.why,
      if (widget.delete)
        l.deleteAccountBody(movements)
      else ...<String>[
        if (movements > 0) l.archiveAccountKept(movements),
        l.archiveAccountHidden(count),
      ],
      if (widget.delete && transfers > 0) l.accountLeavingTransfers(transfers),
    ];
    final List<String> worth = <String>[
      if (held.isNegative)
        everyday
            ? l.accountLeavingOwedSpendable(count, money(held.abs()))
            : l.accountLeavingOwed(count, money(held.abs()))
      else if (!held.isZero)
        everyday
            ? l.accountLeavingHeldSpendable(count, money(held))
            : l.accountLeavingHeld(count, money(held)),
      if (apart.isNegative)
        l.accountLeavingInstalmentsCard(money(apart.abs()))
      else if (!apart.isZero)
        l.accountLeavingInstalmentsApart(money(apart)),
      if (before.total == after.total)
        l.accountLeavingWorthSame(money(after.total))
      else
        l.accountLeavingWorth(money(before.total), money(after.total)),
    ];
    final String names = listed(<String>[
      for (final Account a in widget.accounts) a.name,
    ]);
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.delete
            ? l.deleteAccountTitle(names)
            : l.archiveAccountTitle(names),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(line, style: body),
            ),
          if (paid.isNotEmpty) ...<Widget>[
            Text(
              l.accountLeavingCharges(paid.length, listed(paid)),
              style: body,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _movedTo,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.accountLeavingMoveTo),
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(
                  child: Text(
                    l.accountLeavingNoAccount,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final Account a in others)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (String? id) => setState(() => _movedTo = id),
            ),
            const SizedBox(height: 14),
          ],
          for (final String line in worth)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: body),
            ),
          if (widget.delete && widget.archive) ...<Widget>[
            const SizedBox(height: 6),
            Text(l.deleteAccountPreferArchive, style: context.type.bodySmall),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        if (widget.archive)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((Leaving.archived, _movedTo)),
            child: Text(l.archive),
          ),
        if (widget.delete)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((Leaving.deleted, _movedTo)),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(l.delete),
          ),
      ],
    );
  }
}

/// Among the accounts, the way to those archived, when there are any.
class ArchivedAccountsRow extends StatelessWidget {
  const ArchivedAccountsRow({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final int count = own.archivedAccounts.length;
    if (count == 0) return const SizedBox.shrink();
    final Widget mark = Icon(Glyph.archive, color: context.colors.inkSoft);
    final Widget name = Text(
      l.archivedAccountsTitle,
      style: context.type.titleSmall,
    );
    return Panel(
      children: <Widget>[
        ListTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => ArchivedAccountsPage(own: own),
            ),
          ),
          // With large text the icon goes above the title, as in Plan.
          leading: largeText(context) ? null : mark,
          title: largeText(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[mark, const SizedBox(height: 4), name],
                )
              : name,
          subtitle: Text(
            l.archivedAccountsCount(count),
            style: context.type.bodySmall,
          ),
          trailing: Icon(
            Glyph.caretRight,
            size: 18,
            color: context.colors.inkFaint,
          ),
        ),
      ],
    );
  }
}

/// The accounts put away: each with what it holds, its history a tap
/// away, and the way to bring it back.
class ArchivedAccountsPage extends StatelessWidget {
  const ArchivedAccountsPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final List<Account> archived = own.archivedAccounts;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.archivedAccountsTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    archived.isEmpty
                        ? l.archivedAccountsNone
                        : l.archivedAccountsBody,
                    style: context.type.bodyMedium,
                  ),
                ),
                if (archived.isNotEmpty)
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final Account a in archived)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AccountRow(own: own, account: a),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                child: TextButton.icon(
                                  onPressed: () => own.restoreAccount(a.id),
                                  icon: const Icon(
                                    Glyph.arrowCounterClockwise,
                                    size: 18,
                                  ),
                                  label: Text(l.restore),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// On an archived account's page: that it is put away, and the way back.
class ArchivedNote extends StatelessWidget {
  const ArchivedNote({super.key, required this.own, required this.account});

  final OwnController own;
  final Account account;

  @override
  Widget build(BuildContext context) => Block(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Glyph.archive,
                size: 18,
                color: context.colors.inkSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.accountArchivedNote,
                style: context.type.bodyMedium,
              ),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => own.restoreAccount(account.id),
            icon: const Icon(Glyph.arrowCounterClockwise, size: 18),
            label: Text(context.l10n.restore),
          ),
        ),
      ],
    ),
  );
}
