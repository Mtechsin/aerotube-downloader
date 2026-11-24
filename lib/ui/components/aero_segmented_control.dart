import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/typography.dart';
import 'aero_density.dart';

/// Segmented control switching between Video and Audio modes using
/// [AppMotion.linear] for the sliding indicator pill.
class AeroSegmentedControl extends StatelessWidget {
  final bool isAudio;
  final ValueChanged<bool> onChanged;
  final AeroDensity? density;

  const AeroSegmentedControl({
    super.key,
    required this.isAudio,
    required this.onChanged,
    this.density,
  });

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final effectiveDensity = AeroDensity.resolve(context, density);
    final isCompact = effectiveDensity.isCompact;
    final height = isCompact ? 38.0 : 44.0;
    final duration = appMotionDuration(context, AppMotion.medium);

    return Container(
      height: height,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: aero.surface2,
        borderRadius: AeroRadius.mdBorderRadius,
        border: Border.all(color: aero.outline, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 2) / 2;
          return Stack(
            children: [
              // Sliding indicator pill
              AnimatedAlign(
                alignment: isAudio
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                duration: duration,
                curve: AppMotion.linear,
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: aero.primarySoft,
                    borderRadius: BorderRadius.circular(AeroRadius.md - 3),
                    border: Border.all(color: aero.primary, width: 1.0),
                  ),
                ),
              ),
              // Segment buttons
              Row(
                children: [
                  Expanded(
                    child: _buildItem(
                      context,
                      label: 'Video',
                      icon: Symbols.videocam_rounded,
                      isSelected: !isAudio,
                      onTap: () => onChanged(false),
                      aero: aero,
                      isCompact: isCompact,
                    ),
                  ),
                  Expanded(
                    child: _buildItem(
                      context,
                      label: 'Audio',
                      icon: Symbols.audiotrack_rounded,
                      isSelected: isAudio,
                      onTap: () => onChanged(true),
                      aero: aero,
                      isCompact: isCompact,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AeroColors aero,
    required bool isCompact,
  }) {
    final color = isSelected ? aero.primary : aero.onSurfaceMuted;
    final textStyle = (isCompact ? AeroText.label : AeroText.bodySm).copyWith(
      color: color,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AeroRadius.md - 3),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCompact ? 16 : 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
