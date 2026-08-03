import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _medicationReminders = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notification')
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _medicationReminders = data['medicationReminders'] ?? true;
          _soundEnabled = data['soundEnabled'] ?? true;
          _vibrationEnabled = data['vibrationEnabled'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Keep the last chosen settings locally so medication alarms still work
      // if Firestore is temporarily offline.
      await NotificationService.cacheMedicationSettings(
        medicationReminders: _medicationReminders,
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notification')
          .set({
        'medicationReminders': _medicationReminders,
        'soundEnabled': _soundEnabled,
        'vibrationEnabled': _vibrationEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
          });

      await NotificationService.applyMedicationReminderSettings(
        enabled: _medicationReminders,
      );
      await NotificationService.refreshFallAlertChannel();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Settings saved!'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Notification Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage how and when you receive notifications',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                Card(
                  child: SwitchListTile(
                    title: const Text('Medication Reminders'),
                    subtitle: const Text('Get reminders for your medications'),
                    value: _medicationReminders,
                    onChanged: (value) {
                      setState(() => _medicationReminders = value);
                    },
                    secondary: Icon(
                      _medicationReminders ? Icons.notifications_active : Icons.notifications_off,
                      color: _medicationReminders ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),

                Card(
                  child: SwitchListTile(
                    title: const Text('Sound'),
                    subtitle: const Text('Play sound for notifications'),
                    value: _soundEnabled,
                    onChanged: (value) {
                      setState(() => _soundEnabled = value);
                    },
                    secondary: Icon(
                      _soundEnabled ? Icons.volume_up : Icons.volume_off,
                      color: _soundEnabled ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),

                Card(
                  child: SwitchListTile(
                    title: const Text('Vibration'),
                    subtitle: const Text('Vibrate for notifications'),
                    value: _vibrationEnabled,
                    onChanged: (value) {
                      setState(() => _vibrationEnabled = value);
                    },
                    secondary: Icon(
                      _vibrationEnabled ? Icons.vibration : Icons.notifications_off,
                      color: _vibrationEnabled ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Settings are saved to your account',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
    );
  }
}
