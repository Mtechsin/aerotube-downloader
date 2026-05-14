import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mobile_home_layout.dart';
import '../../core/utils/responsive_layout.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/download_mode.dart';
import '../../providers/video_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../models/video_info.dart';
import '../widgets/video_configuration_widget.dart';
import '../widgets/url_input_card.dart';
import '../widgets/app_logo.dart';
import 'playlist_screen.dart';

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

  @override
  void dispose() {
    _videoProvider?.removeListener(_onVideoProviderChange);
    _urlController.dispose();
    _urlFocusNode.dispose();
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
    final screenType = ResponsiveLayout.getScreenType(context);
    if (screenType == ScreenType.mobile) {
      return const MobileHomeLayout();
    } else {
      return Stack(
        children: [
          // Content Area - No scroll needed
          Positioned.fill(
            top: (videoProvider.hasVideo || videoProvider.isLoading) ? 100 : 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Banners - Compact
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

                  const SizedBox(height: 12),

                  // Loaded State OR Empty State - Expanded to fill space
                  Expanded(
                    child: videoProvider.hasVideo || videoProvider.isLoading
                        ? VideoConfigurationWidget(
                            onDownload: _startDownload,
                            onClear: () {
                              videoProvider.clear();
                              _urlController.clear();
                            },
                          )
                        : !videoProvider.isLoading && !videoProvider.hasError
                        ? _buildAeroTubeEmptyState(context, videoProvider)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Floating Command Capsule (Top) conditionally shown
          if (videoProvider.hasVideo || videoProvider.isLoading)
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _buildCommandCapsule(context, videoProvider),
                ),
              ),
            ),

          // Top Right Actions
          Positioned(
            top: 24,
            right: 24,
            child: Row(
              children: [
                _buildTopRightPasteButton(context),
                const SizedBox(width: 12),
                _buildThemeToggleButton(context),
              ],
            ),
          ),

          // Bottom Footer Text
          if (!videoProvider.hasVideo && !videoProvider.isLoading)
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Secure  •  Fast  •  Reliable',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
      showPasteButton: false,
      onFetch: () => _handleFetch(videoProvider),
      isLoading: videoProvider.isLoading,
      statusMessage: videoProvider.loadingStatus.isEmpty
          ? null
          : videoProvider.loadingStatus,
      errorMessage: videoProvider.hasError ? videoProvider.errorMessage : null,
    ).animate().slideY(begin: -1, curve: Curves.easeOutBack, duration: 600.ms);
  }

  Widget _buildInitializationOverlay(
    BuildContext context,
    PlatformSettingsProvider settingsProvider,
  ) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      color: theme.colorScheme.surface.withValues(alpha: 0.98),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo Image
              AppLogo(size: 140)
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 40),

              // Title
              Text(
                    'YouTube Downloader',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                    'Initializing application...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 48),

              // Progress Steps
              _buildProgressStep(
                context,
                icon: Icons.check_circle_rounded,
                title: 'Loading settings',
                isComplete: true,
                delay: 600.ms,
              ),

              const SizedBox(height: 16),

              _buildProgressStep(
                context,
                icon: Icons.terminal_rounded,
                title: 'Checking yt-dlp',
                isLoading: true,
                delay: 800.ms,
              ),

              const SizedBox(height: 16),

              _buildProgressStep(
                context,
                icon: Icons.movie_rounded,
                title: 'Checking FFmpeg',
                isPending: true,
                delay: 1000.ms,
              ),

              const SizedBox(height: 48),

              // Loading Bar
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  width: 120,
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
    Duration delay = Duration.zero,
  }) {
    final theme = Theme.of(context);

    Color iconColor;
    Widget trailing;

    if (isComplete) {
      iconColor = Colors.green;
      trailing = Icon(Icons.check_rounded, color: Colors.green, size: 20);
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isPending
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                        : theme.colorScheme.onSurface,
                    fontWeight: isLoading ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay)
        .slideX(begin: -0.1, end: 0);
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

  Widget _buildStatusBanner(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    Widget? action,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 12), action],
              ],
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildAeroTubeEmptyState(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppLogo(size: 104, showGlow: false)
                    .animate()
                    .fadeIn(duration: 450.ms, delay: 50.ms)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 22),

                Text(
                      'Paste URL',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1.05,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 140.ms)
                    .slideY(begin: 0.08, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Paste a link and fetch content instantly.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 240.ms, delay: 180.ms),

                const SizedBox(height: 22),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: UrlInputCard(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    showPasteButton: false,
                    onFetch: () => _handleFetch(videoProvider),
                    isLoading: videoProvider.isLoading,
                    statusMessage: videoProvider.loadingStatus.isEmpty
                        ? null
                        : videoProvider.loadingStatus,
                    errorMessage: videoProvider.hasError
                        ? videoProvider.errorMessage
                        : null,
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: 220.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String description}) {
    return Container(
      width: 336,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                color: Color(0xFFBA97FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFBA97FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFetch(VideoProvider videoProvider) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

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

  Widget _buildTopRightPasteButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: _pasteUrl,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(Icons.content_paste_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
      label: const Text(
        'Paste',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
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

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _urlController.text = text;
      _urlController.selection = TextSelection.collapsed(offset: text.length);
    });

    _urlFocusNode.requestFocus();
  }

  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    final settingsProvider = context.read<PlatformSettingsProvider>();

    if (videoProvider.videoInfo == null) return;

    final outputPath =
        settingsProvider.settings.outputPath ??
        await settingsProvider.getDefaultOutputPath();

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
        action: SnackBarAction(label: 'View', onPressed: () {}),
      ),
    );

    videoProvider.clear();
    _urlController.clear();
  }
}
