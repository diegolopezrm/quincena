import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/merchants.dart' show normalize;
import '../../domain/records.dart';
import '../../domain/shared.dart';
import '../../domain/trips.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../money/rates.dart';
import '../../own/own_controller.dart';
import '../../own/undo.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import '../messages.dart';
import 'amount_input.dart';
import 'coming_days_page.dart' show listOf;
import 'entry_sheet.dart';
import 'look.dart';
import 'put_away_page.dart' show PutAwayRow;
import 'shared_page.dart';
import 'split_sheet.dart' show memberName, showSplitSheet;

/// Where a rate came from, for the person.
String rateSourceLabel(AppLocalizations l, String source) => switch (source) {
  'trm' => l.rateSourceTrm,
  'binance' => 'Binance',
  'ecb' => l.rateSourceEcb,
  'manual' => l.rateSourceManual,
  _ => source,
};

/// Trips: a budget in the local currency, counted from the person's own
/// movements, never a copy of them.
class TripsPage extends StatelessWidget {
  const TripsPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final List<Trip> trips = own.trips;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.tripsTitle, style: context.type.titleLarge),
        ),
        floatingActionButton: ScrollAwareFab.extended(
          tooltip: l.tripsNew,
          onPressed: () => showTripForm(context, own: own),
          icon: const Icon(Glyph.plus),
          label: Text(l.tripsNew),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Text(l.tripsBody, style: context.type.bodyMedium),
                const SizedBox(height: 16),
                if (trips.isEmpty)
                  Block(
                    child: Text(l.tripsEmpty, style: context.type.bodyMedium),
                  )
                else
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final Trip t in trips) _TripRow(own: own, trip: t),
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

class _TripRow extends StatelessWidget {
  const _TripRow({required this.own, required this.trip});

  final OwnController own;
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final TripSummary s = own.tripSummary(trip);
    String money(Decimal d) =>
        moneyText(Money(d, trip.asset), base: own.profile?.base);
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => TripPage(own: own, id: trip.id),
        ),
      ),
      leading: Icon(Glyph.suitcaseRolling, color: context.colors.inkSoft),
      title: Text(trip.name, style: context.type.titleSmall),
      subtitle: Text(
        '${dayShortMonth(trip.from)} – ${dayShortMonth(trip.to)}',
        style: context.type.bodySmall,
      ),
      trailing: Text(switch (s.left) {
        final Decimal left => l.tripLeftShort(money(left)),
        null => l.tripSpentShort(money(s.spent)),
      }, style: context.type.bodySmall),
    );
  }
}

/// One trip: what is left of the budget, what each day can take, and every
/// expense with how it was converted.
class TripPage extends StatelessWidget {
  const TripPage({super.key, required this.own, required this.id});

  final OwnController own;
  final String id;

