import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../backup/backup.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../store/store.dart';
import '../../sync/sync_service.dart' show KeyStore, SecureKeyStore;
import '../../sync/vault.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'code_dialogs.dart';

/// Saves [bytes] where the person chooses, and says whether they did.
typedef SaveFile =
    Future<bool> Function(
      String name,
      Uint8List bytes, {
      required String mimeType,
      List<String>? extensions,
    });

/// The bytes of the file the person picks, or null.
typedef PickFile = Future<Uint8List?> Function();

Future<bool> _saveWithPicker(
  String name,
  Uint8List bytes, {
  required String mimeType,
  List<String>? extensions,
}) async =>
    await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: mimeType,
      allowedExtensions: extensions,
    ) !=
    null;

// Any file: a sealed backup is of no type the system knows.
Future<Uint8List?> _pickWithPicker() async {
  final List<PlatformFile> files = await FilePicker.pickFiles();
  if (files.isEmpty) return null;
  return files.first.xFile.readAsBytes();
}

/// Everything in one file: sealed with the person's backup code unless
/// they choose JSON any app can read. The first sealed one shows the code.
Future<void> exportData(
  BuildContext context, {
  required Backups backups,
  required DateTime today,
  SaveFile save = _saveWithPicker,
}) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool? sealed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext context) => _ExportSheet(backups: backups),
  );
  if (sealed == null || !context.mounted) return;
  final String day = today.toIso8601String().substring(0, 10);
  final bool saved;
  if (sealed) {
    final SealedBackup backup = await backups.seal();
    if (backup.newCode case final String code) {
      if (!context.mounted) return;
      await showCode(
        context,
        code: code,
        title: l.backupYourCode,
        keep: l.backupCodeKeep,
        share: l.backupCodeShareText(code),
        done: l.backupCodeKept,
      );
    }
    saved = await save(
      'quincena-$day.qbackup',
      backup.file,
      mimeType: 'application/octet-stream',
    );
  } else {
    saved = await save(
      'quincena-$day.json',
      await backups.plain(),
      mimeType: 'application/json',
      extensions: <String>['json'],
    );
  }
  if (saved) messenger.showSnackBar(SnackBar(content: Text(l.exportDone)));
}

/// Replaces everything with a backup the person picks: a sealed one, with
/// its code if this device does not have it, or an export in JSON. The file
/// is read whole and what it holds is shown before anything changes, with a
/// way to keep what is here first; nothing changes until «Restaurar».
Future<void> restoreBackup(
  BuildContext context, {
  required Backups backups,
  required DateTime today,
  Future<void> Function()? after,
  PickFile pick = _pickWithPicker,
  SaveFile save = _saveWithPicker,
  KeyStore? syncKeys,
}) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));
  String problem(Object? e) => switch (e) {
    ImportException(problem: ImportProblem.notQuincena) => l.importNotQuincena,
    ImportException(problem: ImportProblem.newer) => l.importNewer,
    BackupException(problem: BackupProblem.syncFile) => l.backupIsSync,
    _ => l.importDamaged,
  };

  final Uint8List? file = await pick();
  if (file == null || !context.mounted) return;
  OpenedBackup? opened;
  Object? failure;
  try {
    opened = await backups.open(file);
  } on Object catch (e) {
    failure = e;
  }
  if (failure is BackupException &&
      failure.problem == BackupProblem.needsCode) {
    failure = null;
    if (!context.mounted) return;
    final bool typed = await askForCode(
      context,
      title: l.backupCodeTitle,
      body: l.backupCodeBody,
      action: l.backupOpen,
      use: (String code) async {
        try {
          opened = await backups.open(file, code: code);
        } on BackupException {
          // The person has two codes: when this device knows the one typed,
          // say which one it is.
          if (await codeIsKey(code, (syncKeys ?? SecureKeyStore()).read)) {
            return l.backupCodeIsSync;
          }
          if (await codeIsKey(code, backups.keys.read)) {
            return l.backupCodeIsNewer;
          }
          return l.backupWrongCode;
        } on CodeException {
          rethrow;
        } on Object catch (e) {
          // Opened with the right code and still not whole: said below.
          failure = e;
        }
        return null;
      },
    );
    if (!typed) return;
  }
  final OpenedBackup? backup = opened;
  if (failure != null || backup == null) {
    say(problem(failure));
    return;
  }
  // What the file brings, before it replaces anything. Keeping what is
  // here first comes back to the same question.
  while (true) {
    if (!context.mounted) return;
    final _Restore? choice = await showDialog<_Restore>(
      context: context,
      builder: (BuildContext context) =>
          _RestoreDialog(contents: backup.contents),
    );
    if (choice != _Restore.saveFirst) {
      if (choice != _Restore.restore) return;
      break;
    }
    if (!context.mounted) return;
    await exportData(context, backups: backups, today: today, save: save);
  }
  try {
    await backups.restore(backup);
  } on Object catch (e) {
    say(problem(e));
    return;
  }
  say(l.importDone);
  await after?.call();
}

