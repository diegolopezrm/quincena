// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'group.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [Group].
final CatalogItem groupCatalogItem = CatalogItem(
  name: 'Group',
  dataSchema: S.object(
    description:
        'A card with a title that holds related components, such as '
        'several BudgetMeters or the fields of a form, so they read '
        'as one block.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description:
            'What the pieces have in common, such as "Las que más '
            'cambiaron".',
      ),
      'children': S.list(
        description: 'The components inside the card.',
        items: A2uiSchemas.componentReference(),
      ),
    },
    required: ['title', 'children'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "Group",
    "title": "Quarterly report",
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
      genUiReportMissing(ctx, 'Group', property);
      return fallback;
    }

    final _children = data['children'];
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {'title': GenUiBinding.string(data['title'])},
      builder: (context, v) => Group(
        title: v.string('title') ?? missing<String>('title', ''),
        children: _children is List
            ? _children
                  .whereType<String>()
                  .map((id) => ctx.buildChild(id))
                  .toList()
            : missing<List<Widget>>('children', const <Widget>[]),
      ),
    );
  },
);
