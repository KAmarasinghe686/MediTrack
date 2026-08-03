import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool? _phoneNotificationsEnabled;
  Timer? _dueTimeRefreshTimer;

  String get _userId => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _refreshPhoneNotificationPermission();
    _dueTimeRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _dueTimeRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPhoneNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _phoneNotificationsEnabled = status.isGranted);
  }

  Future<void> _enablePhoneNotifications() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = status.isPermanentlyDenied
          ? await openAppSettings().then((_) => Permission.notification.status)
          : await Permission.notification.request();
    }

    if (!mounted) return;
    setState(() => _phoneNotificationsEnabled = status.isGranted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status.isGranted
              ? 'Phone notifications are enabled.'
              : 'Allow notifications for MediTrack in Android Settings.',
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getNotifications() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: () async {
              final batch = _db.batch();
              final snapshot = await _db
                  .collection('users')
                  .doc(_userId)
                  .collection('notifications')
                  .where('isRead', isEqualTo: false)
                  .get();
              for (var doc in snapshot.docs) {
                batch.update(doc.reference, {'isRead': true});
              }
                if (!mounted) return;
                await batch.commit();
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ All notifications marked as read'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_phoneNotificationsEnabled != true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_off_outlined, color: Colors.orange),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Phone notifications are off. Enable them for medication and safety alerts.',
                    ),
                  ),
                  TextButton(
                    onPressed: _enablePhoneNotifications,
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getNotifications(),
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error loading notifications: ${snapshot.error}'),
                ],
              ),
            );
          }
          final notifications = (snapshot.data?.docs ?? [])
              .where(_isReadyToDisplay)
              .toList();
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications here when you get reminders.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final timestamp = data['timestamp'] as Timestamp?;
              final title = data['title'] ?? 'Medication Reminder';
              final body = data['body'] ?? '';

              final colorScheme = Theme.of(context).colorScheme;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isRead
                    ? colorScheme.surface
                    : colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_active,
                    color: isRead
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onPrimaryContainer,
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(body),
                  trailing: Text(
                    timestamp != null
                        ? _formatTime(timestamp.toDate())
                        : '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    notifications[index].reference.update({'isRead': true});
                    setState(() {});
                  },
                ),
              );
            },
          );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Medication records are created when Android schedules the reminder. The
  /// UI reveals each one at its due time, matching the phone notification.
  bool _isReadyToDisplay(QueryDocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    final rawTime = data['scheduledTime'];
    if (rawTime is! String || rawTime.isEmpty) return true;
    final scheduledTime = DateTime.tryParse(rawTime)?.toLocal();
    return scheduledTime == null || !scheduledTime.isAfter(DateTime.now());
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
