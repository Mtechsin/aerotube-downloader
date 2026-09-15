import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/video_info.dart';
import '../../models/download_item.dart';
import '../../core/theme/app_motion.dart';
import '../../providers/video_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/platform_settings_provider.dart';

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
      return _buildLoadingState(context, theme, isDark);
    }

    if (videoProvider.hasError) {
      return _buildErrorState(theme, isDark, videoProvider.errorMessage);
    }

    if (!videoProvider.hasVideo || videoProvider.videoInfo == null) {
      return const SizedBox.shrink();
    }

    return _buildVideoConfiguration(context, theme, isDark, videoProvider);
  }

  Widget _buildLoadingState(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
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
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Preparing format options',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<VideoProvider>().cancelFetch(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: theme.colorScheme.error.withValues(alpha: 0.5),
                        ),
                        foregroundColor: theme.colorScheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancel'),
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
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSkeletonLine(theme, isDark, widthFactor: 0.92),
                const SizedBox(height: 8),
                _buildSkeletonLine(theme, isDark, widthFactor: 0.78),
              ],
            ),
          ),
          _buildDisabledDownloadSection(theme, context),
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

  Widget _buildDisabledDownloadSection(ThemeData theme, [BuildContext? ctx]) {
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
              onPressed: ctx != null
                  ? () => ctx.read<VideoProvider>().cancelFetch()
                  : null,
              icon: Icon(
                ctx != null ? Icons.close_rounded : Icons.download_rounded,
                size: 18,
              ),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx != null ? 'Cancel' : 'Download'),
                  Text(
                    ctx != null ? 'Stop fetching' : 'Calculating...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              style: FilledButton.styleFrom(
                backgroundColor: ctx != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.5,
                ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeToggle(context, theme, videoProvider),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVideoInfoHeader(context, theme, video),
                  const SizedBox(height: 24),
                  if (!videoProvider.audioOnly) ...[
                    _buildResolutionSection(context, theme, videoProvider),
                    const SizedBox(height: 24),
                  ],
                  if (videoProvider.audioOnly) ...[
                    _buildAudioQualitySection(context, theme, videoProvider),
                    const SizedBox(height: 24),
                  ],
                  if (!videoProvider.audioOnly &&
                      videoProvider.selectedVideoFormat?.hasAudio == false &&
                      videoProvider.videoInfo!.audioOnlyFormats.isNotEmpty) ...[
                    _buildAudioMergeSection(context, theme, videoProvider),
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
          _buildDownloadSection(context, theme, videoProvider),
        ],
      ),
    );
  }

  Widget _buildModeToggle(
    BuildContext context,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    final textColor = theme.colorScheme.onSurface;

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
                      ? theme.colorScheme.primary
                      : textColor.withValues(alpha: 0.1),
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
                          : textColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: !videoProvider.audioOnly
                            ? Colors.white
                            : textColor.withValues(alpha: 0.5),
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
                      ? theme.colorScheme.primary
                      : textColor.withValues(alpha: 0.1),
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
                          : textColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Audio',
                      style: TextStyle(
                        color: videoProvider.audioOnly
                            ? Colors.white
                            : textColor.withValues(alpha: 0.5),
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
    final textColor = theme.colorScheme.onSurface;
    final textSecondaryColor = textColor.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
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
                  memCacheWidth: 600,
                  fadeInDuration: const Duration(milliseconds: 200),
                  fadeOutDuration: const Duration(milliseconds: 200),
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          video.title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: textSecondaryColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                video.channel,
                style: TextStyle(color: textSecondaryColor, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
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

    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final labelColor = textColor.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESOLUTION',
          style: TextStyle(
            color: labelColor,
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
                          ? theme.colorScheme.primary
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.08,
                                  )),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : theme.colorScheme.outline),
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : textColor.withValues(alpha: 0.8),
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

    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final labelColor = textColor.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CODEC VARIANTS',
          style: TextStyle(
            color: labelColor,
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
          final itemTextColor = theme.colorScheme.onSurface;

          return GestureDetector(
            onTap: () => videoProvider.setSelectedVideoFormat(format),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : theme.colorScheme.onSurface.withValues(
                              alpha: 0.04,
                            )),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : theme.colorScheme.outline),
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
                            ? theme.colorScheme.primary
                            : itemTextColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primary
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
                              style: TextStyle(
                                color: itemTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              container,
                              style: TextStyle(
                                color: itemTextColor.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              videoProvider.formattedTotalSizeForFormat(format),
                              style: TextStyle(
                                color: itemTextColor.withValues(alpha: 0.5),
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
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final labelColor = textColor.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUDIO TRACK',
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : theme.colorScheme.outline,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FormatInfo>(
              value: videoProvider.selectedAudioMergeStream,
              isExpanded: true,
              dropdownColor: isDark
                  ? const Color(0xFF2C2C2E)
                  : theme.colorScheme.surface,
              icon: Icon(
                Icons.arrow_drop_down,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
              ),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${format.audioBitrate}kbps • ${format.formattedEstimatedFilesize(videoProvider.videoInfo?.duration)}',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ),
                      Text(
                        format.codecName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
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
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final labelColor = textColor.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUDIO QUALITY',
          style: TextStyle(
            color: labelColor,
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
                          ? theme.colorScheme.primary
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.08,
                                  )),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : theme.colorScheme.outline),
                      ),
                    ),
                    child: Text(
                      quality.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : textColor.withValues(alpha: 0.8),
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
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...videoProvider.videoInfo!
            .getAudioFormatsForQuality(videoProvider.selectedAudioQuality)
            .map((format) {
              final isSelected =
                  format.formatId ==
                  videoProvider.selectedAudioMergeStream?.formatId;
              final itemTextColor = theme.colorScheme.onSurface;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => videoProvider.setSelectedAudioMergeStream(format),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.04,
                                )),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : theme.colorScheme.outline),
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
                                ? theme.colorScheme.primary
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : itemTextColor.withValues(alpha: 0.3)),
                            width: 2,
                          ),
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.audiotrack,
                        size: 18,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : itemTextColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${format.codecName} • ${format.extension?.toUpperCase()}',
                              style: TextStyle(
                                color: isSelected
                                    ? itemTextColor
                                    : itemTextColor.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${format.audioBitrate}kbps • ${format.formattedEstimatedFilesize(videoProvider.videoInfo?.duration)}',
                              style: TextStyle(
                                color: isSelected
                                    ? itemTextColor.withValues(alpha: 0.7)
                                    : itemTextColor.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
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

    final textColor = theme.colorScheme.onSurface;
    final labelColor = textColor.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SUBTITLES',
              style: TextStyle(
                color: labelColor,
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
                    color: textColor.withValues(alpha: 0.4),
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
                  activeTrackColor: theme.colorScheme.primary.withValues(
                    alpha: 0.5,
                  ),
                  thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return theme.colorScheme.primary;
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
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                subtitle: settingsProvider.defaultSubtitleLanguage != 'auto'
                    ? Text(
                        'Default appears first when available',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.45),
                          fontSize: 10.5,
                        ),
                      )
                    : null,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                collapsedIconColor: theme.colorScheme.primary,
                iconColor: theme.colorScheme.primary,
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
                  color: textColor.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: videoProvider.embedSubtitles,
                onChanged: videoProvider.selectedSubtitles.isNotEmpty
                    ? (v) => videoProvider.setEmbedSubtitles(v)
                    : null,
                activeTrackColor: theme.colorScheme.primary.withValues(
                  alpha: 0.5,
                ),
                thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.primary;
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
                    color: textColor.withValues(alpha: 0.45),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: () => videoProvider.toggleSubtitle(sub),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : theme.colorScheme.outline),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
            ],
            Text(
              sub.name,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.primary
                    : textColor.withValues(alpha: 0.7),
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
    final textColor = theme.colorScheme.onSurface;
    final video = videoProvider.videoInfo;
    final videoId = video?.id;
    final videoUrl = video?.url;

    // Scoped to this video's (id, status, progress) record instead of
    // watching the whole provider: progress ticks rebuild only this button,
    // not the entire configuration panel.
    return Selector<MobileDownloadProvider, (String, DownloadStatus, double)?>(
      selector: (_, provider) {
        if (videoId == null && videoUrl == null) return null;
        for (final item in provider.activeDownloads) {
          final matches =
              item.id == videoId ||
              (videoId != null && item.id.startsWith('${videoId}_')) ||
              item.url == videoUrl;
          if (matches) return (item.id, item.status, item.progress);
        }
        return null;
      },
      builder: (context, snapshot, _) {
        final DownloadStatus? status = snapshot?.$2;

        final bool isPreparing =
            status == DownloadStatus.queued || status == DownloadStatus.pending;

        final bool isDownloading =
            status == DownloadStatus.downloadingVideo ||
            status == DownloadStatus.downloadingAudio ||
            status == DownloadStatus.merging;

        final bool isDownloadActive = isPreparing || isDownloading;
        final double downloadProgress = snapshot?.$3 ?? 0.0;

        final String stateKey = !isDownloadActive
            ? 'idle'
            : isPreparing
            ? 'preparing'
            : 'downloading';

        final Widget icon = AnimatedSwitcher(
          duration: appMotionDuration(context, AppMotion.short),
          child: SizedBox(
            key: ValueKey(stateKey),
            width: 18,
            height: 18,
            child: isPreparing
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  )
                : Icon(
                    isDownloading
                        ? Icons.downloading_rounded
                        : Icons.download_rounded,
                    size: 18,
                  ),
          ),
        );

        final Widget label = AnimatedSwitcher(
          duration: appMotionDuration(context, AppMotion.short),
          child: KeyedSubtree(
            key: ValueKey(stateKey),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPreparing
                      ? (status == DownloadStatus.queued
                            ? 'Queued...'
                            : 'Preparing...')
                      : isDownloading
                      ? (status == DownloadStatus.merging
                            ? 'Merging... ${(downloadProgress * 100).toInt()}%'
                            : 'Downloading... ${(downloadProgress * 100).toInt()}%')
                      : 'Download',
                ),
                Text(
                  videoProvider.totalEstimatedDownloadSize > 0
                      ? '~${(videoProvider.totalEstimatedDownloadSize / 1024 / 1024).toStringAsFixed(1)} MB'
                      : 'Calculating...',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                // Thin live progress line inside the button while downloading.
                if (isDownloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: downloadProgress),
                        duration: appMotionDuration(
                          context,
                          const Duration(milliseconds: 320),
                        ),
                        curve: AppMotion.decelerate,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isDownloadActive ? null : onClear,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: textColor.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TweenAnimationBuilder<BorderRadius>(
                    // Morph from rounded rect to pill while a download runs.
                    tween: Tween<BorderRadius>(
                      begin: BorderRadius.circular(10),
                      end: BorderRadius.circular(isDownloadActive ? 20 : 10),
                    ),
                    duration: appMotionDuration(context, AppMotion.medium),
                    curve: AppMotion.spatialSpringCurve,
                    builder: (context, radius, _) => FilledButton.icon(
                      onPressed: isDownloadActive ? null : onDownload,
                      icon: icon,
                      label: label,
                      style: FilledButton.styleFrom(
                        backgroundColor: isDownloadActive
                            ? theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              )
                            : theme.colorScheme.primary,
                        foregroundColor: isDownloadActive
                            ? theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              )
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: radius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
