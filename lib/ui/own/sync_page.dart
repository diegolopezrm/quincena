import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../backup/backup.dart' show BackupKeyStore, SecureBackupKeyStore;
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../store/store.dart' show QuincenaStore;
import '../../domain/categories.dart';
import '../../domain/records.dart';
import '../../sync/compare.dart';
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
  const SyncPage({super.key, required this.own, this.keys, this.backupKeys});

  final OwnController own;

  /// Where the vault's key is kept; the device's keychain unless a test
  /// says otherwise.
  final KeyStore? keys;

  /// Where the backups' key is kept, to tell its code from the vault's.
  final BackupKeyStore? backupKeys;

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
  List<Waiting> _waiting = const <Waiting>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bool linked = await _sync.linked;
    // What waits stays after syncing stops: nothing is lost by stopping.
    final List<Waiting> waiting = await _sync.waiting();
    if (!mounted) return;
    setState(() {
      _linked = linked;
      _waiting = waiting;
    });
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _showCode(String code, {required String title}) => showCode(
    context,
    code: code,
    title: title,
    keep: context.l10n.syncCodeKeep,
    share: context.l10n.syncCodeShareText(code),
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
        // A backup's code would join a vault no other device is in: say
        // which code it is instead.
        if (await codeIsKey(
          code,
          (widget.backupKeys ?? SecureBackupKeyStore()).read,
        )) {
          return l.syncCodeIsBackup;
        }
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
    final Uint8List file = await files.first.xFile.readAsBytes();
    try {
      final SyncReport report = await _sync.import(file);
      await _refresh();
      _say(_arrived(l, report));
    } on SyncFileException catch (e) {
      _say(switch (e.problem) {
        // A backup brought here is pointed to where it opens.
        SyncFileProblem.notSync =>
          SealedFile.backup.marks(file) ? l.syncIsBackup : l.syncNotSync,
        SyncFileProblem.otherVault => l.syncOtherVault,
        SyncFileProblem.newer => l.syncNewer,
        SyncFileProblem.damaged => l.syncDamaged,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What a file brought, by what the person calls it: «Llegaron 12
  /// movimientos, 2 cuentas y 5 cambios del Plan.»
  static String _arrived(AppLocalizations l, SyncReport report) {
    final SyncChanges c = report.changes;
    final List<(int, String)> came = <(int, String)>[
      if (c.movements > 0) (c.movements, l.syncItemMovements(c.movements)),
      if (c.accounts > 0) (c.accounts, l.syncItemAccounts(c.accounts)),
      if (c.plan > 0) (c.plan, l.syncItemPlan(c.plan)),
      if (c.settings > 0) (c.settings, l.syncItemSettings(c.settings)),
    ];
    final List<(int, String)> gone = <(int, String)>[
      if (c.movementsGone > 0)
        (c.movementsGone, l.syncItemMovements(c.movementsGone)),
      if (c.accountsGone > 0)
        (c.accountsGone, l.syncItemAccounts(c.accountsGone)),
    ];
    // «Llegó» for a single thing, «Llegaron» for more.
    bool one(List<(int, String)> items) =>
        items.length == 1 && items.single.$1 == 1;
    String said(List<(int, String)> items) =>
        listed(<String>[for (final (_, String text) in items) text]);
    final List<String> sentences = <String>[
      if (came.isNotEmpty)
        one(came)
            ? l.syncArrivedOne(said(came))
            : l.syncArrivedMany(said(came)),
      if (gone.isNotEmpty)
        one(gone) ? l.syncGoneOne(said(gone)) : l.syncGoneMany(said(gone)),
      if (report.conflicts > 0) l.syncWaitingCount(report.conflicts),
    ];
    return sentences.isEmpty ? l.syncUpToDate : sentences.join(' ');
  }

  /// Lets what waits go, with a way back for a few seconds.
  Future<void> _dismiss(SyncConflict conflict) async {
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await _sync.dismiss(conflict);
    await _refresh();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.syncDismissed),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            await _sync.keepWaiting(conflict);
            await _refresh();
          },
        ),
      ),
    );
  }

  /// The person picks, field by field, what stays of the two versions; the
  /// result is an edit made here.
  Future<void> _combine(Waiting w) async {
    final AppLocalizations l = context.l10n;
    final SyncRecord? kept = w.kept;
    if (kept == null) return;
    final List<SyncField>? take = await showModalBottomSheet<List<SyncField>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (BuildContext context) =>
          _CombineSheet(own: widget.own, waiting: w, kept: kept),
    );
    if (take == null) return;
    await _sync.combine(w.conflict, kept, take);
    await _refresh();
    if (mounted) _say(l.syncCombined);
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
          for (final Waiting w in _waiting.reversed)
            _WaitingCard(
              own: widget.own,
              waiting: w,
              onRestore: () async {
                await _sync.restore(w.conflict);
                await _refresh();
                _say(l.syncRestored);
              },
              onDismiss: () => _dismiss(w.conflict),
              onCombine: () => _combine(w),
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
                if (_waiting.isNotEmpty) ...waiting,
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
                if (_waiting.isNotEmpty) ...waiting,
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

/// How a version of a record reads, field by field, for the person.
class _Reading {
  _Reading(this.own, this.l, this.language);

  final OwnController own;
  final AppLocalizations l;
  final String language;

  String label(SyncField f) => switch (f.name) {
    'payee' || 'name' => l.syncFieldName,
    'money' => l.amount,
    'category' => l.category,
    'date' || 'deadline' => l.date,
    'note' => l.syncFieldNote,
    'institution' => l.syncFieldInstitution,
    'opening' => l.syncFieldOpening,
    'limit' => l.syncFieldLimit,
    'cadence' => l.syncFieldCadence,
    'next' => l.syncFieldNext,
    'account' => l.account,
    'state' => l.syncFieldState,
    'target' => l.syncFieldTarget,
    'saved' => l.syncFieldSaved,
    'monthly' => l.syncFieldMonthly,
    _ => f.name,
  };

  /// [f] as [r] has it; a dash for nothing.
  String value(SyncField f, SyncRecord r, {bool withKind = false}) {
    final Map<String, Object?> d = r.data ?? const <String, Object?>{};
    String text(Object? v) =>
        v == null || '$v'.trim().isEmpty ? '\u2014' : '$v'.trim();
    Asset? asset(Object? code) => code is String ? Asset.of(code) : null;
    Account? account(Object? id) => own.snapshot?.account('$id');
    String money(Object? amount, Asset? of) {
      final Decimal? value = Decimal.tryParse('${amount ?? ''}');
      if (value == null) return '\u2014';
      final Asset? base = own.profile?.base;
      return formatAmount(value, of ?? base ?? Asset.cop, base: base);
    }

    String day(Object? v) {
      final DateTime? date = switch (v) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        final String t => DateTime.tryParse(t),
        _ => null,
      };
      return date == null ? '\u2014' : shortDate(date);
    }

    return switch ((r.table, f.name)) {
      ('entries', 'money') => <String>[
        money(d['amount'], account(d['accountId'])?.asset),
        account(d['accountId'])?.name ?? '\u2014',
        if (withKind)
          switch (EntryKind.parse('${d['kind']}')) {
            EntryKind.expense => l.kindExpense,
            EntryKind.income => l.kindIncome,
            EntryKind.transfer => l.kindTransfer,
            EntryKind.adjustment => l.kindAdjustment,
          },
      ].join(' · '),
      (_, 'category') => switch (d['category']) {
        final String key => categoryLabel(
          key,
          language,
          custom: own.snapshot?.categories
              .where((CategoryItem c) => c.key == key)
              .firstOrNull
              ?.name,
        ),
        _ => '\u2014',
      },
      (_, 'date' || 'next' || 'deadline') => day(d[f.keys.first]),
      ('accounts', 'opening' || 'limit') => money(
        d[f.keys.first],
        asset(d['asset']),
      ),
      ('recurring', 'money') ||
      ('goals', 'target') => money(d[f.keys.first], asset(d['asset'])),
      ('goals', 'saved' || 'monthly') => money(
        d[f.keys.first],
        asset(d['asset']),
      ),
      ('recurring', 'cadence') => switch (Cadence.parse('${d['cadence']}')) {
        Cadence.monthly => l.cadenceMonthly,
        Cadence.biweekly => l.cadenceBiweekly,
        Cadence.weekly => l.cadenceWeekly,
        Cadence.yearly => l.cadenceYearly,
      },
      (_, 'account') => account(d['accountId'])?.name ?? '\u2014',
      ('recurring', 'state') =>
        d['active'] == false ? l.syncPaused : l.syncActive,
      _ => text(d[f.keys.first]),
    };
  }

  /// Whether the two versions' kinds differ, so the amount says each.
  static bool kindsDiffer(SyncRecord a, SyncRecord b) =>
      '${a.data?['kind']}' != '${b.data?['kind']}';
}

