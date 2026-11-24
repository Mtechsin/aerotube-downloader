import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../models/playlist_info.dart';
import '../components/components.dart';

/// Table-style playlist video row conforming to AeroTube redesign spec.
///
/// Features:
/// - Selection checkbox.
/// - 96 px 16:9 [ThumbnailTile] with duration chip.
/// - Two-line title and channel/duration metadata.
/// - Per-row quality override popup.
/// - [AeroCard] container without raw box shadows.
class PlaylistVideoCard extends StatelessWidget {
  final PlaylistVideoItem video;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final String? qualityOverride;
  final ValueChanged<String?>? onQualityOverrideChanged;

  const PlaylistVideoCard({
    super.key,
    required this.video,
    required this.isSelected,
    required this.onToggleSelection,
    this.qualityOverride,
    this.onQualityOverrideChanged,
  });

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AeroSpace.lg,
        vertical: AeroSpace.xs,
      ),
      child: AeroCard(
        borderRadius: AeroRadius.mdBorderRadius,
        backgroundColor: isSelected
            ? Color.alphaBlend(aero.primarySoft, aero.surface1)
            : aero.surface1,
        borderColor: aero.outline,
        padding: const EdgeInsets.all(AeroSpace.md),
        onTap: onToggleSelection,
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelection(),
              activeColor: aero.primary,
              checkColor: aero.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: BorderSide(color: aero.outlineStrong, width: 1.5),
            ),
            const SizedBox(width: AeroSpace.xs),

            // A larger thumbnail makes this list easier to scan at desktop width.
            ThumbnailTile(
              imageUrl: video.thumbnailUrl,
              duration: video.formattedDuration,
              width: 112,
              height: 63,
              borderRadius: AeroRadius.smBorderRadius,
            ),
            const SizedBox(width: AeroSpace.md),

            // Video Title & Channel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AeroText.bodySm.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: aero.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (video.channel.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            video.channel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AeroText.caption.copyWith(
                              color: aero.onSurfaceFaint,
                            ),
                          ),
                        ),
                        const SizedBox(width: AeroSpace.xs),
                        Text(
                          '·',
                          style: AeroText.caption.copyWith(
                            color: aero.onSurfaceFaint,
                          ),
                        ),
                        const SizedBox(width: AeroSpace.xs),
                      ],
                      Text(
                        video.formattedDuration,
                        style: AeroText.caption.withTabularFigures().copyWith(
                          color: aero.onSurfaceFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AeroSpace.sm),

            // Per-row quality override chip / popup
            _buildQualityOverrideChip(context, aero),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOverrideChip(BuildContext context, AeroColors aero) {
    final label = qualityOverride ?? 'Auto';

    return PopupMenuButton<String>(
      tooltip: 'Override Quality',
      initialValue: qualityOverride,
      onSelected: (val) {
        if (onQualityOverrideChanged != null) {
          onQualityOverrideChanged!(val == 'auto' ? null : val);
        }
      },
      color: aero.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: AeroRadius.smBorderRadius,
        side: BorderSide(color: aero.outline),
      ),
      itemBuilder: (context) => [
        _menuItem('Auto (Batch)', 'auto', aero),
        _menuItem('4K (2160p)', '2160', aero),
        _menuItem('2K (1440p)', '1440', aero),
        _menuItem('1080p', '1080', aero),
        _menuItem('720p', '720', aero),
        _menuItem('480p', '480', aero),
        _menuItem('Audio Only', 'audio', aero),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: qualityOverride != null
              ? aero.primary.withValues(alpha: 0.15)
              : aero.surface2,
          borderRadius: AeroRadius.smBorderRadius,
          border: Border.all(
            color: qualityOverride != null ? aero.primary : aero.outline,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AeroText.caption.copyWith(
                color: qualityOverride != null
                    ? aero.primary
                    : aero.onSurfaceMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Symbols.arrow_drop_down_rounded,
              size: 14,
              color: qualityOverride != null
                  ? aero.primary
                  : aero.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String text, String value, AeroColors aero) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(text, style: AeroText.bodySm.copyWith(color: aero.onSurface)),
    );
  }
}
