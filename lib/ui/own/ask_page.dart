import 'dart:async';

import 'package:flutter/material.dart';

import '../../ai/allowance.dart';
import '../../ai/cloud.dart';
import '../../l10n/l10n.dart';
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
  final ScrollController _scroll = ScrollController();
  final GlobalKey _latest = GlobalKey();
  Session? _session;
  int _seenTurns = 0;
  bool _wasBusy = false;

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
    session.addListener(_follow);
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
    session.removeListener(_follow);
    if (widget.session == null) session.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Brings a new question, and then its answer, to the top of the view.
  void _follow() {
    final int count = session.turns.length;
    final bool arrived = _wasBusy && !session.busy;
    final bool asked = count > _seenTurns;
    _seenTurns = count;
    _wasBusy = session.busy;
    if (!asked && !arrived) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _latest.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
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
              IconButton(
                tooltip: l.newConversation,
                onPressed: session.restart,
                icon: const Icon(Glyph.arrowCounterClockwise),
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
              child: CustomScrollView(
                controller: _scroll,
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
                                latest: _latest,
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
                    child: AskBar(onAsk: session.ask, enabled: !session.busy),
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
