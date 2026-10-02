import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:firebase_ai/firebase_ai.dart' as ai;
import 'package:genui/genui.dart';

import '../ai/cloud.dart';
import 'model_client.dart';

/// Gemini through Quincena's Firebase project, with no key in the app.
///
/// Firebase AI Logic answers only an app App Check vouches for, counts each
/// person's requests, and sends them to Gemini on Google Cloud's Agent
/// Platform, whose terms rule out training on what is sent. The tools are
/// the same ones the keyed client gives dartantic, declared to Gemini from
/// their own schemas and run here, on the device, when Gemini asks: the
/// figures never leave the device except as the answers to those calls.
class FirebaseGeminiClient implements ModelClient {
  FirebaseGeminiClient({
    required List<dartantic.Tool> tools,
    this.model = defaultModel,
  }) : _tools = <String, dartantic.Tool>{
         for (final dartantic.Tool t in tools) t.name: t,
       },
       _declarations = <ai.FunctionDeclaration>[
         for (final dartantic.Tool t in tools) declarationFor(t),
       ];

  /// The newest Gemini Flash the project offers.
  static const String defaultModel = 'gemini-3.8-flash';

  /// Where Agent Platform runs the models. Firebase serves Gemini 3 only on
  /// global, us and eu, and global costs the list price.
  static const String location = 'global';

  /// How many times one answer may go back to the tools. Answers here take
  /// two or three; more means the model is going in circles.
  static const int maxRounds = 6;

  /// Models to turn to, in order, when the first is too busy or out of
  /// quota before it has shown or done anything.
  static const List<String> fallbackModels = <String>['gemini-3.5-flash'];

  /// How many more times a request goes out when the model is busy, and
  /// how long it waits first, longer each time.
  static const int retries = 1;
  static const Duration retryDelay = Duration(milliseconds: 1500);

  /// Whether [error] says the project used up what it may ask.
  static bool isOutOfQuota(Object error) {
    final String text = '$error';
    return text.contains('exceeded your current quota') ||
        text.contains('RESOURCE_EXHAUSTED') ||
        text.contains('429');
  }

  /// Whether [error] says the model was too busy to answer, which passes.
  static bool isBusy(Object error) {
    final String text = '$error';
    return text.contains('high demand') ||
        text.contains('overloaded') ||
        text.contains('UNAVAILABLE') ||
        text.contains('503');
  }

