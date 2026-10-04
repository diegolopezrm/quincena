import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ai/cloud.dart';
import '../../app.dart';
import '../../app_mode.dart';
import '../../capture/native_channel.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../../widget/home_widget.dart';
import '../icons.dart';
import '../mark.dart';
import 'accounts_tab.dart';
import 'ask_page.dart';
import 'entry_sheet.dart';
import 'home_tab.dart';
import 'inbox_page.dart';
import 'look.dart';
import 'own_settings_page.dart';
import 'plan_tab.dart';

/// The person's own accounts: home, movements and accounts, a tap apart.
class OwnShell extends StatefulWidget {
  const OwnShell({
    super.key,
    required this.own,
    required this.modes,
    required this.settings,
  });

  final OwnController own;
  final AppModeController modes;
  final AppSettings settings;

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
    if (mounted) _widget.update(context.l10n, own);
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
    super.dispose();
  }

  /// Back in the app: whatever the phone captured meanwhile, and fresh
  /// rates if they are old.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    own.pullCaptures();
    own.refreshRates();
    _openInboxIfAsked();
  }

  /// Asking Gemini about the person's money, with [question] already asked
  /// when they picked one.
  void _openAsk([String? question]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => AskPage(
        own: own,
        allowance: widget.modes.allowance,
        question: question,
      ),
    ),
  );

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
        onAsk: Cloud.supported ? _openAsk : null,
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
                  label: Text('$count'),
                  backgroundColor: context.colors.brand,
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
