import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/error_helper.dart';
import '../../models/video_info.dart';
import '../../providers/download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/playlist_provider.dart';
import '../components/components.dart';
import '../widgets/playlist_video_card.dart';

/// Screen for loading, configuring, and batch downloading playlists.
///
/// Features:
/// - Top bar: Select all / none, item count, total size estimate, and batch quality chips.
/// - Table-style list with checkbox, 96 px thumbnail, title, duration, and per-row quality override.
/// - Sticky bottom bar: "Download N selected".
/// - Clean Aero tokens replacing glass cards and box shadows.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late TextEditingController _urlController;
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _itemQualityOverrides = {};

  @override
  void initState() {
    super.initState();
    final currentUrl = context.read<PlaylistProvider>().currentUrl;
    _urlController = TextEditingController(text: currentUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFetch() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      _itemQualityOverrides.clear();
      context.read<PlaylistProvider>().fetchPlaylist(url);
    }
  }

  Future<void> _downloadSelected() async {
    final provider = context.read<PlaylistProvider>();
    if (provider.playlist == null || provider.selectedCount == 0) return;

    final downloadProvider = context.read<DownloadProvider>();
    final settingsProvider = context.read<PlatformSettingsProvider>();

    final selectedCount = provider.selectedCount;
    final outputPath =
        settingsProvider.settings.outputPath ??
        await settingsProvider.getDefaultOutputPath();

    await provider.downloadSelected(downloadProvider, outputPath);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Queued $selectedCount playlist video${selectedCount == 1 ? '' : 's'}.',
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            final nav = Navigator.of(context, rootNavigator: true);
            if (nav.canPop()) nav.popUntil((route) => route.isFirst);
            context.read<NavigationProvider>().switchToLibrary();
          },
        ),
      ),
    );
  }

  String _formatTotalEstimatedSize(PlaylistProvider provider) {
    final playlist = provider.playlist;
    if (playlist == null || provider.selectedCount == 0) return '0 MB';

    int bytesPerSecond;
    if (provider.audioOnly) {
      bytesPerSecond = 20 * 1024; // ~160kbps
    } else {
      switch (provider.selectedFormatId) {
        case '2160':
          bytesPerSecond = 2500 * 1024;
          break;
        case '1440':
          bytesPerSecond = 1250 * 1024;
          break;
        case '1080':
          bytesPerSecond = 560 * 1024;
          break;
        case '720':
          bytesPerSecond = 310 * 1024;
          break;
        case '480':
          bytesPerSecond = 150 * 1024;
          break;
        default:
          bytesPerSecond = 560 * 1024; // 1080p default
      }
    }

    int totalSeconds = 0;
    for (final video in playlist.videos) {
      if (provider.selectedIds.contains(video.id)) {
        totalSeconds += video.duration;
      }
    }

    final totalBytes = totalSeconds * bytesPerSecond;
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final provider = context.watch<PlaylistProvider>();
    final playlist = provider.playlist;

    return Scaffold(
      backgroundColor: aero.bg,
      appBar: AppBar(
        title: Text('Playlist downloads', style: AeroText.titleSm),
        centerTitle: false,
        backgroundColor: aero.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AeroSpace.xl,
                    AeroSpace.lg,
                    AeroSpace.xl,
                    AeroSpace.md,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: UrlComposer(
                        controller: _urlController,
                        onFetch: _handleFetch,
                        onCancel: provider.cancelFetch,
                        isLoading: provider.isLoading,
                        statusMessage: provider.loadingStatus,
                        showPasteButton: true,
                        hintText: 'Paste a playlist URL…',
                      ),
                    ),
                  ),
                ),

                // Main content
                Expanded(
                  child: provider.isLoading
                      ? _buildLoadingState(aero, provider)
                      : provider.error != null
                      ? _buildErrorState(aero, provider)
                      : playlist == null
                      ? _buildEmptyState(aero)
                      : _buildPlaylistContent(context, aero, provider),
                ),
              ],
            ),
          ),

          // Sticky Bottom Bar
          if (playlist != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(context, aero, provider),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AeroColors aero) {
    return Center(
      child: EmptyState(
        icon: Symbols.playlist_play_rounded,
        title: 'Load a playlist',
        description:
            'Paste a playlist link above to choose videos and download settings.',
      ),
    );
  }

  Widget _buildLoadingState(AeroColors aero, PlaylistProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(AeroSpace.xl),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: aero.primary,
                ),
              ),
              const SizedBox(width: AeroSpace.md),
              Expanded(
                child: Text(
                  provider.loadingStatus ?? 'Loading playlist...',
                  style: AeroText.bodySm.copyWith(color: aero.onSurfaceMuted),
                ),
              ),
              AeroButton(
                variant: AeroButtonVariant.ghost,
                text: 'Cancel',
                onPressed: () => provider.cancelFetch(),
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.xl),
          // Skeleton playlist rows
          Expanded(
            child: ListView.separated(
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: AeroSpace.sm),
              itemBuilder: (_, __) => AeroCard(
                borderRadius: AeroRadius.mdBorderRadius,
                backgroundColor: aero.surface1,
                borderColor: aero.outline,
                padding: const EdgeInsets.all(AeroSpace.sm),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: aero.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: AeroSpace.sm),
                    Container(
                      width: 96,
                      height: 54,
                      decoration: BoxDecoration(
                        color: aero.surface2,
                        borderRadius: AeroRadius.smBorderRadius,
                      ),
                    ),
                    const SizedBox(width: AeroSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 180,
                            decoration: BoxDecoration(
                              color: aero.surface2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 10,
                            width: 100,
                            decoration: BoxDecoration(
                              color: aero.surface2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AeroColors aero, PlaylistProvider provider) {
    final errorHelper = provider.error != null
        ? ErrorHelper.parse(provider.error!)
        : null;

    return Center(
      child: EmptyState(
        icon: Symbols.error_rounded,
        title: errorHelper?.friendlyMessage ?? 'Error Loading Playlist',
        description:
            errorHelper?.suggestion ?? provider.error ?? 'Unknown error',
        actionLabel: 'Try again',
        onAction: _handleFetch,
      ),
    );
  }

  Widget _buildPlaylistContent(
    BuildContext context,
    AeroColors aero,
    PlaylistProvider provider,
  ) {
    final playlist = provider.playlist!;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 1. Playlist Summary Banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AeroSpace.lg,
              0,
              AeroSpace.lg,
              AeroSpace.sm,
            ),
            child: AeroCard(
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
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${playlist.videoCount} videos · ${playlist.uploader.isNotEmpty ? playlist.uploader : "YouTube Playlist"}',
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
          ),
        ),

        // 2. Sticky Controls Header: Select All/None, Count, Total Size Estimate, Batch Quality Chips
        SliverPersistentHeader(
          pinned: true,
          delegate: _PlaylistControlsHeaderDelegate(
            provider: provider,
            aero: aero,
            totalSizeEstimate: _formatTotalEstimatedSize(provider),
          ),
        ),

        // 3. Table-style video list
        SliverPadding(
          padding: const EdgeInsets.only(top: AeroSpace.sm),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final video = playlist.videos[index];
              final isSelected = provider.selectedIds.contains(video.id);
              final override = _itemQualityOverrides[video.id];

              return RepaintBoundary(
                child: PlaylistVideoCard(
                  key: ValueKey(video.id),
                  video: video,
                  isSelected: isSelected,
                  qualityOverride: override,
                  onToggleSelection: () => provider.toggleSelection(video.id),
                  onQualityOverrideChanged: (val) {
                    setState(() {
                      if (val == null) {
                        _itemQualityOverrides.remove(video.id);
                      } else {
                        _itemQualityOverrides[video.id] = val;
                      }
                    });
                  },
                ),
              );
            }, childCount: playlist.videos.length),
          ),
        ),

        // Bottom space so sticky action bar never overlaps items
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AeroColors aero,
    PlaylistProvider provider,
  ) {
    final selectedCount = provider.selectedCount;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AeroSpace.lg,
        AeroSpace.md,
        AeroSpace.lg,
        MediaQuery.paddingOf(context).bottom + AeroSpace.md,
      ),
      decoration: BoxDecoration(
        color: aero.surface1,
        border: Border(top: BorderSide(color: aero.outline, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: AeroButton(
          variant: AeroButtonVariant.primary,
          expand: true,
          icon: const Icon(Symbols.download_rounded, size: 18),
          text: selectedCount > 0
              ? 'Download selected · $selectedCount'
              : 'Select videos to download',
          onPressed: selectedCount > 0 ? _downloadSelected : null,
        ),
      ),
    );
  }
}

