import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../core/utils/platform_utils.dart';
import '../widgets/mobile_url_input_card.dart';
import '../widgets/app_logo.dart';
import 'package:flutter/cupertino.dart';
import 'mobile_result_screen.dart';
import '../../core/utils/error_helper.dart';

/// Minimalist mobile home screen
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  final _urlController = TextEditingController();
  VideoProvider? _videoProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoProvider = context.read<VideoProvider>();
      _videoProvider!.addListener(_onVideoProviderChange);
    });
  }

  bool _isShowingAuthDialog = false;

  @override
  void dispose() {
    _isShowingAuthDialog = false;
    _videoProvider?.removeListener(_onVideoProviderChange);
    _urlController.dispose();
    super.dispose();
  }

  void _onVideoProviderChange() {
    if (!mounted || _videoProvider == null) return;

    if (_urlController.text != _videoProvider!.currentUrl &&
        _videoProvider!.currentUrl.isNotEmpty) {
      _urlController.text = _videoProvider!.currentUrl;
    }

    if (_videoProvider!.hasError) {
      final parsed = ErrorHelper.parse(_videoProvider!.errorMessage!);
      if (parsed.category == ErrorCategory.authentication) {
        _showAuthErrorDialog(parsed.suggestion ?? _videoProvider!.errorMessage!);
      }
    }
  }

  void _showAuthErrorDialog(String message) {
    if (!mounted || _isShowingAuthDialog) return;
    _isShowingAuthDialog = true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Authentication Required'),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) _isShowingAuthDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navProvider = context.read<NavigationProvider>();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App name
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Aero',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: 'Tube',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 26,
                          fontWeight: FontWeight.w300,
                          color: theme.colorScheme.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status pill — isolated so settings notifications don't rebuild whole screen
                const _StatusPill(),
                const Spacer(),
                // Files button with active-download badge — isolated via select
                _DownloadBadgeButton(navProvider: navProvider),
                const SizedBox(width: 2),
                // Settings button
                _TopBarButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Settings',
                  onTap: () => navProvider.setIndex(3),
                ),
              ],
            ),
          ),

          // ── Main Content — vertically centered ───────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _UrlInputSection(controller: _urlController),
                            const SizedBox(height: 20),
                            const _CookieToggle(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

/// Status pill isolated via selects — rebuilds only this small widget on settings changes
class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInitialized =
        context.select<PlatformSettingsProvider, bool>((p) => p.isInitialized);
    if (!isInitialized) {
      return _buildPill(
        context,
        label: 'Initializing...',
        color: theme.colorScheme.primary,
        isLoading: true,
      );
    }
    final hasChecked =
        context.select<PlatformSettingsProvider, bool>((p) => p.hasCheckedTools);
    if (!hasChecked) return const SizedBox.shrink();
    final isYtdlpAvailable = context
        .select<PlatformSettingsProvider, bool>((p) => p.isYtdlpAvailable);
    if (!isYtdlpAvailable) {
      return _buildPill(context, label: 'yt-dlp missing', color: Colors.red);
    }
    final isFfmpegAvailable = context
        .select<PlatformSettingsProvider, bool>((p) => p.isFfmpegAvailable);
    if (!isFfmpegAvailable) {
      return _buildPill(context, label: 'FFmpeg missing', color: Colors.orange);
    }
    return const SizedBox.shrink();
  }

  Widget _buildPill(
    BuildContext context, {
    required String label,
    required Color color,
    bool isLoading = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 6,
            height: 6,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: color.withValues(alpha: 0.6),
            ),
          )
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Active-download badge isolated via select — only rebuilds the icon when count changes
class _DownloadBadgeButton extends StatelessWidget {
  final NavigationProvider navProvider;
  const _DownloadBadgeButton({required this.navProvider});

  @override
  Widget build(BuildContext context) {
    final int activeDownloads = PlatformUtils.isAndroid
        ? context.select<MobileDownloadProvider, int>(
            (p) => p.activeDownloadsCount)
        : context.select<DownloadProvider, int>((p) => p.activeCount);
    return _TopBarButton(
      icon: Icons.download_outlined,
      activeIcon: Icons.download_rounded,
      tooltip: 'Downloads',
      badge: activeDownloads > 0 ? activeDownloads : null,
      onTap: () => navProvider.setIndex(2),
    );
  }
}

/// URL input isolated: watches only isLoading/errorMessage at this level,
/// and delegates per-tick loadingStatus to a nested small widget.
class _UrlInputSection extends StatelessWidget {
  final TextEditingController controller;
  const _UrlInputSection({required this.controller});

