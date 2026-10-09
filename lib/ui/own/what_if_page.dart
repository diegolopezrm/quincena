import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/plan.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'amount_input.dart';
import 'look.dart';

/// One change tried against things as they are: saving more on each
/// payday, a fixed charge going up, or the pay arriving late. Nothing
/// changes until the person applies it, and saving a scenario applies
/// nothing.
class WhatIfPage extends StatefulWidget {
  const WhatIfPage({super.key, required this.own});

  final OwnController own;

  @override
  State<WhatIfPage> createState() => _WhatIfPageState();
}

class _WhatIfPageState extends State<WhatIfPage> {
  ScenarioKind _kind = ScenarioKind.saveMore;
  final TextEditingController _amount = TextEditingController();
  int _days = 5;
  String? _charge;

  /// Whether the day to day's usual spending counts, when it is known.
  bool _daily = true;

  OwnController get own => widget.own;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Scenario? _scenario(Ledger ledger) {
    final Decimal? typed = parseAmount(_amount.text);
    final int amount = typed == null || typed <= Decimal.zero
        ? 0
        : ledger.minor(typed.toDouble());
    return switch (_kind) {
      ScenarioKind.saveMore when amount > 0 => Scenario(
        id: 'save-$amount',
        kind: ScenarioKind.saveMore,
        amount: amount,
      ),
      ScenarioKind.chargeUp when amount > 0 && _charge != null => Scenario(
        id: 'charge-$_charge-$amount',
        kind: ScenarioKind.chargeUp,
        amount: amount,
        chargeName: _charge,
      ),
      ScenarioKind.payLate when ledger.pay != null => Scenario(
        id: 'late-$_days',
        kind: ScenarioKind.payLate,
        days: _days,
      ),
      _ => null,
    };
  }

  String _describe(AppLocalizations l, Ledger ledger, Scenario x) =>
      switch (x.kind) {
        ScenarioKind.saveMore => l.whatIfSaveMoreSaid(
          pesos(ledger.major(x.amount)),
        ),
        ScenarioKind.chargeUp => l.whatIfChargeUpSaid(
          x.chargeName ?? '',
          pesos(ledger.major(x.amount)),
        ),
        ScenarioKind.payLate => l.whatIfPayLateSaid(x.days),
      };

  /// Goals still short of what they are for: where saving more can go.
  List<SavingsGoal> get _openGoals => <SavingsGoal>[
    for (final SavingsGoal g in own.snapshot?.goals ?? const <SavingsGoal>[])
      if (g.saved.amount < g.target.amount) g,
  ];

