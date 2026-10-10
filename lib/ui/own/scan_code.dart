import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final MobileScannerController _camera = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  /// Whether a QR that is not a code was seen, to say so.
  bool _other = false;
  bool _done = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _seen(BarcodeCapture capture) {
    if (_done) return;
    for (final Barcode b in capture.barcodes) {
      final String? code = VaultKey.codeIn(b.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    if (!_other) setState(() => _other = true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
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
          MobileScanner(
            controller: _camera,
            onDetect: _seen,
            errorBuilder: (BuildContext context, MobileScannerException e) =>
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      e.errorCode == MobileScannerErrorCode.permissionDenied
                          ? l.scanNoPermission
                          : l.scanNoCamera,
                      textAlign: TextAlign.center,
                      style: context.type.bodyLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
          ),
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
      ),
    );
  }
}
