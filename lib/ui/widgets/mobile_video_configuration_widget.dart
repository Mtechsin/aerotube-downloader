import 'package:material_symbols_icons/symbols.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../models/download_item.dart';
import '../../models/video_info.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/video_provider.dart';
import '../components/components.dart';

/// Full-screen Android video configuration panel conforming to AeroTube redesign spec.
///
/// Features:
/// - Collapsing header with 16:9 [ThumbnailTile] and bottom gradient scrim overlay
///   (title, channel, duration chip).
/// - [AeroSegmentedControl] (Video | Audio) with a linear sliding indicator.
/// - Wrapping [FormatChip] grid with estimated size under each label.
/// - Codec variant selection with HDR and 60fps tags.
/// - Collapsible "More options" accordion ([SettingsRow]s for container, subtitles, SponsorBlock, trim).
/// - Sticky bottom action bar: "Download · 142 MB" (primary, full width) + destination folder ghost button.
class MobileVideoConfigurationWidget extends StatefulWidget {
  final Future<void> Function() onDownload;
  final VoidCallback? onClear;

  const MobileVideoConfigurationWidget({
    super.key,
    required this.onDownload,
    this.onClear,
  });

  @override
  State<MobileVideoConfigurationWidget> createState() =>
      _MobileVideoConfigurationWidgetState();
}

