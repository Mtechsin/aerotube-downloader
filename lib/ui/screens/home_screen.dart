import 'dart:ui';
import 'package:flutter/material.dart';
import 'mobile_home_layout.dart';
import '../../core/utils/responsive_layout.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/download_mode.dart';
import '../../providers/video_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../models/video_info.dart';
import '../widgets/video_configuration_widget.dart';
import '../widgets/url_input_card.dart';
import 'playlist_screen.dart';
import '../../core/utils/error_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
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
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onVideoProviderChange() {
    if (!mounted || _videoProvider == null) return;

    // Sync URL controller
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
    final vp = context.select<VideoProvider, ({
      bool hasVideo,
      bool isLoading,
      bool hasError,
      String? errorMessage,
      String loadingStatus,
    })>((p) => (
      hasVideo: p.hasVideo,
      isLoading: p.isLoading,
      hasError: p.hasError,
      errorMessage: p.errorMessage,
      loadingStatus: p.loadingStatus,
    ));

    final sp = context.select<PlatformSettingsProvider, ({
      bool isInitialized,
      bool hasCheckedTools,
      bool isYtdlpAvailable,
      bool isFfmpegAvailable,
    })>((p) => (
      isInitialized: p.isInitialized,
      hasCheckedTools: p.hasCheckedTools,
      isYtdlpAvailable: p.isYtdlpAvailable,
      isFfmpegAvailable: p.isFfmpegAvailable,
    ));

    final screenType = ResponsiveLayout.getScreenType(context);
    if (screenType == ScreenType.mobile) {
      return const MobileHomeLayout();
    } else {
      return Stack(
        children: [
          // Content Area - No scroll needed
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vp.hasVideo ||
                          vp.isLoading ||
                          vp.hasError) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: _buildCommandCapsule(context, context.read<VideoProvider>()),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Expanded(
                        child: vp.hasVideo || vp.isLoading
                            ? VideoConfigurationWidget(
                                onDownload: _startDownload,
                                onClear: () {
                                  context.read<VideoProvider>().clear();
                                  _urlController.clear();
                                },
                              )
                            : vp.hasError
                            ? _buildDesktopErrorState(context, context.read<VideoProvider>())
                            : _buildAeroTubeEmptyState(context, context.read<VideoProvider>()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top Right Actions
          Positioned(
            top: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildThemeToggleButton(context),
                const SizedBox(height: 12),
                if (!sp.isInitialized)
                  _buildInitializingBanner(context)
                else ...[
                  if (sp.hasCheckedTools &&
                      !sp.isYtdlpAvailable)
                    _buildCompactStatusBanner(
                      context,
                      title: 'yt-dlp Not Found',
                      message: 'Configure in Settings',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                    ),
                  if (sp.hasCheckedTools &&
                      sp.isYtdlpAvailable &&
                      !sp.isFfmpegAvailable)
                    _buildCompactStatusBanner(
                      context,
                      title: 'FFmpeg Not Found',
                      message: 'Some features limited',
                      icon: Icons.info_outline_rounded,
                      color: Colors.orange,
                    ),
                ],
              ],
            ),
          ),

          // Bottom Footer Text
          if (!vp.hasVideo &&
              !vp.isLoading &&
              !vp.hasError)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Secure  •  Fast  •  Reliable',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
  }

  Widget _buildCommandCapsule(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    return UrlInputCard(
      controller: _urlController,
      focusNode: _urlFocusNode,
      showPasteButton: true,
      onFetch: () => _handleFetch(videoProvider),
      onCancel: () => videoProvider.cancelFetch(),
      isLoading: videoProvider.isLoading,
      statusMessage: videoProvider.loadingStatus.isEmpty
          ? null
          : videoProvider.loadingStatus,
      errorMessage: videoProvider.hasError ? videoProvider.errorMessage : null,
    ).animate().slideY(begin: -1, curve: Curves.easeOutBack, duration: 600.ms);
  }

  Widget _buildInitializingBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Initializing...',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildCompactStatusBanner(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark 
              ? color.withValues(alpha: 0.1) 
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
    );
  }

  Widget _buildAeroTubeEmptyState(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                      'Download YouTube content cleanly',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                        height: 1.05,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 120.ms)
                    .slideY(begin: 0.06, end: 0),

                const SizedBox(height: 10),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    'Paste a video or playlist URL from YouTube or any site yt-dlp supports, choose your format, and keep downloads organized without extra clutter.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.58,
                      ),
                      fontSize: 14,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(duration: 240.ms, delay: 170.ms),

                const SizedBox(height: 28),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: UrlInputCard(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    showPasteButton: true,
                    onFetch: () => _handleFetch(videoProvider),
                    onCancel: () => videoProvider.cancelFetch(),
                    isLoading: videoProvider.isLoading,
                    statusMessage: videoProvider.loadingStatus.isEmpty
                        ? null
                        : videoProvider.loadingStatus,
                    errorMessage: videoProvider.hasError
                        ? videoProvider.errorMessage
                        : null,
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: 220.ms),

                const SizedBox(height: 18),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildFeaturePill(
                      context,
                      Icons.flash_on_rounded,
                      'Fast fetch',
                    ),
                    _buildFeaturePill(
                      context,
                      Icons.high_quality_rounded,
                      'Quality control',
                    ),
                    _buildFeaturePill(
                      context,
                      Icons.playlist_play_rounded,
                      'Playlist ready',
                    ),
                  ],
                ).animate().fadeIn(duration: 240.ms, delay: 260.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopErrorState(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final error = videoProvider.errorMessage ?? 'An unexpected error occurred';

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Error icon
                Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 34,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 260.ms)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      end: const Offset(1, 1),
                      duration: 260.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 22),

                // Title
                Text(
                  'Something went wrong',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 260.ms, delay: 80.ms),

                const SizedBox(height: 12),

                // Error message
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                          fontSize: 13,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 240.ms, delay: 140.ms),

                const SizedBox(height: 28),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        videoProvider.clear();
                        _urlController.clear();
                        _urlFocusNode.requestFocus();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Try again',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        _urlController.clear();
                        _urlFocusNode.requestFocus();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text(
                        'New URL',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 240.ms, delay: 200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _handleFetch(VideoProvider videoProvider) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Apply default quality from settings before fetching formats.
    final settings = context.read<PlatformSettingsProvider>();
    videoProvider.setPreferredQuality(settings.defaultQuality);

    if (url.contains('list=') || url.contains('/playlist')) {
      if (mounted) {
        context.read<PlaylistProvider>().fetchPlaylist(url);

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlaylistScreen()),
        );
      }
    } else {
      videoProvider.fetchVideoInfo(url);
    }
  }

  Widget _buildThemeToggleButton(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.read<PlatformSettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return IconButton(
      onPressed: () {
        settingsProvider.setThemeMode(
          isDark ? ThemeMode.light : ThemeMode.dark,
        );
      },
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.black.withValues(alpha: 0.025),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 18,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
      ),
    );
  }

  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    final settingsProvider = context.read<PlatformSettingsProvider>();

    if (videoProvider.videoInfo == null) return;

    final outputPath =
        settingsProvider.settings.outputPath ??
        await settingsProvider.getDefaultOutputPath();

    final estimatedSize = videoProvider.totalEstimatedDownloadSize;
    downloadProvider.startDownload(
      video: videoProvider.videoInfo!,
      outputPath: outputPath,
      mode: videoProvider.audioOnly
          ? DownloadMode.audioOnly
          : DownloadMode.videoWithAudio,
      formatId: videoProvider.selectedVideoFormatId,
      audioFormatId: videoProvider.selectedAudioFormatId,
      targetHeight: videoProvider.selectedHeight,
      audioQuality: videoProvider.selectedAudioQuality.ytdlpValue,
      embedThumbnail: settingsProvider.settings.embedThumbnail,
      embedMetadata: settingsProvider.settings.embedMetadata,
      subtitleLanguages: videoProvider.selectedSubtitles
          .map((s) => s.languageCode)
          .toList(),
      embedSubtitles: videoProvider.embedSubtitles,
      sponsorBlock: settingsProvider.sponsorBlockEnabled,
      useDownloadArchive: settingsProvider.useDownloadArchive,
      estimatedFileSize: estimatedSize > 0 ? estimatedSize : null,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Download started: ${videoProvider.videoInfo!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => context.read<NavigationProvider>().setIndex(2),
        ),
      ),
    );

    videoProvider.clear();
    _urlController.clear();
  }
}
