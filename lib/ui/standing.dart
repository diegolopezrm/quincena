import 'package:flutter/material.dart';

import '../data/ledger.dart';
import '../domain/pay_schedule.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'icons.dart';
import 'kit.dart';

/// [text] with its first letter in capitals, for a phrase that starts a
/// line here and sits mid-sentence elsewhere.
String sentence(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Where the money stands until payday: the one figure that can be spent,
/// until when, and the sum behind it.
///
/// Only one amount on the card reads as spendable. What the accounts hold
/// today is the first line of the sum, not a second figure beside it, and
/// each thing held back from it has its own line, so the figure is
/// explained before anyone has to ask.
class StandingCard extends StatelessWidget {
  const StandingCard({super.key, required this.ledger, this.onExplain});

  final Ledger ledger;

  /// Shows the sum account by account. Without it the card has no way to
  /// ask.
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final int free = ledger.freeUntilPayday;
    final int balance = ledger.balance;
    final DateTime payday = ledger.nextPayday;
    final int days = payday.difference(ledger.today).inDays;
    final bool short = free < 0;
    final double share = balance <= 0 ? 0 : (free / balance).clamp(0, 1);
    final String when = ledger.schedule is TwiceMonthly
        ? l.standingNextFortnight(days)
        : l.standingNextPay(days);
    final String figure = pesos(ledger.major(free.abs()));
    final String until = short
        ? l.standingShortUntil(dayMonth(payday))
        : l.standingUntil(dayMonth(payday));
    // What is held back from what is there, each only when there is some.
    final List<(String, int)> held = <(String, int)>[
      (
        l.standingPaymentsBefore(dayShortMonth(payday)),
        ledger.committedUntilPayday,
      ),
      (l.standingCushionLine, ledger.cushion),
      (l.standingEnvelopesLine, ledger.setAside),
      (l.standingReserveLine, ledger.reserved),
    ].where(((String, int) h) => h.$2 > 0).toList();
    final Color heldColor = context.colors.inkFaint.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            container: true,
            label: short
                ? l.standingShortSemantics(figure, dayMonth(payday), when)
                : l.standingSemantics(figure, dayMonth(payday), when),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.greeting(ledger.owner),
                  style: context.type.titleMedium?.copyWith(
                    color: context.colors.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  short ? l.standingShort : l.standingCanSpend,
                  style: context.type.labelMedium,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Figures(
                    figure,
                    style: context.type.displayLarge?.copyWith(
                      color: short ? context.colors.negative : null,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  until,
                  style: context.type.bodyLarge?.copyWith(
                    color: context.colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sentence(when), style: context.type.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: ClipRRect(
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
                      child: ColoredBox(color: heldColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Line(
            label: l.standingAvailable,
            value: pesos(ledger.major(balance)),
          ),
          for (final (String label, int amount) in held)
            _Line(
              label: label,
              value: pesos(-ledger.major(amount)),
              key: ValueKey<String>(label),
              swatch: heldColor,
            ),
          if (onExplain case final VoidCallback explain) ...<Widget>[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: explain,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              icon: const Icon(Glyph.info, size: 18),
              label: Text(l.freeExplainAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the sum under the figure: what it is and how much, with
/// the bar's color beside what the bar shows held back.
class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.label,
    required this.value,
    this.swatch,
  });

  final String label;
  final String value;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = context.type.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MergeSemantics(
        child: Row(
          children: <Widget>[
            if (swatch case final Color color) ...<Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(label, style: style)),
            const SizedBox(width: 12),
            Figures(value, style: style),
          ],
        ),
      ),
    );
  }
}
