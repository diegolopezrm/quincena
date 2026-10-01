import 'package:flutter/material.dart';

import '../agent/scripted_agent.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'icons.dart';

/// What the screen shows before the first question: where the money stands,
/// and what to ask it.
class Welcome extends StatelessWidget {
  const Welcome({
    super.key,
    required this.ledger,
    required this.onAsk,
    this.onRecordings,
  });

  final Ledger ledger;
  final ValueChanged<String> onAsk;

  /// Opens the sessions Gemini answered for real; null when there are none.
  final VoidCallback? onRecordings;

  static const List<IconData> _icons = <IconData>[
    Glyph.chartDonut,
    Glyph.airplaneTilt,
    Glyph.arrowsClockwise,
    Glyph.chartBar,
    Glyph.plusCircle,
  ];

  @override
  Widget build(BuildContext context) {
    final List<String> starters = ScriptedAgent.startersFor(
      Localizations.localeOf(context).languageCode,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Standing(ledger: ledger),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            context.l10n.askYourMoney,
            style: context.type.labelSmall,
          ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final bool two = box.maxWidth >= 560;
            final double half = (box.maxWidth - 12) / 2;
            // On a wide screen the first question, the one the story starts
            // with, takes the whole row, and the other four pair up below it
            // instead of leaving the fifth alone in a row of its own.
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (var i = 0; i < starters.length; i++)
                  SizedBox(
                    width: !two || i == 0 ? box.maxWidth : half,
                    child: _Starter(
                      icon: _icons[i],
                      text: starters[i],
                      onTap: () => onAsk(starters[i]),
                    ),
                  ),
              ],
            );
          },
        ),
        if (onRecordings case final VoidCallback open) ...<Widget>[
          const SizedBox(height: 18),
          Center(
            child: TextButton.icon(
              onPressed: open,
              icon: const Icon(Glyph.sparkle, size: 18),
              label: Text(context.l10n.seeRecorded),
            ),
          ),
        ],
      ],
    );
  }
}

class _Standing extends StatelessWidget {
  const _Standing({required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final int free = ledger.freeUntilPayday;
    final int committed = ledger.committedUntilPayday;
    final int balance = ledger.balance;
    final DateTime payday = ledger.nextPayday;
    final int days = payday.difference(appToday).inDays;
    final double share = balance <= 0 ? 0 : (free / balance).clamp(0, 1);

    return Semantics(
      container: true,
      label: context.l10n.standingSemantics(
        dayMonth(payday),
        pesos(free),
        days,
        pesos(balance),
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
              child: Figures(pesos(free), style: context.type.displayLarge),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.standingDetail(days, pesos(committed)),
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
                    context.l10n.inTheAccount,
                    style: context.type.bodySmall,
                  ),
                ),
                Figures(
                  pesos(balance),
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

class _Starter extends StatelessWidget {
  const _Starter({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: context.colors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: context.type.titleSmall)),
              Icon(Glyph.arrowRight, size: 18, color: context.colors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
