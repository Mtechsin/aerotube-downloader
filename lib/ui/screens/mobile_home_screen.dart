import 'package:material_symbols_icons/symbols.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/download_item.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/video_provider.dart';
import '../../services/core/file_action_service.dart';
import '../components/components.dart';
import '../widgets/app_logo.dart';
import 'mobile_result_screen.dart';

/// Minimalist mobile home screen following AeroTube redesign spec section 7.1.
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  final _urlController = TextEditingController();
  VideoProvider? _videoProvider;

  bool _isShowingAuthDialog = false;
  bool _isFetchNavigating = false;
  String? _lastAuthErrorMessage;

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
    _isShowingAuthDialog = false;
    _lastAuthErrorMessage = null;
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

    // C7: never force-unwrap errorMessage. H23: only re-show the auth dialog
    // when the error message itself changes (not on every notify).
    final err = _videoProvider!.errorMessage;
    if (_videoProvider!.hasError && err != null) {
      if (err == _lastAuthErrorMessage) return;
      final parsed = ErrorHelper.parse(err);
      if (parsed.category == ErrorCategory.authentication) {
        _lastAuthErrorMessage = err;
        _showAuthErrorDialog(parsed.suggestion ?? err);
      }
    } else if (!_videoProvider!.hasError) {
      _lastAuthErrorMessage = null;
    }
  }

  void _showAuthErrorDialog(String message) {
    if (!mounted || _isShowingAuthDialog) return;
    _isShowingAuthDialog = true;
    final colors = context.aero;
    showAeroDialog<void>(
      context: context,
      builder: (dialogContext) => AeroDialog(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Symbols.lock_person_rounded,
            color: colors.warning,
            size: 22,
          ),
        ),
        titleText: 'Authentication Required',
        content: Text(
          message,
          style: AeroText.body.copyWith(
            color: colors.onSurfaceMuted,
            height: 1.4,
          ),
        ),
        actions: [
          AeroButton(
            variant: AeroButtonVariant.ghost,
            text: 'Dismiss',
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AeroButton(
            variant: AeroButtonVariant.primary,
            text: 'Sign In',
            icon: const Icon(Symbols.login_rounded, size: 16),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/youtube_login');
            },
          ),
        ],
      ),
    ).then((_) {
      if (mounted) _isShowingAuthDialog = false;
    });
  }

  Future<void> _handleFetch() async {
    // H22: re-entrancy guard — ignore a second Fetch tap while navigating.
    if (_isFetchNavigating) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final videoProvider = context.read<VideoProvider>();
    final settings = context.read<PlatformSettingsProvider>();
    videoProvider.setPreferredQuality(settings.defaultQuality);

    if (url.contains('list=') && !url.contains('v=')) {
      videoProvider.fetchPlaylistInfo(url);
    } else {
      videoProvider.fetchVideoInfo(url);
      videoProvider.setAudioOnly(settings.defaultQuality == 'Audio Only');
    }

    _isFetchNavigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MobileResultScreen()),
      );
    } finally {
      if (mounted) {
        _isFetchNavigating = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    final isLoading = context.select<VideoProvider, bool>((p) => p.isLoading);
    final errorMessage = context.select<VideoProvider, String?>(
      (p) => p.errorMessage,
    );
    final loadingStatus = context.select<VideoProvider, String>(
      (p) => p.loadingStatus,
    );

    final recentDownloads = PlatformUtils.isAndroid
        ? context.select<MobileDownloadProvider, List<DownloadItem>>(
            (p) => p.completedDownloads,
          )
        : context.select<DownloadProvider, List<DownloadItem>>(
            (p) => p.historyDownloads,
          );

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top bar: AeroTube wordmark + StatusPill + avatar ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _AeroTubeWordmark(),
                const Spacer(),
                const _TopBarStatusPill(),
                const SizedBox(width: AeroSpace.sm),
                const _TopBarAvatar(),
              ],
            ),
          ),

          // ── Idle layout: positioned in upper-middle (~35% from top) ────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Ensure composer sits ~35% from the top so it stays above keyboard
                final topSpacing = max(16.0, constraints.maxHeight * 0.10);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: topSpacing),

                            // Headline 28 w800: "Download anything,\ncleanly."
                            Text(
                              'Download anything,\ncleanly.',
                              style: AeroText.headline.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.15,
                                color: colors.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AeroSpace.xs + 2),

                            // Subtitle bodySm muted: "Paste a link. Pick a format."
                            Text(
                              'Paste a link. Pick a format.',
                              style: AeroText.bodySm.copyWith(
                                color: colors.onSurfaceMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AeroSpace.xl),

                            // Composer (UrlComposer): 56dp, radius xl, H27 privacy rule strictly preserved
                            UrlComposer(
                              controller: _urlController,
                              onFetch: _handleFetch,
                              onCancel: () =>
                                  context.read<VideoProvider>().cancelFetch(),
                              isLoading: isLoading,
                              statusMessage: loadingStatus.isNotEmpty
                                  ? loadingStatus
                                  : null,
                              errorMessage: errorMessage,
                              hintText: 'Paste a video URL…',
                              showPasteButton: true,
                              showFetchButton: true,
                            ),

                            // Recent section: top 3 most recent downloads (tap = open/re-open)
                            if (recentDownloads.isNotEmpty) ...[
                              SectionHeader(
                                title: 'Recent',
                                margin: const EdgeInsets.only(
                                  top: AeroSpace.xxl,
                                  bottom: AeroSpace.sm,
                                ),
                              ),
                              ...recentDownloads
                                  .take(3)
                                  .map(
                                    (item) => _RecentDownloadTile(item: item),
                                  ),
                            ],

                            const Spacer(),

                            // Cookie/auth StatusPill row
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AeroSpace.lg,
                              ),
                              child: Center(child: _CookieAuthStatusPill()),
                            ),
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

