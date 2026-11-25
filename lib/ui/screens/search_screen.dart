import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/download_mode.dart';
import '../../models/search_video_result.dart';
import '../../models/video_info.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/video_provider.dart';
import '../components/aero_button.dart';
import '../components/aero_card.dart';
import '../components/aero_chip.dart';
import '../components/aero_density.dart';
import '../components/aero_snack.dart';
import '../components/aero_text_field.dart';
import '../components/empty_state.dart';
import '../components/section_header.dart';
import '../components/thumbnail_tile.dart';
import '../widgets/search_skeleton.dart';
import 'mobile_result_screen.dart';

/// Redesigned AeroTube Search Screen following Section 7.3 of the Redesign Spec.
///
/// Features:
/// - Pinned top search field with [AeroTextField]
/// - Recent searches as chips when the field is empty
/// - 2-line rows on Android (mobile) and 2-3 column grid of [ThumbnailTile] cards on Windows
/// - Quick action "download best" button, tap card/row opens configuration panel
/// - Skeleton loader matching Aero radii and tokens
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _recentSearchesKey = 'aero_recent_searches';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentSearchesKey) ?? [];
    if (mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(_recentSearches);
    current.remove(trimmed);
    current.insert(0, trimmed);
    if (current.length > 10) {
      current.removeRange(10, current.length);
    }
    await prefs.setStringList(_recentSearchesKey, current);
    if (mounted) {
      setState(() => _recentSearches = current);
    }
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(_recentSearches);
    current.remove(query);
    await prefs.setStringList(_recentSearchesKey, current);
    if (mounted) {
      setState(() => _recentSearches = current);
    }
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    if (mounted) {
      setState(() => _recentSearches = []);
    }
  }

  void _handleSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      _saveRecentSearch(trimmed);
      context.read<SearchProvider>().search(trimmed, immediate: true);
      _focusNode.unfocus();
    }
  }

  void _openConfig(SearchVideoResult video) {
    context.read<VideoProvider>().fetchVideoInfo(video.videoUrl);
    if (PlatformUtils.isMobile) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MobileResultScreen()),
      );
    } else {
      context.read<NavigationProvider>().switchToHome();
    }
  }

  Future<void> _downloadBest(SearchVideoResult video) async {
    final videoProvider = context.read<VideoProvider>();
    AeroSnack.info(context, message: 'Fetching "${video.title}"...');

    try {
      await videoProvider.fetchVideoInfo(video.videoUrl);
      if (!mounted) return;

      if (videoProvider.videoInfo == null) {
        AeroSnack.error(
          context,
          message: 'Could not fetch format info for "${video.title}".',
          actionLabel: 'Details',
          onAction: () => _openConfig(video),
        );
        return;
      }

      if (PlatformUtils.isMobile) {
        final downloadProvider = context.read<MobileDownloadProvider>();
        final estSize = videoProvider.totalEstimatedDownloadSize;
        final queued = await downloadProvider.addDownload(
          url: videoProvider.currentUrl,
          title: videoProvider.videoInfo!.title,
          thumbnailUrl: videoProvider.videoInfo!.thumbnailUrl,
          mode: DownloadMode.videoWithAudio,
          formatId: videoProvider.selectedVideoFormatId,
          estimatedFileSize: estSize > 0 ? estSize : null,
          options: {
            'audioFormatId': videoProvider.selectedAudioFormatId,
            'targetHeight': videoProvider.selectedHeight,
            'audioQuality': videoProvider.selectedAudioQuality.ytdlpValue,
            'embedSubtitles': false,
            'estimatedFileSize': estSize > 0 ? estSize : null,
          },
        );
        if (mounted) {
          if (queued) {
            AeroSnack.success(
              context,
              message: 'Queued best quality: "${video.title}"',
            );
          } else {
            AeroSnack.warning(
              context,
              message: 'Already downloading or queued',
            );
          }
        }
      } else {
        final downloadProvider = context.read<DownloadProvider>();
        final settingsProvider = context.read<PlatformSettingsProvider>();
        final outputPath =
            settingsProvider.settings.outputPath ??
            await settingsProvider.getDefaultOutputPath();
        final estSize = videoProvider.totalEstimatedDownloadSize;
        final queued = await downloadProvider.startDownload(
          video: videoProvider.videoInfo!,
          outputPath: outputPath,
          mode: DownloadMode.videoWithAudio,
          formatId: videoProvider.selectedVideoFormatId,
          audioFormatId: videoProvider.selectedAudioFormatId,
          targetHeight: videoProvider.selectedHeight,
          audioQuality: videoProvider.selectedAudioQuality.ytdlpValue,
          embedThumbnail: settingsProvider.settings.embedThumbnail,
          embedMetadata: settingsProvider.settings.embedMetadata,
          sponsorBlock: settingsProvider.sponsorBlockEnabled,
          useDownloadArchive: settingsProvider.useDownloadArchive,
          estimatedFileSize: estSize > 0 ? estSize : null,
        );
        if (mounted) {
          if (queued) {
            AeroSnack.success(
              context,
              message: 'Queued best quality: "${video.title}"',
            );
          } else {
            AeroSnack.warning(context, message: 'Already in download queue');
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      AeroSnack.error(context, message: 'Failed to start download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    final isDesktop = !PlatformUtils.isMobile;

    Widget content = Column(
      children: [
        _buildHeader(context, searchProvider),
        Expanded(child: _buildBody(context, searchProvider)),
      ],
    );

    if (isDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: content,
        ),
      );
    }

    return SafeArea(child: content);
  }

  Widget _buildHeader(BuildContext context, SearchProvider provider) {
    final colors = context.aero;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        PlatformUtils.isMobile ? AeroSpace.lg : AeroSpace.xxl,
        AeroSpace.lg,
        PlatformUtils.isMobile ? AeroSpace.lg : AeroSpace.xxl,
        AeroSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search',
                      style: AeroText.headline.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Find videos by title, creator, or YouTube link.',
                      style: AeroText.bodySm.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (PlatformUtils.isMobile)
                IconButton(
                  icon: const Icon(Symbols.home_rounded, size: 22),
                  tooltip: 'Home',
                  onPressed: () =>
                      context.read<NavigationProvider>().switchToHome(),
                ),
            ],
          ),
          const SizedBox(height: AeroSpace.md),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              final field = AeroTextField(
                controller: _searchController,
                focusNode: _focusNode,
                hintText: 'Search videos, songs, channels…',
                textInputAction: TextInputAction.search,
                onSubmitted: _handleSearch,
                prefixIcon: const Icon(Symbols.search_rounded),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Symbols.close_rounded, size: 18),
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchController.clear();
                          provider.clearSearch();
                        },
                      )
                    : null,
              );
              final action = AeroButton(
                text: 'Search',
                icon: const Icon(Symbols.arrow_forward_rounded, size: 18),
                isLoading: provider.isLoading,
                onPressed: value.text.trim().isEmpty || provider.isLoading
                    ? null
                    : () => _handleSearch(value.text),
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field,
                        const SizedBox(height: AeroSpace.sm),
                        Align(alignment: Alignment.centerRight, child: action),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: field),
                      const SizedBox(width: AeroSpace.sm),
                      action,
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchProvider provider) {
    final colors = context.aero;

    if (provider.isLoading) {
      return const SearchSkeleton();
    }

    if (provider.error != null) {
      final errorHelper = ErrorHelper.parse(provider.error!);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AeroSpace.xxl),
          child: EmptyState(
            icon: Symbols.error_rounded,
            iconColor: colors.danger,
            title: 'Search Failed',
            description: errorHelper.friendlyMessage,
            actionLabel: 'Try Again',
            onAction: () => provider.search(provider.lastQuery, immediate: true),
          ),
        ),
      );
    }

    if (provider.searchResults.isEmpty) {
      return _buildEmptyState(context, provider);
    }

    final videos = provider.searchResults;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: PlatformUtils.isMobile ? AeroSpace.lg : AeroSpace.xxl,
        vertical: AeroSpace.sm,
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AeroSpace.xs,
                bottom: AeroSpace.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Symbols.manage_search_rounded,
                    color: colors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: AeroSpace.sm),
                  Expanded(
                    child: Text(
                      'Results for "${provider.lastQuery}"',
                      style: AeroText.label.copyWith(
                        color: colors.onSurfaceMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${videos.length} videos',
                    style: AeroText.caption.copyWith(
                      color: colors.onSurfaceFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (PlatformUtils.isMobile)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AeroSpace.sm),
                    child: _MobileSearchRow(
                      video: videos[index],
                      onTap: () => _openConfig(videos[index]),
                      onDownloadBest: () => _downloadBest(videos[index]),
                    ),
                  );
                },
                childCount: videos.length,
                addRepaintBoundaries: true,
              ),
            )
          else
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 310,
                crossAxisSpacing: AeroSpace.lg,
                mainAxisSpacing: AeroSpace.lg,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _DesktopSearchCard(
                    video: videos[index],
                    onTap: () => _openConfig(videos[index]),
                    onDownloadBest: () => _downloadBest(videos[index]),
                  );
                },
                childCount: videos.length,
                addRepaintBoundaries: true,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AeroSpace.xxl),
              child: Center(
                child: provider.hasMoreResults
                    ? AeroButton.tonal(
                        text: 'Load more results',
                        icon: const Icon(Symbols.expand_more_rounded, size: 18),
                        isLoading: provider.isLoadingMore,
                        onPressed: provider.isLoadingMore
                            ? null
                            : provider.loadMore,
                      )
                    : Text(
                        'No more results',
                        style: AeroText.caption.copyWith(
                          color: colors.onSurfaceFaint,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, SearchProvider provider) {
    final colors = context.aero;
    final hasQuery = provider.lastQuery.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: PlatformUtils.isMobile ? AeroSpace.lg : AeroSpace.xxl,
        vertical: AeroSpace.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_recentSearches.isNotEmpty) ...[
                SectionHeader(
                  title: 'Recent searches',
                  margin: const EdgeInsets.only(bottom: AeroSpace.md),
                  trailing: AeroButton.ghost(
                    text: 'Clear all',
                    height: 28,
                    density: AeroDensity.compact,
                    onPressed: _clearRecentSearches,
                  ),
                ),
                Wrap(
                  spacing: AeroSpace.sm,
                  runSpacing: AeroSpace.sm,
                  children: _recentSearches.map((query) {
                    return AeroChip(
                      text: query,
                      icon: const Icon(Symbols.history_rounded),
                      onTap: () {
                        _searchController.text = query;
                        _handleSearch(query);
                      },
                      onDeleted: () => _removeRecentSearch(query),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AeroSpace.xl),
              ],
              AeroCard(
                padding: const EdgeInsets.all(AeroSpace.xl),
                child: hasQuery
                    ? EmptyState(
                        icon: Symbols.search_off_rounded,
                        title: 'No results for “${provider.lastQuery}”',
                        description:
                            'Try a shorter phrase, a different creator, or check the spelling.',
                        padding: EdgeInsets.zero,
                      )
                    : Text(
                        'Search YouTube or paste a video link.',
                        style: AeroText.bodySm.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
              ).animate().fadeIn(duration: 240.ms),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2-line row representation of search results for mobile (Android).
class _MobileSearchRow extends StatelessWidget {
  final SearchVideoResult video;
  final VoidCallback onTap;
  final VoidCallback onDownloadBest;

  const _MobileSearchRow({
    required this.video,
    required this.onTap,
    required this.onDownloadBest,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.sm),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ThumbnailTile(
            imageUrl: video.thumbnailUrl,
            duration: _formatDuration(video.duration),
            width: 112,
            height: 64,
            borderRadius: AeroRadius.mdBorderRadius,
          ),
          const SizedBox(width: AeroSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  style: AeroText.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${video.author}${video.viewCount != null ? ' • ${_formatViews(video.viewCount!)}' : ''}',
                  style: AeroText.caption.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AeroSpace.xs),
          AeroButton.icon(
            icon: const Icon(Symbols.download_rounded),
            tooltip: 'Download best quality',
            density: AeroDensity.compact,
            onPressed: onDownloadBest,
          ),
        ],
      ),
    );
  }
}

/// 2-3 column grid card for desktop (Windows).
class _DesktopSearchCard extends StatelessWidget {
  final SearchVideoResult video;
  final VoidCallback onTap;
  final VoidCallback onDownloadBest;

  const _DesktopSearchCard({
    required this.video,
    required this.onTap,
    required this.onDownloadBest,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return AeroCard(
      padding: EdgeInsets.zero,
      hoverable: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThumbnailTile(
            imageUrl: video.thumbnailUrl,
            duration: _formatDuration(video.duration),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AeroRadius.lg - 1),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AeroSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: AeroText.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.author}${video.uploadDate != null ? " • ${video.uploadDate!.split(' ').first}" : ""}',
                    style: AeroText.caption.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatViews(video.viewCount ?? 0)} views',
                        style: AeroText.caption.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                      AeroButton.tonal(
                        icon: const Icon(Symbols.download_rounded, size: 16),
                        text: 'Best',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        density: AeroDensity.compact,
                        tooltip: 'Download best quality',
                        onPressed: onDownloadBest,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration? d) {
  if (d == null) return '';
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

String _formatViews(int views) {
  if (views >= 1000000) {
    return '${(views / 1000000).toStringAsFixed(1)}M';
  } else if (views >= 1000) {
    return '${(views / 1000).toStringAsFixed(1)}K';
  }
  return views.toString();
}
