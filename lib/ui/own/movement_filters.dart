import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/pay_schedule.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/movement_search.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'amount_input.dart';
import 'look.dart';

/// Opens the filters of Movimientos over the list. Each choice applies as
/// it is made, through [onChanged], so the list behind follows, and the
/// button at the end says how many movements are left: [count] works it
/// out for a filter. [entries] are the movements listed, whose accounts and
/// categories are the ones offered.
Future<void> showMovementFilters(
  BuildContext context, {
  required OwnController own,
  required MovementFilter filter,
  required List<Entry> entries,
  required int Function(MovementFilter filter) count,
  required ValueChanged<MovementFilter> onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) => _FilterSheet(
    own: own,
    filter: filter,
    entries: entries,
    count: count,
    onChanged: onChanged,
  ),
);

/// What a day filter is called: the pay period by how the person is paid,
/// the days picked by the days.
String daysLabel(
  AppLocalizations l,
  MovementFilter filter,
  PaySchedule? schedule,
) => switch (filter.days) {
  null => l.filterAnyDate,
  // Paid twice a month or every two weeks, the period is the quincena.
  MovementDays.period =>
    schedule is TwiceMonthly || schedule is EveryTwoWeeks
        ? l.filterThisPeriod
        : l.filterSincePayday,
  MovementDays.thisMonth => l.filterThisMonth,
  MovementDays.lastMonth => l.filterLastMonth,
  MovementDays.range => switch ((filter.from, filter.to)) {
    (final DateTime from, final DateTime to) => dayRange(from, to),
    _ => l.filterPickDays,
  },
};

String typeLabel(AppLocalizations l, MovementType? type) => switch (type) {
  null => l.filterAnyType,
  MovementType.expenses => l.filterExpenses,
  MovementType.incomes => l.filterIncomes,
  MovementType.transfers => l.filterTransfers,
};

