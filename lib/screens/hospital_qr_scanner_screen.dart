import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lets a patient scan a QR code provided by a hospital during check-in.
/// Only web links are opened automatically; all other QR values are displayed
/// for the user to review and scan again.
class HospitalQrScannerScreen extends StatefulWidget {
  const HospitalQrScannerScreen({super.key});

  @override
  State<HospitalQrScannerScreen> createState() =>
      _HospitalQrScannerScreenState();
}

class _HospitalQrScannerScreenState extends State<HospitalQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String value) async {
    if (_handled || value.trim().isEmpty) return;
    _handled = true;
    await _controller.stop();

    final uri = Uri.tryParse(value.trim());
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        if (mounted) Navigator.pop(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the hospital link.')),
        );
      }
    } else if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QR code detected'),
          content: SelectableText(value),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Scan again'),
            ),
          ],
        ),
      );
    }

    if (mounted) {
      _handled = false;
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Hospital QR'),
        actions: [
          IconButton(
            tooltip: 'Toggle flashlight',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flash_on_rounded),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(const ToggleLensType()),
            icon: const Icon(Icons.flip_camera_ios_rounded),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF071A2D),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 22, 24, 14),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white, size: 38),
                    SizedBox(height: 10),
                    Text(
                      'Scan the hospital QR code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Place the code inside the frame to open the hospital link.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _controller,
                              onDetect: (capture) {
                                for (final barcode in capture.barcodes) {
                                  final value = barcode.rawValue;
                                  if (value != null) {
                                    _handleCode(value);
                                    break;
                                  }
                                }
                              },
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _ScannerOverlayPainter(color: primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Text(
                  'Use the flashlight in low light.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    const corner = 34.0;
    const inset = 30.0;
    final path = Path()
      ..moveTo(inset + corner, inset)
      ..lineTo(inset, inset)
      ..lineTo(inset, inset + corner)
      ..moveTo(size.width - inset - corner, inset)
      ..lineTo(size.width - inset, inset)
      ..lineTo(size.width - inset, inset + corner)
      ..moveTo(inset, size.height - inset - corner)
      ..lineTo(inset, size.height - inset)
      ..lineTo(inset + corner, size.height - inset)
      ..moveTo(size.width - inset - corner, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset - corner);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.color != color;
}
