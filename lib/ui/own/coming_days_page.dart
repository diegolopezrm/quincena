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
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
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

  List<ProjectedEvent> get _moves => <ProjectedEvent>[
    for (final (ProjectedEvent e, DateTime to)
        in _moved.values) ...<ProjectedEvent>[
      ProjectedEvent(
        date: e.date,
        amount: -e.amount,
        certainty: Certainty.hypothetical,
        kind: ProjectedKind.tryOut,
        label: e.label,
      ),
      ProjectedEvent(
        date: to,
        amount: e.amount,
        certainty: Certainty.hypothetical,
        kind: ProjectedKind.tryOut,
        label: e.label,
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
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      String amount(int minor) => pesos(ledger.major(minor));
      final int price = _trying ? _priceIn(ledger) : 0;
      final List<ProjectedEvent> moves = _moves;
      final PurchaseCheck? check = price > 0
          ? checkPurchase(
              ledger,
              price: price,
              date: _date(ledger),
              label: _what.text.trim(),
              tryOut: moves,
              atLeast: 30,
            )
          : null;
      final Projection projection =
          check?.projection ??
          Projection.of(ledger, horizon: 30, tryOut: moves);
      final List<ProjectedDay> days = projection.days.take(31).toList();
      final int selected = math.min(_selected, days.length - 1);
      final ProjectedDay low = projection.lowestBeforePayday;
      final ProjectedDay? tight = projection.firstTight;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _trying ? l.buyTitle : l.comingTitle,
            style: context.type.titleLarge,
          ),
          actions: <Widget>[
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
                      Text(
                        (check == null
                            ? l.comingLowest
                            : l.comingLowestWithout)(
                          amount(low.sure),
                          dayShortMonth(low.date),
                        ),
                        style: context.type.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tight != null
                            ? l.comingTight(dayShortMonth(tight.date))
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
                        cushion: ledger.cushion,
                        selected: selected,
                        onSelect: (int i) => setState(() => _selected = i),
                        semanticsLabel: l.comingLowest(
                          amount(low.sure),
                          dayShortMonth(low.date),
                        ),
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
                          if (ledger.cushion > 0)
                            _Key(
                              color: context.colors.caution,
                              text: l.comingLegendCushion(
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
                  onMove: (ProjectedEvent e) => _move(e, ledger),
                  highlighted: true,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < days.length; i++)
                  if (i != selected && days[i].events.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _selected = i),
                      child: _DayDetail(
                        day: days[i],
                        ledger: ledger,
                        onMove: (ProjectedEvent e) => _move(e, ledger),
                      ),
                    ),
                if (days.every((ProjectedDay d) => d.events.isEmpty))
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
    required this.price,
    required this.what,
    required this.when,
    required this.other,
    required this.payday,
    required this.onChanged,
    required this.onWhen,
  });

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
          inputFormatters: <TextInputFormatter>[AmountInputFormatter()],
          style: context.type.headlineMedium,
          decoration: InputDecoration(labelText: l.buyPrice, prefixText: r'$ '),
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
    final String on = dayShortMonth(check.lowestOn);
    final (
      String title,
      String body,
      Color tone,
      Color ground,
    ) = switch (check.verdict) {
      PurchaseVerdict.fits => (
        l.buyFits,
        ledger.cushion > 0
            ? l.buyFitsBody(amount(check.lowest), on)
            : l.buyFitsBodyNoCushion(amount(check.lowest), on),
        context.colors.positive,
        context.colors.brandSoft,
      ),
      PurchaseVerdict.belowCushion => (
        l.buyBelow,
        l.buyBelowBody(on, amount(check.lowest), amount(ledger.cushion)),
        context.colors.caution,
        context.colors.cautionSoft,
      ),
      PurchaseVerdict.short => (
        l.buyShort,
        l.buyShortBody(on, amount(-check.lowest)),
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
            l.buyLowest(pesos(ledger.major(c.lowest))),
            style: context.type.titleSmall?.copyWith(
              color: switch (c.verdict) {
                PurchaseVerdict.fits => context.colors.ink,
                PurchaseVerdict.belowCushion => context.colors.caution,
                PurchaseVerdict.short => context.colors.negative,
              },
            ),
          ),
          Text(switch (c.verdict) {
            PurchaseVerdict.fits => l.buyFits,
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
    required this.onMove,
    this.highlighted = false,
  });

  final ProjectedDay day;
  final Ledger ledger;
  final ValueChanged<ProjectedEvent> onMove;
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
    final bool under = day.sure < ledger.cushion;
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
                  if (day.likely != day.sure)
                    l.comingLeftTrying(amount(day.likely)),
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
                    l.comingUnderCushion,
                    style: context.type.labelSmall?.copyWith(
                      color: context.colors.caution,
                    ),
                  ),
                ),
            ],
          ),
          for (final ProjectedEvent e in day.events)
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
                if (e.certainty == Certainty.scheduled && e.amount < 0)
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
