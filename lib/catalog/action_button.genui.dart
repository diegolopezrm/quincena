// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'action_button.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [ActionButton].
final CatalogItem actionButtonCatalogItem = CatalogItem(
  name: 'ActionButton',
  dataSchema: S.object(
    description:
        'A full-width button that sends an event back to you, such as '
        'saving a form. Put the primary one last. Include in the '
        'event context whatever you need to act on it, bound to the '
        'data paths the form wrote.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description:
            'What pressing it does, as a verb: "Guardar", "Revisar las '
            'marcadas".',
      ),
      'emphasis': A2uiSchemas.stringReference(
        description:
            '`primary` for the main action of the surface, `secondary` '
            'for the rest.',
        enumValues: ['primary', 'secondary'],
      ),
      'onPressed': A2uiSchemas.action(
        description: 'What happens when it is pressed.',
      ),
    },
    required: ['label'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "ActionButton",
    "label": "Sample label",
    "emphasis": "primary",
    "onPressed": {
      "event": {
        "name": "submit"
      }
    }
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'ActionButton', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'label': GenUiBinding.string(data['label']),
        'emphasis': GenUiBinding.string(data['emphasis']),
      },
      builder: (context, v) => ActionButton(
        label: v.string('label') ?? missing<String>('label', ''),
        emphasis:
            Emphasis.values.asNameMap()[v.string('emphasis')] ??
            Emphasis.primary,
        onPressed: genUiActionHandler(ctx, data['onPressed']),
      ),
    );
  },
);
