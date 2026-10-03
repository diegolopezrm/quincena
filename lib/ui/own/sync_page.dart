import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../sync/merge.dart';
import '../../sync/sync_file.dart';
import '../../sync/sync_service.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'code_dialogs.dart';
import 'look.dart';

/// Using Quincena on more than one device: the vault's code, the files
/// that carry each device's changes, and what is waiting after a merge.
class SyncPage extends StatefulWidget {
  const SyncPage({super.key, required this.own, this.keys});

  final OwnController own;

  /// Where the vault's key is kept; the device's keychain unless a test
  /// says otherwise.
  final KeyStore? keys;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  late final SyncService _sync = SyncService(
    widget.own.store,
    keys: widget.keys ?? SecureKeyStore(),
    now: widget.own.now,
  );
  bool? _linked;
  List<SyncConflict> _conflicts = const <SyncConflict>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bool linked = await _sync.linked;
    // What waits stays after syncing stops: nothing is lost by stopping.
    final List<SyncConflict> conflicts = await _sync.conflicts();
    if (!mounted) return;
    setState(() {
      _linked = linked;
      _conflicts = conflicts;
    });
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _showCode(String code, {required String title}) => showCode(
    context,
    code: code,
    title: title,
    keep: context.l10n.syncCodeKeep,
  );

  Future<void> _start() async {
    final String code = await _sync.start();
    await _refresh();
    if (!mounted) return;
    await _showCode(code, title: context.l10n.syncYourCode);
  }

  Future<void> _join() async {
    final AppLocalizations l = context.l10n;
    final bool joined = await askForCode(
      context,
      title: l.syncJoin,
      body: l.syncJoinBody,
      action: l.syncJoinAction,
      use: (String code) async {
        await _sync.join(code);
        return null;
      },
    );
    if (!joined) return;
    await _refresh();
    _say(l.syncJoined);
  }

