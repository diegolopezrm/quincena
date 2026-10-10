import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../ai/allowance.dart';
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
import 'account_sheet.dart';
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
import 'setup_checklist.dart';

/// Where the money stands until payday, the accounts and the last
/// movements.
class OwnHomeTab extends StatelessWidget {
  const OwnHomeTab({
    super.key,
    required this.own,
    required this.onSeeAll,
    this.onAsk,
    this.questions,
    this.allowance,
    this.conversing = false,
  });

  final OwnController own;

  /// Opens the full list of movements.
  final VoidCallback onSeeAll;

  /// Opens a conversation with Gemini, with a question or without one. Null
  /// where Quincena's project does not serve the app.
  final void Function([String? question])? onAsk;

  /// The questions offered under «Pregúntale a tu plata», each with its
  /// icon: the ones the example's script answers, there. Null offers the
  /// ones for the person's own accounts.
  final List<(IconData, String)>? questions;

  /// The day's questions, where asking spends them: said before asking
  /// when few are left, and the questions put away when none are.
  final Allowance? allowance;

  /// Whether a conversation is under way, to go back to it when no
  /// question can be asked today.
  final bool conversing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = own.ledger;
    if (ledger == null) return const SizedBox.shrink();
    final List<Entry> recent = visibleEntries(own).take(5).toList();
    // Without an account there is no figure yet: Inicio leads to the first
    // one instead of showing nothing worth $0.
    final bool accounts = own.accounts.isNotEmpty;
    final bool setup = showsSetup(l, own);
    if (setupFinished(l, own)) {
      // All of it done: the list goes for good.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => own.keepSetupOpen(false),
      );
    }
    final List<_Todo> todos = _todos(l, ledger, fixedInSetup: setup);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (accounts)
          StandingCard(
            ledger: ledger,
            cardDebt: own.spendableCardDebt,
            onExplain: () => showFreeExplained(context, own),
            greet: false,
            caveat: own.provisional ? l.standingProvisional : null,
          )
        else
          _FirstAccount(own: own),
        // What setting up left for later, right under the figure it makes
        // more precise.
        if (setup) ...<Widget>[
          const SizedBox(height: 24),
          SetupChecklist(own: own),
        ],
        // What needs attention, as rows under the figure and lighter than
        // it: the most pressing first, with a button; the rest after it.
        if (todos.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          SectionLabel(l.homeTodo),
          Panel(
            children: <Widget>[
              _TodoRow(todo: todos.first, first: true),
              for (final _Todo todo in todos.skip(1)) _TodoRow(todo: todo),
            ],
          ),
        ],
        if (accounts) ...<Widget>[
          const SizedBox(height: 24),
          _ComingDays(own: own, ledger: ledger),
          const SizedBox(height: 12),
          _CanIBuy(own: own, ledger: ledger),
        ],
        if (onAsk case final void Function([String? question]) ask
            when accounts) ...<Widget>[
          const SizedBox(height: 24),
          SectionLabel(l.askYourMoneyLabel),
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable?>[allowance]),
            builder: (BuildContext context, _) {
              final Allowance? day = allowance;
              // Used up, the questions show put away, with when they come
              // back, instead of being offered and then turned down.
              final bool out = day != null && day.left == 0;
              return Panel(
                children: <Widget>[
                  if (day != null && (out || day.few))
                    _AskLeft(
                      text: out
                          ? l.askNoneLeft(day.perDay)
                          : l.askLeftOf(day.left, day.perDay),
                    ),
                  for (final (IconData icon, String question)
                      in questions ??
                          <(IconData, String)>[
                            (Glyph.wallet, l.ownAskFree),
                            (Glyph.chartDonut, l.ownAskMonth),
                            (Glyph.coins, l.ownAskAll),
                          ])
                    _AskRow(
                      icon: icon,
                      text: question,
                      onTap: out ? null : () => ask(question),
                    ),
                  if (!out)
                    _AskRow(icon: Glyph.sparkle, text: l.askOther, onTap: ask)
                  else if (conversing)
                    _AskRow(
                      icon: Glyph.chatCircleDots,
                      text: l.askSeeConversation,
                      onTap: ask,
                    ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        SectionLabel(l.yourAccounts),
        Panel(
          children: <Widget>[
            for (final Account a in own.accounts)
              if (a.spendable) AccountRow(own: own, account: a),
            if (!accounts)
              ListTile(
                onTap: () => showAccountSheet(context, own: own),
                leading: Icon(Glyph.plus, color: context.colors.brand),
                title: Text(
                  l.addAccount,
                  style: context.type.titleSmall?.copyWith(
                    color: context.colors.brand,
                  ),
                ),
              ),
          ],
        ),
        // Savings, dollars and crypto apart: they are not in the figure.
        if (own.accounts.any((Account a) => !a.spendable)) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(l.homeAccountsApart, style: context.type.bodySmall),
          ),
          Panel(
            children: <Widget>[
              for (final Account a in own.accounts)
                if (!a.spendable) AccountRow(own: own, account: a),
            ],
          ),
        ],
        const SizedBox(height: 24),
        SectionLabel(
          l.recentMovements,
          trailing: recent.isEmpty
              ? null
              : TextButton(onPressed: onSeeAll, child: Text(l.seeAll)),
        ),
        if (recent.isEmpty)
          _Empty(
            title: l.noMovements,
            body: accounts ? l.noMovementsBody : l.noMovementsNoAccount,
          )
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
  /// for, the pay to split, then what it still leaves out. The fixed
  /// payments wait for an account to be paid from, and are left to
  /// «Termina de preparar Quincena» while it shows them, [fixedInSetup].
  List<_Todo> _todos(
    AppLocalizations l,
    Ledger ledger, {
    bool fixedInSetup = false,
  }) {
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
          open: (BuildContext context) => showEntrySheet(
            context,
            own: own,
            kind: EntryKind.income,
            draft: _payDraft(own, late),
          ),
        ),
      if (own.paidWithoutPlan) _payArrived(l, own, ledger),
      if (own.provisional && own.accounts.isNotEmpty && !fixedInSetup)
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
    this.also,
    this.doAlso,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final void Function(BuildContext context) open;

  /// Something else to do there, smaller, under what it says: what [doAlso]
  /// does.
  final String? also;
  final void Function(BuildContext context)? doAlso;
}

/// The pay of [payday] as the app already knows it, to confirm in one tap:
/// what the person said they get, filed as salary on that day, in the
/// account and with the name the last pay came with.
EntryDraft _payDraft(OwnController own, DateTime payday) {
  Entry? last;
  for (final Entry e in own.snapshot?.entries ?? const <Entry>[]) {
    if (e.kind == EntryKind.income &&
        e.category == 'salary' &&
        (last == null || e.date.isAfter(last.date))) {
      last = e;
    }
  }
  final Asset base = own.profile?.base ?? Asset.cop;
  bool inBase(Account a) => a.asset == base;
  final Account? account =
      own.accounts
          .where((Account a) => a.id == last?.accountId && inBase(a))
          .firstOrNull ??
      own.accounts
          .where(
            (Account a) =>
                a.spendable && inBase(a) && a.kind != AccountKind.card,
          )
          .firstOrNull;
  return EntryDraft(
    amount: own.profile?.pay,
    payee: last?.payee,
    category: 'salary',
    date: DateTime(payday.year, payday.month, payday.day),
    accountId: account?.id,
  );
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
  // Not knowing the pay, while it just said what came: one tap keeps it.
  final bool unknown = own.profile?.pay == null && total != null;
  return _Todo(
    also: unknown
        ? (fortnight ? l.paydayKeepPay(amount!) : l.paydayKeepPayOther(amount!))
        : null,
    doAlso: unknown
        ? (BuildContext context) async {
            final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
              context,
            );
            final String said = l.paydayKeptPay(amount!);
            final Profile? p = own.profile;
            if (p == null) return;
            await own.store.saveProfile(
              p.copyWith(pay: Decimal.parse('${ledger.major(total)}')),
            );
            messenger.showSnackBar(SnackBar(content: Text(said)));
          }
        : null,
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

/// One question to ask, or the way to ask another. Null [onTap] shows it
/// put away, as when no question is left today.
class _AskRow extends StatelessWidget {
  const _AskRow({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = ListTile(
      onTap: onTap,
      enabled: onTap != null,
      leading: Icon(icon, color: context.colors.brand),
      title: Text(text, style: context.type.bodyMedium),
      trailing: Icon(
        Glyph.caretRight,
        size: 18,
        color: context.colors.inkFaint,
      ),
    );
    // Dimmed as the questions page dims them, so both read as put away.
    return onTap == null ? Opacity(opacity: 0.5, child: row) : row;
  }
}

/// How many of the day's questions are left, or when they come back.
class _AskLeft extends StatelessWidget {
  const _AskLeft({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Row(
      children: <Widget>[
        Icon(Glyph.clock, size: 18, color: context.colors.inkSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.type.bodySmall)),
      ],
    ),
  );
}

/// Something to do, with what doing it is called: the whole row opens it,
/// and the word at its end says what that is. The [first] says it on a
/// button, small enough that the figure above stays what weighs most.
class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo, this.first = false});

  final _Todo todo;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final bool large = largeText(context);
    final Widget action = first
        ? FilledButton.tonal(
            onPressed: () => todo.open(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(todo.action),
          )
        : Text(
            todo.action,
            style: context.type.labelLarge?.copyWith(
              color: context.colors.brand,
            ),
          );
    final Widget caret = first
        ? const SizedBox.shrink()
        : Icon(Glyph.caretRight, size: 16, color: context.colors.brand);
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
                  if (todo.also case final String also)
                    TextButton(
                      onPressed: () => todo.doAlso?.call(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(also, textAlign: TextAlign.start),
                    ),
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

/// Inicio before any account: no figure yet, only the way to the first
/// account, which gives it one.
class _FirstAccount extends StatelessWidget {
  const _FirstAccount({required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Block(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AccountTile(AccountKind.wallet, size: 44),
          const SizedBox(height: 16),
          Text(l.firstAccountTitle, style: context.type.headlineSmall),
          const SizedBox(height: 6),
          Text(l.firstAccountBody, style: context.type.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showAccountSheet(context, own: own),
            icon: const Icon(Glyph.plus, size: 18),
            label: Text(l.firstAccountAction),
          ),
        ],
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
    // Told as «Puedes gastar» tells it: what will be free, with what is
    // kept apart said apart, never a balance that still holds it.
    final int free = projection.free(low);
    final int kept = projection.kept;
    final ProjectedDay? tight = projection.firstTouchingKept;
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
            comingFreeLine(
              l,
              free: free,
              on: low.date,
              // Nothing lowers it before payday: today is no day ahead.
              today: !low.date.isAfter(projection.days.first.date),
              expecting: expecting,
              amount: (int minor) => pesos(ledger.major(minor)),
            ),
            style: context.type.bodyMedium,
          ),
          if (kept > 0)
            Text(
              keptLine(l, ledger, (int minor) => pesos(ledger.major(minor))),
              style: context.type.bodySmall,
            ),
          if (tight != null)
            Text(
              // The same words and the same days as «Próximos 30 días».
              keptWarning(l, ledger)(
                sentence(dayOrToday(l, tight.date, ledger.today)),
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
  final FocusNode _focus = FocusNode();

  /// What is missing to answer, said under the price until it is typed.
  String? _missing;

  @override
  void dispose() {
    _price.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _check() {
    final Decimal? typed = parseAmount(_price.text);
    final int? price = typed == null || typed <= Decimal.zero
        ? null
        : widget.ledger.minor(typed.toDouble());
    // With no price there is nothing to weigh: it is asked for here.
    if (price == null) {
      setState(() => _missing = context.l10n.buyAskMissing);
      _focus.requestFocus();
      return;
    }
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
      focusNode: _focus,
      onChanged: (_) {
        if (_missing != null) setState(() => _missing = null);
      },
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
        prefixText: amountPrefix(widget.ledger.currency),
        errorText: _missing,
        errorMaxLines: 2,
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
