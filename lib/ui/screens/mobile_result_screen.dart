import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../models/download_mode.dart';
import '../../models/playlist_info.dart';
import '../../models/video_info.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/video_provider.dart';
import '../components/components.dart';
import '../widgets/mobile_video_configuration_widget.dart';

class MobileResultScreen extends StatefulWidget {
  const MobileResultScreen({super.key});

  @override
  State<MobileResultScreen> createState() => _MobileResultScreenState();
}

class _MobileResultScreenState extends State<MobileResultScreen> {
  /// Leaves the Fetched Info stack and lands on the Downloads tab so the
  /// user immediately sees the item they just started.
  void _goToDownloads({required String message}) {
    final messenger = ScaffoldMessenger.of(context);
    final nav = context.read<NavigationProvider>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    nav.setIndex(2);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Symbols.download_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<MobileDownloadProvider>();

    if (videoProvider.videoInfo == null) return;

    final title = videoProvider.videoInfo!.title;
    final selectedSubtitleLanguages = videoProvider.selectedSubtitles
        .map((s) => s.languageCode)
        .toList();

    final estimatedSize = videoProvider.totalEstimatedDownloadSize;
    // H18: only claim success after the provider actually queues the item.
    final queued = await downloadProvider.addDownload(
      url: videoProvider.currentUrl,
      title: title,
      thumbnailUrl: videoProvider.videoInfo!.thumbnailUrl,
      mode: videoProvider.audioOnly
          ? DownloadMode.audioOnly
          : DownloadMode.videoWithAudio,
      formatId: videoProvider.selectedVideoFormatId,
      estimatedFileSize: estimatedSize > 0 ? estimatedSize : null,
      options: {
        'audioFormatId': videoProvider.selectedAudioFormatId,
        'targetHeight': videoProvider.selectedHeight,
        'audioQuality': videoProvider.selectedAudioQuality.ytdlpValue,
        'embedSubtitles': videoProvider.embedSubtitles,
        'subtitleLanguages': selectedSubtitleLanguages,
        'estimatedFileSize': estimatedSize > 0 ? estimatedSize : null,
      },
    );

    if (!mounted) return;
    if (!queued) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Already in queue: $title'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    _goToDownloads(message: 'Download started: $title');
    // Clear after leaving so Fetched Info doesn't flash an empty shell.
    videoProvider.clear();
  }

