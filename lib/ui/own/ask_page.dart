import 'package:flutter/material.dart';

import '../../ai/allowance.dart';
import '../../l10n/l10n.dart';
import '../../domain/plan.dart';
import '../../domain/records.dart';
import '../../own/own_controller.dart';
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
///
/// The conversation is the shell's, kept while the app is open: leaving
/// this page and coming back finds it as it was.
class AskPage extends StatefulWidget {
  const AskPage({
    super.key,
    required this.own,
    required this.session,
    this.allowance,
    this.question,
  });

  final OwnController own;

  /// The conversation to show, which outlives the page.
  final Session session;

  /// The day's questions; null leaves them uncounted.
  final Allowance? allowance;

  /// A question picked on the home screen, asked as the page opens.
  final String? question;

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  late final ConversationFollower _follower = ConversationFollower(session);

  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    // Back to a conversation under way: where the person left it.
    if (session.turns.isNotEmpty) _follower.openAtLatest();
    if (widget.question case final String question) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _speak();
        session.ask(question);
      });
    }
  }

  /// Answers in the language the app is in now, which may have changed
  /// since the conversation started: what was said stays as it was.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (session.language != Localizations.localeOf(context).languageCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _speak();
      });
    }
  }

  void _speak() {
    final String language = Localizations.localeOf(context).languageCode;
    if (session.language != language) session.language = language;
  }

  @override
  void dispose() {
    _follower.dispose();
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
      builder: (BuildContext context, _) {
        final Allowance? day = widget.allowance;
        // With none left today, nothing offers to ask: the page says when
        // they come back, in a quiet tone, instead of turning one down.
        final bool out = day != null && day.left == 0;
        return Scaffold(
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
                                  enabled: !out,
                                  footer: _Footer(
                                    allowance: day,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Under way, how many are left shows here once
                          // they are few; with none, when they come back.
                          if (session.turns.isNotEmpty && day != null)
                            if (out)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _QuestionsGone(perDay: day.perDay),
                              )
                            else if (day.few)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  l.askLeftOf(day.left, day.perDay),
                                  style: context.type.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          AskBar(
                            onAsk: session.ask,
                            enabled: !session.busy,
                            closed: out ? l.askBackTomorrow : null,
                            examples: askExamples(l, widget.own),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// That the day's questions are used up, and that they come back
/// tomorrow: a state of the day, said quietly, not an error.
class _QuestionsGone extends StatelessWidget {
  const _QuestionsGone({required this.perDay});

  final int perDay;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.sunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(Glyph.clock, size: 20, color: context.colors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.askNoneLeft(perDay),
              style: context.type.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

/// How many questions are left today, and what Gemini gets to see.
class _Footer extends StatelessWidget {
  const _Footer({required this.allowance, required this.onNote});

  final Allowance? allowance;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Allowance? day = allowance;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (day != null && day.left == 0) ...<Widget>[
            _QuestionsGone(perDay: day.perDay),
            const SizedBox(height: 8),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: <Widget>[
              if (day != null && day.left > 0)
                Text(
                  l.askLeftOf(day.left, day.perDay),
                  style: context.type.bodySmall,
                ),
              TextButton.icon(
                onPressed: onNote,
                icon: const Icon(Glyph.lock, size: 16),
                label: Text(l.askWhatSees),
              ),
            ],
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
