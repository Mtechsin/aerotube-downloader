import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/download_mode.dart';
import '../../models/playlist_info.dart';
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
  bool _clipboardHasUrl = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoProvider = context.read<VideoProvider>();
      _videoProvider!.addListener(_onVideoUpdate);
      _checkClipboard();
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

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text != null &&
        text.isNotEmpty &&
        (text.contains('youtube.com') ||
            text.contains('youtu.be') ||
            text.contains('youtube.com/playlist'))) {
      if (mounted) {
        setState(() => _clipboardHasUrl = true);
      }
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
        Positioned.fill(
          child: ColoredBox(color: theme.scaffoldBackgroundColor),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(theme, isDark),
              if (!settingsProvider.isInitialized ||
                  !settingsProvider.isYtdlpAvailable ||
                  (settingsProvider.isYtdlpAvailable &&
                      !settingsProvider.isFfmpegAvailable))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _buildUrlInputBar(theme, videoProvider),
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
                            20,
                            0,
                            20,
                            PlatformUtils.isAndroid ? 8 : 12,
                          ),
                          child: _buildResultContent(
                            theme,
                            isDark,
                            videoProvider,
                          ),
                        )
                      : _buildEmptyState(theme, isDark, videoProvider),
                ),
              ),
            ],
          ),
        ),
        if (!hasResult)
          Positioned(
            right: 20,
            bottom: 100.0 + MediaQuery.of(context).padding.bottom,
            child: _buildPasteFab(theme, isDark),
          ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Text(
            'AeroTube',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (PlatformUtils.isAndroid)
            _buildHeaderIcon(
              theme,
              isDark,
              icon: Icons.home_outlined,
              onTap: () {
                final nav = context.read<NavigationProvider>();
                Navigator.of(context).popUntil((route) => route.isFirst);
                nav.switchToHome();
              },
            ),
          _buildHeaderIcon(
            theme,
            isDark,
            icon: Icons.settings_outlined,
            onTap: () => context.read<NavigationProvider>().setIndex(3),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildInitializingBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
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
          const SizedBox(width: 12),
          Text(
            'Initializing...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 13,
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
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

  Widget _buildUrlInputBar(ThemeData theme, VideoProvider videoProvider) {
    final isLoading = videoProvider.isLoading;
    final hasText = _hasUrl;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark(theme)
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.link_rounded,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Paste a link...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
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
          if (hasText && !isLoading)
            GestureDetector(
              onTap: () {
                _urlController.clear();
                setState(() => _hasUrl = false);
                FocusScope.of(context).unfocus();
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading || !hasText ? null : _handleFetch,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isLoading || !hasText
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      )
                    : const Text(
                        'Fetch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  bool isDark(ThemeData theme) => theme.brightness == Brightness.dark;

  Widget _buildResultContent(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    if (videoProvider.hasError) {
      return _buildErrorState(theme, isDark, videoProvider);
    }

    if (videoProvider.isLoading) {
      return _buildLoadingState(theme, isDark, videoProvider);
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

  Widget _buildErrorState(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  videoProvider.errorMessage ?? 'Error',
                  style: TextStyle(
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (videoProvider.requiresYtdlpUpdate) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'yt-dlp update recommended',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to Settings and update yt-dlp, then retry.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.read<NavigationProvider>().setIndex(3),
                      icon: const Icon(
                        Icons.system_update_alt_rounded,
                        size: 15,
                      ),
                      label: const Text(
                        'Open Settings',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade200,
                        side: BorderSide(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
            _buildDiagnostics(theme, isDark, videoProvider, hasError: true),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
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
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildLoadingChip(
                    theme,
                    isDark,
                    icon: Icons.verified_outlined,
                    label: 'Validating URL',
                  ),
                  const SizedBox(width: 8),
                  _buildLoadingChip(
                    theme,
                    isDark,
                    icon: Icons.high_quality_outlined,
                    label: 'Reading formats',
                  ),
                ],
              ),
              if (videoProvider.fetchLogs.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildDiagnostics(theme, isDark, videoProvider),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistResult(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    final playlist = videoProvider.playlistInfo!;
    final allSelected = playlist.videos.every((v) => v.isSelected);
    final selectedCount = playlist.selectedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Playlist header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.playlist_play_rounded,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.videoCount} videos',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Select all / Deselect all row
        Row(
          children: [
            TextButton.icon(
              onPressed: () => videoProvider.selectAllVideos(true),
              icon: Icon(Icons.select_all, size: 16,
                  color: theme.colorScheme.primary),
              label: Text('Select All',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => videoProvider.selectAllVideos(false),
              icon: Icon(Icons.deselect, size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              label: Text('Deselect All',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '$selectedCount / ${playlist.videoCount} selected',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Video list
        Expanded(
          child: ListView.separated(
            itemCount: playlist.videos.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            itemBuilder: (context, index) {
              final video = playlist.videos[index];
              return _buildPlaylistVideoItem(
                theme, video, videoProvider, index,
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Download selected button
        FilledButton.icon(
          onPressed: selectedCount > 0
              ? () => _startPlaylistDownloads(playlist, videoProvider)
              : null,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(
            selectedCount > 0
                ? 'Download Selected ($selectedCount)'
                : 'Select Videos to Download',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistVideoItem(
    ThemeData theme,
    PlaylistVideoItem video,
    VideoProvider videoProvider,
    int index,
  ) {
    return InkWell(
      onTap: () => videoProvider.toggleVideoSelection(index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: video.isSelected
                    ? const Color(0xFF8B5CF6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: video.isSelected
                      ? const Color(0xFF8B5CF6)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: video.isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: video.thumbnailUrl != null
                      ? Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.movie_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        )
                      : Icon(
                          Icons.movie_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (video.channel.isNotEmpty) ...[
                        Text(
                          video.channel,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        video.formattedDuration,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPlaylistDownloads(
    PlaylistInfo playlist,
    VideoProvider videoProvider,
  ) async {
    final downloadProvider = context.read<MobileDownloadProvider>();
    final selectedVideos =
        playlist.videos.where((v) => v.isSelected).toList();

    if (selectedVideos.isEmpty) return;

    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting ${selectedVideos.length} downloads...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    for (final video in selectedVideos) {
      try {
        await downloadProvider.addDownload(
          url: video.url,
          title: video.title,
          thumbnailUrl: video.thumbnailUrl,
          mode: DownloadMode.videoWithAudio,
          formatId: null, // best quality default
          options: {
            'audioFormatId': null,
            'targetHeight': null,
            'audioQuality': '0',
            'embedSubtitles': false,
            'subtitleLanguages': <String>[],
          },
        );
      } catch (e) {
        // Log error but continue with remaining videos
        debugPrint('Failed to queue playlist video: $e');
      }
    }

    snackBar.close();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selectedVideos.length} download${selectedVideos.length == 1 ? '' : 's'} started',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              AppLogo(size: 80, showGlow: true)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 40.ms)
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 28),
              Text(
                'AeroTube',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 120.ms)
                  .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 10),
              Text(
                'Paste a YouTube link to\nget started',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 400.ms, delay: 180.ms),
              const SizedBox(height: 32),
              _buildEmptyUrlInput(theme, isDark, videoProvider)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 240.ms)
                  .slideY(begin: 0.06, end: 0),
              if (_clipboardHasUrl) ...[
                const SizedBox(height: 14),
                _buildClipboardChip(theme, isDark)
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 360.ms)
                    .slideY(begin: 0.1, end: 0),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyUrlInput(
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    final isLoading = videoProvider.isLoading;
    final hasText = _hasUrl;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.link_rounded,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Paste a YouTube link...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
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
          if (hasText && !isLoading)
            GestureDetector(
              onTap: () {
                _urlController.clear();
                setState(() => _hasUrl = false);
                FocusScope.of(context).unfocus();
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading || !hasText ? null : _handleFetch,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isLoading || !hasText
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      )
                    : const Text(
                        'Fetch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildClipboardChip(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: _pasteUrl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.content_paste_rounded,
              size: 16,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Text(
              'Paste from clipboard',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasteFab(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: _pasteUrl,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          Icons.content_paste_rounded,
          color: theme.colorScheme.primary.withValues(alpha: 0.8),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLoadingChip(
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
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
      _clipboardHasUrl = false;
      _urlController.selection = TextSelection.collapsed(offset: text.length);
    });

    _urlFocusNode.requestFocus();
  }

  Widget _buildDiagnostics(
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
            ? Colors.red.withValues(alpha: 0.06)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.terminal_rounded,
                size: 14,
                color: hasError
                    ? Colors.red.shade300
                    : theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                hasError ? 'Error Details' : 'Fetch Logs',
                style: TextStyle(
                  color: hasError
                      ? Colors.red.shade300
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Text(
                errorText != null && errorText.isNotEmpty
                    ? '$terminalText\n\n$errorText'
                    : (terminalText.isNotEmpty
                          ? terminalText
                          : 'Waiting for updates...'),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: hasError
                      ? Colors.red.shade200
                      : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
