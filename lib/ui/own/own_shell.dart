import 'dart:async';
import 'dart:math' as math;

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/material.dart';

import '../../agent/model_client.dart';
import '../../agent/scripted_agent.dart';
import '../../agent/understand.dart';
import '../../ai/cloud.dart';
import '../../app.dart';
import '../../app_mode.dart';
import '../../capture/native_channel.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../own/own_tools.dart';
import '../../platform/network.dart';
import '../../session/session.dart';
import '../../theme/tokens.dart';
import '../../widget/home_widget.dart';
import '../home_page.dart';
import '../icons.dart';
import '../mark.dart';
import 'accounts_tab.dart';
import 'ask_page.dart';
import 'entry_sheet.dart';
import 'home_tab.dart';
import 'inbox_page.dart';
import 'look.dart';
import 'movements_tab.dart';
import 'own_settings_page.dart';
import 'plan_tab.dart';

/// Answers the conversation about the person's own money instead of
/// Gemini, for the flows, which play with no network: the model a test
/// gives, with the tools the conversation hands it.
@visibleForTesting
ModelClient Function(List<dartantic.Tool> tools)? debugAskClient;

/// Says whether the network is back instead of the phone, for the flows:
/// with [debugAskClient] and without it, a question that failed for want
/// of a connection waits for «Volver a preguntar».
@visibleForTesting
Future<bool> Function()? debugReachable;

/// The person's own accounts, or the example's: home, movements and
/// accounts, a tap apart.
class OwnShell extends StatefulWidget {
  const OwnShell({
    super.key,
    required this.own,
    required this.modes,
    required this.settings,
    this.conversation,
  });

  final OwnController own;
  final AppModeController modes;
  final AppSettings settings;

  /// In the example, the scripted conversation over the same story, in the
  /// language given: what «Pregúntale a tu plata» opens there instead of
  /// Gemini.
  final Session Function(String language)? conversation;

  @override
  State<OwnShell> createState() => _OwnShellState();
}

class _OwnShellState extends State<OwnShell> with WidgetsBindingObserver {
  int _tab = 0;

  OwnController get own => widget.own;

