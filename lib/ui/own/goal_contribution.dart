import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'account_sheet.dart';
import 'amount_input.dart';
import 'look.dart';

/// Puts money into [goal]: from an everyday account to the one it is saved
/// in, so it leaves the money to spend, or only counted, for money already
/// saved there. Says before saving what the goal and the accounts become.
Future<void> showGoalContribution(
  BuildContext context, {
  required OwnController own,
  required SavingsGoal goal,
  Decimal? amount,
}) => showDialog<void>(
  context: context,
  builder: (BuildContext context) =>
      _Contribution(own: own, goal: goal, amount: amount),
);

class _Contribution extends StatefulWidget {
  const _Contribution({required this.own, required this.goal, this.amount});

  final OwnController own;
  final SavingsGoal goal;

  /// What to put in, when it is known: what an envelope set aside for it.
  final Decimal? amount;

  @override
  State<_Contribution> createState() => _ContributionState();
}

class _ContributionState extends State<_Contribution> {
  late final TextEditingController _amount = TextEditingController(
    text: switch (widget.amount) {
      final Decimal a => formatDecimal(
        a,
        decimals: widget.goal.target.asset.decimals,
        trim: true,
      ),
      null => '',
    },
  );
  late String? _from = _likelyFrom();
  late String? _to = _savings.firstOrNull?.id;
  String? _error;
  bool _saving = false;

  /// The savings account made from here, listed before the app reads it.
  Account? _made;

  OwnController get own => widget.own;

  /// Everyday accounts in the goal's currency, where the money comes from.
  List<Account> get _everyday => <Account>[
    for (final Account a in own.accounts)
      if (a.spendable &&
          a.kind != AccountKind.card &&
          a.asset == widget.goal.target.asset)
        a,
  ];

  /// Accounts outside the money to spend, in the goal's currency, where it
  /// is saved.
  List<Account> get _savings => <Account>[
    for (final Account a in own.accounts)
      if (!a.spendable &&
          a.kind != AccountKind.card &&
          a.asset == widget.goal.target.asset)
        a,
    if (_made case final Account made
        when !own.accounts.any((Account a) => a.id == made.id))
      made,
  ];

  String? _likelyFrom() {
    final String? likely = own.likelyPaymentAccount?.id;
    return _everyday.any((Account a) => a.id == likely)
        ? likely
        : _everyday.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _addSavings() async {
    final AppLocalizations l = context.l10n;
    final Account? made = await showAccountSheet(
      context,
      own: own,
      draft: AccountDraft(
        name: l.goalSavingsName(widget.goal.name),
        kind: AccountKind.investment,
        asset: widget.goal.target.asset,
      ),
    );
    if (made != null && mounted) {
      setState(() {
        _made = made;
        _to = made.id;
      });
    }
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Decimal? amount = parseAmount(_amount.text);
    if (amount == null || amount <= Decimal.zero) {
      setState(() => _error = l.goalContributeInvalid);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    feelSaved();
    final NavigatorState navigator = Navigator.of(context);
    await own.contributeToGoal(
      widget.goal,
      amount,
      date: own.today,
      fromId: _to == null ? null : _from,
      toId: _to,
    );
    navigator.pop();
  }

  /// What the contribution does, before it is saved.
  String? _after(AppLocalizations l) {
    final Decimal? amount = parseAmount(_amount.text);
    if (amount == null || amount <= Decimal.zero) return null;
    final SavingsGoal goal = widget.goal;
    String money(Decimal d) =>
        moneyText(Money(d, goal.target.asset), base: own.profile?.base);
    String? name(String? id) =>
        own.accounts.where((Account a) => a.id == id).firstOrNull?.name;
    final String? from = name(_from);
    final String? to = name(_to);
    return <String>[
      l.goalContributeAfter(
        money(goal.saved.amount + amount),
        money(goal.target.amount),
      ),
      if (from != null && to != null)
        l.goalContributeMoves(from, money(amount), to)
      else
        l.goalContributeOnlyCounts,
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final List<Account> savings = _savings;
    final List<Account> everyday = _everyday;
    return AlertDialog(
      scrollable: true,
      title: Text(l.goalContributeTitle(widget.goal.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.goal.target.asset.decimals > 0,
            ),
            inputFormatters: <TextInputFormatter>[
              AmountInputFormatter(
                maxDecimals: widget.goal.target.asset.decimals,
              ),
            ],
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: l.amount,
              errorText: _error,
              prefixText: amountPrefix(widget.goal.target.asset),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            icon: const Icon(Glyph.caretDown, size: 18),
            // Made again when a new savings account is chosen for it.
            key: ValueKey<String?>('to-${_made?.id}'),
            initialValue: _to,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.goalContributeTo),
            items: <DropdownMenuItem<String?>>[
              for (final Account a in savings)
                DropdownMenuItem<String?>(
                  value: a.id,
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
              DropdownMenuItem<String?>(child: Text(l.goalContributeKept)),
            ],
            onChanged: (String? id) => setState(() => _to = id),
          ),
          // Without a place outside the money to spend, the money would
          // stay in it: say where to keep it, and make that place here.
          if (savings.isEmpty && _made == null) ...<Widget>[
            const SizedBox(height: 6),
            Text(l.goalContributeNoSavings, style: context.type.bodySmall),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _addSavings,
                icon: const Icon(Glyph.plus, size: 18),
                label: Text(l.goalContributeAddSavings),
              ),
            ),
          ],
          if (_to != null && everyday.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _from,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.goalContributeFrom),
              items: <DropdownMenuItem<String?>>[
                for (final Account a in everyday)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (String? id) => setState(() => _from = id),
            ),
          ],
          if (_after(l) case final String after) ...<Widget>[
            const SizedBox(height: 12),
            Text(after, style: context.type.bodySmall),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _save, child: Text(l.goalContribute)),
      ],
    );
  }
}
