import 'package:flutter/material.dart';

import '../data/ledger.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'kit.dart';

/// Where the money stands until payday: what is free, what is already
/// committed, and what is there in all.
class StandingCard extends StatelessWidget {
  const StandingCard({
    super.key,
    required this.ledger,
    this.balanceLabel,
    this.detail,
  });

  final Ledger ledger;

  /// What the last line calls the balance: "In the account" by default.
  final String? balanceLabel;

  /// The line under the figure. The demo's tells Valentina's story; someone's
  /// own accounts get one that only states what is committed.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final int free = ledger.freeUntilPayday;
    final int committed = ledger.committedUntilPayday;
    final int balance = ledger.balance;
    final DateTime payday = ledger.nextPayday;
    final int days = payday.difference(ledger.today).inDays;
    final double share = balance <= 0 ? 0 : (free / balance).clamp(0, 1);

    return Semantics(
      container: true,
      label: context.l10n.standingSemantics(
        dayMonth(payday),
        pesos(ledger.major(free)),
        days,
        pesos(ledger.major(balance)),
      ),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.greeting(ledger.owner),
              style: context.type.titleMedium?.copyWith(
                color: context.colors.inkSoft,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.freeUntil(dayMonth(payday)),
              style: context.type.labelMedium,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Figures(
                pesos(ledger.major(free)),
                style: context.type.displayLarge,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail ??
                  context.l10n.standingDetail(
                    days,
                    pesos(ledger.major(committed)),
                  ),
              style: context.type.bodyMedium,
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 10,
                child: Row(
                  // An empty ColoredBox takes the smallest height it is
                  // allowed, which in a Row is none.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      flex: (share * 1000).round(),
                      child: ColoredBox(color: context.colors.brand),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: ((1 - share) * 1000).round(),
                      child: ColoredBox(
                        color: context.colors.inkFaint.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: <Widget>[
                _Key(
                  color: context.colors.brand,
                  label: context.l10n.legendFree,
                ),
                _Key(
                  color: context.colors.inkFaint.withValues(alpha: 0.35),
                  label: context.l10n.legendCommitted,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: context.colors.line, height: 1),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    balanceLabel ?? context.l10n.inTheAccount,
                    style: context.type.bodySmall,
                  ),
                ),
                Figures(
                  pesos(ledger.major(balance)),
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.inkSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.type.bodySmall),
    ],
  );
}
