import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/core/logging_service.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/download_item.dart';
import 'animated_button.dart';

class DownloadItemCard extends StatefulWidget {
  final DownloadItem item;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const DownloadItemCard({
    super.key,
    required this.item,
    this.onOpenFolder,
    this.onDelete,
    this.onRetry,
    this.onCancel,
    this.onPause,
    this.onResume,
  });

  @override
  State<DownloadItemCard> createState() => _DownloadItemCardState();
}

class _DownloadItemCardState extends State<DownloadItemCard> {
  Future<void> _openContainingFolder() async {
    final path = widget.item.savePath ?? widget.item.outputPath;

    if (PlatformUtils.isWindows) {
      try {
        // Use explorer /select to highlight the file
        // Quote the path to handle spaces
        await Process.run('explorer.exe', ['/select,', path]);
      } catch (e, st) {
        LoggingService().warning(
          'Error opening folder: $e',
          component: 'DownloadItemCard',
          error: e,
          stackTrace: st,
        );
      }
    } else {
      // Fallback for other platforms if needed, but requirements are Windows focussed
      widget.onOpenFolder?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine active state for animation
    final isActive =
        widget.item.status == DownloadStatus.downloadingVideo ||
        widget.item.status == DownloadStatus.downloadingAudio ||
        widget.item.status == DownloadStatus.merging;

    final theme = Theme.of(context);
    final isCompleted = widget.item.status == DownloadStatus.completed;
    final isFailed = widget.item.status == DownloadStatus.failed;

    return Container(
      height:
          136, // Slightly increased height to prevent clipping when title, error, and progress are visible
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thumbnail (Left side, full height)
            // "make it from top to bottom with no margin or with a little margin" -> No margin implementation
            AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  widget.item.thumbnailPath != null &&
                      widget.item.thumbnailExists
                  ? Image.file(
                      File(widget.item.thumbnailPath!),
                      fit: BoxFit.cover,
                      cacheWidth: 480, // Optimize RAM: Limit decode size
                      errorBuilder: (_, __, ___) =>
                          _buildNetworkThumbnail(theme),
                    )
                  : _buildNetworkThumbnail(theme),
            ),

            // 2. Content (Right side)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row: Title and Actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildActions(context),
                      ],
                    ),