/// A version that waits, beside the one that stayed when there is one,
/// field by field with what differs marked, and what can be done with it.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.own,
    required this.waiting,
    required this.onRestore,
    required this.onDismiss,
    required this.onCombine,
  });

  final OwnController own;
  final Waiting waiting;
  final VoidCallback onRestore;
  final VoidCallback onDismiss;
  final VoidCallback onCombine;

  SyncConflict get conflict => waiting.conflict;

  String _what(AppLocalizations l, SyncRecord r) {
    final Map<String, Object?> d = r.data ?? const <String, Object?>{};
    String text(String key) => '${d[key] ?? ''}';
    return switch (r.table) {
      'entries' => <String>[
        if (text('payee').isNotEmpty) text('payee') else l.kindExpense,
        ?_amount(d),
      ].join(' · '),
      'accounts' || 'recurring' || 'goals' => text('name'),
      'categories' => text('name').isEmpty ? r.id : text('name'),
      'settings' => _setting(l, r.id),
      // A wish, a trip or a group by its own name, else by where it is.
      'list' || 'item' || 'map' =>
        text('name').isNotEmpty
            ? text('name')
            : _setting(l, QuincenaStore.settingOfItem(r.id) ?? ''),
      _ => r.id,
    };
  }

  /// What the person calls the setting [key].
  static String _setting(AppLocalizations l, String key) => switch (key) {
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
  };

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
    final SyncRecord? kept = waiting.kept;
    final List<FieldDiff> diffs = kept == null
        ? const <FieldDiff>[]
        : compareVersions(kept, conflict.record);
    // Combining is worth it when more than one thing can be taken apart.
    final bool combine =
        kept != null &&
        diffs.where((FieldDiff d) => d.differs && d.free).length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Named the way it shows now, when it still does.
          Text(
            _what(l, kept ?? conflict.record),
            style: context.type.titleSmall,
          ),
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
          if (kept != null && diffs.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _Comparison(own: own, kept: kept, waiting: conflict.record),
            if (!diffs.any((FieldDiff d) => d.differs)) ...<Widget>[
              const SizedBox(height: 6),
              Text(l.syncSameFields, style: context.type.bodySmall),
            ],
          ],
          Wrap(
            alignment: WrapAlignment.end,
            children: <Widget>[
              TextButton(onPressed: onDismiss, child: Text(l.syncDismiss)),
              if (combine)
                TextButton(onPressed: onCombine, child: Text(l.syncCombine)),
              TextButton(onPressed: onRestore, child: Text(l.syncRestore)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The two versions side by side, a field a row, with what differs on a
/// soft background and in heavier type. With large text, one under the
/// other, each with its title.
class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.own,
    required this.kept,
    required this.waiting,
  });

  final OwnController own;
  final SyncRecord kept;
  final SyncRecord waiting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final _Reading read = _Reading(
      own,
      l,
      Localizations.localeOf(context).languageCode,
    );
    final bool kinds = _Reading.kindsDiffer(kept, waiting);
    final List<FieldDiff> diffs = compareVersions(kept, waiting);
    final TextStyle? head = context.type.labelSmall;
    final TextStyle? same = context.type.bodySmall;
    final TextStyle? differs = context.type.bodySmall?.copyWith(
      color: context.colors.ink,
      fontWeight: FontWeight.w600,
    );
    String keptOf(SyncField f) => read.value(f, kept, withKind: kinds);
    String waitingOf(SyncField f) => read.value(f, waiting, withKind: kinds);
    if (largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final FieldDiff d in diffs)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: d.differs ? context.colors.cautionSoft : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(read.label(d.field), style: head),
                  Text(
                    '${l.syncKept}: ${keptOf(d.field)}',
                    style: d.differs ? differs : same,
                  ),
                  Text(
                    '${l.syncWaitingVersion}: ${waitingOf(d.field)}',
                    style: d.differs ? differs : same,
                  ),
                ],
              ),
            ),
        ],
      );
    }
    Widget cell(String text, TextStyle? style) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(text, style: style),
    );
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: <TableRow>[
        TableRow(
          children: <Widget>[
            const SizedBox.shrink(),
            cell(l.syncKept, head),
            cell(l.syncWaitingVersion, head),
          ],
        ),
        for (final FieldDiff d in diffs)
          TableRow(
            decoration: d.differs
                ? BoxDecoration(
                    color: context.colors.cautionSoft,
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            children: <Widget>[
              cell(read.label(d.field), head),
              cell(keptOf(d.field), d.differs ? differs : same),
              cell(waitingOf(d.field), d.differs ? differs : same),
            ],
          ),
      ],
    );
  }
}