  /// Deletes the trip, whose expenses stay in the accounts, with a way
  /// back for a few seconds.
  Future<void> _delete(BuildContext context, Trip trip) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String said = context.l10n.deletedNamed(trip.name);
    navigator.pop();
    showUndo(messenger, said, await own.removeTrip(trip));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Trip? trip = own.trip(id);
      final Asset? base = own.profile?.base;
      if (trip == null) return Scaffold(appBar: AppBar());
      final TripSummary s = own.tripSummary(trip);
      String money(Decimal d) => moneyText(Money(d, trip.asset), base: base);
      String inBase(Decimal d) => switch (own.inBase(Money(d, trip.asset))) {
        final Money m => moneyText(m, base: base),
        null => '',
      };
      final Group? group = trip.groupId == null
          ? null
          : own.group(trip.groupId!);
      final int left = trip.daysLeft(own.today);
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(trip.name, style: context.type.titleLarge),
          actions: <Widget>[
            IconButton(
              tooltip: l.tripEdit,
              onPressed: () => showTripForm(context, own: own, trip: trip),
              icon: const Icon(Glyph.pencilSimple),
            ),
            IconButton(
              tooltip: l.tripDelete,
              onPressed: () => _delete(context, trip),
              icon: const Icon(Glyph.trash),
            ),
          ],
        ),
        floatingActionButton: ScrollAwareFab.extended(
          tooltip: l.tripAddExpense,
          onPressed: () => showTripExpenseSheet(context, own: own, trip: trip),
          icon: const Icon(Glyph.plus),
          label: Text(l.tripAddExpense),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Headline(
                  caption: s.left == null ? l.tripSpent : l.tripLeft,
                  value: money(s.left ?? s.spent),
                  detail: <String>[
                    if (trip.budget case final Decimal b) l.tripOf(money(b)),
                    if (inBase(s.left ?? s.spent) case final String b
                        when b.isNotEmpty && trip.asset != base)
                      '≈ $b',
                  ].join(' · '),
                ),
                const SizedBox(height: 12),
                Block(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '${dayMonth(trip.from)} – ${dayMonth(trip.to)}',
                        style: context.type.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      if (s.perDay case final Decimal perDay)
                        Text(
                          l.tripPerDay(money(perDay), left),
                          style: context.type.bodyMedium,
                        ),
                      if (s.average case final Decimal average)
                        Text(
                          l.tripAverage(money(average)),
                          style: context.type.bodyMedium,
                        ),
                      if (left == 0)
                        Text(l.tripOver, style: context.type.bodyMedium),
                      if (s.unconverted.isNotEmpty)
                        Text(
                          l.tripUnconverted(s.unconverted.length),
                          style: context.type.bodySmall?.copyWith(
                            color: context.colors.caution,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (group != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Glyph.usersThree,
                      color: context.colors.inkSoft,
                    ),
                    title: Text(l.tripShared, style: context.type.titleSmall),
                    subtitle: Text(
                      group.members
                          .map((Member m) => memberName(l, m))
                          .join(', '),
                      style: context.type.bodySmall,
                    ),
                    trailing: const Icon(Glyph.caretRight, size: 18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            GroupPage(own: own, id: group.id),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showGroupSheet(
                        context,
                        own: own,
                        onSaved: (Group g) =>
                            own.saveTrip(trip.copyWith(groupId: g.id)),
                      ),
                      icon: const Icon(Glyph.usersThree, size: 18),
                      label: Text(l.tripShare),
                    ),
                  ),
                const SizedBox(height: 12),
                SectionLabel(l.tripExpenses),
                if (s.lines.isEmpty)
                  Block(
                    child: Text(
                      l.tripNoExpenses,
                      style: context.type.bodyMedium,
                    ),
                  )
                else
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      for (final TripLine line in s.lines)
                        _TripLineRow(own: own, trip: trip, line: line),
                    ],
                  ),
                if (s.asked.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _Asked(own: own, trip: trip, asked: s.asked),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _includeEarlier(context, trip),
                    child: Text(l.tripIncludeEarlier),
                  ),
                ),
                ..._leftOut(context, trip),
                const SizedBox(height: 8),
                Text(l.tripSameMovements, style: context.type.bodySmall),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// The expenses the person said are not the trip's, newest first, each
  /// with the way back into it.
  List<Widget> _leftOut(BuildContext context, Trip trip) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final List<Entry> out = <Entry>[
      for (final String id in trip.excluded)
        if (own.entryById(id) case final Entry e
            when e.kind == EntryKind.expense)
          e,
    ]..sort((Entry a, Entry b) => b.date.compareTo(a.date));
    if (out.isEmpty) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: 16),
      SectionLabel(l.tripLeftOutSection),
      Panel(
        indent: 16,
        children: <Widget>[
          for (final Entry e in out)
            PutAwayRow(
              title: e.payee.isEmpty
                  ? categoryNameFor(
                      context,
                      e.category ?? 'other',
                      own.categories,
                    )
                  : e.payee,
              subtitle: dayShortMonth(e.date),
              amount: switch (own.snapshot?.account(e.accountId)) {
                final Account a => moneyText(
                  Money(e.amount, a.asset),
                  base: base,
                  signed: true,
                ),
                null => null,
              },
              action: l.tripPutBack,
              onPressed: () => own.backInTrip(trip, e),
            ),
        ],
      ),
    ];
  }

  /// Lets the person add expenses from before the trip, a flight or a
  /// hotel paid ahead.
  Future<void> _includeEarlier(BuildContext context, Trip trip) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.colors.surface,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (BuildContext context) => _EarlierSheet(own: own, id: trip.id),
      );
}

