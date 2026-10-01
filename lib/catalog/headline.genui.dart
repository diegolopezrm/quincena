// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'headline.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [Headline].
final CatalogItem headlineCatalogItem = CatalogItem(
  name: 'Headline',
  dataSchema: S.object(
    description:
        'The opening of an answer: a short kicker, a headline that '
        'states the finding in one sentence, and an optional line of '
        'context. Start every surface with one. The headline is the '
        'answer; everything below it is the evidence.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description:
            'The finding itself, in one plain sentence, such as "Gastaste '
            'casi todo lo que entró". Never a question and never a label.',
      ),
      'kicker': A2uiSchemas.stringReference(
        description:
            'A few words naming the subject, shown small above the title, '
            'such as "Septiembre" or "Tu meta".',
      ),
      'body': A2uiSchemas.stringReference(
        description: 'One or two sentences of context under the title.',
      ),
    },
    required: ['title'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "Headline",
    "title": "Quarterly report"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'Headline', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'kicker': GenUiBinding.string(data['kicker']),
        'body': GenUiBinding.string(data['body']),
      },
      builder: (context, v) => Headline(
        title: v.string('title') ?? missing<String>('title', ''),
        kicker: v.string('kicker'),
        body: v.string('body'),
      ),
    );
  },
);
