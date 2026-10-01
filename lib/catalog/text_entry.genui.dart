// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'text_entry.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [TextEntry].
final CatalogItem textEntryCatalogItem = CatalogItem(
  name: 'TextEntry',
  dataSchema: S.object(
    description:
        'A one-line text input, such as a note or a merchant name. '
        'Bind `value` to a data path and the field writes what is '
        'typed there.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description: 'The caption above the field.',
      ),
      'value': A2uiSchemas.stringReference(
        description:
            'What the field holds. The component writes the value the '
            'user chooses back to this property, so bind it to a data '
            'path if you need to read the result.',
      ),
      'hint': A2uiSchemas.stringReference(
        description:
            'Greyed text shown while the field is empty, such as '
            '"Opcional".',
      ),
      'checks': A2uiSchemas.checkable(),
    },
    required: ['label', 'value'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "TextEntry",
    "label": "Sample label",
    "value": "Sample value"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'TextEntry', property);
      return fallback;
    }

    return GenUiChecks(
      dataContext: ctx.dataContext,
      checks: data['checks'],
      builder: (context, checked) => GenUiBindings(
        dataContext: ctx.dataContext,
        bindings: {
          'label': GenUiBinding.string(data['label']),
          'value': GenUiBinding.string(
            genUiWriteReference(ctx, data['value'], 'value'),
          ),
          'hint': GenUiBinding.string(data['hint']),
        },
        builder: (context, v) => TextEntry(
          label: v.string('label') ?? missing<String>('label', ''),
          value:
              (v.string('value') ?? genUiAsString(data['value'])) ??
              missing<String>('value', ''),
          hint: v.string('hint'),
          onChanged: genUiValueWriter<String>(ctx, data['value'], 'value'),
          error: checked.message,
        ),
      ),
    );
  },
);
