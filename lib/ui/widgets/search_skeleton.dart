import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/platform_settings_provider.dart';

class SearchSkeleton extends StatelessWidget {
  const SearchSkeleton({super.key});

  Widget _applyShimmer(
    Widget widget,
    Color shimmerColor, {
    Duration delay = Duration.zero,
    required bool enableAnimations,
  }) {
    if (!enableAnimations) return widget;
    return widget
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1500.ms, delay: delay, color: shimmerColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
    final settingsProvider = Provider.of<PlatformSettingsProvider?>(context);
    final enableAnimations = settingsProvider?.enableAnimations ?? true;
    final shimmerColor = theme.colorScheme.primary.withValues(alpha: 0.1);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 320,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail placeholder
              _applyShimmer(
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
                shimmerColor,
                enableAnimations: enableAnimations,
              ),
              
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title placeholder
                    _applyShimmer(
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      shimmerColor,
                      delay: 100.ms,
                      enableAnimations: enableAnimations,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Author placeholder
                    _applyShimmer(
                      Container(
                        height: 12,
                        width: 150,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      shimmerColor,
                      delay: 200.ms,
                      enableAnimations: enableAnimations,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stats placeholder
                    _applyShimmer(
                      Container(
                        height: 10,
                        width: 100,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      shimmerColor,
                      delay: 300.ms,
                      enableAnimations: enableAnimations,
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
