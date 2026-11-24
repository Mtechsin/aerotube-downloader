import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/platform_settings_provider.dart';

/// Skeleton placeholder for the search screen, matching Aero geometry and tokens.
/// Adapts between 2-line rows (Mobile) and card grid (Windows).
class SearchSkeleton extends StatelessWidget {
  const SearchSkeleton({super.key});

  Widget _applyShimmer(
    Widget child,
    Color shimmerColor, {
    Duration delay = Duration.zero,
    required bool enableAnimations,
  }) {
    if (!enableAnimations) return child;
    return child
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1500.ms,
          curve: Curves.linear,
          delay: delay,
          color: shimmerColor,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final settingsProvider = Provider.of<PlatformSettingsProvider?>(context);
    final enableAnimations =
        (settingsProvider?.enableAnimations ?? true) &&
        !MediaQuery.disableAnimationsOf(context);
    final baseColor = colors.surface2;
    final shimmerColor = colors.surface3;

    if (PlatformUtils.isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AeroSpace.lg,
          vertical: AeroSpace.sm,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: AeroSpace.md),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(AeroSpace.sm),
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: AeroRadius.lgBorderRadius,
              border: Border.all(color: colors.outline, width: 1.0),
            ),
            child: Row(
              children: [
                // 16:9 thumbnail skeleton
                _applyShimmer(
                  Container(
                    width: 112,
                    height: 64,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: AeroRadius.mdBorderRadius,
                    ),
                  ),
                  shimmerColor,
                  delay: (index * 60).ms,
                  enableAnimations: enableAnimations,
                ),
                const SizedBox(width: AeroSpace.md),
                // Text rows
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _applyShimmer(
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        shimmerColor,
                        delay: (index * 60 + 50).ms,
                        enableAnimations: enableAnimations,
                      ),
                      const SizedBox(height: AeroSpace.xs),
                      _applyShimmer(
                        Container(
                          height: 12,
                          width: 140,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        shimmerColor,
                        delay: (index * 60 + 100).ms,
                        enableAnimations: enableAnimations,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AeroSpace.sm),
                // Trailing button placeholder
                _applyShimmer(
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: AeroRadius.smBorderRadius,
                    ),
                  ),
                  shimmerColor,
                  delay: (index * 60 + 120).ms,
                  enableAnimations: enableAnimations,
                ),
              ],
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AeroSpace.xxl,
        vertical: AeroSpace.md,
      ),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 310,
        crossAxisSpacing: AeroSpace.lg,
        mainAxisSpacing: AeroSpace.lg,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: AeroRadius.lgBorderRadius,
            border: Border.all(color: colors.outline, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail placeholder
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _applyShimmer(
                  Container(
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AeroRadius.lg - 1),
                      ),
                    ),
                  ),
                  shimmerColor,
                  delay: (index * 80).ms,
                  enableAnimations: enableAnimations,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AeroSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _applyShimmer(
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      shimmerColor,
                      delay: (index * 80 + 60).ms,
                      enableAnimations: enableAnimations,
                    ),
                    const SizedBox(height: AeroSpace.sm),
                    _applyShimmer(
                      Container(
                        height: 12,
                        width: 180,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      shimmerColor,
                      delay: (index * 80 + 120).ms,
                      enableAnimations: enableAnimations,
                    ),
                    const SizedBox(height: AeroSpace.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _applyShimmer(
                          Container(
                            height: 11,
                            width: 80,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          shimmerColor,
                          delay: (index * 80 + 160).ms,
                          enableAnimations: enableAnimations,
                        ),
                        _applyShimmer(
                          Container(
                            height: 28,
                            width: 64,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: AeroRadius.mdBorderRadius,
                            ),
                          ),
                          shimmerColor,
                          delay: (index * 80 + 180).ms,
                          enableAnimations: enableAnimations,
                        ),
                      ],
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
}
