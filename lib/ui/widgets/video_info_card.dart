import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/video_info.dart';

class VideoInfoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback? onClear;

  const VideoInfoCard({
    super.key,
    required this.video,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with gradient overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.error_outline, size: 48),
                      ),
                    ),
                  ),
                ),
                // Duration badge
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Clear button
                if (onClear != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filled(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Video info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Channel
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          video.channel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.visibility_rounded,
                        label: video.formattedViewCount,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.high_quality_rounded,
                        label: _getBestQuality(),
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.video_library_rounded,
                        label: '${video.formats.length} formats',
                      ),
                    ],
                  ),
                ]
                .animate(interval: 50.ms) // Stagger internal content
                .fade(duration: 400.ms, curve: Curves.easeOut)
                .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
              ),
            ),
          ],
        ),
      )
      .animate()
      .fadeIn(duration: 500.ms, curve: Curves.easeOutQuart)
      .scaleXY(begin: 0.95, end: 1.0, duration: 500.ms, curve: Curves.easeOutQuart)
      .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutQuart),
    );
  }

  String _getBestQuality() {
    final resolutions = video.availableResolutions;
    if (resolutions.isEmpty) return 'Unknown';
    
    final best = resolutions.first;
    if (best >= 2160) return '4K';
    if (best >= 1440) return '2K';
    if (best >= 1080) return 'Full HD';
    if (best >= 720) return 'HD';
    return '${best}p';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
