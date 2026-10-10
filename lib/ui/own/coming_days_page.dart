import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/decisions.dart';
import '../../domain/projection.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import '../standing.dart' show sentence;
import 'amount_input.dart';
import 'close_page.dart';
import 'coming_chart.dart';

enum _When { today, afterPay, other }

/// The next 30 days of the money to spend, and what buying something would
/// do to them. Nothing tried here is saved: a purchase and a charge moved
/// to another day only change the dashed line.
class ComingDaysPage extends StatefulWidget {
  const ComingDaysPage({
    super.key,
    required this.own,
    this.tryPurchase = false,
    this.price,
    this.label,
  });

  final OwnController own;

  /// Opens with the purchase to try, as "¿Me alcanza?" does.
  final bool tryPurchase;

  /// A purchase already known, as a wish is: its price in the ledger's
  /// unit, and what it is.
  final int? price;
  final String? label;

  @override
  State<ComingDaysPage> createState() => _ComingDaysPageState();
}

class _ComingDaysPageState extends State<ComingDaysPage> {
  late bool _trying = widget.tryPurchase;
  final TextEditingController _price = TextEditingController();
  final TextEditingController _what = TextEditingController();
  _When _when = _When.today;
  DateTime? _other;

  /// Charges moved to another day in the simulation.
  final Map<String, (ProjectedEvent, DateTime)> _moved =
      <String, (ProjectedEvent, DateTime)>{};
  int _selected = 0;

  OwnController get own => widget.own;

  @override
  void initState() {
    super.initState();
    final int? price = widget.price;
    final Ledger? ledger = own.ledger;
    if (price != null && ledger != null) {
      _price.text = formatDecimal(
        Decimal.parse(ledger.major(price).toString()),
        decimals: ledger.currency.decimals,
        trim: true,
      );
    }
    _what.text = widget.label ?? '';
  }

  @override
  void dispose() {
    _price.dispose();
    _what.dispose();
    super.dispose();
  }

  static String _key(ProjectedEvent e) =>
      '${e.kind.name}|${e.label}|${e.date.toIso8601String()}|${e.amount}';

  // A charge moved stays as sure as it was, on its new day, said as moved;
  // on its old day it and what takes it back cancel out of sight.
  List<ProjectedEvent> get _moves => <ProjectedEvent>[
    for (final (ProjectedEvent e, DateTime to)
        in _moved.values) ...<ProjectedEvent>[
      ProjectedEvent(
        date: e.date,
        amount: -e.amount,
        certainty: Certainty.scheduled,
        kind: ProjectedKind.tryOut,
        label: e.label,
      ),
      ProjectedEvent(
        date: to,
        amount: e.amount,
        certainty: Certainty.scheduled,
        kind: ProjectedKind.tryOut,
        label: context.l10n.comingMovedFrom(e.label, dayShortMonth(e.date)),
      ),
    ],
  ];

  int _priceIn(Ledger ledger) {
    final Decimal? typed = parseAmount(_price.text);
    if (typed == null || typed <= Decimal.zero) return 0;
    return ledger.minor(typed.toDouble());
  }

  DateTime _date(Ledger ledger) => switch (_when) {
    _When.today => ledger.today,
    _When.afterPay => ledger.nextPayday.add(const Duration(days: 1)),
    _When.other => _other ?? ledger.today,
  };

