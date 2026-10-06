import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../capture/merchants.dart';
import '../../data/ledger.dart';
import '../../domain/decisions.dart';
import '../../domain/pay_schedule.dart';
import '../../domain/projection.dart';
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
import '../standing.dart';
import 'accounts_tab.dart';
import 'close_page.dart';
import 'coming_days_page.dart';
import 'commitments_page.dart';
import 'entry_sheet.dart';
import 'envelopes_page.dart';
import 'free_explained.dart';
import 'inbox_page.dart';
import 'amount_input.dart';
import 'look.dart';
import 'movement_list.dart';

/// Where the money stands until payday, the accounts and the last
/// movements.
class OwnHomeTab extends StatelessWidget {
  const OwnHomeTab({
    super.key,
    required this.own,
    required this.onSeeAll,
    this.onAsk,
  });

  final OwnController own;

  /// Opens the full list of movements.
  final VoidCallback onSeeAll;

  /// Opens a conversation with Gemini, with a question or without one. Null
  /// where Quincena's project does not serve the app.
  final void Function([String? question])? onAsk;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = own.ledger;
    if (ledger == null) return const SizedBox.shrink();
    final List<Entry> recent = visibleEntries(own).take(5).toList();
    final List<_Todo> todos = _todos(l, ledger);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StandingCard(
          ledger: ledger,
          cardDebt: own.spendableCardDebt,
          onExplain: () => showFreeExplained(context, own),
          greet: false,
          caveat: own.provisional ? l.standingProvisional : null,
        ),
        // One thing first, given room and a button; the rest after it.
        if (todos.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          SectionLabel(l.homeTodo),
          _MainTodo(todo: todos.first),
          if (todos.length > 1) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Semantics(
                header: true,
                child: Text(l.homeTodoThen, style: context.type.labelMedium),
              ),
            ),
            Panel(
              children: <Widget>[
                for (final _Todo todo in todos.skip(1)) _TodoRow(todo: todo),
              ],
            ),
          ],
        ],
        const SizedBox(height: 24),
        _ComingDays(own: own, ledger: ledger),
        const SizedBox(height: 12),
        _CanIBuy(own: own, ledger: ledger),
        if (onAsk case final void Function([String? question]) ask) ...<Widget>[
          const SizedBox(height: 24),
          SectionLabel(l.askYourMoneyLabel),
          Panel(
            children: <Widget>[
              for (final (IconData icon, String question)
                  in <(IconData, String)>[
                    (Glyph.wallet, l.ownAskFree),
                    (Glyph.chartDonut, l.ownAskMonth),
                    (Glyph.coins, l.ownAskAll),
                  ])
                _AskRow(icon: icon, text: question, onTap: () => ask(question)),
              _AskRow(icon: Glyph.sparkle, text: l.askOther, onTap: ask),
            ],
          ),
        ],
        const SizedBox(height: 24),
        SectionLabel(l.yourAccounts),
        Panel(
          children: <Widget>[
            for (final Account a in own.accounts)
              AccountRow(own: own, account: a),
          ],
        ),
        const SizedBox(height: 24),
        SectionLabel(
          l.recentMovements,
          trailing: recent.isEmpty
              ? null
              : TextButton(onPressed: onSeeAll, child: Text(l.seeAll)),
        ),
        if (recent.isEmpty)
          _Empty(title: l.noMovements, body: l.noMovementsBody)
        else
          Panel(
            children: <Widget>[
              for (final Entry e in recent) MovementRow(own: own, entry: e),
            ],
          ),
      ],
    );
  }

  /// What there is to do, the most pressing first: what the figure waits
  /// for, the pay to split, then what it still leaves out.
  List<_Todo> _todos(AppLocalizations l, Ledger ledger) {
    final int pending = own.pendingInbox.length;
    final List<String> unpriced = <String>[
      for (final Asset a in own.unconverted) a.code,
    ];
    final int guesses = own.provisional ? own.recurringGuesses.length : 0;
    return <_Todo>[
      if (pending > 0)
        _Todo(
          icon: Glyph.tray,
          title: l.inboxBanner(pending),
          body: l.inboxBannerBody(pending),
          action: l.todoReview,
          open: _push((_) => InboxPage(own: own)),
        ),
      if (own.projection?.latePay case final DateTime late)
        _Todo(
          icon: Glyph.hourglass,
          title: l.todoLatePay(dayMonth(late)),
          body: l.todoLatePayBody,
          action: l.todoRecord,
          open: (BuildContext context) =>
              showEntrySheet(context, own: own, kind: EntryKind.income),
        ),
      if (own.paidWithoutPlan) _payArrived(l, own, ledger),
      if (own.provisional)
        _Todo(
          icon: Glyph.repeat,
          title: l.todoFixedTitle,
          body: guesses > 0
              ? l.planFixedGuesses(guesses)
              : l.todoFixedBody(dayShortMonth(ledger.nextPayday)),
          action: l.todoAdd,
          open: _push((_) => CommitmentsPage(own: own)),
        ),
      if (unpriced.isNotEmpty)
        _Todo(
          icon: Glyph.arrowsLeftRight,
          title: l.todoRates(unpriced.length, unpriced.join(', ')),
          body: l.todoRatesBody(unpriced.length),
          action: l.todoSeeRates,
          open: _push((_) => RatesPage(own: own)),
        ),
    ];
  }
}

