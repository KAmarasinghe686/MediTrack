import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/notification_list_screen.dart';
import 'services/notification_service.dart';
import 'services/background_fall_monitor_service.dart';
import 'services/pin_security_service.dart';
import 'theme/clinical_theme.dart';
import 'l10n/app_strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize NotificationService: $e');
    }
    
    try {
      await BackgroundFallMonitorService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize BackgroundFallMonitorService: $e');
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    
    // Delay background service restoration to ensure UI is fully ready
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        await BackgroundFallMonitorService.restoreIfEnabled();
      } catch (e) {
        debugPrint('Failed to restore BackgroundFallMonitorService: $e');
      }
    });
  }

  // Load saved theme preference
  await ThemeManager.instance.init();

  runApp(const MediTrackApp());
}

class MediTrackApp extends StatefulWidget {
  const MediTrackApp({super.key});

  @override
  State<MediTrackApp> createState() => _MediTrackAppState();
}

class _MediTrackAppState extends State<MediTrackApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _fallPromptOpen = false;
  bool _openingNotificationList = false;
  bool _appIsInForeground = true;
  StreamSubscription<void>? _openedFallPromptSubscription;
  StreamSubscription<void>? _openNotificationListSubscription;
  StreamSubscription<String>? _backgroundFallPromptSubscription;
  Timer? _foregroundFallPromptTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(BackgroundFallMonitorService.setAppForeground(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_promoteFallPromptIfNeeded());
      unawaited(_openNotificationListIfNeeded());
    });
    _openedFallPromptSubscription = NotificationService.onOpenedFallPrompt
        .listen((_) => unawaited(_showOpenedFallPromptIfNeeded()));
    _openNotificationListSubscription = NotificationService.onOpenNotificationList
        .listen((_) => unawaited(_openNotificationListIfNeeded()));
    _backgroundFallPromptSubscription = BackgroundFallMonitorService.onFallPrompt
        .listen((token) async {
          await NotificationService.openFallPromptInApp(token);
          await _showOpenedFallPromptIfNeeded();
        });
    _foregroundFallPromptTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_appIsInForeground && !_fallPromptOpen) {
        unawaited(_promoteFallPromptIfNeeded());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openedFallPromptSubscription?.cancel();
    _openNotificationListSubscription?.cancel();
    _backgroundFallPromptSubscription?.cancel();
    _foregroundFallPromptTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsInForeground = state == AppLifecycleState.resumed;
    unawaited(BackgroundFallMonitorService.setAppForeground(
      _appIsInForeground,
    ));
    if (_appIsInForeground) {
      unawaited(_promoteFallPromptIfNeeded());
    }
  }

  Future<void> _promoteFallPromptIfNeeded() async {
    await NotificationService.promotePendingFallPromptForForeground();
    await _showOpenedFallPromptIfNeeded();
  }

  Future<void> _openNotificationListIfNeeded() async {
    if (_openingNotificationList ||
        !await NotificationService.takeOpenNotificationListRequest()) {
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (!mounted || navigator == null) return;
    _openingNotificationList = true;
    await navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationListScreen()),
    );
    if (mounted) _openingNotificationList = false;
  }

  Future<void> _showOpenedFallPromptIfNeeded() async {
    if (_fallPromptOpen) return;
    final token = await NotificationService.takeOpenedFallPrompt();
    final context =
        _navigatorKey.currentState?.overlay?.context ?? _navigatorKey.currentContext;
    if (!mounted || token == null || context == null) return;

    _fallPromptOpen = true;
    final timeout = Timer(const Duration(seconds: 20), () {
      final navigator = _navigatorKey.currentState;
      if (_fallPromptOpen && navigator?.canPop() == true) {
        navigator!.pop(true);
      }
    });

    final sendSos = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Possible fall detected'),
        content: const Text(
          'SOS will be sent in 20 seconds unless you confirm that you are okay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('I am okay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send SOS now'),
          ),
        ],
      ),
    );
    timeout.cancel();
    _fallPromptOpen = false;

    final handled = await NotificationService.respondToOpenedFallPrompt(
      token: token,
      sendSos: sendSos == true,
    );
    if (!mounted || !handled) return;
    ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text(sendSos == true ? 'Emergency alert sent.' : 'Fall alert cancelled.'),
        backgroundColor: sendSos == true ? Colors.red : Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return AppLanguageScope(
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'MediTrack',
            debugShowCheckedModeBanner: false,
            theme: ClinicalTheme.light(),
            darkTheme: ClinicalTheme.dark(),
            themeMode: ThemeManager.instance.mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(ThemeManager.instance.textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const AuthGate(),
          ),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSplash = true;
  bool _showPinScreen = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _showSplash = false);
      return;
    }

    // Check if PIN lock is enabled
    try {
      final cachedPinLock = await PinSecurityService.cachedPinLockEnabled();
      if (cachedPinLock == false) {
        if (mounted) {
          setState(() {
            _showSplash = false;
            _isAuthenticated = true;
          });
        }
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('privacy')
          .get();

      final pinLockEnabled = cachedPinLock ??
          (doc.exists && doc.data()?['pinLock'] == true);
      if (pinLockEnabled) {
        if (mounted) {
          setState(() {
            _showSplash = false;
            _showPinScreen = true;
          });
        }
        return;
      }
    } catch (e) {
      // Silent fail
    }

    if (mounted) {
      setState(() {
        _showSplash = false;
        _isAuthenticated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const SplashScreen();

    if (_showPinScreen) {
      return PinLockScreen(
        onSuccess: () {
          setState(() {
            _showPinScreen = false;
            _isAuthenticated = true;
          });
        },
      );
    }

    if (_isAuthenticated) {
      return const DashboardScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
