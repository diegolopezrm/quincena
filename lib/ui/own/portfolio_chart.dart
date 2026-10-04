import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../charts.dart';

/// The crypto over a range as a line, with when it starts and now under
/// it, and zero as a dashed guide when it draws what prices made. A touch
/// or a drag picks the moment nearest the finger, with a hairline and a
/// dot, until the finger lifts; a screen reader steps through the moments
/// with its adjust gestures.
class PortfolioChart extends StatelessWidget {
  const PortfolioChart({
    super.key,
    required this.values,
    required this.color,
    required this.selected,
    required this.onSelect,
    required this.semanticsLabel,
    required this.describe,
    this.zero = false,
    this.zeroLabel = '',
    this.startLabel = '',
    this.endLabel = '',
    this.progress = 1,
    this.height = 168,
  });

  final List<double> values;
  final Color color;

  /// The moment picked, or null.
  final int? selected;

  /// A moment picked, or null when the finger lifts, even if nothing was.
  final ValueChanged<int?> onSelect;

  /// What the line shows as a whole, for a screen reader.
  final String semanticsLabel;

  /// Moment [i] in words: when it was and what it was.
  final String Function(int i) describe;

  /// Whether the line starts from zero, drawn as a guide named [zeroLabel].
  final bool zero;
  final String zeroLabel;
  final String startLabel;
  final String endLabel;

  /// How much of the line is drawn in, from 0 to 1.
  final double progress;
  final double height;

  void _pick(Offset at, double width) {
    final int i = LinePainter.nearest(at.dx, width, values.length);
    if (i == selected) return;
    HapticFeedback.selectionClick();
    onSelect(i);
  }

  // Told even when nothing seems picked: a quick tap lifts before the
  // moment it picked is built here.
  void _lift() => onSelect(null);

  @override
  Widget build(BuildContext context) {
    final int last = values.length - 1;
    final int? picked = selected;
    // With nothing picked, a screen reader is on now, the line's end, and
    // steps back from it.
    final int at = picked ?? last;
    final int? next = at < last ? at + 1 : null;
    final int? previous = at > 0 ? at - 1 : null;
    final TextStyle? small = context.type.labelSmall;
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: describe(at),
      increasedValue: next == null ? null : describe(next),
      decreasedValue: previous == null ? null : describe(previous),
      onIncrease: next == null ? null : () => onSelect(next),
      onDecrease: previous == null ? null : () => onSelect(previous),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) =>
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails d) =>
                        _pick(d.localPosition, box.maxWidth),
                    onTapUp: (_) => _lift(),
                    onTapCancel: _lift,
                    onHorizontalDragStart: (DragStartDetails d) =>
                        _pick(d.localPosition, box.maxWidth),
                    onHorizontalDragUpdate: (DragUpdateDetails d) =>
                        _pick(d.localPosition, box.maxWidth),
                    onHorizontalDragEnd: (_) => _lift(),
                    onHorizontalDragCancel: _lift,
                    child: CustomPaint(
                      size: Size(box.maxWidth, height),
                      painter: LinePainter(
                        values: values,
                        color: color,
                        progress: progress,
                        selected: picked,
                        baseline: zero ? 0 : null,
                        guide: context.colors.inkFaint,
                        ring: context.colors.surface,
                      ),
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(child: Text(startLabel, style: small)),
              const SizedBox(width: 8),
              Text(endLabel, style: small),
            ],
          ),
          if (zero) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                for (var i = 0; i < 2; i++)
                  Container(
                    width: 4,
                    height: 1,
                    margin: const EdgeInsets.only(right: 4),
                    color: context.colors.inkFaint,
                  ),
                const SizedBox(width: 2),
                Expanded(child: Text(zeroLabel, style: small)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