/// Something to do on the home: what, why it matters, what doing it is
/// called, and where it is done.
class _Todo {
  const _Todo({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.open,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final void Function(BuildContext context) open;
}

/// Opens [page] over the home.
void Function(BuildContext context) _push(WidgetBuilder page) =>
    (BuildContext context) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: page));

/// The pay that arrived with no envelopes yet: how much, when and where,
/// and the way to split it.
_Todo _payArrived(AppLocalizations l, OwnController own, Ledger ledger) {
  final bool fortnight = ledger.schedule is TwiceMonthly;
  // The earliest first, so the accounts read in the order the money came.
  final List<Entry> arrivals = own.payArrivals.reversed.toList();
  final int? total = own.payArrivedTotal;
  final String? amount = total == null ? null : pesos(ledger.major(total));
  final List<String> names = <String>{
    for (final Entry e in arrivals) ?own.snapshot?.account(e.accountId)?.name,
  }.toList();
  final String where = names.length < 2
      ? names.join()
      : l.listAnd(
          names.take(names.length - 1).join(', '),
          names.last,
          _sound(names.last),
        );
  final String from = dayShortMonth(arrivals.first.date);
  final String to = dayShortMonth(arrivals.last.date);
  return _Todo(
    icon: Glyph.wallet,
    title: amount == null
        ? (fortnight ? l.paydayArrived : l.paydayArrivedPay)
        : fortnight
        ? l.paydayArrivedAmount(amount)
        : l.paydayArrivedPayAmount(amount),
    // On two days, both: the latest alone would date all of it.
    body: from == to
        ? l.paydayArrivedDetail(to, where)
        : l.paydayArrivedDetailRange(from, to, where),
    action: l.todoSplit,
    open: _push((_) => EnvelopesPage(own: own)),
  );
}

/// The sound [word] starts with, as listAnd picks its conjunction: "i"
/// for an i, so Spanish says "Nequi e Itaú" and not "y Itaú"; an i
/// opening a diphthong, as in "hielo", keeps the y.
String _sound(String word) =>
    RegExp(r'^h?[ií](?![aeoáéó])', caseSensitive: false).hasMatch(word)
    ? 'i'
    : 'other';

/// One question to ask, or the way to ask another.
class _AskRow extends StatelessWidget {
  const _AskRow({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: context.colors.brand),
    title: Text(text, style: context.type.bodyMedium),
    trailing: Icon(Glyph.caretRight, size: 18, color: context.colors.inkFaint),
  );
}

/// The thing to do first: what and why, with room, and a button that says
/// what doing it is called.
class _MainTodo extends StatelessWidget {
  const _MainTodo({required this.todo});

  final _Todo todo;

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(todo.icon, size: 24, color: context.colors.brand);
    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(todo.title, style: context.type.titleMedium),
        const SizedBox(height: 2),
        Text(todo.body, style: context.type.bodySmall),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: () => todo.open(context),
          child: Text(todo.action),
        ),
      ],
    );
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      // With large text the icon goes above, as iOS lays out its own at
      // those sizes, and the words have the whole width.
      child: largeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[icon, const SizedBox(height: 8), words],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                icon,
                const SizedBox(width: 14),
                Expanded(child: words),
              ],
            ),
    );
  }
}

