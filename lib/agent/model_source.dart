import 'dart:async';

import 'package:genui/genui.dart';

import '../data/ledger.dart';
import 'catalog.dart';
import 'model_client.dart';
import 'prompt.dart';
import 'source.dart';

/// Answers from a model.
///
/// The model writes A2UI messages as JSON blocks in its reply. genui's
/// parser pulls them out of the text as it streams; text outside the blocks
/// is passed on as text, and a block that looks like a message but is not a
/// valid one is passed on as an error, so the model can be told and fix it.
///
/// The parser is used directly rather than through genui's
/// `A2uiTransportAdapter`, whose own subscription to it has no error
/// handler: a rejected message there produces no surface, no text and no
/// report, and the model never learns it was rejected.
class ModelSource implements AnswerSource {
  ModelSource({
    required this.client,
    required Ledger ledger,
    required this.sink,
    String language = 'es',
    bool own = false,
  }) : _ledger = ledger,
       _own = own,
       _language = language,
       _history = <ChatMessage>[_told(ledger, language, own)] {
    _events = _chunks.stream
        .transform(const A2uiParserTransformer())
        .listen(
          (GenerationEvent event) => switch (event) {
            A2uiMessageEvent(:final message) => sink.message(message),
            TextEvent(:final text) => sink.text(text),
          },
          onError: sink.error,
        );
  }

  final ModelClient client;
  final AnswerSink sink;
  final Ledger _ledger;
  final bool _own;
  String _language;

  /// What the model has read: what it is told first, then each message and
  /// its reply.
  final List<ChatMessage> _history;
  final StreamController<String> _chunks = StreamController<String>();
  late final StreamSubscription<GenerationEvent> _events;

  /// What the model is told before the first message, in [language].
  static ChatMessage _told(Ledger ledger, String language, bool own) =>
      ChatMessage.system(
        quincenaPrompt(quincenaCatalog, ledger, language: language, own: own),
      );

  /// Every reply the model wrote, exactly as it wrote it, for debugging and
  /// for the recording tool.
  final List<String> replies = <String>[];

  @override
  Future<void> ask(String question) => _send(question);

  /// The interaction goes to the model as genui encoded it: the event's name,
  /// the component it came from, and its context resolved against the data
  /// model, which is everything the model needs to act on it.
  @override
  Future<void> react(UserAction action) => _send(action.interaction);

  Future<void> _send(String text) async {
    final reply = StringBuffer();
    await for (final String chunk in client.send(
      text,
      history: List<ChatMessage>.of(_history),
    )) {
      reply.write(chunk);
      _chunks.add(chunk);
    }
    replies.add(reply.toString());
    _history
      ..add(ChatMessage.user(text))
      ..add(ChatMessage.model(reply.toString()));
  }

  /// Told from the next message on to write in the new language: what it
  /// already said stays as it was said.
  @override
  set language(String value) {
    if (value == _language) return;
    _language = value;
    _history[0] = _told(_ledger, value, _own);
  }

  /// Adds to what the model has read an exchange the phone answered without
  /// it: [said], what the person did on one of its surfaces, as genui
  /// encoded it, and [answered], the answer the phone gave, written as the
  /// model writes one. A question after it then starts from there.
  void remember(String said, String answered) {
    _history
      ..add(ChatMessage.user(said))
      ..add(ChatMessage.model(answered));
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    unawaited(_chunks.close());
  }
}
