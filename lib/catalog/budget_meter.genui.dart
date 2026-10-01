// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'budget_meter.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [BudgetMeter].
final CatalogItem budgetMeterCatalogItem = CatalogItem(
  name: 'BudgetMeter',
  dataSchema: S.object(
    description:
        'A bar showing how much of a limit one category has used, '
        'such as restaurants against what was spent last month. Turns '
        'red past the limit. Use one per category being compared.',
    properties: {
      'category': A2uiSchemas.stringReference(
        description: 'The category being measured.',
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
      'spent': A2uiSchemas.numberReference(description: 'Pesos spent so far.'),
      'limit': A2uiSchemas.numberReference(
        description: 'The amount it is measured against.',
      ),
      'caption': A2uiSchemas.stringReference(
        description: 'What the limit is, such as "lo de agosto" or "tu tope".',
      ),
    },
    required: ['category', 'spent', 'limit'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "BudgetMeter",
    "category": "housing",
    "spent": 42.5,
    "limit": 19.99
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'BudgetMeter', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'category': GenUiBinding.string(data['category']),
        'spent': GenUiBinding.number(data['spent']),
        'limit': GenUiBinding.number(data['limit']),
        'caption': GenUiBinding.string(data['caption']),
      },
      builder: (context, v) => BudgetMeter(
        category:
            Category.values.asNameMap()[v.string('category')] ??
            missing<Category>('category', Category.values.first),
        spent: (v.number('spent') ?? missing<num>('spent', 0)).toDouble(),
        limit: (v.number('limit') ?? missing<num>('limit', 0)).toDouble(),
        caption: v.string('caption'),
      ),
    );
  },
);