/// Something to do after the first, with what doing it is called: the
/// whole row opens it, and the word at its end says what that is.
class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo});

  final _Todo todo;

  @override
  Widget build(BuildContext context) {
    final bool large = largeText(context);
    final Widget action = Text(
      todo.action,
      style: context.type.labelLarge?.copyWith(color: context.colors.brand),
    );
    final Widget caret = Icon(
      Glyph.caretRight,
      size: 16,
      color: context.colors.brand,
    );
    return InkWell(
      onTap: () => todo.open(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Icon(todo.icon, size: 24, color: context.colors.brand),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(todo.title, style: context.type.titleSmall),
                  Text(todo.body, style: context.type.bodySmall),
                  // With large text what doing it is called goes under
                  // what it is: beside it, the words would have no room.
                  if (large) ...<Widget>[
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Flexible(child: action),
                        caret,
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!large) ...<Widget>[const SizedBox(width: 8), action, caret],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: context.type.titleSmall),
        const SizedBox(height: 4),
        Text(body, style: context.type.bodyMedium),
      ],
    ),
  );
}

/// Every movement, with a search over what it was, where and in which
/// account. A sliver: the days are built as they scroll into view, so a
/// long history costs only what shows.
class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key, required this.own});

  final OwnController own;

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Whether [e] has [q], a query already [normalize]d, in what it was,
  /// its note, its category or its accounts: a transfer is found by either
  /// end. Accents do not count, as a phone's keyboard often leaves them out.
  bool _matches(BuildContext context, Entry e, String q) {
    final OwnController own = widget.own;
    final List<String> accounts = <String>[
      ?own.snapshot?.account(e.accountId)?.name,
      // The other end of a transfer: only a transfer looks for it.
      if (e.transferId case final String transfer)
        for (final Entry leg in own.snapshot?.entries ?? const <Entry>[])
          if (leg.transferId == transfer && leg.id != e.id)
            ?own.snapshot?.account(leg.accountId)?.name,
    ];
    final String category = e.category == null
        ? ''
        : categoryNameFor(context, e.category!, own.categories);
    return <String>[
      e.payee,
      e.note,
      ...accounts,
      category,
    ].any((String s) => normalize(s).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final OwnController own = widget.own;
    final String q = normalize(_search.text);
    final List<Entry> all = visibleEntries(own);
    final List<Entry> shown = q.isEmpty
        ? all
        : all.where((Entry e) => _matches(context, e, q)).toList();
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l.searchMovements,
                // Whole with large text too.
                hintMaxLines: largeText(context) ? 3 : null,
                prefixIcon: const Icon(Glyph.magnifyingGlass, size: 20),
              ),
            ),
          ),
        ),
        if (all.isEmpty)
          SliverToBoxAdapter(
            child: _Empty(title: l.noMovements, body: l.noMovementsBody),
          )
        else if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Text(l.noResults, style: context.type.bodyMedium),
          )
        else
          MovementGroups.sliver(own: own, entries: shown),
      ],
    );
  }
}

/// What comes until payday, as a line of days: each charge on its day and
/// the pay, with the lowest balance said first. What there is today is the
/// card's first line, so the line starts tomorrow. In the week after a
/// payday, the close of the period that ended.
class _ComingDays extends StatelessWidget {
  const _ComingDays({required this.own, required this.ledger});

  final OwnController own;
  final Ledger ledger;

  /// How many of the coming charges the card shows before pointing to the
  /// rest.
  static const int _shown = 5;