  Future<void> _pickOther(Ledger ledger) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _other ?? ledger.today,
      firstDate: ledger.today,
      lastDate: ledger.today.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _other = picked;
        _when = _When.other;
      });
    }
  }

  Future<void> _move(ProjectedEvent e, Ledger ledger) async {
    final DateTime? to = await showDatePicker(
      context: context,
      initialDate: e.date,
      firstDate: ledger.today,
      lastDate: ledger.today.add(const Duration(days: 60)),
      helpText: context.l10n.comingMove,
    );
    if (to != null && to != e.date) {
      setState(() => _moved[_key(e)] = (e, to));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      if (ledger == null) {
        return Scaffold(
          appBar: AppBar(),
          body: LoadingShapes(label: l.accountsLoading),
        );
      }
      String amount(int minor) => pesos(ledger.major(minor));
      final int price = _trying ? _priceIn(ledger) : 0;
      final List<ProjectedEvent> moves = _moves;
      final int horizon = comingHorizon(ledger);
      final PurchaseCheck? check = price > 0
          ? checkPurchase(
              ledger,
              price: price,
              date: _date(ledger),
              label: _what.text.trim(),
              tryOut: moves,
              atLeast: horizon,
            )
          : null;
      // What is scheduled, over the same days Inicio looks at: the lowest
      // point and the first tight day are told from it, whatever is tried.
      final Projection scheduled = Projection.of(
        ledger,
        horizon: horizon,
        tryOut: moves,
      );
      final Projection projection = check?.projection ?? scheduled;
      final List<ProjectedDay> days = projection.days
          .take(horizon + 1)
          .toList();
      final int selected = math.min(_selected, days.length - 1);
      final ProjectedDay low = scheduled.lowestBeforePayday;
      // Judged as «Puedes gastar» is: a day is tight when it would take
      // from what is kept apart, and the lowest point is what stays free.
      final ProjectedDay? tight = scheduled.firstTouchingKept;
      final String lowOn = dayOrToday(l, low.date, ledger.today);
      final int free = scheduled.free(low);
      final String lowest = free < 0
          ? (check == null ? l.comingShortLowest : l.comingShortLowestWithout)(
              amount(-free),
              lowOn,
            )
          : (check == null ? l.comingFreeLowest : l.comingFreeLowestWithout)(
              amount(free),
              lowOn,
            );
      // Whether the dashed line has something tried in it, or only the
      // money expected.
      final bool trying = moves.isNotEmpty || check != null;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _trying ? l.buyTitle : l.comingTitle,
            style: context.type.titleLarge,
          ),
          // Trying a purchase has nothing to do with the period's close.
          actions: <Widget>[
            if (!_trying)
              IconButton(
                tooltip: l.comingClose,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => ClosePage(own: own),
                  ),
                ),
                icon: const Icon(Glyph.receipt),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: <Widget>[
                if (_trying) ...<Widget>[
                  _PurchaseForm(
                    asset: ledger.currency,
                    price: _price,
                    what: _what,
                    when: _when,
                    other: _other,
                    payday: ledger.nextPayday,
                    onChanged: () => setState(() {}),
                    onWhen: (_When w) => w == _When.other
                        ? _pickOther(ledger)
                        : setState(() => _when = w),
                  ),
                  const SizedBox(height: 16),
                  if (check != null) ...<Widget>[
                    _Verdict(check: check, ledger: ledger),
                    const SizedBox(height: 12),
                    _Compare(
                      ledger: ledger,
                      price: price,
                      label: _what.text.trim(),
                      moves: moves,
                    ),
                    const SizedBox(height: 16),
                  ],
                ] else ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => setState(() => _trying = true),
                      icon: const Icon(Glyph.shoppingBag, size: 18),
                      label: Text(l.buyTitle),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_moved.isNotEmpty) ...<Widget>[
                  Block(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.comingSimulation,
                          style: context.type.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => setState(_moved.clear),
                          child: Text(l.comingClearSimulation),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Block(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(lowest, style: context.type.titleSmall),
                      if (scheduled.kept > 0) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          keptLine(l, ledger, amount),
                          style: context.type.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        tight != null
                            ? keptWarning(l, ledger)(
                                sentence(
                                  dayOrToday(l, tight.date, ledger.today),
                                ),
                              )
                            : keepsMoreThanCushion(ledger)
                            ? l.comingNoTouchKept
                            : ledger.cushion > 0
                            ? l.comingNoTight
                            : l.comingNoTightZero,
                        style: context.type.bodySmall?.copyWith(
                          color: tight != null ? context.colors.caution : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComingChart(
                        days: days,
                        kept: scheduled.kept,
                        isTight: scheduled.touchesKept,
                        selected: selected,
                        onSelect: (int i) => setState(() => _selected = i),
                        semanticsLabel: lowest,
                        payday: _dayOf(ledger.nextPayday),
                        startLabel: l.buyToday,
                        paydayLabel: l.comingPay,
                        endLabel: dayShortMonth(days.last.date),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: <Widget>[
                          _Key(
                            color: context.colors.brand,
                            text: l.comingLegendSure,
                          ),
                          if (days.any((ProjectedDay d) => d.likely != d.sure))
                            _Key(
                              color: context.colors.inkSoft,
                              text: l.comingLegendLikely,
                              dashed: true,
                            ),
                          if (scheduled.kept > 0)
                            _Key(
                              color: context.colors.caution,
                              text: keepsMoreThanCushion(ledger)
                                  ? l.comingLegendKept(amount(scheduled.kept))
                                  : l.comingLegendCushion(
                                      amount(ledger.cushion),
                                    ),
                              dashed: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _DayDetail(
                  day: days[selected],
                  ledger: ledger,
                  under: scheduled.touchesKept(days[selected]),
                  free: scheduled.free(days[selected]),
                  onMove: (ProjectedEvent e) => _move(e, ledger),
                  trying: trying,
                  highlighted: true,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < days.length; i++)
                  if (i != selected && shownEvents(days[i]).isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _selected = i),
                      child: _DayDetail(
                        day: days[i],
                        ledger: ledger,
                        under: scheduled.touchesKept(days[i]),
                        free: scheduled.free(days[i]),
                        onMove: (ProjectedEvent e) => _move(e, ledger),
                        trying: trying,
                      ),
                    ),
                if (days.every((ProjectedDay d) => shownEvents(d).isEmpty))
                  Text(l.comingNoEvents, style: context.type.bodyMedium),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.text, this.dashed = false});

  final Color color;
  final String text;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        width: 18,
        height: 2,
        child: dashed
            ? Row(
                // An empty ColoredBox takes the smallest height it is
                // allowed, which in a Row is none: the dashes did not show.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < 3; i++) ...<Widget>[
                    Expanded(child: ColoredBox(color: color)),
                    if (i < 2) const SizedBox(width: 2),
                  ],
                ],
              )
            : ColoredBox(color: color),
      ),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: context.type.bodySmall)),
    ],
  );
}

