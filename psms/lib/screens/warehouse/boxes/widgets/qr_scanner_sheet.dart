// widgets/qr_scanner_sheet.dart
//
// Full-screen QR scanner used by "Find by QR Code". Pops the route with the
// raw scanned string once a code is detected, or with null if the user
// backs out without scanning anything. Box-payload parsing on purpose lives
// outside this widget (see box_qr_payload.dart) — this widget only knows
// how to scan, not what a box QR code looks like.
//
// Requires the `mobile_scanner` package:
//   flutter pub add mobile_scanner
//
// Android: the plugin's manifest already requests camera permission.
// iOS/macOS: add NSCameraUsageDescription to Info.plist, e.g.
//   <key>NSCameraUsageDescription</key>
//   <string>Used to scan box QR codes</string>

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _kAccent = Color(0xFF3498DB);

class QrScannerSheet extends StatefulWidget {
  const QrScannerSheet({super.key});

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // Guards against onDetect firing more than once while the route is
  // already on its way out (the camera keeps emitting frames briefly
  // during the pop transition).
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Find by QR Code',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Dimmed corners + clear scan window for a focused scan area
          _ScanWindowOverlay(),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'Point the camera at a box QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple visual frame marking where to align the QR code; purely cosmetic,
/// detection itself works anywhere in the camera preview.
class _ScanWindowOverlay extends StatelessWidget {
  const _ScanWindowOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: _kAccent, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}