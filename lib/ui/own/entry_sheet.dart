import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_service.dart';
import '../../capture/inbox.dart';
import '../../data/ledger.dart';
import '../../domain/card_payment.dart';
import '../../domain/records.dart';
import '../../domain/shared.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/entry_guess.dart';
import '../../own/own_controller.dart';
import '../../own/undo.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import '../messages.dart';
import 'account_sheet.dart';
import 'amount_input.dart';
import 'capture_reasons.dart';
import 'category_choices.dart';
import 'entry_origin.dart';
import 'look.dart';
import 'split_sheet.dart';

/// What a new movement starts with, from what the app already knows: the
/// pay of a payday, a wish that was bought. Each part is only a start the
/// person can change.
@immutable
class EntryDraft {
  const EntryDraft({
    this.amount,
    this.payee,
    this.category,
    this.date,
    this.accountId,
    this.note,
  });

  /// In the account's own currency.
  final Decimal? amount;
  final String? payee;
  final String? category;
  final DateTime? date;
  final String? accountId;
  final String? note;
}

/// Opens the form for a movement, or for [entry] to change it. True once
/// it was saved.
///
/// A new one opens as [kind] when given, with [draft] filled in; without
/// either it starts by asking what happened. With no account yet, it
/// offers to add the first one, and opens in it once it is there.
Future<bool?> showEntrySheet(
  BuildContext context, {
  required OwnController own,
  Entry? entry,
  String? accountId,
  InboxItem? fromInbox,
  bool ownTransfer = false,
  EntryKind? kind,
  EntryDraft? draft,
}) async {
  String? into = accountId;
  if (own.accounts.isEmpty) {
    into = await _firstAccount(context, own);
    if (into == null || !context.mounted) return null;
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext context) => _EntryForm(
      own: own,
      entry: entry,
      accountId: into,
      fromInbox: fromInbox,
      ownTransfer: ownTransfer,
      kind: kind,
      draft: draft,
    ),
  );
}

/// Before any account there is nowhere for a movement to go: an offer to
/// add the first one instead of an error. The id of the account added, or
/// null when the person let it be.
Future<String?> _firstAccount(BuildContext context, OwnController own) async {
  final AppLocalizations l = context.l10n;
  final bool? add = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      scrollable: true,
      icon: Icon(Glyph.wallet, color: context.colors.brand),
      title: Text(l.entryNeedsAccountTitle),
      content: Text(l.entryNeedsAccountBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.firstAccountAction),
        ),
      ],
    ),
  );
  if (add != true || !context.mounted) return null;
  final Account? added = await showAccountSheet(context, own: own);
  if (added == null) return null;
  await _listed(own, added.id);
  return own.accounts.any((Account a) => a.id == added.id) ? added.id : null;
}

/// Waits, a moment at most, until [own] lists the account [id]: the store
/// tells it of the change a beat after saving.
Future<void> _listed(OwnController own, String id) async {
  bool there() => own.accounts.any((Account a) => a.id == id);
  if (there()) return;
  final Completer<void> listed = Completer<void>();
  void check() {
    if (there() && !listed.isCompleted) listed.complete();
  }

  own.addListener(check);
  try {
    await listed.future.timeout(const Duration(seconds: 3), onTimeout: () {});
  } finally {
    own.removeListener(check);
  }
}

/// Records a movement, or edits [entry]. A transfer is edited as one move,
/// whichever of its legs was tapped.
class _EntryForm extends StatefulWidget {
  const _EntryForm({
    required this.own,
    this.entry,
    this.accountId,
    this.fromInbox,
    this.ownTransfer = false,
    this.kind,
    this.draft,
  });

  final OwnController own;
  final Entry? entry;
  final String? accountId;

  /// What a new movement starts with.
  final EntryDraft? draft;

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

  /// A movement the person writes down now. It shows the amount and where
  /// it was, with the rest in a line until they open it; one being
  /// changed, or a capture being checked, shows every field it has.
  late final bool _new = _editing == null && _capture == null;