/// Field by field, what stays of two versions: for each that differs, the
/// one that stayed or the one that waits, starting from whichever says
/// something. The rest stays as it is.
class _CombineSheet extends StatefulWidget {
  const _CombineSheet({
    required this.own,
    required this.waiting,
    required this.kept,
  });

  final OwnController own;
  final Waiting waiting;
  final SyncRecord kept;

  @override
  State<_CombineSheet> createState() => _CombineSheetState();
}

class _CombineSheetState extends State<_CombineSheet> {
  late final List<FieldDiff> _choices = <FieldDiff>[
    for (final FieldDiff d in compareVersions(
      widget.kept,
      widget.waiting.conflict.record,
    ))
      if (d.differs && d.free) d,
  ];

  /// The fields to take from the version that waits.
  late final Set<String> _fromWaiting = <String>{
    for (final FieldDiff d in _choices)
      if (_empty(widget.kept, d.field) &&
          !_empty(widget.waiting.conflict.record, d.field))
        d.field.name,
  };

  static bool _empty(SyncRecord r, SyncField f) => f.keys.every(
    (String k) => r.data?[k] == null || '${r.data?[k]}'.trim().isEmpty,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final _Reading read = _Reading(
      widget.own,
      l,
      Localizations.localeOf(context).languageCode,
    );
    final SyncRecord waits = widget.waiting.conflict.record;
    final bool kinds = _Reading.kindsDiffer(widget.kept, waits);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l.syncCombineTitle, style: context.type.headlineMedium),
          const SizedBox(height: 8),
          Text(l.syncCombineBody, style: context.type.bodyMedium),
          for (final FieldDiff d in _choices) ...<Widget>[
            const SizedBox(height: 16),
            SectionLabel(read.label(d.field)),
            RadioGroup<bool>(
              groupValue: _fromWaiting.contains(d.field.name),
              onChanged: (bool? fromWaiting) => setState(() {
                if (fromWaiting ?? false) {
                  _fromWaiting.add(d.field.name);
                } else {
                  _fromWaiting.remove(d.field.name);
                }
              }),
              child: Column(
                children: <Widget>[
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      read.value(d.field, widget.kept, withKind: kinds),
                    ),
                    subtitle: Text(l.syncKept),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(read.value(d.field, waits, withKind: kinds)),
                    subtitle: Text(l.syncWaitingVersion),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(<SyncField>[
              for (final FieldDiff d in _choices)
                if (_fromWaiting.contains(d.field.name)) d.field,
            ]),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
