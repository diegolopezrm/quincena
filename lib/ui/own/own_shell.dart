import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_mode.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../mark.dart';
import 'account_sheet.dart';
import 'accounts_tab.dart';
import 'entry_sheet.dart';
import 'home_tab.dart';
import 'inbox_page.dart';
import 'own_settings_page.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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

  Widget _tabBody() => switch (_tab) {
    1 => MovementsTab(own: own),
    2 => AccountsTab(own: own),
    _ => OwnHomeTab(own: own, onSeeAll: () => setState(() => _tab = 1)),
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    final List<(IconData, String)> destinations = <(IconData, String)>[
      (Glyph.house, l.tabHome),
      (Glyph.listBullets, l.tabMovements),
      (Glyph.bank, l.tabAccounts),
    ];
    final Widget content = ListenableBuilder(
      listenable: own,
      builder: (BuildContext context, _) {
        if (own.ledger == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                    child: _tabBody(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    final Widget fab = _tab == 2
        ? FloatingActionButton.extended(
            onPressed: () => showAccountSheet(context, own: own),
            icon: const Icon(Glyph.plus),
            label: Text(l.addAccount),
          )
        : FloatingActionButton(
            tooltip: l.addMovement,
            onPressed: () => showEntrySheet(context, own: own),
            child: const Icon(Glyph.plus),
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
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (int i) => setState(() => _tab = i),
              destinations: <NavigationDestination>[
                for (final (IconData icon, String label) in destinations)
                  NavigationDestination(icon: Icon(icon), label: label),
              ],
            ),
    );
  }
}