  Future<void> _apply(Ledger ledger, Scenario x) async {
    final AppLocalizations l = context.l10n;
    final List<RecurringCharge> charges =
        own.snapshot?.recurring ?? const <RecurringCharge>[];
    final RecurringCharge? charge = charges
        .where((RecurringCharge r) => r.name == x.chargeName && r.active)
        .firstOrNull;
    // Saving more each payday is a goal's monthly part going up by what
    // the paydays of a month add.
    final Decimal more = Decimal.parse(
      '${ledger.major((x.amount * paydaysPerMonth(ledger)).round())}',
    );
    final List<SavingsGoal> goals = _openGoals;
    SavingsGoal? goal = goals.firstOrNull;
    String money(Money m) => moneyText(m, base: own.profile?.base);
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          scrollable: true,
          title: Text(l.whatIfApplyTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (x.kind == ScenarioKind.saveMore && goals.length > 1) ...[
                DropdownButtonFormField<String>(
                  icon: const Icon(Glyph.caretDown, size: 18),
                  initialValue: goal?.id,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.whatIfApplyGoal),
                  items: <DropdownMenuItem<String>>[
                    for (final SavingsGoal g in goals)
                      DropdownMenuItem<String>(
                        value: g.id,
                        child: Text(g.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (String? id) => setState(
                    () =>
                        goal = goals.firstWhere((SavingsGoal g) => g.id == id),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(switch ((x.kind, charge, goal)) {
                (ScenarioKind.chargeUp, final RecurringCharge c, _) =>
                  l.whatIfApplyCharge(
                    c.name,
                    money(
                      Money(
                        c.amount.amount +
                            Decimal.parse(ledger.major(x.amount).toString()),
                        c.amount.asset,
                      ),
                    ),
                  ),
                (ScenarioKind.saveMore, _, final SavingsGoal g) =>
                  l.whatIfApplyGoalSays(
                    g.name,
                    money(g.monthly),
                    money(Money(g.monthly.amount + more, g.monthly.asset)),
                  ),
                _ => l.whatIfApplySave,
              }),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.whatIfApply),
            ),
          ],
        ),
      ),
    );
    if (sure != true) return;
    if (x.kind == ScenarioKind.chargeUp && charge != null) {
      await own.store.updateRecurring(
        charge.id,
        amount: Money(
          charge.amount.amount +
              Decimal.parse(ledger.major(x.amount).toString()),
          charge.amount.asset,
        ),
      );
    }
    if (x.kind == ScenarioKind.saveMore && goal != null) {
      final SavingsGoal g = goal!;
      await own.saveGoalMonthly(
        g,
        Money(g.monthly.amount + more, g.monthly.asset),
      );
    }
    // Applied, it is no longer something to try: kept, it would be weighed
    // again on top of what it changed.
    if (own.scenarios.any((Scenario s) => s.id == x.id)) {
      await own.saveScenarios(<Scenario>[
        for (final Scenario s in own.scenarios)
          if (s.id != x.id) s,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      if (ledger == null) return Scaffold(appBar: AppBar());
      String amount(int minor) => pesos(ledger.major(minor));
      final List<String> charges = <String>{
        for (final Movement m in ledger.upcoming) m.merchant,
      }.toList()..sort();
      final Scenario? scenario = _scenario(ledger);
      // Without the day to day, every figure would come out as if nothing
      // were spent until then.
      final int? usual = switch (usualDailySpending(ledger)) {
        final int u when u > 0 => u,
        _ => null,
      };
      final int daily = _daily ? usual ?? 0 : 0;
      final ScenarioOutcome? outcome = scenario == null
          ? null
          : weighScenario(ledger, scenario, daily: daily);
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.whatIfTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                SegmentedButton<ScenarioKind>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<ScenarioKind>>[
                    ButtonSegment<ScenarioKind>(
                      value: ScenarioKind.saveMore,
                      label: Text(l.whatIfSaveMore),
                    ),
                    ButtonSegment<ScenarioKind>(
                      value: ScenarioKind.chargeUp,
                      label: Text(l.whatIfChargeUp),
                    ),
                    ButtonSegment<ScenarioKind>(
                      value: ScenarioKind.payLate,
                      label: Text(l.whatIfPayLate),
                    ),
                  ],
                  selected: <ScenarioKind>{_kind},
                  onSelectionChanged: (Set<ScenarioKind> s) =>
                      setState(() => _kind = s.single),
                ),
                const SizedBox(height: 16),
                if (_kind == ScenarioKind.chargeUp) ...<Widget>[
                  if (charges.isEmpty)
                    Text(l.whatIfNoCharges, style: context.type.bodyMedium)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String c in charges)
                          ChoiceChip(
                            label: Text(c),
                            selected: _charge == c,
                            onSelected: (_) => setState(() => _charge = c),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                ],
                if (_kind != ScenarioKind.payLate)
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      AmountInputFormatter(
                        maxDecimals: ledger.currency.decimals,
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _kind == ScenarioKind.saveMore
                          ? l.whatIfSaveMoreAmount
                          : l.whatIfChargeUpAmount,
                      prefixText: r'$ ',
                    ),
                  )
                else if (ledger.pay == null)
                  Text(l.whatIfNeedsPay, style: context.type.bodyMedium)
                else
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l.whatIfPayLateDays(_days),
                          style: context.type.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: l.whatIfFewerDays,
                        onPressed: _days > 1
                            ? () => setState(() => _days--)
                            : null,
                        icon: const Icon(Glyph.minusCircle),
                      ),
                      IconButton(
                        tooltip: l.whatIfMoreDays,
                        onPressed: _days < 30
                            ? () => setState(() => _days++)
                            : null,
                        icon: const Icon(Glyph.plusCircle),
                      ),
                    ],
                  ),
                if (usual != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _daily,
                    onChanged: (bool on) => setState(() => _daily = on),
                    title: Text(l.whatIfDaily, style: context.type.bodyMedium),
                    subtitle: Text(
                      l.whatIfDailyAbout(amount(usual)),
                      style: context.type.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                if (outcome != null && scenario != null) ...<Widget>[
                  Block(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _Compare(
                          label: l.whatIfLowest,
                          now:
                              '${amount(outcome.lowestNow.likely)} · ${dayShortMonth(outcome.lowestNow.date)}',
                          tried:
                              '${amount(outcome.lowestTried.likely)} · ${dayShortMonth(outcome.lowestTried.date)}',
                        ),
                        _Compare(
                          label: l.whatIfTight,
                          now: outcome.tightNow == null
                              ? l.whatIfNoTight
                              : dayShortMonth(outcome.tightNow!),
                          tried: outcome.tightTried == null
                              ? l.whatIfNoTight
                              : dayShortMonth(outcome.tightTried!),
                        ),
                        _Compare(
                          label: l.whatIfEnd(
                            dayShortMonth(outcome.tried.days.last.date),
                          ),
                          now: amount(outcome.endNow),
                          tried: amount(outcome.endTried),
                        ),
                        if (scenario.kind == ScenarioKind.saveMore)
                          for (final GoalShare g in own.goalShares)
                            if (arrival(
                                  g,
                                  from: own.today,
                                  monthly:
                                      g.monthly +
                                      (scenario.amount *
                                              paydaysPerMonth(ledger))
                                          .round(),
                                )
                                case final DateTime sooner)
                              _Compare(
                                label: l.whatIfGoal(g.name),
                                now: switch (arrival(g, from: own.today)) {
                                  final DateTime d => monthYear(d),
                                  null => l.whatIfGoalNever,
                                },
                                tried: monthYear(sooner),
                              ),
                        const SizedBox(height: 6),
                        Text(switch (usual) {
                          null => l.whatIfNoDailyYet,
                          _ when daily > 0 => l.whatIfAssumesDaily(
                            amount(daily),
                          ),
                          _ => l.whatIfAssumesNoDaily,
                        }, style: context.type.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed:
                            own.scenarios.any(
                              (Scenario s) => s.id == scenario.id,
                            )
                            ? null
                            : () => own.saveScenarios(<Scenario>[
                                ...own.scenarios,
                                scenario,
                              ]),
                        child: Text(l.whatIfSave),
                      ),
                      if (scenario.kind == ScenarioKind.chargeUp ||
                          (scenario.kind == ScenarioKind.saveMore &&
                              _openGoals.isNotEmpty))
                        TextButton(
                          onPressed: () => _apply(ledger, scenario),
                          child: Text(l.whatIfApply),
                        ),
                    ],
                  ),
                ],
                if (own.scenarios.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  SectionLabel(l.whatIfSaved),
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final Scenario x in own.scenarios)
                        ListTile(
                          title: Text(
                            _describe(l, ledger, x),
                            style: context.type.bodyMedium,
                          ),
                          subtitle: Text(switch (weighScenario(
                            ledger,
                            x,
                            daily: daily,
                          )) {
                            final ScenarioOutcome o => l.whatIfSavedOutcome(
                              amount(o.lowestTried.likely),
                              dayShortMonth(o.lowestTried.date),
                            ),
                          }, style: context.type.bodySmall),
                          trailing: IconButton(
                            tooltip: l.whatIfRemove,
                            onPressed: () => own.saveScenarios(<Scenario>[
                              for (final Scenario s in own.scenarios)
                                if (s.id != x.id) s,
                            ]),
                            icon: Icon(
                              Glyph.trash,
                              size: 18,
                              color: context.colors.inkFaint,
                            ),
                          ),
                        ),
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

class _Compare extends StatelessWidget {
  const _Compare({required this.label, required this.now, required this.tried});

  final String label;
  final String now;
  final String tried;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, style: context.type.labelMedium),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${l.whatIfToday}: $now',
                  style: context.type.bodyMedium,
                ),
              ),
              Expanded(
                child: Text(
                  '${l.whatIfWith}: $tried',
                  style: context.type.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