/// The amount a filter keeps, as a chip says it.
String amountLabel(AppLocalizations l, MovementFilter filter, Asset base) {
  String said(Decimal value) => moneyText(Money(value, base), base: base);
  return switch ((filter.min, filter.max)) {
    (final Decimal min, final Decimal max) => l.filterAmountBetween(
      said(min),
      said(max),
    ),
    (final Decimal min, null) => l.filterAmountAtLeast(said(min)),
    (null, final Decimal max) => l.filterAmountAtMost(said(max)),
    _ => '',
  };
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.own,
    required this.filter,
    required this.entries,
    required this.count,
    required this.onChanged,
  });

  final OwnController own;
  final MovementFilter filter;
  final List<Entry> entries;
  final int Function(MovementFilter filter) count;
  final ValueChanged<MovementFilter> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MovementFilter _filter = widget.filter;
  late final TextEditingController _min = TextEditingController(
    text: _text(widget.filter.min),
  );
  late final TextEditingController _max = TextEditingController(
    text: _text(widget.filter.max),
  );

  OwnController get own => widget.own;
  Asset get _base => own.profile?.base ?? Asset.cop;

  String _text(Decimal? value) => value == null
      ? ''
      : formatDecimal(value, decimals: _base.decimals, trim: true);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _set(MovementFilter filter) {
    setState(() => _filter = filter);
    widget.onChanged(filter);
  }

  void _clear() {
    _min.clear();
    _max.clear();
    _set(const MovementFilter());
  }

  Future<void> _pickDays() async {
    final DateTime today = own.today;
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 2, 12, 31),
      // The days picked before, or this month so far: the calendar opens
      // on days, not on «Fecha de inicio», which does not fit its header
      // with large text.
      initialDateRange: switch ((_filter.from, _filter.to)) {
        (final DateTime from, final DateTime to) => DateTimeRange(
          start: from,
          end: to,
        ),
        _ => DateTimeRange(
          start: DateTime(today.year, today.month),
          end: today,
        ),
      },
      currentDate: today,
    );
    if (picked == null || !mounted) return;
    _set(
      _filter.copyWith(
        days: MovementDays.range,
        from: picked.start,
        to: picked.end,
      ),
    );
  }

  /// The accounts the movements are in, by either end of a transfer, in
  /// the order Cuentas lists them; and those already chosen.
  List<Account> _accounts() {
    final Set<String> used = <String>{
      for (final Entry e in own.snapshot?.entries ?? const <Entry>[])
        e.accountId,
      ..._filter.accounts,
    };
    return <Account>[
      for (final Account a in own.snapshot?.accounts ?? const <Account>[])
        if (used.contains(a.id)) a,
    ];
  }

  /// The categories the movements are filed under, in the order the
  /// person keeps them; and those already chosen.
  List<String> _categories() {
    final Set<String> used = <String>{
      for (final Entry e in widget.entries) ?e.category,
      ..._filter.categories,
    };
    return <String>[
      for (final CategoryItem c in own.categories)
        if (used.contains(c.key)) c.key,
    ];
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: context.type.labelMedium),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _amountField(
    TextEditingController controller,
    String label,
    void Function(Decimal? value) onChanged,
  ) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: <TextInputFormatter>[
      AmountInputFormatter(maxDecimals: _base.decimals),
    ],
    onChanged: (String text) {
      final Decimal? value = parseAmount(text);
      onChanged(value == null || value < Decimal.zero ? null : value);
    },
    // The button that shows what is left comes above the keyboard with it.
    scrollPadding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      40 + MediaQuery.textScalerOf(context).scale(48),
    ),
    decoration: InputDecoration(
      labelText: label,
      prefixText: amountPrefix(_base),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final MovementFilter f = _filter;
    final bool large = largeText(context);
    final List<Account> accounts = _accounts();
    final List<String> categories = _categories();
    final Widget min = _amountField(
      _min,
      l.filterAmountMin,
      (Decimal? v) => _set(_filter.copyWith(min: v, clearMin: v == null)),
    );
    final Widget max = _amountField(
      _max,
      l.filterAmountMax,
      (Decimal? v) => _set(_filter.copyWith(max: v, clearMax: v == null)),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.filterTitle, style: context.type.headlineMedium),
            const SizedBox(height: 16),
            _section(
              l.filterType,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final MovementType? type in <MovementType?>[
                    null,
                    ...MovementType.values,
                  ])
                    ChoiceChip(
                      label: Text(typeLabel(l, type)),
                      selected: f.type == type,
                      onSelected: (_) =>
                          _set(f.copyWith(type: type, clearType: type == null)),
                    ),
                ],
              ),
            ),
            _section(
              l.filterDates,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final MovementDays? days in <MovementDays?>[
                    null,
                    MovementDays.period,
                    MovementDays.thisMonth,
                    MovementDays.lastMonth,
                  ])
                    ChoiceChip(
                      label: Text(
                        daysLabel(
                          l,
                          MovementFilter(days: days),
                          own.profile?.schedule,
                        ),
                      ),
                      selected: f.days == days,
                      // Days picked before go with another choice.
                      onSelected: (_) => _set(
                        f.copyWith(clearDays: true).copyWith(days: days),
                      ),
                    ),
                  ChoiceChip(
                    avatar: const Icon(Glyph.calendarBlank, size: 18),
                    label: Text(
                      f.days == MovementDays.range
                          ? daysLabel(l, f, own.profile?.schedule)
                          : l.filterPickDays,
                    ),
                    selected: f.days == MovementDays.range,
                    onSelected: (_) => _pickDays(),
                  ),
                ],
              ),
            ),
            if (accounts.length > 1)
              _section(
                l.filterAccounts,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final Account a in accounts)
                      FilterChip(
                        avatar: Icon(
                          accountIcon(a.kind),
                          size: 18,
                          color: context.colors.inkSoft,
                        ),
                        label: Text(a.name),
                        selected: f.accounts.contains(a.id),
                        onSelected: (bool on) => _set(
                          f.copyWith(
                            accounts: <String>{
                              for (final String id in f.accounts)
                                if (id != a.id) id,
                              if (on) a.id,
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (categories.isNotEmpty)
              _section(
                l.filterCategories,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String key in categories)
                      FilterChip(
                        avatar: Icon(
                          categoryIconFor(key),
                          size: 18,
                          color: categoryColorFor(context, key),
                        ),
                        label: Text(
                          categoryNameFor(context, key, own.categories),
                        ),
                        selected: f.categories.contains(key),
                        onSelected: (bool on) => _set(
                          f.copyWith(
                            categories: <String>{
                              for (final String k in f.categories)
                                if (k != key) k,
                              if (on) key,
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            _section(
              l.filterAmount,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // With large text one field under the other: side by
                  // side neither would show what is typed.
                  if (large) ...<Widget>[
                    min,
                    const SizedBox(height: 12),
                    max,
                  ] else
                    Row(
                      children: <Widget>[
                        Expanded(child: min),
                        const SizedBox(width: 12),
                        Expanded(child: max),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    l.filterAmountHelp(_base.code),
                    style: context.type.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.filterShow(widget.count(f))),
            ),
            if (!f.isEmpty) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(onPressed: _clear, child: Text(l.filterClear)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The parts of [filter] in use, a chip each that takes it away, and a
/// button that takes them all. Under the search, so what narrows the list
/// is always in sight.
class ActiveFilters extends StatelessWidget {
  const ActiveFilters({
    super.key,
    required this.own,
    required this.filter,
    required this.onChanged,
  });

  final OwnController own;
  final MovementFilter filter;
  final ValueChanged<MovementFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final MovementFilter f = filter;
    final Asset base = own.profile?.base ?? Asset.cop;
    final List<(String, MovementFilter)> parts = <(String, MovementFilter)>[
      if (f.type case final MovementType type)
        (typeLabel(l, type), f.copyWith(clearType: true)),
      if (f.days != null)
        (daysLabel(l, f, own.profile?.schedule), f.copyWith(clearDays: true)),
      for (final String id in f.accounts)
        (
          own.snapshot?.account(id)?.name ?? '',
          f.copyWith(
            accounts: <String>{
              for (final String other in f.accounts)
                if (other != id) other,
            },
          ),
        ),
      for (final String key in f.categories)
        (
          categoryNameFor(context, key, own.categories),
          f.copyWith(
            categories: <String>{
              for (final String other in f.categories)
                if (other != key) other,
            },
          ),
        ),
      if (f.min != null || f.max != null)
        (amountLabel(l, f, base), f.copyWith(clearMin: true, clearMax: true)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final (String label, MovementFilter without) in parts)
            ActionChip(
              tooltip: l.filterRemove(label),
              onPressed: () => onChanged(without),
              backgroundColor: context.colors.brandSoft,
              side: BorderSide.none,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: Text(label)),
                  const SizedBox(width: 6),
                  const Icon(Glyph.x, size: 14),
                ],
              ),
            ),
          if (parts.length > 1)
            TextButton(
              onPressed: () => onChanged(const MovementFilter()),
              child: Text(l.filterClear),
            ),
        ],
      ),
    );
  }
}
