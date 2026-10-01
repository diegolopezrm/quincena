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
import 'look.dart';

/// Records a movement, or edits [entry]. A transfer is edited as one move,
/// whichever of its legs was tapped.
Future<void> showEntrySheet(
  BuildContext context, {
  required OwnController own,
  Entry? entry,
  String? accountId,
}) {
  if (own.accounts.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.needAccountFirst)));
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext context) =>
        _EntryForm(own: own, entry: entry, accountId: accountId),
  );
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.own, this.entry, this.accountId});

  final OwnController own;
  final Entry? entry;
  final String? accountId;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  OwnController get own => widget.own;
  Entry? get _editing => widget.entry;

  /// Both legs of the transfer being edited: the one that left, the one
  /// that arrived.
  late final (Entry, Entry)? _legs = _findLegs();

  late EntryKind _kind = _editing?.kind == EntryKind.transfer
      ? EntryKind.transfer
      : (_editing == null || _editing!.amount < Decimal.zero)
      ? EntryKind.expense
      : EntryKind.income;

  late String _accountId =
      _legs?.$1.accountId ??
      _editing?.accountId ??
      widget.accountId ??
      own.accounts.first.id;
  late String? _toAccountId = _legs?.$2.accountId ?? _secondAccount();
  late final TextEditingController _amount = TextEditingController(
    text: _editing == null
        ? ''
        : _decimalText(
            _legs?.$1.amount ?? _editing!.amount,
            _assetOf(_accountId),
          ),
  );
  late final TextEditingController _received = TextEditingController(
    text: _legs == null
        ? ''
        : _decimalText(_legs.$2.amount, _assetOf(_legs.$2.accountId)),
  );
  late bool _receivedTouched = _legs != null;
  late final TextEditingController _payee = TextEditingController(
    text: _editing?.payee ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: _editing?.note ?? '',
  );
  late String? _category = _editing?.category;
  late DateTime _date = _editing?.date ?? own.today;
  String? _amountError;
  String? _accountError;
  bool _saving = false;

  (Entry, Entry)? _findLegs() {
    final Entry? e = _editing;
    if (e == null || e.transferId == null) return null;
    final List<Entry> legs = <Entry>[
      for (final Entry x in own.snapshot?.entries ?? const <Entry>[])
        if (x.transferId == e.transferId) x,
    ];
    if (legs.length != 2) return null;
    return legs[0].amount < Decimal.zero
        ? (legs[0], legs[1])
        : (legs[1], legs[0]);
  }

  String? _secondAccount() {
    for (final Account a in own.accounts) {
      if (a.id != (widget.accountId ?? own.accounts.first.id)) return a.id;
    }
    return null;
  }

  Asset _assetOf(String? id) {
    for (final Account a in own.accounts) {
      if (a.id == id) return a.asset;
    }
    return own.profile?.base ?? Asset.cop;
  }

  static String _decimalText(Decimal value, Asset asset) =>
      formatDecimal(value.abs(), decimals: asset.decimals, trim: true);

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _crossCurrency =>
      _kind == EntryKind.transfer &&
      _toAccountId != null &&
      _assetOf(_accountId) != _assetOf(_toAccountId);

  /// Fills what arrives with what the rates say, until the person types it.
  void _suggestReceived() {
    if (!_crossCurrency || _receivedTouched) return;
    final Decimal? sent = parseAmount(_amount.text);
    if (sent == null) return;
    final Money? converted = own.rates.convert(
      Money(sent, _assetOf(_accountId)),
      _assetOf(_toAccountId),
    );
    if (converted == null) return;
    _received.text = _decimalText(converted.amount, converted.asset);
  }

  DateTime _stamp(DateTime day) {
    final DateTime now = DateTime.now();
    final bool isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    return isToday
        ? DateTime(day.year, day.month, day.day, now.hour, now.minute)
        : DateTime(day.year, day.month, day.day, 12);
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Decimal? amount = parseAmount(_amount.text);
    final Decimal? received = _crossCurrency
        ? parseAmount(_received.text)
        : null;
    final bool badAmount = amount == null || amount <= Decimal.zero;
    final bool badAccounts =
        _kind == EntryKind.transfer &&
        (_toAccountId == null || _toAccountId == _accountId);
    setState(() {
      _amountError = badAmount ? l.invalidAmount : null;
      _accountError = badAccounts ? l.sameAccount : null;
    });
    if (badAmount || badAccounts || _saving) return;
    if (_crossCurrency && (received == null || received <= Decimal.zero)) {
      setState(() => _amountError = l.invalidAmount);
      return;
    }
    setState(() => _saving = true);
    final DateTime when = _stamp(_date);
    final String? category = _kind == EntryKind.transfer
        ? null
        : (_category ?? (_kind == EntryKind.income ? 'other_income' : 'other'));
    if (_kind == EntryKind.transfer) {
      final String? editingTransfer = _editing?.transferId;
      if (editingTransfer != null) {
        await own.store.updateTransfer(
          editingTransfer,
          fromAccountId: _accountId,
          toAccountId: _toAccountId!,
          sent: amount,
          received: received,
          date: when,
          note: _note.text,
        );
      } else {
        if (_editing != null) await own.store.deleteEntry(_editing!);
        await own.store.addTransfer(
          fromAccountId: _accountId,
          toAccountId: _toAccountId!,
          sent: amount,
          received: received,
          date: when,
          note: _note.text,
        );
      }
    } else if (_editing == null || _editing!.transferId != null) {
      if (_editing != null) await own.store.deleteEntry(_editing!);
      await own.store.addEntry(
        accountId: _accountId,
        amount: amount,
        kind: _kind,
        date: when,
        category: category,
        payee: _payee.text,
        note: _note.text,
      );
    } else {
      await own.store.updateEntry(
        _editing!.copyWith(
          accountId: _accountId,
          amount: _kind == EntryKind.expense ? -amount : amount,
          kind: _kind,
          date: when,
          category: category,
          payee: _payee.text,
          note: _note.text,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final AppLocalizations l = context.l10n;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.deleteMovementTitle),
        content: _editing!.transferId == null
            ? null
            : Text(l.deleteTransferBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await own.store.deleteEntry(_editing!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _newCategory() async {
    final AppLocalizations l = context.l10n;
    final TextEditingController name = TextEditingController();
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.newCategory),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.accountName),
          onSubmitted: (String v) => Navigator.of(context).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(name.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    name.dispose();
    if (typed == null || typed.trim().isEmpty) return;
    final CategoryItem created = await own.store.addCategory(
      typed,
      income: _kind == EntryKind.income,
    );
    setState(() => _category = created.key);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(own.today.year + 2, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _dateLabel(AppLocalizations l) {
    final DateTime today = own.today;
    final DateTime day = DateTime(_date.year, _date.month, _date.day);
    if (day == today) return l.today;
    if (day == today.subtract(const Duration(days: 1))) return l.yesterday;
    return shortDate(day);
  }

  Widget _accountField(
    String label,
    String? value,
    ValueChanged<String?> onChanged, {
    String? error,
  }) {
    return DropdownButtonFormField<String>(
      icon: const Icon(Glyph.caretDown, size: 18),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: error),
      items: <DropdownMenuItem<String>>[
        for (final Account a in own.accounts)
          DropdownMenuItem<String>(
            value: a.id,
            child: Row(
              children: <Widget>[
                Icon(
                  accountIcon(a.kind),
                  size: 18,
                  color: context.colors.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                Text(a.asset.code, style: context.type.labelSmall),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool transfer = _kind == EntryKind.transfer;
    final List<CategoryItem> categories = <CategoryItem>[
      for (final CategoryItem c in own.categories)
        if (!c.archived && c.income == (_kind == EntryKind.income)) c,
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
              _editing == null ? l.addMovement : l.editMovement,
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 16),
            SegmentedButton<EntryKind>(
              segments: <ButtonSegment<EntryKind>>[
                ButtonSegment<EntryKind>(
                  value: EntryKind.expense,
                  label: Text(l.kindExpense),
                ),
                ButtonSegment<EntryKind>(
                  value: EntryKind.income,
                  label: Text(l.kindIncome),
                ),
                if (own.accounts.length > 1)
                  ButtonSegment<EntryKind>(
                    value: EntryKind.transfer,
                    label: Text(l.kindTransfer),
                  ),
              ],
              selected: <EntryKind>{_kind},
              showSelectedIcon: false,
              onSelectionChanged: (Set<EntryKind> s) => setState(() {
                if (_kind != EntryKind.transfer &&
                    s.first != EntryKind.transfer &&
                    s.first != _kind) {
                  _category = null;
                }
                _kind = s.first;
                _toAccountId ??= _secondAccount();
                _suggestReceived();
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amount,
              autofocus: _editing == null,
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(
                  maxDecimals: _assetOf(_accountId).decimals,
                ),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: context.type.displaySmall,
              onChanged: (_) => setState(_suggestReceived),
              decoration: InputDecoration(
                labelText: l.amount,
                suffixText: _assetOf(_accountId).code,
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 16),
            _accountField(
              transfer ? l.fromAccount : l.account,
              _accountId,
              (String? id) => setState(() {
                if (id != null) _accountId = id;
                _suggestReceived();
              }),
            ),
            if (transfer) ...<Widget>[
              const SizedBox(height: 12),
              _accountField(
                l.toAccount,
                _toAccountId,
                (String? id) => setState(() {
                  _toAccountId = id;
                  _suggestReceived();
                }),
                error: _accountError,
              ),
              if (_crossCurrency) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _received,
                  inputFormatters: <TextInputFormatter>[
                    AmountInputFormatter(
                      maxDecimals: _assetOf(_toAccountId).decimals,
                    ),
                  ],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _receivedTouched = true,
                  decoration: InputDecoration(
                    labelText: l.received,
                    helperText: l.receivedHelp,
                    suffixText: _assetOf(_toAccountId).code,
                  ),
                ),
              ],
            ],
            if (!transfer) ...<Widget>[
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
                  ActionChip(
                    avatar: const Icon(Glyph.plus, size: 18),
                    label: Text(l.newCategory),
                    onPressed: _newCategory,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _payee,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _kind == EntryKind.income
                      ? l.payeeIncome
                      : l.payee,
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.date,
                  suffixIcon: const Icon(Glyph.calendarBlank, size: 20),
                ),
                child: Text(_dateLabel(l)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.note),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
            if (_editing != null) ...<Widget>[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.negative,
                ),
                icon: const Icon(Glyph.trash, size: 18),
                label: Text(l.delete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