/// App wordmark for the mobile top bar.
class _AeroTubeWordmark extends StatelessWidget {
  const _AeroTubeWordmark();

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Aero',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: 'Tube',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.w300,
              color: colors.primary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill in the top bar isolated via selects.
class _TopBarStatusPill extends StatelessWidget {
  const _TopBarStatusPill();

  @override
  Widget build(BuildContext context) {
    final isInitialized = context.select<PlatformSettingsProvider, bool>(
      (p) => p.isInitialized,
    );
    if (!isInitialized) {
      return const StatusPill.info(label: 'Initializing', showSpinner: true);
    }

    final hasChecked = context.select<PlatformSettingsProvider, bool>(
      (p) => p.hasCheckedTools,
    );
    if (hasChecked) {
      final isYtdlpAvailable = context.select<PlatformSettingsProvider, bool>(
        (p) => p.isYtdlpAvailable,
      );
      if (!isYtdlpAvailable) {
        return StatusPill.danger(
          label: 'yt-dlp missing',
          icon: Symbols.warning_amber_rounded,
          onTap: () => context.read<NavigationProvider>().setIndex(3),
        );
      }

      final isFfmpegAvailable = context.select<PlatformSettingsProvider, bool>(
        (p) => p.isFfmpegAvailable,
      );
      if (!isFfmpegAvailable) {
        return StatusPill.warning(
          label: 'FFmpeg missing',
          icon: Symbols.warning_amber_rounded,
          onTap: () => context.read<NavigationProvider>().setIndex(3),
        );
      }
    }

    final isLoggedIn = context.select<PlatformSettingsProvider, bool>(
      (p) => p.isYouTubeLoggedIn,
    );
    if (isLoggedIn) {
      return StatusPill.success(
        label: 'Signed in',
        icon: Symbols.verified_user_rounded,
        onTap: () => context.read<NavigationProvider>().setIndex(3),
      );
    }

    final isCookieActive = context.select<PlatformSettingsProvider, bool>(
      (p) => p.isCookieActive,
    );
    if (isCookieActive) {
      return StatusPill.info(
        label: 'Cookies on',
        icon: Symbols.cookie_rounded,
        onTap: () => context.read<NavigationProvider>().setIndex(3),
      );
    }

    return StatusPill.neutral(
      label: 'Ready',
      showDot: true,
      onTap: () => context.read<NavigationProvider>().setIndex(3),
    );
  }
}

/// Avatar button in the top bar.
class _TopBarAvatar extends StatelessWidget {
  const _TopBarAvatar();

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final isLoggedIn = context.select<PlatformSettingsProvider, bool>(
      (p) => p.isYouTubeLoggedIn,
    );
    final profileImageUrl = context.select<PlatformSettingsProvider, String?>(
      (p) => p.youtubeProfileImageUrl,
    );

