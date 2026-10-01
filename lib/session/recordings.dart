import 'package:flutter/services.dart';
import 'package:genui_gen/tracing.dart';

/// A session a model answered for real, recorded with genui_gen.
class Recording {
  const Recording({required this.trace, required this.asset});

  final GenUiTrace trace;
  final String asset;

  String get question => trace.notes['question'] as String? ?? '';
  String get model => trace.notes['model'] as String? ?? 'el modelo';
  num? get seconds => trace.notes['seconds'] as num?;
}

/// The recordings shipped with the app, in the order of their file names.
Future<List<Recording>> loadRecordings([AssetBundle? bundle]) async {
  final AssetBundle assets = bundle ?? rootBundle;
  final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
    assets,
  );
  final List<String> paths =
      manifest
          .listAssets()
          .where(
            (String a) => a.startsWith('assets/traces/') && a.endsWith('.json'),
          )
          .toList()
        ..sort();
  return <Recording>[
    for (final String path in paths)
      Recording(
        trace: GenUiTrace.decode(await assets.loadString(path)),
        asset: path,
      ),
  ];
}
