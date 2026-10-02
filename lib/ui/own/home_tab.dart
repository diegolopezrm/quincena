import 'package:flutter/material.dart';

import '../../data/ledger.dart';
import '../../domain/decisions.dart';
import '../../domain/projection.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import '../standing.dart';
import 'accounts_tab.dart';
import 'close_page.dart';
import 'coming_days_page.dart';
import 'free_explained.dart';
import 'inbox_page.dart';
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
          onExplain: () => showFreeExplained(context, own),
          balanceLabel: l.groupSpendable,
          detail: <String>[
            l.standingDaysLeft(
              ledger.nextPayday.difference(ledger.today).inDays,
            ),
            if (ledger.committedUntilPayday > 0)
              l.standingCommittedOwn(
                pesos(ledger.major(ledger.committedUntilPayday)),
              ),
            if (ledger.cushion > 0)
              l.standingCushion(pesos(ledger.major(ledger.cushion))),
          ].join(' '),
        ),
        if (own.projection?.latePay case final DateTime late) ...<Widget>[
          const SizedBox(height: 12),
          _Notice(text: l.payLate(dayMonth(late))),
        ],
        if (own.pendingInbox.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InboxBanner(own: own),
        ],
        const SizedBox(height: 12),
        _ComingCard(own: own, ledger: ledger),
        if (missing.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _Notice(
            text: l.ratesMissing(missing.map((Asset a) => a.code).join(', ')),
          ),
        ],
        if (onAsk case final void Function([String? question]) ask) ...<Widget>[
          const SizedBox(height: 28),
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
        const SizedBox(height: 28),
        SectionLabel(l.yourAccounts),
        Panel(
          children: <Widget>[
            for (final Account a in own.accounts)
              AccountRow(own: own, account: a),
          ],
        ),
        const SizedBox(height: 28),
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

class _InboxBanner extends StatelessWidget {
  const _InboxBanner({required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Material(
      color: context.colors.brandSoft,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => InboxPage(own: own),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(Glyph.tray, size: 24, color: context.colors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.inboxBanner(own.pendingInbox.length),
                      style: context.type.titleSmall,
                    ),
                    Text(l.inboxBannerBody, style: context.type.bodySmall),
                  ],
                ),
              ),
              Icon(Glyph.arrowRight, size: 18, color: context.colors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
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

/// What comes until payday: the lowest point, a tight day if there is one,
/// and the ways to look closer or try a purchase. In the week after a
/// payday, the close of the period that ended.
class _ComingCard extends StatelessWidget {
  const _ComingCard({required this.own, required this.ledger});

  final OwnController own;
  final Ledger ledger;

  void _open(BuildContext context, Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Projection? projection = own.projection;
    if (projection == null) return const SizedBox.shrink();
    final ProjectedDay low = projection.lowestBeforePayday;
    final ProjectedDay? tight = projection.firstTight;
    final PeriodClose? close = closePeriod(ledger);
    final bool closeFresh =
        close != null && ledger.today.difference(close.end).inDays <= 7;
    return Block(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.homeComing, style: context.type.titleSmall),
          const SizedBox(height: 4),
          Text(
            l.comingLowest(
              pesos(ledger.major(low.sure)),
              dayShortMonth(low.date),
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
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              TextButton.icon(
                onPressed: () =>
                    _open(context, ComingDaysPage(own: own, tryPurchase: true)),
                icon: const Icon(Glyph.shoppingBag, size: 18),
                label: Text(l.buyTitle),
              ),
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
