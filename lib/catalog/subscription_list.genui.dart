// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'subscription_list.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [SubscriptionList].
final CatalogItem subscriptionListCatalogItem = CatalogItem(
  name: 'SubscriptionList',
  dataSchema: S.object(
    description:
        'The person\'s subscriptions, one SubscriptionRow per item, '
        'with a footer saying what cancelling the unticked ones would '
        'save. Send the rows as a template over the list in the data '
        'model, and bind `savings` to `money` over '
        '`savingsIfCancelled` on that same list: the footer then '
        'updates on the device as switches flip.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description: 'A heading, such as "Tus suscripciones".',
      ),
      'rows': A2uiSchemas.componentArrayReference(
        description: 'One SubscriptionRow per subscription.',
      ),
      'savings': A2uiSchemas.stringReference(
        description:
            'What cancelling the switched-off rows saves each month, '
            'formatted.',
      ),
    },
    required: ['title', 'rows', 'savings'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "SubscriptionList",
    "title": "Quarterly report",
    "rows": [
      "child_rows_1",
      "child_rows_2"
    ],
    "savings": "Sample savings"
  },
  {
    "id": "child_rows_1",
    "component": "Text",
    "text": "Sample rows 1"
  },
  {
    "id": "child_rows_2",
    "component": "Text",
    "text": "Sample rows 2"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'SubscriptionList', property);
      return fallback;
    }

    final _rows = data['rows'];
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'rows': GenUiBinding.value(genUiTemplatePath(data['rows'])),
        'savings': GenUiBinding.string(data['savings']),
      },
      builder: (context, v) => SubscriptionList(
        title: v.string('title') ?? missing<String>('title', ''),
        rows: genUiTemplateChildren(ctx, _rows, v.raw('rows')),
        savings: v.string('savings') ?? missing<String>('savings', ''),
      ),
    );
  },
);
