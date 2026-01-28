import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';

import '../../models/playlist_info.dart';
import '../../models/video_info.dart';
import '../../models/download_mode.dart';
import '../../providers/video_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/glass_card.dart';

class PlaylistPreviewScreen extends StatelessWidget {
  const PlaylistPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final playlist = videoProvider.playlistInfo;
    final theme = Theme.of(context);

    if (playlist == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Sliver App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                playlist.title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
            actions: [
              IconButton(
                onPressed: () => videoProvider.selectAllVideos(true),
                icon: const Icon(Icons.select_all_rounded),
                tooltip: 'Select All',
              ),
              IconButton(
                onPressed: () => videoProvider.selectAllVideos(false),
                icon: const Icon(Icons.deselect_rounded),
                tooltip: 'Deselect All',
              ),
            ],
          ),

          // 2. Batch Settings Header
          SliverToBoxAdapter(
            child: _buildBatchSettings(context, videoProvider, theme),
          ),

          // 3. Video List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final video = playlist.videos[index];
                  return _buildModernVideoCard(
                    context,
                    video,
                    index,
                    videoProvider,
                    theme,
                  ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0);
                },
                childCount: playlist.videos.length,
              ),
            ),
          ),
          
          // Bottom Padding for Action Bar
           const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      
      // Bottom Action Bar
      bottomSheet: _buildBottomActionBar(context, playlist, theme),
    );
  }

  Widget _buildBatchSettings(BuildContext context, VideoProvider provider, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        borderRadius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Batch Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
             Row(
              children: [
                Expanded(
                  child: _buildModernDropdown<int>(
                    context: context,
                    value: provider.selectedHeight ?? 1080,
                    label: 'Resolution',
                    icon: Icons.high_quality_rounded,
                    items: [2160, 1440, 1080, 720, 480, 360],
                    displayItem: (item) => '${item}p',
                     onChanged: (val) => provider.setSelectedHeight(val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernDropdown<AudioQuality>(
                    context: context,
                    value: provider.selectedAudioQuality,
                    label: 'Audio',
                    icon: Icons.audiotrack_rounded,
                    items: AudioQuality.values,
                    displayItem: (item) => item.label,
                    onChanged: (val) => provider.setAudioQuality(val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
             Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
               child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                    children: [
                      Icon(Icons.headphones_rounded, size: 18, color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      const Text('Audio Only Mode'),
                    ],
                   ),
                   Switch(
                    value: provider.audioOnly,
                    onChanged: (val) => provider.setAudioOnly(val),
                    activeThumbColor: theme.colorScheme.secondary,
                  ),
                ],
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDropdown<T>({
    required BuildContext context,
    required T value,
    required String label,
    required IconData icon,
    required List<T> items,
    required String Function(T) displayItem,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(
          displayItem(item),
          style: const TextStyle(fontSize: 13),
           overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: onChanged,
       decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: theme.colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
      ),
      isExpanded: true,
      style: theme.textTheme.bodyMedium,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
    );
  }

  Widget _buildModernVideoCard(
    BuildContext context,
    PlaylistVideoItem video,
    int index,
    VideoProvider provider,
    ThemeData theme,
  ) {
    final isSelected = video.isSelected;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => provider.toggleVideoSelection(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected 
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1) 
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? theme.colorScheme.primary.withValues(alpha: 0.5) 
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // Checkbox Area
              SizedBox(
                width: 30, 
                child: Checkbox(
                   value: isSelected,
                   onChanged: (v) => provider.toggleVideoSelection(index),
                   activeColor: theme.colorScheme.primary,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
               
              // Thumbnail
              Stack(
                alignment: Alignment.center,
                children: [
                   ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: video.thumbnailUrl != null
                        ? Image.network(
                            video.thumbnailUrl!,
                            width: 100,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => Container(
                              width: 100, height: 56, color: Colors.grey[900]
                            ),
                          )
                        : Container(width: 100, height: 56, color: Colors.grey[900]),
                  ),
                  Container(
                    width: 100,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      // Vignette
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                   if (isSelected)
                    Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
                ],
              ),
              
              const SizedBox(width: 12),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.uploader,
                       style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                       ),
                       maxLines: 1,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Duration/Index
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    video.formattedDuration,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, PlaylistInfo playlist, ThemeData theme) {
    if (playlist.selectedCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16) + const EdgeInsets.only(bottom: 16), // Extra bottom padding
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1))),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withValues(alpha: 0.2), 
            blurRadius: 10, 
            offset: const Offset(0, -5),
           ),
        ],
      ),
      child: Row(
        children: [
          // Info Text
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${playlist.selectedCount} Selected',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Ready to download',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const Spacer(),
          // Download Button
          FilledButton.icon(
            onPressed: () => _startBatchDownload(context),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download All'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1.0, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }

  void _startBatchDownload(BuildContext context) {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final playlist = videoProvider.playlistInfo!;

    final selectedVideos = playlist.videos.where((v) => v.isSelected).toList();
    if (selectedVideos.isEmpty) return;

    final outputPath = settingsProvider.settings.outputPath ?? 
        '${Platform.environment['USERPROFILE']}Downloads';

    // Start each download
    for (final videoItem in selectedVideos) {
      final videoInfo = VideoInfo(
        id: videoItem.id,
        title: videoItem.title,
        channel: videoItem.uploader,
        channelUrl: '',
        thumbnailUrl: videoItem.thumbnailUrl ?? '',
        duration: videoItem.duration,
        description: '',
        viewCount: 0,
        uploadDate: '',
        formats: [],
        subtitles: [],
        url: videoItem.url,
      );

      downloadProvider.startDownload(
        video: videoInfo,
        outputPath: outputPath,
        mode: videoProvider.audioOnly 
            ? DownloadMode.audioOnly 
            : DownloadMode.videoWithAudio,
        targetHeight: videoProvider.selectedHeight,
        audioQuality: videoProvider.selectedAudioQuality.ytdlpValue,
        embedThumbnail: settingsProvider.settings.embedThumbnail,
        embedMetadata: settingsProvider.settings.embedMetadata,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text('Starting download of ${selectedVideos.length} videos'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    Navigator.pop(context);
    videoProvider.clear();
  }
}