class _PlaylistControlsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PlaylistProvider provider;
  final AeroColors aero;
  final String totalSizeEstimate;

  final String selectedFormatId;
  final bool audioOnly;
  final AudioQuality audioQuality;
  final bool isAllSelected;
  final int selectedCount;

  _PlaylistControlsHeaderDelegate({
    required this.provider,
    required this.aero,
    required this.totalSizeEstimate,
  }) : selectedFormatId = provider.selectedFormatId,
       audioOnly = provider.audioOnly,
       audioQuality = provider.audioQuality,
       isAllSelected = provider.isAllSelected,
       selectedCount = provider.selectedCount;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AeroSpace.lg,
        vertical: AeroSpace.xs,
      ),
      decoration: BoxDecoration(
        color: aero.surface1,
        border: Border(bottom: BorderSide(color: aero.outline, width: 1.0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: one selection toggle, count, and estimated size.
          Row(
            children: [
              AeroButton(
                variant: AeroButtonVariant.ghost,
                text: isAllSelected ? 'Clear selection' : 'Select all',
                icon: Icon(
                  isAllSelected
                      ? Symbols.deselect_rounded
                      : Symbols.select_all_rounded,
                  size: 16,
                ),
                onPressed: isAllSelected
                    ? provider.deselectAll
                    : provider.selectAll,
              ),
              const Spacer(),
              // Selected count and total size estimate
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedCount / ${provider.playlist?.videoCount ?? 0} selected',
                    style: AeroText.caption.copyWith(
                      color: aero.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Est. ~$totalSizeEstimate',
                    style: AeroText.caption.withTabularFigures().copyWith(
                      color: aero.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.xs),

          // Row 2: Audio Only toggle + Batch Quality Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Audio Only Chip
                FormatChip(
                  label: 'Audio Only',
                  icon: const Icon(Symbols.audiotrack_rounded),
                  selected: provider.audioOnly,
                  onTap: () => provider.updateBatchSettings(
                    audioOnly: !provider.audioOnly,
                  ),
                ),
                const SizedBox(width: AeroSpace.sm),

                // Batch Quality Chips
                if (!provider.audioOnly) ...[
                  _qualityChip('Best', 'best'),
                  _qualityChip('4K', '2160'),
                  _qualityChip('2K', '1440'),
                  _qualityChip('1080p', '1080'),
                  _qualityChip('720p', '720'),
                  _qualityChip('480p', '480'),
                ] else ...[
                  ...AudioQuality.values.map(
                    (q) => Padding(
                      padding: const EdgeInsets.only(right: AeroSpace.xs),
                      child: FormatChip(
                        label: q.label,
                        selected: provider.audioQuality == q,
                        onTap: () =>
                            provider.updateBatchSettings(audioQuality: q),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qualityChip(String label, String formatId) {
    final isSelected = provider.selectedFormatId == formatId;
    return Padding(
      padding: const EdgeInsets.only(right: AeroSpace.xs),
      child: FormatChip(
        label: label,
        selected: isSelected,
        onTap: () => provider.updateBatchSettings(formatId: formatId),
      ),
    );
  }

  @override
  double get maxExtent => 104;

  @override
  double get minExtent => 104;

  @override
  bool shouldRebuild(covariant _PlaylistControlsHeaderDelegate oldDelegate) {
    return oldDelegate.selectedFormatId != selectedFormatId ||
        oldDelegate.audioOnly != audioOnly ||
        oldDelegate.audioQuality != audioQuality ||
        oldDelegate.isAllSelected != isAllSelected ||
        oldDelegate.selectedCount != selectedCount ||
        oldDelegate.totalSizeEstimate != totalSizeEstimate ||
        oldDelegate.aero != aero;
  }
}
