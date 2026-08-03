import 'package:flutter/material.dart';

/// Poster hero used by the teammate's dashboard design.
class MediTrackPosterHero extends StatelessWidget {
  const MediTrackPosterHero({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.badge,
    this.chipLabels = const [],
    this.chipActions = const [],
    this.whiteOverlayOpacity = 1,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final String? badge;
  final List<String> chipLabels;
  final List<VoidCallback?> chipActions;
  final double whiteOverlayOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final accent = isDark ? colors.secondary : colors.primary;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2230) : Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: isDark ? .18 : .14), blurRadius: 36, offset: const Offset(0, 18))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: SizedBox(
          height: 330,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [colors.primary, colors.secondary])))),
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: .08 * whiteOverlayOpacity), Colors.white.withValues(alpha: .34 * whiteOverlayOpacity), Colors.white.withValues(alpha: .72 * whiteOverlayOpacity)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            if (badge != null && badge!.isNotEmpty)
              Positioned(top: 16, left: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .82), borderRadius: BorderRadius.circular(999)), child: Text(badge!, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800)))),
            Positioned(right: -16, top: 110, child: Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .20)))),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .82), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withValues(alpha: .72))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: const TextStyle(color: Color(0xFF1A2B4A), fontSize: 26, height: 1.05, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF66768F), fontSize: 13, height: 1.35)),
                  if (chipLabels.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: List.generate(chipLabels.length, (index) => _PosterChip(label: chipLabels[index], accent: accent, onTap: index < chipActions.length ? chipActions[index] : null))),
                  ],
                  const SizedBox(height: 16),
                  Material(color: accent, borderRadius: BorderRadius.circular(999), child: InkWell(onTap: onAction, borderRadius: BorderRadius.circular(999), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(actionLabel, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)), const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17)])))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PosterChip extends StatelessWidget {
  const _PosterChip({required this.label, required this.accent, this.onTap});
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(onTap == null ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 12, color: accent), const SizedBox(width: 4), Text(label, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800))]));
    if (onTap == null) return content;
    return Material(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(999), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: content));
  }
}

/// Illustration panel used by the teammate's Records, Profile and QR screens.
class MediTrackIllustrationPanel extends StatelessWidget {
  const MediTrackIllustrationPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.tags = const [],
    this.leading,
    this.onTap,
    this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final List<String> tags;
  final Widget? leading;
  final VoidCallback? onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final panel = Container(
      constraints: const BoxConstraints(minHeight: 178),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline.withValues(alpha: .55)),
        boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: .13), blurRadius: 26, offset: const Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          Positioned(
            right: -26,
            top: -10,
            bottom: -12,
            width: 190,
            child: Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: colors.primary.withValues(alpha: .08), child: Icon(Icons.health_and_safety_rounded, color: colors.primary, size: 52)),
            ),
          ),
          Positioned(right: 102, top: 0, bottom: 0, width: 70, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withValues(alpha: 0)])))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 142, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(height: 10)],
                Text(title, style: TextStyle(color: colors.onSurface, fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(subtitle, style: TextStyle(color: colors.onSurface.withValues(alpha: .66), fontSize: 12.5, height: 1.35)),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Wrap(spacing: 6, runSpacing: 6, children: tags.map((tag) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, color: colors.primary, size: 13), const SizedBox(width: 4), Text(tag, style: TextStyle(color: colors.primary, fontSize: 10.5, fontWeight: FontWeight.w700))])).toList()),
                ],
                if (actionLabel != null) ...[
                  const SizedBox(height: 13),
                  Row(mainAxisSize: MainAxisSize.min, children: [Text(actionLabel!, style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 15, color: colors.primary)]),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
    if (onTap == null) return panel;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(28), onTap: onTap, child: panel));
  }
}

/// A wide, photographic header shared by MediTrack's primary screens.
///
/// The image is deliberately presented as a landscape bar, never as a square
/// illustration. If an image cannot be loaded, the branded gradient and icon
/// still provide a complete header.
class MediTrackImageBanner extends StatelessWidget {
  const MediTrackImageBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
    this.showOverlay = true,
    this.overlayOpacity = 1,
    this.textBackdropOpacity = 0,
    this.whiteOverlayOpacity = 0,
    this.fullWhiteOverlayOpacity = 0,
    this.imageOffsetX = 0,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final IconData icon;
  final bool showOverlay;
  final double overlayOpacity;
  final double textBackdropOpacity;
  final double whiteOverlayOpacity;
  final double fullWhiteOverlayOpacity;
  final double imageOffsetX;

