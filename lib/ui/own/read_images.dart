import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../capture/capture_service.dart';
import '../../capture/native_channel.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../icons.dart';

/// Lets the person pick screenshots, photos or PDFs of payments, reads them
/// on the device and runs what they say through the inbox, where they wait
/// to be confirmed.
Future<void> readImages(BuildContext context, OwnController own) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool? pdf = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Glyph.image),
            title: Text(l.pickImages),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ListTile(
            leading: const Icon(Glyph.filePdf),
            title: Text(l.pickPdf),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (pdf == null) return;
  final List<PlatformFile> files = await FilePicker.pickFiles(
    type: pdf ? FileType.custom : FileType.image,
    allowedExtensions: pdf ? const <String>['pdf'] : null,
  );
  if (files.isEmpty) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l.readingImages),
      duration: const Duration(minutes: 1),
    ),
  );
  final List<String> texts = <String>[];
  for (final PlatformFile file in files) {
    final String? text = await CaptureChannel.readText(
      await file.xFile.readAsBytes(),
    );
    if (text != null && text.trim().isNotEmpty) texts.add(text.trim());
  }
  final IngestReport r = await own.ingestRead(texts);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          r.added + r.recorded > 0
              ? l.readFound(r.added + r.recorded)
              : r.duplicates > 0
              ? l.pasteDuplicate
              : l.readNothing,
        ),
      ),
    );
}
