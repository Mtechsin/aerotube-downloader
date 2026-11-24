import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../models/download_item.dart';
import '../../models/video_info.dart';
import '../../providers/download_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/video_provider.dart';
import '../components/components.dart';

/// Two-pane Windows video configuration panel conforming to AeroTube design spec.
///
/// Layout:
/// - Left 40%: 16:9 [ThumbnailTile], title, author/metadata, status pill.
/// - Right 60%: [AeroSegmentedControl] (Video | Audio), quality grid (3 columns),
///   codec variants, options accordion ([SettingsRow]s), and pinned bottom-right action bar.
class VideoConfigurationWidget extends StatefulWidget {
  final Future<void> Function() onDownload;
  final VoidCallback? onClear;
  final VoidCallback? onQueue;
  final VoidCallback? onCancel;

  const VideoConfigurationWidget({
    super.key,
    required this.onDownload,
    this.onClear,
    this.onQueue,
    this.onCancel,
  });

  @override
  State<VideoConfigurationWidget> createState() =>
      _VideoConfigurationWidgetState();
}

class _VideoConfigurationWidgetState extends State<VideoConfigurationWidget> {
  bool _optionsExpanded = false;

  VoidCallback? get _effectiveCancel => widget.onCancel ?? widget.onClear;

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final aero = context.aero;

    if (!videoProvider.hasVideo &&
        !videoProvider.isLoading &&
        !videoProvider.hasError) {
      return const SizedBox.shrink();
    }

    if (videoProvider.isLoading) {
      return _buildLoadingSkeleton(context, aero);
    }

    if (videoProvider.hasError) {
      return _buildErrorState(context, aero, videoProvider);
    }

