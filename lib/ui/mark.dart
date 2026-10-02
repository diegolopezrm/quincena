import 'package:flutter/material.dart';

import 'brand_paths.g.dart';

const Color _emerald = Color(0xFF0B7552);
const Color _mint = Color(0xFF42D6A4);
const Color _ink = Color(0xFF111513);
const Color _paper = Color(0xFFF2F4F1);

/// A continuous Q; its two colors represent the halves of the pay cycle.
class QuincenaMark extends StatelessWidget {
  const QuincenaMark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandPainter(
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    ),
  );
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter({required this.dark, this.wordmark = false});

  final bool dark;
  final bool wordmark;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = wordmark ? quincenaLogoBounds : quincenaMarkBounds;
    final double scale = (size.width / bounds.width).clamp(
      0.0,
      size.height / bounds.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - bounds.width * scale) / 2,
      (size.height - bounds.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);

    // The same complete silhouette is exported to every SVG. Clip its color,
    // never build its tail by overlaying an unrelated shape.
    canvas.drawPath(quincenaQPath, Paint()..color = dark ? _paper : _emerald);
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(124, 0, 132, 256));
    canvas.drawPath(quincenaQPath, Paint()..color = _mint);
    canvas.restore();

    if (wordmark) {
      canvas.drawPath(
        quincenaLetteringPath,
        Paint()..color = dark ? _paper : _ink,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandPainter old) =>
      old.dark != dark || old.wordmark != wordmark;
}

/// Outlined lettering fixes the logo's optical spacing on every platform.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.textScalerOf(context).scale(28);
    return Semantics(
      label: 'Quincena',
      header: true,
      excludeSemantics: true,
      child: SizedBox(
        width: height * quincenaLogoBounds.width / quincenaLogoBounds.height,
        height: height,
        child: CustomPaint(
          painter: _BrandPainter(
            dark: Theme.of(context).brightness == Brightness.dark,
            wordmark: true,
          ),
        ),
      ),
    );
  }
}
