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
import '../kit.dart';
import 'amount_input.dart';
import 'look.dart';

String rateKindLabel(AppLocalizations l, RateKind kind) => switch (kind) {
  RateKind.effectiveAnnual => l.rateEffectiveAnnual,
  RateKind.nominalMonthly => l.rateNominalMonthly,
  RateKind.monthly => l.rateMonthly,
};

/// Purchases in instalments, as the bank or the shop stated them. What was
/// not stated stays an estimate, never a final figure.
class InstalmentsPage extends StatelessWidget {
  const InstalmentsPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final List<Instalments> plans = <Instalments>[...own.instalments]
        ..sort((Instalments a, Instalments b) => a.name.compareTo(b.name));
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.instalTitle, style: context.type.titleLarge),
        ),
        floatingActionButton: ScrollAwareFab(
          child: FloatingActionButton.extended(
            onPressed: () => showInstalmentSheet(context, own: own),
            icon: const Icon(Glyph.plus),
            label: Text(l.instalAdd),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Text(l.instalBody, style: context.type.bodyMedium),
                const SizedBox(height: 16),
                if (plans.isEmpty || ledger == null)
                  Block(
                    child: Text(l.instalEmpty, style: context.type.bodyMedium),
                  )
                else ...<Widget>[
                  _Owed(ledger: ledger, plans: plans),
                  const SizedBox(height: 24),
                  SectionLabel(l.instalList),
                  Panel(
                    children: <Widget>[
                      for (final Instalments p in plans)
                        _PlanRow(own: own, ledger: ledger, plan: p),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                const _CardNote(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Paying a card is not a new expense.
class _CardNote extends StatelessWidget {
  const _CardNote();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(Glyph.info, size: 18, color: context.colors.inkSoft),
      const SizedBox(width: 8),
      Expanded(
        child: Text(context.l10n.instalCardNote, style: context.type.bodySmall),
      ),
    ],
  );
}

/// What is left to pay across every purchase, and how sure that is.
class _Owed extends StatelessWidget {
  const _Owed({required this.ledger, required this.plans});

  final Ledger ledger;
  final List<Instalments> plans;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    var owed = 0;
    var estimated = false;
    var unknown = 0;
    for (final Instalments p in plans) {
      final int? left = p.remaining;
      if (left == null) {
        unknown++;
        continue;
      }
      owed += left;
      if (!p.totalKnown && left > 0) estimated = true;
    }
    // With nothing to work from, no figure: a zero would say nothing is owed.
    final bool none = unknown == plans.length;
    return Block(
      child: Headline(
        caption: l.instalOwed,
        value: none ? l.instalUnknown : pesos(ledger.major(owed)),
        detail: <String>[
          if (!none)
            if (estimated) l.instalOwedEstimated else l.instalOwedKnown,
          if (unknown > 0) l.instalOwedUnknown(unknown),
        ].join(' '),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.own, required this.ledger, required this.plan});

  final OwnController own;
  final Ledger ledger;
  final Instalments plan;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final InstalmentRow? next = plan.next;
    final int? left = plan.remaining;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              InstalmentDetailPage(own: own, id: plan.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            const AccountTile(AccountKind.card),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(plan.name, style: context.type.titleSmall),
                  Text(
                    plan.schedule.isEmpty
                        ? l.instalNoData
                        : next == null
                        ? l.instalPaidOff
                        : l.instalNextRow(
                            next.number,
                            plan.count,
                            dayMonth(next.due),
                          ),
                    style: context.type.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (left != null)
                  Figures(
                    pesos(ledger.major(left)),
                    style: context.type.titleSmall,
                  ),
                if (left != null && left > 0 && !plan.totalKnown)
                  Text(l.instalEstimated, style: context.type.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One purchase in instalments: what is known and what is estimated, the
/// payments, and the schedule.
class InstalmentDetailPage extends StatelessWidget {
  const InstalmentDetailPage({super.key, required this.own, required this.id});

  final OwnController own;
  final String id;

  Future<void> _delete(BuildContext context, Instalments plan) async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.instalDeleteTitle(plan.name)),
        content: Text(l.instalDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.instalDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    navigator.pop();
    await own.deleteInstalments(plan.id);
  }

  Future<void> _pay(
    BuildContext context,
    Ledger ledger,
    Instalments plan,
  ) async {
    final (int covered, int owing) = plan.progress;
    final List<InstalmentRow> rows = plan.schedule;
    final int suggested = owing > 0
        ? owing
        : covered < rows.length
        ? rows[covered].payment
        : 0;
    final (DateTime, int)? payment = await showDialog<(DateTime, int)>(
      context: context,
      builder: (BuildContext context) => _PaymentDialog(
        ledger: ledger,
        asset: own.profile?.base ?? Asset.cop,
        today: own.today,
        suggested: suggested,
      ),
    );
    if (payment == null) return;
    await own.saveInstalments(plan.withPayment(payment.$1, payment.$2));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final Instalments? plan = own.instalments
          .where((Instalments p) => p.id == id)
          .firstOrNull;
      if (plan == null || ledger == null) {
        return Scaffold(appBar: AppBar());
      }
      String amount(int minor) => pesos(ledger.major(minor));
      final List<InstalmentRow> rows = plan.schedule;
      final (int covered, int owing) = plan.progress;
      final InstalmentRow? next = plan.next;
      final int? total = plan.total;
      final int? left = plan.remaining;
      final int? cash = plan.cashPrice;
      final Account? account = plan.accountId == null
          ? null
          : own.snapshot?.account(plan.accountId!);
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(plan.name, style: context.type.titleLarge),
          actions: <Widget>[
            IconButton(
              tooltip: l.instalEdit,
              onPressed: () =>
                  showInstalmentSheet(context, own: own, plan: plan),
              icon: const Icon(Glyph.pencilSimple),
            ),
            IconButton(
              tooltip: l.instalDelete,
              onPressed: () => _delete(context, plan),
              icon: const Icon(Glyph.trash),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Headline(
                  caption: l.instalOwed,
                  value: left == null ? l.instalUnknown : amount(left),
                  detail: total == null
                      ? l.instalTotalUnknown
                      : plan.totalKnown
                      ? l.instalTotalKnown(amount(total))
                      : l.instalTotalEstimated(amount(total)),
                ),
                if (cash != null && total != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    total <= cash
                        ? l.instalVsCashSame(amount(cash))
                        : plan.totalKnown
                        ? l.instalVsCash(amount(cash), amount(total - cash))
                        : l.instalVsCashAtLeast(
                            amount(cash),
                            amount(total - cash),
                          ),
                    style: context.type.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                if (rows.isNotEmpty)
                  Block(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          l.instalProgress(covered, plan.count),
                          style: context.type.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: covered / plan.count,
                            minHeight: 8,
                            backgroundColor: context.colors.sunken,
                            color: context.colors.brand,
                          ),
                        ),
                        if (next != null && owing > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l.instalOwing(next.number, amount(owing)),
                              style: context.type.bodySmall,
                            ),
                          ),
                        if (next != null && next.due.isBefore(own.today))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l.instalLate(next.number, dayMonth(next.due)),
                              style: context.type.bodySmall,
                            ),
                          ),
                        if (next != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              onPressed: () => _pay(context, ledger, plan),
                              icon: const Icon(Glyph.check, size: 18),
                              label: Text(l.instalPay),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SectionLabel(l.instalFacts),
                Panel(
                  indent: 16,
                  children: <Widget>[
                    _Fact(l.instalFinanced, amount(plan.principal)),
                    _Fact(l.instalCount, '${plan.count}'),
                    _Fact(l.instalRate, switch ((plan.rate, plan.monthlyRate)) {
                      (final double rate, final double monthly) =>
                        l.instalRateValue(
                          percent(rate, decimals: 2, trim: true),
                          rateKindLabel(l, plan.rateKind),
                          percent(monthly * 100, decimals: 2, trim: true),
                        ),
                      _ => l.instalNotKnown,
                    }),
                    _Fact(l.instalPayment, switch (plan.payment) {
                      null => l.instalNotKnown,
                      final int p =>
                        plan.paymentStated
                            ? l.instalPaymentStated(amount(p))
                            : l.instalPaymentWorked(amount(p)),
                    }),
                    _Fact(l.instalFee, switch (plan.fee) {
                      null => l.instalNotKnown,
                      0 => l.instalNoFee,
                      final int fee => amount(fee),
                    }),
                    _Fact(l.instalPaysFrom, account?.name ?? l.instalOutside),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  account != null && account.spendable && !account.archived
                      ? l.instalCountedOnce
                      : l.instalCountedAsComing,
                  style: context.type.bodySmall,
                ),
                const SizedBox(height: 24),
                SectionLabel(l.instalPayments),
                if (plan.payments.isEmpty)
                  Block(
                    child: Text(
                      l.instalNoPayments,
                      style: context.type.bodyMedium,
                    ),
                  )
                else
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final (int i, (DateTime, int) p)
                          in plan.payments.indexed)
                        ListTile(
                          title: Figures(
                            amount(p.$2),
                            style: context.type.titleSmall,
                          ),
                          subtitle: Text(
                            dayMonth(p.$1),
                            style: context.type.bodySmall,
                          ),
                          trailing: IconButton(
                            tooltip: l.instalPaymentRemove,
                            onPressed: () => own.saveInstalments(
                              plan.withPayments(<(DateTime, int)>[
                                for (final (int j, (DateTime, int) q)
                                    in plan.payments.indexed)
                                  if (j != i) q,
                              ]),
                            ),
                            icon: Icon(
                              Glyph.trash,
                              size: 18,
                              color: context.colors.inkFaint,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                SectionLabel(l.instalSchedule),
                if (rows.isEmpty)
                  Block(
                    child: Text(
                      l.instalNoSchedule,
                      style: context.type.bodyMedium,
                    ),
                  )
                else
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final InstalmentRow r in rows)
                        _ScheduleRow(
                          row: r,
                          paid: r.number <= covered,
                          split: plan.monthlyRate != null,
                          amount: amount,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 2, child: Text(label, style: context.type.bodyMedium)),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: context.type.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.row,
    required this.paid,
    required this.split,
    required this.amount,
  });

  final InstalmentRow row;
  final bool paid;

  /// Whether the interest is known, to show it apart.
  final bool split;
  final String Function(int minor) amount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(
            paid ? Glyph.checkCircle : Glyph.calendarBlank,
            size: 18,
            color: paid ? context.colors.positive : context.colors.inkFaint,
            semanticLabel: paid ? l.instalRowPaid : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.instalRow(row.number, shortDate(row.due)),
                  style: context.type.bodyMedium,
                ),
                Text(
                  split
                      ? l.instalRowSplit(
                          amount(row.interest),
                          amount(row.principal),
                          amount(row.balance),
                        )
                      : l.instalRowLeft(amount(row.balance)),
                  style: context.type.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Figures(amount(row.payment), style: context.type.bodyMedium),
        ],
      ),
    );
  }
}

/// A payment towards the purchase: whole or partial, on a day.
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.ledger,
    required this.asset,
    required this.today,
    required this.suggested,
  });

  final Ledger ledger;
  final Asset asset;
  final DateTime today;
  final int suggested;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.suggested <= 0
        ? ''
        : formatDecimal(
            Decimal.parse('${widget.ledger.major(widget.suggested)}'),
            decimals: widget.asset.decimals,
            trim: true,
          ),
  );
  late DateTime _on = widget.today;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _done() {
    final Decimal? value = parseAmount(_amount.text);
    if (value == null || value <= Decimal.zero) {
      setState(() => _error = context.l10n.instalPaymentInvalid);
      return;
    }
    Navigator.of(context).pop((_on, widget.ledger.minor(value.toDouble())));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      title: Text(l.instalPay),
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
            decoration: InputDecoration(
              labelText: l.instalPaymentAmount,
              errorText: _error,
              prefixText: switch (widget.asset.localSymbol ??
                  widget.asset.symbol) {
                final String sign => '$sign ',
                null => null,
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(l.instalPaymentPartial, style: context.type.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _on,
                firstDate: DateTime(widget.today.year - 5),
                lastDate: widget.today,
              );
              if (picked != null) setState(() => _on = picked);
            },
            icon: const Icon(Glyph.calendarBlank, size: 18),
            label: Text(dayMonth(_on)),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _done, child: Text(l.save)),
      ],
    );
  }
}

