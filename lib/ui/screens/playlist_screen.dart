import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/navigation_provider.dart';
import '../widgets/url_input_card.dart';
import '../widgets/playlist_video_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import '../../models/video_info.dart';
import '../../core/utils/error_helper.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late TextEditingController _urlController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize with current URL from provider if available
    final currentUrl = context.read<PlaylistProvider>().currentUrl;
    _urlController = TextEditingController(text: currentUrl);
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
            // Pop any pushed modal/route so the tab switch is visible immediately (W5)
            final nav = Navigator.of(context, rootNavigator: true);
            if (nav.canPop()) nav.popUntil((route) => route.isFirst);
            context.read<NavigationProvider>().switchToLibrary();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PlaylistProvider>();
    final playlist = provider.playlist;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Playlist Downloader'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GradientBackground()),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: UrlInputCard(
                    controller: _urlController,
                    onFetch: _handleFetch,
                    onCancel: provider.isLoading ? () => provider.cancelFetch() : null,
                    isLoading: provider.isLoading,
                    statusMessage: provider.loadingStatus,
                    errorMessage: provider.error,
                  ),
                ),

                Expanded(
                  child: provider.isLoading
                      ? _buildLoadingState(theme, provider)
                      : provider.error != null
                          ? _buildErrorState(theme, provider)
                          : playlist == null
                              ? _buildEmptyState(theme)
                              : _buildPlaylistContent(context, provider),
                ),
              ],
            ),
          ),

          if (playlist != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(context, provider, theme),
            ).animate().slideY(
              begin: 1,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOut,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.playlist_play_rounded,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Playlist Loaded',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a playlist URL above to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildLoadingState(ThemeData theme, PlaylistProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            provider.loadingStatus != null
                ? provider.loadingStatus!
                : 'Loading playlist info...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => provider.cancelFetch(),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildErrorState(ThemeData theme, PlaylistProvider provider) {
    final errorHelper = provider.error != null
        ? ErrorHelper.parse(provider.error!)
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              errorHelper?.friendlyMessage ?? 'Error Loading Playlist',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorHelper?.suggestion ?? provider.error ?? 'Unknown error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _handleFetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPlaylistContent(
    BuildContext context,
    PlaylistProvider provider,
  ) {
    final playlist = provider.playlist!;
    final theme = Theme.of(context);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 1. Playlist Metadata (Scrolls away)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${playlist.videoCount} videos • ${playlist.uploader}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Sticky Controls Header
        SliverPersistentHeader(
          pinned: true,
          delegate: _PlaylistControlsHeaderDelegate(
            provider: provider,
            theme: theme,
            topPadding: MediaQuery.of(context).padding.top,
          ),
        ),

        // 3. Video List
        SliverPadding(
          padding: const EdgeInsets.only(top: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final video = playlist.videos[index];
              final isSelected = provider.selectedIds.contains(video.id);

              return RepaintBoundary(
                child: PlaylistVideoCard(
                  key: ValueKey(video.id),
                  video: video,
                  isSelected: isSelected,
                  onToggleSelection: () => context
                      .read<PlaylistProvider>()
                      .toggleSelection(video.id),
                ),
              );
            }, childCount: playlist.videos.length),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    PlaylistProvider provider,
    ThemeData theme,
  ) {
    // Simplified bottom bar - only Download button
    return GlassCard(
      borderRadius: 0,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      border: Border(
        top: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: provider.selectedCount > 0 ? _downloadSelected : null,
            icon: const Icon(Icons.download_rounded),
            label: Text(
              provider.selectedCount > 0
                  ? 'Queue ${provider.selectedCount}'
                  : 'Select videos to download',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistControlsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PlaylistProvider provider;
  final ThemeData theme;
  final double topPadding;

  // State properties for change detection
  final String selectedFormatId;
  final bool audioOnly;
  final AudioQuality audioQuality;
  final bool isAllSelected;
  final int selectedCount;

  _PlaylistControlsHeaderDelegate({
    required this.provider,
    required this.theme,
    required this.topPadding,
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
    return GlassCard(
      borderRadius: 0,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: Border(
        bottom: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      backgroundColor: theme.colorScheme.surface.withValues(
        alpha: 0.7,
      ), // Glassy look
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Select All & Audio Toggle
          Row(
            children: [
              // Select All Button
              TextButton.icon(
                onPressed: () => context.read<PlaylistProvider>().selectAll(),
                icon: Icon(
                  Icons.select_all,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Select All',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 16),
              // Deselect All Button
              TextButton.icon(
                onPressed: () => context.read<PlaylistProvider>().deselectAll(),
                icon: Icon(
                  Icons.deselect,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Deselect All',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
              const Spacer(),

              // Audio Only Switch
              Row(
                children: [
                  Icon(
                    Icons.audiotrack_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audio Only',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: provider.audioOnly,
                    onChanged: (val) => context
                        .read<PlaylistProvider>()
                        .updateBatchSettings(audioOnly: val),
                    activeThumbColor: theme.colorScheme.secondary,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Config Chips (Resolution or Audio Quality)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (!provider.audioOnly) ...[
                  // Resolution Chips
                  _buildChip<String>(
                    context,
                    'Best',
                    'best',
                    provider.selectedFormatId == 'best',
                    (val) => provider.updateBatchSettings(formatId: val),
                  ),
                  _buildChip<String>(
                    context,
                    '4K',
                    '2160',
                    provider.selectedFormatId == '2160',
                    (val) => provider.updateBatchSettings(formatId: val),
                  ),
                  _buildChip<String>(
                    context,
                    '2K',
                    '1440',
                    provider.selectedFormatId == '1440',
                    (val) => provider.updateBatchSettings(formatId: val),
                  ),
                  _buildChip<String>(
                    context,
                    '1080p',
                    '1080',
                    provider.selectedFormatId == '1080',
                    (val) => provider.updateBatchSettings(formatId: val),
                  ),
                  _buildChip<String>(
                    context,
                    '720p',
                    '720',
                    provider.selectedFormatId == '720',
                    (val) => provider.updateBatchSettings(formatId: val),
                  ),
                  _buildChip<String>(
                    context,
                    '480p',
                    '480',
                    provider.selectedFormatId == '480',
                    (val) => provider.updateBatchSettings(formatId: val),
                  ),
                ] else ...[
                  // Audio Quality Chips
                  ...AudioQuality.values.map(
                    (q) => _buildChip<AudioQuality>(
                      context,
                      q.label,
                      q,
                      provider.audioQuality == q,
                      (val) => provider.updateBatchSettings(audioQuality: val),
                      isSecondary: true,
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

  Widget _buildChip<T>(
    BuildContext context,
    String label,
    T value,
    bool isSelected,
    Function(T) onSelect, {
    bool isSecondary = false,
  }) {
    final activeColor = isSecondary
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 110;

  @override
  double get minExtent => 110;

  @override
  bool shouldRebuild(covariant _PlaylistControlsHeaderDelegate oldDelegate) {
    return oldDelegate.selectedFormatId != selectedFormatId ||
        oldDelegate.audioOnly != audioOnly ||
        oldDelegate.audioQuality != audioQuality ||
        oldDelegate.isAllSelected != isAllSelected ||
        oldDelegate.selectedCount != selectedCount ||
        oldDelegate.theme != theme;
  }
}
