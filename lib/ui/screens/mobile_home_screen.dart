import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/download_mode.dart';
import '../../providers/video_provider.dart';

import '../../providers/platform_settings_provider.dart';

import '../../providers/mobile_download_provider.dart';
import '../../models/video_info.dart';

import '../../core/utils/responsive_layout.dart';
import '../widgets/mobile_url_input_card.dart';
import '../widgets/mobile_glass_card.dart';
import '../widgets/video_configuration_widget.dart';
import '../widgets/app_logo.dart';

/// Mobile-optimized home screen with responsive layout
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

    // Sync URL controller
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
    final videoProvider = context.watch<VideoProvider>();
    final settingsProvider = context.watch<PlatformSettingsProvider>();
    final padding = ResponsiveLayout.getPadding(context);

    return Stack(
      children: [
        // Main Content Area
        Positioned.fill(
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),

                // App Logo and Title
                _buildHeader(context),

                const SizedBox(height: 24),

                // Status Banners
                if (!settingsProvider.isInitialized)
                  _buildInitializingBanner(context)
                else ...[
                  if (!settingsProvider.isYtdlpAvailable)
                    _buildCompactStatusBanner(
                      context,
                      title: 'yt-dlp Not Found',
                      message: 'Configure in Settings',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                    ),
                  if (settingsProvider.isYtdlpAvailable &&
                      !settingsProvider.isFfmpegAvailable)
                    _buildCompactStatusBanner(
                      context,
                      title: 'FFmpeg Not Found',
                      message: 'Some features limited',
                      icon: Icons.info_outline_rounded,
                      color: Colors.orange,
                    ),
                ],

                const SizedBox(height: 16),

                // URL Input Card
                MobileUrlInputCard(
                  controller: _urlController,
                  onFetch: () => _handleFetch(videoProvider),
                  isLoading: videoProvider.isLoading,
                  statusMessage: videoProvider.loadingStatus.isEmpty
                      ? null
                      : videoProvider.loadingStatus,
                  errorMessage: videoProvider.hasError
                      ? videoProvider.errorMessage
                      : null,
                ),

                const SizedBox(height: 24),

                // Video Configuration or Empty State
                if (videoProvider.hasVideo || videoProvider.isLoading)
                  VideoConfigurationWidget(
                        onDownload: _startDownload,
                        onClear: () {
                          videoProvider.clear();
                          _urlController.clear();
                        },
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0)
                else if (!videoProvider.isLoading && !videoProvider.hasError)
                  _buildMobileEmptyState(context, videoProvider)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return MobileGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          // App Logo
          SizedBox(width: 56, height: 56, child: AppLogo(size: 56)),
          const SizedBox(width: 16),
          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AeroTube',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Video & Audio Downloader',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildInitializingBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildMobileEmptyState(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    final theme = Theme.of(context);

    return MobileGlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 20,
      child: Column(
        children: [
          // Icon
          Icon(
            Icons.download_rounded,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Ready to Download',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Paste a YouTube video or playlist link to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Feature Pills
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeaturePill(context, Icons.four_k_rounded, '4K Video'),
              _buildFeaturePill(
                context,
                Icons.music_note_rounded,
                'Audio Only',
              ),
              _buildFeaturePill(
                context,
                Icons.playlist_play_rounded,
                'Playlists',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _handleFetch(VideoProvider videoProvider) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    videoProvider.fetchVideoInfo(url);
  }

  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<MobileDownloadProvider>();

    if (videoProvider.videoInfo == null) return;

    // Add download with selected format/audio options for Android
    final selectedSubtitleLanguages = videoProvider.selectedSubtitles
        .map((s) => s.languageCode)
        .toList();

    await downloadProvider.addDownload(
      url: videoProvider.currentUrl,
      title: videoProvider.videoInfo!.title,
      thumbnailUrl: videoProvider.videoInfo!.thumbnailUrl,
      mode: videoProvider.audioOnly
          ? DownloadMode.audioOnly
          : DownloadMode.videoWithAudio,
      formatId: videoProvider.selectedVideoFormatId,
      options: {
        'audioFormatId': videoProvider.selectedAudioFormatId,
        'targetHeight': videoProvider.selectedHeight,
        'audioQuality': videoProvider.selectedAudioQuality.ytdlpValue,
        'embedSubtitles': videoProvider.embedSubtitles,
        'subtitleLanguages': selectedSubtitleLanguages,
      },
    );

    // Show confirmation
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download started: ${videoProvider.videoInfo!.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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
              // Animated Logo
              AppLogo(size: 120)
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 32),

              // Title
              Text(
                'YouTube Downloader',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Initializing application...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 40),

              // Progress Steps
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

              // Loading Bar
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
