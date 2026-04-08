import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/video_info.dart';
import '../../providers/video_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../core/utils/platform_utils.dart';

class MobileVideoConfigurationWidget extends StatelessWidget {
  final Future<void> Function() onDownload;
  final VoidCallback? onClear;

  const MobileVideoConfigurationWidget({
    super.key,
    required this.onDownload,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (videoProvider.isLoading) {
      return _buildLoadingState(theme, isDark);
    }

    if (videoProvider.hasError) {
      return _buildErrorState(theme, isDark, videoProvider.errorMessage);
    }

    if (!videoProvider.hasVideo || videoProvider.videoInfo == null) {
      return const SizedBox.shrink();
    }

    return _buildVideoConfiguration(context, theme, isDark, videoProvider);
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141417) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Preparing format options',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Analyzing streams and calculating final size',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    minHeight: 5,
                    color: Color(0xFF8B5CF6),
                    backgroundColor: Color(0x33222222),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSkeletonLine(theme, isDark, widthFactor: 0.92),
                const SizedBox(height: 8),
                _buildSkeletonLine(theme, isDark, widthFactor: 0.78),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildDisabledDownloadSection(),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine(
    ThemeData theme,
    bool isDark, {
    required double widthFactor,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildDisabledDownloadSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: null, // Disabled during loading
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Download'),
                  Text(
                    'Calculating...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              style: FilledButton.styleFrom(
                disabledBackgroundColor: const Color(
                  0xFF8B5CF6,
                ).withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, bool isDark, String? error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error ?? 'Error',
              style: TextStyle(
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoConfiguration(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    VideoProvider videoProvider,
  ) {
    final video = videoProvider.videoInfo!;
    final cardHeightFactor = PlatformUtils.isAndroid ? 0.78 : 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * cardHeightFactor,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 100,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  filterQuality: FilterQuality.low,
                  errorWidget: (_, __, ___) =>
                      Container(color: theme.colorScheme.surface),
                ),
                Container(
                  color: theme.colorScheme.surface.withValues(alpha: 0.88),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.3),
                        theme.colorScheme.surface.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeToggle(context, theme, videoProvider),
                _buildVideoInfoHeader(context, theme, video),
                const Divider(height: 1, color: Colors.white24),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!videoProvider.audioOnly) ...[
                          _buildResolutionSection(
                            context,
                            theme,
                            videoProvider,
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (videoProvider.audioOnly) ...[
                          _buildAudioQualitySection(
                            context,
                            theme,
                            videoProvider,
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (!videoProvider.audioOnly &&
                            videoProvider.selectedVideoFormat?.hasAudio ==
                                false &&
                            videoProvider
                                .videoInfo!
                                .audioOnlyFormats
                                .isNotEmpty) ...[
                          _buildAudioMergeSection(
                            context,
                            theme,
                            videoProvider,
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (videoProvider.videoInfo!.subtitles.isNotEmpty) ...[
                          _buildSubtitleSection(context, theme, videoProvider),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                _buildDownloadSection(context, theme, videoProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => videoProvider.setAudioOnly(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !videoProvider.audioOnly
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      size: 18,
                      color: !videoProvider.audioOnly
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: !videoProvider.audioOnly
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => videoProvider.setAudioOnly(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: videoProvider.audioOnly
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note_outlined,
                      size: 18,
                      color: videoProvider.audioOnly
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Audio',
                      style: TextStyle(
                        color: videoProvider.audioOnly
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

  Widget _buildVideoInfoHeader(
    BuildContext context,
    ThemeData theme,
    VideoInfo video,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        video.channel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildResolutionSection(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    if (videoProvider.availableResolutions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESOLUTION',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: videoProvider.availableResolutions.map((option) {
              final isSelected =
                  option.height == videoProvider.selectedResolution?.height;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => videoProvider.selectResolution(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _buildVariantSelector(context, theme, videoProvider),
      ],
    );
  }

  Widget _buildVariantSelector(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    final resolution = videoProvider.selectedResolution;
    if (resolution == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CODEC VARIANTS',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...resolution.formats.map((format) {
          final isSelected =
              videoProvider.selectedVideoFormat?.formatId == format.formatId;
          final container = (format.extension ?? 'mp4').toUpperCase();

          return GestureDetector(
            onTap: () => videoProvider.setSelectedVideoFormat(format),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              format.codecName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              container,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              format.formattedFilesize,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                            if (format.isHdr) ...[
                              const SizedBox(width: 8),
                              _buildMiniTag('HDR', Colors.green),
                            ],
                            if (format.is60fps) ...[
                              const SizedBox(width: 8),
                              _buildMiniTag('60fps', Colors.orange),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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

  Widget _buildAudioMergeSection(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUDIO TRACK',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FormatInfo>(
              value: videoProvider.selectedAudioMergeStream,
              isExpanded: true,
              dropdownColor: const Color(0xFF2C2C2E),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (FormatInfo? newValue) {
                if (newValue != null) {
                  videoProvider.setSelectedAudioMergeStream(newValue);
                }
              },
              items: videoProvider.videoInfo!.audioOnlyFormats.map((format) {
                return DropdownMenuItem<FormatInfo>(
                  value: format,
                  child: Row(
                    children: [
                      Icon(
                        Icons.audiotrack,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${format.audioBitrate}kbps • ${format.formattedFilesize}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        format.codecName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
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

  Widget _buildAudioQualitySection(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUDIO QUALITY',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AudioQuality.values.map((quality) {
              final isSelected = quality == videoProvider.selectedAudioQuality;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => videoProvider.setAudioQuality(quality),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      quality.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AVAILABLE STREAMS',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...videoProvider.videoInfo!.audioOnlyFormats.take(3).map((format) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${format.codecName} • ${format.extension?.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${format.audioBitrate}kbps • ${format.formattedFilesize}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubtitleSection(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    final settingsProvider = context.watch<PlatformSettingsProvider>();
    var subtitles = List<SubtitleTrack>.from(
      videoProvider.videoInfo!.subtitles,
    );
    subtitles = _sortSubtitlesByDefault(
      subtitles,
      settingsProvider.defaultSubtitleLanguage,
    );

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
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              children: [
                Text(
                  'Enable',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: videoProvider.subtitlesEnabled,
                  onChanged: (v) => videoProvider.setSubtitlesEnabled(
                    v,
                    preferredLanguageCode:
                        settingsProvider.defaultSubtitleLanguage,
                  ),
                  activeTrackColor: const Color(
                    0xFF8B5CF6,
                  ).withValues(alpha: 0.5),
                  thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF8B5CF6);
                    }
                    return Colors.grey;
                  }),
                ),
              ],
            ),
          ],
        ),
        if (videoProvider.subtitlesEnabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: top3
                .map((sub) => _buildSubtitleChip(context, videoProvider, sub))
                .toList(),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'More (${rest.length})',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 12,
                  ),
                ),
                subtitle: settingsProvider.defaultSubtitleLanguage != 'auto'
                    ? Text(
                        'Default appears first when available',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5,
                        ),
                      )
                    : null,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                collapsedIconColor: const Color(0xFF8B5CF6),
                iconColor: const Color(0xFF8B5CF6),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rest
                        .map(
                          (sub) =>
                              _buildSubtitleChip(context, videoProvider, sub),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Embed in file',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: videoProvider.embedSubtitles,
                onChanged: videoProvider.selectedSubtitles.isNotEmpty
                    ? (v) => videoProvider.setEmbedSubtitles(v)
                    : null,
                activeTrackColor: const Color(
                  0xFF8B5CF6,
                ).withValues(alpha: 0.5),
                thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF8B5CF6);
                  }
                  return Colors.grey;
                }),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  videoProvider.selectedSubtitles.isEmpty
                      ? 'Select at least one language'
                      : '${videoProvider.selectedSubtitles.length} selected',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<SubtitleTrack> _sortSubtitlesByDefault(
    List<SubtitleTrack> subtitles,
    String preferredLanguageCode,
  ) {
    if (preferredLanguageCode.isEmpty || preferredLanguageCode == 'auto') {
      return subtitles;
    }

    final preferred = preferredLanguageCode.toLowerCase();
    subtitles.sort((a, b) {
      final aPreferred = _isPreferredSubtitle(a.languageCode, preferred);
      final bPreferred = _isPreferredSubtitle(b.languageCode, preferred);
      if (aPreferred == bPreferred) return a.name.compareTo(b.name);
      return aPreferred ? -1 : 1;
    });

    return subtitles;
  }

  bool _isPreferredSubtitle(String languageCode, String preferred) {
    final code = languageCode.toLowerCase();
    return code == preferred ||
        code.startsWith('$preferred-') ||
        code.startsWith('${preferred}_') ||
        code.startsWith(preferred);
  }

  Widget _buildSubtitleChip(
    BuildContext context,
    VideoProvider videoProvider,
    SubtitleTrack sub,
  ) {
    final isSelected = videoProvider.selectedSubtitles.contains(sub);
    return GestureDetector(
      onTap: () => videoProvider.toggleSubtitle(sub),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 4),
            ],
            Text(
              sub.name,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF8B5CF6)
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadSection(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Download'),
                  Text(
                    videoProvider.totalEstimatedDownloadSize > 0
                        ? '~${(videoProvider.totalEstimatedDownloadSize / 1024 / 1024).toStringAsFixed(1)} MB'
                        : 'Calculating...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