/// The expenses of the trip's days paid at home, asked about at once: a
/// trip in another currency counts only what was paid in it or abroad.
class _Asked extends StatelessWidget {
  const _Asked({required this.own, required this.trip, required this.asked});

  final OwnController own;
  final Trip trip;
  final List<Entry> asked;

  String _name(BuildContext context, Entry e) => e.payee.isEmpty
      ? categoryNameFor(context, e.category ?? 'other', own.categories)
      : e.payee;

  Future<void> _answer(BuildContext context, {required bool belongs}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = context.l10n;
    final String said = belongs
        ? l.tripAskedCounted(asked.length)
        : l.tripAskedLeftOut(asked.length);
    showUndo(
      messenger,
      said,
      await own.answerTrip(trip, asked, belongs: belongs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset home = own.profile?.base ?? Asset.cop;
    final List<String> names = <String>[
      for (final Entry e in asked.take(3)) _name(context, e),
    ];
    return Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.tripAskedTitle(asked.length, home.code, trip.currency),
            style: context.type.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            asked.length > names.length
                ? l.tripAskedMore(names.join(', '), asked.length - names.length)
                : names.join(', '),
            style: context.type.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(l.tripAskedWhy, style: context.type.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: () => _answer(context, belongs: true),
                child: Text(l.tripAskedYes(asked.length)),
              ),
              TextButton(
                onPressed: () => _answer(context, belongs: false),
                child: Text(l.tripAskedNo(asked.length)),
              ),
              if (asked.length > 1)
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    useSafeArea: true,
                    backgroundColor: context.colors.surface,
                    constraints: const BoxConstraints(maxWidth: 560),
                    builder: (BuildContext context) =>
                        _PickSheet(own: own, trip: trip, asked: asked),
                  ),
                  child: Text(l.tripAskedPick),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The expenses a trip asked about, one by one: the ones ticked count in
/// it, the rest stay out.
class _PickSheet extends StatefulWidget {
  const _PickSheet({
    required this.own,
    required this.trip,
    required this.asked,
  });

  final OwnController own;
  final Trip trip;
  final List<Entry> asked;

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  final Set<String> _belong = <String>{};

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final OwnController own = widget.own;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: <Widget>[
        Text(l.tripAskedPickTitle, style: context.type.headlineMedium),
        const SizedBox(height: 4),
        Text(l.tripAskedPickBody, style: context.type.bodySmall),
        const SizedBox(height: 8),
        for (final Entry e in widget.asked)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _belong.contains(e.id),
            onChanged: (bool? on) => setState(
              () => (on ?? false) ? _belong.add(e.id) : _belong.remove(e.id),
            ),
            title: Text(
              e.payee.isEmpty
                  ? categoryNameFor(
                      context,
                      e.category ?? 'other',
                      own.categories,
                    )
                  : e.payee,
              style: context.type.bodyMedium,
            ),
            subtitle: Text(
              '${dayShortMonth(e.date)} · ${moneyText(Money(-e.amount, own.snapshot?.account(e.accountId)?.asset ?? Asset.cop), base: own.profile?.base)}',
              style: context.type.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final NavigatorState navigator = Navigator.of(context);
            await own.sortTrip(widget.trip, widget.asked, belong: _belong);
            navigator.pop();
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _TripLineRow extends StatelessWidget {
  const _TripLineRow({
    required this.own,
    required this.trip,
    required this.line,
  });

  final OwnController own;
  final Trip trip;
  final TripLine line;

  /// Takes the expense out of the trip, with a way back for a few seconds.
  Future<void> _leaveOut(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Entry e = line.entry;
    final String said = context.l10n.tripLeftOut(
      e.payee.isEmpty
          ? categoryNameFor(context, e.category ?? 'other', own.categories)
          : e.payee,
    );
    showUndo(messenger, said, await own.leaveOutOfTrip(trip, e));
  }

  Future<void> _adjust(BuildContext context) async {
    final ForeignCharge? foreign = line.foreign;
    if (foreign == null) return;
    final Decimal estimate = foreign.estimate(line.account.decimals);
    final Decimal? charged = await showDialog<Decimal>(
      context: context,
      builder: (BuildContext context) =>
          _AdjustDialog(asset: line.account, estimate: estimate),
    );
    if (charged == null) return;
    await own.store.updateEntry(line.entry.copyWith(amount: -charged));
    await own.saveTrip(
      trip.copyWith(
        adjusted: <String, Decimal>{
          ...trip.adjusted,
          line.entry.id: line.adjustedFrom ?? estimate,
        },
      ),
    );
  }

  /// Splits the expense with whoever went: in the trip's group, or in one
  /// made for it now, which the next ones then go to.
  Future<void> _split(BuildContext context) async {
    final Group? group = trip.groupId == null ? null : own.group(trip.groupId!);
    final Group? saved = await showSplitSheet(
      context,
      own: own,
      entry: line.entry,
      group: group,
      groupName: trip.name,
    );
    if (group == null && saved != null) {
      await own.saveTrip(
        (own.trip(trip.id) ?? trip).copyWith(groupId: saved.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final Entry e = line.entry;
    final (Group, SharedExpense)? split = own.splitOf(e.id);
    final Account? account = own.snapshot?.account(e.accountId);
    String money(Decimal d, Asset a) => moneyText(Money(d, a), base: base);
    // A rate keeps its cents even in pesos: the TRM has them.
    String rate(Decimal d, Asset a) =>
        formatAmount(d, a, base: base, decimals: 2);
    final ForeignCharge? foreign = line.foreign;
    final List<String> how = <String>[
      if (foreign != null)
        foreign.fee == 0
            ? l.tripForeignNoFee(
                money(foreign.amount, trip.asset),
                rate(foreign.rate, line.account),
                dayShortMonth(foreign.rateOn),
                money(foreign.estimate(line.account.decimals), line.account),
              )
            : l.tripForeign(
                money(foreign.amount, trip.asset),
                rate(foreign.rate, line.account),
                dayShortMonth(foreign.rateOn),
                percent(foreign.fee, decimals: 2, trim: true),
                money(foreign.estimate(line.account.decimals), line.account),
              )
      else if (line.rates.isNotEmpty)
        l.tripConverted(
          money(-e.amount, line.account),
          rateSourceLabel(l, line.rates.first.source),
          dayShortMonth(line.rates.first.asOf),
        ),
      if (line.difference case final Decimal diff)
        diff >= Decimal.zero
            ? l.tripChargedMore(
                money(-e.amount, line.account),
                money(diff, line.account),
              )
            : l.tripChargedLess(
                money(-e.amount, line.account),
                money(-diff, line.account),
              ),
    ];
    return InkWell(
      onTap: () => showEntrySheet(context, own: own, entry: e),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        e.payee.isEmpty
                            ? categoryNameFor(
                                context,
                                e.category ?? 'other',
                                own.categories,
                              )
                            : e.payee,
                        style: context.type.titleSmall,
                      ),
                      Text(
                        <String>[
                          dayShortMonth(e.date),
                          ?account?.name,
                        ].join(' · '),
                        style: context.type.bodySmall,
                      ),
                    ],
                  ),
                ),
                Figures(switch (line.local) {
                  final Decimal d => money(d, trip.asset),
                  null => l.tripNoRate,
                }, style: context.type.titleSmall),
                IconButton(
                  tooltip: l.tripExclude,
                  onPressed: () => _leaveOut(context),
                  icon: Icon(
                    Glyph.minusCircle,
                    size: 18,
                    color: context.colors.inkFaint,
                  ),
                ),
              ],
            ),
            for (final String text in how)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Text(text, style: context.type.bodySmall),
              ),
            if (split case (final Group g, final SharedExpense x))
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Text(
                  l.tripSplitWith(
                    listOf(l, <String>[
                      for (final String id in x.shares.keys)
                        if (id != meId) memberName(l, g.member(id)),
                    ]),
                  ),
                  style: context.type.bodySmall,
                ),
              ),
            Wrap(
              spacing: 16,
              children: <Widget>[
                if (foreign != null && line.adjustedFrom == null)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _adjust(context),
                    child: Text(l.tripAdjust),
                  ),
                if (split == null && e.kind == EntryKind.expense)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _split(context),
                    child: Text(l.tripSplit),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the bank charged, in the account's currency.
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.asset, required this.estimate});

  final Asset asset;
  final Decimal estimate;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: formatDecimal(
      widget.estimate,
      decimals: widget.asset.decimals,
      trim: true,
    ),
  );
  String? _error;

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
      title: Text(l.tripAdjust),
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
              labelText: l.tripCharged,
              errorText: _error,
              suffixText: widget.asset.code,
            ),
          ),
          const SizedBox(height: 8),
          Text(l.tripAdjustHelp, style: context.type.bodySmall),
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
              setState(() => _error = l.instalPaymentInvalid);
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Expenses from before the trip, to count in it or not: what a trip is
/// usually paid ahead with first, the transport, the lodging and the
/// biggest expenses, and a way to look for the rest.
class _EarlierSheet extends StatefulWidget {
  const _EarlierSheet({required this.own, required this.id});

