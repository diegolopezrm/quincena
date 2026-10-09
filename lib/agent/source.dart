import 'package:a2ui_core/a2ui_core.dart' as core;

/// Something the person did on a surface, as it goes back to the agent.
class UserAction {
  const UserAction({
    required this.name,
    required this.context,
    required this.interaction,
  });

  /// The event's name, such as `save_expense`.
  final String name;

  /// The event's context, already resolved against the data model.
  final Map<String, Object?> context;

  /// The interaction exactly as genui encoded it, which is what a model
  /// reads.
  final String interaction;
}

/// Where answers come from.
///
/// The session does not know or care whether a script or a model is behind
/// it: both answer with A2UI messages, which go through the same recorder to
/// the same controller, and render with the same catalog.
abstract interface class AnswerSource {
  /// Answers [question].
  Future<void> ask(String question);

  /// Answers something the person did on a surface.
  Future<void> react(UserAction action);

  /// The language the next answers are written in, `es` or `en`. What was
  /// already said stays as it was said.
  set language(String value);

  void dispose();
}

/// What an [AnswerSource] delivers its answer through.
class AnswerSink {
  const AnswerSink({
    required this.message,
    required this.text,
    required this.error,
  });

  /// An A2UI message for the controller.
  final void Function(core.A2uiMessage message) message;

  /// Text the agent wrote outside the surface, if any.
  final void Function(String text) text;

  /// Something the agent wrote that could not be used, such as JSON that
  /// looks like an A2UI message and is not one.
  final void Function(Object error, StackTrace stack) error;
}
