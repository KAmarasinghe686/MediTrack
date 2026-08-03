import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/common_widgets.dart';
import '../widgets/screen_heroes.dart';
import '../theme/clinical_theme.dart';
import '../l10n/app_strings.dart';

class TemporaryAccessScreen extends StatefulWidget {
  const TemporaryAccessScreen({super.key});

  @override
  State<TemporaryAccessScreen> createState() =>
      _TemporaryAccessScreenState();
}

class _TemporaryAccessScreenState
    extends State<TemporaryAccessScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isGenerating = false;
  int _selectedMinutes = 60;
  final GlobalKey _durationKey = GlobalKey();

  final List<Map<String, dynamic>> _durations = [
    {'label': '15 MIN', 'minutes': 15},
    {'label': '1 HOUR', 'minutes': 60},
    {'label': '6 HOURS', 'minutes': 360},
    {'label': '24 HOURS', 'minutes': 1440},
  ];

  Future<void> _generateLink() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isGenerating = true);

    try {
      final token = DateTime.now().millisecondsSinceEpoch.toString() +
          userId.substring(0, 8);
      final expiresAt = DateTime.now()
          .add(Duration(minutes: _selectedMinutes));

      await _db.collection('access_tokens').add({
        'userId': userId,
        'token': token,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'durationMinutes': _selectedMinutes,
        'isRevoked': false,
      });

      final link =
    'https://meditrack-gr05.web.app/access.html?token=$token';

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Link Generated!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Valid for $_selectedMinutes minutes. Share this link:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClinicalPalette.tealSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  link,
                  style: const TextStyle(
                      fontSize: 12, color: ClinicalPalette.navy),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Link copied to clipboard!')),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // ✅ CORRECT: Use SharePlus.instance
                SharePlus.instance.share(
  ShareParams(
    text: 'Access my MediTrack medical records: $link\n\nThis link expires in $_selectedMinutes minutes.',
  ),
);
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _revokeToken(String docId) async {
    await _db
        .collection('access_tokens')
        .doc(docId)
        .update({'isRevoked': true});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Access link revoked.')),
    );
  }

  String _timeRemaining(Timestamp expiresAt) {
    final now = DateTime.now();
    final expiry = expiresAt.toDate();
    final diff = expiry.difference(now);

    if (diff.isNegative) return 'Expired';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m remaining';
    return '${diff.inMinutes}m remaining';
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('temporary_access'))),
      body: FluidBlobBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          MediTrackImageBanner(
            imageUrl: 'assets/images/temporary_access_pastel_cartoon.png',
            title: 'Share with confidence',
            subtitle: 'Create a private link that closes automatically when time is up.',
            icon: Icons.lock_clock_rounded,
            showOverlay: false,
            fullWhiteOverlayOpacity: 0.56,
          ),
          const SizedBox(height: 24),
          SectionHeader(
            key: _durationKey,
            title: context.tr('share_access'),
            subtitle: context.tr('share_access_subtitle'),
          ),
          const SizedBox(height: 16),

          // Duration selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durations.map((d) {
              final selected = d['minutes'] == _selectedMinutes;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedMinutes = d['minutes']),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? ClinicalPalette.teal
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? ClinicalPalette.teal
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    d['label'],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateLink,
            icon: _isGenerating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: Text(_isGenerating
                ? context.tr('generating')
                : context.tr('generate_access_link')),
          ),
          const SizedBox(height: 24),

          SectionHeader(
            title: context.tr('active_links'),
            subtitle: context.tr('active_links_subtitle'),
          ),
          const SizedBox(height: 12),

          if (userId != null)
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('access_tokens')
                  .where('userId', isEqualTo: userId)
                  .where('isRevoked', isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final activeDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final expiresAt =
                      data['expiresAt'] as Timestamp?;
                  if (expiresAt == null) return false;
                  return expiresAt.toDate().isAfter(DateTime.now());
                }).toList();

                if (activeDocs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: const [
                          Icon(Icons.link_off,
                              size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No active links.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: activeDocs.map((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;
                    final expiresAt =
                        data['expiresAt'] as Timestamp;
                    final duration = data['durationMinutes'] ?? 60;

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.timer_outlined,
                          color: ClinicalPalette.teal,
                        ),
                        title: Text('$duration min access link'),
                        subtitle:
                            Text(_timeRemaining(expiresAt)),
                        trailing: TextButton(
                          onPressed: () =>
                              _revokeToken(doc.id),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          child: Text(context.tr('revoke')),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