  /// The widget on the phone's home screen, kept saying what Inicio says.
  final WidgetFeed _widget = WidgetFeed();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // What the phone shares and what it shows outside the app belong to the
    // person's own accounts, never to the example.
    if (own.example) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInboxIfAsked());
    own.addListener(_feedWidget);
  }

  // Also when the language changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedWidget();
  }

  void _feedWidget() {
    if (mounted && !own.example) _widget.update(context.l10n, own);
  }

  /// Someone shared a screenshot or a text with Quincena from another app
  /// and chose to see it.
  Future<void> _openInboxIfAsked() async {
    if (await CaptureChannel.takeOpenInbox() && mounted) _openInbox();
  }

  @override
  void dispose() {
    own.removeListener(_feedWidget);
    WidgetsBinding.instance.removeObserver(this);
    _asking?.dispose();
    super.dispose();
  }

  /// Back in the app: whatever the phone captured meanwhile, and fresh
  /// rates if they are old.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || own.example) return;
    own.pullCaptures();
    own.refreshRates();
    _openInboxIfAsked();
  }

  /// The conversation with Gemini about the person's money, made the first
  /// time it is opened and kept while these accounts are open: going back
  /// to Inicio and returning finds it as it was, as the example's does.
  /// The questions it took were spent; its answers stay to be read.
  Session? _asking;

  Session _askingIn(String language) => _asking ??= Session(
    mode: AgentMode.gemini,
    clientFor: debugAskClient,
    reachable: debugAskClient == null ? networkReachable : debugReachable,
    language: language,
    ledgerOf: () => own.ledger!,
    toolsFor: (_) => ownTools(own),
    own: true,
    allowance: widget.modes.allowance,
  );

  /// Asking Gemini about the person's money, with [question] already asked
  /// when they picked one.
  Future<void> _openAsk([String? question]) async {
    // App Check and the anonymous sign-in take a moment the first time;
    // better while the person reads the questions than after they ask.
    unawaited(Cloud.start());
    final Session session = _askingIn(
      Localizations.localeOf(context).languageCode,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AskPage(
          own: own,
          session: session,
          allowance: widget.modes.allowance,
          question: question,
        ),
      ),
    );
    // Inicio offers the way back to the conversation once it has one.
    if (mounted) setState(() {});
  }

  /// The example's conversation, with [question] asked when the script
  /// knows it; otherwise it opens on the questions it does know.
  void _openConversation([String? question]) {
    final Session session = widget.conversation!(
      Localizations.localeOf(context).languageCode,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            HomePage(session: session, settings: widget.settings),
      ),
    );
    if (question != null && intentOf(question) != null && !session.busy) {
      session.ask(question);
    }
  }

  /// The first three of the script's questions, with the icons its
  /// conversation gives them.
  static List<(IconData, String)> _exampleQuestions(BuildContext context) {
    final List<String> asked = ScriptedAgent.startersFor(
      Localizations.localeOf(context).languageCode,
    );
    return <(IconData, String)>[
      (Glyph.chartDonut, asked[0]),
      (Glyph.airplaneTilt, asked[1]),
      (Glyph.arrowsClockwise, asked[2]),
    ];
  }

  void _openInbox() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => InboxPage(own: own),
    ),
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => OwnSettingsPage(
        own: own,
        modes: widget.modes,
        settings: widget.settings,
      ),
    ),
  );

  /// How large the tab labels may grow. Material stops them at 1.3 times;
  /// on a narrow phone the longest would break mid-word before that, so
  /// they stop where it still fits.
  double _labelScale(BuildContext context, List<String> labels) {
    final TextStyle? style = NavigationBarTheme.of(
      context,
    ).labelTextStyle?.resolve(<WidgetState>{WidgetState.selected});
    final double room = MediaQuery.sizeOf(context).width / labels.length - 4;
    double widest = 0;
    for (final String label in labels) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest == 0 ? 1.3 : math.max(1, room / widest);
  }

  /// The tab as a sliver: Movimientos builds its days as they scroll into
  /// view, the others are laid out whole.
  Widget _tabBody() => switch (_tab) {
    1 => MovementsTab(own: own),
    2 => SliverToBoxAdapter(child: AccountsTab(own: own)),
    3 => SliverToBoxAdapter(child: PlanTab(own: own)),
    _ => SliverToBoxAdapter(
      child: OwnHomeTab(
        own: own,
        onSeeAll: () => setState(() => _tab = 1),
        onAsk: own.example
            ? (widget.conversation == null ? null : _openConversation)
            : (Cloud.supported ? _openAsk : null),
        // In the example, the questions its script answers.
        questions: own.example ? _exampleQuestions(context) : null,
        // The example's script spends none of the day's questions.
        allowance: own.example ? null : widget.modes.allowance,
        conversing: _asking?.turns.isNotEmpty ?? false,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    final List<(IconData, String)> destinations = <(IconData, String)>[
      (Glyph.house, l.tabHome),
      (Glyph.listBullets, l.tabMovements),
      (Glyph.bank, l.tabAccounts),
      (Glyph.piggyBank, l.tabPlan),
    ];
    final Widget content = ListenableBuilder(
      listenable: own,
      builder: (BuildContext context, _) {
        if (own.ledger == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // No wider than 760 points, in the middle of a wide screen.
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double side = 16 + math.max(0, (box.maxWidth - 760) / 2);
            return CustomScrollView(
              // Each tab keeps its own place: another tab opens at its top,
              // not as far down as the one left.
              key: PageStorageKey<int>(_tab),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 8, side, 112),
                  sliver: _tabBody(),
                ),
              ],
            );
          },
        );
      },
    );
    // Accounts and goals are added in place, on their own tabs: nothing
    // floats over the amounts there.
    final Widget? fab = _tab >= 2
        ? null
        : ScrollAwareFab(
            child: FloatingActionButton.extended(
              // Each tab starts with it in sight.
              key: ValueKey<int>(_tab),
              tooltip: l.addMovement,
              onPressed: () => showEntrySheet(context, own: own),
              icon: const Icon(Glyph.plus),
              label: Text(l.fabMovement),
            ),
          );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Wordmark(),
        actions: <Widget>[
          ListenableBuilder(
            listenable: own,
            builder: (BuildContext context, _) {
              final int count = own.pendingInbox.length;
              return IconButton(
                tooltip: l.inboxTitle,
                onPressed: _openInbox,
                icon: Badge(
                  isLabelVisible: count > 0,
                  // The count grows no more than the tab labels: at the
                  // largest text it would hide the tray it sits on.
                  label: Text(
                    '$count',
                    textScaler: MediaQuery.textScalerOf(
                      context,
                    ).clamp(maxScaleFactor: 1.3),
                  ),
                  child: const Icon(Glyph.tray),
                ),
              );
            },
          ),
          IconButton(
            tooltip: l.settingsTitle,
            onPressed: _openSettings,
            icon: const Icon(Glyph.gear),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: fab,
      floatingActionButtonAnimator: MediaQuery.disableAnimationsOf(context)
          ? FloatingActionButtonAnimator.noAnimation
          : null,
      body: wide
          ? Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _tab,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (int i) => setState(() => _tab = i),
                  destinations: <NavigationRailDestination>[
                    for (final (IconData icon, String label) in destinations)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        label: Text(label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: context.colors.line),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : MediaQuery.withClampedTextScaling(
              maxScaleFactor: _labelScale(context, <String>[
                for (final (_, String label) in destinations) label,
              ]),
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (int i) => setState(() => _tab = i),
                destinations: <NavigationDestination>[
                  for (final (IconData icon, String label) in destinations)
                    NavigationDestination(icon: Icon(icon), label: label),
                ],
              ),
            ),
    );
  }
}