    final video = videoProvider.videoInfo;
    if (video == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        return AeroCard(
          borderRadius: AeroRadius.lgBorderRadius,
          backgroundColor: aero.surface1,
          borderColor: aero.outline,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: isCompact
                    ? Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(AeroSpace.xl),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 520,
                                      ),
                                      child: _buildVideoSummary(
                                        context,
                                        aero,
                                        videoProvider,
                                        video,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AeroSpace.xl),
                                  Divider(height: 1, color: aero.outline),
                                  const SizedBox(height: AeroSpace.xl),
                                  _buildConfigurationOptions(
                                    context,
                                    aero,
                                    videoProvider,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _buildBottomActionBar(context, aero, videoProvider),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 40,
                            child: _buildLeftPane(
                              context,
                              aero,
                              videoProvider,
                              video,
                            ),
                          ),
                          Container(width: 1, color: aero.outline),
                          Expanded(
                            flex: 60,
                            child: _buildRightPane(
                              context,
                              aero,
                              videoProvider,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // Left 40% Pane
  // ==========================================

  Widget _buildLeftPane(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
    VideoInfo video,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AeroSpace.xxl),
      child: _buildVideoSummary(context, aero, provider, video),
    );
  }

  Widget _buildVideoSummary(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
    VideoInfo video,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 16:9 Thumbnail Tile with soft elevation
        Container(
          decoration: BoxDecoration(
            borderRadius: AeroRadius.mdBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ThumbnailTile(
            imageUrl: video.thumbnailUrl,
            duration: video.formattedDuration,
            borderRadius: AeroRadius.mdBorderRadius,
          ),
        ),
        const SizedBox(height: AeroSpace.xl),

        // Video Title
        Text(
          video.title,
          style: AeroText.titleSm.copyWith(
            color: aero.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1.35,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AeroSpace.md),

        // Channel Creator Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: aero.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: aero.outline.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: aero.primary.withValues(alpha: 0.15),
                child: Icon(
                  Symbols.person_rounded,
                  size: 13,
                  color: aero.primary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  video.channel,
                  style: AeroText.bodySm.copyWith(
                    color: aero.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AeroSpace.md),

        // Stats row: Views & Formatted Date
        Wrap(
          spacing: AeroSpace.sm,
          runSpacing: AeroSpace.xs,
          children: [
            _buildStatItem(
              aero,
              Symbols.visibility_rounded,
              video.formattedViewCount,
            ),
            if (video.uploadDate.isNotEmpty)
              _buildStatItem(
                aero,
                Symbols.calendar_today_rounded,
                _formatUploadDate(video.uploadDate),
              ),
          ],
        ),
        const SizedBox(height: AeroSpace.xl),

        // Status indicator
        StatusPill(
          label: provider.audioOnly
              ? 'Audio Extract Ready'
              : 'Ready to Download',
          type: StatusPillType.success,
          icon: Symbols.check_circle_rounded,
        ),
      ],
    );
  }

  String _formatUploadDate(String raw) {
    if (raw.isEmpty) return '';
    if (raw.length == 8 && int.tryParse(raw) != null) {
      final year = raw.substring(0, 4);
      final month = int.tryParse(raw.substring(4, 6)) ?? 1;
      final day = int.tryParse(raw.substring(6, 8)) ?? 1;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final monthStr = (month >= 1 && month <= 12) ? months[month - 1] : '';
      return '$monthStr $day, $year';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
    }
    return raw;
  }

  Widget _buildStatItem(AeroColors aero, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: aero.surface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: aero.outline.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: aero.onSurfaceFaint),
          const SizedBox(width: 5),
          Text(
            text,
            style: AeroText.caption.copyWith(
              color: aero.onSurfaceMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Right 60% Pane
  // ==========================================

  Widget _buildRightPane(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    return Column(
      children: [
        // Scrollable configurations
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AeroSpace.xxl),
            child: _buildConfigurationOptions(context, aero, provider),
          ),
        ),

        // Pinned Bottom-Right Action Bar
        _buildBottomActionBar(context, aero, provider),
      ],
    );
  }

  Widget _buildConfigurationOptions(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AeroSegmentedControl(
          isAudio: provider.audioOnly,
          onChanged: (isAudio) => provider.setAudioOnly(isAudio),
        ),
        const SizedBox(height: AeroSpace.xl),
        if (provider.audioOnly)
          _buildAudioQualitySection(context, aero, provider)
        else
          _buildVideoQualitySection(context, aero, provider),
        const SizedBox(height: AeroSpace.xl),
        _buildOptionsAccordion(context, aero, provider),
      ],
    );
  }

  Widget _buildVideoQualitySection(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    if (provider.availableResolutions.isEmpty) {
      return Text(
        'No resolutions available',
        style: AeroText.bodySm.copyWith(color: aero.onSurfaceMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'QUALITY (RESOLUTION)',
          margin: EdgeInsets.only(top: 0, bottom: AeroSpace.md),
        ),

        // 3-Column Grid of FormatChips
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            const columns = 3;
            final itemWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: provider.availableResolutions.map((option) {
                final isSelected =
                    option.height == provider.selectedResolution?.height;

                // Quality badges: 4K, 2K, FHD, HD
                String? badge;
                if (option.height >= 2160) {
                  badge = '4K';
                } else if (option.height >= 1440) {
                  badge = '2K';
                } else if (option.height >= 1080) {
                  badge = 'FHD';
                } else if (option.height >= 720) {
                  badge = 'HD';
                }

                return SizedBox(
                  width: itemWidth,
                  child: FormatChip(
                    label: option.label,
                    badge: badge,
                    sizeEstimate: option.formattedSize,
                    selected: isSelected,
                    onTap: () => provider.selectResolution(option),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: AeroSpace.xl),

        // Codec Variants list
        _buildCodecVariants(context, aero, provider),

        // Audio merge track selector if video is video-only
        if (provider.selectedVideoFormat?.hasAudio == false) ...[
          const SizedBox(height: AeroSpace.xl),
          _buildAudioTrackSelector(context, aero, provider),
        ],
      ],
    );
  }

  Widget _buildCodecVariants(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    final resolution = provider.selectedResolution;
    if (resolution == null || resolution.formats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'CODEC & CONTAINER',
          margin: EdgeInsets.only(top: 0, bottom: AeroSpace.md),
        ),
        Wrap(
          spacing: AeroSpace.sm,
          runSpacing: AeroSpace.sm,
          children: resolution.formats.map((format) {
            final isSelected =
                provider.selectedVideoFormat?.formatId == format.formatId;
            final container = (format.extension ?? 'mp4').toUpperCase();
            final label = '$container · ${format.codecName}';

            return FormatChip(
              label: label,
              badge: format.isHdr
                  ? 'HDR'
                  : format.is60fps
                  ? '${format.fps!.round()}fps'
                  : null,
              sizeEstimate: provider.formattedTotalSizeForFormat(format),
              selected: isSelected,
              onTap: () => provider.setSelectedVideoFormat(format),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAudioTrackSelector(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    final video = provider.videoInfo;
    if (video == null || video.audioOnlyFormats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'AUDIO TRACK TO MERGE',
          margin: EdgeInsets.only(top: 0, bottom: AeroSpace.md),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AeroSpace.lg,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: aero.surface2,
            borderRadius: AeroRadius.smBorderRadius,
            border: Border.all(color: aero.outline, width: 1.0),
          ),
          child: Row(
            children: [
              Icon(Symbols.audiotrack_rounded, size: 18, color: aero.primary),
              const SizedBox(width: AeroSpace.md),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<FormatInfo>(
                    value: provider.selectedAudioMergeStream,
                    isExpanded: true,
                    dropdownColor: aero.surface2,
                    icon: Icon(
                      Symbols.arrow_drop_down_rounded,
                      color: aero.onSurfaceMuted,
                    ),
                    style: AeroText.bodySm.copyWith(color: aero.onSurface),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        provider.setSelectedAudioMergeStream(newValue);
                      }
                    },
                    items: video.audioOnlyFormats.map((format) {
                      final bitrate = format.audioBitrate ?? 0;
                      final size = format.formattedEstimatedFilesize(
                        video.duration,
                      );
                      return DropdownMenuItem<FormatInfo>(
                        value: format,
                        child: Text(
                          '${format.audioTrackLabel} · ${bitrate}kbps ($size) [${format.codecName}]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioQualitySection(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'AUDIO QUALITY TIER'),
        const SizedBox(height: AeroSpace.md),
        Wrap(
          spacing: AeroSpace.sm,
          runSpacing: AeroSpace.sm,
          children: AudioQuality.values.map((quality) {
            final isSelected = quality == provider.selectedAudioQuality;
            return FormatChip(
              label: quality.label,
              selected: isSelected,
              onTap: () => provider.setAudioQuality(quality),
            );
          }).toList(),
        ),
        const SizedBox(height: AeroSpace.xl),

        // Detailed available streams for the chosen quality
        _buildAudioStreamsList(context, aero, provider),
      ],
    );
  }

  Widget _buildAudioStreamsList(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    final video = provider.videoInfo;
    if (video == null) return const SizedBox.shrink();

    final audioFormats = video.getAudioFormatsForQuality(
      provider.selectedAudioQuality,
    );

    if (audioFormats.isEmpty) {
      return Text(
        'No audio streams available for this quality tier.',
        style: AeroText.bodySm.copyWith(color: aero.onSurfaceMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'AUDIO STREAMS'),
        const SizedBox(height: AeroSpace.md),
        Wrap(
          spacing: AeroSpace.sm,
          runSpacing: AeroSpace.sm,
          children: audioFormats.map((format) {
            final isSelected =
                format.formatId == provider.selectedAudioMergeStream?.formatId;
            final ext = (format.extension ?? 'AUDIO').toUpperCase();
            final label = '$ext · ${format.audioBitrate ?? 0}kbps';
            final size = format.formattedEstimatedFilesize(video.duration);

            return FormatChip(
              label: label,
              sizeEstimate: size,
              badge: format.audioTrackLabel,
              selected: isSelected,
              onTap: () => provider.setSelectedAudioMergeStream(format),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // Options Accordion
  // ==========================================

  Widget _buildOptionsAccordion(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    final settingsProvider = context.watch<PlatformSettingsProvider>();
    final video = provider.videoInfo;

    return AeroCard(
      borderRadius: AeroRadius.mdBorderRadius,
      backgroundColor: aero.surface2,
      borderColor: aero.outline,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => setState(() => _optionsExpanded = !_optionsExpanded),
            borderRadius: AeroRadius.mdBorderRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AeroSpace.lg,
                vertical: AeroSpace.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Symbols.tune_rounded,
                    size: 18,
                    color: aero.onSurfaceMuted,
                  ),
                  const SizedBox(width: AeroSpace.md),
                  Text(
                    'More Options',
                    style: AeroText.bodySm.copyWith(
                      color: aero.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _optionsExpanded ? 0.5 : 0.0,
                    duration: appMotionDuration(context, AppMotion.short),
                    child: Icon(
                      Symbols.keyboard_arrow_down_rounded,
                      size: 20,
                      color: aero.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible rows
          if (_optionsExpanded) ...[
            Divider(height: 1, color: aero.outline),

            // Container row
            SettingsRow(
              icon: Symbols.folder_zip_rounded,
              title: 'Container Format',
              subtitle: provider.audioOnly
                  ? 'MP3 / M4A / Opus based on stream'
                  : (provider.selectedVideoFormat?.extension ?? 'mp4')
                        .toUpperCase(),
              trailing: Text(
                provider.audioOnly
                    ? (provider.selectedAudioMergeStream?.extension ?? 'audio')
                          .toUpperCase()
                    : (provider.selectedVideoFormat?.extension ?? 'mp4')
                          .toUpperCase(),
                style: AeroText.caption.copyWith(
                  color: aero.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(height: 1, color: aero.outline),

            // Subtitles row
            if (video != null && video.subtitles.isNotEmpty) ...[
              SettingsRow(
                icon: Symbols.subtitles_rounded,
                title: 'Subtitles',
                subtitle: provider.selectedSubtitles.isEmpty
                    ? 'None selected'
                    : '${provider.selectedSubtitles.length} language(s) selected',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Embed',
                      style: AeroText.caption.copyWith(
                        color: aero.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(width: AeroSpace.xs),
                    Switch(
                      value: provider.embedSubtitles,
                      onChanged: provider.selectedSubtitles.isNotEmpty
                          ? (v) => provider.setEmbedSubtitles(v)
                          : null,
                      activeThumbColor: aero.primary,
                    ),
                  ],
                ),
              ),
              // Subtitle chips row
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AeroSpace.lg,
                  0,
                  AeroSpace.lg,
                  AeroSpace.md,
                ),
                child: Wrap(
                  spacing: AeroSpace.xs,
                  runSpacing: AeroSpace.xs,
                  children: video.subtitles.take(6).map((sub) {
                    final isSel = provider.selectedSubtitles.contains(sub);
                    return AeroChip(
                      text: sub.name,
                      selected: isSel,
                      onTap: () => provider.toggleSubtitle(sub),
                    );
                  }).toList(),
                ),
              ),
              Divider(height: 1, color: aero.outline),
            ],

            // SponsorBlock row
            SettingsRow(
              icon: Symbols.shield_rounded,
              title: 'SponsorBlock',
              subtitle: 'Skip sponsors, intros and outros automatically',
              trailing: Switch(
                value: settingsProvider.sponsorBlockEnabled,
                onChanged: (v) => settingsProvider.setSponsorBlockEnabled(v),
                activeThumbColor: aero.primary,
              ),
            ),
            Divider(height: 1, color: aero.outline),

            // Trim row
            SettingsRow(
              icon: Symbols.content_cut_rounded,
              title: 'Video Range (Trim)',
              subtitle:
                  'Full length (0:00 - ${video?.formattedDuration ?? ""})',
              trailing: Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: aero.onSurfaceMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // Pinned Bottom-Right Action Bar
  // ==========================================

  Widget _buildBottomActionBar(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    final video = provider.videoInfo;
    final downloadProvider = context.watch<DownloadProvider>();
    final activeDownloads = downloadProvider.activeDownloads;

    final activeItem = activeDownloads.where((item) {
      if (video == null) return false;
      return item.id == video.id ||
          item.id.startsWith('${video.id}_') ||
          item.url == video.url;
    }).firstOrNull;

    final bool isPreparing =
        activeItem != null &&
        (activeItem.status == DownloadStatus.queued ||
            activeItem.status == DownloadStatus.pending);

    final bool isDownloading =
        activeItem != null &&
        (activeItem.status == DownloadStatus.downloadingVideo ||
            activeItem.status == DownloadStatus.downloadingAudio ||
            activeItem.status == DownloadStatus.merging);

    final double progress = activeItem?.progress ?? 0.0;

    final estSize = provider.totalEstimatedDownloadSize;
    final qualityLabel = provider.audioOnly
        ? provider.selectedAudioQuality.label
        : (provider.selectedHeight == null
              ? 'Best available'
              : '${provider.selectedHeight}p');
    final estimateLabel = estSize > 0
        ? '${(estSize / 1024 / 1024).toStringAsFixed(1)} MB estimated'
        : 'Size calculated from selected format';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AeroSpace.xxl,
        vertical: AeroSpace.lg,
      ),
      decoration: BoxDecoration(
        color: aero.surface1,
        border: Border(top: BorderSide(color: aero.outline, width: 1.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Progress Bar when downloading
          if (isDownloading) ...[
            AeroProgress(value: progress),
            const SizedBox(height: AeroSpace.md),
          ],

          LayoutBuilder(
            builder: (context, constraints) {
              final details = Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: aero.primarySoft,
                      borderRadius: BorderRadius.circular(AeroRadius.xs),
                      border: Border.all(
                        color: aero.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        provider.audioOnly
                            ? Symbols.headphones_rounded
                            : Symbols.video_file_rounded,
                        size: 18,
                        color: aero.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AeroSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.audioOnly
                              ? 'Audio download'
                              : 'Video download',
                          style: AeroText.bodySm.copyWith(
                            color: aero.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$qualityLabel · $estimateLabel',
                          style: AeroText.caption.copyWith(
                            color: aero.onSurfaceMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actions = Wrap(
                alignment: WrapAlignment.end,
                spacing: AeroSpace.sm,
                runSpacing: AeroSpace.sm,
                children: [
                  if (_effectiveCancel != null)
                    AeroButton(
                      variant: AeroButtonVariant.ghost,
                      text: 'Change link',
                      onPressed: _effectiveCancel,
                    ),
                  if (widget.onQueue != null)
                    AeroButton(
                      variant: AeroButtonVariant.tonal,
                      text: 'Add to queue',
                      icon: const Icon(Symbols.playlist_add_rounded, size: 18),
                      onPressed: (isDownloading || isPreparing)
                          ? null
                          : widget.onQueue,
                    ),
                  AeroButton(
                    variant: AeroButtonVariant.primary,
                    isLoading: isPreparing,
                    icon: const Icon(Symbols.download_rounded, size: 18),
                    text: isDownloading
                        ? '${(progress * 100).toInt()}%'
                        : 'Download',
                    onPressed: (isDownloading || isPreparing)
                        ? null
                        : () => widget.onDownload(),
                  ),
                ],
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: AeroSpace.md),
                    actions,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AeroSpace.lg),
                  actions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Loading & Error States
  // ==========================================

  Widget _buildLoadingSkeleton(BuildContext context, AeroColors aero) {
    return AeroCard(
      borderRadius: AeroRadius.lgBorderRadius,
      backgroundColor: aero.surface1,
      borderColor: aero.outline,
      padding: const EdgeInsets.all(AeroSpace.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left skeleton
          Expanded(
            flex: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ThumbnailTile(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
                const SizedBox(height: AeroSpace.xl),
                _skeletonBox(aero, height: 20, widthFactor: 0.85),
                const SizedBox(height: AeroSpace.md),
                _skeletonBox(aero, height: 14, widthFactor: 0.5),
                const SizedBox(height: AeroSpace.md),
                _skeletonBox(aero, height: 12, widthFactor: 0.7),
              ],
            ),
          ),
          Container(width: 1.0, color: aero.outline),
          // Right skeleton
          Expanded(
            flex: 60,
            child: Padding(
              padding: const EdgeInsets.all(AeroSpace.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(aero, height: 38, widthFactor: 1.0),
                  const SizedBox(height: AeroSpace.xxl),
                  _skeletonBox(aero, height: 16, widthFactor: 0.4),
                  const SizedBox(height: AeroSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _skeletonBox(aero, height: 48, widthFactor: 1.0),
                      ),
                      const SizedBox(width: AeroSpace.sm),
                      Expanded(
                        child: _skeletonBox(aero, height: 48, widthFactor: 1.0),
                      ),
                      const SizedBox(width: AeroSpace.sm),
                      Expanded(
                        child: _skeletonBox(aero, height: 48, widthFactor: 1.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: AeroSpace.xl),
                  _skeletonBox(aero, height: 80, widthFactor: 1.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox(
    AeroColors aero, {
    required double height,
    required double widthFactor,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: aero.surface2,
          borderRadius: AeroRadius.smBorderRadius,
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    return Center(
      child: EmptyState(
        icon: Symbols.error_rounded,
        title: "Couldn't load video info",
        description:
            provider.errorMessage ?? 'Something went wrong fetching formats.',
        actionLabel: 'Try again',
        onAction: () {
          final url = provider.currentUrl;
          if (url.isNotEmpty) provider.fetchVideoInfo(url);
        },
        secondaryActionLabel: _effectiveCancel != null ? 'Close' : null,
        onSecondaryAction: _effectiveCancel,
      ),
    );
  }
}
