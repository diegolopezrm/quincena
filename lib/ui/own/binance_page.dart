import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../exchanges/binance_link.dart';
import '../../exchanges/binance_sync.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'example_bar.dart';
import 'look.dart';

/// The words a sync writes, in the person's language.
BinanceLabels binanceLabels(AppLocalizations l) => BinanceLabels(
  p2p: l.binanceLabelP2p,
  conversion: l.binanceLabelConversion,
  deposit: l.binanceLabelDeposit,
  withdrawal: l.binanceLabelWithdrawal,
  fee: l.binanceLabelFee,
  adjustment: l.binanceLabelAdjustment,
);

/// Crypto accounts the person keeps by hand at Binance: what connecting it
/// would keep up to date.
List<Account> manualBinanceAccounts(OwnController own) => <Account>[
  for (final Account a in own.accounts)
    if (a.syncRef == null &&
        a.asset.isCrypto &&
        a.institution.toLowerCase().contains('binance'))
      a,
];

/// An invitation to connect Binance, or how the connection is doing: a
/// card of its own where there is no crypto yet, or, [compact], a row
/// among the crypto page's sources.
class BinanceCard extends StatelessWidget {
  const BinanceCard({super.key, required this.own, this.compact = false});

  final OwnController own;

  /// A row in a panel, with one line of how it is doing and no list of
  /// what the key can do, which its page has.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final BinanceLink link = own.binance;
    return ListenableBuilder(
      listenable: link,
      builder: (BuildContext context, _) {
        final AppLocalizations l = context.l10n;
        final DateTime? at = link.syncedAt;
        // Balances written by hand are the reason to connect it.
        final bool manual = manualBinanceAccounts(own).isNotEmpty;
        final String body = own.example
            ? l.exampleNotConnected
            : !link.connected
            ? (manual
                  ? l.binanceCardManualBody
                  : compact
                  ? l.binanceRowOff
                  : l.binanceCardBody)
            : link.syncing
            ? l.binanceSyncing
            : at == null
            ? l.binanceNeverSynced
            : l.binanceSyncedAt(dayAndTime(at));
        Future<void> open() async {
          if (await explainExample(context, own, l.binanceTitle)) return;
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => BinancePage(own: own),
            ),
          );
        }

