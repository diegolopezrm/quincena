import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../kit.dart';
import 'entry_sheet.dart';
import 'look.dart';

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
  });

  final OwnController own;
  final Entry entry;

  /// Shown inside one account's page, where its name goes without saying.
  final bool inAccount;

  Account? _account(String id) => own.snapshot?.account(id);

  String? _otherLegAccount() {
    for (final Entry e in own.snapshot?.entries ?? const <Entry>[]) {
      if (e.transferId == entry.transferId && e.id != entry.id) {
        return _account(e.accountId)?.name;
      }
    }
    return null;
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
    final String title;
    if (transfer) {
      final String other = _otherLegAccount() ?? '';
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
    final List<String> detail = <String>[
      if (transfer)
        l.kindTransfer
      else if (cost != null)
        moneyText(cost, base: own.profile?.base)
      else if (entry.payee.isNotEmpty)
        categoryName,
      if (!inAccount && !transfer) account.name,
      if (entry.date.isAfter(endOfToday(own.today))) l.scheduled,
    ]..removeWhere((String s) => s.isEmpty);

    final Money money = Money(entry.amount, account.asset);
    final Money? base = account.asset == own.profile?.base
        ? null
        : own.inBase(money);
    final Color amountColor = transfer || cost != null
        ? context.colors.inkSoft
        : entry.amount > Decimal.zero
        ? context.colors.positive
        : context.colors.ink;

    return InkWell(
      onTap: () => showEntrySheet(context, own: own, entry: entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            CategoryDisc(transfer || cost != null ? null : category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: context.type.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail.join(' · '),
                      style: context.type.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
            ),
          ],
        ),
      ),
    );
  }
}

DateTime endOfToday(DateTime today) =>
    DateTime(today.year, today.month, today.day, 23, 59, 59);

/// Movements grouped under the day they happened.
class MovementGroups extends StatelessWidget {
  const MovementGroups({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final MapEntry<DateTime, List<Entry>> day
            in days.entries) ...<Widget>[
          SectionLabel(_dayLabel(l, day.key)),
          Panel(
            children: <Widget>[
              for (final Entry e in day.value)
                MovementRow(own: own, entry: e, inAccount: inAccount),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
