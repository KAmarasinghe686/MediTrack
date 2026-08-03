import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
import 'emergency_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_security_screen.dart';
import 'edit_profile_screen.dart';
import 'app_preferences_screen.dart';
import '../l10n/app_strings.dart';
import '../theme/clinical_theme.dart';
import '../widgets/screen_heroes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _profileImageUrl;
  String? _savedDisplayName;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _profileImageUrl = doc.data()?['profileImageUrl'];
          _savedDisplayName = doc.data()?['displayName']?.toString();
        });
      }
    } catch (e) {
      // silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _savedDisplayName?.trim().isNotEmpty == true
        ? _savedDisplayName!
        : user?.displayName ??
        user?.email?.split('@')[0] ??
        'MediTrack User';
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: FluidBlobBackground(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Clickable Profile Header
          FadeSlideIn(
            delay: const Duration(milliseconds: 0),
            child: MediTrackIllustrationPanel(
              title: displayName,
              subtitle: email.isEmpty
                  ? 'Keep your health details ready for care.'
                  : email,
              imageUrl: 'assets/images/dashboard_illustration (1).png',
              leading: CircleAvatar(
                radius: 23,
                backgroundColor: ClinicalPalette.teal.withValues(alpha: 0.12),
                backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                    ? const Icon(Icons.person_rounded, color: ClinicalPalette.teal, size: 25)
                    : null,
              ),
              actionLabel: 'Edit profile',
              onTap: () async {
                  final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (result == true) {
                  await _loadProfileImage();
                }
              },
            ),
          ),
          const SizedBox(height: 18),

          FadeSlideIn(
            delay: const Duration(milliseconds: 50),
            child: SectionHeader(
              title: context.tr('preferences'),
              subtitle: context.tr('preferences_subtitle'),
            ),
          ),
          const SizedBox(height: 10),

          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.tune_rounded),
                title: Text(context.tr('app_preferences')),
                subtitle: Text(context.tr('app_preferences_subtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppPreferencesScreen(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(context.tr('medication_notifications')),
                subtitle: Text(context.tr('medication_notifications_subtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.lock_outline),
                title: Text(context.tr('privacy_security')),
                subtitle: Text(context.tr('privacy_security_subtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.medical_information_outlined),
                title: Text(context.tr('emergency_profile')),
                subtitle: Text(context.tr('emergency_profile_subtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          FadeSlideIn(
            delay: const Duration(milliseconds: 250),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  context.tr('sign_out'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out?'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await authService.signOut();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