class _PurchaseForm extends StatelessWidget {
  const _PurchaseForm({
    required this.asset,
    required this.price,
    required this.what,
    required this.when,
    required this.other,
    required this.payday,
    required this.onChanged,
    required this.onWhen,
  });

  final Asset asset;
  final TextEditingController price;
  final TextEditingController what;
  final _When when;
  final DateTime? other;
  final DateTime payday;
  final VoidCallback onChanged;
  final ValueChanged<_When> onWhen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: price,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            AmountInputFormatter(maxDecimals: asset.decimals),
          ],
          style: context.type.headlineMedium,
          decoration: InputDecoration(
            labelText: l.buyPrice,
            prefixText: amountPrefix(asset),
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: what,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.buyWhat),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_When>(
          showSelectedIcon: false,
          segments: <ButtonSegment<_When>>[
            ButtonSegment<_When>(value: _When.today, label: Text(l.buyToday)),
            ButtonSegment<_When>(
              value: _When.afterPay,
              label: Text(l.buyAfterPay),
            ),
            ButtonSegment<_When>(
              value: _When.other,
              label: Text(
                when == _When.other && other != null
                    ? dayShortMonth(other!)
                    : l.buyOther,
              ),
            ),
          ],
          selected: <_When>{when},
          onSelectionChanged: (Set<_When> s) => onWhen(s.single),
        ),
      ],
    );
  }
}