/// Adds a purchase in instalments, or changes [plan]. Its payments stay.
Future<void> showInstalmentSheet(
  BuildContext context, {
  required OwnController own,
  Instalments? plan,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) => _InstalmentSheet(own: own, plan: plan),
);

class _InstalmentSheet extends StatefulWidget {
  const _InstalmentSheet({required this.own, this.plan});

  final OwnController own;
  final Instalments? plan;

  @override
  State<_InstalmentSheet> createState() => _InstalmentSheetState();
}

class _InstalmentSheetState extends State<_InstalmentSheet> {
  OwnController get own => widget.own;
  late final Asset _asset = own.profile?.base ?? Asset.cop;
  late final Ledger? _ledger = own.ledger;

  late final TextEditingController _name = TextEditingController(
    text: widget.plan?.name ?? '',
  );
  late final TextEditingController _principal = _money(widget.plan?.principal);
  late final TextEditingController _count = TextEditingController(
    text: widget.plan == null ? '' : '${widget.plan!.count}',
  );
  late final TextEditingController _rate = TextEditingController(
    text: switch (widget.plan?.rate) {
      final double r => formatDecimal(
        Decimal.parse(r.toStringAsFixed(4)),
        decimals: 4,
        trim: true,
      ),
      null => '',
    },
  );
  late final TextEditingController _instalment = _money(
    widget.plan?.instalment,
  );
  late final TextEditingController _fee = _money(widget.plan?.fee, zero: true);
  late final TextEditingController _cash = _money(widget.plan?.cashPrice);
  late RateKind _rateKind = widget.plan?.rateKind ?? RateKind.effectiveAnnual;
  late DateTime _firstDue =
      widget.plan?.firstDue ??
      DateTime(own.today.year, own.today.month + 1, own.today.day);
  // An account deleted or archived since is none the list offers: the
  // purchase reads as paid outside Quincena.
  late String? _accountId = own.accounts
      .where((Account a) => a.id == widget.plan?.accountId)
      .firstOrNull
      ?.id;
  String? _error;

