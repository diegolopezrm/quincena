// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'movement_list.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [MovementList].
final CatalogItem movementListCatalogItem = CatalogItem(
  name: 'MovementList',
  dataSchema: S.object(
    description:
        'A list of payments from the statement, each with its '
        'merchant, category, day and amount. Use it to show the '
        'payments behind a finding, such as the largest of the month '
        'or every payment in one category. Ten rows or fewer.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description: 'What the list is, such as "Los cinco pagos más grandes".',
      ),
      'items': A2uiSchemas.listOrReference(
        description: 'The payments, in the order they should be read.',
        items: movementItemGenUiSchema,
      ),
    },
    required: ['title', 'items'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "MovementList",
    "title": "Quarterly report",
    "items": [
      {
        "merchant": "Sample merchant 1",
        "category": "housing",
        "amount": 19.99,
        "date": "2026-01-15"
      },
      {
        "merchant": "Sample merchant 2",
        "category": "groceries",
        "amount": 249.5,
        "date": "2026-01-15"
      }
    ]
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'MovementList', property);
      return fallback;
    }

    GenUiMissingFieldReporter missingIn(String property) =>
        (field) => genUiReportMissing(ctx, 'MovementList', '$property.$field');
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'items': GenUiBinding.objectList(data['items']),
      },
      builder: (context, v) => MovementList(
        title: v.string('title') ?? missing<String>('title', ''),
        items:
            v
                .objectList('items')
                ?.map(
                  (json) => movementItemFromGenUiJson(json, missingIn('items')),
                )
                .toList() ??
            missing<List<MovementItem>>('items', const <MovementItem>[]),
      ),
    );
  },
);
