import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../exchanges/wallets.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'look.dart';
import 'portfolio_page.dart';

/// Among the crypto page's sources: the wallets followed by address, a
/// tap away.
class WalletsRow extends StatelessWidget {
  const WalletsRow({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own.wallets,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final WalletLink link = own.wallets;
      final DateTime? at = link.syncedAt;
      return InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => WalletsPage(own: own),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Glyph.vault, size: 20, color: context.colors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.walletsTitle, style: context.type.titleSmall),
                    Text(
                      link.wallets.isEmpty || at == null
                          ? l.walletsCardBody
                          : l.walletsSyncedAt(dayAndTime(at)),
                      style: context.type.bodySmall,
                    ),
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
    },
  );
}

/// The wallets the person follows by public address, and what each holds.
class WalletsPage extends StatefulWidget {
  const WalletsPage({super.key, required this.own});

  final OwnController own;

  @override
  State<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends State<WalletsPage> {
  OwnController get own => widget.own;

  @override
  void initState() {
    super.initState();
    own.wallets.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    own.wallets.adjustment = context.l10n.walletsAdjustment;
  }

  Future<void> _remove(WalletAddress w) async {
    final AppLocalizations l = context.l10n;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          '${l.walletsRemove}: ${w.label.isEmpty ? w.short : w.label}',
        ),
        content: Text(l.walletsRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.walletsRemove),
          ),
        ],
      ),
    );
    if (sure == true) await own.wallets.remove(w);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.walletsTitle, style: context.type.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: l.ratesRefresh,
            onPressed: own.wallets.syncing ? null : own.wallets.sync,
            icon: const Icon(Glyph.arrowCounterClockwise),
          ),
        ],
      ),
      floatingActionButton: ScrollAwareFab(
        child: FloatingActionButton.extended(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            useSafeArea: true,
            backgroundColor: context.colors.surface,
            constraints: const BoxConstraints(maxWidth: 560),
            builder: (BuildContext context) => _AddWallet(own: own),
          ),
          icon: const Icon(Glyph.plus),
          label: Text(l.walletsAdd),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[own.wallets, own]),
        builder: (BuildContext context, _) {
          final WalletLink link = own.wallets;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: <Widget>[
                  Text(l.walletsBody, style: context.type.bodyMedium),
                  const SizedBox(height: 8),
                  Text(l.walletsChains, style: context.type.bodySmall),
                  const SizedBox(height: 20),
                  if (link.failed != null) ...<Widget>[
                    Text(
                      l.walletsFailed,
                      style: context.type.bodySmall?.copyWith(
                        color: context.colors.caution,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (link.wallets.isEmpty)
                    Text(l.walletsEmpty, style: context.type.titleSmall),
                  for (final WalletAddress w in link.wallets) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  (w.label.isEmpty ? w.chain.label : w.label)
                                      .toUpperCase(),
                                  style: context.type.labelSmall,
                                ),
                                // An address keeps its own case.
                                Text(
                                  '${w.chain.label} · ${w.short}',
                                  style: context.type.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l.walletsRemove,
                            onPressed: () => _remove(w),
                            icon: Icon(
                              Glyph.trash,
                              size: 18,
                              color: context.colors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Panel(
                      children: <Widget>[
                        for (final Account a in own.accounts)
                          if (a.syncRef?.startsWith(
                                'wallet:${w.chain.name}:${w.address}:',
                              ) ??
                              false)
                            _Held(own: own, account: a),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  Text(l.walletsPrivacy, style: context.type.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What one asset in a wallet holds.
class _Held extends StatelessWidget {
  const _Held({required this.own, required this.account});

  final OwnController own;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final Money balance = own.balances[account.id] ?? account.openingMoney;
    final Money? inBase = own.inBase(balance);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          CoinMark(account.asset, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(account.asset.code, style: context.type.titleSmall),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Figures(
                moneyText(balance, base: own.profile?.base),
                style: context.type.titleSmall,
              ),
              if (inBase != null)
                Figures(
                  '≈ ${moneyText(inBase, base: own.profile?.base)}',
                  style: context.type.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Follows a new wallet: its chain, its address, a name.
class _AddWallet extends StatefulWidget {
  const _AddWallet({required this.own});

  final OwnController own;

  @override
  State<_AddWallet> createState() => _AddWalletState();
}

class _AddWalletState extends State<_AddWallet> {
  Chain _chain = Chain.bitcoin;
  final TextEditingController _address = TextEditingController();
  final TextEditingController _label = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final String address = _address.text.trim();
    if (!_chain.accepts(address)) {
      setState(() => _error = l.walletsBadAddress(_chain.label));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final bool ok = await widget.own.wallets.add(
      WalletAddress(chain: _chain, address: address, label: _label.text.trim()),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = l.walletsUnreadable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.walletsAdd, style: context.type.headlineMedium),
            const SizedBox(height: 16),
            SegmentedButton<Chain>(
              showSelectedIcon: false,
              segments: <ButtonSegment<Chain>>[
                for (final Chain c in Chain.values)
                  ButtonSegment<Chain>(value: c, label: Text(c.label)),
              ],
              selected: <Chain>{_chain},
              onSelectionChanged: (Set<Chain> s) =>
                  setState(() => _chain = s.single),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l.walletsAddress,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.walletsLabel),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.walletsAdd),
            ),
          ],
        ),
      ),
    );
  }
}
