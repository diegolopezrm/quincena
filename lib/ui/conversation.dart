import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:genui/genui.dart';

import '../ai/reports.dart';
import '../format/dates.dart';
import '../session/session.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'computed_sheet.dart';
import 'icons.dart';
import 'mark.dart';
import 'report_sheet.dart';

/// Keeps a conversation's newest turn in view without taking the page from
/// someone reading.
///
/// A question, or something done on a surface, comes into view as it
/// starts, with the top of its turn at the top of the screen. Its answer
/// does too, unless the person scrolled while it was on its way: then the
/// page stays where they put it, and [behind] says there is an answer below
/// to offer them.
class ConversationFollower extends ChangeNotifier {
  ConversationFollower(this.session)
    : _seenTurns = session.turns.length,
      _wasBusy = session.busy {
    session.addListener(_follow);
  }

  final Session session;

  /// The controller of the scroll view the conversation is in.
  final ScrollController scroll = ScrollController();

  final Expando<GlobalKey> _keys = Expando<GlobalKey>();
  int _seenTurns;
  bool _wasBusy;

  /// Whether the person scrolled since the newest turn started.
  bool _scrolled = false;
  bool _disposed = false;

  /// Whether an answer arrived below where the person is reading.
  bool get behind => _behind;
  bool _behind = false;

  /// The key on [turn], to find it on the page.
  GlobalKey keyOf(Turn turn) => _keys[turn] ??= GlobalKey();

  void _follow() {
    final List<Turn> turns = session.turns;
    final bool arrived = _wasBusy && !session.busy;
    final bool started = turns.length > _seenTurns;
    _seenTurns = turns.length;
    _wasBusy = session.busy;
    if (turns.isEmpty) {
      _setBehind(false);
      return;
    }
    final Turn latest = turns.last;
    if (started) {
      _scrolled = false;
      _setBehind(false);
      _afterLayout(() => _reveal(latest));
    } else if (arrived) {
      _afterLayout(() {
        if (!_scrolled) {
          _reveal(latest);
        } else if (identical(session.turns.lastOrNull, latest) &&
            !_inView(latest)) {
          _setBehind(true);
        }
      });
    }
  }

  /// Brings [turn] to the top of the view, as the bubble or a receipt asks.
  void show(Turn turn) {
    _reveal(turn);
    if (identical(turn, session.turns.lastOrNull)) _setBehind(false);
  }

  /// Brings the newest turn to the top of the view.
  void showLatest() {
    if (session.turns.lastOrNull case final Turn latest) show(latest);
  }

  /// What the person does with the page: scrolling while an answer is on
  /// its way keeps the page where they put it, and reaching the newest turn
  /// puts the bubble away. For a [NotificationListener] over the view.
  bool onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _scrolled = true;
    }
    if (_behind && notification is ScrollUpdateNotification) {
      final Turn? latest = session.turns.lastOrNull;
      if (latest == null || _inView(latest)) _setBehind(false);
    }
    return false;
  }

  void _afterLayout(VoidCallback then) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) then();
      });

  void _reveal(Turn turn) {
    final BuildContext? target = _keys[turn]?.currentContext;
    if (target == null || !target.mounted) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: MediaQuery.maybeDisableAnimationsOf(target) ?? false
            ? Duration.zero
            : const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Whether the top of [turn] shows in the upper part of the view, or is
  /// above it, with the person reading inside the turn.
  bool _inView(Turn turn) {
    final RenderObject? box = _keys[turn]?.currentContext?.findRenderObject();
    if (box == null || !box.attached || !scroll.hasClients) return true;
    final ScrollPosition position = scroll.position;
    final double top =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset -
        position.pixels;
    return top < position.viewportDimension * 0.6;
  }

  void _setBehind(bool value) {
    if (_behind == value || _disposed) return;
    _behind = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_follow);
    scroll.dispose();
    super.dispose();
  }
}

/// The conversation's scroll view, with a bubble over its foot when an
/// answer arrived below where the person is reading.
class FollowedScroll extends StatelessWidget {
  const FollowedScroll({
    super.key,
    required this.follower,
    required this.slivers,
  });

  final ConversationFollower follower;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      NotificationListener<ScrollNotification>(
        onNotification: follower.onScroll,
        child: CustomScrollView(controller: follower.scroll, slivers: slivers),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 12,
        child: Center(
          child: ListenableBuilder(
            listenable: follower,
            builder: (BuildContext context, _) => follower.behind
                ? _SeeResult(onPressed: follower.showLatest)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ],
  );
}

/// Offers the answer that arrived below.
class _SeeResult extends StatelessWidget {
  const _SeeResult({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: context.l10n.newAnswerBelow,
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(elevation: 3),
      icon: const Icon(Glyph.arrowDown, size: 18),
      label: Text(context.l10n.seeResult),
    ),
  );
}

/// Starts a new conversation, with a short label beside the icon so it
/// does not read as undo or reload.
class NewConversationButton extends StatelessWidget {
  const NewConversationButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.newConversation,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Glyph.notePencil, size: 20),
      label: Text(context.l10n.newConversationShort),
    ),
  );
}

