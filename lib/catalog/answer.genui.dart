// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'answer.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [Answer].
final CatalogItem answerCatalogItem = CatalogItem(
  name: 'Answer',
  dataSchema: S.object(
    description:
        'The root of every answer: stacks its children top to bottom '
        'with even spacing. Make it the `root` component of every '
        'surface, with a Headline first.',
    properties: {
      'children': S.list(
        description: 'The parts of the answer, in reading order.',
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
    "component": "Answer",
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
      genUiReportMissing(ctx, 'Answer', property);
      return fallback;
    }

    final _children = data['children'];
    return Answer(
      children: _children is List
          ? _children
                .whereType<String>()
                .map((id) => ctx.buildChild(id))
                .toList()
          : missing<List<Widget>>('children', const <Widget>[]),
    );
  },
);
