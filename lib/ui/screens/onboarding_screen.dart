import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/platform_utils.dart';
import '../../services/core/android_storage_service.dart';
import '../components/aero_button.dart';
import '../components/aero_chip.dart';
import '../components/aero_density.dart';

/// Aero-styled onboarding flow for AeroTube.
///
/// Features (redesign_spec 7.6):
/// - 3 pages max with full-bleed black background.
/// - Large icon centered in a violet glow circle.
/// - Headline + one-line description, animated dots indicator, Skip top-right.
/// - Last page requests notification and storage permissions with clear reasons.
/// - Built strictly with Aero design tokens (AeroColors, AeroText, AeroRadius, AeroSpace).
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _requestingPermission = false;
  bool _storageGranted = false;
  bool _notificationGranted = false;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      icon: Symbols.play_circle_rounded,
      title: 'Welcome to AeroTube',
      description:
          'Download videos and audio in original quality, fast and ad-free.',
    ),
    _OnboardingPageData(
      icon: Symbols.tune_rounded,
      title: 'Formats & Quality',
      description:
          'Save 4K 60fps video, pure MP3 audio, playlists, and subtitles.',
    ),
    _OnboardingPageData(
      icon: Symbols.verified_user_rounded,
      title: 'Permissions & Setup',
      description:
          'Grant storage and notification access to save and track your downloads.',
      isPermissionPage: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (!PlatformUtils.isAndroid) {
      if (mounted) {
        setState(() {
          _storageGranted = true;
          _notificationGranted = true;
        });
      }
      return;
    }

    try {
      final storageService = AndroidStorageService();
      final hasStorage = await storageService.hasStoragePermission();
      final notificationStatus = await Permission.notification.status;
      if (mounted) {
        setState(() {
          _storageGranted = hasStorage;
          _notificationGranted = notificationStatus.isGranted;
        });
      }
    } catch (_) {
      // Fallback silently if platform checks fail
    }
  }

  Future<void> _requestStorage() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    try {
      final storageService = AndroidStorageService();
      await storageService.requestStoragePermission();
    } catch (_) {
      // Denied is fine — app falls back to app-specific storage + MediaStore
    }
    await _checkPermissions();
    if (mounted) {
      setState(() => _requestingPermission = false);
    }
  }

  Future<void> _requestNotifications() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    try {
      if (PlatformUtils.isAndroid) {
        await Permission.notification.request();
      }
    } catch (_) {}
    await _checkPermissions();
    if (mounted) {
      setState(() => _requestingPermission = false);
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);

    try {
      if (PlatformUtils.isAndroid) {
        final storageService = AndroidStorageService();
        final hasStorage = await storageService.hasStoragePermission();
        if (!hasStorage) {
          await storageService.requestStoragePermission();
        }
        try {
          await Permission.notification.request();
        } catch (_) {}
      }
    } catch (_) {
      // Permission denied is okay - app still works with limited storage
    } finally {
      if (mounted) {
        setState(() => _requestingPermission = false);
      }
    }

    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar: Skip button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AeroSpace.lg,
                  vertical: AeroSpace.xs,
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: AeroButton(
                    variant: AeroButtonVariant.ghost,
                    density: AeroDensity.compact,
                    text: 'Skip',
                    tooltip: 'Skip onboarding',
                    onPressed: widget.onComplete,
                  ),
                ),
              ),

              // Paged Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    // M18: if user navigates to the permissions page, refresh statuses
                    if (_pages[index].isPermissionPage) {
                      _checkPermissions();
                    }
                  },
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], colors);
                  },
                ),
              ),

              // Page indicators (dots)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  final duration = appMotionDuration(
                    context,
                    const Duration(milliseconds: 250),
                  );
                  return AnimatedContainer(
                    duration: duration,
                    curve: Curves.linear,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? colors.primary : colors.outlineStrong,
                      borderRadius: AeroRadius.fullBorderRadius,
                    ),
                  );
                }),
              ),

              const SizedBox(height: AeroSpace.xxl),

              // Primary Action (Next / Get Started)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AeroSpace.xxl),
                child: AeroButton(
                  variant: AeroButtonVariant.primary,
                  expand: true,
                  isLoading: _requestingPermission,
                  text: _currentPage == _pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                  onPressed: _requestingPermission ? null : _nextPage,
                ),
              ),

              const SizedBox(height: AeroSpace.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page, AeroColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AeroSpace.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large icon in violet glow circle
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primarySoft,
              boxShadow: [
                BoxShadow(
                  color: colors.primaryGlow,
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(page.icon, size: 48, color: colors.primary),
          ),

          const SizedBox(height: AeroSpace.xxl),

          // Headline
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AeroText.headline.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: AeroSpace.md),

          // One-line description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: AeroText.body.copyWith(
              color: colors.onSurfaceMuted,
              height: 1.4,
            ),
          ),

          if (page.isPermissionPage) ...[
            const SizedBox(height: AeroSpace.xxl),
            _buildPermissionCard(
              colors: colors,
              icon: Symbols.folder_rounded,
              title: 'Storage Access',
              reason: 'Save videos and audio directly to Downloads/AeroTube.',
              isGranted: _storageGranted,
              onRequest: _requestStorage,
            ),
            const SizedBox(height: AeroSpace.md),
            _buildPermissionCard(
              colors: colors,
              icon: Symbols.notifications_active_rounded,
              title: 'Notifications',
              reason: 'Receive alerts when downloads finish in the background.',
              isGranted: _notificationGranted,
              onRequest: _requestNotifications,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required AeroColors colors,
    required IconData icon,
    required String title,
    required String reason,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(AeroSpace.md),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: AeroRadius.lgBorderRadius,
        border: Border.all(
          color: isGranted
              ? colors.success.withValues(alpha: 0.3)
              : colors.outline,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGranted
                  ? colors.success.withValues(alpha: 0.15)
                  : colors.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isGranted ? colors.success : colors.onSurface,
            ),
          ),
          const SizedBox(width: AeroSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AeroText.label.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: AeroText.caption.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AeroSpace.sm),
          if (isGranted)
            AeroChip(
              text: 'Allowed',
              icon: Icon(
                Symbols.check_rounded,
                size: 14,
                color: colors.success,
              ),
              density: AeroDensity.compact,
            )
          else
            AeroButton(
              variant: AeroButtonVariant.tonal,
              density: AeroDensity.compact,
              text: 'Allow',
              onPressed: onRequest,
            ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final bool isPermissionPage;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    this.isPermissionPage = false,
  });
}
