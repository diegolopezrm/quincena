import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One arc of a donut: its weight and its color.
class DonutSegment {
  const DonutSegment(this.value, this.color);

  final double value;
  final Color color;
}

/// A ring split by weight, with a small gap between segments.
///
/// [progress] runs from 0 to 1 and reveals the ring clockwise, so the chart
/// can be drawn in instead of appearing all at once.
class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.segments,
    required this.track,
    this.thickness = 22,
    this.progress = 1,
  });

  final List<DonutSegment> segments;
  final Color track;
  final double thickness;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2 - thickness / 2;
    final Offset center = size.center(Offset.zero);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );

    final double total = segments.fold(
      0,
      (double s, DonutSegment e) => s + e.value,
    );
    if (total <= 0) return;

    // A gap measured in radians at the ring's centre line, so it reads as the
    // same width whatever the ring's size.
    final double gap = segments.length > 1 ? 3 / radius : 0;
    final double sweepAll = math.pi * 2 * progress;
    var start = -math.pi / 2;
    for (final DonutSegment segment in segments) {
      final double sweep = segment.value / total * math.pi * 2;
      final double visible = math.min(sweep, sweepAll - (start + math.pi / 2));
      if (visible <= 0) break;
      final double drawn = math.max(0.0, visible - gap);
      if (drawn > 0) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          drawn,
          false,
          Paint()
            ..color = segment.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.butt,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.track != track;
}

/// One bar of a bar chart.
class Bar {
  const Bar({required this.value, required this.color});

  final double value;
  final Color color;
}

/// Vertical bars on a shared scale, with an optional dashed reference line.
class BarsPainter extends CustomPainter {
  BarsPainter({
    required this.bars,
    required this.max,
    required this.lineColor,
    this.reference,
    this.progress = 1,
  });

  final List<Bar> bars;
  final double max;
  final double? reference;
  final Color lineColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || max <= 0) return;
    final double slot = size.width / bars.length;
    final double width = math.min(slot * 0.56, 46);
    for (var i = 0; i < bars.length; i++) {
      final double height = bars[i].value / max * size.height * progress;
      final double left = slot * i + (slot - width) / 2;
      final RRect bar = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, size.height - height, width, height),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      );
      canvas.drawRRect(bar, Paint()..color = bars[i].color);
    }

    final double? line = reference;
    if (line != null && line > 0) {
      final double y = size.height - line / max * size.height;
      final Paint paint = Paint()
        ..color = lineColor
        ..strokeWidth = 1.4;
      const double dash = 5;
      for (double x = 0; x < size.width; x += dash * 2) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dash, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(BarsPainter old) =>
      old.progress != progress ||
      old.bars != bars ||
      old.max != max ||
      old.reference != reference ||
      old.lineColor != lineColor;
}

/// A line over time with a soft fill under it, scaled between its own
/// lowest and highest points.
///
/// [progress] draws it in from the left. The values are only shapes here:
/// the screen around the chart says what they are.
class LinePainter extends CustomPainter {
  LinePainter({
    required this.values,
    required this.color,
    this.progress = 1,
    this.strokeWidth = 2.2,
  });

  final List<double> values;
  final Color color;
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final double low = values.reduce(math.min);
    final double high = values.reduce(math.max);
    // A flat line sits in the middle rather than on the floor.
    final double spread = high - low == 0 ? 1 : high - low;
    final double pad = strokeWidth;
    double y(double v) => high - low == 0
        ? size.height / 2
        : pad + (1 - (v - low) / spread) * (size.height - pad * 2);
    final double step = size.width / (values.length - 1);
    final int shown = math.max(2, (values.length * progress).ceil());

    final Path line = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < shown; i++) {
      line.lineTo(step * i, y(values[i]));
    }
    final Path area = Path.from(line)
      ..lineTo(step * (shown - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // Where it ends now.
    if (shown == values.length) {
      final Offset end = Offset(step * (shown - 1), y(values.last));
      canvas
        ..drawCircle(end, 5, Paint()..color = color.withValues(alpha: 0.25))
        ..drawCircle(end, 2.8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(LinePainter old) =>
      old.progress != progress || old.values != values || old.color != color;
}

/// Plays a chart in once, the first time it is built.
///
/// Honors the platform's reduced-motion setting: with animations disabled the
/// chart is drawn complete on the first frame.
class DrawIn extends StatefulWidget {
  const DrawIn({super.key, required this.builder, this.duration});

  final Widget Function(BuildContext context, double progress) builder;
  final Duration? duration;

  @override
  State<DrawIn> createState() => _DrawInState();
}

class _DrawInState extends State<DrawIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration ?? const Duration(milliseconds: 900),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (BuildContext context, _) => widget.builder(context, _curve.value),
  );
}
