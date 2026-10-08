import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/tracing.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;

import '../agent/catalog.dart';
import '../agent/firebase_client.dart';
import '../agent/model_client.dart';
import '../agent/model_source.dart';
import '../agent/scripted_agent.dart' show ScriptedKeeper;
import '../agent/scripted_source.dart';
import '../agent/source.dart';
import '../agent/tools.dart';
import '../ai/allowance.dart';
import '../data/ledger.dart';
import '../data/seed.dart';
import '../l10n/l10n.dart';

/// Who answers: the script the demo ships with, Gemini with a key the
/// person brought, or Gemini through Quincena's own project, with no key.
enum AgentMode { demo, live, gemini }

/// What the person did on a surface, shown in place of a question.
enum TurnNote { savedExpense, choseMonthly, askedCancel, askedPayments, other }

/// Why an answer did not arrive. [limit] is the day's questions used up.
enum AnswerProblem { key, busy, limit, offline, other }

/// A computation the phone made for an answer: which tool, with what.
@immutable
class Computed {
  const Computed(this.tool, this.arguments, this.at);

  final String tool;
  final Map<String, Object?> arguments;
  final DateTime at;
}

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

  /// What the phone worked out for the answer, in order: every figure in
  /// it comes from one of these.
  final List<Computed> computed = <Computed>[];

  /// Whether the person reported the answer to DL SOFT.
  bool reported = false;
}

/// A surface whose committing action arrived: what it committed, when, and
/// the turn that answered it. It takes nothing more until it is reopened.
class Settled {
  Settled._(this.action, this.at, this.id, this.turn);

  /// The event, such as `save_expense`.
  final String action;
  final DateTime at;

  /// What names the thing committed, the same through every edit of the
  /// surface, so that saving it again corrects it.
  final String id;

  /// The turn the action started.
  final Turn turn;

  /// Whether the person reopened the surface to change what they sent.
  bool get open => _open;
  bool _open = false;

  /// What the action added to the conversation's account, to take out
  /// again when the person corrects it.
  List<Movement> _recorded = const <Movement>[];

  /// Whether a model's record_expense saved the expense while answering.
  bool _saved = false;
}

/// A conversation [Session.startOver] put aside: its turns, its surfaces,
/// its account and whoever was answering, whole, so it can come back.
class Previous {
  Previous._(
    this._ledger,
    this._controller,
    this._recorder,
    this._source,
    this._turns,
    this._settled,
  );

  final Ledger _ledger;
  final SurfaceController _controller;
  final GenUiTraceRecorder _recorder;
  final AnswerSource _source;
  final List<Turn> _turns;
  final Map<String, Settled> _settled;

  void _dispose() {
    _source.dispose();
    _recorder.dispose();
    _controller.dispose();
  }
}

