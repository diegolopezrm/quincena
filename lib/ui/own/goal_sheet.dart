import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'amount_input.dart';

/// Adds a savings goal, or changes or deletes [goal].
Future<void> showGoalSheet(
  BuildContext context, {
  required OwnController own,
  SavingsGoal? goal,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) => _GoalSheet(own: own, goal: goal),
);

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.own, this.goal});

  final OwnController own;
  final SavingsGoal? goal;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final Asset _asset =
      widget.goal?.target.asset ?? widget.own.profile?.base ?? Asset.cop;
  late final TextEditingController _name = TextEditingController(
    text: widget.goal?.name ?? '',
  );
  late final TextEditingController _target = _amount(widget.goal?.target);
  late final TextEditingController _saved = _amount(widget.goal?.saved);
  late final TextEditingController _monthly = _amount(widget.goal?.monthly);
  late DateTime? _deadline = widget.goal?.deadline;
  String? _error;
  bool _saving = false;

  TextEditingController _amount(Money? m) => TextEditingController(
    text: m == null || m.amount == Decimal.zero
        ? ''
        : formatDecimal(m.amount, decimals: _asset.decimals, trim: true),
  );

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    _monthly.dispose();
    super.dispose();
  }

  Money _money(TextEditingController c) =>
      Money(parseAmount(c.text) ?? Decimal.zero, _asset);

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Decimal? target = parseAmount(_target.text);
    if (_name.text.trim().isEmpty || target == null || target <= Decimal.zero) {
      setState(() => _error = l.goalIncomplete);
      return;
    }
    setState(() => _saving = true);
    final SavingsGoal? old = widget.goal;
    if (old == null) {
      await widget.own.store.addGoal(
        name: _name.text,
        target: Money(target, _asset),
        saved: _money(_saved),
        monthly: _money(_monthly),
        deadline: _deadline,
      );
    } else {
      await widget.own.store.updateGoal(
        SavingsGoal(
          id: old.id,
          name: _name.text,
          target: Money(target, _asset),
          saved: _money(_saved),
          monthly: _money(_monthly),
          deadline: _deadline,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.goalDeleteTitle(widget.goal!.name)),
        content: Text(l.goalDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.goalDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await widget.own.store.deleteGoal(widget.goal!.id);
    navigator.pop();
  }

  Widget _field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        AmountInputFormatter(maxDecimals: _asset.decimals),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: switch (_asset.localSymbol ?? _asset.symbol) {
          final String sign => '$sign ',
          null => null,
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.goal == null ? l.goalAdd : l.goalEdit,
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.goalName),
              ),
            ),
            _field(_target, l.goalTarget),
            _field(_saved, l.goalSaved),
            _field(_monthly, l.goalMonthly),
            OutlinedButton.icon(
              onPressed: () async {
                final DateTime now = widget.own.today;
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime(now.year, now.month + 6),
                  firstDate: now,
                  lastDate: DateTime(now.year + 30),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
              icon: const Icon(Glyph.calendarBlank, size: 18),
              label: Text(
                _deadline == null
                    ? l.goalNoDeadline
                    : l.goalBy(dayMonth(_deadline!)),
              ),
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
            if (widget.goal != null)
              TextButton(
                onPressed: _saving ? null : _delete,
                child: Text(l.goalDelete),
              ),
          ],
        ),
      ),
    );
  }
}
