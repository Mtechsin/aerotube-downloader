import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/platform_settings_provider.dart';

/// Skeleton placeholder for the search screen, matching Aero geometry and tokens.
/// Uses a single shared [AnimationController] wrapped in a [RepaintBoundary]
/// instead of per-item shimmer controllers.
class SearchSkeleton extends StatefulWidget {
  const SearchSkeleton({super.key});

  @override
  State<SearchSkeleton> createState() => _SearchSkeletonState();
}

class _SearchSkeletonState extends State<SearchSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _shimmerController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settingsProvider = Provider.of<PlatformSettingsProvider?>(context);
    final enableAnimations =
        (settingsProvider?.enableAnimations ?? true) &&
        !MediaQuery.disableAnimationsOf(context);

    if (!enableAnimations) {
      _shimmerController?.stop();
    } else {
      _shimmerController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );
      if (!_shimmerController!.isAnimating) {
        _shimmerController!.repeat();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController?.dispose();
    super.dispose();
  }

  Widget _shimmerBox({
    double? width,
    double? height,
    required BorderRadius borderRadius,
    required Color baseColor,
    required Color shimmerColor,
  }) {
    final controller = _shimmerController;
    if (controller == null || !controller.isAnimating) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: baseColor, borderRadius: borderRadius),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-2.0 + controller.value * 4.0, -0.2),
              end: Alignment(-0.5 + controller.value * 4.0, 0.2),
              colors: [baseColor, shimmerColor, baseColor],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final baseColor = colors.surface2;
    final shimmerColor = colors.surface3;

    if (PlatformUtils.isMobile) {
      return RepaintBoundary(
        child: ListView.separated(
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
                  _shimmerBox(
                    width: 112,
                    height: 64,
                    borderRadius: AeroRadius.mdBorderRadius,
                    baseColor: baseColor,
                    shimmerColor: shimmerColor,
                  ),
                  const SizedBox(width: AeroSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _shimmerBox(
                          height: 14,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(4),
                          baseColor: baseColor,
                          shimmerColor: shimmerColor,
                        ),
                        const SizedBox(height: AeroSpace.xs),
                        _shimmerBox(
                          height: 12,
                          width: 140,
                          borderRadius: BorderRadius.circular(4),
                          baseColor: baseColor,
                          shimmerColor: shimmerColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AeroSpace.sm),
                  _shimmerBox(
                    width: 36,
                    height: 36,
                    borderRadius: AeroRadius.smBorderRadius,
                    baseColor: baseColor,
                    shimmerColor: shimmerColor,
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return RepaintBoundary(
      child: GridView.builder(
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
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _shimmerBox(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AeroRadius.lg - 1),
                    ),
                    baseColor: baseColor,
                    shimmerColor: shimmerColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AeroSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(
                        height: 14,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(4),
                        baseColor: baseColor,
                        shimmerColor: shimmerColor,
                      ),
                      const SizedBox(height: AeroSpace.sm),
                      _shimmerBox(
                        height: 12,
                        width: 180,
                        borderRadius: BorderRadius.circular(4),
                        baseColor: baseColor,
                        shimmerColor: shimmerColor,
                      ),
                      const SizedBox(height: AeroSpace.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _shimmerBox(
                            height: 11,
                            width: 80,
                            borderRadius: BorderRadius.circular(4),
                            baseColor: baseColor,
                            shimmerColor: shimmerColor,
                          ),
                          _shimmerBox(
                            height: 28,
                            width: 64,
                            borderRadius: AeroRadius.mdBorderRadius,
                            baseColor: baseColor,
                            shimmerColor: shimmerColor,
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
      ),
    );
  }
}