/// A conversation with the agent about an account: the demo's, unless
/// [ledgerOf] gives another.
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
    this.clientFor,
    Ledger Function()? ledgerOf,
    List<dartantic.Tool> Function(Ledger ledger)? toolsFor,
    this.own = false,
    this.allowance,
    this.keeper,
    this.scripted = false,
  }) : _ledgerOf = ledgerOf ?? demoLedger,
       _toolsFor = toolsFor ?? ledgerTools {
    _mode = scripted ? AgentMode.demo : mode;
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

  /// Makes the model from the tools it may call, as they are noted on each
  /// turn; for tests of what an answer computed. Gemini otherwise.
  final ModelClient Function(List<dartantic.Tool> tools)? clientFor;

  /// The account each conversation starts from: a fresh demo one by
  /// default, or the person's own as it is now.
  final Ledger Function() _ledgerOf;

  /// What a model can ask the account.
  final List<dartantic.Tool> Function(Ledger ledger) _toolsFor;

  /// Whether the account is the person's own, which changes what the model
  /// is told.
  final bool own;

  /// The day's questions to Gemini through Quincena; null leaves them
  /// uncounted.
  final Allowance? allowance;

  /// Where the script keeps what the person saves, when the account lives
  /// outside the conversation, as the example account's database does. The
  /// conversation then reads the account as [ledgerOf] gives it at each
  /// answer, and starting over leaves what was saved where it is.
  final ScriptedKeeper? keeper;

  /// Whether only the script answers, as in the example account: no one
  /// else can be chosen, nothing goes out to a model and no question of the
  /// day is spent.
  final bool scripted;

  late AgentMode _mode;
  AgentMode get mode => _mode;

  /// Whether the person can choose who answers.
  bool get choosable => !scripted;
  String? _apiKey;

  /// Whether a model can answer: there is a key, or a client was given.
  bool get canGoLive => client != null || (_apiKey?.isNotEmpty ?? false);

  /// The account this conversation is about: as it was when it started,
  /// with what it saved, or, with a [keeper], as it is now.
  Ledger get ledger => keeper == null ? _ledger : _ledgerOf();
  late Ledger _ledger;
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

  /// The events that commit something. The first to arrive from a surface
  /// settles it, and it takes no more: two taps save one expense.
  static const Set<String> commits = <String>{
    'save_expense',
    'save_goal_plan',
    'cancel_subscriptions',
  };

  static const Uuid _ids = Uuid();

  /// The surfaces a committing action settled, by id.
  Map<String, Settled> _settled = <String, Settled>{};

  /// What settled the surface [surfaceId], or null while it takes actions.
  Settled? settledOf(String surfaceId) {
    final Settled? settled = _settled[surfaceId];
    return settled == null || settled.open ? null : settled;
  }

  /// Opens a settled surface again for the person to change what they
  /// sent. Sending it again replaces what it committed.
  void reopen(String surfaceId) {
    final Settled? settled = _settled[surfaceId];
    if (settled == null || settled.open) return;
    settled._open = true;
    notifyListeners();
  }

  /// The expense form whose save [turn] is answering, if it is one.
  Settled? _savingIn(Turn? turn) {
    for (final Settled settled in _settled.values) {
      if (identical(settled.turn, turn) && settled.action == 'save_expense') {
        return settled;
      }
    }
    return null;
  }

  /// The conversation [startOver] put aside, until the person asks
  /// something in the new one.
  Previous? _previous;

  /// Whether there is a conversation to [restore].
  bool get canRestore => _previous != null;

  /// Errors genui reported about the current answer, waiting to go back to
  /// the model once it has finished writing.
  final List<String> _errors = <String>[];

  /// How many times the model has been asked to fix one answer. A model that
  /// cannot fix its surface in two tries will not in a third.
  int _corrections = 0;
  static const int _maxCorrections = 2;

  static const String _noSurface =
      'That answer created no surface, so the person saw only its text. '
      'Answer the same message again by creating one new surface, as the '
      'instructions say.';

  void _start() {
    final Ledger ledger = _ledger = _ledgerOf();
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
        keeper == null ? () => ledger : _ledgerOf,
        sink: sink,
        thinking: thinking,
        language: _language,
        keeper: _kept(keeper),
      ),
      AgentMode.live => ModelSource(
        client:
            client ??
            (clientFor ??
                (List<dartantic.Tool> tools) => GeminiClient(
                  apiKey: _apiKey!,
                  tools: tools,
                ))(_traced(_toolsFor(ledger))),
        ledger: ledger,
        sink: sink,
        language: _language,
        own: own,
      ),
      AgentMode.gemini => ModelSource(
        client:
            client ??
            (clientFor ??
                (List<dartantic.Tool> tools) => FirebaseGeminiClient(
                  tools: tools,
                ))(_traced(_toolsFor(ledger))),
        ledger: ledger,
        sink: sink,
        language: _language,
        own: own,
      ),
    };
    _listen();
  }

  void _listen() {
    _submissions = controller.onSubmit.listen(_onSubmit);
    _surfaces = controller.surfaceUpdates.listen(_onSurface);
  }

  void _onMessage(core.A2uiMessage message) {
    recorder.handleMessage(message);
    if (_mode == AgentMode.demo) return;
    // Valid to genui, and still wrong: the person would read the call itself.
    if (writtenOutCall(message) case final String where) {
      final String surfaceId =
          (message as core.UpdateComponentsMessage).surfaceId;
      if (turns.isNotEmpty) turns.last.surfaceIds.remove(surfaceId);
      _errors.add(
        'Surface "$surfaceId" shows a function call as text, in $where. '
        'Text cannot make calls: an amount on its own is {"call": "money", '
        '"args": {"amount": 120000}}, and inside a sentence it goes through '
        'formatString, {"call": "formatString", "args": {"value": "You have '
        '\${money(amount: 120000)} left"}}. Answer the same message again by '
        'creating one new surface.',
      );
      notifyListeners();
    }
  }

  /// Where [message] writes a function call out as text instead of making
  /// it, as a model may when it puts an amount inside a sentence: "Tienes
  /// {call: money, args: {amount: 2283966}}". genui shows such text as it
  /// is. Null when there is none.
  @visibleForTesting
  static String? writtenOutCall(core.A2uiMessage message) {
    if (message is! core.UpdateComponentsMessage) return null;
    for (final Map<String, dynamic> component in message.components) {
      for (final MapEntry<String, dynamic> property in component.entries) {
        if (property.key == 'id' || property.key == 'component') continue;
        if (_writtenOut(property.value) case final String text) {
          return '${component['id']}.${property.key}: "$text"';
        }
      }
    }
    return null;
  }

  static final RegExp _textCall = RegExp(r'\{\s*"?call"?\s*:');
  static final RegExp _interpolation = RegExp(r'\$\{');

  /// Text holding a call, or holding `${...}` anywhere but in formatString,
  /// the one function that reads it.
  static String? _writtenOut(Object? value, {bool formatted = false}) {
    switch (value) {
      case final String text:
        final bool wrong =
            _textCall.hasMatch(text) ||
            (!formatted && _interpolation.hasMatch(text));
        return wrong ? text : null;
      case final Map<Object?, Object?> map:
        final bool format = formatted || map['call'] == 'formatString';
        for (final Object? inner in map.values) {
          if (_writtenOut(inner, formatted: format) case final String text) {
            return text;
          }
        }
        return null;
      case final List<Object?> list:
        for (final Object? inner in list) {
          if (_writtenOut(inner, formatted: formatted) case final String text) {
            return text;
          }
        }
        return null;
      default:
        return null;
    }
  }

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

  /// [tools] as the model calls them: each call is noted on the turn being
  /// answered, so the answer can say where its figures come from.
  List<dartantic.Tool> _traced(List<dartantic.Tool> tools) => <dartantic.Tool>[
    for (final dartantic.Tool t in tools)
      dartantic.Tool<Map<String, dynamic>>(
        name: t.name,
        description: t.description,
        inputSchema: t.inputSchema,
        onCall: (Map<String, dynamic> args) async {
          // An expense saved from a form goes with the form's id, whatever
          // the model passed, so saving the form again corrects it.
          final Settled? saving = t.name == 'record_expense'
              ? _savingIn(turns.lastOrNull)
              : null;
          final Map<String, dynamic> call = saving == null
              ? args
              : <String, dynamic>{...args, 'id': saving.id};
          if (turns.isNotEmpty) {
            turns.last.computed.add(
              Computed(t.name, Map<String, Object?>.of(call), DateTime.now()),
            );
            notifyListeners();
          }
          final Object? result = await t.call(call);
          if (saving != null && result is Map && result['recorded'] == true) {
            saving._saved = true;
          }
          return result;
        },
      ),
  ];

  /// [keeper] as the script calls it: an expense saved from a form is
  /// noted on that form, as a model's record_expense is, so the form
  /// settles and saving it again corrects it.
  ScriptedKeeper? _kept(ScriptedKeeper? keeper) => keeper == null
      ? null
      : ScriptedKeeper(
          expense: (ExpenseToRecord expense) async {
            final Settled? saving = _savingIn(turns.lastOrNull);
            await keeper.expense(expense);
            saving?._saved = true;
          },
          goalMonthly: keeper.goalMonthly,
        );

  /// Asks the agent [question].
  Future<void> ask(String question) async {
    final String text = question.trim();
    if (text.isEmpty || _busy) return;
    await _run(Turn(question: text), () => _source.ask(text));
  }

  Future<void> _run(Turn turn, Future<void> Function() answer) async {
    // Once the new conversation has a question, the old one stays gone.
    _forgetPrevious();
    turns.add(turn);
    _busy = true;
    _corrections = 0;
    _errors.clear();
    notifyListeners();
    // Through Quincena's project, each question counts against the day's.
    final Allowance? day = _mode == AgentMode.gemini ? allowance : null;
    if (day != null && !await day.take()) {
      turn.error = AnswerProblem.limit;
      _busy = false;
      notifyListeners();
      return;
    }
    try {
      await answer();
      // genui announces a new surface a moment after it takes it in, and a
      // turn is only known to have an answer once the announcement is in.
      await Future<void>.delayed(Duration.zero);
      // genui validates each surface against the catalog as it arrives, and
      // reports what fails back through onSubmit for the agent to fix. The
      // model hears about it once it has finished, within the same turn.
      if (_mode != AgentMode.demo) {
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
        // An answer in prose alone shows nothing of what the app is for; the
        // model is reminded once, the way a broken surface is reported.
        if (turn.surfaceIds.isEmpty && _corrections < _maxCorrections) {
          _corrections++;
          await _source.react(
            const UserAction(
              name: 'error',
              context: <String, Object?>{},
              interaction: _noSurface,
            ),
          );
          await Future<void>.delayed(errorWindow);
        }
      }
    } on Object catch (error) {
      // An error can quote what was asked; a release build keeps it out of
      // the device's logs.
      if (kDebugMode) debugPrint('The answer did not arrive: $error');
      turn.error = _explain(error, _mode);
      // Only a question that got its answer counts against the day.
      await day?.giveBack();
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
      if (commits.contains(name) && action['surfaceId'] is String) {
        _commit(action['surfaceId']! as String, name, context, decoded);
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

  /// Sends a committing action from [surfaceId], once.
  ///
  /// An expense carries an id that stays with its form, so a model that
  /// saves it again after an edit corrects it. The id is the session's own:
  /// one a form brings could be on another form too, and saving that one
  /// would overwrite this expense. Whoever answers, what the first save
  /// added to this account comes out before the correction is counted.
  /// When nothing was committed, the surface opens again.
  void _commit(
    String surfaceId,
    String name,
    Map<String, Object?> context,
    Map<Object?, Object?> interaction,
  ) {
    final Map<String, Settled> settled = _settled;
    final Settled? earlier = settled[surfaceId];
    if (earlier != null && !earlier.open) return;
    final String id = earlier?.id ?? _ids.v4();
    if (name == 'save_expense') {
      context['id'] = id;
      (interaction['action']! as Map<Object?, Object?>)['context'] = context;
    }
    final Turn turn = Turn(note: _describe(name));
    final Settled now = settled[surfaceId] = Settled._(
      name,
      DateTime.now(),
      id,
      turn,
    );
    final Ledger account = ledger;
    final List<Movement> taken = <Movement>[
      for (final Movement m in earlier?._recorded ?? const <Movement>[])
        if (account.remove(m)) m,
    ];
    final Set<Movement> before = Set<Movement>.identity()
      ..addAll(account.movements);
    final UserAction action = UserAction(
      name: name,
      context: context,
      interaction: jsonEncode(interaction),
    );
    unawaited(() async {
      await _run(turn, () => _source.react(action));
      final List<Movement> added = <Movement>[
        for (final Movement m in account.movements)
          if (!before.contains(m)) m,
      ];
      final bool done =
          turn.error == null &&
          turns.contains(turn) &&
          (name != 'save_expense' || added.isNotEmpty || now._saved);
      if (done) {
        now._recorded = added;
        return;
      }
      taken.forEach(account.record);
      if (earlier == null) {
        settled.remove(surfaceId);
      } else {
        settled[surfaceId] = earlier;
      }
      notifyListeners();
    }());
  }

  /// A surface the model sent failed validation or a function failed.
  ///
  /// The broken surface is taken out of the turn, so the person sees the
  /// corrected one rather than both, and the error waits for the model to
  /// finish before it goes back. The scripted agent never sends one; if it
  /// did, the test that rendered it would already have failed.
  void _onError(String interaction, Map<Object?, Object?> error) {
    if (_mode == AgentMode.demo) return;
    final Object? surfaceId = error['surfaceId'];
    if (surfaceId is String && turns.isNotEmpty) {
      turns.last.surfaceIds.remove(surfaceId);
    }
    _errors.add(interaction);
    notifyListeners();
  }

  /// Whether [turn]'s answer can be reported: one a model wrote, finished,
  /// with something to show.
  bool canReport(Turn turn) =>
      _mode != AgentMode.demo &&
      turn.error == null &&
      !(_busy && identical(turn, turns.lastOrNull)) &&
      (turn.surfaceIds.isNotEmpty || turn.text.isNotEmpty);

  /// [turn]'s answer as the model sent it, for a report: its text, the
  /// messages that built its surfaces, and each surface's data as it last
  /// stood. What the person types into a form stays out, as it does from a
  /// recording.
  String answerOf(Turn turn) {
    final Set<String> ids = turn.surfaceIds.toSet();
    final List<Object?> messages = <Object?>[];
    final Map<String, Object?> data = <String, Object?>{};
    for (final GenUiTraceStep step in recorder.build().steps) {
      switch (step) {
        case GenUiMessageStep(:final message)
            when ids.contains(_surfaceOf(message)):
          messages.add(message);
        case GenUiDataStep(:final surfaceId, data: final Object? value)
            when ids.contains(surfaceId):
          data[surfaceId] = value;
        default:
      }
    }
    return jsonEncode(<String, Object?>{
      'text': turn.text.toString().trim(),
      'messages': messages,
      'data': data,
    });
  }

  /// The surface an A2UI message is about, whichever kind it is.
  static String? _surfaceOf(Map<String, Object?> message) {
    for (final Object? body in message.values) {
      if (body is Map && body['surfaceId'] is String) {
        return body['surfaceId'] as String;
      }
    }
    return null;
  }

  /// Notes that [turn]'s answer was reported, so it is not sent twice.
  void markReported(Turn turn) {
    turn.reported = true;
    notifyListeners();
  }

  static TurnNote _describe(String action) => switch (action) {
    'save_expense' => TurnNote.savedExpense,
    'save_goal_plan' => TurnNote.choseMonthly,
    'cancel_subscriptions' => TurnNote.askedCancel,
    'show_category' => TurnNote.askedPayments,
    _ => TurnNote.other,
  };

  /// Why the model could not answer, as far as the error says. Without a
  /// key of the person's, a refusal is the project's, not theirs to fix.
  static AnswerProblem _explain(Object error, AgentMode mode) {
    final String text = '$error';
    if (offline(text)) return AnswerProblem.offline;
    if (text.contains('429') ||
        text.contains('RESOURCE_EXHAUSTED') ||
        text.contains('quota') ||
        FirebaseGeminiClient.isBusy(error)) {
      return AnswerProblem.busy;
    }
    if (mode == AgentMode.gemini) return AnswerProblem.other;
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

  /// Whether an error says the phone could not reach the network at all,
  /// as `dart:io`, `package:http` and the browser each word it.
  static bool offline(String error) => const <String>[
    'SocketException',
    'Failed host lookup',
    'Network is unreachable',
    'No address associated with hostname',
    'Connection refused',
    'Connection reset',
    'Connection closed before full header',
    'XMLHttpRequest error',
    'Failed to fetch',
    'NSURLErrorDomain',
    'The Internet connection appears to be offline',
    'network-request-failed',
  ].any(error.contains);

  /// Switches who answers, and starts over with the untouched account.
  /// Where only the script answers, it stays answering.
  void use(AgentMode mode, {String? apiKey}) {
    _mode = scripted ? AgentMode.demo : mode;
    if (apiKey != null) _apiKey = apiKey.trim();
    if (mode == AgentMode.live && !canGoLive) _mode = AgentMode.demo;
    restart();
  }

  /// Back to the untouched demo account and an empty conversation.
  void restart() {
    _forgetPrevious();
    _teardown();
    turns.clear();
    _settled = <String, Settled>{};
    _busy = false;
    _start();
    notifyListeners();
  }

  /// Starts an empty conversation over the untouched account, and puts this
  /// one aside for [restore] to bring back. Null when there was nothing to
  /// keep, or an answer was still on its way, which goes with the rest.
  Previous? startOver() {
    if (turns.isEmpty || _busy) {
      restart();
      return null;
    }
    _forgetPrevious();
    _quiet();
    final Previous previous = _previous = Previous._(
      _ledger,
      controller,
      recorder,
      _source,
      List<Turn>.of(turns),
      _settled,
    );
    turns.clear();
    _settled = <String, Settled>{};
    _start();
    notifyListeners();
    return previous;
  }

  /// Brings back the conversation [startOver] put aside, in place of the
  /// new one. Nothing once the person asked something in the new one.
  void restore(Previous previous) {
    if (!identical(previous, _previous)) return;
    _previous = null;
    _teardown();
    _ledger = previous._ledger;
    controller = previous._controller;
    recorder = previous._recorder;
    _source = previous._source;
    turns
      ..clear()
      ..addAll(previous._turns);
    _settled = previous._settled;
    _busy = false;
    _listen();
    notifyListeners();
  }

  /// Lets go of [previous] for good, once the offer to bring it back ends.
  void forget(Previous previous) {
    if (identical(previous, _previous)) _forgetPrevious();
  }

  void _forgetPrevious() {
    final Previous? previous = _previous;
    _previous = null;
    previous?._dispose();
  }

  void _quiet() {
    unawaited(_submissions.cancel());
    unawaited(_surfaces.cancel());
  }

  void _teardown() {
    _quiet();
    _source.dispose();
    recorder.dispose();
    controller.dispose();
  }

  @override
  void dispose() {
    _forgetPrevious();
    _teardown();
    super.dispose();
  }
}