/// Starts a new conversation and keeps the one on screen aside for a few
/// seconds, with a way back to it. The way back goes as soon as the new
/// conversation has a question, or the person leaves the page.
void startNewConversation(BuildContext context, Session session) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AppLocalizations l = context.l10n;
  final ModalRoute<Object?>? page = ModalRoute.of(context);
  final Previous? previous = session.startOver();
  if (previous == null) return;
  messenger.hideCurrentSnackBar();
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> bar =
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.conversationCleared),
          duration: const Duration(seconds: 6),
          persist: false,
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => session.restore(previous),
          ),
        ),
      );
  var showing = true;
  void close() {
    if (!showing) return;
    showing = false;
    bar.close();
  }

  void gone() {
    if (!session.canRestore) close();
  }

  session.addListener(gone);
  // Over another page, the way back would lead nowhere.
  unawaited(page?.popped.then((_) => close()));
  unawaited(
    bar.closed.then((SnackBarClosedReason reason) {
      showing = false;
      session.removeListener(gone);
      if (reason != SnackBarClosedReason.action) session.forget(previous);
    }),
  );
}

/// The exchange so far: each question and the surface that answered it.
class Conversation extends StatelessWidget {
  const Conversation({
    super.key,
    required this.session,
    this.follower,
    this.onExplainFree,
    this.reports,
  });

  final Session session;

  /// Keeps the newest turn in view and finds each turn on the page; none
  /// where nothing scrolls to them.
  final ConversationFollower? follower;

  /// Shows how the free amount is worked out, where there is one to show.
  final VoidCallback? onExplainFree;

  /// Where reports about a model's answers go: Quincena's project unless
  /// another is given, and none where there is no Firebase app.
  final AnswerReports? reports;

  @override
  Widget build(BuildContext context) {
    final List<Turn> turns = session.turns;
    final AnswerReports? reports = this.reports ?? AnswerReports.standard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < turns.length; i++)
          KeyedSubtree(
            key: follower?.keyOf(turns[i]),
            child: _TurnView(
              turn: turns[i],
              session: session,
              waiting: session.busy && i == turns.length - 1,
              onExplainFree: onExplainFree,
              reports: reports,
              onShow: follower?.show,
            ),
          ),
      ],
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({
    required this.turn,
    required this.session,
    required this.waiting,
    this.onExplainFree,
    this.reports,
    this.onShow,
  });

  final Turn turn;
  final Session session;
  final bool waiting;
  final VoidCallback? onExplainFree;
  final AnswerReports? reports;

  /// Brings another turn into view.
  final void Function(Turn turn)? onShow;

  @override
  Widget build(BuildContext context) {
    final bool explain =
        !waiting && turn.error == null && turn.computed.isNotEmpty;
    // Only a model's finished answer can be reported.
    final AnswerReports? reports = !waiting && session.canReport(turn)
        ? this.reports
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (turn.question case final String question)
            _Question(question)
          else if (turn.note case final TurnNote note)
            // A save whose answer did not arrive saved nothing: the note
            // says what was tapped, not that it was saved.
            _Note(switch (turn.error == null ? note : TurnNote.other) {
              TurnNote.savedExpense => context.l10n.noteSavedExpense,
              TurnNote.choseMonthly => context.l10n.noteChoseMonthly,
              TurnNote.askedCancel => context.l10n.noteAskedCancel,
              TurnNote.askedPayments => context.l10n.noteAskedPayments,
              TurnNote.other => context.l10n.noteTappedAction,
            }),
          const SizedBox(height: 14),
          // A surface opens with its own headline; the name above it would
          // only take a line.
          if (turn.surfaceIds.isEmpty) ...<Widget>[
            const _Speaker(),
            const SizedBox(height: 10),
          ],
          if (turn.text.isNotEmpty) ...<Widget>[
            Text(turn.text.toString().trim(), style: context.type.bodyLarge),
            const SizedBox(height: 12),
          ],
          for (final String id in turn.surfaceIds) ...<Widget>[
            if (_receipt(id) case final Settled settled) ...<Widget>[
              _Receipt(
                settled: settled,
                onEdit: () => session.reopen(id),
                onSeeResult: onShow == null
                    ? null
                    : () => onShow!(settled.turn),
              ),
              const SizedBox(height: 6),
            ],
            _Arrive(
              key: ValueKey<String>(id),
              child: _Closed(
                closed: session.settledOf(id) != null,
                child: Surface(
                  surfaceContext: session.controller.contextFor(id),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (explain || reports != null)
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (explain)
                  TextButton.icon(
                    onPressed: () => showComputed(
                      context,
                      turn.computed,
                      onExplainFree: onExplainFree,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Glyph.info, size: 18),
                    label: Text(context.l10n.computedOnPhone),
                  ),
                if (reports != null)
                  TextButton.icon(
                    onPressed: turn.reported
                        ? null
                        : () => showReportSheet(
                            context,
                            session: session,
                            turn: turn,
                            reports: reports,
                          ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: Icon(
                      turn.reported ? Glyph.check : Glyph.flag,
                      size: 18,
                    ),
                    label: Text(
                      turn.reported
                          ? context.l10n.reportSent
                          : context.l10n.reportAnswer,
                    ),
                  ),
              ],
            ),
          if (turn.error case final AnswerProblem problem)
            _Problem(switch (problem) {
              AnswerProblem.key => context.l10n.problemKey,
              AnswerProblem.busy => context.l10n.problemBusy,
              AnswerProblem.limit => context.l10n.problemLimit,
              AnswerProblem.offline => context.l10n.problemOffline,
              AnswerProblem.other => context.l10n.problemOther,
            })
          else if (waiting)
            const _Thinking(),
        ],
      ),
    );
  }

  /// What settled the surface [id], once the answer to it arrived and is
  /// still in the conversation.
  Settled? _receipt(String id) {
    final Settled? settled = session.settledOf(id);
    if (settled == null || !session.turns.contains(settled.turn)) return null;
    final bool answering =
        session.busy && identical(settled.turn, session.turns.lastOrNull);
    return answering ? null : settled;
  }
}

