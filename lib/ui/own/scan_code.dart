import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zxing2/qrcode.dart';

import '../../l10n/l10n.dart';
import '../../sync/vault.dart';
import '../../theme/tokens.dart';
import '../icons.dart';

/// Reads a code with the camera instead, for the flows and the tests, where
/// there is none: what it gives is what the camera would have read.
@visibleForTesting
Future<String?> Function()? debugScanCode;

/// Whether this device can read a code with its camera: a phone. A browser
/// or a computer pastes it.
bool get canScanCodes =>
    debugScanCode != null ||
    (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android));

/// Opens the camera until it reads one of Quincena's codes, the QR another
/// phone shows, and gives it back; null when the person closed it first.
Future<String?> scanCode(BuildContext context) {
  if (debugScanCode case final Future<String?> Function() fake) return fake();
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (BuildContext context) => const _ScanPage(),
    ),
  );
}

/// The text of the QR code in a frame, or null when it has none.
///
/// [luminance] is the frame's brightness, one byte per pixel, [stride]
/// bytes to a row of which the first [width] are the picture: the first
/// plane of the YUV frames both phones' cameras give. zxing reads it here,
/// in Dart, so nothing about the frame leaves the phone; a reader that
/// reported its use to anyone would have to be declared to the stores.
String? readQr(
  Uint8List luminance, {
  required int width,
  required int height,
  int? stride,
}) {
  final source = _Brightness(luminance, width, height, stride ?? width);
  try {
    return QRCodeReader()
        .decode(
          BinaryBitmap(HybridBinarizer(source)),
          hints: DecodeHints()..put(DecodeHintType.tryHarder),
        )
        .text;
  } on ReaderException {
    return null;
  }
}

/// A frame's brightness as zxing reads it: the first [width] of every
/// [_stride] bytes, row after row.
class _Brightness extends LuminanceSource {
  _Brightness(Uint8List bytes, super.width, super.height, this._stride)
    : _bytes = Int8List.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

  final Int8List _bytes;
  final int _stride;

  @override
  Int8List getRow(int y, Int8List? row) {
    final Int8List out = row != null && row.length >= width
        ? row
        : Int8List(width);
    out.setRange(0, width, _bytes, y * _stride);
    return out;
  }

  @override
  Int8List getMatrix() {
    final matrix = Int8List(width * height);
    for (var y = 0; y < height; y++) {
      matrix.setRange(y * width, (y + 1) * width, _bytes, y * _stride);
    }
    return matrix;
  }
}

/// [readQr] over a frame sent to another isolate, so the preview keeps its
/// pace while the frame is read.
String? _readFrame((Uint8List, int, int, int) frame) =>
    readQr(frame.$1, width: frame.$2, height: frame.$3, stride: frame.$4);

/// Why the camera shows nothing.
enum _Trouble { permission, camera }

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> with WidgetsBindingObserver {
  CameraController? _camera;
  _Trouble? _trouble;

  /// Whether a QR that is not a code was seen, to say so.
  bool _other = false;
  bool _done = false;

  /// Whether a frame is being read: the ones that arrive meanwhile go by.
  bool _reading = false;

  /// Whether the app went to the background, perhaps to the phone's
  /// settings to give the permission, so the camera starts again on return.
  bool _away = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is let go while the app is away, not while a permission
    // prompt covers it, which makes it inactive too.
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _away = true;
        _stop();
      case AppLifecycleState.resumed when _away:
        _away = false;
        if (!_done) _start();
      default:
    }
  }

  Future<void> _start() async {
    if (_camera != null) return;
    CameraController? camera;
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _trouble = _Trouble.camera);
        return;
      }
      camera = CameraController(
        cameras.firstWhere(
          (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _camera = camera;
      await camera.initialize();
      if (!mounted || _camera != camera) {
        await camera.dispose();
        return;
      }
      await camera.startImageStream(_frame);
      setState(() => _trouble = null);
    } on CameraException catch (e) {
      if (_camera == camera) _camera = null;
      await camera?.dispose();
      if (!mounted) return;
      setState(
        () => _trouble = e.code.startsWith('CameraAccess')
            ? _Trouble.permission
            : _Trouble.camera,
      );
    }
  }

  Future<void> _stop() async {
    final CameraController? camera = _camera;
    _camera = null;
    if (mounted) setState(() {});
    await camera?.dispose();
  }

  void _frame(CameraImage image) {
    if (_reading || _done) return;
    _reading = true;
    final Plane plane = image.planes.first;
    // A copy: the camera reuses the frame's memory once this returns.
    final frame = (
      Uint8List.fromList(plane.bytes),
      image.width,
      image.height,
      plane.bytesPerRow,
    );
    compute(
      _readFrame,
      frame,
    ).then(_read, onError: (Object _) {}).whenComplete(() => _reading = false);
  }

  void _read(String? text) {
    if (text == null || _done || !mounted) return;
    final String? code = VaultKey.codeIn(text);
    if (code == null) {
      if (!_other) setState(() => _other = true);
      return;
    }
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final CameraController? camera = _camera;
    final _Trouble? trouble = _trouble;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.scanTitle),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Glyph.x),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (trouble != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  trouble == _Trouble.permission
                      ? l.scanNoPermission
                      : l.scanNoCamera,
                  textAlign: TextAlign.center,
                  style: context.type.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            )
          else if (camera != null && camera.value.isInitialized)
            _Preview(camera),
          if (trouble == null) ...<Widget>[
            // Where to hold the code, and what to do.
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: Text(
                _other ? l.scanNotACode : l.scanHint,
                textAlign: TextAlign.center,
                style: context.type.bodyLarge?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the camera sees, filling the screen without stretching: the sides
/// that do not fit are cut.
class _Preview extends StatelessWidget {
  const _Preview(this.camera);

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    // The size of the sensor's frame, which is wider than tall; a phone held
    // upright shows it turned.
    final Size size = camera.value.previewSize ?? const Size(1280, 720);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(camera),
        ),
      ),
    );
  }
}