  /// Whether the form starts by asking what happened: a new movement
  /// opened without saying what kind it is.
  late final bool _asks = _new && widget.kind == null && widget.draft == null;

  /// Whether the form is asking what happened now.
  late bool _asking = _asks;

  /// Whether what happened is known: asked again, the answer given before
  /// is marked.
  late bool _answered = !_asks;

  /// Whether the account, the category, the day and the note show as
  /// fields: on a new movement they wait in a line until it is opened.
  late bool _more = !_new;

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

  /// What the person wrote down before says of a new movement: the
  /// account and the category of the last one with the same name, or else
  /// the account of the last time.
  EntryGuess _guess = const EntryGuess();

  /// Whether the person chose the account or the category themselves:
  /// what was written before no longer moves them. A category the draft
  /// brings counts as chosen.
  bool _accountChosen = false;
  late bool _categoryChosen = widget.draft?.category != null;

  /// Null for a capture the app could not place: the person chooses,
  /// since whatever account the form guessed would be learned from. A new
  /// movement's is placed from the start.
  late String? _accountId = _arrived
      ? _otherThan(_capture?.suggestion.accountId)
      : _legs?.$1.accountId ??
            _editing?.accountId ??
            _capture?.suggestion.accountId ??
            widget.accountId ??
            widget.draft?.accountId;
  late String? _toAccountId = _arrived
      ? (_capture?.suggestion.accountId ?? _secondAccount())
      : widget.ownTransfer
      ? _otherThan(_accountId)
      : _legs?.$2.accountId ?? _secondAccount();
  late final TextEditingController _amount = TextEditingController(
    text: _capture?.parsed.amount != null
        ? _decimalText(_capture!.parsed.amount!, _assetOf(_accountId))
        : _editing == null
        ? switch (widget.draft?.amount) {
            final Decimal amount => _decimalText(amount, _assetOf(_accountId)),
            null => '',
          }
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

  /// The currency the amount was written in. In an account of another
  /// one, chosen or guessed, the same number is another amount: the field
  /// says so until it is written again.
  late Asset _amountIn = _assetOf(_accountId);

  /// Whether the person typed what left: until then, money that arrived
  /// keeps what its alert says arrived.
  bool _amountTouched = false;
  late final TextEditingController _payee = TextEditingController(
    text:
        _editing?.payee ??
        _capture?.suggestion.payee ??
        widget.draft?.payee ??
        '',
  );
  final FocusNode _payeeFocus = FocusNode();
  late final TextEditingController _note = TextEditingController(
    text: _editing?.note ?? widget.draft?.note ?? '',
  );
  late String? _category =
      _editing?.category ??
      _capture?.suggestion.category ??
      widget.draft?.category;
  late DateTime _date =
      _editing?.date ??
      _capture?.parsed.when ??
      _capture?.event.at ??
      widget.draft?.date ??
      own.today;

  /// The hour it happened, when it is known, as a notice's or a saved
  /// movement's, or the person set it. Null otherwise: then today is now
  /// and another day noon.
  late TimeOfDay? _time = switch (_editing?.date ??
      _capture?.parsed.when ??
      _capture?.event.at) {
    final DateTime had => TimeOfDay.fromDateTime(had),
    null => null,
  };
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

  /// The account a new movement starts in when nothing says another: the
  /// first to spend from in the currency of the totals.
  String _mainAccount() {
    final Asset base = own.profile?.base ?? Asset.cop;
    return (own.accounts
                .where((Account a) => a.spendable && a.asset == base)
                .firstOrNull ??
            own.accounts.where((Account a) => a.spendable).firstOrNull ??
            own.accounts.first)
        .id;
  }

  Asset _assetOf(String? id) =>
      (id == null ? null : own.snapshot?.account(id))?.asset ??
      own.profile?.base ??
      Asset.cop;

  /// The accounts to choose from, and the archived one a movement being
  /// changed is in, so it opens where it is.
  List<Account> _choices(String? value) => <Account>[
    ...own.accounts,
    if (value != null && !own.accounts.any((Account a) => a.id == value))
      ?own.snapshot?.account(value),
  ];

  static String _decimalText(Decimal value, Asset asset) =>
      formatDecimal(value.abs(), decimals: asset.decimals, trim: true);

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _payee.dispose();
    _payeeFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _crossCurrency =>
      _kind == EntryKind.transfer &&
      _toAccountId != null &&
      _assetOf(_accountId) != _assetOf(_toAccountId);

  @override
  void initState() {
    super.initState();
    _rethink();
    if (_arrived) _suggestReceived();
  }

  /// For a new movement, what was written before: the account and the
  /// category of the last one with the same name, or the account of the
  /// last time, for those the person has not chosen.
  void _rethink() {
    if (!_new) return;
    _guess = guessEntry(
      entries: own.snapshot?.entries ?? const <Entry>[],
      accounts: own.accounts,
      kind: _kind,
      payee: _payee.text,
      today: own.today,
      learned: own.captureSettings.merchantCategories,
    );
    if (_kind != EntryKind.transfer && !_categoryChosen) {
      _category = _guess.category;
    }
    _placeAccounts();
  }

  /// Puts a new movement in the account it most likely is, while the
  /// person has not chosen one: the one it was opened from or the draft
  /// brings, or else the one its name or the last time says.
  void _placeAccounts() {
    if (_accountChosen) return;
    final String? given = widget.accountId ?? widget.draft?.accountId;
    final Account? page = given == null ? null : own.snapshot?.account(given);
    if (_kind == EntryKind.transfer && page?.kind == AccountKind.card) {
      // From a card's own page, a move is most likely its payment: into
      // it, from where payments usually come.
      _toAccountId = page!.id;
      _accountId = own.likelyPaymentAccount?.id ?? _otherThan(page.id);
      return;
    }
    _accountId =
        given ??
        (_kind == EntryKind.transfer ? null : _guess.accountId) ??
        _mainAccount();
    if (_toAccountId == null || _toAccountId == _accountId) {
      _toAccountId = _kind == EntryKind.transfer
          ? _otherThan(_accountId)
          : _secondAccount();
    }
  }

  /// Fills what arrives with what the rates say, until the person types it.
  /// Money that arrived says how much arrived, in the account it arrived
  /// in: across currencies that is what arrives, and what left is worked
  /// back from the rates.
  void _suggestReceived() {
    final Decimal? arrived = _arrived && !_amountTouched
        ? _capture?.parsed.amount
        : null;
    if (arrived != null) {
      final Asset from = _assetOf(_accountId);
      _amountIn = from;
      if (!_crossCurrency) {
        _amount.text = _decimalText(arrived, from);
        return;
      }
      final Asset to = _assetOf(_toAccountId);
      _received.text = _decimalText(arrived, to);
      _receivedTouched = true;
      final Money? left = own.rates.convert(Money(arrived, to), from);
      if (left != null) {
        _amount.text = _decimalText(
          left.amount.round(scale: from.decimals),
          from,
        );
      }
      return;
    }
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

  /// Another kind of movement: what was chosen for the other kind does not
  /// carry over, and a new one takes what was written before for this
  /// kind.
  void _switchKind(EntryKind kind) {
    if (_kind != EntryKind.transfer &&
        kind != EntryKind.transfer &&
        kind != _kind) {
      _category = null;
      _categoryChosen = false;
    }
    _kind = kind;
    _toAccountId ??= _secondAccount();
    _rethink();
    _suggestReceived();
  }

  /// What happened, answered: the form for it, with the amount to type.
  void _answer(EntryKind kind) => setState(() {
    _asking = false;
    _answered = true;
    _switchKind(kind);
  });

  /// Where the money went or came from, picked from the usual ones: said,
  /// the keyboard goes and the rest shows, to save.
  void _pickPayee(String name) {
    _payee.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    setState(_rethink);
  }

  DateTime _stamp(DateTime day) {
    final DateTime now = DateTime.now();
    final bool isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    return isToday
        ? DateTime(day.year, day.month, day.day, now.hour, now.minute)
        : DateTime(day.year, day.month, day.day, 12);
  }

  /// When the movement happened: its day at the hour it has, or else what
  /// [_stamp] gives the day picked.
  DateTime _when() => switch (_time) {
    final TimeOfDay t => DateTime(
      _date.year,
      _date.month,
      _date.day,
      t.hour,
      t.minute,
    ),
    null => _stamp(_date),
  };

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
    final (Group, SharedExpense)? split = _editing == null
        ? null
        : own.splitOf(_editing!.id);
    // No longer an expense, it leaves its split behind: said first, as
    // deleting it says it.
    if (split != null && _kind != EntryKind.expense) {
      final bool? sure = await _askLeaveSplit();
      if (sure != true || !mounted) return;
    }
    // Paying a card written as an expense would count what was bought on
    // it twice: asked first, it becomes a payment between the accounts.
    if (_kind == EntryKind.expense && _editing == null && _capture == null) {
      final bool? toCard = await _askCardPayment(from, amount);
      if (toCard == null || !mounted) return;
      if (toCard) {
        setState(() => _saving = true);
        await own.store.addTransfer(
          fromAccountId: from,
          toAccountId: _cardPaid!.id,
          sent: amount,
          date: _when(),
          note: _note.text,
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
    }
    setState(() => _saving = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final DateTime when = _when();
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
        note: _note.text,
      );
      showRecorded(messenger, own, done);
      if (mounted) Navigator.of(context).pop(true);
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
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Whether a split expense is to be saved as something else, which takes
  /// its split away: what the others owe for it stops counting.
  Future<bool?> _askLeaveSplit() {
    final AppLocalizations l = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.kindChangeSplitTitle),
        content: Text(l.deleteSplitBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.kindChangeSplitYes),
          ),
        ],
      ),
    );
  }

  /// The card the expense being saved looks like a payment to, when the
  /// person was asked about it.
  Account? _cardPaid;

  /// Whether the expense is a card's payment, when it looks like one: true
  /// to save it as a payment to the card, false to keep it an expense, and
  /// null when the person closed the question to keep editing. False when
  /// it does not look like one.
  Future<bool?> _askCardPayment(String from, Decimal amount) async {
    final Account? source = own.snapshot?.account(from);
    final Account? card = cardPaidBy(
      '${_payee.text} ${_note.text}',
      _category,
      accounts: own.accounts,
      owed: <String, num>{
        for (final MapEntry<String, Money> b in own.balances.entries)
          if (b.value.isNegative) b.key: -b.value.amount.toDouble(),
      },
    );
    // A card in another currency, or the card paying itself, is no
    // payment this form can write.
    if (card == null ||
        source == null ||
        card.id == from ||
        card.asset != source.asset) {
      return false;
    }
    _cardPaid = card;
    final AppLocalizations l = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.cardPaymentTitle(card.name)),
        content: Text(
          l.cardPaymentBody(
            source.name,
            card.name,
            moneyText(Money(amount, source.asset), base: own.profile?.base),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cardPaymentNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.cardPaymentYes),
          ),
        ],
      ),
    );
  }

  /// [amount] held in the account [accountId], in the ledger's smallest
  /// unit of the base currency; null without a rate for it.
  int? _inBase(Decimal amount, String accountId) {
    final Money? money = own.inBase(Money(amount, _assetOf(accountId)));
    final Ledger? ledger = own.ledger;
    if (money == null || ledger == null) return null;
    return ledger.minor(money.amount.toDouble());
  }

  /// Deletes the movement, both legs of a transfer, and its split, and
  /// offers for a few seconds to put all of it back as it was.
  Future<void> _delete() async {
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Entry entry = _editing!;
    final String said = entry.transferId != null
        ? l.transferDeleted
        : own.splitOf(entry.id) != null
        ? l.entrySplitDeleted
        : l.entryDeleted;
    final Undo back = await own.deleteMovement(entry);
    if (mounted) Navigator.of(context).pop();
    showUndo(messenger, said, back);
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

  Future<void> _pickTime() async {
    final bool today = DateUtils.isSameDay(_date, DateTime.now());
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          _time ??
          (today ? TimeOfDay.now() : const TimeOfDay(hour: 12, minute: 0)),
    );
    if (picked != null) setState(() => _time = picked);
  }

  /// The hour as it will be saved: the one it has, «Ahora» for one of
  /// today without one, or noon.
  String _timeLabel(AppLocalizations l) => switch (_time) {
    final TimeOfDay t => timeOfDay(DateTime(2000, 1, 1, t.hour, t.minute)),
    null when DateUtils.isSameDay(_date, own.today) => l.entryTimeNow,
    null => timeOfDay(DateTime(2000, 1, 1, 12)),
  };

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
      // Placed again by a guess, the field shows the new account.
      key: ValueKey<String?>('$label $value'),
      icon: const Icon(Glyph.caretDown, size: 18),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: error),
      items: <DropdownMenuItem<String>>[
        for (final Account a in _choices(value))
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

  /// What each kind of movement is, as a person says it happened.
  (IconData, String, String) _said(AppLocalizations l, EntryKind kind) =>
      switch (kind) {
        EntryKind.income => (Glyph.handCoins, l.entryGot, l.entryGotBody),
        EntryKind.transfer => (
          Glyph.arrowsLeftRight,
          l.entryMoved,
          l.entryMovedBody,
        ),
        _ => (Glyph.shoppingBag, l.entrySpent, l.entrySpentBody),
      };

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
          children: _asking ? _question(l) : _form(l),
        ),
      ),
    );
  }

  /// «¿Qué pasó?»: the movement starts by what happened, not by its kind.
  /// Moving money takes two accounts, so it is offered once there are.
  List<Widget> _question(AppLocalizations l) => <Widget>[
    Text(l.entryWhatHappened, style: context.type.headlineMedium),
    const SizedBox(height: 16),
    for (final EntryKind kind in <EntryKind>[
      EntryKind.expense,
      EntryKind.income,
      if (own.accounts.length > 1) EntryKind.transfer,
    ]) ...<Widget>[
      _Answer(
        said: _said(l, kind),
        selected: _answered && kind == _kind,
        onTap: () => _answer(kind),
      ),
      const SizedBox(height: 10),
    ],
  ];

  List<Widget> _form(AppLocalizations l) {
    final bool transfer = _kind == EntryKind.transfer;
    final bool income = _kind == EntryKind.income;
    final double scale = MediaQuery.textScalerOf(context).scale(48);
    return <Widget>[
      if (_new)
        _KindTitle(
          said: _said(l, _kind),
          tooltip: l.entryChangeKind,
          onTap: () => setState(() => _asking = true),
        )
      else ...<Widget>[
        Text(
          _editing != null ? l.editMovement : l.reviewMovement,
          style: context.type.headlineMedium,
        ),
        if (_editing case final Entry e) EntryOrigin(own: own, entry: e),
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
          onSelectionChanged: (Set<EntryKind> s) =>
              setState(() => _switchKind(s.first)),
        ),
      ],
      const SizedBox(height: 20),
      TextField(
        controller: _amount,
        // A draft with its amount is there to be confirmed, not typed.
        autofocus: _editing == null && widget.draft?.amount == null,
        inputFormatters: <TextInputFormatter>[
          AmountInputFormatter(maxDecimals: _assetOf(_accountId).decimals),
        ],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // On a new expense or income, where it was comes next.
        textInputAction: _new && !transfer
            ? TextInputAction.next
            : TextInputAction.done,
        onSubmitted: _new && !transfer
            ? (_) => _payeeFocus.requestFocus()
            : null,
        style: context.type.displaySmall,
        // What saving said of the amount no longer holds.
        onChanged: (_) => setState(() {
          _amountTouched = true;
          _amountError = null;
          _amountIn = _assetOf(_accountId);
          _suggestReceived();
        }),
        decoration: InputDecoration(
          labelText: l.amount,
          suffixText: _assetOf(_accountId).code,
          helperText:
              _amount.text.trim().isEmpty || _amountIn == _assetOf(_accountId)
              ? null
              : l.entryCurrencyChanged(
                  _amountIn.code,
                  _assetOf(_accountId).code,
                ),
          helperMaxLines: 2,
          errorText: _amountError,
        ),
      ),
      if (_new) ...<Widget>[
        if (transfer)
          ..._accounts(l)
        else ...<Widget>[
          const SizedBox(height: 16),
          _payeeField(l, scrollPadding: _payeeRoom(scale)),
          _usual(),
        ],
        if (_more) ...<Widget>[
          if (!transfer) ..._accounts(l),
          if (!transfer) ..._categories(l, income: income),
          ..._dayAndNote(l, scale),
        ] else ...<Widget>[const SizedBox(height: 16), _summary(l)],
      ] else ...<Widget>[
        ..._accounts(l),
        if (!transfer) ...<Widget>[
          ..._categories(l, income: income),
          const SizedBox(height: 16),
          _payeeField(l),
        ],
        ..._dayAndNote(l, scale),
      ],
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
          style: TextButton.styleFrom(foregroundColor: context.colors.negative),
          icon: const Icon(Glyph.trash, size: 18),
          label: Text(l.delete),
        ),
      ],
    ];
  }

  /// The account it is in, or the two a move goes between, and what
  /// arrived when they are in different currencies.
  List<Widget> _accounts(AppLocalizations l) {
    final bool transfer = _kind == EntryKind.transfer;
    return <Widget>[
      const SizedBox(height: 16),
      _accountField(
        transfer ? l.fromAccount : l.account,
        _accountId,
        (String? id) => setState(() {
          if (id != null) _accountId = id;
          _accountChosen = true;
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
            _accountChosen = true;
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    ];
  }

  List<Widget> _categories(AppLocalizations l, {required bool income}) =>
      <Widget>[
        const SizedBox(height: 20),
        Text(l.category, style: context.type.labelMedium),
        const SizedBox(height: 8),
        // A category made from here shows once the store says it is there,
        // which may be after the form chose it.
        ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) => CategoryChoices(
            own: own,
            income: income,
            selected: _category,
            onChanged: (String? key) => setState(() {
              _category = key;
              _categoryChosen = true;
            }),
          ),
        ),
      ];

  /// Room under the field where a new movement's name is typed, for what
  /// comes after it to come above the keyboard with it: the usual names,
  /// the line with the rest and the button that saves. Never more than half
  /// of what the keyboard leaves, so the field itself stays in sight.
  EdgeInsets _payeeRoom(double scale) {
    final double left =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return EdgeInsets.fromLTRB(20, 20, 20, math.min(120 + 3 * scale, left / 2));
  }

  Widget _payeeField(
    AppLocalizations l, {
    EdgeInsets scrollPadding = const EdgeInsets.all(20),
  }) => TextField(
    controller: _payee,
    focusNode: _payeeFocus,
    textCapitalization: TextCapitalization.sentences,
    scrollPadding: scrollPadding,
    // On a new movement the name says the rest: the account and the
    // category of the last time it was used.
    onChanged: _new ? (_) => setState(_rethink) : null,
    decoration: InputDecoration(
      labelText: _kind == EntryKind.income ? l.payeeIncome : l.payee,
    ),
  );

  /// The names this kind of movement went to or came from most lately, to
  /// pick instead of typing; as the field fills, those that fit it.
  Widget _usual() {
    final List<String> names = usualPayees(
      entries: own.snapshot?.entries ?? const <Entry>[],
      kind: _kind,
      today: own.today,
      typed: _payee.text,
    );
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final String name in names)
            ActionChip(label: Text(name), onPressed: () => _pickPayee(name)),
        ],
      ),
    );
  }

  List<Widget> _dayAndNote(AppLocalizations l, double scale) {
    final Widget day = InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l.date,
          suffixIcon: const Icon(Glyph.calendarBlank, size: 20),
        ),
        child: Text(_dateLabel(l)),
      ),
    );
    final Widget hour = InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l.entryTime,
          suffixIcon: const Icon(Glyph.clock, size: 20),
        ),
        child: Text(_timeLabel(l)),
      ),
    );
    return <Widget>[
      const SizedBox(height: 12),
      // With large text the hour goes under the day.
      if (largeText(context)) ...<Widget>[
        day,
        const SizedBox(height: 12),
        hour,
      ] else
        Row(
          children: <Widget>[
            Expanded(flex: 3, child: day),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: hour),
          ],
        ),
      ..._noteField(l, scale),
    ];
  }

  List<Widget> _noteField(AppLocalizations l, double scale) => <Widget>[
    const SizedBox(height: 12),
    TextField(
      controller: _note,
      textCapitalization: TextCapitalization.sentences,
      // The last field: the button that saves comes above the keyboard
      // with it.
      scrollPadding: EdgeInsets.fromLTRB(20, 20, 20, 40 + scale),
      decoration: InputDecoration(labelText: l.note),
    ),
  ];

  /// The rest of a new movement in a line, as it will be saved: its
  /// category, its account and its day, or only the day for a move. Under
  /// it, that they repeat the last time, when the name was seen before, or
  /// where it goes with no category. «Cambiar» opens each as a field.
  Widget _summary(AppLocalizations l) {
    final bool transfer = _kind == EntryKind.transfer;
    final bool income = _kind == EntryKind.income;
    final String fallback = income ? 'other_income' : 'other';
    final String? account = _accountId == null
        ? null
        : own.snapshot?.account(_accountId!)?.name;
    final String line = <String>[
      if (!transfer)
        _category == null
            ? l.entryNoCategory
            : categoryNameFor(context, _category!, own.categories),
      if (!transfer && account != null) account,
      _dateLabel(l),
    ].join(' · ');
    final Entry? like = _guess.like;
    final String? why = transfer
        ? null
        : like != null &&
              like.category == _category &&
              like.accountId == _accountId
        ? l.entryLikeLastTime(income ? 'income' : 'other', _payee.text.trim())
        : _category == null
        ? l.entryStaysIn(categoryNameFor(context, fallback, own.categories))
        : null;
    final String note = _note.text.trim();
    final Widget said = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(line, style: context.type.titleSmall),
        if (note.isNotEmpty) Text(note, style: context.type.bodySmall),
        if (why != null) Text(why, style: context.type.bodySmall),
      ],
    );
    final Widget change = TextButton(
      onPressed: () => setState(() => _more = true),
      child: Text(l.entryChange),
    );
    return Block(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      // With large text what changes it goes under what it says.
      child: largeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[said, change],
            )
          : Row(
              children: <Widget>[
                if (transfer)
                  Icon(
                    Glyph.calendarBlank,
                    size: 22,
                    color: context.colors.inkSoft,
                  )
                else
                  CategoryDisc(_category ?? fallback, size: 32),
                const SizedBox(width: 12),
                Expanded(child: said),
                change,
              ],
            ),
    );
  }
}

/// One answer to «¿Qué pasó?»: what happened, and the cases it covers.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.said,
    required this.selected,
    required this.onTap,
  });

  final (IconData, String, String) said;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String body) = said;
    return Material(
      color: selected ? context.colors.brandSoft : context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? context.colors.brand : context.colors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: context.colors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: context.type.titleMedium),
                    const SizedBox(height: 2),
                    Text(body, style: context.type.bodySmall),
                  ],
                ),
              ),
              Icon(Glyph.caretRight, size: 18, color: context.colors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// What happened, as the title of a new movement, and the way back to the
/// question to answer it otherwise.
class _KindTitle extends StatelessWidget {
  const _KindTitle({
    required this.said,
    required this.tooltip,
    required this.onTap,
  });

  final (IconData, String, String) said;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, _) = said;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 24, color: context.colors.brand),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(title, style: context.type.headlineMedium),
                ),
                const SizedBox(width: 6),
                Icon(Glyph.caretDown, size: 20, color: context.colors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