  final OwnController own;
  final String id;

  @override
  State<_EarlierSheet> createState() => _EarlierSheetState();
}

class _EarlierSheetState extends State<_EarlierSheet> {
  final TextEditingController _search = TextEditingController();

  /// The month's own payments, which a trip is seldom paid with.
  static const Set<String> _monthly = <String>{
    'housing',
    'subscriptions',
    'utilities',
    'debt',
  };

  /// Names that give a trip's lodging or tickets away.
  static final RegExp _travel = RegExp(
    r'\b(hotel|hostal|hostel|airbnb|booking|despegar|expedia|avianca|latam|'
    r'wingo|jetsmart|aerolinea|vuelo|tiquete|tiquetes)\b',
  );

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final OwnController own = widget.own;
      final Trip? trip = own.trip(widget.id);
      if (trip == null) return const SizedBox.shrink();
      final DateTime since = trip.from.subtract(const Duration(days: 120));
      Asset assetOf(Entry e) =>
          own.snapshot?.account(e.accountId)?.asset ??
          own.profile?.base ??
          Asset.cop;
      String amount(Entry e) =>
          moneyText(Money(-e.amount, assetOf(e)), base: own.profile?.base);
      // Compared in the person's own currency, where a rate allows.
      Decimal value(Entry e) =>
          own.inBase(Money(-e.amount, assetOf(e)))?.amount ?? -e.amount;
      final List<Entry> before = <Entry>[
        for (final Entry e in own.snapshot?.entries ?? const <Entry>[])
          if (e.kind == EntryKind.expense &&
              !e.isTrade &&
              e.amount < Decimal.zero &&
              e.date.isBefore(trip.from) &&
              !e.date.isBefore(since))
            e,
      ]..sort((Entry a, Entry b) => b.date.compareTo(a.date));
      final List<Decimal> values = <Decimal>[
        for (final Entry e in before) value(e),
      ]..sort();
      final Decimal middle = values.isEmpty
          ? Decimal.zero
          : values[values.length ~/ 2];
      final Set<Entry> biggest =
          (<Entry>[
                for (final Entry e in before)
                  if (!_monthly.contains(e.category)) e,
              ]..sort((Entry a, Entry b) => value(b).compareTo(value(a))))
              .take(5)
              .toSet();
      bool likely(Entry e) =>
          trip.included.contains(e.id) ||
          biggest.contains(e) ||
          ((e.category == 'transport' ||
                  _travel.hasMatch(normalize(e.payee))) &&
              value(e) >= middle);
      final String query = normalize(_search.text);
      final String digits = _search.text.replaceAll(RegExp(r'[^0-9]'), '');
      bool found(Entry e) =>
          query.isEmpty ||
          normalize(
            '${e.payee} ${categoryNameFor(context, e.category ?? 'other', own.categories)}',
          ).contains(query) ||
          (digits.isNotEmpty &&
              amount(e).replaceAll(RegExp(r'[^0-9]'), '').contains(digits));
      final List<Entry> shown = <Entry>[
        for (final Entry e in before)
          if (found(e)) e,
      ];
      final List<Entry> first = <Entry>[
        for (final Entry e in shown)
          if (likely(e)) e,
      ]..sort((Entry a, Entry b) => value(b).compareTo(value(a)));
      final List<Entry> rest = <Entry>[
        for (final Entry e in shown)
          if (!likely(e) && !_monthly.contains(e.category)) e,
        for (final Entry e in shown)
          if (!likely(e) && _monthly.contains(e.category)) e,
      ];
      Widget row(Entry e) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: trip.included.contains(e.id),
        onChanged: (bool? on) => own.saveTrip(
          trip.copyWith(
            included: <String>{
              for (final String x in trip.included)
                if (x != e.id) x,
              if (on ?? false) e.id,
            },
          ),
        ),
        title: Text(
          e.payee.isEmpty ? l.kindExpense : e.payee,
          style: context.type.bodyMedium,
        ),
        subtitle: Text(
          '${dayShortMonth(e.date)} · ${amount(e)}',
          style: context.type.bodySmall,
        ),
      );
      return ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: <Widget>[
          Text(l.tripIncludeEarlier, style: context.type.headlineMedium),
          const SizedBox(height: 4),
          Text(l.tripIncludeEarlierBody, style: context.type.bodySmall),
          const SizedBox(height: 12),
          if (before.isEmpty)
            Text(l.tripNothingEarlier, style: context.type.bodyMedium)
          else ...<Widget>[
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l.tripEarlierSearch,
                prefixIcon: const Icon(Glyph.magnifyingGlass, size: 20),
                isDense: true,
              ),
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l.tripEarlierNone, style: context.type.bodyMedium),
              ),
            if (first.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SectionLabel(l.tripEarlierLikely),
              for (final Entry e in first) row(e),
            ],
            if (rest.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SectionLabel(l.tripEarlierRest),
              for (final Entry e in rest) row(e),
            ],
          ],
        ],
      );
    },
  );
}

