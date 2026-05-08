import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/download_mode.dart';
import '../../providers/video_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../models/video_info.dart';
import '../widgets/mobile_url_input_card.dart';
import '../widgets/mobile_video_configuration_widget.dart';
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
    final videoProvider = context.watch<VideoProvider>();
    final settingsProvider = context.watch<PlatformSettingsProvider>();
    final hasResult = videoProvider.hasVideo ||
        videoProvider.hasPlaylist ||
        videoProvider.isLoading ||
        videoProvider.hasError;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: _buildAppTitle(context),
          ),

          // Status Banners
          if (!settingsProvider.isInitialized ||
              !settingsProvider.isYtdlpAvailable ||
              (settingsProvider.isYtdlpAvailable &&
                  !settingsProvider.isFfmpegAvailable)) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (!settingsProvider.isInitialized)
                    _buildInitializingBanner(context),
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
              ),
            ),
          ],

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  MobileUrlInputCard(
                    controller: _urlController,
                    onFetch: () => _handleFetch(videoProvider),
                    isLoading: false,
                    statusMessage: null,
                    errorMessage: null,
                  ),
                  const SizedBox(height: 32),
                  _buildMobileEmptyState(context, videoProvider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'AeroTube',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildInitializingBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Initializing...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEmptyState(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.download_rounded,
          size: 40,
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 16),
        Text(
          'Ready to Download',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Paste a YouTube link to get started',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeaturePill(context, Icons.four_k_rounded, '4K'),
            _buildFeaturePill(context, Icons.music_note_rounded, 'Audio'),
            _buildFeaturePill(context, Icons.playlist_play_rounded, 'Playlist'),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturePill(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
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
