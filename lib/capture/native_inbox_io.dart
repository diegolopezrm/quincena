import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'event.dart';
import 'native_channel.dart';

/// Where the native side writes, one JSON object per line. The same name in
/// `CaptureInbox.swift` and `CaptureListener.kt`.
const String captureFileName = 'capture-inbox.jsonl';

/// Takes every event the native side has written since the last time, and
/// empties the file.
///
/// The file is renamed before it is read: the native side opens the file
/// by name for each event, so one arriving meanwhile starts a new file
/// instead of being lost in the one being read.
///
/// On iOS the share extension writes to a folder the app shares with it,
/// which is read the same way after the app's own.
Future<List<CaptureEvent>> takeNativeEvents({Directory? directory}) async {
  final Directory dir;
  try {
    dir = directory ?? await getApplicationSupportDirectory();
  } on Object {
    return const <CaptureEvent>[];
  }
  final List<CaptureEvent> events = <CaptureEvent>[...await _take(dir)];
  if (directory == null) {
    final String? shared = await CaptureChannel.sharedInbox();
    if (shared != null) events.addAll(await _take(Directory(shared)));
  }
  return events;
}

Future<List<CaptureEvent>> _take(Directory dir) async {
  final File file = File('${dir.path}/$captureFileName');
  if (!await file.exists()) return const <CaptureEvent>[];
  final File taken = await file.rename(
    '${dir.path}/capture-inbox.${DateTime.now().microsecondsSinceEpoch}.jsonl',
  );
  final List<String> lines = await taken.readAsLines();
  await taken.delete();
  return <CaptureEvent>[
    for (final String line in lines)
      if (_decode(line) case final CaptureEvent event) event,
  ];
}

CaptureEvent? _decode(String line) {
  if (line.trim().isEmpty) return null;
  try {
    final Object? json = jsonDecode(line);
    return json is Map
        ? CaptureEvent.fromJson(json.cast<String, Object?>())
        : null;
  } on FormatException {
    return null;
  }
}