  void _handleFetch(BuildContext context) {
    final url = controller.text.trim();
    if (url.isEmpty) return;
    final videoProvider = context.read<VideoProvider>();
    // Apply default quality from settings before fetching formats.
    final settings = context.read<PlatformSettingsProvider>();
    videoProvider.setPreferredQuality(settings.defaultQuality);
    if (url.contains('list=') && !url.contains('v=')) {
      videoProvider.fetchPlaylistInfo(url);
    } else {
      videoProvider.fetchVideoInfo(url);
      videoProvider.setAudioOnly(settings.defaultQuality == 'Audio Only');
    }
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const MobileResultScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.select<VideoProvider, bool>((p) => p.isLoading);
    final errorMessage =
        context.select<VideoProvider, String?>((p) => p.errorMessage);
    return _UrlInputStatusWrapper(
      controller: controller,
      isLoading: isLoading,
      errorMessage: errorMessage,
      onFetch: () => _handleFetch(context),
      onCancel: () => context.read<VideoProvider>().cancelFetch(),
    );
  }
}

/// Inner wrapper that watches only loadingStatus — per-fetch-progress ticks
/// rebuild only this small widget, not the whole screen or even the loading/error wrapper.
class _UrlInputStatusWrapper extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onFetch;
  final VoidCallback? onCancel;
  const _UrlInputStatusWrapper({
    required this.controller,
    required this.isLoading,
    required this.errorMessage,
    required this.onFetch,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final loadingStatus =
        context.select<VideoProvider, String>((p) => p.loadingStatus);
    return MobileUrlInputCard(
      controller: controller,
      onFetch: onFetch,
      onCancel: onCancel,
      isLoading: isLoading,
      statusMessage: loadingStatus,
      errorMessage: errorMessage,
    );
  }
}

/// Cookie toggle isolated via selects — rebuilds only this row
class _CookieToggle extends StatelessWidget {
  const _CookieToggle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled =
        context.select<PlatformSettingsProvider, bool>((p) => p.enableCookies);
    final isCookieActive =
        context.select<PlatformSettingsProvider, bool>((p) => p.isCookieActive);
    final isLoggedIn = context
        .select<PlatformSettingsProvider, bool>((p) => p.isYouTubeLoggedIn);
    final cookieStatus =
        context.select<PlatformSettingsProvider, String>((p) => p.cookieStatus);

    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    if (!enabled) {
      statusLabel = 'Cookies disabled';
      statusColor = theme.colorScheme.onSurface.withValues(alpha: 0.35);
      statusIcon = Icons.cookie_outlined;
    } else if (isLoggedIn) {
      statusLabel = 'Signed in to YouTube · cookies active';
      statusColor = Colors.green;
      statusIcon = Icons.verified_user_rounded;
    } else if (isCookieActive) {
      statusLabel = cookieStatus;
      statusColor = Colors.orange;
      statusIcon = Icons.cookie_rounded;
    } else {
      statusLabel = 'Cookies enabled · not signed in';
      statusColor = Colors.orange.withValues(alpha: 0.8);
      statusIcon = Icons.cookie_rounded;
    }

    return GestureDetector(
      onTap: () async {
        await context
            .read<PlatformSettingsProvider>()
            .setEnableCookies(!enabled);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: enabled
              ? (isLoggedIn
                  ? Colors.green.withValues(alpha: 0.07)
                  : theme.colorScheme.primary.withValues(alpha: 0.05))
              : theme.colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? (isLoggedIn
                    ? Colors.green.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.12))
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 24,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: enabled,
                  onChanged: (val) async {
                    await context
                        .read<PlatformSettingsProvider>()
                        .setEnableCookies(val);
                  },
                  activeThumbColor:
                      isLoggedIn ? Colors.green : theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact top-bar icon button with optional badge
class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String tooltip;
  final int? badge;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    this.activeIcon,
    required this.tooltip,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            icon,
            size: 22,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          onPressed: onTap,
          tooltip: tooltip,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
        if (badge != null)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badge! > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Mobile initialization overlay
class MobileInitializationOverlay extends StatelessWidget {
  final PlatformSettingsProvider settingsProvider;

  const MobileInitializationOverlay({
    super.key,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLogo(size: 120)
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 32),
              Text(
                'YouTube Downloader',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Initializing application...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 40),
              _buildProgressStep(
                context,
                icon: Icons.check_circle_rounded,
                title: 'Loading settings',
                isComplete: true,
              ),
              const SizedBox(height: 12),
              _buildProgressStep(
                context,
                icon: Icons.terminal_rounded,
                title: 'Checking yt-dlp',
                isLoading: true,
              ),
              const SizedBox(height: 12),
              _buildProgressStep(
                context,
                icon: Icons.movie_rounded,
                title: 'Checking FFmpeg',
                isPending: true,
              ),
              const SizedBox(height: 32),
              Container(
                width: 150,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 1200.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool isComplete = false,
    bool isLoading = false,
    bool isPending = false,
  }) {
    final theme = Theme.of(context);

    Color iconColor;
    Widget trailing;

    if (isComplete) {
      iconColor = Colors.green;
      trailing = const Icon(Icons.check_rounded, color: Colors.green, size: 20);
    } else if (isLoading) {
      iconColor = theme.colorScheme.primary;
      trailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    } else {
      iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
      trailing = const SizedBox(width: 20);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLoading
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : isComplete
                ? Colors.green.withValues(alpha: 0.05)
                : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLoading
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : isComplete
                  ? Colors.green.withValues(alpha: 0.2)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isPending
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface,
                fontWeight: isLoading ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
