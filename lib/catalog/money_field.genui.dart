// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'money_field.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [MoneyField].
final CatalogItem moneyFieldCatalogItem = CatalogItem(
  name: 'MoneyField',
  dataSchema: S.object(
    description:
        'An input for an amount of pesos, grouped with dots as it is '
        'typed. Bind `value` to a data path and the field writes the '
        'number there. Attach `checks` to validate it, such as a '
        'minimum with the `numeric` function; the message of the '
        'first failing rule shows under the field.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description: 'The caption above the field, such as "Monto".',
      ),
      'value': A2uiSchemas.numberReference(
        description:
            'The amount in the field, in pesos. Zero shows an empty '
            'field. The component writes the value the user chooses back '
            'to this property, so bind it to a data path if you need to '
            'read the result.',
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
    "component": "MoneyField",
    "label": "Sample label",
    "value": 19.99
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'MoneyField', property);
      return fallback;
    }

    return GenUiChecks(
      dataContext: ctx.dataContext,
      checks: data['checks'],
      builder: (context, checked) => GenUiBindings(
        dataContext: ctx.dataContext,
        bindings: {
          'label': GenUiBinding.string(data['label']),
          'value': GenUiBinding.number(
            genUiWriteReference(ctx, data['value'], 'value'),
          ),
        },
        builder: (context, v) => MoneyField(
          label: v.string('label') ?? missing<String>('label', ''),
          value:
              ((v.number('value') ?? genUiAsNum(data['value'])) ??
                      missing<num>('value', 0))
                  .toDouble(),
          onChanged: genUiValueWriter<double>(ctx, data['value'], 'value'),
          error: checked.message,
        ),
      ),
    );
  },
);
