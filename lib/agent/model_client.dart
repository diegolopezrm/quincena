import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:genui/genui.dart';

/// Streams a model's reply as text.
///
/// The live agent talks to this rather than to a provider, so the whole
/// pipeline from model text to rendered surface can be tested with a model
/// that says something known.
abstract interface class ModelClient {
  Stream<String> send(String prompt, {required List<ChatMessage> history});
}

/// Gemini, through dartantic as genui's own examples use it.
class GeminiClient implements ModelClient {
  GeminiClient({
    required String apiKey,
    required List<dartantic.Tool> tools,
    this.model = defaultModel,
  }) : _agent = dartantic.Agent.forProvider(
         dartantic.GoogleProvider(apiKey: apiKey),
         chatModelName: model,
         tools: tools,
       );

  /// The model genui's examples are run against.
  static const String defaultModel = 'gemini-3-flash-preview';

  final String model;
  final dartantic.Agent _agent;

  @override
  Stream<String> send(String prompt, {required List<ChatMessage> history}) =>
      _agent
          .sendStream(prompt, history: history)
          .map((dartantic.ChatResult<String> result) => result.output)
          .where((String chunk) => chunk.isNotEmpty);
}
