import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/qr_service.dart';
import '../widgets/screen_heroes.dart';
import '../l10n/app_strings.dart';
import 'hospital_qr_scanner_screen.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final QRService _qrService = QRService();
  late Future<Map<String, String>?> _accessDataFuture;

  @override
  void initState() {
    super.initState();
    _accessDataFuture = _qrService.getPatientAccessData();
  }

  void _regenerate() {
    setState(() {
      _accessDataFuture = _qrService.getPatientAccessData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Emergency Access')),
      body: FutureBuilder<Map<String, String>?>(
        future: _accessDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text(
                  'QR sharing is disabled or access data could not be loaded.'),
            );
          }

          final url = data['url'] ??
              'https://meditrack-gr05.web.app/access.html?token=${data['qrToken']}';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MediTrackIllustrationPanel(
                  title: context.tr('ready_at_reception'),
                  subtitle: context.tr('qr_reception_subtitle'),
                  imageUrl: 'assets/images/QR_Scan.png',
                  tags: [context.tr('fast'), context.tr('private')],
                ),
                const SizedBox(height: 22),
                // QR Code card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // QR encodes the full URL
                      QrImageView(
                        data: url,
                        version: QrVersions.auto,
                        size: 220,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Show this to the doctor',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Doctor scans with any camera — no app needed',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // URL card with copy button
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFD1E9FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Or share this link:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        url,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: url));
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text('Link copied!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Link'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Fallback code
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Fallback Code',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['fallbackCode'] ?? '',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: Color(0xFF007FFF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Use if QR scanner unavailable',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                AspectRatio(
                  aspectRatio: 1,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HospitalQrScannerScreen(),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 64,
                              color: Color(0xFFF59E0B),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Hospital QR Access',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Scan the hospital QR code to check in.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: _regenerate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Access'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
