// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'suggestions.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [Suggestions].
final CatalogItem suggestionsCatalogItem = CatalogItem(
  name: 'Suggestions',
  dataSchema: S.object(
    description:
        'Two or three follow-up questions the person might ask next, '
        'as chips. End most answers with one. Each child is a '
        'Suggestion.',
    properties: {
      'children': S.list(
        description: 'The Suggestion chips.',
        items: A2uiSchemas.componentReference(),
      ),
    },
    required: ['children'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "Suggestions",
    "children": [
      "child_children_1",
      "child_children_2"
    ]
  },
  {
    "id": "child_children_1",
    "component": "Text",
    "text": "Sample children 1"
  },
  {
    "id": "child_children_2",
    "component": "Text",
    "text": "Sample children 2"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'Suggestions', property);
      return fallback;
    }

    final _children = data['children'];
    return Suggestions(
      children: _children is List
          ? _children
                .whereType<String>()
                .map((id) => ctx.buildChild(id))
                .toList()
          : missing<List<Widget>>('children', const <Widget>[]),
    );
  },
);

/// Generated [CatalogItem] for [Suggestion].
final CatalogItem suggestionCatalogItem = CatalogItem(
  name: 'Suggestion',
  dataSchema: S.object(
    description:
        'One follow-up question, as a chip inside Suggestions. Its '
        'action should be an event named "ask" whose context carries '
        'the question text, so pressing it asks you that question.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description:
            'The question, in the person\'s words, such as "¿Cómo voy '
            'contra agosto?".',
      ),
      'onPressed': A2uiSchemas.action(description: 'Asks the question.'),
    },
    required: ['label'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "Suggestion",
    "label": "Sample label",
    "onPressed": {
      "event": {
        "name": "ask"
      }
    }
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'Suggestion', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {'label': GenUiBinding.string(data['label'])},
      builder: (context, v) => Suggestion(
        label: v.string('label') ?? missing<String>('label', ''),
        onPressed: genUiActionHandler(ctx, data['onPressed']),
      ),
    );
  },
);
