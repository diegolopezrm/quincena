import 'package:flutter/material.dart';

import '../../data/category.dart';
import '../../data/ledger.dart';
import '../../domain/decisions.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'coming_days_page.dart';

/// The pay period that just ended, in three cards: what changed against the
/// one before, what comes until the next payday, and one thing to do. Each
/// conclusion opens the movements behind it.
class ClosePage extends StatelessWidget {
  const ClosePage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final PeriodClose? close = ledger == null
          ? null
          : closePeriod(
              ledger,
              hasGoals: own.snapshot?.goals.isNotEmpty ?? false,
            );
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.closeTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: <Widget>[
                if (ledger == null || close == null)
                  Block(
                    child: Text(l.closeNone, style: context.type.bodyMedium),
                  )
                else
                  ..._cards(context, ledger, close),
              ],
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _cards(BuildContext context, Ledger ledger, PeriodClose close) {
    final AppLocalizations l = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;
    String amount(int minor) => pesos(ledger.major(minor));
    final DateTime last = close.end.subtract(const Duration(days: 1));
    final int? before = close.spentBefore;
    final int committed = close.coming.fold(
      0,
      (int a, Movement m) => a + m.amount,
    );

    void payments(Category category) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l.closePaymentsTitle(
                category.labelIn(lang),
                dayShortMonth(close.start),
                dayShortMonth(last),
              ),
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 12),
            for (final Movement m in close.movementsOf(ledger, category))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            m.merchant.isEmpty
                                ? category.labelIn(lang)
                                : m.merchant,
                            style: context.type.titleSmall,
                          ),
                          Text(
                            dayShortMonth(m.date),
                            style: context.type.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Figures(amount(-m.amount), style: context.type.titleSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    void days() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ComingDaysPage(own: own),
      ),
    );

    final String spentLine = close.spent == 0
        ? l.closeSpentNone
        : before == null
        ? l.closeSpentFirst(amount(close.spent))
        : close.spent > before
        ? l.closeSpentMore(amount(close.spent), amount(close.spent - before))
        : close.spent < before
        ? l.closeSpentLess(amount(close.spent), amount(before - close.spent))
        : l.closeSpentSame(amount(close.spent));

    return <Widget>[
      Text(
        l.closeRange(dayMonth(close.start), dayMonth(last)),
        style: context.type.bodyMedium,
      ),
      const SizedBox(height: 16),
      _Card(
        title: l.closeChanged,
        children: <Widget>[
          Text(spentLine, style: context.type.bodyMedium),
          const SizedBox(height: 8),
          for (final CategoryChange c in close.changes.take(3))
            InkWell(
              onTap: () => payments(c.category),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        c.category.labelIn(lang),
                        style: context.type.titleSmall,
                      ),
                    ),
                    Figures(amount(c.now), style: context.type.titleSmall),
                    if (c.before != null) ...<Widget>[
                      const SizedBox(width: 10),
                      Figures(
                        c.difference == 0
                            ? '='
                            : pesos(ledger.major(c.difference), signed: true),
                        style: context.type.bodySmall,
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Glyph.caretRight,
                      size: 16,
                      color: context.colors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _Card(
        title: l.closeComing,
        children: <Widget>[
          Text(
            committed > 0
                ? l.closeComingTotal(
                    dayMonth(ledger.nextPayday),
                    amount(committed),
                  )
                : l.closeComingNone(dayMonth(ledger.nextPayday)),
            style: context.type.bodyMedium,
          ),
          for (final Movement m in close.coming.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${dayShortMonth(m.date)} · ${m.merchant}',
                      style: context.type.bodyMedium,
                    ),
                  ),
                  Figures(amount(-m.amount), style: context.type.bodyMedium),
                ],
              ),
            ),
          if (close.coming.length > 5)
            Text(
              l.closeComingMore(close.coming.length - 5),
              style: context.type.bodySmall,
            ),
          const SizedBox(height: 8),
          Text(
            l.closeFree(amount(ledger.freeUntilPayday)),
            style: context.type.titleSmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: days, child: Text(l.closeSeeDays)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _Card(
        title: l.closeAction,
        children: <Widget>[
          Text(switch (close.action) {
            CloseAction.tightDay => l.closeActionTight(
              dayMonth(close.tightDay!),
            ),
            CloseAction.lookAtCategory => () {
              final CategoryChange c = close.changes.firstWhere(
                (CategoryChange x) => x.category == close.actionCategory,
              );
              return l.closeActionCategory(
                c.category.labelIn(lang),
                amount(c.before ?? 0),
                amount(c.now),
              );
            }(),
            CloseAction.moveToGoal => l.closeActionGoal(
              amount(ledger.freeUntilPayday),
            ),
            null => l.closeActionNone,
          }, style: context.type.bodyMedium),
          if (close.action == CloseAction.tightDay)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: days, child: Text(l.closeSeeDays)),
            ),
          if (close.actionCategory case final Category category)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => payments(category),
                child: Text(l.closeSeePayments),
              ),
            ),
        ],
      ),
    ];
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Block(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: context.type.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}
