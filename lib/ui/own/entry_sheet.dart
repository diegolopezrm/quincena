import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_service.dart';
import '../../capture/inbox.dart';
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
import 'capture_reasons.dart';
import 'category_choices.dart';
import 'look.dart';
import 'split_sheet.dart';

/// Records a movement, or edits [entry]. A transfer is edited as one move,
/// whichever of its legs was tapped. A new one opens as [kind] when given.
Future<void> showEntrySheet(
  BuildContext context, {
  required OwnController own,
  Entry? entry,
  String? accountId,
  InboxItem? fromInbox,
  bool ownTransfer = false,
  EntryKind? kind,
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
    builder: (BuildContext context) => _EntryForm(
      own: own,
      entry: entry,
      accountId: accountId,
      fromInbox: fromInbox,
      ownTransfer: ownTransfer,
      kind: kind,
    ),
  );
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({
    required this.own,
    this.entry,
    this.accountId,
    this.fromInbox,
    this.ownTransfer = false,
    this.kind,
  });

  final OwnController own;
  final Entry? entry;
  final String? accountId;

  /// A capture being confirmed: its reading fills the form, and saving it
  /// records it through the inbox, so the app learns from what changed.
  final InboxItem? fromInbox;

  /// [fromInbox] is money the person moved between their own accounts: the
  /// form opens as a transfer, with the capture's account on its side,
  /// where the money arrived for an income and where it left otherwise.
  /// Recorded that way, it is neither income nor spending.
  final bool ownTransfer;

  /// What a new movement starts as: an income for the pay that has not
  /// shown up yet.
  final EntryKind? kind;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  OwnController get own => widget.own;
  Entry? get _editing => widget.entry;

  /// Both legs of the transfer being edited: the one that left, the one
  /// that arrived.
  late final (Entry, Entry)? _legs = _findLegs();

  InboxItem? get _capture => widget.fromInbox;

  late EntryKind _kind = widget.ownTransfer
      ? EntryKind.transfer
      : _capture != null
      ? (_capture!.parsed.kind ?? EntryKind.expense)
      : _editing?.kind == EntryKind.transfer
      ? EntryKind.transfer
      : _editing == null && widget.kind != null
      ? widget.kind!
      : (_editing == null || _editing!.amount < Decimal.zero)
      ? EntryKind.expense
      : EntryKind.income;

  /// An income moved in from another of the person's accounts arrived in
  /// the capture's account: that one is where the transfer goes.
  late final bool _arrived =
      widget.ownTransfer && _capture?.parsed.kind == EntryKind.income;

  /// Null for a capture the app could not place: the person chooses,
  /// since whatever account the form guessed would be learned from.
  late String? _accountId = _arrived
      ? _otherThan(_capture?.suggestion.accountId)
      : _legs?.$1.accountId ??
            _editing?.accountId ??
            _capture?.suggestion.accountId ??
            widget.accountId ??
            (_capture == null ? own.accounts.first.id : null);
  late String? _toAccountId = _arrived
      ? (_capture?.suggestion.accountId ?? _secondAccount())
      : widget.ownTransfer
      ? _otherThan(_accountId)
      : _legs?.$2.accountId ?? _secondAccount();
  late final TextEditingController _amount = TextEditingController(
    text: _capture?.parsed.amount != null
        ? _decimalText(_capture!.parsed.amount!, _assetOf(_accountId))
        : _editing == null
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
    text: _editing?.payee ?? _capture?.suggestion.payee ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: _editing?.note ?? '',
  );
  late String? _category = _editing?.category ?? _capture?.suggestion.category;
  late DateTime _date =
      _editing?.date ??
      _capture?.parsed.when ??
      _capture?.event.at ??
      own.today;
  String? _amountError;
  String? _receivedError;
  String? _fromError;
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

  /// Another account than [id], one to spend from if there is one.
  String _otherThan(String? id) {
    final List<Account> others = <Account>[
      for (final Account a in own.accounts)
        if (a.id != id) a,
    ];
    if (others.isEmpty) return own.accounts.first.id;
    return (others.where((Account a) => a.spendable).firstOrNull ??
            others.first)
        .id;
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
    _receivedError = null;
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
    final String? from = _accountId;
    final bool badAccounts =
        _kind == EntryKind.transfer &&
        (_toAccountId == null || _toAccountId == _accountId);
    // Between currencies, what arrived is said apart, under its own field.
    final bool badReceived =
        _crossCurrency && (received == null || received <= Decimal.zero);
    setState(() {
      _amountError = badAmount ? l.invalidAmount : null;
      _fromError = from == null ? l.accountRequired : null;
      _accountError = badAccounts ? l.sameAccount : null;
      _receivedError = badReceived ? l.invalidAmount : null;
    });
    if (badAmount || from == null || badAccounts || badReceived || _saving) {
      return;
    }
    setState(() => _saving = true);
    final (Group, SharedExpense)? split = _editing == null
        ? null
        : own.splitOf(_editing!.id);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final DateTime when = _stamp(_date);
    final String? category = _kind == EntryKind.transfer
        ? null
        : (_category ?? (_kind == EntryKind.income ? 'other_income' : 'other'));
    final InboxItem? capture = _capture;
    if (capture != null && _kind != EntryKind.transfer) {
      final Accepted done = await own.capture.accept(
        capture,
        accountId: from,
        category: category,
        payee: _payee.text,
        amount: amount,
        kind: _kind,
        date: when,
      );
      showRecorded(messenger, own, done);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_kind == EntryKind.transfer) {
      final String? editingTransfer = _editing?.transferId;
      if (editingTransfer != null) {
        await own.store.updateTransfer(
          editingTransfer,
          fromAccountId: from,
          toAccountId: _toAccountId!,
          sent: amount,
          received: received,
          date: when,
          note: _note.text,
        );
      } else {
        if (_editing != null) await own.store.deleteEntry(_editing!);
        if (capture != null) {
          showRecorded(
            messenger,
            own,
            await own.capture.acceptTransfer(
              capture,
              fromAccountId: from,
              toAccountId: _toAccountId!,
              sent: amount,
              received: received,
              date: when,
              note: _note.text,
            ),
          );
        } else {
          await own.store.addTransfer(
            fromAccountId: from,
            toAccountId: _toAccountId!,
            sent: amount,
            received: received,
            date: when,
            note: _note.text,
          );
        }
      }
    } else if (_editing == null || _editing!.transferId != null) {
      if (_editing != null) await own.store.deleteEntry(_editing!);
      await own.store.addEntry(
        accountId: from,
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
          accountId: from,
          amount: _kind == EntryKind.expense ? -amount : amount,
          kind: _kind,
          date: when,
          category: category,
          payee: _payee.text,
          note: _note.text,
        ),
      );
    }
    // A split belongs to an expense: one that is no longer an expense
    // takes it along, or the others would still owe for it; one whose
    // amount was put right is split again at the new amount.
    if (split case (final Group group, final SharedExpense expense)) {
      if (_kind != EntryKind.expense) {
        await own.saveGroup(group.withoutExpense(expense.id));
      } else if (_inBase(amount, from) case final int total) {
        await own.saveGroup(group.withExpense(expense.resizedTo(total)));
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// [amount] held in the account [accountId], in the ledger's smallest
  /// unit of the base currency; null without a rate for it.
  int? _inBase(Decimal amount, String accountId) {
    final Money? money = own.inBase(Money(amount, _assetOf(accountId)));
    final Ledger? ledger = own.ledger;
    if (money == null || ledger == null) return null;
    return ledger.minor(money.amount.toDouble());
  }

  Future<void> _delete() async {
    final AppLocalizations l = context.l10n;
    final (Group, SharedExpense)? split = own.splitOf(_editing!.id);
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.deleteMovementTitle),
        content: _editing!.transferId != null
            ? Text(l.deleteTransferBody)
            : split != null
            ? Text(l.deleteSplitBody)
            : null,
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
    // The split goes with what was split: no one owes for a deleted one.
    if (split case (final Group group, final SharedExpense expense)) {
      await own.saveGroup(group.withoutExpense(expense.id));
    }
    if (mounted) Navigator.of(context).pop();
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _editing != null
                  ? l.editMovement
                  : _capture != null
                  ? l.reviewMovement
                  : l.addMovement,
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
              // With large text one kind under the other, each word whole.
              direction: largeText(context) ? Axis.vertical : Axis.horizontal,
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
              // What saving said of the amount no longer holds.
              onChanged: (_) => setState(() {
                _amountError = null;
                _suggestReceived();
              }),
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
                _fromError = null;
                _accountError = null;
                _suggestReceived();
              }),
              error: _fromError,
            ),
            if (transfer) ...<Widget>[
              const SizedBox(height: 12),
              _accountField(
                l.toAccount,
                _toAccountId,
                (String? id) => setState(() {
                  _toAccountId = id;
                  _accountError = null;
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
                  onChanged: (_) => setState(() {
                    _receivedTouched = true;
                    _receivedError = null;
                  }),
                  decoration: InputDecoration(
                    labelText: l.received,
                    helperText: l.receivedHelp,
                    suffixText: _assetOf(_toAccountId).code,
                    errorText: _receivedError,
                  ),
                ),
              ],
            ],
            if (!transfer) ...<Widget>[
              const SizedBox(height: 20),
              Text(l.category, style: context.type.labelMedium),
              const SizedBox(height: 8),
              CategoryChoices(
                own: own,
                income: _kind == EntryKind.income,
                selected: _category,
                onChanged: (String? key) => setState(() => _category = key),
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
              // The last field: the button that saves comes above the
              // keyboard with it.
              scrollPadding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                40 + MediaQuery.textScalerOf(context).scale(48),
              ),
              decoration: InputDecoration(labelText: l.note),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _capture == null
                    ? l.save
                    : switch (_kind) {
                        EntryKind.income => l.recordIncome,
                        EntryKind.transfer => l.recordTransfer,
                        _ => l.recordExpense,
                      },
              ),
            ),
            // Only while it is still an expense: switched to another kind,
            // there is nothing to split.
            if (_editing case final Entry editing
                when editing.kind == EntryKind.expense &&
                    _kind == EntryKind.expense &&
                    !editing.isTrade &&
                    !editing.isTransfer) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  // The split opens over the page this sheet came from.
                  final NavigatorState navigator = Navigator.of(context)..pop();
                  showSplitSheet(navigator.context, own: own, entry: editing);
                },
                icon: const Icon(Glyph.usersThree, size: 18),
                label: Text(
                  own.splitOf(editing.id) == null ? l.splitThis : l.splitChange,
                ),
              ),
            ],
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