  void _open(BuildContext context, Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Projection? projection = own.projection;
    if (projection == null) return const SizedBox.shrink();
    final ProjectedDay low = projection.lowestBeforePayday;
    // The lowest counts only what is sure: when money is expected by then,
    // the line says it leaves that out.
    final bool expecting = projection.days.any(
      (ProjectedDay d) =>
          !d.date.isAfter(low.date) &&
          d.events.any(
            (ProjectedEvent e) =>
                e.certainty == Certainty.expected && e.amount > 0,
          ),
    );
    final ProjectedDay? tight = projection.firstTight;
    final DateTime payday = projection.nextPayday;
    final PeriodClose? close = closePeriod(ledger);
    final bool closeFresh =
        close != null && ledger.today.difference(close.end).inDays <= 7;
    final List<ProjectedEvent> events = <ProjectedEvent>[
      for (final ProjectedDay d in projection.days)
        if (!d.date.isAfter(payday))
          for (final ProjectedEvent e in d.events)
            if (e.kind != ProjectedKind.tryOut) e,
    ];
    final bool fortnight = ledger.schedule is TwiceMonthly;
    String label(ProjectedEvent e) => switch (e.kind) {
      ProjectedKind.pay => fortnight ? l.timelineFortnight : l.comingPay,
      ProjectedKind.latePay => l.comingLatePay,
      _ => e.label.isEmpty ? l.timelineCharge : e.label,
    };
    String amount(int minor) => pesos(ledger.major(minor), signed: true);
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.homeComing, style: context.type.titleSmall),
          const SizedBox(height: 4),
          Text(
            (expecting ? l.comingLowestLineSure : l.comingLowestLine)(
              pesos(ledger.major(low.sure)),
              dayMonth(low.date),
            ),
            style: context.type.bodyMedium,
          ),
          if (tight != null)
            Text(
              // Without a cushion, under it is out of money.
              (ledger.cushion > 0 ? l.comingTight : l.comingRunsOut)(
                dayShortMonth(tight.date),
              ),
              style: context.type.bodySmall?.copyWith(
                color: context.colors.caution,
              ),
            ),
          const SizedBox(height: 6),
          for (final ProjectedEvent e in events.take(_shown))
            _TimelineRow(
              when: dayShortMonth(e.date),
              what: label(e),
              amount: amount(e.amount),
              note: e.certainty == Certainty.expected
                  ? l.timelineExpected
                  : null,
              income: e.amount > 0,
            ),
          if (events.length > _shown)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l.timelineMore(events.length - _shown),
                style: context.type.bodySmall,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _open(context, ComingDaysPage(own: own)),
                icon: const Icon(Glyph.calendarBlank, size: 18),
                label: Text(l.homeSeeDays),
              ),
              if (closeFresh)
                TextButton.icon(
                  onPressed: () => _open(context, ClosePage(own: own)),
                  icon: const Icon(Glyph.receipt, size: 18),
                  label: Text(l.closeTitle),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One day on the line: when, what, and how much, with expected money
/// marked as such.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.when,
    required this.what,
    required this.amount,
    this.note,
    this.income = false,
  });

  final String when;
  final String what;
  final String amount;
  final String? note;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = context.type.bodyMedium;
    final Widget day = Text(when, style: context.type.bodySmall);
    final Widget label = Text.rich(
      TextSpan(
        text: what,
        children: <InlineSpan>[
          if (note case final String n)
            TextSpan(text: ' · $n', style: context.type.bodySmall),
        ],
      ),
      style: style,
    );
    final Widget figure = Figures(
      amount,
      style: style?.copyWith(color: income ? context.colors.positive : null),
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        // With large text the day, what and how much go one under the
        // other: in columns none of them would fit.
        child: largeText(context)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[day, label, figure],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 64, child: day),
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  figure,
                ],
              ),
      ),
    );
  }
}

/// "Can I afford it?" with the price at hand: typed here, it opens the
/// coming days with the purchase tried out.
class _CanIBuy extends StatefulWidget {
  const _CanIBuy({required this.own, required this.ledger});

  final OwnController own;
  final Ledger ledger;

  @override
  State<_CanIBuy> createState() => _CanIBuyState();
}

class _CanIBuyState extends State<_CanIBuy> {
  final TextEditingController _price = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _check() {
    final Decimal? typed = parseAmount(_price.text);
    final int? price = typed == null || typed <= Decimal.zero
        ? null
        : widget.ledger.minor(typed.toDouble());
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ComingDaysPage(own: widget.own, tryPurchase: true, price: price),
      ),
    );
    _price.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Widget field = TextField(
      controller: _price,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        AmountInputFormatter(maxDecimals: widget.ledger.currency.decimals),
      ],
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _check(),
      // With large text the button is under it: it comes above the
      // keyboard with the field.
      scrollPadding: largeText(context)
          ? EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30 + MediaQuery.textScalerOf(context).scale(48),
            )
          : const EdgeInsets.all(20),
      decoration: InputDecoration(
        hintText: l.buyAskHint,
        prefixText: r'$',
        isDense: true,
      ),
    );
    final Widget go = FilledButton(onPressed: _check, child: Text(l.buyAskGo));
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.buyAsk, style: context.type.titleSmall),
          Text(l.buyAskBody, style: context.type.bodySmall),
          const SizedBox(height: 10),
          // With large text the button goes under the field, which keeps
          // the room to read what to type.
          if (largeText(context)) ...<Widget>[
            field,
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerEnd, child: go),
          ] else
            Row(
              children: <Widget>[
                Expanded(child: field),
                const SizedBox(width: 10),
                go,
              ],
            ),
        ],
      ),
    );
  }
}
