// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'stat_tile.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [StatTile].
final CatalogItem statTileCatalogItem = CatalogItem(
  name: 'StatTile',
  dataSchema: S.object(
    description:
        'A compact figure with a label and an optional caption. Put '
        'two to four inside a Tiles component to compare numbers side '
        'by side. The value is text, so format money with the `money` '
        'function rather than writing digits by hand.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description: 'What the figure is, in two or three words.',
      ),
      'value': A2uiSchemas.stringReference(
        description:
            'The figure, already formatted, such as "\$ 589.300" or "+67 '
            '%".',
      ),
      'caption': A2uiSchemas.stringReference(
        description:
            'A short line under the figure, such as "contra \$ 353.600 en '
            'agosto".',
      ),
      'tone': A2uiSchemas.stringReference(
        description:
            'Colors the value: `good`, `caution`, `alert`, or `neutral` '
            'for no claim.',
        enumValues: ['neutral', 'good', 'caution', 'alert'],
      ),
    },
    required: ['label', 'value'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "StatTile",
    "label": "Sample label",
    "value": "Sample value",
    "tone": "neutral"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'StatTile', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'label': GenUiBinding.string(data['label']),
        'value': GenUiBinding.string(data['value']),
        'caption': GenUiBinding.string(data['caption']),
        'tone': GenUiBinding.string(data['tone']),
      },
      builder: (context, v) => StatTile(
        label: v.string('label') ?? missing<String>('label', ''),
        value: v.string('value') ?? missing<String>('value', ''),
        caption: v.string('caption'),
        tone: Tone.values.asNameMap()[v.string('tone')] ?? Tone.neutral,
      ),
    );
  },
);
