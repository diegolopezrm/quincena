import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Quincena's mark: a coin split in two halves, one per payday.
class QuincenaMark extends StatelessWidget {
  const QuincenaMark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(context.colors.brand, context.colors.brandSoft),
      ),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.full, this.soft);

  final Color full;
  final Color soft;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double gap = size.width * 0.08;
    canvas.drawArc(
      rect.deflate(gap / 2).shift(Offset(-gap / 2, 0)),
      math.pi / 2,
      math.pi,
      true,
      Paint()..color = full,
    );
    canvas.drawArc(
      rect.deflate(gap / 2).shift(Offset(gap / 2, 0)),
      -math.pi / 2,
      math.pi,
      true,
      Paint()..color = soft,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.full != full || old.soft != soft;
}

/// The mark and the name, for the top of the screen.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Quincena',
    header: true,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const QuincenaMark(size: 26),
        const SizedBox(width: 10),
        Text(
          'quincena',
          style: context.type.headlineMedium?.copyWith(
            letterSpacing: -0.9,
            height: 1,
          ),
        ),
      ],
    ),
  );
}
