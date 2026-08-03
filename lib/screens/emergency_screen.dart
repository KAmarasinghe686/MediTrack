import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_profile.dart';
import '../services/emergency_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/screen_heroes.dart';
import '../theme/clinical_theme.dart';
import '../l10n/app_strings.dart';
import 'emergency_profile_screen.dart';
import 'test_emergency_screen.dart';
import '../services/background_fall_monitor_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isSendingAlert = false;
  bool _backgroundFallMonitoring = false;
  bool _changingBackgroundFallMonitoring = false;

  String get _userId => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadBackgroundFallMonitoringState();
  }

  Future<void> _loadBackgroundFallMonitoringState() async {
    var enabled = await BackgroundFallMonitorService.isEnabled();
    if (enabled && !await BackgroundFallMonitorService.isRunning()) {
      enabled = await BackgroundFallMonitorService.start();
    }
    if (mounted) setState(() => _backgroundFallMonitoring = enabled);
  }

  Future<void> _setBackgroundFallMonitoring(bool enabled) async {
    if (_changingBackgroundFallMonitoring) return;
    setState(() => _changingBackgroundFallMonitoring = true);
    var active = false;
    if (enabled) {
      active = await BackgroundFallMonitorService.start();
    } else {
      await BackgroundFallMonitorService.stop();
    }
    if (!mounted) return;
    setState(() {
      _backgroundFallMonitoring = active;
      _changingBackgroundFallMonitoring = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled && !active
            ? 'Allow notifications and physical-activity access to enable fall detection.'
            : enabled
                ? 'Fall detection enabled.'
                : 'Background fall detection disabled.'),
      ),
    );
  }

  // ✅ Get medications from the medications collection
  Stream<List<Map<String, dynamic>>> _getMedications() {
    return _db
        .collection('medications')
        .doc(_userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      return (data['medications'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    });
  }

  Future<void> _handlePanicButton() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trigger Emergency Alert?'),
        content: const Text(
          'This will immediately notify your emergency contacts and hospital staff with your current location.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SEND ALERT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSendingAlert = true);
      try {
        await _emergencyService.triggerPanicAlert();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Emergency Alert Sent!'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send alert: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isSendingAlert = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('emergency')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Emergency test tools',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestEmergencyScreen()),
              ),
            ),
        ],
      ),
      body: FluidBlobBackground(
        child: SingleChildScrollView(
        child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: MediTrackImageBanner(
              title: context.tr('emergency_support'),
              subtitle: context.tr('emergency_support_subtitle'),
              imageUrl: 'assets/images/emergency_pastel_banner_cartoon.png',
              icon: Icons.emergency_rounded,
              overlayOpacity: 0.35,
            ),
          ),
          // SOS Section
          FadeSlideIn(
            delay: const Duration(milliseconds: 0),
            child: Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.05),
              child: Column(
                children: [
                  StatusPill(label: context.tr('sos_ready'), color: Colors.red),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _handlePanicButton,
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            spreadRadius: 10,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSendingAlert
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Icon(Icons.warning_rounded, color: Colors.white, size: 60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('send_sos'),
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  secondary: Icon(
                    _backgroundFallMonitoring
                        ? Icons.sensors_rounded
                        : Icons.sensors_off_rounded,
                    color: _backgroundFallMonitoring
                        ? ClinicalPalette.teal
                        : Colors.grey,
                  ),
                  title: const Text('Fall detection'),
                  subtitle: Text(
                    _backgroundFallMonitoring
                        ? 'Monitoring while MediTrack is open, backgrounded, or locked.'
                        : 'Enable to detect falls and send an SOS alert.',
                  ),
                  value: _backgroundFallMonitoring,
                  onChanged: _changingBackgroundFallMonitoring
                      ? null
                      : _setBackgroundFallMonitoring,
                ),
              ),
            ),
          ),

          // Edit Profile Button
          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmergencyProfileScreen()),
                      );
                      if (result == true && mounted) setState(() {});
                    },
                    icon: const Icon(Icons.edit),
                    label: Text(context.tr('edit_emergency_profile')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),

          // Profile Display Section
          FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: StreamBuilder<EmergencyProfile?>(
              stream: _emergencyService.getEmergencyProfile(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final profile = snapshot.data;
                if (profile == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medical_information, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No Emergency Profile',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Edit Emergency Profile" to add your medical information',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This information will be visible to doctors during emergencies.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    SectionHeader(
                      title: context.tr('critical_information'),
                      subtitle: context.tr('critical_information_subtitle'),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      context.tr('blood_type'),
                      [profile.bloodType],
                      Icons.bloodtype,
                    ),
                    _buildAllergyCards(profile),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('active_medications'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildMedicationsCard(), // ✅ Reads from medications collection
                    _buildContactsCard(profile.emergencyContacts),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Keep your emergency information up to date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<String> items, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: ClinicalPalette.teal, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          items.isEmpty ? AppStrings.text('none_reported') : items.join(', '),
          style: const TextStyle(fontSize: 15, color: ClinicalPalette.ink),
        ),
      ),
    );
  }

  Widget _buildAllergyCards(EmergencyProfile profile) {
    final allergies = profile.allergies;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.sick, color: Colors.orange, size: 28),
        title: Text(
          AppStrings.text('allergies'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          allergies.isEmpty ? AppStrings.text('none_reported') : allergies.join(', '),
          style: const TextStyle(fontSize: 15, color: ClinicalPalette.ink),
        ),
      ),
    );
  }

  // ✅ Medications card – reads from medications collection
  Widget _buildMedicationsCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getMedications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final meds = snapshot.data ?? [];
        if (meds.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.medication, color: ClinicalPalette.teal),
              title: Text(AppStrings.text('active_medications')),
              subtitle: Text(AppStrings.text('no_medications_added')),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.medication, color: ClinicalPalette.teal, size: 28),
            title: Text(
              AppStrings.text('active_medications'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text('${meds.length} medication(s)'),
            children: meds.map((med) {
              final name = med['name'] ?? '';
              final dosage = med['dosage'] ?? '';
              final times = med['times'] as List? ?? [];
              String timeStr = '';
              if (times.isNotEmpty && times.first is Map) {
                timeStr = times.map((t) {
                  if (t is Map) {
                    final hour = t['hour'] ?? 0;
                    final minute = t['minute'] ?? 0;
                    final amPm = t['amPm'] ?? 'AM';
                    return '$hour:${minute.toString().padLeft(2, '0')} $amPm';
                  }
                  return t.toString();
                }).join(', ');
              } else if (times.isNotEmpty) {
                timeStr = times.join(', ');
              }
              
              return ListTile(
                leading: const Icon(Icons.circle, color: Colors.green, size: 12),
                title: Text('$name $dosage'),
                subtitle: timeStr.isNotEmpty ? Text(timeStr) : null,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ✅ Contacts with working CALL button
  Widget _buildContactsCard(Map<String, dynamic> contacts) {
    if (contacts.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(Icons.contact_phone, color: ClinicalPalette.teal),
          title: Text(AppStrings.text('emergency_contacts')),
          subtitle: Text('No contacts added'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.contact_phone, color: ClinicalPalette.teal, size: 28),
        title: Text(
          AppStrings.text('emergency_contacts'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text('${contacts.length} contact(s)'),
        children: contacts.entries.map((entry) {
          final value = entry.value;
          String phone = '';
          String relationship = '';
          if (value is String) {
            phone = value;
            relationship = 'Unknown';
          } else if (value is Map) {
            phone = value['phone']?.toString() ?? '';
            relationship = value['relationship']?.toString() ?? 'Unknown';
          }
          return ListTile(
            leading: const Icon(Icons.person, color: ClinicalPalette.teal),
            title: Text(entry.key),
            subtitle: Text('$relationship • $phone'),
            trailing: IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () async {
                final cleanNumber = phone.replaceAll(RegExp(r'[^\d+]'), '');
                final Uri phoneUri = Uri.parse('tel:$cleanNumber');
                try {
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot make call on this device')),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
