import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/video_info.dart';
import '../../providers/video_provider.dart';
import 'animated_button.dart';

class VideoConfigurationWidget extends StatefulWidget {
  final Future<void> Function()
  onDownload; // Changed to Future for button state
  final VoidCallback? onClear;

  const VideoConfigurationWidget({
    super.key,
    required this.onDownload,
    this.onClear,
  });

  @override
  State<VideoConfigurationWidget> createState() =>
      _VideoConfigurationWidgetState();
}

class _VideoConfigurationWidgetState extends State<VideoConfigurationWidget> {
  // Download Button State
  bool _isPreparing = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    // If video info is null (cleared), show nothing or empty container
    if (!videoProvider.hasVideo && !videoProvider.isLoading)
      return const SizedBox.shrink();
    if (videoProvider.isLoading) return _buildSkeleton(context);

    final video = videoProvider.videoInfo!;
    final theme = Theme.of(context);

    // Glassmorphic Container Structure
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Fallback
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image (Blurred)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      100, // Background is blurred, high res not needed
                  errorWidget: (_, __, ___) =>
                      Container(color: theme.colorScheme.surface),
                ),
                // Blur Effect
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  ),
                ),
                // Gradient for extra depth
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.1),
                        theme.colorScheme.surface.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Content Split View
          Row(
            children: [
              // Left Column (35%) - Visual Anchor
              Expanded(flex: 35, child: _buildLeftColumn(context, video)),

              // Vertical Divider
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 40),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),

              // Right Column (65%) - Control Center
              Expanded(
                flex: 65,
                child: _buildRightColumn(context, videoProvider),
              ),
            ],
          ),

          // 3. Close Button
          _buildCloseButton(context),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildSkeleton(BuildContext context) {
    // A simple skeleton loader for the entire widget
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Fetching video info...', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    if (widget.onClear == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Positioned(
      top: 10,
      right: 16,
      child: IconButton(
        onPressed: widget.onClear,
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          foregroundColor: theme.colorScheme.onSurface,
          hoverColor: Colors.red.withValues(alpha: 0.8),
        ),
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Close',
      ).animate().fadeIn(delay: 600.ms),
    );
  }

  Widget _buildLeftColumn(BuildContext context, VideoInfo video) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 600, // Optimize memory
                  ),
                  // Duration Overlay (Improved)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Metadata
          Text(
            video.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Author
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.1,
                ),
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  video.channel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildStat(Icons.visibility_outlined, video.formattedViewCount),
              _buildStat(Icons.calendar_today_outlined, video.uploadDate),
            ],
          ),

          const Spacer(),

          // Tag/Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'Ready to Download',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context, VideoProvider provider) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Sections Title
                Text(
                  'CONFIGURATION',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Mode Toggle (SegmentedButton)
                Center(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Video'),
                        icon: Icon(Icons.videocam_outlined),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Audio'),
                        icon: Icon(Icons.audiotrack_outlined),
                      ),
                    ],
                    selected: {provider.audioOnly},
                    onSelectionChanged: (Set<bool> newSelection) {
                      provider.setAudioOnly(newSelection.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Theme.of(context).colorScheme.primary;
                        }
                        return Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1);
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Theme.of(context).colorScheme.onPrimary;
                        }
                        return Theme.of(context).colorScheme.onSurface;
                      }),
                      side: WidgetStateProperty.all(
                        BorderSide.none,
                      ), // Cleaner look
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 2. Dynamic Section with Layout Animation
                AnimatedCrossFade(
                  firstChild: KeyedSubtree(
                    key: const ValueKey('video_options'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVideoOptions(context, provider),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  secondChild: KeyedSubtree(
                    key: const ValueKey('audio_options'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAudioOptions(context, provider),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  crossFadeState: provider.audioOnly
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                  sizeCurve: Curves.easeOutQuart,
                ),

                // 3. Subtitles Section (Smart)
                if (provider.videoInfo?.subtitles.isNotEmpty ?? false) ...[
                  _buildSubtitleSmartSelection(context, provider),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),

        // Footer - Interactive Download Button
        _buildDownloadButtonSection(context, provider),
      ],
    );
  }

  Widget _buildVideoOptions(BuildContext context, VideoProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESOLUTION',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // Resolution Chips & Variant List
        _buildResolutionCards(context, provider),

        const SizedBox(height: 32),

        // Audio Track Selection (New)
        if (provider.selectedVideoFormat?.hasAudio == false)
          _buildAudioMergeSelection(context, provider),
      ],
    );
  }

  Widget _buildResolutionCards(BuildContext context, VideoProvider provider) {
    if (provider.availableResolutions.isEmpty) {
      return Text(
        "No resolutions available",
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Resolution Chips Selector (Horizontal)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: provider.availableResolutions.map((option) {
              final isSelected =
                  option.height == provider.selectedResolution?.height;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedButton(
                  onPressed: () => provider.selectResolution(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // 2. Variants / Codecs List
        Text(
          'AVAILABLE VARIANT VS CODECS',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        _buildVariantSelector(context, provider),
      ],
    );
  }

  Widget _buildVariantSelector(BuildContext context, VideoProvider provider) {
    final resolution = provider.selectedResolution;
    if (resolution == null) return const SizedBox.shrink();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: resolution.formats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final format = resolution.formats[index];
        final isSelected =
            provider.selectedVideoFormat?.formatId == format.formatId;

        // Determine icons and text based on codec
        IconData icon = Icons.movie_outlined;
        String container = (format.extension ?? 'mp4').toUpperCase();
        String codec = format.codecName;

        return AnimatedButton(
          onPressed: () => provider.setSelectedVideoFormat(format),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$container • $codec',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (format.isHdr) ...[
                            const SizedBox(width: 6),
                            _buildMiniTag('HDR', Colors.green),
                          ],
                          if (format.is60fps) ...[
                            const SizedBox(width: 6),
                            _buildMiniTag('60fps', Colors.orange),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        format.formattedFilesize == 'Unknown size'
                            ? 'Unknown size'
                            : (format.hasAudio ||
                                  format.hasVideo &&
                                      provider.audioOnly ==
                                          false) // Simple logic, refine if needed
                            ? '${format.formattedFilesize} (approx)' // Most valid streams are separated, so size is approx sum
                            : format.formattedFilesize,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection Indicator
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAudioMergeSelection(
    BuildContext context,
    VideoProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUDIO TRACK (MERGE)',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FormatInfo>(
              value: provider.selectedAudioMergeStream,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardTheme.color,
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
              onChanged: (FormatInfo? newValue) {
                if (newValue != null) {
                  provider.setSelectedAudioMergeStream(newValue);
                }
              },
              items: provider.videoInfo!.audioOnlyFormats.map((format) {
                return DropdownMenuItem<FormatInfo>(
                  value: format,
                  child: Row(
                    children: [
                      Icon(
                        Icons.audiotrack,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${format.audioBitrate}kbps (${format.formattedFilesize})',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        format.codecName,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitleSmartSelection(
    BuildContext context,
    VideoProvider provider,
  ) {
    var subtitles = List<SubtitleTrack>.from(provider.videoInfo!.subtitles);

    // Smart Sorting: Arabic -> English/System -> Others
    // Prioritize 'ar' explicitly as per request
    final priorityLangs = ['ar', 'en', 'fr', 'es', 'zh'];
    subtitles.sort((a, b) {
      final pA = priorityLangs.indexWhere((l) => a.languageCode.startsWith(l));
      final pB = priorityLangs.indexWhere((l) => b.languageCode.startsWith(l));

      final indexA = pA == -1 ? 999 : pA;
      final indexB = pB == -1 ? 999 : pB;

      if (indexA != indexB) return indexA.compareTo(indexB);
      // Secondary sort by name
      return a.name.compareTo(b.name);
    });

    final top3 = subtitles.take(3).toList();
    final rest = subtitles.skip(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SUBTITLES',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Row(
              children: [
                Text(
                  'Embed',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                Switch(
                  value: provider.embedSubtitles,
                  onChanged: provider.selectedSubtitles.isNotEmpty
                      ? (v) => provider.setEmbedSubtitles(v)
                      : null,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Top 3 Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top3
              .map((sub) => _buildSubtitleChip(context, provider, sub))
              .toList(),
        ),

        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Dropdown/Expansion for the rest
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                'Add Subtitles (${rest.length} more)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              collapsedIconColor: Theme.of(context).colorScheme.primary,
              iconColor: Theme.of(context).colorScheme.primary,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: rest
                          .map(
                            (sub) => _buildSubtitleChip(context, provider, sub),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubtitleChip(
    BuildContext context,
    VideoProvider provider,
    SubtitleTrack sub,
  ) {
    final isSelected = provider.selectedSubtitles.contains(sub);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => provider.toggleSubtitle(sub),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                sub.name,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButtonSection(
    BuildContext context,
    VideoProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.2,
            ), // Shadow can remain black
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: AnimatedButton(
        onPressed: (_isDownloading || _isPreparing)
            ? null
            : _handleDownloadPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _isDownloading
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Progress Bar (if downloading)
              if (_isDownloading)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width:
                      MediaQuery.of(context).size.width *
                      0.65 *
                      _downloadProgress, // 0.65 is flex factor approx
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

              // Button Content
              Center(
                child: _isPreparing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Preparing...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : _isDownloading
                    ? Text(
                        'Downloading... ${(_downloadProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Download Now',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                provider.totalEstimatedDownloadSize > 0
                                    ? '~${(provider.totalEstimatedDownloadSize / 1024 / 1024).toStringAsFixed(1)} MB'
                                    : 'Calculating...',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Future<void> _handleDownloadPress() async {
    setState(() => _isPreparing = true);

    // Simulate preparation time or allow logic to run
    // In real app, we verify everything needed is ready
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isPreparing = false;
      _isDownloading = true;
      _downloadProgress = 0.05; // Start a little bit
    });

    // Invoke actual download
    await widget.onDownload();

    // Note: if widget.onDownload clears the provider, this widget will be disposed.
    // If it doesn't, we can simulate progress or reset.
    if (mounted) {
      // Just in case it stays mounted
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  Widget _buildAudioOptions(BuildContext context, VideoProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUALITY TIER',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: AudioQuality.values.map((quality) {
            final isSelected = quality == provider.selectedAudioQuality;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Center(child: Text(quality.label)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) provider.setAudioQuality(quality);
                  },
                  showCheckmark: false,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
                  selectedColor: Theme.of(context).colorScheme.tertiary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        Text(
          'AVAILABLE STREAMS',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        _buildDetailedAudioList(context, provider),
      ],
    );
  }

  Widget _buildDetailedAudioList(BuildContext context, VideoProvider provider) {
    final audioFormats = provider.videoInfo!.getAudioFormatsForQuality(
      provider.selectedAudioQuality,
    );

    if (audioFormats.isEmpty) {
      return Text(
        'No audio streams found for this quality tier.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    return Column(
      children: audioFormats.map((format) {
        // Since audio selection logic in provider is a bit implicit (it selects based on quality),
        // we might not have a precise 'selectedAudioFormatId' matching one of these if it was auto-selected.
        // However, we can highlight based on ID matching if we updated the provider to track explicit audio selection better.
        // For now, let's assume the provider's selectedAudioFormatId is correct.
        final isSelected = format.formatId == provider.selectedAudioFormatId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // We need a way to select a specific audio format explicitly.
                // key: The current provider might overwrite this if 'setAudioQuality' is called.
                // For now, we unfortunately rely on Quality Tier mainly.
                // But visually we can show what is being picked.
              },
              borderRadius: BorderRadius.circular(12),
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuart,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.tertiary.withValues(alpha: 0.2)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutQuart,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.audiotrack_rounded,
                        size: 20,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onTertiary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${format.extension?.toUpperCase() ?? "AUDIO"} • ${format.audioCodec ?? "Unknown"}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(format.audioBitrate ?? 0)} kbps • ${format.formattedFilesize}',
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: const ValueKey('checked'),
                              color: Theme.of(context).colorScheme.tertiary,
                              size: 24,
                            )
                          : const SizedBox(
                              key: ValueKey('empty'),
                              width: 24,
                              height: 24,
                            ), // Placeholder to keep layout stable if unselected shouldn't show circle
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