enum _Restore { restore, saveFirst }

/// What a backup brings, and the choice to replace what is here with it.
class _RestoreDialog extends StatelessWidget {
  const _RestoreDialog({required this.contents});

  final BackupContents contents;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final DateTime? made = contents.made;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: context.colors.inkSoft),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.type.bodyMedium)),
        ],
      ),
    );
    return AlertDialog(
      scrollable: true,
      title: Text(l.restoreTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            made == null ? l.restoreHolds : l.restoreFrom(dayMonthYear(made)),
            style: context.type.titleSmall,
          ),
          const SizedBox(height: 4),
          line(Glyph.bank, l.restoreAccounts(contents.accounts)),
          line(Glyph.listBullets, l.restoreMovements(contents.movements)),
          line(Glyph.flag, l.restoreGoals(contents.goals)),
          line(Glyph.calendarBlank, l.restorePlan(contents.plan)),
          const SizedBox(height: 16),
          Text(l.restoreReplaces, style: context.type.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(_Restore.saveFirst),
            icon: const Icon(Glyph.downloadSimple, size: 18),
            label: Text(l.restoreSaveFirst),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Restore.restore),
          style: TextButton.styleFrom(foregroundColor: context.colors.negative),
          child: Text(l.restore),
        ),
      ],
    );
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.backups});

  final Backups backups;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _sealed = true;
  String? _code;

  @override
  void initState() {
    super.initState();
    widget.backups.code().then((String? code) {
      if (mounted) setState(() => _code = code);
    });
  }

  Future<void> _change() async {
    final AppLocalizations l = context.l10n;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.backupChangeTitle),
        content: Text(l.backupChangeBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.backupChange),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final String code = await widget.backups.changeCode();
    if (!mounted) return;
    setState(() => _code = code);
    await showCode(
      context,
      code: code,
      title: l.backupNewCode,
      keep: l.backupCodeKeep,
      share: l.backupCodeShareText(code),
      done: l.backupCodeKept,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final String? code = _code;
    Widget choice(bool sealed, String title, String body) =>
        RadioListTile<bool>(
          value: sealed,
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(body),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l.exportData, style: context.type.headlineMedium),
          const SizedBox(height: 8),
          Text(l.exportBody, style: context.type.bodyMedium),
          const SizedBox(height: 8),
          RadioGroup<bool>(
            groupValue: _sealed,
            onChanged: (bool? sealed) {
              if (sealed != null) setState(() => _sealed = sealed);
            },
            child: Column(
              children: <Widget>[
                choice(true, l.exportSealed, l.exportSealedBody),
                choice(false, l.exportPlain, l.exportPlainBody),
              ],
            ),
          ),
          if (code != null)
            Wrap(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => showCode(
                    context,
                    code: code,
                    title: l.backupYourCode,
                    keep: l.backupCodeKeep,
                    share: l.backupCodeShareText(code),
                  ),
                  icon: const Icon(Glyph.lock, size: 18),
                  label: Text(l.backupShowCode),
                ),
                TextButton.icon(
                  onPressed: _change,
                  icon: const Icon(Glyph.arrowsClockwise, size: 18),
                  label: Text(l.backupChangeCode),
                ),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_sealed),
            child: Text(l.exportAction),
          ),
        ],
      ),
    );
  }
}
