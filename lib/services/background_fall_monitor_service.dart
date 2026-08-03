import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'fall_detection_service.dart';
import 'notification_service.dart';

const _monitorChannelId = 'background_fall_monitor';
const _monitorNotificationId = 900002;
const _enabledKey = 'background_fall_monitoring_enabled';
const _foregroundKey = 'meditrack_app_is_foreground';

/// The single owner of sensor monitoring. It runs as an Android foreground
/// service, so detection can continue while the app is backgrounded or the
/// screen is locked. It cannot run while a phone is fully powered off or after
/// Android's Force stop command.
class BackgroundFallMonitorService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _initialized = false;
  static bool _appIsForeground = true;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    
    // Non-blocking initialization - fire and forget
    _performInitialization();
  }

  static Future<void> _performInitialization() async {
    try {
      // Create notification channel
      const channel = AndroidNotificationChannel(
        _monitorChannelId,
        'Fall detection monitoring',
        description: 'Shown while MediTrack fall detection is active',
        importance: Importance.low,
      );
      final notifications = FlutterLocalNotificationsPlugin();
      await notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('Failed to create notification channel: $e');
    }

    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: backgroundFallMonitorEntrypoint,
          autoStart: false,
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: _monitorChannelId,
          initialNotificationTitle: 'MediTrack fall detection active',
          initialNotificationContent: 'Monitoring device motion in the background.',
          foregroundServiceNotificationId: _monitorNotificationId,
          foregroundServiceTypes: const [AndroidForegroundType.health],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: backgroundFallMonitorEntrypoint,
        ),
      );
    } catch (e) {
      debugPrint('Failed to configure background service: $e');
    }
  }

  /// Starts monitoring only after Android notification and activity-recognition
  /// access has been granted. The persistent preference is the source of truth
  /// for the Emergency screen toggle and boot recovery.
  static Future<bool> start() async {
    await initialize();
    if (!await _requestRequiredPermissions()) return false;
    return _startPersisted();
  }

  static Future<bool> _startPersisted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, true);
    if (!await _service.isRunning()) await _service.startService();
    final running = await _service.isRunning();
    if (running) {
      _service.invoke('appLifecycle', {'foreground': _appIsForeground});
    } else {
      await preferences.setBool(_enabledKey, false);
    }
    return running;
  }

  static Future<bool> _requestRequiredPermissions() async {
    final notification = await Permission.notification.request();
    if (!notification.isGranted) return false;
    final activity = await Permission.activityRecognition.request();
    return activity.isGranted;
  }

  /// Stops both the Android service and the persisted setting. No screen-level
  /// detector is left running after this method completes.
  static Future<void> stop() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    if (await _service.isRunning()) {
      _service.invoke('stopFallMonitoring');
    }
  }

  static Future<bool> isRunning() => _service.isRunning();

  static Stream<String> get onFallPrompt => _service
      .on('fallDetected')
      .map((event) => event?['token']?.toString())
      .where((token) => token != null)
      .cast<String>();

  /// Keeps the Android service aware of whether it should create a Flutter
  /// dialog handoff (app open) or an actionable notification (app not open).
  static Future<void> setAppForeground(bool isForeground) async {
    _appIsForeground = isForeground;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_foregroundKey, isForeground);
    if (await _service.isRunning()) {
      _service.invoke('appLifecycle', {'foreground': isForeground});
    }
  }

  static Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  /// Restores only an already-enabled service. It never prompts for a
  /// permission during app startup.
  static Future<void> restoreIfEnabled() async {
    await initialize();
    if (!await isEnabled() || await _service.isRunning()) return;
    final notificationsAllowed = await Permission.notification.isGranted;
    final activityAllowed = await Permission.activityRecognition.isGranted;
    if (notificationsAllowed && activityAllowed) {
      await _startPersisted();
    }
  }
}

@pragma('vm:entry-point')
void backgroundFallMonitorEntrypoint(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.initialize(requestPermissions: false);

  final preferences = await SharedPreferences.getInstance();
  if (!(preferences.getBool(_enabledKey) ?? false)) {
    service.stopSelf();
    return;
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'MediTrack fall detection active',
      content: 'Monitoring device motion in the background.',
    );
  }

  final detector = FallDetectionService();
  await detector.startMonitoring();
  var handlingFall = false;

  service.on('appLifecycle').listen((data) async {
    await preferences.setBool(_foregroundKey, data?['foreground'] == true);
  });
  service.on('stopFallMonitoring').listen((_) async {
    await detector.dispose();
    service.stopSelf();
  });

  detector.onFallDetected.listen((_) async {
    if (handlingFall || !(preferences.getBool(_enabledKey) ?? false)) return;
    handlingFall = true;
    try {
      final appIsForeground = preferences.getBool(_foregroundKey) ?? false;
      final token = appIsForeground
          ? await NotificationService.createPendingFallPrompt()
          : await NotificationService.showFallDetectedPrompt();
      // The running app listens to this and turns the token into the dialog.
      // A backgrounded app keeps Android's actionable notification instead.
      service.invoke('fallDetected', {'token': token});
      await NotificationService.sendFallSosAfterTimeout(token);
    } finally {
      handlingFall = false;
    }
  });
}
