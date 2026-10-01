import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/tracing.dart';
import 'package:intl/intl.dart';

import '../agent/catalog.dart';
import '../agent/model_client.dart';
import '../agent/model_source.dart';
import '../agent/scripted_source.dart';
import '../agent/source.dart';
import '../agent/tools.dart';
import '../data/ledger.dart';
import '../data/seed.dart';
import '../l10n/l10n.dart';

/// Who answers: the script the demo ships with, or a model.
enum AgentMode { demo, live }

/// What the person did on a surface, shown in place of a question.
enum TurnNote { savedExpense, choseMonthly, askedCancel, askedPayments, other }

/// Why an answer did not arrive.
enum AnswerProblem { key, busy, other }

/// One exchange: what the person asked, and what answered it.
class Turn {
  Turn({this.question, this.note});

  /// What the person typed or picked. Null when the turn started from
  /// something they did on a surface, which [note] describes instead.
  final String? question;
  final TurnNote? note;

  /// The surfaces the answer created, in order. A model may create more than
  /// one, and the first arrives before the answer is finished.
  final List<String> surfaceIds = <String>[];

  /// What the agent wrote outside its surfaces.
  final StringBuffer text = StringBuffer();

  /// Set when the answer failed.
  AnswerProblem? error;
}

/// A conversation with the agent about the demo account.
///
/// Every message the agent sends goes through a [GenUiTraceRecorder] on its
/// way to the controller, so the whole session can be inspected while it runs
/// and written out afterwards, with no change to how it renders, and whether
/// a script or a model sent it.
class Session extends ChangeNotifier {
  Session({
    this.thinking = const Duration(milliseconds: 700),
    this.errorWindow = const Duration(milliseconds: 300),
    AgentMode mode = AgentMode.demo,
    String? apiKey,
    String language = 'es',
    this.client,
  }) {
    _mode = mode;
    _apiKey = apiKey;
    _language = language;
    Intl.defaultLocale = intlLocaleFor(language);
    _start();
  }

  late String _language;

  /// The language answers are written in: `es` or `en`.
  String get language => _language;

  /// Switches the language of the answers and of every amount and date
  /// formatted after it, and starts over, since a conversation half in one
  /// language and half in the other helps no one.
  set language(String value) {
    if (value == _language) return;
    _language = value;
    Intl.defaultLocale = intlLocaleFor(value);
    restart();
  }

  /// How long the scripted agent takes to answer. A pause the length of a
  /// real one keeps the demo honest about what it is imitating.
  final Duration thinking;

  /// How long to wait after a model's answer for genui to report what was
  /// wrong with it.
  ///
  /// genui validates a surface against the catalog asynchronously and says
  /// nothing when it finds no problem, so there is no moment that marks
  /// validation as done. A short quiet window is the honest way to wait.
  final Duration errorWindow;

  /// A model to use instead of Gemini, for tests.
  final ModelClient? client;

  late AgentMode _mode;
  AgentMode get mode => _mode;
  String? _apiKey;

  /// Whether a model can answer: there is a key, or a client was given.
  bool get canGoLive => client != null || (_apiKey?.isNotEmpty ?? false);

  late Ledger ledger;
  late SurfaceController controller;
  late GenUiTraceRecorder recorder;
  late AnswerSource _source;

  /// The model's raw replies in this conversation, when a model is answering.
  List<String> get replies => switch (_source) {
    final ModelSource source => List<String>.unmodifiable(source.replies),
    _ => const <String>[],
  };
  late StreamSubscription<ChatMessage> _submissions;
  late StreamSubscription<SurfaceUpdate> _surfaces;

  final List<Turn> turns = <Turn>[];
  bool _busy = false;
  bool get busy => _busy;

  /// Errors genui reported about the current answer, waiting to go back to
  /// the model once it has finished writing.
  final List<String> _errors = <String>[];

  /// How many times the model has been asked to fix one answer. A model that
  /// cannot fix its surface in two tries will not in a third.
  int _corrections = 0;
  static const int _maxCorrections = 2;

  void _start() {
    ledger = demoLedger();
    controller = SurfaceController(catalogs: <Catalog>[quincenaCatalog]);
    recorder = GenUiTraceRecorder.attach(
      controller,
      catalogId: quincenaCatalog.catalogId,
      // What the person types into a form never leaves in a copied session.
      // The scripted agent keeps its form at /draft, and models have been
      // seen to pick /form; both are covered.
      redact: const <String>['/draft/note', '/form/note'],
      notes: <String, Object?>{
        'app': 'quincena',
        'agent': _mode.name,
        'language': _language,
      },
    );
    final sink = AnswerSink(
      message: _onMessage,
      text: _onText,
      // Through genui's own error path, so it reaches the model the way a
      // validation failure does, and lands in the recording.
      error: (Object error, StackTrace stack) =>
          controller.reportError(error, stack),
    );
    _source = switch (_mode) {
      AgentMode.demo => ScriptedSource(
        ledger,
        sink: sink,
        thinking: thinking,
        language: _language,
      ),
      AgentMode.live => ModelSource(
        client:
            client ??
            GeminiClient(apiKey: _apiKey!, tools: ledgerTools(ledger)),
        ledger: ledger,
        sink: sink,
        language: _language,
      ),
    };
    _submissions = controller.onSubmit.listen(_onSubmit);
    _surfaces = controller.surfaceUpdates.listen(_onSurface);
  }