                    // Bottom Row: Status, Progress, Speed/Eta
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _buildStatusBadge(context),
                            const Spacer(),
                            if (widget.item.status ==
                                    DownloadStatus.downloadingVideo ||
                                widget.item.status ==
                                    DownloadStatus.downloadingAudio) ...[
                              _buildInfoTag(
                                context,
                                Icons.speed,
                                _formatSpeed(),
                              ),
                              const SizedBox(width: 10),
                              _buildInfoTag(
                                context,
                                Icons.timer_outlined,
                                _formatEta(),
                              ),
                            ] else if (isCompleted) ...[
                              _buildInfoTag(
                                context,
                                Icons.calendar_today_outlined,
                                _formatDate(widget.item.completedDate),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ), // Spacing before progress bar
                        // Progress Bar
                        if (isActive ||
                            (widget.item.progress > 0 && !isCompleted))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                end: widget.item.progress.clamp(0.0, 1.0),
                              ),
                              duration: appMotionDuration(
                                context,
                                const Duration(milliseconds: 320),
                              ),
                              curve: AppMotion.decelerate,
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 6,
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getProgressColor(context),
                                    ),
                                  ),
                            ),
                          ),

                        if (isFailed && widget.item.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.item.error!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSpeed() {
    if (widget.item.speed <= 0) return 'Starting...';
    return widget.item.formattedSpeed;
  }

  String _formatEta() {
    if (widget.item.eta <= 0) return 'Calculating...';
    return widget.item.formattedEta;
  }

  Widget _buildInfoTag(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color color = Theme.of(context).colorScheme.outline;
    String text = 'Pending';
    IconData icon = Icons.hourglass_empty_rounded;

    switch (widget.item.status) {
      case DownloadStatus.pending:
      case DownloadStatus.queued:
        color = Theme.of(context).colorScheme.outline;
        text = 'Pending';
        icon = Icons.hourglass_empty_rounded;
        break;
      case DownloadStatus.downloadingVideo:
        color = Theme.of(context).colorScheme.primary;
        text = 'Video';
        icon = Icons.videocam_outlined;
        break;
      case DownloadStatus.downloadingAudio:
        color = Theme.of(context).colorScheme.secondary;
        text = 'Audio';
        icon = Icons.audiotrack_outlined;
        break;
      case DownloadStatus.merging:
        color = Colors.orange;
        text = 'Merging';
        icon = Icons.call_merge_rounded;
        break;
      case DownloadStatus.completed:
        color = Colors.green;
        text = 'Done';
        icon = Icons.check_circle_outline_rounded;
        break;
      case DownloadStatus.failed:
        color = Theme.of(context).colorScheme.error;
        text = 'Failed';
        icon = Icons.error_outline_rounded;
        break;
      case DownloadStatus.cancelled:
        color = Theme.of(context).disabledColor;
        text = 'Cancelled';
        icon = Icons.cancel_outlined;
        break;
      case DownloadStatus.paused:
        color = Colors.amber;
        text = 'Paused';
        icon = Icons.pause_circle_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    // Helper for circular button style

    // Using simple Row of IconButtons for cleaner look on light background

    // Active Actions (downloading)
    if (widget.item.status == DownloadStatus.downloadingVideo ||
        widget.item.status == DownloadStatus.downloadingAudio ||
        widget.item.status == DownloadStatus.merging) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedButton(
            onPressed: widget.onPause,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pause_rounded, color: Colors.amber, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedButton(
            onPressed: widget.onCancel,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.stop_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
            ),
          ),
        ],
      );
    }

    // Paused Actions
    if (widget.item.status == DownloadStatus.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedButton(
            onPressed: widget.onResume,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedButton(
            onPressed: widget.onCancel,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.stop_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
            ),
          ),
        ],
      );
    }

    // Queued/Pending Actions
    if (widget.item.status == DownloadStatus.pending ||
        widget.item.status == DownloadStatus.queued) {
      return AnimatedButton(
        onPressed: widget.onCancel,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.stop_rounded,
            color: theme.colorScheme.error,
            size: 20,
          ),
        ),
      );
    }

    // History Actions
    if (widget.item.status == DownloadStatus.completed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedButton(
            onPressed: _openContainingFolder,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                color: theme.colorScheme.primary,
                size: 25,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (widget.onDelete != null)
            AnimatedButton(
              onPressed: widget.onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 25,
                ),
              ),
            ),
        ],
      );
    }

    // Failed/Cancelled Actions
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onRetry != null)
          AnimatedButton(
            onPressed: widget.onRetry,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ),
          ),
        const SizedBox(width: 4),
        if (widget.onDelete != null)
          AnimatedButton(
            onPressed: widget.onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Color _getProgressColor(BuildContext context) {
    if (widget.item.status == DownloadStatus.merging) {
      return Colors.orangeAccent;
    }
    if (widget.item.status == DownloadStatus.downloadingAudio) {
      return Colors.deepPurpleAccent;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildNetworkThumbnail(ThemeData theme) {
    return widget.item.thumbnailUrl != null
        ? CachedNetworkImage(
            imageUrl: widget.item.thumbnailUrl!,
            fit: BoxFit.cover,
            memCacheWidth: 480, // Optimize RAM: Limit decode size
            placeholder: (context, url) =>
                _buildPlaceholder(theme, Icons.movie_outlined),
            errorWidget: (context, url, error) =>
                _buildPlaceholder(theme, Icons.broken_image_outlined),
          )
        : _buildPlaceholder(theme, Icons.movie_outlined);
  }

  Widget _buildPlaceholder(ThemeData theme, IconData icon) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
