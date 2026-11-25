import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/download_item.dart';
import '../../models/download_mode.dart';
import '../../models/video_info.dart';
import '../../providers/download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/video_provider.dart';
import '../../services/core/file_action_service.dart';
import '../components/components.dart';
import '../widgets/video_configuration_widget.dart';
import 'mobile_home_layout.dart';
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
      _onVideoProviderChange();
    });
  }

  bool _isShowingAuthDialog = false;
  bool _isFetchNavigating = false;
  String? _lastAuthErrorMessage;

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

  @override
  Widget build(BuildContext context) {
    final vp = context
        .select<
          VideoProvider,
          ({
            bool hasVideo,
            bool isLoading,
            bool hasError,
            String? errorMessage,
            String loadingStatus,
          })
        >(
          (p) => (
            hasVideo: p.hasVideo,
            isLoading: p.isLoading,
            hasError: p.hasError,
            errorMessage: p.errorMessage,
            loadingStatus: p.loadingStatus,
          ),
        );

    final screenType = ResponsiveLayout.getScreenType(context);
    if (screenType == ScreenType.mobile) {
      return const MobileHomeLayout();
    }

    return Stack(
      children: [
        // Content Area
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: vp.hasVideo
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: _buildCommandCapsule(
                                context,
                                context.read<VideoProvider>(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: VideoConfigurationWidget(
                              onDownload: _startDownload,
                              onClear: () {
                                context.read<VideoProvider>().clear();
                                _urlController.clear();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildDesktopHomeLayout(
                    context,
                    context.read<VideoProvider>(),
                  ),
          ),
        ),
      ],
    );
  }

  /// Command capsule shown at top of the result / configuration view.
  Widget _buildCommandCapsule(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    return UrlComposer(
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
      maxWidth: 860,
    ).animate().slideY(begin: -0.18, curve: AppMotion.decelerate, duration: 180.ms).fadeIn(duration: 140.ms);
  }

  /// One readable workspace keeps the form and activity on the same grid.
  Widget _buildDesktopHomeLayout(
    BuildContext context,
    VideoProvider videoProvider,
  ) {
    final colors = context.aero;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New download',
                style: AeroText.headline.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: AeroSpace.sm),
              Text(
                'Choose video or audio, then save it to your device.',
                style: AeroText.body.copyWith(color: colors.onSurfaceMuted),
              ),
              const SizedBox(height: AeroSpace.xl),
              _buildDownloadForm(context, videoProvider),
              const SizedBox(height: AeroSpace.xxl + 8),
              Divider(height: 1, color: colors.outline),
              const SizedBox(height: AeroSpace.xl),
              _buildRightActivityPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadForm(BuildContext context, VideoProvider videoProvider) {
    final colors = context.aero;
    final settings = context.watch<PlatformSettingsProvider>();
    final destination = settings.outputPath ?? 'Downloads folder';
    return AeroCard(
      hoverable: false,
      borderRadius: AeroRadius.lgBorderRadius,
      padding: const EdgeInsets.all(AeroSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Video or playlist link',
            style: AeroText.label.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AeroSpace.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final composer = UrlComposer(
                controller: _urlController,
                focusNode: _urlFocusNode,
                height: 56,
                showPasteButton: true,
                showFetchButton: false,
                onFetch: () => _handleFetch(videoProvider),
                onCancel: () => videoProvider.cancelFetch(),
                isLoading: videoProvider.isLoading,
                statusMessage: videoProvider.loadingStatus.isEmpty
                    ? null
                    : videoProvider.loadingStatus,
                errorMessage: videoProvider.hasError
                    ? videoProvider.errorMessage
                    : null,
                hintText: 'https://www.youtube.com/watch?v=…',
              );
              final action = ValueListenableBuilder<TextEditingValue>(
                valueListenable: _urlController,
                builder: (context, value, _) => AeroButton(
                  text: videoProvider.isLoading ? 'Cancel' : 'Choose format',
                  icon: Icon(
                    videoProvider.isLoading
                        ? Symbols.close_rounded
                        : Symbols.arrow_forward_rounded,
                    size: 18,
                  ),
                  height: 56,
                  expand: constraints.maxWidth < 650,
                  tooltip: videoProvider.isLoading
                      ? 'Cancel fetch'
                      : 'Choose format (Enter)',
                  variant: videoProvider.isLoading
                      ? AeroButtonVariant.tonal
                      : AeroButtonVariant.primary,
                  // Empty submission simply focuses the input, keeping the next step visible.
                  onPressed: videoProvider.isLoading
                      ? () => videoProvider.cancelFetch()
                      : () {
                          if (value.text.trim().isEmpty) {
                            _urlFocusNode.requestFocus();
                          } else {
                            _handleFetch(videoProvider);
                          }
                        },
                ),
              );
              if (constraints.maxWidth >= 650) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: composer),
                    const SizedBox(width: AeroSpace.md),
                    action,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  composer,
                  const SizedBox(height: AeroSpace.md),
                  action,
                ],
              );
            },
          ),
          const SizedBox(height: AeroSpace.lg),
          Row(
            children: [
              Icon(
                Symbols.folder_rounded,
                size: 16,
                color: colors.onSurfaceMuted,
              ),
              const SizedBox(width: AeroSpace.sm),
              Expanded(
                child: Tooltip(
                  message: destination,
                  child: Text(
                    'Save to $destination',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AeroText.caption.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.read<NavigationProvider>().switchToSettings(),
                child: const Text('Change folder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Activity follows the form at full width; every action has a visible label.
  Widget _buildRightActivityPanel(BuildContext context) {
    final colors = context.aero;
    final active = context.select<DownloadProvider, List<DownloadItem>>(
      (p) => p.activeDownloads,
    );
    final history = context.select<DownloadProvider, List<DownloadItem>>(
      (p) => p.historyDownloads,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent activity',
                style: AeroText.titleSm.copyWith(color: colors.onSurface),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  context.read<NavigationProvider>().switchToLibrary(),
              label: const Text('View library'),
              icon: const Icon(Symbols.arrow_forward_rounded, size: 16),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
        const SizedBox(height: AeroSpace.md),
        if (active.isNotEmpty) ...[
          SectionHeader(
            title: 'Active · ${active.length}',
            margin: const EdgeInsets.only(bottom: AeroSpace.sm),
          ),
          ...active.take(3).map((item) => _ActiveDownloadCard(item: item)),
        ],
        if (history.isNotEmpty) ...[
          if (active.isNotEmpty) const SizedBox(height: AeroSpace.md),
          ...history.take(5).map((item) => _DesktopHistoryTile(item: item)),
        ],
        if (active.isEmpty && history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AeroSpace.lg),
            child: Row(
              children: [
                Icon(
                  Symbols.history_rounded,
                  size: 24,
                  color: colors.onSurfaceFaint,
                ),
                const SizedBox(width: AeroSpace.md),
                Expanded(
                  child: Text(
                    'Your downloads will appear here.',
                    style: AeroText.bodySm.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleFetch(VideoProvider videoProvider) async {
    // H22: ignore double-taps while a fetch/navigation is already in flight.
    if (_isFetchNavigating) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    _isFetchNavigating = true;

    // Apply default quality from settings before fetching formats.
    final settings = context.read<PlatformSettingsProvider>();
    videoProvider.setPreferredQuality(settings.defaultQuality);

    if (url.contains('list=') || url.contains('/playlist')) {
      if (!mounted) {
        _isFetchNavigating = false;
        return;
      }
      try {
        context.read<PlaylistProvider>().fetchPlaylist(url);

        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlaylistScreen()),
        );
      } finally {
        _isFetchNavigating = false;
      }
    } else {
      videoProvider.fetchVideoInfo(url);
      // Release the guard on the next frame so a deliberate retry is possible
      // if fetch fails immediately without navigating.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isFetchNavigating = false;
      });
    }
  }

  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    final settingsProvider = context.read<PlatformSettingsProvider>();

    if (videoProvider.videoInfo == null) return;

    final video = videoProvider.videoInfo!;
    final outputPath =
        settingsProvider.settings.outputPath ??
        await settingsProvider.getDefaultOutputPath();

    final estimatedSize = videoProvider.totalEstimatedDownloadSize;
    // H18: only claim success after the provider actually queues the item.
    final queued = await downloadProvider.startDownload(
      video: video,
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
    if (!queued) {
      // H19: duplicate tap must not look like a silent no-op.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Already in queue: ${video.title}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Symbols.download_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Download started: ${video.title}',
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

/// Active download card with live progress bar and pause/cancel controls.
class _ActiveDownloadCard extends StatelessWidget {
  final DownloadItem item;

  const _ActiveDownloadCard({required this.item});

  String _formatActiveSubtitle() {
    switch (item.status) {
      case DownloadStatus.merging:
        return 'Merging audio & video…';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.pending:
        return 'Preparing…';
      default:
        final speedMb = (item.speed / (1024 * 1024)).toStringAsFixed(1);
        final quality = item.videoQuality ?? (item.audioOnly ? 'MP3' : 'MP4');
        if (item.eta > 0) {
          final m = item.eta ~/ 60;
          final s = item.eta % 60;
          final etaStr = m > 0 ? '${m}m ${s}s' : '${s}s';
          return '$quality · $speedMb MB/s · $etaStr left';
        }
        return '$quality · $speedMb MB/s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final dp = context.read<DownloadProvider>();
    final progressValue = item.progress > 0
        ? (item.progress / 100.0).clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AeroSpace.sm),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: AeroRadius.mdBorderRadius,
          border: Border.all(color: colors.outline, width: 0.8),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ThumbnailTile(
              imageUrl: item.thumbnailUrl,
              width: 60,
              height: 33.75,
              borderRadius: BorderRadius.circular(6.0),
            ),
            const SizedBox(width: AeroSpace.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AeroText.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.progress.toStringAsFixed(0)}%',
                        style: AeroText.label.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  AeroProgress(value: progressValue, height: 4.0),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatActiveSubtitle(),
                          style: AeroText.caption.copyWith(
                            color: colors.onSurfaceMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _DesktopMiniAction(
                        icon: item.status == DownloadStatus.paused
                            ? Symbols.play_arrow_rounded
                            : Symbols.pause_rounded,
                        tooltip: item.status == DownloadStatus.paused
                            ? 'Resume'
                            : 'Pause',
                        onTap: () {
                          if (item.status == DownloadStatus.paused) {
                            dp.resumeDownload(item.id);
                          } else {
                            dp.pauseDownload(item.id);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      _DesktopMiniAction(
                        icon: Symbols.close_rounded,
                        tooltip: 'Cancel',
                        onTap: () => dp.cancelDownload(item.id),
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
}

/// History row tile for desktop activity panel.
class _DesktopHistoryTile extends StatelessWidget {
  final DownloadItem item;

  const _DesktopHistoryTile({required this.item});

  String _formatFormatBadge() {
    if (item.audioOnly) return 'MP3';
    if (item.videoQuality != null && item.videoQuality!.trim().isNotEmpty) {
      final q = item.videoQuality!.trim();
      return q.toLowerCase().contains('mp4') ? q : '$q MP4';
    }
    return 'Video';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0 && now.day == date.day) {
      return 'Today';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != date.day)) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    if (item.status != DownloadStatus.completed) {
      context.read<NavigationProvider>().switchToLibrary();
      return;
    }
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AeroRadius.mdBorderRadius,
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                ThumbnailTile(
                  imageUrl: item.thumbnailUrl,
                  width: 80,
                  height: 45,
                  borderRadius: BorderRadius.circular(6.0),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface2,
                              borderRadius: AeroRadius.fullBorderRadius,
                              border: Border.all(
                                color: colors.outline,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _formatFormatBadge(),
                              style: AeroText.caption.copyWith(
                                color: colors.onSurfaceMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (item.completedDate != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(item.completedDate!),
                              style: AeroText.caption.copyWith(
                                color: colors.onSurfaceFaint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AeroSpace.xs),
                Text(
                  item.status == DownloadStatus.completed
                      ? 'Completed'
                      : item.status == DownloadStatus.failed
                      ? 'Failed'
                      : 'Cancelled',
                  style: AeroText.caption.copyWith(
                    color: item.status == DownloadStatus.completed
                        ? colors.success
                        : colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini icon button for inline actions in the active download card.
class _DesktopMiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _DesktopMiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(icon, size: 14, color: colors.onSurfaceMuted),
          ),
        ),
      ),
    );
  }
}
