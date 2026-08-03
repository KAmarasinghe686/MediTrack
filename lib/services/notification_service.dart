import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(
    NotificationResponse response) async {
  // Background notification handler
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize({bool requestPermissions = true}) async {
    tzdata.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await saveNotificationToFirestore(
            title: 'Medication Reminder',
            body: response.payload ?? '',
          );
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'medication_channel',
      'Medication Reminders',
      description: 'Reminders to take your medication',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      if (requestPermissions) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    }
  }

  static Future<Map<String, dynamic>> _loadSettings() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return {};

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notification')
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // dayOfWeek: 1=Monday … 7=Sunday (DateTime constants). null = repeat daily.
  static Future<void> scheduleMedicationReminder({
    required String id,
    required String medicationName,
    required String dosage,
    required String time,
    required String notifyBefore,
    int? dayOfWeek,
  }) async {
    try {
      final settings = await _loadSettings();
      final medicationReminders = settings['medicationReminders'] ?? true;

      if (!medicationReminders) return;

      final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)');
      final match = timeRegex.firstMatch(time.trim());

      if (match == null) return;

      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      String amPm = match.group(3)!;

      if (amPm == 'PM' && hour != 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }

      int offsetMinutes = 0;
      if (notifyBefore.contains('5 min')) {
        offsetMinutes = 5;
      } else if (notifyBefore.contains('10 min')) {
        offsetMinutes = 10;
      } else if (notifyBefore.contains('15 min')) {
        offsetMinutes = 15;
      } else if (notifyBefore.contains('30 min')) {
        offsetMinutes = 30;
      } else if (notifyBefore.contains('1 hour')) {
        offsetMinutes = 60;
      } else if (notifyBefore.contains('2 hours')) {
        offsetMinutes = 120;
      }

      // DateTime.now() is always in the device's local timezone — no tz.local needed.
      final DateTime localNow = DateTime.now();
      var localScheduled = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
        hour,
        minute,
      ).subtract(Duration(minutes: offsetMinutes));

      if (dayOfWeek == null) {
        // Daily: roll forward to tomorrow if today's slot has already passed
        if (localScheduled.isBefore(localNow)) {
          localScheduled = localScheduled.add(const Duration(days: 1));
        }
      } else {
        // Weekly: advance until the correct local weekday and the time is future
        while (localScheduled.weekday != dayOfWeek ||
            localScheduled.isBefore(localNow)) {
          localScheduled = localScheduled.add(const Duration(days: 1));
        }
      }

      // Convert the local DateTime to a UTC-based TZDateTime.
      // millisecondsSinceEpoch on a local DateTime is a UTC reference, so
      // TZDateTime.from preserves the exact intended instant regardless of timezone.
      final scheduled = tz.TZDateTime.from(localScheduled, tz.UTC);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'medication_channel',
        'Medication Reminders',
        channelDescription: 'Reminders to take your medication',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails =
          DarwinNotificationDetails(
        categoryIdentifier: 'medication_category',
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final String dayKey = dayOfWeek?.toString() ?? '';
      final int notificationId = (id + dayKey + time).hashCode.abs() % 1000000;

      await _notifications.zonedSchedule(
        notificationId,
        '💊 Time to take $medicationName',
        'Take $dosage now${notifyBefore != 'On Time' ? ' ($notifyBefore)' : ''}',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: dayOfWeek == null
            ? DateTimeComponents.time
            : DateTimeComponents.dayOfWeekAndTime,
      );
      // Firestore is written only when the notification is actually received/tapped
      // (see onDidReceiveNotificationResponse in initialize()), not at schedule time.
    } catch (e) {
      // Handle error silently
    }
  }

  static Future<void> saveNotificationToFirestore({
    required String title,
    required String body,
    DateTime? scheduledTime,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'scheduledTime': scheduledTime?.toIso8601String() ?? '',
        'isRead': false,
        'type': 'medication_reminder',
      });
    } catch (e) {
      // Handle error silently
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'medication_channel',
      'Medication Reminders',
      channelDescription: 'Reminders to take your medication',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.abs() % 1000000,
      title,
      body,
      details,
    );

    await saveNotificationToFirestore(
      title: title,
      body: body,
    );
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Stub methods for fall-related notifications - to be implemented
  static Future<String?> createPendingFallPrompt() async => null;
  static Future<String?> showFallDetectedPrompt() async => null;
  static Future<void> sendFallSosAfterTimeout(String? token) async {}
  static Future<void> openFallPromptInApp(String? token) async {}
  static Future<void> promotePendingFallPromptForForeground() async {}
  static Future<bool> takeOpenNotificationListRequest() async => false;
  static Future<String?> takeOpenedFallPrompt() async => null;
  static Future<bool> respondToOpenedFallPrompt({String? token, bool sendSos = false}) async => true;
  static Stream<String?> get onOpenedFallPrompt => Stream.empty();
  static Stream<void> get onOpenNotificationList => Stream.empty();
  static Future<void> cacheMedicationSettings({
    bool medicationReminders = true,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) async {}
  static Future<void> applyMedicationReminderSettings({bool enabled = false}) async {}
  static Future<void> refreshFallAlertChannel() async {}
  static Future<bool> medicationRemindersEnabled() async => true;
  static Future<String?> medicationReminderPermissionIssue() async => null;
}
