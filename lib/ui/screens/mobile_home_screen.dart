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

  @override
  void dispose() {
    _videoProvider?.removeListener(_onVideoProviderChange);
    _urlController.dispose();
    super.dispose();
  }

  void _onVideoProviderChange() {
    if (_videoProvider == null) return;

    if (_urlController.text != _videoProvider!.currentUrl &&
        _videoProvider!.currentUrl.isNotEmpty) {
      _urlController.text = _videoProvider!.currentUrl;
    }

    if (_videoProvider!.hasError &&
        (_videoProvider!.errorMessage!.contains('Authentication') ||
            _videoProvider!.errorMessage!.contains('cookies.txt'))) {
      _showAuthErrorDialog(_videoProvider!.errorMessage!);
    }
  }

  void _showAuthErrorDialog(String message) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final videoProvider = context.watch<VideoProvider>();
    final settingsProvider = context.watch<PlatformSettingsProvider>();
    final navProvider = context.read<NavigationProvider>();

    final activeDownloads = PlatformUtils.isAndroid
        ? context.watch<MobileDownloadProvider>().activeDownloadsCount
        : context.watch<DownloadProvider>().activeCount;

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
                // Status pill — only highest priority
                if (!settingsProvider.isInitialized)
                  _buildStatusPill(
                    context,
                    label: 'Initializing...',
                    color: theme.colorScheme.primary,
                    isLoading: true,
                  )
                else if (!settingsProvider.isYtdlpAvailable)
                  _buildStatusPill(
                    context,
                    label: 'yt-dlp missing',
                    color: Colors.red,
                  )
                else if (!settingsProvider.isFfmpegAvailable)
                  _buildStatusPill(
                    context,
                    label: 'FFmpeg missing',
                    color: Colors.orange,
                  ),

                const Spacer(),

                // Files button with active-download badge
                _TopBarButton(
                  icon: Icons.download_outlined,
                  activeIcon: Icons.download_rounded,
                  tooltip: 'Downloads',
                  badge: activeDownloads > 0 ? activeDownloads : null,
                  onTap: () => navProvider.setIndex(2),
                ),
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
                            MobileUrlInputCard(
                              controller: _urlController,
                              onFetch: () => _handleFetch(videoProvider),
                              isLoading: false,
                              statusMessage: null,
                              errorMessage: null,
                            ),
                            const SizedBox(height: 20),
                            _buildCookieToggle(context, settingsProvider),
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

  /// Cookie enable/disable toggle row
  Widget _buildCookieToggle(
    BuildContext context,
    PlatformSettingsProvider settingsProvider,
  ) {
    final theme = Theme.of(context);
    final enabled = settingsProvider.enableCookies;
    final isCookieActive = settingsProvider.isCookieActive;
    final isLoggedIn = settingsProvider.isYouTubeLoggedIn;

    // Build the status label
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
      statusLabel = settingsProvider.cookieStatus;
      statusColor = Colors.orange;
      statusIcon = Icons.cookie_rounded;
    } else {
      statusLabel = 'Cookies enabled · not signed in';
      statusColor = Colors.orange.withValues(alpha: 0.8);
      statusIcon = Icons.cookie_rounded;
    }

    return GestureDetector(
      onTap: () async {
        await settingsProvider.setEnableCookies(!enabled);
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
            // Toggle switch — compact
            SizedBox(
              height: 24,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: enabled,
                  onChanged: (val) async {
                    await settingsProvider.setEnableCookies(val);
                  },
                  activeThumbColor: isLoggedIn
                      ? Colors.green
                      : theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(
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

  void _handleFetch(VideoProvider videoProvider) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (url.contains('list=') && !url.contains('v=')) {
      videoProvider.fetchPlaylistInfo(url);
    } else {
      videoProvider.fetchVideoInfo(url);
      videoProvider.setAudioOnly(false);
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const MobileResultScreen(),
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