class _MobileVideoConfigurationWidgetState
    extends State<MobileVideoConfigurationWidget> {
  bool _optionsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final aero = context.aero;

    if (videoProvider.isLoading) {
      return _buildLoadingState(context, aero, videoProvider);
    }

    if (videoProvider.hasError) {
      return _buildErrorState(context, aero, videoProvider);
    }

    final video = videoProvider.videoInfo;
    if (video == null || !videoProvider.hasVideo) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: aero.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Collapsing 16:9 Header with scrim overlay
              _buildCollapsingHeader(context, aero, videoProvider, video),

              // 2. Configuration Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AeroSpace.xl,
                    AeroSpace.lg,
                    AeroSpace.xl,
                    140, // Bottom padding so sticky bar never clips content
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video | Audio Segmented Control
                      AeroSegmentedControl(
                        isAudio: videoProvider.audioOnly,
                        onChanged: (isAudio) =>
                            videoProvider.setAudioOnly(isAudio),
                      ),
                      const SizedBox(height: AeroSpace.xl),

                      // Quality Section (Video format chips or Audio tier chips)
                      if (!videoProvider.audioOnly) ...[
                        _buildVideoQualitySection(context, aero, videoProvider),
                      ] else ...[
                        _buildAudioQualitySection(context, aero, videoProvider),
                      ],
                      const SizedBox(height: AeroSpace.xl),

                      // Collapsible "More options" accordion
                      _buildOptionsAccordion(
                        context,
                        aero,
                        videoProvider,
                        video,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomBar(context, aero, videoProvider, video),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. Collapsing 16:9 Header
  // ==========================================

  Widget _buildCollapsingHeader(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
    VideoInfo video,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final headerHeight = screenWidth * 9 / 16;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: headerHeight,
      backgroundColor: aero.surface1,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: aero.surface1.withValues(alpha: 0.75),
            shape: BoxShape.circle,
            border: Border.all(color: aero.outline, width: 1.0),
          ),
          child: IconButton(
            icon: const Icon(Symbols.arrow_back_rounded, size: 20),
            color: aero.onSurface,
            tooltip: 'Back',
            onPressed: () {
              if (widget.onClear != null) {
                widget.onClear!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: aero.surface1.withValues(alpha: 0.75),
              shape: BoxShape.circle,
              border: Border.all(color: aero.outline, width: 1.0),
            ),
            child: IconButton(
              icon: const Icon(Symbols.home_rounded, size: 20),
              color: aero.onSurface,
              tooltip: 'Home',
              onPressed: () {
                final nav = context.read<NavigationProvider>();
                if (provider.isLoading) {
                  provider.cancelFetch();
                }
                Navigator.of(context).popUntil((route) => route.isFirst);
                nav.switchToHome();
              },
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail Tile
            ThumbnailTile(
              imageUrl: video.thumbnailUrl,
              borderRadius: BorderRadius.zero,
              fit: BoxFit.cover,
            ),

            // Bottom Gradient Scrim
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Metadata overlay at bottom of header
            Positioned(
              left: AeroSpace.lg,
              right: AeroSpace.lg,
              bottom: AeroSpace.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              style: AeroText.titleSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${video.channel} · ${video.formattedViewCount} views',
                              style: AeroText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AeroSpace.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          video.formattedDuration,
                          style: AeroText.caption.withTabularFigures().copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
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

  // ==========================================
  // 2. Video Quality Section
  // ==========================================

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
        const SectionHeader(title: 'QUALITY'),
        const SizedBox(height: AeroSpace.sm),

        // Show the full quality ladder without hiding options off-screen.
        Wrap(
          spacing: AeroSpace.sm,
          runSpacing: AeroSpace.sm,
          children: provider.availableResolutions.map((option) {
            final isSelected =
                option.height == provider.selectedResolution?.height;

            return FormatChip(
              label: option.label,
              sizeEstimate: option.formattedSize,
              selected: isSelected,
              onTap: () => provider.selectResolution(option),
            );
          }).toList(),
        ),
        const SizedBox(height: AeroSpace.lg),

        // Codec variants row
        _buildCodecVariants(context, aero, provider),

        // Audio merge track selector if video is video-only
        if (provider.selectedVideoFormat?.hasAudio == false) ...[
          const SizedBox(height: AeroSpace.lg),
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
        const SectionHeader(title: 'CODEC VARIANTS'),
        const SizedBox(height: AeroSpace.sm),
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
                  ? '60fps'
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
        const SectionHeader(title: 'AUDIO TRACK TO MERGE'),
        const SizedBox(height: AeroSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AeroSpace.md),
          decoration: BoxDecoration(
            color: aero.surface2,
            borderRadius: AeroRadius.smBorderRadius,
            border: Border.all(color: aero.outline, width: 1.0),
          ),
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
                final size = format.formattedEstimatedFilesize(video.duration);
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
    );
  }

  // ==========================================
  // 3. Audio Quality Section
  // ==========================================

  Widget _buildAudioQualitySection(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'AUDIO QUALITY TIER'),
        const SizedBox(height: AeroSpace.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AudioQuality.values.map((quality) {
              final isSelected = quality == provider.selectedAudioQuality;
              return Padding(
                padding: const EdgeInsets.only(right: AeroSpace.sm),
                child: FormatChip(
                  label: quality.label,
                  selected: isSelected,
                  onTap: () => provider.setAudioQuality(quality),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AeroSpace.lg),
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
        'No audio streams available.',
        style: AeroText.bodySm.copyWith(color: aero.onSurfaceMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'AUDIO STREAMS'),
        const SizedBox(height: AeroSpace.sm),
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
  // 4. Options Accordion (Collapsible)
  // ==========================================

  Widget _buildOptionsAccordion(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
    VideoInfo video,
  ) {
    final settingsProvider = context.watch<PlatformSettingsProvider>();

    return AeroCard(
      borderRadius: AeroRadius.mdBorderRadius,
      backgroundColor: aero.surface1,
      borderColor: aero.outline,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
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

          // Options rows
          if (_optionsExpanded) ...[
            Divider(height: 1, color: aero.outline),

            // Container row
            SettingsRow(
              icon: Symbols.folder_zip_rounded,
              title: 'Container',
              subtitle: provider.audioOnly
                  ? 'Audio stream default'
                  : (provider.selectedVideoFormat?.extension ?? 'mp4')
                        .toUpperCase(),
              trailing: Text(
                provider.audioOnly
                    ? (provider.selectedAudioMergeStream?.extension ?? 'AUDIO')
                          .toUpperCase()
                    : (provider.selectedVideoFormat?.extension ?? 'MP4')
                          .toUpperCase(),
                style: AeroText.caption.copyWith(
                  color: aero.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(height: 1, color: aero.outline),

            // Subtitles row
            if (video.subtitles.isNotEmpty) ...[
              SettingsRow(
                icon: Symbols.subtitles_rounded,
                title: 'Subtitles',
                subtitle: provider.selectedSubtitles.isEmpty
                    ? 'None selected'
                    : '${provider.selectedSubtitles.length} selected',
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
                  children:
                      _sortSubtitles(
                        video.subtitles,
                        settingsProvider.defaultSubtitleLanguage,
                      ).take(6).map((sub) {
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
              subtitle: 'Skip sponsored segments automatically',
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
              title: 'Trim',
              subtitle: 'Full video (0:00 - ${video.formattedDuration})',
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

  List<SubtitleTrack> _sortSubtitles(
    List<SubtitleTrack> subtitles,
    String preferred,
  ) {
    if (preferred.isEmpty || preferred == 'auto') return subtitles;
    final copy = List<SubtitleTrack>.from(subtitles);
    copy.sort((a, b) {
      final aPref = a.languageCode.toLowerCase().startsWith(
        preferred.toLowerCase(),
      );
      final bPref = b.languageCode.toLowerCase().startsWith(
        preferred.toLowerCase(),
      );
      if (aPref == bPref) return a.name.compareTo(b.name);
      return aPref ? -1 : 1;
    });
    return copy;
  }

  // ==========================================
  // 5. Sticky Bottom Action Bar
  // ==========================================

  Widget _buildStickyBottomBar(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
    VideoInfo video,
  ) {
    final settingsProvider = context.watch<PlatformSettingsProvider>();
    final outputPath = settingsProvider.settings.outputPath ?? '';

    final estSize = provider.totalEstimatedDownloadSize;
    final String sizeLabel = estSize > 0
        ? ' · ${(estSize / 1024 / 1024).toStringAsFixed(1)} MB'
        : '';

    final videoId = video.id;
    final videoUrl = video.url;

    return Selector<MobileDownloadProvider, (String, DownloadStatus, double)?>(
      selector: (_, p) {
        for (final item in p.activeDownloads) {
          if (item.id == videoId ||
              item.id.startsWith('${videoId}_') ||
              item.url == videoUrl) {
            return (item.id, item.status, item.progress);
          }
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
        final double progress = snapshot?.$3 ?? 0.0;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live Progress Line while downloading
              if (isDownloading) ...[
                AeroProgress(value: progress),
                const SizedBox(height: AeroSpace.sm),
              ],

              // Row: Destination Folder Ghost Button
              Row(
                children: [
                  Expanded(
                    child: AeroButton(
                      variant: AeroButtonVariant.ghost,
                      icon: const Icon(Symbols.folder_rounded, size: 16),
                      text: outputPath.isNotEmpty
                          ? outputPath.split(RegExp(r'[\\/]')).last
                          : 'Select Destination Folder',
                      tooltip: outputPath,
                      onPressed: () async {
                        // ignore: deprecated_member_use
                        final picked = await FilePicker.getDirectoryPath();
                        if (picked != null && picked.isNotEmpty) {
                          await settingsProvider.setOutputPath(picked);
                        }
                      },
                    ),
                  ),
                  if (widget.onClear != null && !isDownloading && !isPreparing)
                    AeroButton(
                      variant: AeroButtonVariant.ghost,
                      text: 'Clear',
                      onPressed: widget.onClear,
                    ),
                ],
              ),
              const SizedBox(height: AeroSpace.sm),

              // Full-Width Primary Download Button
              AeroButton(
                variant: AeroButtonVariant.primary,
                expand: true,
                isLoading: isPreparing,
                icon: const Icon(Symbols.download_rounded, size: 18),
                text: isPreparing
                    ? (status == DownloadStatus.queued
                          ? 'Queued...'
                          : 'Preparing...')
                    : isDownloading
                    ? (status == DownloadStatus.merging
                          ? 'Merging · ${(progress * 100).toInt()}%'
                          : 'Downloading · ${(progress * 100).toInt()}%')
                    : 'Download$sizeLabel',
                onPressed: (isDownloading || isPreparing)
                    ? null
                    : () => widget.onDownload(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // Loading & Error States
  // ==========================================

  Widget _buildLoadingState(
    BuildContext context,
    AeroColors aero,
    VideoProvider provider,
  ) {
    return Scaffold(
      backgroundColor: aero.bg,
      appBar: AppBar(
        backgroundColor: aero.surface1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () {
            provider.cancelFetch();
            if (widget.onClear != null) {
              widget.onClear!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text('Loading Video', style: AeroText.titleSm),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AeroSpace.xxl),
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
            _skeletonBar(aero, height: 18, widthFactor: 0.9),
            const SizedBox(height: AeroSpace.md),
            _skeletonBar(aero, height: 12, widthFactor: 0.5),
            const SizedBox(height: AeroSpace.xxl),
            Row(
              children: [
                Expanded(
                  child: _skeletonBar(aero, height: 44, widthFactor: 1.0),
                ),
                const SizedBox(width: AeroSpace.sm),
                Expanded(
                  child: _skeletonBar(aero, height: 44, widthFactor: 1.0),
                ),
                const SizedBox(width: AeroSpace.sm),
                Expanded(
                  child: _skeletonBar(aero, height: 44, widthFactor: 1.0),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: AeroButton(
                    variant: AeroButtonVariant.ghost,
                    text: 'Cancel',
                    onPressed: () {
                      provider.cancelFetch();
                      if (widget.onClear != null) {
                        widget.onClear!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBar(
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
    return Scaffold(
      backgroundColor: aero.bg,
      appBar: AppBar(
        backgroundColor: aero.surface1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () {
            if (widget.onClear != null) {
              widget.onClear!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Center(
        child: EmptyState(
          icon: Symbols.error_rounded,
          title: "Couldn't load video info",
          description: provider.errorMessage ?? 'Failed to load video streams.',
          actionLabel: 'Try again',
          onAction: () {
            final url = provider.currentUrl;
            if (url.isNotEmpty) provider.fetchVideoInfo(url);
          },
          secondaryActionLabel: 'Back',
          onSecondaryAction: () {
            if (widget.onClear != null) {
              widget.onClear!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }
}
