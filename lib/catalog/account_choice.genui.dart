// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'account_choice.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [AccountChoice].
final CatalogItem accountChoiceCatalogItem = CatalogItem(
  name: 'AccountChoice',
  dataSchema: S.object(
    description:
        'Chips for choosing the account a payment comes from, one per '
        'name in `options`. Bind `value` to a data path and the '
        'choice is written there. Preselect the account the person '
        'named, or else the likely one expense_accounts gives.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description: 'The caption above the chips, such as "Desde".',
      ),
      'options': A2uiSchemas.stringArrayReference(
        description:
            'The accounts to choose from, named as the app names them.',
      ),
      'value': A2uiSchemas.stringReference(
        description:
            'The name of the chosen account. The component writes the '
            'value the user chooses back to this property, so bind it to '
            'a data path if you need to read the result.',
      ),
    },
    required: ['label', 'options', 'value'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "AccountChoice",
    "label": "Sample label",
    "options": [
      "Alpha",
      "Beta"
    ],
    "value": "Sample value"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'AccountChoice', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'label': GenUiBinding.string(data['label']),
        'options': GenUiBinding.stringList(data['options']),
        'value': GenUiBinding.string(
          genUiWriteReference(ctx, data['value'], 'value'),
        ),
      },
      builder: (context, v) => AccountChoice(
        label: v.string('label') ?? missing<String>('label', ''),
        options:
            v.stringList('options') ??
            missing<List<String>>('options', const <String>[]),
        value:
            (v.string('value') ?? genUiAsString(data['value'])) ??
            missing<String>('value', ''),
        onChanged: genUiValueWriter<String>(ctx, data['value'], 'value'),
      ),
    );
  },
);