/// Adds a trip, or changes [trip], on a page of its own.
Future<void> showTripForm(
  BuildContext context, {
  required OwnController own,
  Trip? trip,
}) => showFormPage<void>(
  context,
  (BuildContext context) => _TripForm(own: own, trip: trip),
);

class _TripForm extends StatefulWidget {
  const _TripForm({required this.own, this.trip});

  final OwnController own;
  final Trip? trip;

  @override
  State<_TripForm> createState() => _TripFormState();
}

class _TripFormState extends State<_TripForm> {
  OwnController get own => widget.own;
  late final TextEditingController _name = TextEditingController(
    text: widget.trip?.name ?? '',
  );
  late String _currency =
      widget.trip?.currency ?? (own.profile?.base ?? Asset.cop).code;
  late final TextEditingController _budget = TextEditingController(
    text: switch (widget.trip?.budget) {
      final Decimal b => formatDecimal(
        b,
        decimals: Asset.of(_currency).decimals,
        trim: true,
      ),
      null => '',
    },
  );
  late final TextEditingController _fee = TextEditingController(
    text: switch (widget.trip?.fee) {
      final double f when f > 0 => formatDecimal(
        Decimal.parse(f.toStringAsFixed(2)),
        decimals: 2,
        trim: true,
      ),
      _ => '',
    },
  );
  late DateTimeRange _dates = widget.trip == null
      ? DateTimeRange(
          start: own.today,
          end: own.today.add(const Duration(days: 6)),
        )
      : DateTimeRange(start: widget.trip!.from, end: widget.trip!.to);
  String? _error;

