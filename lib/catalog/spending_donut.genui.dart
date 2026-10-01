// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'spending_donut.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [SpendingDonut].
final CatalogItem spendingDonutCatalogItem = CatalogItem(
  name: 'SpendingDonut',
  dataSchema: S.object(
    description:
        'A donut chart of spending by category, with a legend listing '
        'each category, its amount and its share. Use it to answer '
        'where the money went in a period. Send every category with '
        'spending, largest first.',
    properties: {
      'slices': A2uiSchemas.listOrReference(
        description: 'The categories and their amounts, largest first.',
        items: categorySliceGenUiSchema,
      ),
      'centerLabel': A2uiSchemas.stringReference(
        description:
            'A word or two under the total in the middle of the ring, '
            'such as "septiembre".',
      ),
      'title': A2uiSchemas.stringReference(
        description: 'A heading above the chart, such as "Por categoría".',
      ),
    },
    required: ['slices', 'centerLabel'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "SpendingDonut",
    "slices": [
      {
        "category": "housing",
        "amount": 19.99
      },
      {
        "category": "groceries",
        "amount": 249.5
      }
    ],
    "centerLabel": "Sample center label"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'SpendingDonut', property);
      return fallback;
    }

    GenUiMissingFieldReporter missingIn(String property) =>
        (field) => genUiReportMissing(ctx, 'SpendingDonut', '$property.$field');
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'slices': GenUiBinding.objectList(data['slices']),
        'centerLabel': GenUiBinding.string(data['centerLabel']),
        'title': GenUiBinding.string(data['title']),
      },
      builder: (context, v) => SpendingDonut(
        slices:
            v
                .objectList('slices')
                ?.map(
                  (json) =>
                      categorySliceFromGenUiJson(json, missingIn('slices')),
                )
                .toList() ??
            missing<List<CategorySlice>>('slices', const <CategorySlice>[]),
        centerLabel:
            v.string('centerLabel') ?? missing<String>('centerLabel', ''),
        title: v.string('title'),
      ),
    );
  },
);
