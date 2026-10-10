import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/freelance.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../own/undo.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import '../messages.dart';
import 'amount_input.dart';
import 'look.dart';
import 'shared_page.dart' show shareMessage;

/// For income that changes from month to month: what was collected, what
/// is billed and what is only estimated, which of it counts ahead, and a
/// reserve the person sizes. No tax is worked out here.
class FreelancePage extends StatelessWidget {
  const FreelancePage({super.key, required this.own});

  final OwnController own;

  static const List<int> _percents = <int>[0, 5, 10, 15, 20, 25, 30, 35, 40];

  Future<void> _use(BuildContext context, Ledger ledger) async {
    final String payee = context.l10n.freelanceUsePayee;
    final (int, String?)? used = await showDialog<(int, String?)>(
      context: context,
      builder: (BuildContext context) => _UseDialog(
        ledger: ledger,
        asset: own.profile?.base ?? Asset.cop,
        accounts: own.paymentAccounts,
        likely: own.likelyPaymentAccount?.id,
      ),
    );
    if (used == null) return;
    final (int amount, String? accountId) = used;
    // The money went out of an account: written there, what can be spent
    // does not go up by what left the reserve.
    if (accountId != null) {
      await own.store.addEntry(
        accountId: accountId,
        amount: Decimal.parse('${ledger.major(amount)}'),
        kind: EntryKind.expense,
        date: own.today,
        category: 'other',
        payee: payee,
        source: OwnController.planSource,
      );
    }
    final FreelancePlan plan = own.freelance;
    await own.saveFreelance(
      plan.copyWith(used: <(DateTime, int)>[...plan.used, (own.today, amount)]),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      if (ledger == null) return Scaffold(appBar: AppBar());
      String amount(int minor) => pesos(ledger.major(minor));
      final FreelancePlan plan = own.freelance;
      final DateTime today = own.today;
      int sum(Iterable<ExpectedIncome> list) =>
          list.fold(0, (int s, ExpectedIncome i) => s + i.amount);
      final List<ExpectedIncome> overdue = <ExpectedIncome>[
        for (final ExpectedIncome i in plan.by(IncomeStatus.pending))
          if (i.overdue(today)) i,
      ];
      final List<ExpectedIncome> pending =
          <ExpectedIncome>[
            for (final ExpectedIncome i in plan.by(IncomeStatus.pending))
              if (!i.overdue(today)) i,
          ]..sort(
            (ExpectedIncome a, ExpectedIncome b) =>
                a.expected.compareTo(b.expected),
          );
      final List<ExpectedIncome> estimated =
          plan.by(IncomeStatus.estimated).toList()..sort(
            (ExpectedIncome a, ExpectedIncome b) =>
                a.expected.compareTo(b.expected),
          );
      final List<ExpectedIncome> collected =
          plan.by(IncomeStatus.collected).toList()..sort(
            (ExpectedIncome a, ExpectedIncome b) =>
                (b.collectedOn ?? b.expected).compareTo(
                  a.collectedOn ?? a.expected,
                ),
          );
      final int reserve = ledger.reserved;
      Widget list(String title, List<ExpectedIncome> incomes) => incomes.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 24),
                SectionLabel(title),
                Panel(
                  indent: 16,
                  children: <Widget>[
                    for (final ExpectedIncome i in incomes)
                      _IncomeRow(own: own, income: i, amount: amount),
                  ],
                ),
              ],
            );
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.freelanceTitle, style: context.type.titleLarge),
        ),
        floatingActionButton: ScrollAwareFab(
          child: FloatingActionButton.extended(
            onPressed: () => showIncomeSheet(context, own: own),
            icon: const Icon(Glyph.plus),
            label: Text(l.freelanceAdd),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Text(l.freelanceBody, style: context.type.bodyMedium),
                const SizedBox(height: 16),
                Block(
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: <Widget>[
                      _Total(
                        caption: l.freelancePending,
                        value: amount(sum(pending) + sum(overdue)),
                      ),
                      _Total(
                        caption: l.freelanceEstimated,
                        value: amount(sum(estimated)),
                      ),
                      _Total(
                        caption: l.freelanceReserve,
                        value: amount(reserve),
                      ),
                    ],
                  ),
                ),
                if (overdue.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.freelanceOverdueNote(
                        overdue.length,
                        amount(sum(overdue)),
                      ),
                      style: context.type.bodySmall?.copyWith(
                        color: context.colors.caution,
                      ),
                    ),
                  ),
                list(l.freelanceOverdue, overdue),
                list(l.freelancePendingList, pending),
                list(l.freelanceEstimatedList, estimated),
                const SizedBox(height: 24),
                SectionLabel(l.freelanceScenario),
                Block(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SegmentedButton<IncomeScenario>(
                        showSelectedIcon: false,
                        segments: <ButtonSegment<IncomeScenario>>[
                          ButtonSegment<IncomeScenario>(
                            value: IncomeScenario.collected,
                            label: Text(l.scenarioCollected),
                          ),
                          ButtonSegment<IncomeScenario>(
                            value: IncomeScenario.pending,
                            label: Text(l.scenarioPending),
                          ),
                          ButtonSegment<IncomeScenario>(
                            value: IncomeScenario.estimated,
                            label: Text(l.scenarioEstimated),
                          ),
                        ],
                        selected: <IncomeScenario>{plan.scenario},
                        onSelectionChanged: (Set<IncomeScenario> v) =>
                            own.saveFreelance(plan.copyWith(scenario: v.first)),
                      ),
                      const SizedBox(height: 10),
                      Text(switch (plan.scenario) {
                        IncomeScenario.collected => l.scenarioCollectedBody,
                        IncomeScenario.pending => l.scenarioPendingBody,
                        IncomeScenario.estimated => l.scenarioEstimatedBody,
                      }, style: context.type.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionLabel(l.freelanceReserve),
                Block(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DropdownButtonFormField<int>(
                        icon: const Icon(Glyph.caretDown, size: 18),
                        initialValue:
                            _percents.contains(plan.reservePercent.round())
                            ? plan.reservePercent.round()
                            : 0,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l.freelanceReservePercent,
                          // A new percentage counts for all that came in
                          // since the reserve began, not from today.
                          helperText: switch (plan.reserveSince) {
                            final DateTime since => l.freelanceReserveCounts(
                              dayMonth(since),
                            ),
                            null => null,
                          },
                          helperMaxLines: 2,
                        ),
                        items: <DropdownMenuItem<int>>[
                          for (final int p in _percents)
                            DropdownMenuItem<int>(
                              value: p,
                              child: Text(
                                p == 0 ? l.freelanceNoReserve : percent(p),
                              ),
                            ),
                        ],
                        onChanged: (int? p) => own.saveFreelance(
                          plan.copyWith(
                            reservePercent: (p ?? 0).toDouble(),
                            reserveSince: plan.reserveSince ?? own.today,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        plan.reservePercent > 0
                            ? l.freelanceReserveNow(
                                amount(reserve),
                                dayMonth(plan.reserveSince ?? today),
                              )
                            : l.freelanceReserveOff,
                        style: context.type.bodyMedium,
                      ),
                      // Why a client's payment kept elsewhere adds nothing.
                      if (plan.reservePercent > 0 &&
                          own.collectedOutsideReserve > 0) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          l.freelanceReserveOutside(
                            amount(own.collectedOutsideReserve),
                          ),
                          style: context.type.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(l.freelanceNoTax, style: context.type.bodySmall),
                      if (reserve > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _use(context, ledger),
                            child: Text(l.freelanceUse),
                          ),
                        ),
                    ],
                  ),
                ),
                list(l.freelanceCollectedList, collected.take(5).toList()),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// What was taken out of the reserve. The dialog keeps its own field, so
