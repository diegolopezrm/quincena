import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../domain/account_trace.dart';
import '../../domain/records.dart';
import '../../domain/shared.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/movement_search.dart';
import '../../own/own_controller.dart';
import '../../own/repeats.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'entry_sheet.dart';
import 'look.dart';
import 'repeat_sheet.dart';

/// The movements to show, newest first, with each transfer once: by its
/// leg in [accountId] when the list is one account's, by the leg that left
/// otherwise.
List<Entry> visibleEntries(OwnController own, {String? accountId}) => <Entry>[
  for (final Entry e
      in (own.snapshot?.entries ?? const <Entry>[]).reversed.toList()
        ..sort((Entry a, Entry b) => b.date.compareTo(a.date)))
    if (accountId != null
        ? e.accountId == accountId
        : e.transferId == null || e.amount < Decimal.zero)
      e,
];

/// One movement: what it was, where, and how much.
class MovementRow extends StatelessWidget {
  const MovementRow({
    super.key,
    required this.own,
    required this.entry,
    this.inAccount = false,
    this.markRepeats = false,
  });

  final OwnController own;
  final Entry entry;

  /// Shown inside one account's page, where its name goes without saying.
  final bool inAccount;

  /// Whether a movement that may repeat another says so, with a way to
  /// look at both: in the full lists, where the two can be compared.
  final bool markRepeats;

  Account? _account(String id) => own.snapshot?.account(id);

  /// The transfer's other leg, if it is one and the leg is there.
  Entry? _otherLeg() {
    for (final Entry e in own.snapshot?.entries ?? const <Entry>[]) {
      if (e.transferId == entry.transferId && e.id != entry.id) return e;
    }
    return null;
  }

  /// What a transfer was: a purchase or a sale when it traded crypto, as
  /// the account it arrived in sees it, or in a list of one account's, as
  /// that account does; a transfer otherwise.
  String _transferKind(AppLocalizations l, Account account, Entry? other) {
    final Account? there = other == null ? null : _account(other.accountId);
    final TraceKind kind = there == null
        ? transferKind(entry, account.asset, null)
        : inAccount || entry.amount > Decimal.zero
        ? transferKind(entry, account.asset, there.asset)
        : transferKind(other!, there.asset, account.asset);
    return switch (kind) {
      TraceKind.bought => l.tradeBought,
      TraceKind.sold => l.tradeSold,
      _ => l.kindTransfer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Account? account = _account(entry.accountId);
    if (account == null) return const SizedBox.shrink();
    final bool transfer = entry.transferId != null;
    final Money? cost = entry.cost;
    final String? category = entry.category;
    final String categoryName = category == null
        ? ''
        : categoryNameFor(context, category, own.categories);
    final Entry? otherLeg = transfer ? _otherLeg() : null;
    final String title;
    if (transfer) {
      final String other = otherLeg == null
          ? ''
          : _account(otherLeg.accountId)?.name ?? '';
      title = entry.amount < Decimal.zero
          ? '${account.name} → $other'
          : '$other → ${account.name}';
    } else if (cost != null) {
      title = entry.payee.isNotEmpty
          ? entry.payee
          : (entry.amount > Decimal.zero ? l.tradeBought : l.tradeSold);
    } else {
      title = entry.payee.isNotEmpty
          ? entry.payee
          : (categoryName.isNotEmpty ? categoryName : l.kindExpense);
    }
    // What it was and where: the line a narrow row may cut short.
    final List<String> detail = <String>[
      if (transfer)
        _transferKind(l, account, otherLeg)
      else if (cost != null)
        moneyText(cost, base: own.profile?.base)
      else if (entry.payee.isNotEmpty)
        categoryName,
      if (!inAccount && !transfer) account.name,
    ]..removeWhere((String s) => s.isEmpty);
    // What sets it apart, each in a label of its own under that line:
    // cut with it, the mark is what went.
    final Account? there = otherLeg == null
        ? null
        : _account(otherLeg.accountId);
    final List<Widget> marks = <Widget>[
      if (entry.date.isAfter(endOfToday(own.today))) _Tag(l.scheduled),
      if (own.splitOf(entry.id) case (
        _,
        final SharedExpense split,
      ) when own.ledger != null)
        _Tag(l.splitYours(pesos(own.ledger!.major(split.shares[meId] ?? 0)))),
      // Between currencies the other side is another amount: what arrived
      // for the money that left, what left for the money that arrived.
      if (otherLeg != null && there != null && there.asset != account.asset)
        _Tag(
          (entry.amount < Decimal.zero ? l.transferArrived : l.transferSent)(
            moneyText(
              Money(otherLeg.amount.abs(), there.asset),
              base: own.profile?.base,
            ),
          ),
        ),
      if (markRepeats ? own.repeats[entry.id] : null
          case final PossibleRepeat pair)
        _RepeatMark(
          about: title,
          onPressed: () => showRepeatSheet(context, own: own, pair: pair),
        ),
    ];

    final Money money = Money(entry.amount, account.asset);
    final Money? base = account.asset == own.profile?.base
        ? null
        : own.inBase(money);
    final Color amountColor = transfer || cost != null
        ? context.colors.inkSoft
        : entry.amount > Decimal.zero
        ? context.colors.positive
        : context.colors.ink;
    // With large text the row is read top to bottom, as iOS lays out its
    // own at those sizes: the category, the name whole, then the amount.
    // Side by side neither could be read whole.
    final bool large = largeText(context);
    final Widget disc = CategoryDisc(
      transfer || cost != null ? null : category,
    );
    final Widget names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: context.type.titleSmall,
          // A transfer's title is both accounts: two lines keep both.
          maxLines: large ? null : (transfer ? 2 : 1),
          overflow: large ? null : TextOverflow.ellipsis,
        ),
        if (detail.isNotEmpty)
          Text(
            detail.join(' · '),
            style: context.type.bodySmall,
            maxLines: large ? null : 1,
            overflow: large ? null : TextOverflow.ellipsis,
          ),
        if (marks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: marks,
            ),
          ),
      ],
    );
    final Widget amounts = Column(
      crossAxisAlignment: large
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: <Widget>[
        Figures(
          moneyText(
            transfer && !inAccount ? money.abs() : money,
            base: own.profile?.base,
            signed: !transfer || inAccount,
          ),
          style: context.type.titleSmall?.copyWith(color: amountColor),
        ),
        if (base != null)
          Figures(
            '≈ ${moneyText(transfer && !inAccount ? base.abs() : base, base: own.profile?.base)}',
            style: context.type.bodySmall,
          ),
      ],
    );

    return InkWell(
      onTap: () => showEntrySheet(context, own: own, entry: entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  disc,
                  const SizedBox(height: 8),
                  names,
                  const SizedBox(height: 4),
                  amounts,
                ],
              )
            : Row(
                children: <Widget>[
                  disc,
                  const SizedBox(width: 12),
                  Expanded(child: names),
                  const SizedBox(width: 12),
                  amounts,
                ],
              ),
      ),
    );
  }
}

