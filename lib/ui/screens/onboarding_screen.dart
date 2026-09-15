import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_utils.dart';
import '../../services/core/android_storage_service.dart';

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

  static const _violet = AppTheme.primaryPurple;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.play_circle_filled_rounded,
      title: 'Welcome to AeroTube',
      subtitle: 'Download videos and audio from YouTube with ease.',
      description: 'Fast, simple, and ad-free.',
    ),
    _OnboardingPage(
      icon: Icons.folder_rounded,
      title: 'Storage Access',
      subtitle: 'AeroTube needs storage permission to save your downloads.',
      description:
          'Your files are saved to Downloads/AeroTube so you can find them easily.',
      isPermissionPage: true,
    ),
    _OnboardingPage(
      icon: Icons.notifications_rounded,
      title: 'Stay Updated',
      subtitle: 'Get notified when your downloads finish.',
      description:
          'We\'ll only send notifications for download progress and completion.',
      isNotificationPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      // Request storage when leaving the storage page so the user sees the
      // system dialog / All-files-access settings while still onboarding.
      if (_pages[_currentPage].isPermissionPage) {
        _requestPermissionsThenAdvance();
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _requestPermissionsThenAdvance() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    try {
      final storageService = AndroidStorageService();
      await storageService.requestStoragePermission();
    } catch (_) {
      // Denied is fine — app falls back to app-specific storage + MediaStore.
    }
    if (!mounted) return;
    setState(() => _requestingPermission = false);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);

    try {
      final storageService = AndroidStorageService();
      final hasStorage = await storageService.hasStoragePermission();
      if (!hasStorage) {
        await storageService.requestStoragePermission();
      }
      // Notification permission (Android 13+) shows a real system dialog.
      if (PlatformUtils.isAndroid) {
        try {
          await Permission.notification.request();
        } catch (_) {}
      }
    } catch (_) {
      // Permission denied is okay - app still works with limited storage
    }

    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isDark ? const Color(0xFF0E0E11) : Colors.white,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0E0E11) : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], isDark);
                  },
                ),
              ),

              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? _violet
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // Next / Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _requestingPermission ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _violet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _requestingPermission
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 40, color: _violet),
          ),

          const SizedBox(height: 36),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 14),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black54,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 10),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black38,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool isPermissionPage;
  final bool isNotificationPage;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    this.isPermissionPage = false,
    this.isNotificationPage = false,
  });
}