/// the field lives until the dialog is gone.
class _UseDialog extends StatefulWidget {
  const _UseDialog({
    required this.ledger,
    required this.asset,
    required this.accounts,
    this.likely,
  });

  final Ledger ledger;
  final Asset asset;

  /// Where the money can have gone out from, the likeliest chosen.
  final List<Account> accounts;
  final String? likely;

  @override
  State<_UseDialog> createState() => _UseDialogState();
}

class _UseDialogState extends State<_UseDialog> {
  final TextEditingController _amount = TextEditingController();

  /// Saving with nothing typed says what is missing instead of closing.
  bool _missing = false;

  late String? _from = widget.accounts.any((Account a) => a.id == widget.likely)
      ? widget.likely
      : widget.accounts.firstOrNull?.id;

  /// What saving does, once there is an amount.
  String? _after(AppLocalizations l) {
    final Decimal? value = parseAmount(_amount.text);
    if (value == null || value <= Decimal.zero) return null;
    final String amount = formatAmount(value, widget.asset, base: widget.asset);
    final String? from = widget.accounts
        .where((Account a) => a.id == _from)
        .firstOrNull
        ?.name;
    return from == null
        ? l.freelanceUseOnlyReserve(amount)
        : l.freelanceUseFrom(amount, from);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.freelanceUse),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              AmountInputFormatter(maxDecimals: widget.asset.decimals),
            ],
            onChanged: (_) => setState(() => _missing = false),
            decoration: InputDecoration(
              labelText: l.freelanceUseAmount,
              errorText: _missing ? l.freelanceUseMissing : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(l.freelanceUseHelp, style: context.type.bodySmall),
          if (widget.accounts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _from,
              isExpanded: true,
              icon: const Icon(Glyph.caretDown, size: 18),
              decoration: InputDecoration(labelText: l.instalPaymentFrom),
              items: <DropdownMenuItem<String?>>[
                for (final Account a in widget.accounts)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
                DropdownMenuItem<String?>(
                  child: Text(l.instalPaymentNoAccount),
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
        TextButton(
          onPressed: () {
            final Decimal? value = parseAmount(_amount.text);
            if (value == null || value <= Decimal.zero) {
              setState(() => _missing = true);
              return;
            }
            Navigator.of(
              context,
            ).pop((widget.ledger.minor(value.toDouble()), _from));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(caption, style: context.type.labelMedium),
      const SizedBox(height: 2),
      Figures(value, style: context.type.titleLarge),
    ],
  );
}

class _IncomeRow extends StatelessWidget {
  const _IncomeRow({
    required this.own,
    required this.income,
    required this.amount,
  });

  final OwnController own;
  final ExpectedIncome income;
  final String Function(int minor) amount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final DateTime today = own.today;
    final bool late = income.overdue(today);
    return ListTile(
      onTap: () => showIncomeSheet(context, own: own, income: income),
      title: Text(income.client, style: context.type.titleSmall),
      subtitle: Text(
        switch (income.status) {
          IncomeStatus.collected => l.freelanceCollectedOn(
            dayMonth(income.collectedOn ?? income.expected),
          ),
          _ when late => l.freelanceLate(
            income.daysLate(today),
            dayMonth(income.expected),
          ),
          _ => l.freelanceExpectedOn(dayMonth(income.expected)),
        },
        style: context.type.bodySmall?.copyWith(
          color: late ? context.colors.caution : null,
        ),
      ),
      trailing: Figures(amount(income.amount), style: context.type.titleSmall),
    );
  }
}

/// Adds a payment a client owes or may owe, or changes [income]: its day,
/// whether it arrived, and with which movement.
Future<void> showIncomeSheet(
  BuildContext context, {
  required OwnController own,
  ExpectedIncome? income,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) => _IncomeSheet(own: own, income: income),
);

class _IncomeSheet extends StatefulWidget {
  const _IncomeSheet({required this.own, this.income});

  final OwnController own;
  final ExpectedIncome? income;

  @override
  State<_IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends State<_IncomeSheet> {
  OwnController get own => widget.own;
  late final Asset _base = own.profile?.base ?? Asset.cop;
  late final TextEditingController _client = TextEditingController(
    text: widget.income?.client ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: switch (widget.income) {
      final ExpectedIncome i => formatDecimal(
        Decimal.parse('${own.ledger?.major(i.amount) ?? i.amount}'),
        decimals: _base.decimals,
        trim: true,
      ),
      null => '',
    },
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.income?.note ?? '',
  );
  late DateTime _expected =
      widget.income?.expected ?? own.today.add(const Duration(days: 15));
  late IncomeStatus _status = widget.income?.status ?? IncomeStatus.pending;
  late DateTime _collectedOn = widget.income?.collectedOn ?? own.today;
  late String? _entryId = widget.income?.entryId;
  String? _error;

  @override
  void initState() {
    super.initState();
    // What was missing is said until something is typed.
    for (final TextEditingController c in <TextEditingController>[
      _client,
      _amount,
      _note,
    ]) {
      c.addListener(_typed);
    }
  }

  void _typed() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _client.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = own.ledger;
    final Decimal? value = parseAmount(_amount.text);
    if (_client.text.trim().isEmpty ||
        value == null ||
        value <= Decimal.zero ||
        ledger == null) {
      setState(() => _error = l.freelanceIncomplete);
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final bool collected = _status == IncomeStatus.collected;
    await own.saveFreelance(
      own.freelance.withIncome(
        ExpectedIncome(
          id:
              widget.income?.id ??
              'income-${DateTime.now().microsecondsSinceEpoch}',
          client: _client.text.trim(),
          amount: ledger.minor(value.toDouble()),
          expected: _expected,
          status: _status,
          collectedOn: collected ? _collectedOn : null,
          entryId: collected ? _entryId : null,
          note: _note.text.trim(),
        ),
      ),
    );
    navigator.pop();
  }

  /// Deletes the payment, with a way back for a few seconds.
  Future<void> _delete() async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ExpectedIncome income = widget.income!;
    final String said = context.l10n.incomeDeleted(income.client);
    final Undo back = await own.removeIncome(income);
    navigator.pop();
    showUndo(messenger, said, back);
  }

  Future<DateTime?> _pick(DateTime initial) {
    final DateTime today = own.today;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final ExpectedIncome? income = widget.income;
    final List<Entry> incomes = own.recentIncomes(days: 90);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              income == null ? l.freelanceAdd : l.freelanceEdit,
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _client,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.freelanceClient),
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
                labelText: l.freelanceAmount,
                prefixText: switch (_base.localSymbol ?? _base.symbol) {
                  final String sign => '$sign ',
                  null => null,
                },
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<IncomeStatus>(
              showSelectedIcon: false,
              segments: <ButtonSegment<IncomeStatus>>[
                ButtonSegment<IncomeStatus>(
                  value: IncomeStatus.estimated,
                  label: Text(l.incomeEstimated),
                ),
                ButtonSegment<IncomeStatus>(
                  value: IncomeStatus.pending,
                  label: Text(l.incomePending),
                ),
                ButtonSegment<IncomeStatus>(
                  value: IncomeStatus.collected,
                  label: Text(l.incomeCollected),
                ),
              ],
              selected: <IncomeStatus>{_status},
              onSelectionChanged: (Set<IncomeStatus> v) =>
                  setState(() => _status = v.first),
            ),
            const SizedBox(height: 8),
            Text(switch (_status) {
              IncomeStatus.estimated => l.incomeEstimatedHelp,
              IncomeStatus.pending => l.incomePendingHelp,
              IncomeStatus.collected => l.incomeCollectedHelp,
            }, style: context.type.bodySmall),
            const SizedBox(height: 12),
            if (_status != IncomeStatus.collected)
              OutlinedButton.icon(
                onPressed: () async {
                  final DateTime? picked = await _pick(_expected);
                  if (picked != null) setState(() => _expected = picked);
                },
                icon: const Icon(Glyph.calendarBlank, size: 18),
                label: Text(l.freelanceExpectedOn(dayMonth(_expected))),
              )
            else ...<Widget>[
              OutlinedButton.icon(
                onPressed: () async {
                  final DateTime? picked = await _pick(_collectedOn);
                  if (picked != null) setState(() => _collectedOn = picked);
                },
                icon: const Icon(Glyph.calendarBlank, size: 18),
                label: Text(l.freelanceCollectedOn(dayMonth(_collectedOn))),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                icon: const Icon(Glyph.caretDown, size: 18),
                initialValue: incomes.any((Entry e) => e.id == _entryId)
                    ? _entryId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.freelanceArrivedAs),
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
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.freelanceNote),
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
            if (income != null &&
                income.status == IncomeStatus.pending &&
                own.ledger != null)
              TextButton.icon(
                onPressed: () => shareMessage(
                  context,
                  l.freelanceReminderMessage(
                    income.client,
                    pesos(own.ledger!.major(income.amount)),
                    dayMonth(income.expected),
                  ),
                ),
                icon: const Icon(Glyph.shareNetwork, size: 18),
                label: Text(l.freelanceRemind),
              ),
            if (income != null)
              TextButton(onPressed: _delete, child: Text(l.freelanceDelete)),
          ],
        ),
      ),
    );
  }
}
