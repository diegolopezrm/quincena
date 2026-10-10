import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/records.dart';
import '../../domain/shared.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'amount_input.dart';

/// Records money lent to someone, or borrowed from them, as what it is: a
/// debt between two people, with no split to work out.
///
/// It goes into the group the person shares with just that someone, or a
/// new one named after them. Money lent from one of the person's accounts
/// is recorded there too, linked, so it counts as money lent and not as
/// spending.
Future<void> showLoanSheet(
  BuildContext context, {
  required OwnController own,
  required bool lent,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) => _LoanSheet(own: own, lent: lent),
);

class _LoanSheet extends StatefulWidget {
  const _LoanSheet({required this.own, required this.lent});

  final OwnController own;

  /// Money the person gave; otherwise money they received.
  final bool lent;

  @override
  State<_LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends State<_LoanSheet> {
  final TextEditingController _who = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _what = TextEditingController();
  late DateTime _date = widget.own.today;

  /// The account the money left or came into, when it did: the one it
  /// most likely moved in comes chosen.
  late String? _accountId = widget.own.likelyPaymentAccount?.id;
  String? _error;
  bool _saving = false;

  OwnController get own => widget.own;
  Asset get _base => own.profile?.base ?? Asset.cop;

  @override
  void dispose() {
    _who.dispose();
    _amount.dispose();
    _what.dispose();
    super.dispose();
  }

  static String _key(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = own.ledger;
    final String name = _who.text.trim();
    final Decimal? amount = parseAmount(_amount.text);
    if (name.isEmpty ||
        amount == null ||
        amount <= Decimal.zero ||
        ledger == null) {
      setState(() => _error = l.loanIncomplete);
      return;
    }
    setState(() => _saving = true);
    feelSaved();
    final NavigatorState navigator = Navigator.of(context);
    final int minor = ledger.minor(amount.toDouble());
    final String label = _what.text.trim().isEmpty
        ? l.loanLabel
        : _what.text.trim();
    // The group with just this person, or a new one named after them.
    final String key = _key(name);
    Group? group = own.groups
        .where(
          (Group g) =>
              g.members.length == 2 &&
              g.members.any((Member m) => !m.isMe && _key(m.name) == key),
        )
        .firstOrNull;
    final DateTime now = DateTime.now();
    final String personId =
        group?.members.firstWhere((Member m) => !m.isMe).id ??
        'p-${key.replaceAll(' ', '-')}';
    group ??= Group(
      id: 'group-${now.microsecondsSinceEpoch}',
      name: name,
      members: <Member>[
        const Member(id: meId, name: ''),
        Member(id: personId, name: name),
      ],
    );
    // Lent, the money leaves an account; borrowed, it comes into one.
    // Neither is spent nor earned: the loan's own part keeps it apart.
    String? entryId;
    final String? account = _accountId;
    if (account != null) {
      final Entry entry = await own.store.addEntry(
        accountId: account,
        amount: amount,
        kind: widget.lent ? EntryKind.expense : EntryKind.income,
        date: _date,
        category: 'other',
        payee: name,
        note: label,
        source: OwnController.planSource,
      );
      entryId = entry.id;
    }
    await own.saveGroup(
      group.withExpense(
        SharedExpense(
          id: 'expense-${now.microsecondsSinceEpoch}',
          label: label,
          date: _date,
          paidBy: widget.lent ? meId : personId,
          // A loan is an expense whose payer's own part is nothing.
          shares: <String, int>{widget.lent ? personId : meId: minor},
          entryId: entryId,
        ),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool lent = widget.lent;
    final List<Account> accounts = own.paymentAccounts;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              lent ? l.loanLentTitle : l.loanBorrowedTitle,
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _who,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: lent ? l.loanLentWho : l.loanBorrowedWho,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: _base.decimals),
              ],
              decoration: InputDecoration(
                labelText: l.amount,
                prefixText: amountPrefix(_base),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _what,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.loanWhat),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _accountId,
              isExpanded: true,
              icon: const Icon(Glyph.caretDown, size: 18),
              decoration: InputDecoration(
                labelText: lent ? l.loanFromAccount : l.loanToAccount,
              ),
              items: <DropdownMenuItem<String?>>[
                for (final Account a in accounts)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
                DropdownMenuItem<String?>(
                  child: Text(lent ? l.loanNoAccount : l.loanNoAccountIn),
                ),
              ],
              onChanged: (String? id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(own.today.year - 5),
                  lastDate: own.today,
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Glyph.calendarBlank, size: 18),
              label: Text(dayMonth(_date)),
            ),
            const SizedBox(height: 12),
            Text(
              lent ? l.loanLentNote : l.loanBorrowedNote,
              style: context.type.bodySmall,
            ),
            if (_error case final String error) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                error,
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.negative,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