/// A surface that took what it commits: it shows what was sent, and takes
/// nothing more.
class _Closed extends StatelessWidget {
  const _Closed({required this.closed, required this.child});

  final bool closed;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: closed,
    child: ExcludeFocus(
      excluding: closed,
      child: AnimatedOpacity(
        opacity: closed ? 0.5 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: child,
      ),
    ),
  );
}

/// Over a settled surface: what was committed and when, a way to change it,
/// and a way to the answer it got.
class _Receipt extends StatelessWidget {
  const _Receipt({
    required this.settled,
    required this.onEdit,
    this.onSeeResult,
  });

  final Settled settled;
  final VoidCallback onEdit;
  final VoidCallback? onSeeResult;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final String what = switch (settled.action) {
      'save_goal_plan' => l.settledPlan,
      'cancel_subscriptions' => l.settledCancelled,
      _ => l.settledExpense,
    };
    final ButtonStyle compact = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Glyph.checkCircle, size: 20, color: context.colors.positive),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l.settledAt(what, timeOfDay(settled.at)),
                  style: context.type.labelLarge,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          style: compact,
          icon: const Icon(Glyph.pencilSimple, size: 18),
          label: Text(l.edit),
        ),
        if (onSeeResult case final VoidCallback see)
          TextButton.icon(
            onPressed: see,
            style: compact,
            icon: const Icon(Glyph.arrowDown, size: 18),
            label: Text(l.seeResult),
          ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: context.colors.ink,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: context.type.bodyLarge?.copyWith(
            color: context.colors.surface,
          ),
        ),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.sunken,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: context.type.bodySmall),
    ),
  );
}

class _Speaker extends StatelessWidget {
  const _Speaker();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      children: <Widget>[
        const QuincenaMark(size: 18),
        const SizedBox(width: 8),
        Text('Quincena', style: context.type.labelMedium),
      ],
    ),
  );
}

/// Shown while the agent composes the answer.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: context.l10n.thinking,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: _pulse,
                builder: (BuildContext context, _) => Row(
                  children: <Widget>[
                    for (var i = 0; i < 3; i++)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.brand.withValues(
                            alpha: _dot(i),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(context.l10n.thinking, style: context.type.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  double _dot(int i) {
    final double t = (_pulse.value - i * 0.18) % 1;
    return 0.25 + 0.75 * (t < 0.5 ? t * 2 : (1 - t) * 2);
  }
}

/// Lifts an answer into place as it arrives.
class _Arrive extends StatefulWidget {
  const _Arrive({super.key, required this.child});

  final Widget child;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
    } else if (_in.value == 0 && !_in.isAnimating) {
      _in.forward();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curve = CurvedAnimation(
      parent: _in,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// Shown when the agent could not answer.
class _Problem extends StatelessWidget {
  const _Problem(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.negativeSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(Glyph.warningCircle, color: context.colors.negative, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
