import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/url_input_card.dart';
import '../widgets/playlist_video_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import '../../models/video_info.dart';
import 'dart:io';

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

  void _downloadSelected() {
    final provider = context.read<PlaylistProvider>();
    if (provider.playlist == null || provider.selectedCount == 0) return;

    final downloadProvider = context.read<DownloadProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    
    final outputPath = settingsProvider.settings.outputPath ?? 
        '${Platform.environment['USERPROFILE']}\\Downloads';

    provider.downloadSelected(downloadProvider, outputPath);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${provider.selectedCount} videos to download queue'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PlaylistProvider>();
    final playlist = provider.playlist;
    
    // Auto-fill URL if fetching (e.g. from Home triggers)
    // Actually, fetching doesn't update the controller. 
    // If we want to sync, we'd need to know the fetching URL.

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
                    isLoading: provider.isLoading,
                    statusMessage: provider.loadingStatus,
                    errorMessage: provider.error,
                  ),
                ),

                Expanded(
                  child: playlist == null
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
             ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play_rounded, size: 64, color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No Playlist Loaded',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a YouTube playlist URL above to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildPlaylistContent(BuildContext context, PlaylistProvider provider) {
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${playlist.videoCount} videos • ${playlist.uploader}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video = playlist.videos[index];
                final isSelected = provider.selectedIds.contains(video.id);
                
                return PlaylistVideoCard(
                  video: video,
                  isSelected: isSelected,
                  onToggleSelection: () => context.read<PlaylistProvider>().toggleSelection(video.id),
                ).animate().fadeIn(delay: (index * 10).ms).slideX(begin: 0.1, end: 0);
              },
              childCount: playlist.videos.length,
            ),
          ),
        ),
        
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, PlaylistProvider provider, ThemeData theme) {
    // Simplified bottom bar - only Download button
    return GlassCard(
      borderRadius: 0,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1))),
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7), 
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: provider.selectedCount > 0 ? _downloadSelected : null,
            icon: const Icon(Icons.download_rounded),
            label: Text('Download ${provider.selectedCount > 0 ? "(${provider.selectedCount})" : ""}'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return GlassCard(
      borderRadius: 0,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1))),
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7), // Glassy look
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
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
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
                  Icon(Icons.audiotrack_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Text('Audio Only', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Switch(
                    value: provider.audioOnly,
                    onChanged: (val) => context.read<PlaylistProvider>().updateBatchSettings(audioOnly: val),
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
                  _buildChip<String>(context, 'Best', 'best', provider.selectedFormatId == 'best', (val) => provider.updateBatchSettings(formatId: val)),
                  _buildChip<String>(context, '4K', '2160', provider.selectedFormatId == '2160', (val) => provider.updateBatchSettings(formatId: val)),
                  _buildChip<String>(context, '2K', '1440', provider.selectedFormatId == '1440', (val) => provider.updateBatchSettings(formatId: val)),
                  _buildChip<String>(context, '1080p', '1080', provider.selectedFormatId == '1080', (val) => provider.updateBatchSettings(formatId: val)),
                  _buildChip<String>(context, '720p', '720', provider.selectedFormatId == '720', (val) => provider.updateBatchSettings(formatId: val)),
                  _buildChip<String>(context, '480p', '480', provider.selectedFormatId == '480', (val) => provider.updateBatchSettings(formatId: val)),
                ] else ...[
                  // Audio Quality Chips
                  ...AudioQuality.values.map((q) => _buildChip<AudioQuality>(
                    context, 
                    q.label, 
                    q, 
                    provider.audioQuality == q, 
                    (val) => provider.updateBatchSettings(audioQuality: val),
                    isSecondary: true
                  )),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip<T>(BuildContext context, String label, T value, bool isSelected, Function(T) onSelect, {bool isSecondary = false}) {
    final activeColor = isSecondary ? theme.colorScheme.secondary : theme.colorScheme.primary;
    
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
              color: isSelected ? activeColor : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
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
