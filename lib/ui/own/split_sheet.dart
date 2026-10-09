import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/records.dart';
import '../../domain/shared.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'amount_input.dart';
import 'coming_days_page.dart' show listOf;

/// A member's name for the screen: "Tú" for the person.
String memberName(AppLocalizations l, Member? m) =>
    m == null ? '' : (m.isMe ? l.sharedYou : m.name);

/// Names typed apart by commas, each once, in the order typed.
List<String> namesIn(String text) {
  final List<String> out = <String>[];
  for (final String raw in text.split(',')) {
    final String name = raw.trim();
    if (name.isEmpty) continue;
    if (out.any((String n) => n.toLowerCase() == name.toLowerCase())) continue;
    out.add(name);
  }
  return out;
}

/// Splits an expense in [group], or the movement [entry] the person paid,
/// or changes [expense]. With neither group nor an existing split, the
/// people are typed by name and a group is made for them, named
/// [groupName] when there is one to suggest. The group it was saved in
/// once saved.
Future<Group?> showSplitSheet(
  BuildContext context, {
  required OwnController own,
  Group? group,
  SharedExpense? expense,
  Entry? entry,
  String? groupName,
}) => showModalBottomSheet<Group>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) => _SplitSheet(
    own: own,
    group: group,
    expense: expense,
    entry: entry,
    groupName: groupName,
  ),
);

class _SplitSheet extends StatefulWidget {
  const _SplitSheet({
    required this.own,
    this.group,
    this.expense,
    this.entry,
    this.groupName,
  });

  final OwnController own;
  final Group? group;
  final SharedExpense? expense;
  final Entry? entry;
  final String? groupName;

