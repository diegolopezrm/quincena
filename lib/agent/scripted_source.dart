import 'dart:async';

import '../data/ledger.dart';
import 'catalog.dart';
import 'scripted_agent.dart';
import 'source.dart';

/// Answers from [ScriptedAgent], with the pause a model would take.
class ScriptedSource implements AnswerSource {
  /// Answers from the account [ledger] gives at each answer; what the
  /// person saves goes where [keeper] keeps it, or into that account.
  ScriptedSource(
    Ledger Function() ledger, {
    required this.sink,
    this.thinking = const Duration(milliseconds: 700),
    String language = 'es',
    ScriptedKeeper? keeper,
  }) : _ledger = ledger,
       _keeper = keeper,
       _agent = ScriptedAgent.over(ledger, language: language, keeper: keeper);

  final Ledger Function() _ledger;
  final ScriptedKeeper? _keeper;
  ScriptedAgent _agent;
  final AnswerSink sink;
  final Duration thinking;
  int _serial = 0;

  /// A script in the new language from the next answer on. The count of
  /// surfaces goes on, so a new answer never takes an old one's id.
  @override
  set language(String value) {
    if (value == _agent.language) return;
    _agent = ScriptedAgent.over(_ledger, language: value, keeper: _keeper);
  }

  @override
  Future<void> ask(String question) => _deliver(() => _agent.answer(question));

  @override
  Future<void> react(UserAction action) =>
      _deliver(() => _agent.respond(action.name, action.context));

  Future<void> _deliver(FutureOr<AgentTurn?> Function() compose) async {
    // Worked out before the pause: something with no answer, such as a form
    // sent with an amount it turns down, is not kept waiting as if one were
    // coming.
    final AgentTurn? answer = await compose();
    if (answer == null) return;
    await Future<void>.delayed(thinking);
    final String surfaceId = 'answer-${++_serial}';
    answer
        .messages(surfaceId, quincenaCatalog.catalogId!)
        .forEach(sink.message);
  }

  @override
  void dispose() {}
}
