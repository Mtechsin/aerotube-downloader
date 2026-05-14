import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/download_mode.dart';
import '../../models/playlist_info.dart';
import '../../models/video_info.dart';
import '../widgets/mobile_video_configuration_widget.dart';

class MobileResultScreen extends StatefulWidget {
  const MobileResultScreen({super.key});

  @override
  State<MobileResultScreen> createState() => _MobileResultScreenState();
}

class _MobileResultScreenState extends State<MobileResultScreen> {
  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<MobileDownloadProvider>();

    if (videoProvider.videoInfo == null) return;

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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download started: ${videoProvider.videoInfo!.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPlaylistContent(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    final playlist = videoProvider.playlistInfo!;
    final selectedCount = playlist.selectedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Playlist header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.playlist_play_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
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
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
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
            cacheExtent: 200.0,
            addRepaintBoundaries: true,
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

    ScaffoldMessenger.of(context).showSnackBar(
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
          formatId: null,
          options: {
            'audioFormatId': null,
            'targetHeight': null,
            'audioQuality': '0',
            'embedSubtitles': false,
            'subtitleLanguages': <String>[],
          },
        );
      } catch (e) {
        debugPrint('Failed to queue playlist video: $e');
      }
    }

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

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Fetched Info',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (PlatformUtils.isAndroid)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Home',
              onPressed: () {
                final nav = context.read<NavigationProvider>();
                Navigator.of(context).popUntil((route) => route.isFirst);
                nav.switchToHome();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (videoProvider.hasVideo ||
                  videoProvider.isLoading ||
                  videoProvider.hasError)
                Expanded(
                  child: MobileVideoConfigurationWidget(
                    onDownload: _startDownload,
                    onClear: () {
                      videoProvider.clear();
                      Navigator.pop(context);
                    },
                  ),
                )
              else if (videoProvider.hasPlaylist &&
                  videoProvider.playlistInfo != null)
                Expanded(
                  child: _buildPlaylistContent(
                    context,
                    theme,
                    videoProvider,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