/// What the purchase does, in words, and on what it rests.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.check, required this.ledger});

  final PurchaseCheck check;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String amount(int minor) => pesos(ledger.major(minor));
    final String on = dayOrToday(l, check.lowestOn, ledger.today);
    // What it takes from what is kept apart, said by name and amount. The
    // cushion only when the title does not say it already.
    String uses({required bool cushion}) => listOf(l, <String>[
      if (check.usesSetAside > 0) l.buyUsesSetAside(amount(check.usesSetAside)),
      if (check.usesReserve > 0) l.buyUsesReserve(amount(check.usesReserve)),
      if (cushion && check.usesCushion > 0)
        l.buyUsesCushion(amount(check.usesCushion)),
    ]);
    final int free = ledger.freeUntilPayday;
    final String payday = dayMonth(ledger.nextPayday);
    // What stays free is what «Puedes gastar» would say; when the purchase
    // takes from what is kept apart, only the accounts are left to name.
    final int kept = check.projection.kept;
    final String lowest = check.lowest >= kept
        ? l.buyFitsFree(amount(check.lowest - kept), on)
        : l.buyLowestInAccounts(amount(check.lowest), on);
    final (
      String title,
      String body,
      Color tone,
      Color ground,
    ) = switch (check.verdict) {
      PurchaseVerdict.fits => (
        l.buyFits,
        <String>[
          // Before payday it says it is within «Puedes gastar».
          if (!check.afterPay && check.price <= free)
            l.buyWithinFree(amount(free), payday),
          lowest,
        ].join(' '),
        context.colors.positive,
        context.colors.brandSoft,
      ),
      PurchaseVerdict.takesApart => (
        l.buyTakesApart,
        <String>[
          if (check.afterPay)
            l.buyUses(uses(cushion: false))
          else if (free > 0)
            l.buyOverFree(amount(free), payday, uses(cushion: false))
          else
            l.buyNothingFree(payday, uses(cushion: false)),
          lowest,
        ].join(' '),
        context.colors.caution,
        context.colors.cautionSoft,
      ),
      PurchaseVerdict.belowCushion => (
        l.buyBelow,
        <String>[
          l.buyBelowBody(
            sentence(on),
            amount(check.lowest),
            amount(ledger.cushion),
          ),
          if (uses(cushion: false) case final String used when used.isNotEmpty)
            l.buyAlsoUses(used),
        ].join(' '),
        context.colors.caution,
        context.colors.cautionSoft,
      ),
      PurchaseVerdict.short => (
        l.buyShort,
        <String>[
          l.buyShortBody(sentence(on), amount(-check.lowest)),
          if (uses(cushion: true) case final String used when used.isNotEmpty)
            l.buyAlsoUses(used),
        ].join(' '),
        context.colors.negative,
        context.colors.negativeSoft,
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: context.type.titleMedium?.copyWith(color: tone)),
          const SizedBox(height: 4),
          Text(body, style: context.type.bodyMedium),
          if (check.reliesOnPay && ledger.pay != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              l.buyReliesOnPay(
                amount(ledger.pay!),
                dayShortMonth(ledger.nextPayday),
              ),
              style: context.type.bodySmall,
            ),
          ],
          if (check.payUnknown) ...<Widget>[
            const SizedBox(height: 6),
            Text(l.buyPayUnknown, style: context.type.bodySmall),
          ],
          const SizedBox(height: 6),
          Text(l.buyEstimate, style: context.type.bodySmall),
        ],
      ),
    );
  }
}

/// Buying today against waiting for the day after payday.
class _Compare extends StatelessWidget {
  const _Compare({
    required this.ledger,
    required this.price,
    required this.label,
    required this.moves,
  });

