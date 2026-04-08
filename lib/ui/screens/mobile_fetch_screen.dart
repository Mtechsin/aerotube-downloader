import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/download_mode.dart';
import '../../providers/video_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/video_info.dart';
import '../widgets/app_logo.dart';
import '../widgets/mobile_video_configuration_widget.dart';

class MobileFetchScreen extends StatefulWidget {
  const MobileFetchScreen({super.key});

  @override
  State<MobileFetchScreen> createState() => _MobileFetchScreenState();
}

class _MobileFetchScreenState extends State<MobileFetchScreen>
    with TickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  VideoProvider? _videoProvider;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoProvider = context.read<VideoProvider>();
      _videoProvider!.addListener(_onVideoUpdate);
    });
  }

  @override
  void dispose() {
    _videoProvider?.removeListener(_onVideoUpdate);
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  bool _hasUrl = false;
  void _onUrlChanged() {
    final hasText = _urlController.text.trim().isNotEmpty;
    if (hasText != _hasUrl) {
      setState(() => _hasUrl = hasText);
    }
  }

  void _onVideoUpdate() {
    if (_videoProvider == null) return;
    if (_urlController.text != _videoProvider!.currentUrl &&
        _videoProvider!.currentUrl.isNotEmpty) {
      _urlController.text = _videoProvider!.currentUrl;
    }
    if (_videoProvider!.hasError &&
        (_videoProvider!.errorMessage!.contains('Authentication') ||
            _videoProvider!.errorMessage!.contains('cookies.txt'))) {
      _showAuthError(_videoProvider!.errorMessage!);
    }
  }

  void _showAuthError(String message) {
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

  void _handleFetch() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final videoProvider = context.read<VideoProvider>();
    if (url.contains('list=') && !url.contains('v=')) {
      videoProvider.fetchPlaylistInfo(url);
    } else {
      videoProvider.fetchVideoInfo(url);
      videoProvider.setAudioOnly(false);
    }
  }

  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<MobileDownloadProvider>();

    if (videoProvider.videoInfo == null) return;

    final selectedSubtitleLanguages = videoProvider.subtitlesEnabled
        ? videoProvider.selectedSubtitles.map((s) => s.languageCode).toList()
        : <String>[];

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
        'embedSubtitles':
            videoProvider.subtitlesEnabled && videoProvider.embedSubtitles,
        'subtitleLanguages': selectedSubtitleLanguages,
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download started: ${videoProvider.videoInfo!.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAndReset() {
    context.read<VideoProvider>().clear();
    _urlController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final settingsProvider = context.watch<PlatformSettingsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasResult =
        videoProvider.hasVideo ||
        videoProvider.hasPlaylist ||
        videoProvider.isLoading ||
        videoProvider.hasError;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: theme.scaffoldBackgroundColor)),
        SafeArea(
          child: Column(
            children: [
              _buildAppBar(theme, isDark),
              if (!settingsProvider.isInitialized ||
                  !settingsProvider.isYtdlpAvailable ||
                  (settingsProvider.isYtdlpAvailable &&
                      !settingsProvider.isFfmpegAvailable))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(
                    children: [
                      if (!settingsProvider.isInitialized)
                        _buildInitializingBanner(theme),
                      if (!settingsProvider.isYtdlpAvailable)
                        _buildStatusBanner(
                          theme,
                          'yt-dlp Not Found',
                          'Configure in Settings',
                          Icons.warning_amber_rounded,
                          Colors.red,
                        ),
                      if (settingsProvider.isYtdlpAvailable &&
                          !settingsProvider.isFfmpegAvailable)
                        _buildStatusBanner(
                          theme,
                          'FFmpeg Not Found',
                          'Some features limited',
                          Icons.info_outline_rounded,
                          Colors.orange,
                        ),
                    ],
                  ),
                ),
              if (hasResult)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _buildUrlInputCard(theme, videoProvider),
                ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    FocusScope.of(context).unfocus();
                    return false;
                  },
                  child: hasResult
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            PlatformUtils.isAndroid ? 8 : 12,
                          ),
                          child: _buildResultCard(theme, isDark, videoProvider),
                        )
                      : _buildEmptyState(theme, isDark, videoProvider),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 96.0 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.small(
            heroTag: 'mobile-paste-fab',
            onPressed: _pasteUrl,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.14),
              ),
            ),
            child: const Icon(Icons.content_paste_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Text(
            'AeroTube',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            splashRadius: 20,
            onPressed: () => context.read<NavigationProvider>().setIndex(3),
          ),
        ],
      ),
    );
  }

  Widget _buildInitializingBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Initializing...',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(
    ThemeData theme,
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
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
                    fontSize: 13,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildUrlInputCard(
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    final isLoading = videoProvider.isLoading;
    final hasText = _hasUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              Icons.link_rounded,
              color: Color(0xFF8B5CF6),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste link',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  textInputAction: TextInputAction.go,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _handleFetch(),
                ),
              ),
            ),
          ),
          if (hasText && !isLoading)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: () {
                _urlController.clear();
                setState(() => _hasUrl = false);
                FocusScope.of(context).unfocus();
              },
            ),
          const SizedBox(width: 2),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: isLoading || !hasText ? null : _handleFetch,
              style: FilledButton.styleFrom(
                backgroundColor: isLoading
                    ? theme.colorScheme.primary.withValues(alpha: 0.8)
                    : const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(78, 42),
                elevation: 0,
              ),
              icon: isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                isLoading ? 'Fetching' : 'Fetch',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    if (videoProvider.hasError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    videoProvider.errorMessage ?? 'Error',
                    style: TextStyle(
                      color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (videoProvider.requiresYtdlpUpdate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'yt-dlp update recommended',
                      style: TextStyle(
                        color: Color(0xFFFF8A8A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Go to Settings and update yt-dlp, then retry this link.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.78,
                        ),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<NavigationProvider>().setIndex(3),
                      icon: const Icon(
                        Icons.system_update_alt_rounded,
                        size: 16,
                      ),
                      label: const Text('Open Settings'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade200,
                        side: BorderSide(
                          color: Colors.red.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (videoProvider.fetchLogs.isNotEmpty ||
                (videoProvider.technicalError != null &&
                    videoProvider.technicalError!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              _buildFetchDiagnostics(
                theme,
                isDark,
                videoProvider,
                hasError: true,
              ),
            ],
          ],
        ),
      );
    }

    if (videoProvider.isLoading) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141417) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        videoProvider.loadingStatus.isNotEmpty
                            ? videoProvider.loadingStatus
                            : 'Fetching video information...',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    minHeight: 5,
                    color: Color(0xFF8B5CF6),
                    backgroundColor: Color(0x33222222),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildLoadingPill(
                      theme,
                      isDark,
                      icon: Icons.verified_outlined,
                      label: 'Validating URL',
                    ),
                    const SizedBox(width: 8),
                    _buildLoadingPill(
                      theme,
                      isDark,
                      icon: Icons.high_quality_outlined,
                      label: 'Reading formats',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildFetchDiagnostics(theme, isDark, videoProvider),
              ],
            ),
          ),
        ),
      );
    }

    if (videoProvider.hasVideo && videoProvider.videoInfo != null) {
      return MobileVideoConfigurationWidget(
        onDownload: _startDownload,
        onClear: _clearAndReset,
      );
    }

    if (videoProvider.hasPlaylist && videoProvider.playlistInfo != null) {
      return _buildPlaylistResult(theme, isDark, videoProvider);
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlaylistResult(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    final playlist = videoProvider.playlistInfo!;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.playlist_play,
              color: Color(0xFF8B5CF6),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${playlist.videoCount} videos',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLogo(size: 92, showGlow: true)
                  .animate()
                  .fadeIn(duration: 450.ms, delay: 40.ms)
                  .scale(
                    begin: const Offset(0.94, 0.94),
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 18),
              Text(
                    'Paste URL',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 120.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 8),
              Text(
                'Paste and fetch.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 300.ms, delay: 160.ms),
              const SizedBox(height: 18),
              _buildUrlInputCard(theme, videoProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPill(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
      _hasUrl = true;
      _urlController.selection = TextSelection.collapsed(offset: text.length);
    });

    _urlFocusNode.requestFocus();
  }

  Widget _buildFetchDiagnostics(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider, {
    bool hasError = false,
  }) {
    final logs = videoProvider.fetchLogs;
    final terminalText = logs.join('\n');
    final errorText = videoProvider.technicalError;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasError
            ? Colors.red.withValues(alpha: 0.1)
            : (isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? Colors.red.withValues(alpha: 0.35)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.terminal_rounded,
                size: 15,
                color: hasError ? Colors.red.shade300 : const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 6),
              Text(
                hasError ? 'Fetch Error Details' : 'Fetch Logs',
                style: TextStyle(
                  color: hasError
                      ? Colors.red.shade300
                      : theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Text(
                errorText != null && errorText.isNotEmpty
                    ? '$terminalText\n\n$errorText'
                    : (terminalText.isNotEmpty
                          ? terminalText
                          : 'Waiting for fetch updates...'),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: hasError
                      ? Colors.red.shade200
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