  Future<void> _export() async {
    final AppLocalizations l = context.l10n;
    setState(() => _busy = true);
    try {
      final Uint8List file = await _sync.export();
      final String day = widget.own.today.toIso8601String().substring(0, 10);
      final Uri? saved = await FilePicker.saveFile(
        fileName: 'quincena-$day.qsync',
        bytes: file,
        mimeType: 'application/octet-stream',
      );
      if (saved != null) _say(l.syncSaved);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final AppLocalizations l = context.l10n;
    final List<PlatformFile> files = await FilePicker.pickFiles();
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final SyncReport report = await _sync.import(
        await files.first.xFile.readAsBytes(),
      );
      await _refresh();
      _say(
        report.conflicts > 0
            ? l.syncMergedWaiting(report.applied, report.conflicts)
            : l.syncMerged(report.applied),
      );
    } on SyncFileException catch (e) {
      _say(switch (e.problem) {
        SyncFileProblem.notSync => l.syncNotSync,
        SyncFileProblem.otherVault => l.syncOtherVault,
        SyncFileProblem.newer => l.syncNewer,
        SyncFileProblem.damaged => l.syncDamaged,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _changeCode() async {
    final AppLocalizations l = context.l10n;
    if (!await _confirm(l.syncChangeTitle, l.syncChangeBody, l.syncChange)) {
      return;
    }
    final String code = await _sync.changeCode();
    if (!mounted) return;
    await _showCode(code, title: l.syncNewCode);
  }

  Future<void> _stop() async {
    final AppLocalizations l = context.l10n;
    if (!await _confirm(l.syncStopTitle, l.syncStopBody, l.syncStop)) return;
    await _sync.stop();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool? linked = _linked;
    // What waits shows near the top, whether or not this device syncs.
    final List<Widget> waiting = <Widget>[
      const SizedBox(height: 24),
      SectionLabel(l.syncWaiting),
      Text(l.syncWaitingBody, style: context.type.bodySmall),
      const SizedBox(height: 8),
      Panel(
        indent: 16,
        children: <Widget>[
          for (final SyncConflict c in _conflicts.reversed)
            _ConflictRow(
              own: widget.own,
              conflict: c,
              onRestore: () async {
                await _sync.restore(c);
                await _refresh();
                _say(l.syncRestored);
              },
              onDismiss: () async {
                await _sync.dismiss(c);
                await _refresh();
              },
            ),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.syncTitle, style: context.type.titleLarge),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Text(l.syncBody, style: context.type.bodyMedium),
              const SizedBox(height: 12),
              Block(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Glyph.info, size: 20, color: context.colors.inkSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.syncNotBackup,
                        style: context.type.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (kIsWeb)
                Text(l.syncNotOnWeb, style: context.type.bodyMedium)
              else if (linked == null)
                const Center(child: CircularProgressIndicator())
              else if (!linked) ...<Widget>[
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Glyph.deviceMobile, size: 18),
                  label: Text(l.syncStart),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _join,
                  icon: const Icon(Glyph.lock, size: 18),
                  label: Text(l.syncJoin),
                ),
                const SizedBox(height: 12),
                Text(l.syncHow, style: context.type.bodySmall),
                if (_conflicts.isNotEmpty) ...waiting,
              ] else ...<Widget>[
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Glyph.uploadSimple, size: 18),
                  label: Text(l.syncSend),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Glyph.downloadSimple, size: 18),
                  label: Text(l.syncOpen),
                ),
                const SizedBox(height: 8),
                Text(l.syncSendHow, style: context.type.bodySmall),
                if (_conflicts.isNotEmpty) ...waiting,
                const SizedBox(height: 24),
                SectionLabel(l.syncThisDevice),
                Panel(
                  indent: 16,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Glyph.lock),
                      title: Text(l.syncShowCode),
                      onTap: () async {
                        final String? code = await _sync.code();
                        if (code != null && mounted) {
                          await _showCode(code, title: l.syncYourCode);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Glyph.arrowsClockwise),
                      title: Text(l.syncChange),
                      onTap: _changeCode,
                    ),
                    ListTile(
                      leading: Icon(
                        Glyph.signOut,
                        color: context.colors.negative,
                      ),
                      title: Text(
                        l.syncStop,
                        style: TextStyle(color: context.colors.negative),
                      ),
                      onTap: _stop,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A version that lost, said the way the person knows it.
class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
    required this.own,
    required this.conflict,
    required this.onRestore,
    required this.onDismiss,
  });

  final OwnController own;
  final SyncConflict conflict;
  final VoidCallback onRestore;
  final VoidCallback onDismiss;

  String _what(AppLocalizations l) {
    final SyncRecord r = conflict.record;
    final Map<String, Object?> d = r.data ?? const <String, Object?>{};
    String text(String key) => '${d[key] ?? ''}';
    return switch (r.table) {
      'entries' => <String>[
        if (text('payee').isNotEmpty) text('payee') else l.kindExpense,
        ?_amount(d),
      ].join(' · '),
      'accounts' || 'recurring' || 'goals' => text('name'),
      'categories' => text('name').isEmpty ? r.id : text('name'),
      'settings' => switch (r.id) {
        'profile' => l.syncWhatProfile,
        'plan.envelopes' => l.envelopesTitle,
        'plan.wishes' => l.wishesTitle,
        'plan.cushion' => l.cushionDaysTitle,
        'plan.scenarios' => l.whatIfTitle,
        'shared.groups' => l.sharedTitle,
        'freelance' => l.freelanceTitle,
        'trips' => l.tripsTitle,
        'commitments.instalments' => l.instalTitle,
        'commitments.memories' => l.fixedTitle,
        'commitments.detective' => l.detectiveTitle,
        _ => l.syncWhatSetting,
      },
      _ => r.id,
    };
  }

  /// A movement's amount in its account's currency, when it reads.
  String? _amount(Map<String, Object?> d) {
    final Decimal? amount = Decimal.tryParse('${d['amount']}');
    if (amount == null) return null;
    final Asset? base = own.profile?.base;
    final Asset asset =
        own.snapshot?.account('${d['accountId']}')?.asset ?? base ?? Asset.cop;
    return formatAmount(amount, asset, base: base);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(_what(l), style: context.type.titleSmall),
          const SizedBox(height: 2),
          Text(
            '${switch (conflict.reason) {
              ConflictReason.editedBoth => l.syncWhyEditedBoth,
              ConflictReason.deletedElsewhere => l.syncWhyDeletedElsewhere,
              ConflictReason.deletedHere => l.syncWhyDeletedHere,
              ConflictReason.withAccount => l.syncWhyWithAccount,
              ConflictReason.replaced => l.syncWhyReplaced,
              ConflictReason.duplicate => l.syncWhyDuplicate,
            }} ${dayAndTime(conflict.at)}',
            style: context.type.bodySmall,
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: <Widget>[
              TextButton(onPressed: onDismiss, child: Text(l.syncDismiss)),
              TextButton(onPressed: onRestore, child: Text(l.syncRestore)),
            ],
          ),
        ],
      ),
    );
  }
}
