import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/geofence_service.dart';
import 'emergency_screen.dart';
import 'hospital_check_in_screen.dart';
import 'how_it_works_screen.dart';
import 'medication_screen.dart';
import 'profile_screen.dart';
import 'qr_screen.dart';
import 'records_screen.dart';
import 'temporary_access_screen.dart';
import 'upload_screen.dart';
import 'notification_list_screen.dart';
import '../widgets/common_widgets.dart';
import '../theme/clinical_theme.dart';
import '../widgets/screen_heroes.dart';
import '../l10n/app_strings.dart';

Color get _kPrimary => ThemeManager.instance.isDark
    ? ClinicalPalette.darkTeal
    : ClinicalPalette.teal;

Color get _outline => ThemeManager.instance.isDark
    ? const Color(0xFF2A3545)
    : const Color(0xFFE2E8F0);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  StreamSubscription<HospitalLocation>? _geofenceSubscription;

  @override
  void initState() {
    super.initState();
    _geofenceSubscription =
        GeofenceService().onHospitalEnter.listen((hospital) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '📍 Auto checked in at ${hospital.name}! QR code ready.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QRScreen()),
      );
    });
  }

  @override
  void dispose() {
    _geofenceSubscription?.cancel();
    super.dispose();
  }

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeTab(onOpenScreen: _openScreen),
      const RecordsScreen(),
      EmergencyScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _currentIndex == 0
          ? AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              centerTitle: true,
              title: Text(
                'MediTrack',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: _kPrimary),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    ThemeManager.instance.toggle();
                  },
                  icon: Icon(
                    ThemeManager.instance.isDark 
                        ? Icons.light_mode_rounded 
                        : Icons.dark_mode_rounded,
                    color: _kPrimary,
                  ),
                  tooltip: context.tr('toggle_theme'),
                ),
                _NotificationInboxButton(
                  color: _kPrimary,
                  tooltip: context.tr('notifications'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationListScreen(),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) =>
            setState(() => _currentIndex = value),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: context.tr('home')),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: context.tr('records')),
          NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
              label: context.tr('emergency')),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: context.tr('profile')),
        ],
      ),
    );
  }
}