  void _onMessage(core.A2uiMessage message) => recorder.handleMessage(message);

  void _onText(String text) {
    if (turns.isEmpty) return;
    turns.last.text.write(text);
    notifyListeners();
  }

  void _onSurface(SurfaceUpdate update) {
    if (update is! SurfaceAdded || turns.isEmpty) return;
    final List<String> ids = turns.last.surfaceIds;
    if (!ids.contains(update.surfaceId)) ids.add(update.surfaceId);
    notifyListeners();
  }

  /// Asks the agent [question].
  Future<void> ask(String question) async {
    final String text = question.trim();
    if (text.isEmpty || _busy) return;
    await _run(Turn(question: text), () => _source.ask(text));
  }

  Future<void> _run(Turn turn, Future<void> Function() answer) async {
    turns.add(turn);
    _busy = true;
    _corrections = 0;
    _errors.clear();
    notifyListeners();
    try {
      await answer();
      // genui validates each surface against the catalog as it arrives, and
      // reports what fails back through onSubmit for the agent to fix. The
      // model hears about it once it has finished, within the same turn.
      if (_mode == AgentMode.live) {
        await Future<void>.delayed(errorWindow);
        while (_errors.isNotEmpty && _corrections < _maxCorrections) {
          _corrections++;
          final String errors = _errors.join('\n');
          _errors.clear();
          await _source.react(
            UserAction(name: 'error', context: const {}, interaction: errors),
          );
          await Future<void>.delayed(errorWindow);
        }
      }
    } on Object catch (error) {
      turn.error = _explain(error);
    }
    if (!turns.contains(turn)) return;
    // An action the script has no answer for leaves nothing to show.
    if (turn.surfaceIds.isEmpty &&
        turn.text.isEmpty &&
        turn.error == null &&
        turn.question == null) {
      turns.remove(turn);
    }
    _busy = false;
    notifyListeners();
  }

  void _onSubmit(ChatMessage message) {
    for (final UiInteractionPart part in message.parts.uiInteractionParts) {
      final Object? decoded = jsonDecode(part.interaction);
      if (decoded is! Map) continue;
      if (decoded['error'] case final Map<Object?, Object?> error) {
        _onError(part.interaction, error);
        continue;
      }
      final Object? action = decoded['action'];
      if (action is! Map) continue;
      final String? name = action['name'] as String?;
      final Map<String, Object?> context = <String, Object?>{
        ...?(action['context'] as Map?)?.cast<String, Object?>(),
      };
      if (name == null || _busy) continue;
      if (name == 'ask' && context['question'] is String) {
        unawaited(ask(context['question']! as String));
        continue;
      }
      final action0 = UserAction(
        name: name,
        context: context,
        interaction: part.interaction,
      );
      unawaited(
        _run(Turn(note: _describe(name)), () => _source.react(action0)),
      );
    }
  }

  /// A surface the model sent failed validation or a function failed.
  ///
  /// The broken surface is taken out of the turn, so the person sees the
  /// corrected one rather than both, and the error waits for the model to
  /// finish before it goes back. The scripted agent never sends one; if it
  /// did, the test that rendered it would already have failed.
  void _onError(String interaction, Map<Object?, Object?> error) {
    if (_mode != AgentMode.live) return;
    final Object? surfaceId = error['surfaceId'];
    if (surfaceId is String && turns.isNotEmpty) {
      turns.last.surfaceIds.remove(surfaceId);
    }
    _errors.add(interaction);
    notifyListeners();
  }

  static TurnNote _describe(String action) => switch (action) {
    'save_expense' => TurnNote.savedExpense,
    'save_goal_plan' => TurnNote.choseMonthly,
    'cancel_subscriptions' => TurnNote.askedCancel,
    'show_category' => TurnNote.askedPayments,
    _ => TurnNote.other,
  };

  /// Why the model could not answer, as far as the error says.
  static AnswerProblem _explain(Object error) {
    final String text = '$error';
    if (text.contains('API key') ||
        text.contains('PERMISSION_DENIED') ||
        text.contains('401') ||
        text.contains('403')) {
      return AnswerProblem.key;
    }
    if (text.contains('429') || text.contains('RESOURCE_EXHAUSTED')) {
      return AnswerProblem.busy;
    }
    return AnswerProblem.other;
  }

  /// Switches who answers, and starts over with the untouched account.
  void use(AgentMode mode, {String? apiKey}) {
    _mode = mode;
    if (apiKey != null) _apiKey = apiKey.trim();
    if (mode == AgentMode.live && !canGoLive) _mode = AgentMode.demo;
    restart();
  }

  /// Back to the untouched demo account and an empty conversation.
  void restart() {
    _teardown();
    turns.clear();
    _busy = false;
    _start();
    notifyListeners();
  }

  void _teardown() {
    unawaited(_submissions.cancel());
    unawaited(_surfaces.cancel());
    _source.dispose();
    recorder.dispose();
    controller.dispose();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
