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
import '../../platform/share_text.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'amount_input.dart';
import 'look.dart';
import 'split_sheet.dart';

/// Who paid whom, said right when the person is one of them.
String paidLine(AppLocalizations l, Group group, String from, String to) {
  String name(String id) => memberName(l, group.member(id));
  if (to == meId) return l.sharedPaidYou(name(from));
  if (from == meId) return l.sharedYouPaid(name(to));
  return l.sharedPaid(name(from), name(to));
}

/// Hands [message] to the share sheet, or says it was copied.
Future<void> shareMessage(BuildContext context, String message) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String copied = context.l10n.messageCopied;
  if (!await ShareText.share(message)) {
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }
}

/// Expenses shared with others, and what they owe. Nobody else needs the
/// app: people are names, and reminders go only if the person sends them.
class SharedPage extends StatelessWidget {
  const SharedPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final List<Group> groups = own.groups;
      final (int owed, int owing) = own.sharedBalance;
      String amount(int minor) =>
          ledger == null ? '' : pesos(ledger.major(minor));
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.sharedTitle, style: context.type.titleLarge),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showGroupSheet(context, own: own),
          icon: const Icon(Glyph.plus),
          label: Text(l.sharedNewGroup),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Text(l.sharedBody, style: context.type.bodyMedium),
                const SizedBox(height: 16),
                if (groups.isEmpty)
                  Block(
                    child: Text(l.sharedEmpty, style: context.type.bodyMedium),
                  )
                else ...<Widget>[
                  Block(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Figure(
                          caption: l.sharedOwedToYou,
                          value: amount(owed),
                        ),
                        const SizedBox(width: 16),
                        _Figure(caption: l.sharedYouOwe, value: amount(owing)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.sharedNotCash, style: context.type.bodySmall),
                  const SizedBox(height: 24),
                  SectionLabel(l.sharedGroups),
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final Group g in groups)
                        _GroupRow(own: own, group: g, amount: amount),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Figure extends StatelessWidget {
  const _Figure({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(caption, style: context.type.labelMedium),
        const SizedBox(height: 2),
        Figures(value, style: context.type.titleLarge),
      ],
    ),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.own,
    required this.group,
    required this.amount,
  });

  final OwnController own;
  final Group group;
  final String Function(int minor) amount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final int mine = group.balances[meId] ?? 0;
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => GroupPage(own: own, id: group.id),
        ),
      ),
      title: Text(group.name, style: context.type.titleSmall),
      subtitle: Text(
        group.members.map((Member m) => memberName(l, m)).join(', '),
        style: context.type.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        mine > 0
            ? l.sharedOwesYouShort(amount(mine))
            : mine < 0
            ? l.sharedYouOweShort(amount(-mine))
            : l.sharedEven,
        style: context.type.bodySmall?.copyWith(
          color: mine > 0
              ? context.colors.brand
              : mine < 0
              ? context.colors.caution
              : context.colors.inkSoft,
        ),
      ),
    );
  }
}

/// One group: where everyone stands, the payments that settle it, its
/// expenses and what was paid back.
class GroupPage extends StatelessWidget {
  const GroupPage({super.key, required this.own, required this.id});

  final OwnController own;
  final String id;