  Widget _buildPlaylistScreen(
    BuildContext context,
    AeroColors aero,
    VideoProvider videoProvider,
  ) {
    final playlist = videoProvider.playlistInfo!;
    final selectedCount = playlist.selectedCount;

    return Scaffold(
      backgroundColor: aero.bg,
      appBar: AppBar(
        backgroundColor: aero.surface1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Playlist Info', style: AeroText.titleSm),
        actions: [
          IconButton(
            icon: const Icon(Symbols.home_rounded),
            tooltip: 'Home',
            onPressed: () {
              final nav = context.read<NavigationProvider>();
              Navigator.of(context).popUntil((route) => route.isFirst);
              nav.switchToHome();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AeroSpace.lg,
              AeroSpace.md,
              AeroSpace.lg,
              100, // Space for sticky bottom bar
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Playlist Header Banner
                AeroCard(
                  borderRadius: AeroRadius.mdBorderRadius,
                  backgroundColor: aero.surface1,
                  borderColor: aero.outline,
                  padding: const EdgeInsets.all(AeroSpace.md),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: aero.primarySoft,
                          borderRadius: AeroRadius.smBorderRadius,
                          border: Border.all(color: aero.primary, width: 1.0),
                        ),
                        child: Icon(
                          Symbols.playlist_play_rounded,
                          color: aero.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AeroSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.title,
                              style: AeroText.titleSm.copyWith(
                                color: aero.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${playlist.videoCount} videos',
                              style: AeroText.caption.copyWith(
                                color: aero.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AeroSpace.sm),

                // Selection toolbar
                Row(
                  children: [
                    AeroButton(
                      variant: AeroButtonVariant.ghost,
                      text: 'Select All',
                      icon: const Icon(Symbols.select_all_rounded, size: 16),
                      onPressed: () => videoProvider.selectAllVideos(true),
                    ),
                    const SizedBox(width: AeroSpace.xs),
                    AeroButton(
                      variant: AeroButtonVariant.ghost,
                      text: 'Deselect All',
                      icon: const Icon(Symbols.deselect_rounded, size: 16),
                      onPressed: () => videoProvider.selectAllVideos(false),
                    ),
                    const Spacer(),
                    Text(
                      '$selectedCount / ${playlist.videoCount} selected',
                      style: AeroText.caption.copyWith(
                        color: aero.onSurfaceMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AeroSpace.sm),

                // Table-style Video List
                Expanded(
                  child: ListView.separated(
                    itemCount: playlist.videos.length,
                    // ignore: deprecated_member_use
                    cacheExtent: 200.0,
                    addRepaintBoundaries: true,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AeroSpace.xs),
                    itemBuilder: (context, index) {
                      final video = playlist.videos[index];
                      return _buildPlaylistVideoItem(
                        aero,
                        video,
                        videoProvider,
                        index,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                AeroSpace.lg,
                AeroSpace.md,
                AeroSpace.lg,
                MediaQuery.paddingOf(context).bottom + AeroSpace.md,
              ),
              decoration: BoxDecoration(
                color: aero.surface1,
                border: Border(
                  top: BorderSide(color: aero.outline, width: 1.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: AeroButton(
                  variant: AeroButtonVariant.primary,
                  expand: true,
                  icon: const Icon(Symbols.download_rounded, size: 18),
                  text: selectedCount > 0
                      ? 'Download Selected ($selectedCount)'
                      : 'Select Videos to Download',
                  onPressed: selectedCount > 0
                      ? () => _startPlaylistDownloads(playlist, videoProvider)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistVideoItem(
    AeroColors aero,
    PlaylistVideoItem video,
    VideoProvider videoProvider,
    int index,
  ) {
    return AeroCard(
      selected: video.isSelected,
      borderRadius: AeroRadius.mdBorderRadius,
      backgroundColor: video.isSelected ? aero.primarySoft : aero.surface1,
      borderColor: video.isSelected ? aero.primary : aero.outline,
      padding: const EdgeInsets.all(AeroSpace.sm),
      onTap: () => videoProvider.toggleVideoSelection(index),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: video.isSelected,
            onChanged: (_) => videoProvider.toggleVideoSelection(index),
            activeColor: aero.primary,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(color: aero.outlineStrong, width: 1.5),
          ),
          const SizedBox(width: AeroSpace.xs),

          // 96 px thumbnail
          ThumbnailTile(
            imageUrl: video.thumbnailUrl,
            duration: video.formattedDuration,
            width: 96,
            height: 54,
            borderRadius: AeroRadius.smBorderRadius,
          ),
          const SizedBox(width: AeroSpace.md),

          // Title & Channel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  style: AeroText.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: video.isSelected
                        ? aero.onSurface
                        : aero.onSurfaceMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (video.channel.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          video.channel,
                          style: AeroText.caption.copyWith(
                            color: aero.onSurfaceFaint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AeroSpace.xs),
                      Text(
                        '·',
                        style: AeroText.caption.copyWith(
                          color: aero.onSurfaceFaint,
                        ),
                      ),
                      const SizedBox(width: AeroSpace.xs),
                    ],
                    Text(
                      video.formattedDuration,
                      style: AeroText.caption.withTabularFigures().copyWith(
                        color: aero.onSurfaceFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPlaylistDownloads(
    PlaylistInfo playlist,
    VideoProvider videoProvider,
  ) async {
    final downloadProvider = context.read<MobileDownloadProvider>();
    final selectedVideos = playlist.videos.where((v) => v.isSelected).toList();

    if (selectedVideos.isEmpty) return;

    // PF10 fix (mobile parity): single batched enqueue instead of one
    // addDownload call per video (N Hive writes + N UI rebuilds).
    final added = await downloadProvider.startDownloadsBatch(
      items: selectedVideos
          .map(
            (v) => (url: v.url, title: v.title, thumbnailUrl: v.thumbnailUrl),
          )
          .toList(),
      mode: DownloadMode.videoWithAudio,
      options: {
        'audioFormatId': null,
        'targetHeight': null,
        'audioQuality': '0',
        'embedSubtitles': false,
        'subtitleLanguages': <String>[],
      },
    );

    if (!mounted) return;
    _goToDownloads(
      message:
          '$added of ${selectedVideos.length} download${selectedVideos.length == 1 ? '' : 's'} queued',
    );
    videoProvider.clear();
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final aero = context.aero;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Let Android preview the previous route before committing the gesture.
        if (didPop && videoProvider.isLoading) {
          videoProvider.cancelFetch();
        }
      },
      child:
          videoProvider.hasVideo ||
              videoProvider.isLoading ||
              videoProvider.hasError
          ? MobileVideoConfigurationWidget(
              onDownload: _startDownload,
              onClear: () {
                if (videoProvider.isLoading) {
                  videoProvider.cancelFetch();
                }
                videoProvider.clear();
                Navigator.pop(context);
              },
            )
          : videoProvider.hasPlaylist && videoProvider.playlistInfo != null
          ? _buildPlaylistScreen(context, aero, videoProvider)
          : Scaffold(
              backgroundColor: aero.bg,
              appBar: AppBar(
                backgroundColor: aero.surface1,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Symbols.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Center(
                child: EmptyState(
                  icon: Symbols.movie_rounded,
                  title: 'Nothing to show',
                  description: 'No active video or playlist found.',
                ),
              ),
            ),
    );
  }
}
