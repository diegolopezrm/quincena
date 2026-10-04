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
  const StandingCard({
    super.key,
    required this.ledger,
    this.cardDebt = 0,
    this.onExplain,
    this.greet = true,
    this.caveat,
  });

  final Ledger ledger;

  /// What the credit cards counted here owe, in the ledger's smallest
  /// unit. With some, what the accounts hold and what the cards owe take a
  /// line each, so the debt is not taken off in silence.
  final int cardDebt;

  /// Shows the sum account by account. Without it the card has no way to
  /// ask.
  final VoidCallback? onExplain;

  /// Whether the card opens with the owner's name: the sample's does, to
  /// introduce the person it is about; someone's own card goes straight to
  /// the figure.
  final bool greet;

  /// What the figure still leaves out, said under it in caution: the fixed
  /// payments of someone who has not told them yet. Null when nothing is
  /// missing.
  final String? caveat;

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
    // The payment that comes first, under the payments line, so the next
    // thing due is in view and not only their total.
    final String? next = switch (ledger.committed.firstOrNull) {
      final Movement m => l.standingNextCharge(
        m.merchant.isEmpty ? l.timelineCharge : m.merchant,
        pesos(ledger.major(m.amount)),
        dayShortMonth(m.date),
      ),
      null => null,
    };
    // What is held back from what is there, each only when there is some.
    final List<(String, int, String?)> held = <(String, int, String?)>[
      (
        l.standingPaymentsBefore(dayShortMonth(payday)),
        ledger.committedUntilPayday,
        next,
      ),
      (l.standingCushionLine, ledger.cushion, null),
      (l.standingEnvelopesLine, ledger.setAside, null),
      (l.standingReserveLine, ledger.reserved, null),
    ].where(((String, int, String?) h) => h.$2 > 0).toList();
    final Color heldColor = context.colors.inkFaint.withValues(alpha: 0.35);
    final String summary = short
        ? l.standingShortSemantics(figure, dayMonth(payday), when)
        : l.standingSemantics(figure, dayMonth(payday), when);
    // Beside the label it asks about, at the size a finger needs; with large
    // text it drops under the label instead of squeezing it.
    final Widget? explain = switch (onExplain) {
      final VoidCallback explain => TextButton.icon(
        onPressed: explain,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        icon: const Icon(Glyph.info, size: 18),
        label: Text(l.freeExplainAction),
      ),
      null => null,
    };

    return Container(
      // Beside the label, the room the button needs around it is the
      // card's top margin.
      padding: EdgeInsets.fromLTRB(
        20,
        greet || explain == null ? 16 : 4,
        20,
        14,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Read as one sentence, with the way to ask where it comes from
          // a button of its own inside it.
          Semantics(
            container: true,
            label: caveat == null ? summary : '$summary $caveat',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (greet)
                  ExcludeSemantics(
                    child: Text(
                      l.greeting(ledger.owner),
                      style: context.type.titleMedium?.copyWith(
                        color: context.colors.inkSoft,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: <Widget>[
                      // As tall as the button, so the label keeps its room
                      // above it when large text puts the button below.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: explain == null ? 0 : 48,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1,
                          child: ExcludeSemantics(
                            child: Text(
                              short ? l.standingShort : l.standingCanSpend,
                              style: context.type.labelMedium,
                            ),
                          ),
                        ),
                      ),
                      ?explain,
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (explain == null) const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        // A new figure counts its way there from the one
                        // before, so a change reads as a change; at once with
                        // animations turned down.
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: free.abs().toDouble()),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder: (BuildContext context, double value, _) =>
                              Figures(
                                pesos(ledger.major(value.round())),
                                style: context.type.displayLarge?.copyWith(
                                  color: short ? context.colors.negative : null,
                                ),
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
                      if (caveat case final String text) ...<Widget>[
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Icon(
                              Glyph.warningCircle,
                              size: 16,
                              color: context.colors.caution,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                text,
                                style: context.type.bodySmall?.copyWith(
                                  color: context.colors.caution,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          _Line(
            label: l.standingAvailable,
            value: pesos(ledger.major(balance + cardDebt)),
          ),
          if (cardDebt > 0)
            _Line(
              label: l.standingCardDebtLine,
              value: pesos(-ledger.major(cardDebt)),
            ),
          for (final (String label, int amount, String? detail) in held)
            _Line(
              label: label,
              value: pesos(-ledger.major(amount)),
              key: ValueKey<String>(label),
              swatch: heldColor,
              detail: detail,
            ),
        ],
      ),
    );
  }
}

/// One line of the sum under the figure: what it is and how much, with
/// the bar's color beside what the bar shows held back, and what explains
/// it under it, heard with it.
class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.label,
    required this.value,
    this.swatch,
    this.detail,
  });

  final String label;
  final String value;
  final Color? swatch;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = context.type.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
            if (detail case final String text)
              Padding(
                padding: EdgeInsets.only(left: swatch == null ? 0 : 16),
                child: Text(text, style: context.type.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