        if (compact) {
          return InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  const _BinanceMark(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.binanceTitle, style: context.type.titleSmall),
                        Text(body, style: context.type.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (link.syncing)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Glyph.caretRight,
                      size: 18,
                      color: context.colors.inkFaint,
                    ),
                ],
              ),
            ),
          );
        }
        return Material(
          color: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.colors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: <Widget>[
                  const _BinanceMark(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          link.connected ? l.binanceTitle : l.binanceCardTitle,
                          style: context.type.titleSmall,
                        ),
                        Text(body, style: context.type.bodySmall),
                        // What the key can and cannot do, before anyone is
                        // asked for one.
                        if (!link.connected) ...<Widget>[
                          const SizedBox(height: 8),
                          for (final String promise in <String>[
                            l.binancePromiseRead,
                            l.binancePromiseNoWithdraw,
                            l.binancePromiseNoTrade,
                            l.binancePromiseDisconnect,
                          ])
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Glyph.check,
                                    size: 14,
                                    color: context.colors.brand,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      promise,
                                      style: context.type.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (link.syncing)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Glyph.caretRight,
                      size: 18,
                      color: context.colors.inkFaint,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Binance's yellow, around the exchange's icon.
class _BinanceMark extends StatelessWidget {
  const _BinanceMark({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFF0B90B).withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(
      Glyph.currencyBtc,
      size: size * 0.5,
      color: const Color(0xFFE0A800),
    ),
  );
}

/// Connects Binance with a read-only key, and keeps it read.
class BinancePage extends StatefulWidget {
  const BinancePage({super.key, required this.own});

  final OwnController own;

  @override
  State<BinancePage> createState() => _BinancePageState();
}

class _BinancePageState extends State<BinancePage> {
  final TextEditingController _key = TextEditingController();
  final TextEditingController _secret = TextEditingController();
  bool _connecting = false;
  bool _hidden = true;
  ConnectOutcome? _outcome;

  BinanceLink get link => widget.own.binance;

  @override
  void initState() {
    super.initState();
    link.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    link.labels = binanceLabels(context.l10n);
  }

  @override
  void dispose() {
    _key.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_key.text.trim().isEmpty || _secret.text.trim().isEmpty) return;
    setState(() {
      _connecting = true;
      _outcome = null;
    });
    final ConnectOutcome outcome = await link.connect(_key.text, _secret.text);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _outcome = outcome;
      if (outcome == ConnectOutcome.connected) {
        _key.clear();
        _secret.clear();
      }
    });
  }

  Future<void> _disconnect() async {
    final AppLocalizations l = context.l10n;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.binanceDisconnectTitle),
        content: Text(l.binanceDisconnectBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(l.binanceDisconnect),
          ),
        ],
      ),
    );
    if (sure == true) await link.disconnect();
  }

  /// Accounts the person kept by hand at Binance, which the synced ones
  /// now count too.
  List<Account> get _manual => manualBinanceAccounts(widget.own);

  Future<void> _archiveManual() async {
    for (final Account a in _manual) {
      await widget.own.store.updateAccount(a.copyWith(archived: true));
    }
  }

  String? _message(AppLocalizations l) => switch (_outcome) {
    ConnectOutcome.notReadOnly => l.binanceNotReadOnly(
      link.refused.map(_permission).join(', '),
    ),
    ConnectOutcome.badKey => l.binanceBadKey,
    ConnectOutcome.offline => l.binanceOffline,
    ConnectOutcome.limited => l.binanceLimited,
    ConnectOutcome.failed => l.binanceFailed,
    ConnectOutcome.connected || null => null,
  };

  String? _syncMessage(AppLocalizations l) => switch (link.problem) {
    SyncProblem.badKey => l.binanceBadKey,
    SyncProblem.offline => l.binanceOffline,
    SyncProblem.limited => l.binanceLimited,
    SyncProblem.failed => l.binanceFailed,
    null => null,
  };

  /// Binance's name for a permission, made readable.
  static String _permission(String flag) => switch (flag) {
    'enableSpotAndMarginTrading' => 'Spot & Margin',
    'enableWithdrawals' => 'Withdrawals',
    'enableInternalTransfer' => 'Internal Transfer',
    'permitsUniversalTransfer' => 'Universal Transfer',
    'enableMargin' => 'Margin',
    'enableFutures' => 'Futures',
    'enableVanillaOptions' => 'Options',
    'enablePortfolioMarginTrading' => 'Portfolio Margin',
    'enableFixApiTrade' => 'FIX Trade',
    'enableReading' => 'Reading off',
    _ => flag,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.binanceTitle, style: context.type.titleLarge),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[link, widget.own]),
        builder: (BuildContext context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: !BinanceLink.available
                  ? <Widget>[
                      Text(l.binanceWebOnly, style: context.type.bodyMedium),
                    ]
                  : link.connected
                  ? _status(l)
                  : _form(l),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _status(AppLocalizations l) {
    final DateTime? at = link.syncedAt;
    final SyncReport? report = link.report;
    final String? problem = _syncMessage(l);
    // Kept by hand, they count twice only once Binance brought its own:
    // before that, archiving them would only take them off the totals.
    final bool brought = widget.own.accounts.any(
      (Account a) => a.syncRef?.startsWith(BinanceSync.prefix) ?? false,
    );
    final List<Account> manual = brought ? _manual : const <Account>[];
    return <Widget>[
      Row(
        children: <Widget>[
          const _BinanceMark(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.binanceConnected, style: context.type.titleMedium),
                Text(
                  at == null
                      ? l.binanceNeverSynced
                      : l.binanceSyncedAt(dayAndTime(at)),
                  style: context.type.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (link.syncing) ...<Widget>[
        LinearProgressIndicator(value: link.progress),
        const SizedBox(height: 8),
        Text(l.binanceSyncing, style: context.type.bodySmall),
      ] else ...<Widget>[
        if (problem != null)
          _Note(text: problem, color: context.colors.negative)
        else if (report != null)
          _Note(text: l.binanceReport(report.movementsAdded)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: link.sync,
          icon: const Icon(Glyph.arrowCounterClockwise, size: 18),
          label: Text(l.binanceSyncNow),
        ),
      ],
      if (manual.isNotEmpty) ...<Widget>[
        const SizedBox(height: 20),
        _Note(
          text: l.binanceManualAccounts(
            manual.map((Account a) => a.name).join(', '),
          ),
          color: context.colors.caution,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _archiveManual,
            child: Text(l.binanceArchive),
          ),
        ),
      ],
      const SizedBox(height: 24),
      _Point(
        icon: Glyph.lock,
        title: l.binanceReadOnlyTitle,
        body: l.binanceReadOnlyBody,
      ),
      _Point(
        icon: Glyph.deviceMobile,
        title: l.binanceKeyStoredTitle,
        body: l.binanceKeyStoredBody,
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _disconnect,
          style: TextButton.styleFrom(foregroundColor: context.colors.negative),
          icon: const Icon(Glyph.signOut, size: 18),
          label: Text(l.binanceDisconnect),
        ),
      ),
    ];
  }

  List<Widget> _form(AppLocalizations l) {
    final String? message = _message(l);
    return <Widget>[
      Text(l.binanceConnectTitle, style: context.type.headlineMedium),
      const SizedBox(height: 8),
      Text(l.binanceConnectBody, style: context.type.bodyMedium),
      const SizedBox(height: 20),
      _Point(
        icon: Glyph.lock,
        title: l.binanceReadOnlyTitle,
        body: l.binanceReadOnlyBody,
      ),
      _Point(
        icon: Glyph.deviceMobile,
        title: l.binanceKeyStoredTitle,
        body: l.binanceKeyStoredBody,
      ),
      const SizedBox(height: 8),
      SectionLabel(l.binanceStepsTitle),
      Block(child: Text(l.binanceSteps, style: context.type.bodyMedium)),
      const SizedBox(height: 20),
      TextField(
        controller: _key,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(labelText: l.binanceApiKey),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _secret,
        autocorrect: false,
        enableSuggestions: false,
        obscureText: _hidden,
        decoration: InputDecoration(
          labelText: l.binanceSecretKey,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(_hidden ? Glyph.lock : Glyph.check, size: 18),
          ),
        ),
      ),
      if (message != null) ...<Widget>[
        const SizedBox(height: 12),
        _Note(text: message, color: context.colors.negative),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _connecting ? null : _connect,
        child: Text(_connecting ? l.binanceConnecting : l.binanceConnect),
      ),
    ];
  }
}

/// One promise the connection makes, with its icon.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: context.colors.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: context.type.titleSmall),
              const SizedBox(height: 2),
              Text(body, style: context.type.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A sentence on a soft background, in [color] when it is a warning.
class _Note extends StatelessWidget {
  const _Note({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    decoration: BoxDecoration(
      color: (color ?? context.colors.brand).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: context.type.bodySmall?.copyWith(
        color: color ?? context.colors.ink,
      ),
    ),
  );
}