  final Ledger ledger;
  final int price;
  final String label;
  final List<ProjectedEvent> moves;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final DateTime after = ledger.nextPayday.add(const Duration(days: 1));
    final PurchaseCheck now = checkPurchase(
      ledger,
      price: price,
      date: ledger.today,
      label: label,
      tryOut: moves,
    );
    final PurchaseCheck later = checkPurchase(
      ledger,
      price: price,
      date: after,
      label: label,
      tryOut: moves,
    );
    Widget side(String title, PurchaseCheck c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: context.type.labelMedium),
          const SizedBox(height: 2),
          Figures(
            // Free as «Puedes gastar» counts it: what is kept apart is out.
            c.lowest >= c.projection.kept
                ? l.buyLowestFree(
                    pesos(ledger.major(c.lowest - c.projection.kept)),
                  )
                : l.buyLowestShort(
                    pesos(ledger.major(c.projection.kept - c.lowest)),
                  ),
            style: context.type.titleSmall?.copyWith(
              color: switch (c.verdict) {
                PurchaseVerdict.fits => context.colors.ink,
                PurchaseVerdict.takesApart ||
                PurchaseVerdict.belowCushion => context.colors.caution,
                PurchaseVerdict.short => context.colors.negative,
              },
            ),
          ),
          Text(switch (c.verdict) {
            PurchaseVerdict.fits => l.buyFits,
            PurchaseVerdict.takesApart => l.buyTakesApart,
            PurchaseVerdict.belowCushion => l.buyBelow,
            PurchaseVerdict.short => l.buyShort,
          }, style: context.type.bodySmall),
          if (c.payUnknown)
            Text(l.buyWithoutPay, style: context.type.bodySmall),
        ],
      ),
    );
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          side(l.buyCompareToday, now),
          const SizedBox(width: 16),
          side(l.buyCompareAfter(dayShortMonth(after)), later),
        ],
      ),
    );
  }
}

/// One day: what happens in it, and what is left after.
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.ledger,
    required this.under,
    required this.free,
    required this.onMove,
    required this.trying,
    this.highlighted = false,
  });

  final ProjectedDay day;
  final Ledger ledger;

  /// Whether the day takes from what is kept apart, or runs out of money,
  /// by the same rule as the line above the chart.
  final bool under;

  /// What will be free that day once what is kept apart is out.
  final int free;
  final ValueChanged<ProjectedEvent> onMove;

  /// Whether something is being tried: without it, what the day would
  /// have besides is only the money expected.
  final bool trying;
  final bool highlighted;

  String _label(AppLocalizations l, ProjectedEvent e) => switch (e.kind) {
    ProjectedKind.pay => l.comingPay,
    ProjectedKind.latePay => l.comingLatePay,
    ProjectedKind.income => l.comingIncome(e.label),
    ProjectedKind.tryOut when e.label.isEmpty => l.comingTryOut,
    _ => e.label,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String amount(int minor) => pesos(ledger.major(minor));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
      decoration: BoxDecoration(
        color: highlighted ? context.colors.surface : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? context.colors.line : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(weekdayDayMonth(day.date), style: context.type.titleSmall),
              Text(
                <String>[
                  l.comingLeft(amount(day.sure)),
                  // What of it is free, when some of it is kept apart: the
                  // same count as «Puedes gastar».
                  if (free != day.sure && free >= 0)
                    l.comingLeftFree(amount(free)),
                  if (day.likely != day.sure)
                    (trying ? l.comingLeftTrying : l.comingLeftExpected)(
                      amount(day.likely),
                    ),
                ].join(' · '),
                style: context.type.bodySmall,
              ),
              if (under)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.cautionSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    keepsMoreThanCushion(ledger)
                        ? l.comingUnderKept
                        : ledger.cushion > 0
                        ? l.comingUnderCushion
                        : l.comingRunsOutBadge,
                    style: context.type.labelSmall?.copyWith(
                      color: context.colors.caution,
                    ),
                  ),
                ),
            ],
          ),
          for (final ProjectedEvent e in shownEvents(day))
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _label(l, e),
                    style: context.type.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Figures(
                  pesos(ledger.major(e.amount), signed: true),
                  style: context.type.bodyMedium?.copyWith(
                    color: e.amount > 0 ? context.colors.positive : null,
                  ),
                ),
                if (e.certainty == Certainty.scheduled &&
                    e.amount < 0 &&
                    e.kind != ProjectedKind.tryOut)
                  IconButton(
                    tooltip: l.comingMove,
                    onPressed: () => onMove(e),
                    icon: Icon(
                      Glyph.calendarBlank,
                      size: 18,
                      color: context.colors.inkSoft,
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
        ],
      ),
    );
  }
}

