// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'category_choice.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [CategoryChoice].
final CatalogItem categoryChoiceCatalogItem = CatalogItem(
  name: 'CategoryChoice',
  dataSchema: S.object(
    description:
        'Chips for choosing one spending category. Bind `value` to a '
        'data path and the choice is written there. Preselect the '
        'category you inferred from what the person said.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description: 'The caption above the chips, such as "Categoría".',
      ),
      'value': A2uiSchemas.stringReference(
        description:
            'The chosen category. The component writes the value the user '
            'chooses back to this property, so bind it to a data path if '
            'you need to read the result.',
        enumValues: [
          'housing',
          'groceries',
          'restaurants',
          'transport',
          'utilities',
          'subscriptions',
          'health',
          'shopping',
          'leisure',
          'debt',
          'other',
        ],
      ),
    },
    required: ['label', 'value'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "CategoryChoice",
    "label": "Sample label",
    "value": "housing"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'CategoryChoice', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'label': GenUiBinding.string(data['label']),
        'value': GenUiBinding.string(
          genUiWriteReference(ctx, data['value'], 'value'),
        ),
      },
      builder: (context, v) => CategoryChoice(
        label: v.string('label') ?? missing<String>('label', ''),
        value:
            Category.values.asNameMap()[(v.string('value') ??
                genUiAsString(data['value']))] ??
            missing<Category>('value', Category.values.first),
        onChanged: genUiValueWriter<Category>(
          ctx,
          data['value'],
          'value',
          encode: (value) => value.name,
        ),
      ),
    );
  },
);
