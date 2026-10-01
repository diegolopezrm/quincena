// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'big_amount.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [BigAmount].
final CatalogItem bigAmountCatalogItem = CatalogItem(
  name: 'BigAmount',
  dataSchema: S.object(
    description:
        'One amount of money shown large, with a label above and a '
        'caption below. Use it for the single number an answer turns '
        'on, at most once per surface.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description: 'What the amount is, such as "Gastado en septiembre".',
      ),
      'amount': A2uiSchemas.numberReference(
        description: 'The amount in pesos.',
      ),
      'caption': A2uiSchemas.stringReference(
        description:
            'A short line under the amount that puts it in context, such '
            'as "de \$ 4.800.000 que entraron".',
      ),
      'tone': A2uiSchemas.stringReference(
        description:
            'Colors the caption: `good` when the number is fine, '
            '`caution` when it is worth a look, `alert` when something '
            'has to change.',
        enumValues: ['neutral', 'good', 'caution', 'alert'],
      ),
    },
    required: ['label', 'amount'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "BigAmount",
    "label": "Sample label",
    "amount": 19.99,
    "tone": "neutral"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'BigAmount', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'label': GenUiBinding.string(data['label']),
        'amount': GenUiBinding.number(data['amount']),
        'caption': GenUiBinding.string(data['caption']),
        'tone': GenUiBinding.string(data['tone']),
      },
      builder: (context, v) => BigAmount(
        label: v.string('label') ?? missing<String>('label', ''),
        amount: (v.number('amount') ?? missing<num>('amount', 0)).toDouble(),
        caption: v.string('caption'),
        tone: Tone.values.asNameMap()[v.string('tone')] ?? Tone.neutral,
      ),
    );
  },
);
