import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../backup/backup.dart';
import '../../l10n/l10n.dart';
import '../../store/store.dart';
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

/// Replaces everything with a file the person picks: a sealed backup, with
/// its code if this device does not have it, or an export in JSON. The file
/// is read whole before [confirm] asks; nothing changes until then.
Future<void> importData(
  BuildContext context, {
  required Backups backups,
  required Future<bool?> Function() confirm,
  Future<void> Function()? after,
  PickFile pick = _pickWithPicker,
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
  if (!context.mounted || await confirm() != true) return;
  try {
    await backups.restore(backup);
  } on Object catch (e) {
    say(problem(e));
    return;
  }
  say(l.importDone);
  await after?.call();
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
