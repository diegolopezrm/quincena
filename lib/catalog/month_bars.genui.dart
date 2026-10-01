// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'month_bars.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [MonthBars].
final CatalogItem monthBarsCatalogItem = CatalogItem(
  name: 'MonthBars',
  dataSchema: S.object(
    description:
        'A bar chart of spending over several months, oldest on the '
        'left, with an optional dashed line for a reference such as '
        'income. Use it to answer how one month compares with the '
        'ones before. Highlight the month the answer is about.',
    properties: {
      'months': A2uiSchemas.listOrReference(
        description: 'One entry per month, oldest first.',
        items: monthTotalGenUiSchema,
      ),
      'title': A2uiSchemas.stringReference(
        description: 'A heading above the chart, such as "Últimos seis meses".',
      ),
      'reference': A2uiSchemas.numberReference(
        description:
            'An amount drawn as a dashed line across the chart, such as '
            'the monthly income.',
      ),
      'referenceLabel': A2uiSchemas.stringReference(
        description: 'What the dashed line is, such as "Ingresos".',
      ),
    },
    required: ['months'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "MonthBars",
    "months": [
      {
        "month": "Sample month 1",
        "amount": 19.99
      },
      {
        "month": "Sample month 2",
        "amount": 249.5
      }
    ]
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'MonthBars', property);
      return fallback;
    }

    GenUiMissingFieldReporter missingIn(String property) =>
        (field) => genUiReportMissing(ctx, 'MonthBars', '$property.$field');
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'months': GenUiBinding.objectList(data['months']),
        'title': GenUiBinding.string(data['title']),
        'reference': GenUiBinding.number(data['reference']),
        'referenceLabel': GenUiBinding.string(data['referenceLabel']),
      },
      builder: (context, v) => MonthBars(
        months:
            v
                .objectList('months')
                ?.map(
                  (json) => monthTotalFromGenUiJson(json, missingIn('months')),
                )
                .toList() ??
            missing<List<MonthTotal>>('months', const <MonthTotal>[]),
        title: v.string('title'),
        reference: v.number('reference')?.toDouble(),
        referenceLabel: v.string('referenceLabel'),
      ),
    );
  },
);
