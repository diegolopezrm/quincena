import '../data/ledger.dart';
import 'catalog.dart';
import 'scripted_agent.dart';
import 'source.dart';

/// Answers from [ScriptedAgent], with the pause a model would take.
class ScriptedSource implements AnswerSource {
  ScriptedSource(
    Ledger ledger, {
    required this.sink,
    this.thinking = const Duration(milliseconds: 700),
  }) : _agent = ScriptedAgent(ledger);

  final ScriptedAgent _agent;
  final AnswerSink sink;
  final Duration thinking;
  int _serial = 0;

  @override
  Future<void> ask(String question) => _deliver(() => _agent.answer(question));

  @override
  Future<void> react(UserAction action) =>
      _deliver(() => _agent.react(action.name, action.context));

  Future<void> _deliver(AgentTurn? Function() compose) async {
    await Future<void>.delayed(thinking);
    final AgentTurn? answer = compose();
    if (answer == null) return;
    final String surfaceId = 'answer-${++_serial}';
    answer
        .messages(surfaceId, quincenaCatalog.catalogId!)
        .forEach(sink.message);
  }

  @override
  void dispose() {}
}