  final String model;
  final Map<String, dartantic.Tool> _tools;
  final List<ai.FunctionDeclaration> _declarations;

  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    if (!await Cloud.start()) {
      throw StateError('Firebase is not available on this platform');
    }
    await Cloud.signIn();
    final String system = <String>[
      for (final ChatMessage m in history)
        if (m.role == ChatMessageRole.system) m.text,
    ].join('\n\n');
    final List<String> models = <String>[
      model,
      for (final String m in fallbackModels)
        if (m != model) m,
    ];
    for (var i = 0; ; i++) {
      var started = false;
      try {
        await for (final String chunk in _answer(
          _chat(models[i], system, history),
          prompt,
          onTools: () => started = true,
        )) {
          started = true;
          yield chunk;
        }
        return;
      } on Object catch (error) {
        // Another model only while nothing has been shown or done: a tool
        // that ran, such as recording an expense, must not run twice.
        final bool next = isBusy(error) || isOutOfQuota(error);
        if (started || !next || i + 1 >= models.length) rethrow;
      }
    }
  }

  ai.ChatSession _chat(
    String model,
    String system,
    List<ChatMessage> history,
  ) => ai.FirebaseAI.agentPlatform(location: location)
      .generativeModel(
        model: model,
        systemInstruction: system.isEmpty ? null : ai.Content.system(system),
        tools: <ai.Tool>[ai.Tool.functionDeclarations(_declarations)],
        // The figures come from the tools and the shapes from the catalog:
        // composing an answer needs little reasoning, and a person waits
        // for every second of it.
        generationConfig: ai.GenerationConfig(
          thinkingConfig: ai.ThinkingConfig.withThinkingLevel(
            ai.ThinkingLevel.low,
          ),
        ),
      )
      .startChat(
        history: <ai.Content>[
          for (final ChatMessage m in history)
            if (m.role == ChatMessageRole.user)
              ai.Content.text(m.text)
            else if (m.role == ChatMessageRole.model)
              ai.Content.model(<ai.Part>[ai.TextPart(m.text)]),
        ],
      );

  /// One answer from one model: its text as it streams, and the tools it
  /// asks for run between rounds.
  Stream<String> _answer(
    ai.ChatSession chat,
    String prompt, {
    required void Function() onTools,
  }) async* {
    ai.Content next = ai.Content.text(prompt);
    for (var round = 0; round < maxRounds; round++) {
      final List<ai.FunctionCall> calls = <ai.FunctionCall>[];
      for (var attempt = 0; ; attempt++) {
        var wrote = false;
        try {
          await for (final ai.GenerateContentResponse response
              in chat.sendMessageStream(next)) {
            final String? text = response.text;
            if (text != null && text.isNotEmpty) {
              wrote = true;
              yield text;
            }
            calls.addAll(response.functionCalls);
          }
          break;
        } on Object catch (error) {
          // A busy model is worth a second try, as long as nothing of the
          // answer has been shown: the chat keeps no trace of a failed turn.
          if (wrote || attempt >= retries || !isBusy(error)) rethrow;
          calls.clear();
          await Future<void>.delayed(retryDelay * (attempt + 1));
        }
      }
      if (calls.isEmpty) return;
      onTools();
      // As the user's turn: the API no longer takes the `function` role
      // that firebase_ai's Content.functionResponses gives them.
      next = ai.Content('user', <ai.Part>[
        for (final ai.FunctionCall call in calls)
          ai.FunctionResponse(call.name, await _run(call), id: call.id),
      ]);
    }
  }

  Future<Map<String, Object?>> _run(ai.FunctionCall call) async {
    final dartantic.Tool? tool = _tools[call.name];
    if (tool == null) {
      return <String, Object?>{'error': 'There is no tool named ${call.name}.'};
    }
    try {
      final Object? result = await tool.call(
        Map<String, dynamic>.of(call.args),
      );
      return result is Map
          ? result.cast<String, Object?>()
          : <String, Object?>{'result': result};
    } on Object catch (error) {
      return <String, Object?>{'error': '$error'};
    }
  }
}

/// A dartantic tool as Firebase AI Logic declares it: the same name, the
/// same description and the same parameters, from the tool's JSON schema.
ai.FunctionDeclaration declarationFor(dartantic.Tool tool) {
  final Map<String, Object?> schema = tool.inputSchema.value;
  final Map<String, Object?> properties =
      (schema['properties'] as Map?)?.cast<String, Object?>() ??
      const <String, Object?>{};
  final Set<String> required = <String>{
    ...?(schema['required'] as List?)?.cast<String>(),
  };
  return ai.FunctionDeclaration(
    tool.name,
    tool.description,
    parameters: <String, ai.Schema>{
      for (final MapEntry<String, Object?> p in properties.entries)
        p.key: schemaFor((p.value! as Map).cast<String, Object?>()),
    },
    optionalParameters: <String>[
      for (final String name in properties.keys)
        if (!required.contains(name)) name,
    ],
  );
}

/// One JSON schema, as Firebase AI Logic's own.
ai.Schema schemaFor(Map<String, Object?> json) {
  final String? description = json['description'] as String?;
  switch (json['type']) {
    case 'object':
      final Map<String, Object?> properties =
          (json['properties'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final Set<String> required = <String>{
        ...?(json['required'] as List?)?.cast<String>(),
      };
      return ai.Schema.object(
        properties: <String, ai.Schema>{
          for (final MapEntry<String, Object?> p in properties.entries)
            p.key: schemaFor((p.value! as Map).cast<String, Object?>()),
        },
        optionalProperties: <String>[
          for (final String name in properties.keys)
            if (!required.contains(name)) name,
        ],
        description: description,
      );
    case 'array':
      return ai.Schema.array(
        items: schemaFor(
          (json['items'] as Map?)?.cast<String, Object?>() ??
              const <String, Object?>{'type': 'string'},
        ),
        description: description,
      );
    case 'integer':
      return ai.Schema.integer(description: description);
    case 'number':
      return ai.Schema.number(description: description);
    case 'boolean':
      return ai.Schema.boolean(description: description);
    default:
      final Object? values = json['enum'];
      return values is List
          ? ai.Schema.enumString(
              enumValues: <String>[for (final Object? v in values) '$v'],
              description: description,
            )
          : ai.Schema.string(description: description);
  }
}
