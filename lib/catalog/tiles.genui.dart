// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'tiles.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [Tiles].
final CatalogItem tilesCatalogItem = CatalogItem(
  name: 'Tiles',
  dataSchema: S.object(
    description:
        'Lays two to four components side by side in equal columns, '
        'folding to a single column on a narrow screen. Use it for '
        'StatTiles.',
    properties: {
      'children': S.list(
        description: 'The components to lay out, usually StatTiles.',
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
    "component": "Tiles",
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
      genUiReportMissing(ctx, 'Tiles', property);
      return fallback;
    }

    final _children = data['children'];
    return Tiles(
      children: _children is List
          ? _children
                .whereType<String>()
                .map((id) => ctx.buildChild(id))
                .toList()
          : missing<List<Widget>>('children', const <Widget>[]),
    );
  },
);
