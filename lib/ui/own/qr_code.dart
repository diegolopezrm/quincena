import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// [data] as a QR code another phone's camera reads: dark squares on white
/// with the quiet border the readers need, whatever the theme, since a QR
/// in light on dark is one many cameras miss.
class QrCodeView extends StatelessWidget {
  const QrCodeView({super.key, required this.data, this.size = 200});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    color: Colors.white,
    padding: EdgeInsets.all(size / 14),
    child: CustomPaint(
      painter: _QrPainter(
        QrImage(
          QrCode(
            payload: QrPayload.fromString(data),
            errorCorrectLevel: QrErrorCorrectLevel.medium,
          ),
        ),
      ),
    ),
  );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final int count = image.moduleCount;
    final double side = size.shortestSide / count;
    final Paint dark = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var x = 0; x < count; x++) {
      for (var y = 0; y < count; y++) {
        if (image.isDark(y, x)) {
          // A hair wider than its square, so no seam shows between two.
          canvas.drawRect(
            Rect.fromLTWH(x * side, y * side, side + 0.5, side + 0.5),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
