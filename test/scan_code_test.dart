// Reading the QR another phone shows, as the camera hands it over: the
// first plane of a YUV frame, brightness only, with the padding a camera
// adds at the end of each row. zxing reads it in Dart, so these frames are
// all the reader ever gets, and none of it leaves the phone.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:quincena/sync/vault.dart';
import 'package:quincena/ui/own/qr_code.dart';
import 'package:quincena/ui/own/scan_code.dart';

/// A camera frame, the way the camera plugin gives its first plane.
typedef Frame = ({Uint8List bytes, int width, int height, int stride});

/// The squares of [data]'s QR as the app draws it, with medium correction.
List<List<bool>> squares(String data) {
  final image = QrImage(
    QrCode(
      payload: QrPayload.fromString(data),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ),
  );
  return <List<bool>>[
    for (var y = 0; y < image.moduleCount; y++)
      <bool>[for (var x = 0; x < image.moduleCount; x++) image.isDark(y, x)],
  ];
}

/// A 1280 by 720 frame, as a phone's sensor sends it, with [picture] in the
/// middle and grey around it; [picture] gives the brightness of its pixel
/// at x, y, or null outside it. Light falls unevenly from left to right,
/// [noise] adds grain, and past each row's 1280 pixels are 64 bytes the
/// camera uses for itself.
Frame frame(
  int? Function(int x, int y) picture, {
  int noise = 0,
  int seed = 1,
}) {
  const width = 1280;
  const height = 720;
  const stride = 1344;
  final random = Random(seed);
  final bytes = Uint8List(stride * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < stride; x++) {
      if (x >= width) {
        bytes[y * stride + x] = x.isEven ? 0 : 255;
        continue;
      }
      final int base = picture(x, y) ?? 140;
      final int light = (x * 50 ~/ width) - 30;
      final int grain = noise == 0 ? 0 : random.nextInt(noise * 2 + 1) - noise;
      bytes[y * stride + x] = (base + light + grain).clamp(0, 255);
    }
  }
  return (bytes: bytes, width: width, height: height, stride: stride);
}

/// [data]'s QR as a phone's screen shows it, [module] pixels to a square,
/// with four squares of white around it, centred in the frame and turned
/// a quarter if [turned], as a phone held upright sends it.
int? Function(int x, int y) shown(
  String data, {
  int module = 6,
  bool turned = false,
}) {
  final List<List<bool>> qr = squares(data);
  final int side = (qr.length + 8) * module;
  final int left = (1280 - side) ~/ 2;
  final int top = (720 - side) ~/ 2;
  return (int x, int y) {
    var u = x - left;
    var v = y - top;
    if (u < 0 || v < 0 || u >= side || v >= side) return null;
    if (turned) (u, v) = (v, side - 1 - u);
    final int col = u ~/ module - 4;
    final int row = v ~/ module - 4;
    final bool dark =
        row >= 0 &&
        col >= 0 &&
        row < qr.length &&
        col < qr.length &&
        qr[row][col];
    return dark ? 30 : 225;
  };
}

String? read(Frame f) =>
    readQr(f.bytes, width: f.width, height: f.height, stride: f.stride);

void main() {
  final String code = VaultKey.generate(Random(7)).code;

  test('the other phone\'s QR is read from the frame the camera gives', () {
    expect(read(frame(shown(code))), code);
  });

  test('turned, unevenly lit and grainy, it still reads', () {
    expect(read(frame(shown(code, turned: true), noise: 18)), code);
  });

  test('held far, with small squares, it still reads', () {
    expect(read(frame(shown(code, module: 4), noise: 8)), code);
  });

  test('a frame with no QR reads as nothing', () {
    expect(read(frame((int x, int y) => null, noise: 30)), isNull);
  });

  test('a QR that is not a code reads as its text, which holds no code', () {
    const String other = 'https://diegolopezrm.github.io/quincena/';
    final String? text = read(frame(shown(other)));
    expect(text, other);
    expect(VaultKey.codeIn(text!), isNull);
  });

  testWidgets('the QR the app draws is one the camera reads', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: QrCodeView(data: code),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final ByteData? captured = await tester.runAsync<ByteData?>(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 2);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      return data;
    });
    final ByteData rgba = captured!;
    // As big on the frame as on a phone's screen held near the camera.
    const int side = 400;
    final int left = (1280 - side) ~/ 2;
    final int top = (720 - side) ~/ 2;
    final Frame f = frame((int x, int y) {
      final int u = x - left;
      final int v = y - top;
      if (u < 0 || v < 0 || u >= side || v >= side) return null;
      final int i = (v * side + u) * 4;
      final int r = rgba.getUint8(i);
      final int g = rgba.getUint8(i + 1);
      final int b = rgba.getUint8(i + 2);
      return (r * 299 + g * 587 + b * 114) ~/ 1000;
    }, noise: 6);
    expect(read(f), code);
  });
}
