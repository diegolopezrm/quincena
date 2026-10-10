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
import 'account_leaving.dart';
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

/// Crypto accounts kept by hand at Binance once Binance brought its own:
/// the same balances, counted twice. None before it brought any, when
/// archiving them would only take them off the totals.
List<Account> twiceCountedBinance(OwnController own) {
  final bool brought = own.accounts.any(
    (Account a) => a.syncRef?.startsWith(BinanceSync.prefix) ?? false,
  );
  return brought ? manualBinanceAccounts(own) : const <Account>[];
}

/// Archives [accounts], kept by hand at Binance, once the person saw what it
/// does: they leave the totals, keep their movements and wait in «Cuentas
/// archivadas».
Future<void> archiveTwiceCounted(
  BuildContext context,
  OwnController own,
  List<Account> accounts,
) =>
    confirmLeaving(context, own, accounts, why: context.l10n.binanceArchiveWhy);

/// That what Binance brought counts a second time beside the balances kept
/// by hand there, with the way to archive those right where it is said:
/// [compact], under the Binance row among the crypto's sources; otherwise a
/// row of its own, as among the accounts. Nothing while nothing counts
/// twice.
class BinanceTwice extends StatelessWidget {
  const BinanceTwice({super.key, required this.own, this.compact = false});

  final OwnController own;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<Account> twice = twiceCountedBinance(own);
    if (twice.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l = context.l10n;
    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.binanceTwiceTitle,
          style: (compact ? context.type.bodySmall : context.type.titleSmall)
              ?.copyWith(color: context.colors.caution),
        ),
        Text(
          l.binanceTwiceBody(twice.map((Account a) => a.name).join(', ')),
          style: context.type.bodySmall,
        ),
        TextButton(
          onPressed: () => archiveTwiceCounted(context, own, twice),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(l.binanceArchive),
        ),
      ],
    );
    if (compact) return words;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox.square(
            dimension: 40,
            child: Icon(
              Glyph.warningCircle,
              size: 22,
              color: context.colors.caution,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: words),
        ],
      ),
    );
  }
}

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
        // A read that failed says so here too, not only on its page: the
        // balances beside it are as old as the last good read.
        final bool failed =
            link.connected && !link.syncing && link.problem != null;
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
            : failed
            ? (at == null
                  ? l.binanceReadFailedNever
                  : l.binanceReadFailedAt(dayAndTime(at)))
            : at == null
            ? l.binanceNeverSynced
            : l.binanceSyncedAt(dayAndTime(at));
        final TextStyle? bodyStyle = failed
            ? context.type.bodySmall?.copyWith(color: context.colors.negative)
            : context.type.bodySmall;
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
                        Text(body, style: bodyStyle),
                        BinanceTwice(own: own, compact: true),
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
                        Text(body, style: bodyStyle),
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

  /// Whether a key is being put in place of the one kept, which stays
  /// until Binance takes the new one.
  bool _changing = false;

  /// What is missing, said under the field that misses it until it is
  /// written.
  String? _keyMissing;
  String? _secretMissing;

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
    final AppLocalizations l = context.l10n;
    final bool noKey = _key.text.trim().isEmpty;
    final bool noSecret = _secret.text.trim().isEmpty;
    if (noKey || noSecret) {
      setState(() {
        _keyMissing = noKey ? l.binanceNeedKey : null;
        _secretMissing = noSecret ? l.binanceNeedSecret : null;
      });
      return;
    }
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
        _changing = false;
      }
    });
  }

  /// Opens the form for a new key, or goes back to how the connection is.
  void _changeKey(bool changing) => setState(() {
    _changing = changing;
    _outcome = null;
    _keyMissing = null;
    _secretMissing = null;
    _key.clear();
    _secret.clear();
  });

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
                  : link.connected && !_changing
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
    // Failing again and again with no reason given, the key is what to
    // look at: said so, with the way to put another.
    final String? problem =
        link.keyInDoubt && link.problem == SyncProblem.failed
        ? l.binanceKeyInDoubt(link.failures)
        : _syncMessage(l);
    final List<Account> manual = twiceCountedBinance(widget.own);
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
        if (link.keyInDoubt) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _changeKey(true),
              icon: const Icon(Glyph.key, size: 18),
              label: Text(l.binanceChangeKey),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: link.sync,
          icon: const Icon(Glyph.arrowsClockwise, size: 18),
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
            onPressed: () => archiveTwiceCounted(context, widget.own, manual),
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
    // In place of a key kept, or the first one.
    final bool changing = _changing && link.connected;
    return <Widget>[
      Text(
        changing ? l.binanceChangeKeyTitle : l.binanceConnectTitle,
        style: context.type.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        changing ? l.binanceChangeKeyBody : l.binanceConnectBody,
        style: context.type.bodyMedium,
      ),
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
        decoration: InputDecoration(
          labelText: l.binanceApiKey,
          errorText: _keyMissing,
        ),
        onChanged: (_) {
          if (_keyMissing != null) setState(() => _keyMissing = null);
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _secret,
        autocorrect: false,
        enableSuggestions: false,
        obscureText: _hidden,
        onChanged: (_) {
          if (_secretMissing != null) setState(() => _secretMissing = null);
        },
        decoration: InputDecoration(
          labelText: l.binanceSecretKey,
          errorText: _secretMissing,
          // An eye that says what it does: open to show the key, crossed
          // out to hide it again.
          suffixIcon: IconButton(
            tooltip: _hidden ? l.binanceShowSecret : l.binanceHideSecret,
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(_hidden ? Glyph.eye : Glyph.eyeSlash, size: 20),
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
      // The key kept stays as it was.
      if (changing) ...<Widget>[
        const SizedBox(height: 8),
        TextButton(
          onPressed: _connecting ? null : () => _changeKey(false),
          child: Text(l.cancel),
        ),
      ],
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
