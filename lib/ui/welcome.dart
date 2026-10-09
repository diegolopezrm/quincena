import 'package:flutter/material.dart';

import '../agent/scripted_agent.dart';
import '../data/ledger.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'icons.dart';
import 'own/free_explained.dart';
import 'standing.dart';

/// What the screen shows before the first question: where the money stands,
/// and what to ask it.
class Welcome extends StatelessWidget {
  const Welcome({
    super.key,
    required this.ledger,
    required this.onAsk,
    this.onRecordings,
    this.starters,
    this.icons,
    this.standing = true,
    this.footer,
    this.enabled = true,
  });

  final Ledger ledger;
  final ValueChanged<String> onAsk;

  /// Whether the questions can be asked now: dimmed and untouchable when
  /// the day's are used up, rather than offered and then turned down.
  final bool enabled;

  /// The questions offered; the scripted agent's five by default.
  final List<String>? starters;

  /// One per question in [starters].
  final List<IconData>? icons;

  /// Whether the card with where the money stands goes first.
  final bool standing;

  /// What goes under the questions.
  final Widget? footer;

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
    final List<String> starters =
        this.starters ??
        ScriptedAgent.startersFor(Localizations.localeOf(context).languageCode);
    final List<IconData> icons = this.icons ?? _icons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (standing) ...<Widget>[
          StandingCard(
            ledger: ledger,
            onExplain: () => showLedgerExplained(context, ledger),
          ),
          const SizedBox(height: 28),
        ],
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
                      icon: icons[i % icons.length],
                      text: starters[i],
                      onTap: enabled ? () => onAsk(starters[i]) : null,
                    ),
                  ),
              ],
            );
          },
        ),
        ?footer,
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

class _Starter extends StatelessWidget {
  const _Starter({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;

  /// Null while it cannot be asked: it shows dimmed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget starter = Material(
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
    return onTap == null ? Opacity(opacity: 0.5, child: starter) : starter;
  }
}