  @override
  void initState() {
    super.initState();
    // What was missing is said until something is typed.
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _budget,
      _fee,
    ]) {
      c.addListener(_typed);
    }
  }

  void _typed() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l.tripIncomplete);
      return;
    }
    feelSaved();
    final NavigatorState navigator = Navigator.of(context);
    final Decimal? budget = switch (parseAmount(_budget.text)) {
      final Decimal b when b > Decimal.zero => b,
      _ => null,
    };
    final double fee = parseAmount(_fee.text)?.toDouble() ?? 0;
    final Trip? old = widget.trip;
    // The page goes as the trip is saved, without the wait in between.
    navigator.pop();
    await own.saveTrip(
      (old ??
              Trip(
                id: 'trip-${DateTime.now().microsecondsSinceEpoch}',
                name: '',
                from: _dates.start,
                to: _dates.end,
                currency: _currency,
              ))
          .copyWith(
            name: _name.text.trim(),
            from: _dates.start,
            to: _dates.end,
            currency: _currency,
            budget: budget,
            clearBudget: budget == null,
            fee: fee,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final List<Asset> currencies = <Asset>[
      ...Asset.fiat,
      if (!Asset.fiat.any((Asset a) => a.code == _currency))
        Asset.of(_currency),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FormTitle(widget.trip == null ? l.tripsNew : l.tripEdit),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.tripName),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final DateTime today = own.today;
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: _dates,
                  firstDate: DateTime(today.year - 2),
                  lastDate: DateTime(today.year + 3),
                );
                if (picked != null) setState(() => _dates = picked);
              },
              icon: const Icon(Glyph.calendarBlank, size: 18),
              label: Text(
                '${dayMonth(_dates.start)} – ${dayMonth(_dates.end)}',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _currency,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.tripCurrency),
              items: <DropdownMenuItem<String>>[
                for (final Asset a in currencies)
                  DropdownMenuItem<String>(value: a.code, child: Text(a.code)),
              ],
              onChanged: (String? c) =>
                  setState(() => _currency = c ?? _currency),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: Asset.of(_currency).decimals),
              ],
              decoration: InputDecoration(
                labelText: l.tripBudget,
                suffixText: _currency,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fee,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: 2),
              ],
              decoration: InputDecoration(
                labelText: l.tripFee,
                helperText: l.tripFeeHelp,
                helperMaxLines: 3,
                suffixText: '%',
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

/// Records an expense of [trip] in its currency. Charged to an account in
/// another currency, it is estimated with a dated rate and the card's fee
/// until the bank says what it charged.
Future<void> showTripExpenseSheet(
  BuildContext context, {
  required OwnController own,
  required Trip trip,
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
    builder: (BuildContext context) => _TripExpenseSheet(own: own, trip: trip),
  );
}

class _TripExpenseSheet extends StatefulWidget {
  const _TripExpenseSheet({required this.own, required this.trip});

  final OwnController own;
  final Trip trip;

  @override
  State<_TripExpenseSheet> createState() => _TripExpenseSheetState();
}

class _TripExpenseSheetState extends State<_TripExpenseSheet> {
  OwnController get own => widget.own;
  Trip get trip => widget.trip;
  final TextEditingController _what = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  late final TextEditingController _rate = TextEditingController();
  late final TextEditingController _fee = TextEditingController(
    text: trip.fee > 0
        ? formatDecimal(
            Decimal.parse(trip.fee.toStringAsFixed(2)),
            decimals: 2,
            trim: true,
          )
        : '',
  );
  late DateTime _date = trip.within(own.today) ? own.today : trip.from;
  String _category = 'leisure';
  late String _accountId = _firstAccount();
  String? _error;

  String _firstAccount() {
    for (final Account a in own.accounts) {
      if (a.asset == trip.asset && a.spendable) return a.id;
    }
    for (final Account a in own.accounts) {
      if (a.kind == AccountKind.card) return a.id;
    }
    return own.accounts.first.id;
  }

  Asset get _accountAsset =>
      own.snapshot?.account(_accountId)?.asset ??
      own.profile?.base ??
      Asset.cop;

  bool get _converts => _accountAsset != trip.asset;

  /// The latest rate from the trip's currency to the account's, if known.
  Rate? get _known {
    final List<Rate> used = own.rates.used(trip.asset, _accountAsset);
    return used.isEmpty ? null : used.first;
  }

  @override
  void initState() {
    super.initState();
    _fillRate();
    for (final TextEditingController c in <TextEditingController>[
      _amount,
      _rate,
      _fee,
    ]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  void _fillRate() {
    final Decimal? rate = own.rates.rate(trip.asset, _accountAsset);
    _rate.text = rate == null || !_converts
        ? ''
        : formatDecimal(rate, decimals: 2, trim: true);
  }

  @override
  void dispose() {
    _what.dispose();
    _amount.dispose();
    _rate.dispose();
    _fee.dispose();
    super.dispose();
  }

  ForeignCharge? get _foreign {
    final Decimal? amount = parseAmount(_amount.text);
    final Decimal? rate = parseAmount(_rate.text);
    if (!_converts || amount == null || rate == null || rate <= Decimal.zero) {
      return null;
    }
    // The suggested rate keeps its source and day; one typed is the
    // person's, as of today.
    final Rate? known = _known;
    final Decimal? suggested = own.rates.rate(trip.asset, _accountAsset);
    final bool asSuggested =
        known != null &&
        suggested != null &&
        suggested.round(scale: 2) == rate.round(scale: 2);
    return ForeignCharge(
      amount: amount,
      rate: rate,
      rateOn: asSuggested ? known.asOf : own.today,
      rateSource: asSuggested ? known.source : 'manual',
      fee: parseAmount(_fee.text)?.toDouble() ?? 0,
    );
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Decimal? amount = parseAmount(_amount.text);
    final ForeignCharge? foreign = _foreign;
    if (amount == null ||
        amount <= Decimal.zero ||
        (_converts && foreign == null)) {
      setState(() => _error = l.tripExpenseIncomplete);
      return;
    }
    feelSaved();
    final NavigatorState navigator = Navigator.of(context);
    final Entry entry = await own.store.addEntry(
      accountId: _accountId,
      amount: foreign?.estimate(_accountAsset.decimals) ?? amount,
      kind: EntryKind.expense,
      date: _date,
      category: _category,
      payee: _what.text.trim(),
    );
    final Trip now = own.trip(trip.id) ?? trip;
    await own.saveTrip(
      now.copyWith(
        foreign: <String, ForeignCharge>{...now.foreign, entry.id: ?foreign},
        included: now.within(_date)
            ? now.included
            : <String>{...now.included, entry.id},
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final ForeignCharge? foreign = _foreign;
    final Rate? known = _known;
    final List<CategoryItem> categories = <CategoryItem>[
      for (final CategoryItem c in own.categories)
        if (!c.archived && !c.income) c,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.tripAddExpense, style: context.type.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _what,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.tripWhat),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: trip.asset.decimals),
              ],
              decoration: InputDecoration(
                labelText: l.tripAmount,
                suffixText: trip.currency,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _accountId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.tripPaidWith),
              items: <DropdownMenuItem<String>>[
                for (final Account a in own.accounts)
                  DropdownMenuItem<String>(
                    value: a.id,
                    child: Text('${a.name} · ${a.asset.code}'),
                  ),
              ],
              onChanged: (String? id) => setState(() {
                _accountId = id ?? _accountId;
                _fillRate();
              }),
            ),
            if (_converts) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        AmountInputFormatter(maxDecimals: 6),
                      ],
                      decoration: InputDecoration(
                        labelText: l.tripRate(
                          trip.currency,
                          _accountAsset.code,
                        ),
                        helperText: known == null
                            ? l.tripRateNone
                            : l.tripRateFrom(
                                rateSourceLabel(l, known.source),
                                dayShortMonth(known.asOf),
                              ),
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _fee,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        AmountInputFormatter(maxDecimals: 2),
                      ],
                      decoration: InputDecoration(
                        labelText: l.tripFeeShort,
                        suffixText: '%',
                      ),
                    ),
                  ),
                ],
              ),
              if (foreign != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l.tripWillRecord(
                      moneyText(
                        Money(
                          foreign.estimate(_accountAsset.decimals),
                          _accountAsset,
                        ),
                        base: base,
                      ),
                      own.snapshot?.account(_accountId)?.name ?? '',
                    ),
                    style: context.type.bodyMedium,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: trip.from.subtract(const Duration(days: 120)),
                  lastDate: trip.to.add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Glyph.calendarBlank, size: 18),
              label: Text(dayMonth(_date)),
            ),
            const SizedBox(height: 16),
            Text(l.category, style: context.type.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final CategoryItem c in categories)
                  ChoiceChip(
                    avatar: Icon(
                      categoryIconFor(c.key),
                      size: 18,
                      color: categoryColorFor(context, c.key),
                    ),
                    label: Text(
                      categoryNameFor(context, c.key, own.categories),
                    ),
                    selected: _category == c.key,
                    onSelected: (_) => setState(() => _category = c.key),
                  ),
              ],
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
