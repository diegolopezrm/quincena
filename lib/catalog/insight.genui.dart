// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'insight.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [Insight].
final CatalogItem insightCatalogItem = CatalogItem(
  name: 'Insight',
  dataSchema: S.object(
    description:
        'One finding about the money, said plainly, with an optional '
        'action. Use one per finding, two or three per answer at '
        'most, and lead with the one that matters most. The title '
        'names the finding with its number; the body says why it '
        'happened.',
    properties: {
      'tone': A2uiSchemas.stringReference(
        description:
            '`good` for good news, `caution` for something worth a look, '
            '`alert` for something that needs changing, `neutral` for a '
            'plain fact.',
        enumValues: ['neutral', 'good', 'caution', 'alert'],
      ),
      'title': A2uiSchemas.stringReference(
        description:
            'The finding with its number, such as "Restaurantes subió 67 '
            '%".',
      ),
      'body': A2uiSchemas.stringReference(
        description: 'Why it happened, in one or two sentences.',
      ),
      'actionLabel': A2uiSchemas.stringReference(
        description:
            'The text of the action link, such as "Ver esos pagos". Leave '
            'it out when there is nothing to do.',
      ),
      'onAction': A2uiSchemas.action(
        description: 'What happens when the action link is pressed.',
      ),
    },
    required: ['tone', 'title', 'body'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "Insight",
    "tone": "neutral",
    "title": "Quarterly report",
    "body": "A short line of copy, the length a real one tends to be.",
    "actionLabel": "https://example.com",
    "onAction": {
      "event": {
        "name": "insight_action"
      }
    }
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'Insight', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'tone': GenUiBinding.string(data['tone']),
        'title': GenUiBinding.string(data['title']),
        'body': GenUiBinding.string(data['body']),
        'actionLabel': GenUiBinding.string(data['actionLabel']),
      },
      builder: (context, v) => Insight(
        tone:
            Tone.values.asNameMap()[v.string('tone')] ??
            missing<Tone>('tone', Tone.values.first),
        title: v.string('title') ?? missing<String>('title', ''),
        body: v.string('body') ?? missing<String>('body', ''),
        actionLabel: v.string('actionLabel'),
        onAction: genUiActionHandler(ctx, data['onAction']),
      ),
    );
  },
);