  Future<void> _delete(BuildContext context, Group group) async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.sharedDeleteTitle(group.name)),
        content: Text(l.sharedDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.sharedDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    navigator.pop();
    await own.deleteGroup(group.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final Group? group = own.group(id);
      if (group == null || ledger == null) return Scaffold(appBar: AppBar());
      String amount(int minor) => pesos(ledger.major(minor));
      String name(String id) => memberName(l, group.member(id));
      final int mine = group.balances[meId] ?? 0;
      final List<Transfer> plan = group.plan;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(group.name, style: context.type.titleLarge),
          actions: <Widget>[
            IconButton(
              tooltip: l.sharedEditGroup,
              onPressed: () => showGroupSheet(context, own: own, group: group),
              icon: const Icon(Glyph.pencilSimple),
            ),
            IconButton(
              tooltip: l.sharedDelete,
              onPressed: () => _delete(context, group),
              icon: const Icon(Glyph.trash),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showSplitSheet(context, own: own, group: group),
          icon: const Icon(Glyph.plus),
          label: Text(l.sharedAddExpense),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Block(
                  child: Text(
                    mine > 0
                        ? l.sharedOwedToYouIn(amount(mine))
                        : mine < 0
                        ? l.sharedYouOweIn(amount(-mine))
                        : l.sharedAllEven,
                    style: context.type.titleMedium,
                  ),
                ),
                if (plan.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  SectionLabel(l.sharedToSettle),
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final Transfer t in plan)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                t.to == meId
                                    ? l.sharedPaysYou(
                                        name(t.from),
                                        amount(t.amount),
                                      )
                                    : t.from == meId
                                    ? l.sharedYouPay(
                                        name(t.to),
                                        amount(t.amount),
                                      )
                                    : l.sharedPays(
                                        name(t.from),
                                        name(t.to),
                                        amount(t.amount),
                                      ),
                                style: context.type.bodyMedium,
                              ),
                              Wrap(
                                alignment: WrapAlignment.end,
                                children: <Widget>[
                                  if (t.to == meId)
                                    TextButton.icon(
                                      onPressed: () => shareMessage(
                                        context,
                                        l.sharedReminderMessage(
                                          name(t.from),
                                          amount(t.amount),
                                          group.name,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Glyph.shareNetwork,
                                        size: 18,
                                      ),
                                      label: Text(l.sharedRemind),
                                    ),
                                  TextButton(
                                    onPressed: () => showSettleDialog(
                                      context,
                                      own: own,
                                      group: group,
                                      from: t.from,
                                      to: t.to,
                                      amount: t.amount,
                                    ),
                                    child: Text(l.sharedRecordPayment),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SectionLabel(l.sharedExpenses),
                if (group.expenses.isEmpty)
                  Block(
                    child: Text(
                      l.sharedNoExpenses,
                      style: context.type.bodyMedium,
                    ),
                  )
                else
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final SharedExpense e in group.expenses.reversed)
                        ListTile(
                          onTap: () => showSplitSheet(
                            context,
                            own: own,
                            group: group,
                            expense: e,
                          ),
                          title: Text(
                            e.label.isEmpty ? l.kindExpense : e.label,
                            style: context.type.titleSmall,
                          ),
                          subtitle: Text(
                            <String>[
                              dayShortMonth(e.date),
                              if (e.paidBy == meId)
                                l.sharedPaidByYou
                              else
                                l.sharedPaidBy(name(e.paidBy)),
                              if (e.shares[meId] case final int part)
                                l.sharedYourShare(amount(part)),
                            ].join(' · '),
                            style: context.type.bodySmall,
                          ),
                          trailing: Figures(
                            amount(e.amount),
                            style: context.type.titleSmall,
                          ),
                        ),
                    ],
                  ),
                if (group.settlements.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  SectionLabel(l.sharedPayments),
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final Settlement s in group.settlements.reversed)
                        ListTile(
                          title: Text(
                            paidLine(l, group, s.from, s.to),
                            style: context.type.bodyMedium,
                          ),
                          subtitle: Text(
                            <String>[
                              dayShortMonth(s.date),
                              if (s.entryId != null) l.sharedLinked,
                            ].join(' · '),
                            style: context.type.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Figures(
                                amount(s.amount),
                                style: context.type.bodyMedium,
                              ),
                              IconButton(
                                tooltip: l.sharedRemovePayment,
                                onPressed: () => own.saveGroup(
                                  group.withoutSettlement(s.id),
                                ),
                                icon: Icon(
                                  Glyph.trash,
                                  size: 18,
                                  color: context.colors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text(l.sharedLedgerNote, style: context.type.bodySmall),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Names a new group and its people, or renames [group] and adds people.
/// Someone with expenses stays.
Future<void> showGroupSheet(
  BuildContext context, {
  required OwnController own,
  Group? group,
  void Function(Group group)? onSaved,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) =>
      _GroupSheet(own: own, group: group, onSaved: onSaved),
);

class _GroupSheet extends StatefulWidget {
  const _GroupSheet({required this.own, this.group, this.onSaved});

  final OwnController own;
  final Group? group;
  final void Function(Group group)? onSaved;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group?.name ?? '',
  );
  final TextEditingController _people = TextEditingController();
  late final List<Member> _members = <Member>[
    ...widget.group?.members ?? const <Member>[Member(id: meId, name: '')],
  ];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _people.dispose();
    super.dispose();
  }

  bool _inUse(String id) {
    final Group? g = widget.group;
    if (g == null) return false;
    return g.expenses.any(
          (SharedExpense e) => e.paidBy == id || e.shares.containsKey(id),
        ) ||
        g.settlements.any((Settlement s) => s.from == id || s.to == id);
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final List<Member> members = <Member>[
      ..._members,
      for (final String name in namesIn(_people.text))
        if (!_members.any(
          (Member m) => m.name.toLowerCase() == name.toLowerCase(),
        ))
          Member(
            id: 'p-${DateTime.now().microsecondsSinceEpoch}-${name.hashCode.abs()}',
            name: name,
          ),
    ];
    if (_name.text.trim().isEmpty || members.length < 2) {
      setState(() => _error = l.sharedGroupIncomplete);
      return;
    }
    final Group group =
        widget.group?.copyWith(name: _name.text.trim(), members: members) ??
        Group(
          id: 'group-${DateTime.now().microsecondsSinceEpoch}',
          name: _name.text.trim(),
          members: members,
        );
    await widget.own.saveGroup(group);
    widget.onSaved?.call(group);
    navigator.pop();
  }

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
              widget.group == null ? l.sharedNewGroup : l.sharedEditGroup,
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.sharedGroupName),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final Member m in _members)
                  InputChip(
                    label: Text(memberName(l, m)),
                    onDeleted: m.isMe || _inUse(m.id)
                        ? null
                        : () => setState(() => _members.remove(m)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _people,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l.sharedAddPeople,
                helperText: l.splitWithWhomHelp,
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
          ],
        ),
      ),
    );
  }
}

/// Records that [from] paid [to]. When the money came to the person, it can
/// be tied to the income it arrived as, which then counts as money back.
Future<void> showSettleDialog(
  BuildContext context, {
  required OwnController own,
  required Group group,
  required String from,
  required String to,
  required int amount,
}) => showDialog<void>(
  context: context,
  builder: (BuildContext context) =>
      _SettleDialog(own: own, group: group, from: from, to: to, amount: amount),
);

class _SettleDialog extends StatefulWidget {
  const _SettleDialog({
    required this.own,
    required this.group,
    required this.from,
    required this.to,
    required this.amount,
  });

  final OwnController own;
  final Group group;
  final String from;
  final String to;
  final int amount;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final Asset _base = widget.own.profile?.base ?? Asset.cop;
  late final TextEditingController _amount = TextEditingController(
    text: formatDecimal(
      Decimal.parse('${widget.own.ledger?.major(widget.amount) ?? 0}'),
      decimals: _base.decimals,
      trim: true,
    ),
  );
  late DateTime _on = widget.own.today;
  String? _entryId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final Ledger? ledger = widget.own.ledger;
    final Decimal? value = parseAmount(_amount.text);
    if (ledger == null || value == null || value <= Decimal.zero) {
      setState(() => _error = context.l10n.instalPaymentInvalid);
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    await widget.own.saveGroup(
      widget.group.withSettlement(
        Settlement(
          id: 'settle-${DateTime.now().microsecondsSinceEpoch}',
          from: widget.from,
          to: widget.to,
          amount: ledger.minor(value.toDouble()),
          date: _on,
          entryId: _entryId,
        ),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final OwnController own = widget.own;
    final List<Entry> incomes = widget.to == meId
        ? own.recentIncomes()
        : const <Entry>[];
    return AlertDialog(
      title: Text(paidLine(l, widget.group, widget.from, widget.to)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: _base.decimals),
              ],
              decoration: InputDecoration(
                labelText: l.instalPaymentAmount,
                errorText: _error,
                prefixText: switch (_base.localSymbol ?? _base.symbol) {
                  final String sign => '$sign ',
                  null => null,
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _on,
                  firstDate: DateTime(own.today.year - 2),
                  lastDate: own.today,
                );
                if (picked != null) setState(() => _on = picked);
              },
              icon: const Icon(Glyph.calendarBlank, size: 18),
              label: Text(dayMonth(_on)),
            ),
            if (widget.to == meId) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                icon: const Icon(Glyph.caretDown, size: 18),
                initialValue: _entryId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.sharedArrivedAs),
                items: <DropdownMenuItem<String?>>[
                  DropdownMenuItem<String?>(child: Text(l.sharedNotRecorded)),
                  for (final Entry e in incomes)
                    DropdownMenuItem<String?>(
                      value: e.id,
                      child: Text(
                        '${e.payee.isEmpty ? l.kindIncome : e.payee} · '
                        '${moneyText(Money(e.amount, own.snapshot?.account(e.accountId)?.asset ?? _base), base: _base)} · '
                        '${dayShortMonth(e.date)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? id) => setState(() => _entryId = id),
              ),
              const SizedBox(height: 4),
              Text(l.sharedArrivedAsHelp, style: context.type.bodySmall),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
