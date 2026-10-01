// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'subscription_row.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [SubscriptionRow].
final CatalogItem subscriptionRowCatalogItem = CatalogItem(
  name: 'SubscriptionRow',
  dataSchema: S.object(
    description:
        'One subscription with its monthly price, when it was last '
        'used, and a switch to keep it. Bind `keep` to a data path: '
        'the switch writes there. Meant as the template row of a '
        'SubscriptionList, with every property bound to a path '
        'relative to the row.',
    properties: {
      'name': A2uiSchemas.stringReference(
        description: 'The service, as the statement names it.',
      ),
      'price': A2uiSchemas.numberReference(
        description: 'What it costs every month, in pesos.',
      ),
      'keep': A2uiSchemas.booleanReference(
        description:
            'Whether the person keeps paying for it. The component writes '
            'the value the user chooses back to this property, so bind it '
            'to a data path if you need to read the result.',
      ),
      'lastUsed': A2uiSchemas.stringReference(
        description: 'The last day it was used, written as YYYY-MM-DD.',
      ),
    },
    required: ['name', 'price', 'keep'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "SubscriptionRow",
    "name": "Sample name",
    "price": 19.99,
    "keep": true
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'SubscriptionRow', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'name': GenUiBinding.string(data['name']),
        'price': GenUiBinding.number(data['price']),
        'keep': GenUiBinding.bool(
          genUiWriteReference(ctx, data['keep'], 'keep'),
        ),
        'lastUsed': GenUiBinding.string(data['lastUsed']),
      },
      builder: (context, v) => SubscriptionRow(
        name: v.string('name') ?? missing<String>('name', ''),
        price: (v.number('price') ?? missing<num>('price', 0)).toDouble(),
        keep:
            (v.boolean('keep') ?? genUiAsBool(data['keep'])) ??
            missing<bool>('keep', false),
        onKeepChanged: genUiValueWriter<bool>(ctx, data['keep'], 'keep'),
        lastUsed: v.string('lastUsed'),
      ),
    );
  },
);