  TextEditingController _money(int? minor, {bool zero = false}) =>
      TextEditingController(
        text: minor == null || _ledger == null || (minor == 0 && !zero)
            ? ''
            : formatDecimal(
                Decimal.parse('${_ledger.major(minor)}'),
                decimals: _asset.decimals,
                trim: true,
              ),
      );

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _principal,
      _count,
      _rate,
      _instalment,
      _fee,
      _cash,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _minor(TextEditingController c) {
    final Decimal? value = parseAmount(c.text);
    final Ledger? ledger = _ledger;
    if (value == null || value < Decimal.zero || ledger == null) return null;
    return ledger.minor(value.toDouble());
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final int? principal = _minor(_principal);
    final int? count = int.tryParse(_count.text.trim());
    if (_name.text.trim().isEmpty ||
        principal == null ||
        principal <= 0 ||
        count == null ||
        count < 1 ||
        count > 360) {
      setState(() => _error = l.instalIncomplete);
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final Instalments? old = widget.plan;
    final int? instalment = _minor(_instalment);
    await own.saveInstalments(
      Instalments(
        id: old?.id ?? 'instalments-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        principal: principal,
        count: count,
        firstDue: _firstDue,
        rate: parseAmount(_rate.text)?.toDouble(),
        rateKind: _rateKind,
        instalment: instalment == null || instalment <= 0 ? null : instalment,
        fee: _minor(_fee),
        cashPrice: switch (_minor(_cash)) {
          final int c when c > 0 => c,
          _ => null,
        },
        accountId: _accountId,
        payments: old?.payments ?? const <(DateTime, int)>[],
      ),
    );
    navigator.pop();
  }

  Widget _amountField(
    TextEditingController c,
    String label, {
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        AmountInputFormatter(maxDecimals: _asset.decimals),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
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
    final Account? account = _accountId == null
        ? null
        : own.snapshot?.account(_accountId!);
    final List<Account> accounts = <Account>[
      for (final Account a in own.accounts)
        if (a.kind == AccountKind.card) a,
      for (final Account a in own.accounts)
        if (a.kind != AccountKind.card) a,
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
              widget.plan == null ? l.instalAdd : l.instalEdit,
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(l.instalSheetBody, style: context.type.bodySmall),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.instalName),
              ),
            ),
            _amountField(_principal, l.instalPrincipal),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _count,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(labelText: l.instalCountField),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final DateTime today = own.today;
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _firstDue,
                  firstDate: DateTime(today.year - 5),
                  lastDate: DateTime(today.year + 5),
                );
                if (picked != null) setState(() => _firstDue = picked);
              },
              icon: const Icon(Glyph.calendarBlank, size: 18),
              label: Text(l.instalFirstDue(dayMonth(_firstDue))),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      AmountInputFormatter(maxDecimals: 4),
                    ],
                    decoration: InputDecoration(
                      labelText: l.instalRateField,
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<RateKind>(
                    icon: const Icon(Glyph.caretDown, size: 18),
                    initialValue: _rateKind,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.instalRateKind),
                    items: <DropdownMenuItem<RateKind>>[
                      for (final RateKind k in RateKind.values)
                        DropdownMenuItem<RateKind>(
                          value: k,
                          child: Text(rateKindLabel(l, k)),
                        ),
                    ],
                    onChanged: (RateKind? k) =>
                        setState(() => _rateKind = k ?? _rateKind),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(l.instalRateHelp, style: context.type.bodySmall),
            ),
            _amountField(
              _instalment,
              l.instalStated,
              helper: l.instalStatedHelp,
            ),
            _amountField(_fee, l.instalFeeField, helper: l.instalFeeHelp),
            _amountField(_cash, l.instalCash, helper: l.instalCashHelp),
            DropdownButtonFormField<String?>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _accountId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.instalPaysFrom),
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(child: Text(l.instalOutside)),
                for (final Account a in accounts)
                  DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
              ],
              onChanged: (String? id) => setState(() => _accountId = id),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(
                account != null && account.spendable
                    ? l.instalCountedOnce
                    : l.instalCountedAsComing,
                style: context.type.bodySmall,
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
