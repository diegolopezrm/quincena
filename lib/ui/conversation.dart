import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import '../session/session.dart';
import '../theme/tokens.dart';
import 'icons.dart';
import 'mark.dart';

/// The exchange so far: each question and the surface that answered it.
class Conversation extends StatelessWidget {
  const Conversation({super.key, required this.session, required this.latest});

  final Session session;

  /// Attached to the newest turn, so the screen can bring it into view.
  final GlobalKey latest;

  @override
  Widget build(BuildContext context) {
    final List<Turn> turns = session.turns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < turns.length; i++)
          KeyedSubtree(
            key: i == turns.length - 1 ? latest : null,
            child: _TurnView(
              turn: turns[i],
              session: session,
              waiting: session.busy && i == turns.length - 1,
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
  });

  final Turn turn;
  final Session session;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (turn.question case final String question)
            _Question(question)
          else if (turn.note case final String note)
            _Note(note),
          const SizedBox(height: 14),
          const _Speaker(),
          const SizedBox(height: 10),
          if (turn.text.isNotEmpty) ...<Widget>[
            Text(turn.text.toString().trim(), style: context.type.bodyLarge),
            const SizedBox(height: 12),
          ],
          for (final String id in turn.surfaceIds) ...<Widget>[
            _Arrive(
              key: ValueKey<String>(id),
              child: Surface(surfaceContext: session.controller.contextFor(id)),
            ),
            const SizedBox(height: 12),
          ],
          if (turn.error case final String error)
            _Problem(error)
          else if (waiting)
            const _Thinking(),
        ],
      ),
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
      label: 'Revisando tus movimientos',
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
              Text('Revisando tus movimientos', style: context.type.bodyMedium),
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
