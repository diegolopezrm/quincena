import 'package:flutter/material.dart';
import 'package:genui_gen/inspector.dart';

import '../agent/scripted_agent.dart';
import '../app.dart';
import '../l10n/l10n.dart';
import '../session/recordings.dart';
import '../session/session.dart';
import '../theme/tokens.dart';
import 'ask_bar.dart';
import 'conversation.dart';
import 'mark.dart';
import 'recorded_page.dart';
import 'settings_sheet.dart';
import 'welcome.dart';
import 'icons.dart';

/// The one screen: where the money stands, the conversation, the question.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.settings,
    this.onUseOwn,
    this.hasOwn = false,
  });

  final Session session;
  final AppSettings settings;

  /// Leaves the sample for the person's own accounts, where the build can
  /// keep them.
  final VoidCallback? onUseOwn;
  final bool hasOwn;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ConversationFollower _follower = ConversationFollower(_session);

  /// Sessions Gemini answered for real, if the app ships any.
  List<Recording> _recordings = const <Recording>[];

  Session get _session => widget.session;

  @override
  void initState() {
    super.initState();
    loadRecordings().then((List<Recording> found) {
      if (mounted && found.isNotEmpty) setState(() => _recordings = found);
    }, onError: (Object _) {});
  }

  /// Keeps the answers in the language the interface resolved to, whether
  /// the person chose it or the device did.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String language = Localizations.localeOf(context).languageCode;
    if (_session.language != language) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _session.language = language;
      });
    }
  }

  @override
  void dispose() {
    _follower.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_session, widget.settings]),
      builder: (BuildContext context, _) {
        // A new question, and then its answer, come to the top of the view,
        // so a long answer is read from its headline.
        final Widget content = FollowedScroll(
          follower: _follower,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _Column(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: _session.turns.isEmpty
                      ? Welcome(
                          ledger: _session.ledger,
                          onAsk: _session.ask,
                          onRecordings: _recordings.isEmpty
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        RecordedPage(recordings: _recordings),
                                  ),
                                ),
                        )
                      : Conversation(session: _session, follower: _follower),
                ),
              ),
            ),
            // Room below the last answer so it can scroll to the top.
            if (_session.turns.isNotEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: const SizedBox(height: 120),
              ),
          ],
        );

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _TopBar(
                  onSettings: () => showSettings(
                    context,
                    settings: widget.settings,
                    session: _session,
                    onUseOwn: widget.onUseOwn,
                    hasOwn: widget.hasOwn,
                  ),
                  onRestart: _session.turns.isEmpty
                      ? null
                      : () => startNewConversation(context, _session),
                  live: _session.mode == AgentMode.live,
                ),
                Expanded(
                  // The panel reports on the conversation, so it covers the
                  // conversation and leaves the question bar alone.
                  child: GenUiInspector(
                    controller: _session.controller,
                    recorder: _session.recorder,
                    enabled: widget.settings.developer,
                    child: content,
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
                          onAsk: _session.ask,
                          enabled: !_session.busy,
                          examples: ScriptedAgent.startersFor(
                            _session.language,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSettings,
    required this.onRestart,
    required this.live,
  });

  final VoidCallback onSettings;
  final VoidCallback? onRestart;

  /// Whether a model is answering rather than the script.
  final bool live;

  @override
  Widget build(BuildContext context) {
    return _Column(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
        child: Row(
          children: <Widget>[
            // Shrinks rather than overflows when the text is set large.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: <Widget>[
                      const Wordmark(),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.sunken,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          live
                              ? context.l10n.badgeLive
                              : context.l10n.badgeDemo,
                          style: context.type.labelSmall?.copyWith(
                            color: live ? context.colors.brand : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onRestart case final VoidCallback restart)
              NewConversationButton(onPressed: restart),
            IconButton(
              onPressed: onSettings,
              tooltip: context.l10n.settings,
              icon: const Icon(Glyph.gear),
            ),
          ],
        ),
      ),
    );
  }
}