/// A mark on a row, such as «Programado» or the person's part of a shared
/// expense, in a soft pill of its own: never cut, and with large text it
/// wraps like the rest. In ink: it says what a row is, it asks nothing.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: context.colors.sunken,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: context.type.labelMedium?.copyWith(color: context.colors.inkSoft),
    ),
  );
}

/// Says a movement may repeat another, in caution's soft amber: a chip
/// that opens both, to take the repeat away or say they are two.
class _RepeatMark extends StatelessWidget {
  const _RepeatMark({required this.about, required this.onPressed});

  /// The movement's name, said with the mark to a screen reader: two rows
  /// may carry one.
  final String about;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    onPressed: onPressed,
    avatar: Icon(Glyph.copy, size: 16, color: context.colors.caution),
    label: Text(
      context.l10n.repeatMark,
      semanticsLabel: context.l10n.actionOn(context.l10n.repeatMark, about),
    ),
    labelStyle: context.type.labelMedium?.copyWith(color: context.colors.ink),
    backgroundColor: context.colors.cautionSoft,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
  );
}

DateTime endOfToday(DateTime today) =>
    DateTime(today.year, today.month, today.day, 23, 59, 59);

/// Movements grouped under the day they happened, as a sliver for a
/// CustomScrollView: each day is built as it scrolls into view, so a long
/// history costs only what shows.
class MovementGroups extends StatelessWidget {
  const MovementGroups.sliver({
    super.key,
    required this.own,
    required this.entries,
    this.inAccount = false,
  });

  final OwnController own;
  final List<Entry> entries;
  final bool inAccount;

  String _dayLabel(AppLocalizations l, DateTime day) {
    final DateTime today = own.today;
    final DateTime d = DateTime(day.year, day.month, day.day);
    if (d == today) return l.today;
    if (d == today.subtract(const Duration(days: 1))) return l.yesterday;
    return weekdayDayMonth(d);
  }

  /// What the movements of one day add up to, in each currency, beside its
  /// title: in one account's list its transfers count too, as they moved
  /// its money. Empty when it all comes to nothing.
  String _dayTotal(List<Entry> day) => <String>[
    for (final Money m in totalsOf(
      day,
      assetOf: (String id) => own.snapshot?.account(id)?.asset,
      base: own.profile?.base,
      transfers: inAccount,
    ))
      if (!m.isZero) moneyText(m, base: own.profile?.base, signed: true),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Map<DateTime, List<Entry>> days = <DateTime, List<Entry>>{};
    for (final Entry e in entries) {
      days
          .putIfAbsent(
            DateTime(e.date.year, e.date.month, e.date.day),
            () => <Entry>[],
          )
          .add(e);
    }
    final List<MapEntry<DateTime, List<Entry>>> list = days.entries.toList();
    return SliverList.builder(
      itemCount: list.length,
      itemBuilder: (BuildContext context, int i) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionLabel(
            _dayLabel(l, list[i].key),
            trailing: switch (_dayTotal(list[i].value)) {
              '' => null,
              final String total => Figures(
                total,
                style: context.type.labelMedium,
              ),
            },
          ),
          Panel(
            children: <Widget>[
              for (final Entry e in list[i].value)
                MovementRow(
                  own: own,
                  entry: e,
                  inAccount: inAccount,
                  markRepeats: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
