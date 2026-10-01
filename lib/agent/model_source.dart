import 'dart:async';

import 'package:genui/genui.dart';

import '../data/ledger.dart';
import 'catalog.dart';
import 'model_client.dart';
import 'prompt.dart';
import 'source.dart';

/// Answers from a model.
///
/// The model writes A2UI messages as JSON blocks in its reply; genui's
/// transport adapter pulls them out of the text as it streams, and they go to
/// the same sink the scripted agent uses. Text outside the blocks is passed
/// on as text.
class ModelSource implements AnswerSource {
  ModelSource({
    required this.client,
    required Ledger ledger,
    required this.sink,
  }) : _history = <ChatMessage>[
         ChatMessage.system(quincenaPrompt(quincenaCatalog, ledger)),
       ] {
    _messages = _adapter.incomingMessages.listen(sink.message);
    _text = _adapter.incomingText.listen(sink.text);
  }

  final ModelClient client;
  final AnswerSink sink;
  final List<ChatMessage> _history;
  final A2uiTransportAdapter _adapter = A2uiTransportAdapter();
  late final StreamSubscription<Object?> _messages;
  late final StreamSubscription<Object?> _text;

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
      _adapter.addChunk(chunk);
    }
    _history
      ..add(ChatMessage.user(text))
      ..add(ChatMessage.model(reply.toString()));
  }

  @override
  void dispose() {
    unawaited(_messages.cancel());
    unawaited(_text.cancel());
    _adapter.dispose();
  }
}
