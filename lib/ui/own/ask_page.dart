import 'dart:async';

import 'package:flutter/material.dart';

import '../../ai/allowance.dart';
import '../../ai/cloud.dart';
import '../../l10n/l10n.dart';
import '../../domain/plan.dart';
import '../../domain/records.dart';
import '../../own/own_controller.dart';
import '../../own/own_tools.dart';
import '../../session/session.dart';
import '../../theme/tokens.dart';
import '../ask_bar.dart';
import '../conversation.dart';
import '../icons.dart';
import '../welcome.dart';
import 'free_explained.dart';
import 'gemini_note_page.dart';

/// The questions offered before the first one, for the person's own money.
List<String> ownStarters(AppLocalizations l) => <String>[
  l.ownAskFree,
  l.ownAskMonth,
  l.ownAskAll,
  l.ownAskCompare,
  l.ownAskRecord,
];

const List<IconData> _starterIcons = <IconData>[
  Glyph.wallet,
  Glyph.chartDonut,
  Glyph.coins,
  Glyph.chartBar,
  Glyph.plusCircle,
];

/// Questions to suggest in the ask bar, from what this account holds: a
/// goal by its name, a card's debt, crypto, and what anyone can ask.
List<String> askExamples(AppLocalizations l, OwnController own) => <String>[
  l.askExampleBuy,
  if (own.goalShares.firstOrNull case final GoalShare g)
    l.askExampleGoal(g.name),
  l.askExampleWeekend,
  if (own.accounts.any(
    (Account a) =>
        a.kind == AccountKind.card && (own.balances[a.id]?.isNegative ?? false),
  ))
    l.askExampleCard,
  if (own.portfolio.hasHoldings) l.askExampleCrypto,
  l.askExampleMost,
];

/// Asking Gemini about the person's own money, through Quincena's project:
/// the same conversation as the demo's, over their own accounts.
class AskPage extends StatefulWidget {
  const AskPage({
    super.key,
    required this.own,
    this.allowance,
    this.question,
    this.session,
  });

  final OwnController own;

  /// The day's questions; null leaves them uncounted.
  final Allowance? allowance;

  /// A question picked on the home screen, asked as the page opens.
  final String? question;

  /// A conversation to show instead of a new one, for tests.
  final Session? session;

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  Session? _session;
  late final ConversationFollower _follower = ConversationFollower(session);

  Session get session => _session!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session != null) return;
    _session =
        widget.session ??
        Session(
          mode: AgentMode.gemini,
          language: Localizations.localeOf(context).languageCode,
          ledgerOf: () => widget.own.ledger!,
          toolsFor: (_) => ownTools(widget.own),
          own: true,
          allowance: widget.allowance,
        );
    // App Check and the anonymous sign-in take a moment the first time;
    // better while the person reads the questions than after they ask.
    if (widget.session == null) unawaited(Cloud.start());
    if (widget.question case final String question) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.ask(question);
      });
    }
  }

  @override
  void dispose() {
    _follower.dispose();
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  void _openNote() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          GeminiNotePage(perDay: widget.allowance?.perDay),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[session, widget.allowance]),
      builder: (BuildContext context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.askTitle, style: context.type.titleLarge),
          actions: <Widget>[
            if (session.turns.isNotEmpty)
              NewConversationButton(
                onPressed: () => startNewConversation(context, session),
              ),
            IconButton(
              tooltip: l.askWhatSees,
              onPressed: _openNote,
              icon: const Icon(Glyph.info),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: FollowedScroll(
                follower: _follower,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _Column(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: session.turns.isEmpty
                            ? Welcome(
                                ledger: session.ledger,
                                onAsk: session.ask,
                                standing: false,
                                starters: ownStarters(l),
                                icons: _starterIcons,
                                footer: _Footer(
                                  allowance: widget.allowance,
                                  onNote: _openNote,
                                ),
                              )
                            : Conversation(
                                session: session,
                                follower: _follower,
                                onExplainFree: () =>
                                    showFreeExplained(context, widget.own),
                              ),
                      ),
                    ),
                  ),
                  if (session.turns.isNotEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: SizedBox(height: 120),
                    ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.canvas,
                border: Border(top: BorderSide(color: context.colors.line)),
              ),
              child: SafeArea(
                top: false,
                child: _Column(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: AskBar(
                      onAsk: session.ask,
                      enabled: !session.busy,
                      examples: askExamples(l, widget.own),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many questions are left today, and what Gemini gets to see.
class _Footer extends StatelessWidget {
  const _Footer({required this.allowance, required this.onNote});

  final Allowance? allowance;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: <Widget>[
          if (allowance case final Allowance a)
            Text(l.askLeft(a.left), style: context.type.bodySmall),
          TextButton.icon(
            onPressed: onNote,
            icon: const Icon(Glyph.lock, size: 16),
            label: Text(l.askWhatSees),
          ),
        ],
      ),
    );
  }
}

/// Keeps reading width comfortable on a wide screen.
class _Column extends StatelessWidget {
  const _Column({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: child,
    ),
  );
}