/// Keeps the notification inbox visible while making unread items obvious.
/// This is separate from Android's notification shade: the shade is for
/// time-sensitive phone alerts, while this is the app's notification history.
class _NotificationInboxButton extends StatefulWidget {
  const _NotificationInboxButton({
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_NotificationInboxButton> createState() =>
      _NotificationInboxButtonState();
}

class _NotificationInboxButtonState extends State<_NotificationInboxButton> {
  Timer? _dueTimeRefreshTimer;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return IconButton(
        onPressed: widget.onPressed,
        icon: Icon(Icons.notifications_none_rounded, color: widget.color),
        tooltip: widget.tooltip,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data?.docs ?? [])
            .where(_isDueNotification)
            .length;
        final label = unreadCount > 99 ? '99+' : '$unreadCount';

        return IconButton(
          onPressed: widget.onPressed,
          tooltip: widget.tooltip,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none_rounded, color: widget.color),
              if (unreadCount > 0)
                Positioned(
                  right: -8,
                  top: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).appBarTheme.backgroundColor ??
                            Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _isDueNotification(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final rawTime = doc.data()['scheduledTime'];
    if (rawTime is! String || rawTime.isEmpty) return true;
    final scheduledTime = DateTime.tryParse(rawTime)?.toLocal();
    return scheduledTime == null || !scheduledTime.isAfter(DateTime.now());
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onOpenScreen});

  final ValueChanged<Widget> onOpenScreen;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String? _profileImageUrl;
  String? _savedDisplayName;
  final GlobalKey _quickAccessKey = GlobalKey();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : const Color(0xFF1A2B4A);
    final subtitleColor = isDark ? const Color(0xFF8899AA) : const Color(0xFF627587);
    return FluidBlobBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Teammate dashboard visual: poster hero and glass cards.
                  // Navigation continues to use this project's existing screens.
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 0),
                    child: MediTrackPosterHero(
                      imageUrl: 'assets/images/dashboard_illustration (1).png',
                      title: 'How is your health today?',
                      subtitle: context.tr('health_summary'),
                      actionLabel: context.tr('quick_access'),
                      chipLabels: const ['Records', 'Check-in', 'Medication'],
                      chipActions: [
                        () => widget.onOpenScreen(const RecordsScreen()),
                        () => widget.onOpenScreen(const HospitalCheckInScreen()),
                        () => widget.onOpenScreen(const MedicationScreen()),
                      ],
                      onAction: () {
                        final target = _quickAccessKey.currentContext;
                        if (target != null) {
                          Scrollable.ensureVisible(
                            target,
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            alignment: 0.08,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 50),
                    child: _DashboardGreetingCard(
                      displayName: displayName,
                      profileImageUrl: _profileImageUrl,
                      headingColor: headingColor,
                      subtitleColor: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 22),

                  FadeSlideIn(
                    delay: const Duration(milliseconds: 75),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onOpenScreen(EmergencyScreen()),
                        icon: const Icon(Icons.warning_rounded),
                        label: const Text('Emergency Assistance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD92D3F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          widget.onOpenScreen(const HowItWorksScreen()),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('How it works'),
                    ),
                  ),

                  // Section heading
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      key: _quickAccessKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('quick_access'),
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700, color: headingColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('quick_access_subtitle'),
                          style: TextStyle(
                              color: subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    child: GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 120,
                      ),
                      children: [
                        _QuickAccessCard(
                          icon: Icons.folder_shared_rounded,
                          title: context.tr('medical_records'),
                          color: ClinicalPalette.teal,
                          onTap: () => widget.onOpenScreen(const RecordsScreen()),
                        ),
                        _QuickAccessCard(
                          icon: Icons.upload_rounded,
                          title: context.tr('upload_reports'),
                          color: const Color(0xFF10B981),
                          onTap: () => widget.onOpenScreen(const UploadScreen()),
                        ),
                        _QuickAccessCard(
                          icon: Icons.location_on_rounded,
                          title: context.tr('hospital_check_in'),
                          color: ClinicalPalette.navy,
                          onTap: () =>
                              widget.onOpenScreen(const HospitalCheckInScreen()),
                        ),
                        _QuickAccessCard(
                          icon: Icons.share_rounded,
                          title: context.tr('temporary_access'),
                          color: ClinicalPalette.teal,
                          onTap: () =>
                              widget.onOpenScreen(const TemporaryAccessScreen()),
                        ),
                        _QuickAccessCard(
                          icon: Icons.qr_code_2_rounded,
                          title: context.tr('qr_access'),
                          color: const Color(0xFFF59E0B),
                          onTap: () => widget.onOpenScreen(const QRScreen()),
                        ),
                        _QuickAccessCard(
                          icon: Icons.medication_rounded,
                          title: context.tr('medication_alerts'),
                          color: const Color(0xFF8B5CF6),
                          onTap: () =>
                              widget.onOpenScreen(const MedicationScreen()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tip card
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A2230) : const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _outline),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.12),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _kPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.lightbulb_outline_rounded,
                                color: _kPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Professional tip: Keep QR and emergency profile updated for faster hospital check-ins.',
                              style: TextStyle(
                                  color: headingColor,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardGreetingCard extends StatelessWidget {
  const _DashboardGreetingCard({
    required this.displayName,
    required this.profileImageUrl,
    required this.headingColor,
    required this.subtitleColor,
  });

  final String displayName;
  final String? profileImageUrl;
  final Color headingColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _kPrimary.withValues(alpha: 0.12), blurRadius: 28, offset: const Offset(0, 16)),
          BoxShadow(color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.90), blurRadius: 10, offset: const Offset(-4, -5)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xDD25374D) : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.95)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _kPrimary.withValues(alpha: 0.10)),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: _kPrimary.withValues(alpha: 0.12),
                backgroundImage: profileImageUrl?.isNotEmpty == true ? NetworkImage(profileImageUrl!) : null,
                child: profileImageUrl?.isNotEmpty == true ? null : Icon(Icons.person, color: _kPrimary, size: 30),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: headingColor)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(context.tr('health_status'), overflow: TextOverflow.ellipsis, style: TextStyle(color: subtitleColor, fontSize: 13))),
                  ]),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.favorite_rounded, color: _kPrimary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : const Color(0xFF1B2A38);

    return Transform.translate(
      offset: const Offset(0, -1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: isDark ? 0.22 : 0.16), blurRadius: 26, offset: const Offset(0, 14)),
            BoxShadow(color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.92), blurRadius: 8, offset: const Offset(-4, -5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xCC2C3E55) : Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.96), width: 1.1),
                  ),
                  child: Stack(children: [
                    Positioned(right: -18, top: -18, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.08)))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            gradient: LinearGradient(colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.70)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const Spacer(),
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: headingColor, height: 1.16)),
                      ],
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
