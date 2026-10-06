import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/commitments.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'amount_input.dart';
import 'look.dart';

/// What follows an amount to say how often: "al mes", "al año".
String cadenceAfter(AppLocalizations l, Cadence c) => switch (c) {
  Cadence.monthly => l.cadencePerMonth,
  Cadence.biweekly => l.cadencePerTwoWeeks,
  Cadence.weekly => l.cadencePerWeek,
  Cadence.yearly => l.cadencePerYear,
};

/// A fixed payment to add, filled in from charges that looked like one.
@immutable
class ChargeDraft {
  const ChargeDraft({
    required this.name,
    required this.amount,
    required this.next,
    this.category,
  });

  final String name;
  final Money amount;
  final DateTime next;
  final String? category;
}

/// Adds a fixed payment, or changes, pauses or deletes [charge].
Future<void> showChargeSheet(
  BuildContext context, {
  required OwnController own,
  RecurringCharge? charge,
  ChargeDraft? draft,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) =>
      _ChargeSheet(own: own, charge: charge, draft: draft),
);

class _ChargeSheet extends StatefulWidget {
  const _ChargeSheet({required this.own, this.charge, this.draft});

  final OwnController own;
  final RecurringCharge? charge;
  final ChargeDraft? draft;

  @override
  State<_ChargeSheet> createState() => _ChargeSheetState();
}

class _ChargeSheetState extends State<_ChargeSheet> {
  OwnController get own => widget.own;

  late final Asset _asset =
      widget.charge?.amount.asset ??
      widget.draft?.amount.asset ??
      own.profile?.base ??
      Asset.cop;
  late final TextEditingController _name = TextEditingController(
    text: widget.charge?.name ?? widget.draft?.name ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: switch (widget.charge?.amount ?? widget.draft?.amount) {
      final Money m when m.amount > Decimal.zero => formatDecimal(
        m.amount,
        decimals: _asset.decimals,
        trim: true,
      ),
      _ => '',
    },
  );
  late Cadence _cadence = widget.charge?.cadence ?? Cadence.monthly;
  late DateTime _next =
      widget.charge?.nextDate ??
      widget.draft?.next ??
      DateTime(own.today.year, own.today.month + 1, own.today.day);
  late String? _accountId = widget.charge != null
      ? widget.charge!.accountId
      : _mainAccount();
  late String? _category =
      widget.charge?.category ?? widget.draft?.category ?? 'subscriptions';
  late final ChargeMemory _memory = widget.charge == null
      ? const ChargeMemory()
      : own.memoryOf(widget.charge!.id);
  late DateTime? _trial = _memory.trialEnds;
  late int? _remind = _memory.remindDays;
  late bool? _inUse = _memory.inUse;
  String? _error;
  bool _saving = false;

  bool get _subscription => _category == 'subscriptions';

  String? _mainAccount() {
    final Asset? base = own.profile?.base;
    for (final Account a in own.accounts) {
      if (a.spendable && a.asset == base) return a.id;
    }
    return own.accounts.firstOrNull?.id;
  }

  @override
  void initState() {
    super.initState();
    _amount.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  RecurringCharge _charge(String id, Money amount, {required bool active}) =>
      RecurringCharge(
        id: id,
        name: _name.text.trim(),
        amount: amount,
        cadence: _cadence,
        nextDate: _next,
        accountId: _accountId,
        category: _category,
        active: active,
        since: widget.charge?.since,
      );

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Decimal? amount = parseAmount(_amount.text);
    if (_name.text.trim().isEmpty || amount == null || amount <= Decimal.zero) {
      setState(() => _error = l.chargeIncomplete);
      return;
    }
    setState(() => _saving = true);
    final String denied = own.example
        ? l.exampleNoReminders
        : l.chargeRemindDenied;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final Money money = Money(amount, _asset);
    final RecurringCharge? old = widget.charge;
    final String id;
    if (old == null) {
      id = (await own.store.addRecurring(
        name: _name.text,
        amount: money,
        cadence: _cadence,
        nextDate: _next,
        accountId: _accountId,
        category: _category,
      )).id;
    } else {
      id = old.id;
      await own.store.saveRecurring(_charge(id, money, active: old.active));
    }
    final ChargeMemory memory = ChargeMemory(
      trialEnds: _subscription ? _trial : null,
      remindDays: _remind,
      usedAt: _subscription && _inUse != _memory.inUse
          ? own.now()
          : _memory.usedAt,
      inUse: _subscription ? _inUse : null,
    );
    if (memory.trialEnds == null &&
        memory.remindDays == null &&
        memory.inUse == null) {
      await own.forgetMemory(id);
    } else {
      await own.saveMemory(id, memory);
    }
    navigator.pop();
    final bool asked =
        (memory.remindDays != null &&
            memory.remindDays != _memory.remindDays) ||
        (memory.trialEnds != null && memory.trialEnds != _memory.trialEnds);
    if (asked && !await own.allowReminders()) {
      messenger.showSnackBar(SnackBar(content: Text(denied)));
    }
  }

