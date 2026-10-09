import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/projection.dart';
import '../../theme/tokens.dart';

/// The money to spend over the coming days: what is sure as a solid line,
/// what includes the expected pay and anything tried out as a dashed one,
/// what is kept apart and zero as guides, and the days that take from what
/// is kept apart shaded.
/// A tap or a drag picks a day.
class ComingChart extends StatelessWidget {
  const ComingChart({
    super.key,
    required this.days,
    required this.kept,
    required this.selected,
    required this.onSelect,
    required this.semanticsLabel,
    this.payday,
    this.startLabel = '',
    this.paydayLabel = '',
    this.endLabel = '',
    this.isTight,
  });

  final List<ProjectedDay> days;

  /// What is kept apart from what can be spent: the cushion, the envelopes
  /// and the reserve, drawn as a guide.
  final int kept;

  /// Whether a day takes from what is kept apart, as the words beside the chart
  /// judge it; without it, when what is sure does.
  final bool Function(ProjectedDay day)? isTight;

  /// Marked with a dotted line, when it falls in [days].
  final DateTime? payday;
  final String startLabel;
  final String paydayLabel;
  final String endLabel;
  final int selected;
  final ValueChanged<int> onSelect;

  /// What the chart shows, for a screen reader; the days are listed under
  /// it too.
  final String semanticsLabel;

  void _pick(Offset at, double width) {
    if (days.isEmpty || width <= 0) return;
    final double step = width / math.max(1, days.length - 1);
    onSelect((at.dx / step).round().clamp(0, days.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final int paydayAt = payday == null
        ? -1
        : days.indexWhere((ProjectedDay d) => d.date == payday);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _chart(context, paydayAt),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final TextStyle? style = context.type.labelSmall;
              final double at = paydayAt < 0 || days.length < 2
                  ? -1
                  : box.maxWidth * paydayAt / (days.length - 1);
              return SizedBox(
                height: 16,
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(startLabel, style: style),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(endLabel, style: style),
                    ),
                    // The payday's label, kept clear of the two ends.
                    if (at > 48 && at < box.maxWidth - 48)
                      Positioned(
                        left: at - 40,
                        width: 80,
                        child: Text(
                          paydayLabel,
                          style: style?.copyWith(color: context.colors.brand),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, int paydayAt) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails t) => _pick(t.localPosition, box.maxWidth),
      onHorizontalDragUpdate: (DragUpdateDetails u) =>
          _pick(u.localPosition, box.maxWidth),
      child: CustomPaint(
        size: Size(box.maxWidth, 180),
        painter: _ComingPainter(
          days: days,
          kept: kept,
          isTight: isTight ?? (ProjectedDay d) => d.sure < kept,
          selected: selected,
          paydayAt: paydayAt,
          sure: context.colors.brand,
          likely: context.colors.inkSoft,
          guide: context.colors.line,
          caution: context.colors.caution,
          tight: context.colors.cautionSoft,
          ink: context.colors.ink,
        ),
      ),
    ),
  );
}

class _ComingPainter extends CustomPainter {
  _ComingPainter({
    required this.days,
    required this.kept,
    required this.isTight,
    required this.selected,
    required this.paydayAt,
    required this.sure,
    required this.likely,
    required this.guide,
    required this.caution,
    required this.tight,
    required this.ink,
  });

  final List<ProjectedDay> days;
  final int kept;
  final bool Function(ProjectedDay day) isTight;
  final int selected;
  final int paydayAt;
  final Color sure;
  final Color likely;
  final Color guide;
  final Color caution;
  final Color tight;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.length < 2) return;
    final List<int> all = <int>[
      for (final ProjectedDay d in days) ...<int>[d.sure, d.likely],
      kept,
      0,
    ];
    final double low = all.reduce(math.min).toDouble();
    final double high = all.reduce(math.max).toDouble();
    final double spread = high - low == 0 ? 1 : high - low;
    const double pad = 10;
    final double h = size.height - pad * 2;
    double x(int i) => size.width * i / (days.length - 1);
    double y(num v) => pad + h - (v - low) / spread * h;
    final double step = size.width / (days.length - 1);

    // Days that take from what is kept apart, shaded behind everything.
    final Paint shade = Paint()..color = tight;
    for (var i = 0; i < days.length; i++) {
      if (isTight(days[i])) {
        canvas.drawRect(
          Rect.fromLTWH(x(i) - step / 2, 0, step, size.height),
          shade,
        );
      }
    }

    void dashed(double at, Color color) {
      final Paint p = Paint()
        ..color = color
        ..strokeWidth = 1;
      for (double s = 0; s < size.width; s += 8) {
        canvas.drawLine(Offset(s, at), Offset(s + 4, at), p);
      }
    }

    dashed(y(0), guide);
    if (kept > 0) dashed(y(kept), caution);
    if (paydayAt >= 0) {
      final Paint p = Paint()
        ..color = sure.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (double v = 0; v < size.height; v += 6) {
        canvas.drawLine(Offset(x(paydayAt), v), Offset(x(paydayAt), v + 3), p);
      }
    }

    Path line(int Function(ProjectedDay) of) {
      final Path path = Path()..moveTo(x(0), y(of(days.first)));
      for (var i = 1; i < days.length; i++) {
        // Balances change from one day to the next: steps, not slopes.
        path
          ..lineTo(x(i), y(of(days[i - 1])))
          ..lineTo(x(i), y(of(days[i])));
      }
      return path;
    }

    final bool differs = days.any((ProjectedDay d) => d.likely != d.sure);
    if (differs) {
      final Path likelyPath = line((ProjectedDay d) => d.likely);
      final Paint dash = Paint()
        ..color = likely
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (final metric in likelyPath.computeMetrics()) {
        for (double s = 0; s < metric.length; s += 9) {
          canvas.drawPath(metric.extractPath(s, s + 5), dash);
        }
      }
    }
    canvas.drawPath(
      line((ProjectedDay d) => d.sure),
      Paint()
        ..color = sure
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );

    // The picked day.
    final int i = selected.clamp(0, days.length - 1);
    canvas.drawLine(
      Offset(x(i), 0),
      Offset(x(i), size.height),
      Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      Offset(x(i), y(days[i].sure)),
      4.5,
      Paint()..color = sure,
    );
  }

  @override
  bool shouldRepaint(_ComingPainter old) =>
      old.days != days ||
      old.selected != selected ||
      old.kept != kept ||
      old.sure != sure;
}
