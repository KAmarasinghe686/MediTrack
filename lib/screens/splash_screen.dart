import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF8899AA) : const Color(0xFF6B7A99);

    return Scaffold(
      body: FluidBlobBackground(
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Icon(Icons.health_and_safety, color: cs.primary, size: 72),
              ),
              const SizedBox(height: 16),
              // App Name
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    Text(
                      'MediTrack',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Slogan
              FadeSlideIn(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  'Manage your health with precision',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
              const Spacer(),
              // Loading Bar
              FadeSlideIn(
                delay: const Duration(milliseconds: 700),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: cs.outline.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
