import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/tracing.dart';

import '../agent/catalog.dart';
import '../agent/scripted_agent.dart';
import '../data/ledger.dart';
import '../data/seed.dart';

/// One exchange: what the person asked, and the surface that answered.
class Turn {
  Turn({this.question, this.note});

  /// What the person typed or picked. Null when the turn started from
  /// something they did on a surface, which [note] describes instead.
  final String? question;
  final String? note;

  /// The surface holding the answer, once it has arrived.
  String? surfaceId;
}

/// A conversation with the agent about the demo account.
///
/// Every message the agent sends goes through a [GenUiTraceRecorder] on its
/// way to the controller, so the whole session can be inspected while it runs
/// and written out afterwards, with no change to how it renders.
class Session extends ChangeNotifier {
  Session({this.thinking = const Duration(milliseconds: 700)}) {
    _start();
  }

  /// How long the scripted agent takes to answer. A pause the length of a
  /// real one keeps the demo honest about what it is imitating.
  final Duration thinking;

  late Ledger ledger;
  late ScriptedAgent _agent;
  late SurfaceController controller;
  late GenUiTraceRecorder recorder;
  late StreamSubscription<ChatMessage> _submissions;

  final List<Turn> turns = <Turn>[];
  bool _busy = false;
  bool get busy => _busy;
  int _serial = 0;

  void _start() {
    ledger = demoLedger();
    _agent = ScriptedAgent(ledger);
    controller = SurfaceController(catalogs: <Catalog>[quincenaCatalog]);
    recorder = GenUiTraceRecorder.attach(
      controller,
      catalogId: quincenaCatalog.catalogId,
      notes: const <String, Object?>{'app': 'quincena', 'agent': 'scripted'},
    );
    _submissions = controller.onSubmit.listen(_onSubmit);
  }

  /// Asks the agent [question].
  Future<void> ask(String question) async {
    final String text = question.trim();
    if (text.isEmpty || _busy) return;
    final turn = Turn(question: text);
    await _respond(turn, () => _agent.answer(text));
  }

  Future<void> _respond(Turn turn, AgentTurn? Function() compose) async {
    turns.add(turn);
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(thinking);
    if (!turns.contains(turn)) return;
    final AgentTurn? answer = compose();
    if (answer != null) {
      final String id = 'answer-${++_serial}';
      for (final message in answer.messages(id, quincenaCatalog.catalogId!)) {
        recorder.handleMessage(message);
      }
      turn.surfaceId = id;
    } else {
      turns.remove(turn);
    }
    _busy = false;
    notifyListeners();
  }

  void _onSubmit(ChatMessage message) {
    for (final UiInteractionPart part in message.parts.uiInteractionParts) {
      final Object? decoded = jsonDecode(part.interaction);
      if (decoded is! Map) continue;
      final Object? action = decoded['action'];
      if (action is! Map) continue;
      final String? name = action['name'] as String?;
      final Map<String, Object?> context = <String, Object?>{
        ...?(action['context'] as Map?)?.cast<String, Object?>(),
      };
      if (name == null || _busy) continue;
      if (name == 'ask' && context['question'] is String) {
        unawaited(ask(context['question']! as String));
      } else {
        unawaited(
          _respond(
            Turn(note: _describe(name)),
            () => _agent.react(name, context),
          ),
        );
      }
    }
  }

  static String _describe(String action) => switch (action) {
    'save_expense' => 'Guardaste el gasto',
    'save_goal_plan' => 'Elegiste cuánto apartar',
    'cancel_subscriptions' => 'Pediste cancelar suscripciones',
    'show_category' => 'Pediste ver los pagos',
    _ => 'Tocaste una acción',
  };

  /// Back to the untouched demo account and an empty conversation.
  void restart() {
    _teardown();
    turns.clear();
    _busy = false;
    _serial = 0;
    _start();
    notifyListeners();
  }

  void _teardown() {
    unawaited(_submissions.cancel());
    recorder.dispose();
    controller.dispose();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