  @override
  State<_SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<_SplitSheet> {
  OwnController get own => widget.own;
  Ledger? get _ledger => own.ledger;
  late final Asset _base = own.profile?.base ?? Asset.cop;

  /// The group it goes to; null makes a new one from [_names].
  late Group? _group = widget.group;
  late final TextEditingController _groupName = TextEditingController(
    text: widget.groupName ?? '',
  );
  final TextEditingController _names = TextEditingController();
  late final TextEditingController _label = TextEditingController(
    text: widget.expense?.label ?? widget.entry?.payee ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: _initialAmount(),
  );
  late DateTime _date = widget.expense?.date ?? widget.entry?.date ?? own.today;
  late String _paidBy = widget.expense?.paidBy ?? meId;

  /// The account a new expense the person paid went out of: the one it
  /// most likely did comes chosen; null for none in Quincena.
  late String? _accountId = widget.own.likelyPaymentAccount?.id;

  /// Whether this is an expense not written down anywhere yet.
  bool get _new => widget.entry == null && widget.expense == null;
  late bool _even = widget.expense == null || _isEven(widget.expense!);
  late final Set<String> _in = <String>{...?widget.expense?.shares.keys};
  final Map<String, TextEditingController> _custom =
      <String, TextEditingController>{};
  String? _error;

  /// The movement's amount in the base currency, which is what is split.
  int? get _entryAmount {
    final Entry? e = widget.entry;
    final Ledger? l = _ledger;
    if (e == null || l == null) return null;
    final Account? a = own.snapshot?.account(e.accountId);
    if (a == null) return null;
    final Money? m = own.inBase(Money(e.amount.abs(), a.asset));
    return m == null ? null : l.minor(m.amount.toDouble());
  }

  String _initialAmount() {
    final int? amount = widget.expense?.amount ?? _entryAmount;
    return amount == null ? '' : _format(amount);
  }

  String _format(int minor) => formatDecimal(
    Decimal.parse('${_ledger?.major(minor) ?? minor}'),
    decimals: _base.decimals,
    trim: true,
  );

  static bool _isEven(SharedExpense e) {
    final List<int> parts = e.shares.values.toList();
    if (parts.isEmpty) return true;
    final int high = parts.reduce((int a, int b) => a > b ? a : b);
    final int low = parts.reduce((int a, int b) => a < b ? a : b);
    return high - low <= 1;
  }

  @override
  void initState() {
    super.initState();
    SharedExpense? existing = widget.expense;
    if (widget.entry case final Entry e) {
      if (own.splitOf(e.id) case (final Group g, final SharedExpense x)) {
        _group = g;
        _label.text = x.label;
        _even = _isEven(x);
        _in.addAll(x.shares.keys);
        existing = x;
      }
    }
    for (final TextEditingController c in <TextEditingController>[
      _amount,
      _names,
    ]) {
      c.addListener(_changed);
    }
    // A new split goes where the last one went, as with the same people
    // most of the time; a name to suggest means a group of its own.
    if (_group == null &&
        existing == null &&
        widget.group == null &&
        widget.groupName == null) {
      _group = _lastGroup();
    }
    if (_in.isEmpty) _in.addAll(_members.map((Member m) => m.id));
    // Each part as it was, so a split by amounts opens with its amounts.
    if (existing case final SharedExpense x) {
      for (final MapEntry<String, int> s in x.shares.entries) {
        _controller(s.key).text = _format(s.value);
      }
    }
  }

  /// What was typed changed: what saving last said may no longer hold.
  void _changed() => setState(() => _error = null);

  @override
  void dispose() {
    _groupName.dispose();
    _names.dispose();
    _label.dispose();
    _amount.dispose();
    for (final TextEditingController c in _custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String id) => _custom.putIfAbsent(
    id,
    () => TextEditingController()..addListener(_changed),
  );

  /// The group of the last split, loans aside.
  Group? _lastGroup() {
    Group? last;
    DateTime? when;
    for (final Group g in own.groups) {
      if (g.onlyLoans) continue;
      for (final SharedExpense x in g.expenses) {
        if (when == null || x.date.isAfter(when)) {
          when = x.date;
          last = g;
        }
      }
    }
    return last;
  }

  /// The name of a new group left unnamed: its people, never the shop.
  String _defaultName(AppLocalizations l) => l.splitGroupWith(
    listOf(l, <String>[
      for (final Member m in _members)
        if (!m.isMe) m.name,
    ]),
  );

  /// The people it is split among: the group's, or the person and the names
  /// typed for a new one.
  List<Member> get _members =>
      _group?.members ??
      <Member>[
        const Member(id: meId, name: ''),
        for (final String name in namesIn(_names.text))
          Member(id: _idFor(name), name: name),
      ];

  static String _idFor(String name) =>
      'p-${name.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}';

  int? get _total {
    final Decimal? value = parseAmount(_amount.text);
    final Ledger? l = _ledger;
    if (value == null || value <= Decimal.zero || l == null) return null;
    return l.minor(value.toDouble());
  }

  /// Each member's part as things stand, or null when it does not add up.
  Map<String, int>? get _shares {
    final int? total = _total;
    if (total == null) return null;
    final List<Member> members = <Member>[
      for (final Member m in _members)
        if (_in.contains(m.id)) m,
    ];
    if (members.isEmpty) return null;
    if (_even) {
      // The payer first, so what rounding leaves is theirs.
      members.sort(
        (Member a, Member b) =>
            (b.id == _paidBy ? 1 : 0) - (a.id == _paidBy ? 1 : 0),
      );
      final List<int> parts = splitEvenly(total, members.length);
      return <String, int>{
        for (var i = 0; i < members.length; i++) members[i].id: parts[i],
      };
    }
    final Ledger? l = _ledger;
    if (l == null) return null;
    final Map<String, int> out = <String, int>{
      for (final Member m in members)
        m.id: switch (parseAmount(_controller(m.id).text)) {
          final Decimal d when d >= Decimal.zero => l.minor(d.toDouble()),
          _ => 0,
        },
    };
    return out;
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final int? total = _total;
    final Map<String, int>? shares = _shares;
    if (total == null || shares == null) {
      setState(() => _error = l.splitIncomplete);
      return;
    }
    final int sum = shares.values.fold(0, (int a, int b) => a + b);
    if (sum != total) {
      setState(() => _error = l.splitDoesNotAddUp);
      return;
    }
    if (_members.length < 2) {
      setState(() => _error = l.splitNeedsSomeone);
      return;
    }
    // Someone besides whoever paid has a part, or nothing is split.
    final String payer = widget.entry != null ? meId : _paidBy;
    if (!shares.entries.any(
      (MapEntry<String, int> s) => s.key != payer && s.value > 0,
    )) {
      setState(() => _error = l.splitNeedsShare);
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final DateTime now = DateTime.now();
    Group group =
        _group ??
        Group(
          id: 'group-${now.microsecondsSinceEpoch}',
          name: _groupName.text.trim().isEmpty
              ? _defaultName(l)
              : _groupName.text.trim(),
          // Only who has a part: someone unticked was never in it.
          members: <Member>[
            for (final Member m in _members)
              if (m.isMe || (shares[m.id] ?? 0) > 0) m,
          ],
        );
    final SharedExpense? old =
        widget.expense ??
        switch (widget.entry) {
          final Entry e => own.splitOf(e.id)?.$2,
          null => null,
        };
    // Paid by the person, a new expense leaves the account they say; one
    // the Plan wrote down before follows what it says now.
    String? entryId = widget.entry?.id ?? old?.entryId;
    final String label = _label.text.trim();
    if (_new && _paidBy == meId && _accountId != null) {
      entryId = await own.payGroupExpense(
        accountId: _accountId!,
        amount: total,
        date: _date,
        label: label.isEmpty ? group.name : label,
        group: group.name,
      );
    } else if (old != null && widget.entry == null) {
      await own.updatePlanEntry(
        old.entryId,
        amount: total,
        date: _date,
        payee: label.isEmpty ? group.name : label,
      );
    }
    group = group.withExpense(
      SharedExpense(
        id: old?.id ?? 'expense-${now.microsecondsSinceEpoch}',
        label: label,
        date: _date,
        paidBy: widget.entry != null ? meId : _paidBy,
        shares: <String, int>{
          for (final MapEntry<String, int> s in shares.entries)
            if (s.value > 0) s.key: s.value,
        },
        entryId: entryId,
      ),
    );
    await own.saveGroup(group);
    navigator.pop(group);
  }

  Future<void> _remove() async {
    final NavigatorState navigator = Navigator.of(context);
    final SharedExpense? old =
        widget.expense ??
        switch (widget.entry) {
          final Entry e => own.splitOf(e.id)?.$2,
          null => null,
        };
    final Group? group = _group;
    if (old == null || group == null) return;
    // The movement the Plan wrote down for it goes with it; one the person
    // wrote down and split stays theirs.
    if (widget.entry == null) await own.dropPlanEntry(old.entryId);
    await own.saveGroup(group.withoutExpense(old.id));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = _ledger;
    final Map<String, int>? shares = _shares;
    final int? total = _total;
    final int sum = shares == null
        ? 0
        : shares.values.fold(0, (int a, int b) => a + b);
    final bool fromEntry = widget.entry != null;
    final bool editing =
        widget.expense != null ||
        (widget.entry != null && own.splitOf(widget.entry!.id) != null);
    String amount(int minor) =>
        ledger == null ? '' : pesos(ledger.major(minor));
    final int rest = total == null || !_even || _in.isEmpty
        ? 0
        : total % _in.length;
    // Who carries what rounding leaves: the payer when in, else the first.
    final Member? carries = _members
        .where((Member m) => _in.contains(m.id))
        .fold<Member?>(
          null,
          (Member? best, Member m) =>
              best == null || (m.id == _paidBy && best.id != _paidBy)
              ? m
              : best,
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.splitTitle, style: context.type.headlineMedium),
            const SizedBox(height: 4),
            Text(l.splitBody, style: context.type.bodySmall),
            const SizedBox(height: 16),
            if (widget.group == null && !editing) ...<Widget>[
              DropdownButtonFormField<String?>(
                icon: const Icon(Glyph.caretDown, size: 18),
                initialValue: _group?.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.splitGroup),
                items: <DropdownMenuItem<String?>>[
                  DropdownMenuItem<String?>(child: Text(l.splitNewGroup)),
                  for (final Group g in own.groups)
                    DropdownMenuItem<String?>(value: g.id, child: Text(g.name)),
                ],
                onChanged: (String? id) => setState(() {
                  _error = null;
                  _group = id == null ? null : own.group(id);
                  _in
                    ..clear()
                    ..addAll(_members.map((Member m) => m.id));
                }),
              ),
              const SizedBox(height: 12),
              if (_group == null) ...<Widget>[
                TextField(
                  controller: _names,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l.splitWithWhom,
                    helperText: l.splitWithWhomHelp,
                  ),
                  onChanged: (_) => setState(() {
                    _in
                      ..clear()
                      ..addAll(_members.map((Member m) => m.id));
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _groupName,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l.splitGroupName,
                    // What it will be called if left empty.
                    helperText: _members.length < 2
                        ? null
                        : l.splitGroupNameEmpty(_defaultName(l)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            TextField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.splitWhat),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              enabled: !fromEntry,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: _base.decimals),
              ],
              decoration: InputDecoration(
                labelText: l.splitAmount,
                helperText: fromEntry ? l.splitFromEntry : null,
                prefixText: switch (_base.localSymbol ?? _base.symbol) {
                  final String sign => '$sign ',
                  null => null,
                },
              ),
            ),
            const SizedBox(height: 12),
            if (!fromEntry) ...<Widget>[
              DropdownButtonFormField<String>(
                icon: const Icon(Glyph.caretDown, size: 18),
                initialValue: _members.any((Member m) => m.id == _paidBy)
                    ? _paidBy
                    : meId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.splitPaidBy),
                items: <DropdownMenuItem<String>>[
                  for (final Member m in _members)
                    DropdownMenuItem<String>(
                      value: m.id,
                      child: Text(memberName(l, m)),
                    ),
                ],
                onChanged: (String? id) =>
                    setState(() => _paidBy = id ?? _paidBy),
              ),
              if (_new && _paidBy == meId) ...<Widget>[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  icon: const Icon(Glyph.caretDown, size: 18),
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.instalPaymentFrom),
                  items: <DropdownMenuItem<String?>>[
                    for (final Account a in own.paymentAccounts)
                      DropdownMenuItem<String?>(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    DropdownMenuItem<String?>(
                      child: Text(l.instalPaymentNoAccount),
                    ),
                  ],
                  onChanged: (String? id) => setState(() => _accountId = id),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final DateTime today = own.today;
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(today.year - 2),
                    lastDate: DateTime(today.year + 1),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                icon: const Icon(Glyph.calendarBlank, size: 18),
                label: Text(dayMonth(_date)),
              ),
              const SizedBox(height: 12),
            ],
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: true, label: Text(l.splitEven)),
                ButtonSegment<bool>(value: false, label: Text(l.splitCustom)),
              ],
              selected: <bool>{_even},
              onSelectionChanged: (Set<bool> v) => setState(() {
                _even = v.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            for (final Member m in _members)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    Checkbox(
                      value: _in.contains(m.id),
                      onChanged: (bool? on) => setState(() {
                        _error = null;
                        if (on ?? false) {
                          _in.add(m.id);
                        } else {
                          _in.remove(m.id);
                        }
                      }),
                    ),
                    Expanded(
                      child: Text(
                        memberName(l, m),
                        style: context.type.bodyMedium,
                      ),
                    ),
                    if (_even)
                      Text(
                        _in.contains(m.id) && shares != null
                            ? amount(shares[m.id] ?? 0)
                            : '',
                        style: context.type.bodyMedium,
                      )
                    else
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _controller(m.id),
                          enabled: _in.contains(m.id),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            AmountInputFormatter(maxDecimals: _base.decimals),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: m.isMe
                                ? l.splitPartYou
                                : l.splitPartOf(m.name),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (rest > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  carries?.isMe ?? false
                      ? l.splitRestYou(amount(rest))
                      : l.splitRest(amount(rest), memberName(l, carries)),
                  style: context.type.bodySmall,
                ),
              ),
            if (!_even && total != null && sum != total)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  sum < total
                      ? l.splitMissing(amount(total - sum))
                      : l.splitOver(amount(sum - total)),
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.caution,
                  ),
                ),
              ),
            if (fromEntry && shares != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.splitYourPart(
                    amount(shares[meId] ?? 0),
                    amount((total ?? 0) - (shares[meId] ?? 0)),
                  ),
                  style: context.type.bodyMedium,
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
            FilledButton(onPressed: _save, child: Text(l.save)),
            if (editing)
              TextButton(onPressed: _remove, child: Text(l.splitRemove)),
          ],
        ),
      ),
    );
  }
}