  /// Stops counting it as committed, or starts again, as it was saved.
  Future<void> _pause() async {
    final RecurringCharge old = widget.charge!;
    final NavigatorState navigator = Navigator.of(context);
    await own.store.saveRecurring(
      RecurringCharge(
        id: old.id,
        name: old.name,
        amount: old.amount,
        cadence: old.cadence,
        nextDate: old.nextDate,
        accountId: old.accountId,
        category: old.category,
        active: !old.active,
        since: old.since,
      ),
    );
    navigator.pop();
  }

  Future<void> _delete() async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final RecurringCharge old = widget.charge!;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.chargeDeleteTitle(old.name)),
        content: Text(l.chargeDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.chargeDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await own.store.deleteRecurring(old.id);
    await own.forgetMemory(old.id);
    navigator.pop();
  }

  Future<void> _pickNext() async {
    final DateTime today = own.today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _next,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) setState(() => _next = picked);
  }

  Future<void> _pickTrial() async {
    final DateTime today = own.today;
    final DateTime initial = _trial ?? today.add(const Duration(days: 7));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // A trial that already ended still opens, to move it.
      firstDate: initial.isBefore(today) ? initial : today,
      lastDate: DateTime(today.year + 2),
    );
    // The first charge comes when the trial ends.
    if (picked != null) {
      setState(() {
        _trial = picked;
        _next = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final Decimal? amount = parseAmount(_amount.text);
    final Money? yearly = amount == null || amount <= Decimal.zero
        ? null
        : Money(amount * Decimal.fromInt(perYear(_cadence).round()), _asset);
    final Ledger? ledger = own.ledger;
    final Movement? last = ledger == null || widget.charge == null
        ? null
        : lastChargeOf(ledger, widget.charge!.name);
    final List<CategoryItem> categories = <CategoryItem>[
      for (final CategoryItem c in own.categories)
        if (!c.archived && !c.income) c,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.charge == null ? l.chargeAdd : l.chargeEdit,
              style: context.type.headlineMedium,
            ),
            if (widget.charge?.active == false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.chargePausedNote, style: context.type.bodySmall),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.chargeName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: _asset.decimals),
              ],
              decoration: InputDecoration(
                labelText: l.chargeAmount,
                prefixText: switch (_asset.localSymbol ?? _asset.symbol) {
                  final String sign => '$sign ',
                  null => null,
                },
                suffixText: _asset == base ? null : _asset.code,
              ),
            ),
            if (last != null &&
                ledger != null &&
                _asset == base &&
                amount != null &&
                ledger.minor(amount.toDouble()) != last.amount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _amount.text = formatDecimal(
                    Decimal.parse('${ledger.major(last.amount)}'),
                    decimals: _asset.decimals,
                    trim: true,
                  ),
                  child: Text(
                    l.chargeUseLast(
                      pesos(ledger.major(last.amount)),
                      dayMonth(last.date),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Cadence>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _cadence,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.chargeCadence),
              items: <DropdownMenuItem<Cadence>>[
                for (final Cadence c in Cadence.values)
                  DropdownMenuItem<Cadence>(
                    value: c,
                    child: Text(switch (c) {
                      Cadence.monthly => l.cadenceMonthly,
                      Cadence.biweekly => l.cadenceBiweekly,
                      Cadence.weekly => l.cadenceWeekly,
                      Cadence.yearly => l.cadenceYearly,
                    }),
                  ),
              ],
              onChanged: (Cadence? c) =>
                  setState(() => _cadence = c ?? _cadence),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickNext,
              icon: const Icon(Glyph.calendarBlank, size: 18),
              label: Text(l.chargeNext(dayMonth(_next))),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _accountId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.chargeAccount),
              items: <DropdownMenuItem<String?>>[
                for (final Account a in own.accounts)
                  DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
                DropdownMenuItem<String?>(child: Text(l.chargeNoAccount)),
              ],
              onChanged: (String? id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 20),
            Text(l.category, style: context.type.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final CategoryItem c in categories)
                  ChoiceChip(
                    avatar: Icon(
                      categoryIconFor(c.key),
                      size: 18,
                      color: categoryColorFor(context, c.key),
                    ),
                    label: Text(
                      categoryNameFor(context, c.key, own.categories),
                    ),
                    selected: _category == c.key,
                    onSelected: (bool on) =>
                        setState(() => _category = on ? c.key : null),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int?>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _remind,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.chargeRemind,
                prefixIcon: Icon(
                  _remind == null ? Glyph.bellSlash : Glyph.bell,
                  size: 18,
                ),
              ),
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(child: Text(l.remindNever)),
                DropdownMenuItem<int?>(value: 0, child: Text(l.remindSameDay)),
                DropdownMenuItem<int?>(
                  value: 1,
                  child: Text(l.remindDayBefore),
                ),
                DropdownMenuItem<int?>(
                  value: 3,
                  child: Text(l.remindDaysBefore(3)),
                ),
                DropdownMenuItem<int?>(
                  value: 7,
                  child: Text(l.remindWeekBefore),
                ),
              ],
              onChanged: (int? days) => setState(() => _remind = days),
            ),
            if (_subscription) ...<Widget>[
              const SizedBox(height: 20),
              Text(l.chargeSubscription, style: context.type.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTrial,
                      icon: const Icon(Glyph.hourglass, size: 18),
                      label: Text(
                        _trial == null
                            ? l.chargeTrialAsk
                            : l.chargeTrialUntil(dayMonth(_trial!)),
                      ),
                    ),
                  ),
                  if (_trial != null)
                    IconButton(
                      tooltip: l.chargeTrialClear,
                      onPressed: () => setState(() => _trial = null),
                      icon: const Icon(Glyph.x, size: 18),
                    ),
                ],
              ),
              if (_trial != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.chargeTrialNote, style: context.type.bodySmall),
                ),
              const SizedBox(height: 16),
              Text(l.chargeInUseAsk, style: context.type.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(l.chargeInUseYes),
                    selected: _inUse == true,
                    onSelected: (bool on) =>
                        setState(() => _inUse = on ? true : null),
                  ),
                  ChoiceChip(
                    label: Text(l.chargeInUseNo),
                    selected: _inUse == false,
                    onSelected: (bool on) =>
                        setState(() => _inUse = on ? false : null),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.chargeInUseNote, style: context.type.bodySmall),
              if (yearly != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  l.chargeYearly(moneyText(yearly, base: base)),
                  style: context.type.bodyMedium,
                ),
                if (_inUse == false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l.chargeSaving(moneyText(yearly, base: base)),
                      style: context.type.bodyMedium?.copyWith(
                        color: context.colors.brand,
                      ),
                    ),
                  ),
              ],
            ],
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
            if (widget.charge case final RecurringCharge charge) ...<Widget>[
              TextButton.icon(
                onPressed: _saving ? null : _pause,
                icon: Icon(charge.active ? Glyph.pause : Glyph.play, size: 18),
                label: Text(charge.active ? l.chargePause : l.chargeResume),
              ),
              if (charge.active)
                Text(
                  l.chargePauseNote,
                  style: context.type.bodySmall,
                  textAlign: TextAlign.center,
                ),
              TextButton(
                onPressed: _saving ? null : _delete,
                child: Text(l.chargeDelete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
