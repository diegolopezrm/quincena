import 'package:flutter/material.dart';
import 'package:genui_gen/inspector.dart';

import '../app.dart';
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
  const HomePage({super.key, required this.session, required this.settings});

  final Session session;
  final AppSettings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _latest = GlobalKey();
  int _seenTurns = 0;
  bool _wasBusy = false;

  /// Sessions Gemini answered for real, if the app ships any.
  List<Recording> _recordings = const <Recording>[];

  Session get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.addListener(_follow);
    loadRecordings().then((List<Recording> found) {
      if (mounted && found.isNotEmpty) setState(() => _recordings = found);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _session.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  /// Brings a new question, and then its answer, to the top of the view, so
  /// a long answer is read from its headline rather than from its last line.
  void _follow() {
    final int count = _session.turns.length;
    final bool arrived = _wasBusy && !_session.busy;
    final bool asked = count > _seenTurns;
    _seenTurns = count;
    _wasBusy = _session.busy;
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_session, widget.settings]),
      builder: (BuildContext context, _) {
        final Widget content = CustomScrollView(
          controller: _scroll,
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
                      : Conversation(session: _session, latest: _latest),
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
                  ),
                  onRestart: _session.turns.isEmpty ? null : _session.restart,
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
                          live ? 'EN VIVO' : 'DEMO',
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
            if (onRestart != null)
              IconButton(
                onPressed: onRestart,
                tooltip: 'Nueva conversación',
                icon: const Icon(Glyph.arrowCounterClockwise),
              ),
            IconButton(
              onPressed: onSettings,
              tooltip: 'Ajustes',
              icon: const Icon(Glyph.gear),
            ),
          ],
        ),
      ),
    );
  }
}
