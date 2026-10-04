import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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
    final Set<Asset> missing = own.unconverted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StandingCard(
          ledger: ledger,
          cardDebt: own.spendableCardDebt,
          onExplain: () => showFreeExplained(context, own),
        ),
        if (own.projection?.latePay case final DateTime late) ...<Widget>[
          const SizedBox(height: 12),
          _Notice(text: l.payLate(dayMonth(late))),
        ],
        if (own.pendingInbox.isNotEmpty || own.paidWithoutPlan) ...<Widget>[
          const SizedBox(height: 24),
          SectionLabel(l.homeTodo),
          Panel(
            children: <Widget>[
              if (own.pendingInbox.isNotEmpty)
                _TodoRow(
                  icon: Glyph.tray,
                  title: l.inboxBanner(own.pendingInbox.length),
                  body: l.inboxBannerBody(own.pendingInbox.length),
                  action: l.todoReview,
                  open: (_) => InboxPage(own: own),
                ),
              if (own.paidWithoutPlan) _PayArrivedRow(own: own, ledger: ledger),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _ComingDays(own: own, ledger: ledger),
        const SizedBox(height: 12),
        _CanIBuy(own: own, ledger: ledger),
        if (missing.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _Notice(
            text: l.ratesMissing(missing.map((Asset a) => a.code).join(', ')),
          ),
        ],
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
}

/// The pay that arrived with no envelopes yet: how much, when and where,
/// and the way to split it.
class _PayArrivedRow extends StatelessWidget {
  const _PayArrivedRow({required this.own, required this.ledger});

  final OwnController own;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
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
    return _TodoRow(
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
      open: (_) => EnvelopesPage(own: own),
    );
  }

  /// The sound [word] starts with, as listAnd picks its conjunction: "i"
  /// for an i, so Spanish says "Nequi e Itaú" and not "y Itaú"; an i
  /// opening a diphthong, as in "hielo", keeps the y.
  static String _sound(String word) =>
      RegExp(r'^h?[ií](?![aeoáéó])', caseSensitive: false).hasMatch(word)
      ? 'i'
      : 'other';
}

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

/// Something to do now, with what doing it is called: the whole row opens
/// it, and the word at its end says what that is.
class _TodoRow extends StatelessWidget {
  const _TodoRow({
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
  final WidgetBuilder open;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: open)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 24, color: context.colors.brand),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.type.titleSmall),
                Text(body, style: context.type.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            action,
            style: context.type.labelLarge?.copyWith(
              color: context.colors.brand,
            ),
          ),
          Icon(Glyph.caretRight, size: 16, color: context.colors.brand),
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.colors.cautionSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: <Widget>[
        Icon(Glyph.warningCircle, size: 20, color: context.colors.caution),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.type.bodyMedium)),
      ],
    ),
  );
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
/// account.
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

  bool _matches(BuildContext context, Entry e, String q) {
    final OwnController own = widget.own;
    final String account = own.snapshot?.account(e.accountId)?.name ?? '';
    final String category = e.category == null
        ? ''
        : categoryNameFor(context, e.category!, own.categories);
    return <String>[
      e.payee,
      e.note,
      account,
      category,
    ].any((String s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final OwnController own = widget.own;
    final String q = _search.text.trim().toLowerCase();
    final List<Entry> all = visibleEntries(own);
    final List<Entry> shown = q.isEmpty
        ? all
        : all.where((Entry e) => _matches(context, e, q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l.searchMovements,
            prefixIcon: const Icon(Glyph.magnifyingGlass, size: 20),
          ),
        ),
        const SizedBox(height: 20),
        if (all.isEmpty)
          _Empty(title: l.noMovements, body: l.noMovementsBody)
        else if (shown.isEmpty)
          Text(l.noResults, style: context.type.bodyMedium)
        else
          MovementGroups(own: own, entries: shown),
      ],
    );
  }
}

/// What comes until payday, as a line of days: what there is today, each
/// charge on its day, and the pay, with the lowest balance said first. In
/// the week after a payday, the close of the period that ended.
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
    String amount(int minor) =>
        '${minor > 0 ? '+' : ''}${pesos(ledger.major(minor))}';
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
              l.comingTight(dayShortMonth(tight.date)),
              style: context.type.bodySmall?.copyWith(
                color: context.colors.caution,
              ),
            ),
          const SizedBox(height: 10),
          _TimelineRow(
            when: l.timelineToday,
            what: l.timelineAvailable,
            amount: pesos(ledger.major(projection.start)),
            strong: true,
          ),
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
    this.strong = false,
    this.income = false,
  });

  final String when;
  final String what;
  final String amount;
  final String? note;
  final bool strong;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = strong
        ? context.type.titleSmall
        : context.type.bodyMedium;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Text(when, style: context.type.bodySmall),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: what,
                  children: <InlineSpan>[
                    if (note case final String n)
                      TextSpan(text: ' · $n', style: context.type.bodySmall),
                  ],
                ),
                style: style,
              ),
            ),
            const SizedBox(width: 12),
            Figures(
              amount,
              style: style?.copyWith(
                color: income ? context.colors.positive : null,
              ),
            ),
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
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.buyAsk, style: context.type.titleSmall),
          Text(l.buyAskBody, style: context.type.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    AmountInputFormatter(
                      maxDecimals: widget.ledger.currency.decimals,
                    ),
                  ],
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(
                    hintText: l.buyAskHint,
                    prefixText: r'$',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _check, child: Text(l.buyAskGo)),
            ],
          ),
        ],
      ),
    );
  }
}