DateTime _dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// What happens on [day], without a charge moved away and what takes it
/// back: together they are nothing that day.
List<ProjectedEvent> shownEvents(ProjectedDay day) {
  final List<ProjectedEvent> back = <ProjectedEvent>[
    for (final ProjectedEvent e in day.events)
      if (e.kind == ProjectedKind.tryOut && e.amount > 0) e,
  ];
  final List<ProjectedEvent> shown = <ProjectedEvent>[...day.events];
  for (final ProjectedEvent b in back) {
    final ProjectedEvent? moved = shown
        .where(
          (ProjectedEvent e) =>
              e.kind != ProjectedKind.tryOut &&
              e.label == b.label &&
              e.amount == -b.amount,
        )
        .firstOrNull;
    if (moved == null) continue;
    shown
      ..remove(moved)
      ..remove(b);
  }
  return shown;
}

/// [day] as these screens say it in a sentence: «el 3 oct», or «hoy» when
/// it is [today], which is never named as if it were another day.
String dayOrToday(AppLocalizations l, DateTime day, DateTime today) =>
    _dayOf(day) == _dayOf(today) ? l.todayWhen : l.dayWhen(dayShortMonth(day));

/// The least that will be free before payday, said the way «Puedes
/// gastar» says it: what is left once what is kept apart is out, or what
/// would be short. [today] when nothing lowers it before payday.
String comingFreeLine(
  AppLocalizations l, {
  required int free,
  required DateTime on,
  required bool today,
  required bool expecting,
  required String Function(int minor) amount,
}) {
  if (free < 0) {
    final String short = amount(-free);
    if (today) return l.comingShortLineToday(short);
    return (expecting ? l.comingShortLineSure : l.comingShortLine)(
      short,
      dayMonth(on),
    );
  }
  if (today) return l.comingFreeLineToday(amount(free));
  return (expecting ? l.comingFreeLineSure : l.comingFreeLine)(
    amount(free),
    dayMonth(on),
  );
}

/// What stays kept apart besides what is free, by name: the reserve, the
/// envelopes and the cushion, each only when there is some.
String keptLine(
  AppLocalizations l,
  Ledger ledger,
  String Function(int minor) amount,
) => l.comingKept(
  listOf(l, <String>[
    if (ledger.reserved > 0) l.comingKeptReserve(amount(ledger.reserved)),
    if (ledger.setAside > 0) l.comingKeptEnvelopes(amount(ledger.setAside)),
    if (ledger.cushion > 0) l.comingKeptCushion(amount(ledger.cushion)),
  ]),
);

/// Whether more than the cushion is kept apart: the envelopes or the
/// reserve. With only a cushion, going under it keeps its own words.
bool keepsMoreThanCushion(Ledger ledger) =>
    ledger.setAside > 0 || ledger.reserved > 0;

/// How the first day that takes from what is kept apart is told: out of
/// money when nothing is kept apart, under the cushion when it is all
/// there is, touching what is kept apart otherwise.
String Function(String when) keptWarning(AppLocalizations l, Ledger ledger) =>
    keepsMoreThanCushion(ledger)
    ? l.comingTouchesKept
    : ledger.cushion > 0
    ? l.comingTight
    : l.comingRunsOut;

/// [items] said as one list: «a, b y c».
String listOf(AppLocalizations l, List<String> items) => items.length < 2
    ? items.join()
    : l.listAnd(
        items.take(items.length - 1).join(', '),
        items.last,
        // Each item here starts with an amount.
        'other',
      );