  @override
  Widget build(BuildContext context) {
    final useLightForeground = showOverlay &&
        overlayOpacity > 0.55 &&
        textBackdropOpacity == 0;
    final foregroundColor =
        useLightForeground ? Colors.white : const Color(0xFF173F5F);
    final subtitleColor = useLightForeground
        ? Colors.white
        : const Color(0xFF173F5F).withValues(alpha: 0.78);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 156,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.white),
            Transform.translate(
              offset: Offset(imageOffsetX, 0),
              child: imageUrl.startsWith('assets/')
                  ? Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF173F5F), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF173F5F), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
            ),
            if (showOverlay)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF173F5F)
                          .withValues(alpha: 0.85 * overlayOpacity),
                      const Color(0xFF14B8A6)
                          .withValues(alpha: 0.54 * overlayOpacity),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            if (textBackdropOpacity > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: textBackdropOpacity),
                      Colors.white.withValues(alpha: 0),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0, 0.78],
                  ),
                ),
              ),
            if (whiteOverlayOpacity > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(
                        alpha: 0.08 * whiteOverlayOpacity,
                      ),
                      Colors.white.withValues(
                        alpha: 0.34 * whiteOverlayOpacity,
                      ),
                      Colors.white.withValues(
                        alpha: 0.72 * whiteOverlayOpacity,
                      ),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            if (fullWhiteOverlayOpacity > 0)
              ColoredBox(
                color: Colors.white.withValues(
                  alpha: fullWhiteOverlayOpacity,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: useLightForeground
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: useLightForeground
                            ? Colors.white30
                            : const Color(0x33173F5F),
                      ),
                    ),
                    child: Icon(icon, color: foregroundColor, size: 25),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white38, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBase extends StatelessWidget {
  const _HeroBase({required this.gradient, required this.child});
  final List<Color> gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 185,
        decoration: BoxDecoration(
          color: gradient.first,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [child],
        ),
      ),
    );
  }
}

// ── 1. Medical Records Hero ───────────────────────────────────────────────────

class RecordsHero extends StatelessWidget {
  const RecordsHero({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeroBase(
      gradient: const [Color(0xFF2B5EA7), Color(0xFF5B9BD5)],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_copy_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Your Health Records',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All your documents, safe & organised',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _HeroChip(Icons.science_outlined, 'Lab Tests'),
                      _HeroChip(Icons.medication_liquid, 'Prescriptions'),
                      _HeroChip(Icons.document_scanner_outlined, 'Scans'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 2. Upload Hero ────────────────────────────────────────────────────────────

class UploadHero extends StatelessWidget {
  const UploadHero({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeroBase(
      gradient: const [Color(0xFF1565C0), Color(0xFF5B9BD5)],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    top: 10,
                    child: Container(
                      width: 55,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white54,
                        size: 28,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: Container(
                      width: 64,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.upload_rounded,
                              color: Colors.white, size: 28),
                          SizedBox(height: 4),
                          Text(
                            'UPLOAD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4FC3F7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_outlined,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Upload Medical Reports',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add documents from your camera or gallery',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _HeroChip(Icons.photo_library_outlined, 'Gallery'),
                      _HeroChip(Icons.camera_alt_outlined, 'Camera'),
                      _HeroChip(Icons.picture_as_pdf, 'PDF'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3. QR Usage Hero ─────────────────────────────────────────────────────────

class QrUsageHero extends StatelessWidget {
  const QrUsageHero({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeroBase(
      gradient: const [Color(0xFF1A3A7C), Color(0xFF3A7FC1)],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white38),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4FC3F7),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Show QR at Reception',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Instant hospital identification — no card needed',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      _StepBubble('1', 'Open QR', Color(0xFF4FC3F7)),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward_rounded,
                          size: 12, color: Colors.white38),
                      SizedBox(width: 5),
                      _StepBubble('2', 'Show Staff', Color(0xFF81C784)),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward_rounded,
                          size: 12, color: Colors.white38),
                      SizedBox(width: 5),
                      _StepBubble('3', 'Done!', Color(0xFFFFB74D)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBubble extends StatelessWidget {
  const _StepBubble(this.step, this.label, this.color);
  final String step;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── 4. Temporary Access Hero ──────────────────────────────────────────────────

class TemporaryAccessHero extends StatelessWidget {
  const TemporaryAccessHero({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeroBase(
      gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Share Records Safely',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Give doctors a time-limited secure link',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _HeroChip(Icons.timer_outlined, 'Auto-Expires'),
                      _HeroChip(Icons.visibility_outlined, 'Read-Only'),
                      _HeroChip(Icons.link_rounded, 'Shareable'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 5. Medication Hero ────────────────────────────────────────────────────────

class MedicationHero extends StatelessWidget {
  const MedicationHero({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeroBase(
      gradient: const [Color(0xFF1565C0), Color(0xFF5B9BD5)],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medication_liquid,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF7043),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF66BB6A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Never Miss a Dose',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Smart reminders for all your medications',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _HeroChip(Icons.alarm_rounded, 'Reminders'),
                      _HeroChip(Icons.calendar_today_rounded, 'Schedule'),
                      _HeroChip(Icons.trending_up_rounded, 'Streaks'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 6. OCR Scanner Hero ───────────────────────────────────────────────────────

class OcrScannerHero extends StatelessWidget {
  const OcrScannerHero({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeroBase(
      gradient: const [Color(0xFF1A2B4A), Color(0xFF2D5086)],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.document_scanner,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 2,
                          width: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4FC3F7),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 2,
                          width: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Scan Any Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'AI reads and saves your medical papers for you',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _HeroChip(Icons.camera_alt_rounded, 'Camera'),
                      _HeroChip(Icons.auto_fix_high_rounded, 'AI Extract'),
                      _HeroChip(Icons.save_alt_rounded, 'Auto Save'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