    return Tooltip(
      message: isLoggedIn ? 'Account & Settings' : 'Settings',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => context.read<NavigationProvider>().setIndex(3),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLoggedIn
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.surface2,
              border: Border.all(
                color: isLoggedIn
                    ? colors.primary.withValues(alpha: 0.35)
                    : colors.outline,
                width: 1,
              ),
            ),
            child: ClipOval(
              child: isLoggedIn && profileImageUrl != null
                  ? Image.network(
                      profileImageUrl,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Symbols.person_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    )
                  : Icon(
                      isLoggedIn
                          ? Symbols.person_rounded
                          : Symbols.person_rounded,
                      size: 18,
                      color: isLoggedIn
                          ? colors.primary
                          : colors.onSurfaceMuted,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile representing a recent download item on Mobile Home.
class _RecentDownloadTile extends StatelessWidget {
  final DownloadItem item;

  const _RecentDownloadTile({required this.item});

  String _formatBadge() {
    if (item.audioOnly) return 'MP3';
    if (item.videoQuality != null && item.videoQuality!.trim().isNotEmpty) {
      final q = item.videoQuality!.trim();
      return q.toLowerCase().contains('mp4') ? q : '$q MP4';
    }
    return '1080p MP4';
  }

  Future<void> _handleTap(BuildContext context) async {
    final path = item.savePath ?? item.outputPath;
    final success = await FileActionService().openFile(path);
    if (!success && context.mounted) {
      final msg = FileActionService().lastError ?? 'Could not open file';
      AeroSnack.error(context, message: msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return Padding(
      padding: const EdgeInsets.only(bottom: AeroSpace.xs + 2),
      child: AeroCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderRadius: AeroRadius.mdBorderRadius,
        onTap: () => _handleTap(context),
        child: Row(
          children: [
            ThumbnailTile(
              imageUrl: item.thumbnailUrl,
              width: 72,
              height: 40.5,
              borderRadius: AeroRadius.smBorderRadius,
            ),
            const SizedBox(width: AeroSpace.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: AeroText.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: AeroRadius.fullBorderRadius,
                      border: Border.all(color: colors.outline, width: 0.8),
                    ),
                    child: Text(
                      _formatBadge(),
                      style: AeroText.caption.copyWith(
                        color: colors.onSurfaceMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AeroSpace.xs),
            Icon(Symbols.check_circle_rounded, color: colors.success, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Cookie / auth status pill row ("Signed in · cookies on", "Cookies on · not signed in", "Cookies off").
class _CookieAuthStatusPill extends StatelessWidget {
  const _CookieAuthStatusPill();

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<PlatformSettingsProvider, bool>(
      (p) => p.enableCookies,
    );
    final isLoggedIn = context.select<PlatformSettingsProvider, bool>(
      (p) => p.isYouTubeLoggedIn,
    );

    if (!enabled) {
      return StatusPill.neutral(
        label: 'Cookies off',
        icon: Symbols.cookie_rounded,
        tooltip: 'Tap to turn cookies on',
        onTap: () async {
          await context.read<PlatformSettingsProvider>().setEnableCookies(true);
          if (context.mounted) {
            AeroSnack.success(context, message: 'Cookies enabled');
          }
        },
      );
    } else if (isLoggedIn) {
      return StatusPill.success(
        label: 'Signed in · cookies on',
        icon: Symbols.verified_user_rounded,
        tooltip: 'Signed in to YouTube · cookies active',
        onTap: () => context.read<NavigationProvider>().setIndex(3),
      );
    } else {
      return StatusPill.warning(
        label: 'Cookies on · not signed in',
        icon: Symbols.cookie_rounded,
        tooltip: 'Tap to sign in to YouTube',
        onTap: () {
          Navigator.pushNamed(context, '/youtube_login');
        },
      );
    }
  }
}

/// Mobile initialization overlay (preserved for background initialization sequences).
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
                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.linear),
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
                icon: Symbols.check_circle_rounded,
                title: 'Loading settings',
                isComplete: true,
              ),
              const SizedBox(height: 12),
              _buildProgressStep(
                context,
                icon: Symbols.terminal_rounded,
                title: 'Checking yt-dlp',
                isLoading: true,
              ),
              const SizedBox(height: 12),
              _buildProgressStep(
                context,
                icon: Symbols.movie_rounded,
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
                  curve: Curves.linear,
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
      trailing = const Icon(
        Symbols.check_rounded,
        color: Colors.green,
        size: 20,
      );
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
