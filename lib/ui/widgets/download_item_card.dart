import 'package:material_symbols_icons/symbols.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/download_item.dart';
import '../../services/core/file_action_service.dart';
import '../../services/core/logging_service.dart';
import '../components/aero_button.dart';
import '../components/aero_card.dart';
import '../components/aero_progress.dart';
import '../components/thumbnail_tile.dart';

/// Redesigned download card for Active and History downloads.
///
/// Follows redesign_spec.md Section 7.4:
/// - Compact layout: ThumbnailTile 96x54, Title (1-2 lines), state line
///   ("1080p MP4 · 4.2 MB/s · 00:41 left" using tabular figures),
///   AeroProgress bar (4 px), pause/cancel/resume/retry buttons.
/// - State colors: downloading = violet, merging = info shimmer, paused = warning,
///   failed = danger + one-line reason + Retry button.
/// - AeroCard with surface1 + hairline border; BoxShadow removed.
/// - History row: thumbnail, title, size, format, date, overflow action menu
///   (Open, Share, Show in folder, Delete), right-click context menu and multi-select.
class DownloadItemCard extends StatefulWidget {
  final DownloadItem item;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final bool isHistory;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectChanged;
  final bool showCheckbox;

  const DownloadItemCard({
    super.key,
    required this.item,
    this.onOpenFolder,
    this.onDelete,
    this.onRetry,
    this.onCancel,
    this.onPause,
    this.onResume,
    this.onOpen,
    this.onShare,
    this.isHistory = false,
    this.isSelected = false,
    this.onSelectChanged,
    this.showCheckbox = false,
  });

  @override
  State<DownloadItemCard> createState() => _DownloadItemCardState();
}

class _DownloadItemCardState extends State<DownloadItemCard> {
  Future<void> _openContainingFolder() async {
    final path = widget.item.savePath ?? widget.item.outputPath;
    if (path.isEmpty) {
      _showOpenFolderError(context, 'Folder path cannot be empty.');
      return;
    }

    if (PlatformUtils.isWindows) {
      try {
        final result = await Process.run('explorer.exe', ['/select,', path]);
        if (result.exitCode != 0 && result.exitCode != 1) {
          LoggingService().warning(
            'explorer /select exited with ${result.exitCode}: ${result.stderr}',
            component: 'DownloadItemCard',
          );
          if (mounted) {
            _showOpenFolderError(
              context,
              'Could not open folder (exit ${result.exitCode}). Path: $path',
            );
          }
        }
      } catch (e, st) {
        LoggingService().warning(
          'Error opening folder: $e',
          component: 'DownloadItemCard',
          error: e,
          stackTrace: st,
        );
        if (mounted) {
          _showOpenFolderError(context, 'Could not open folder: $e\n$path');
        }
      }
    } else {
      if (widget.onOpenFolder != null) {
        widget.onOpenFolder!();
      } else {
        final success = await FileActionService().openFolder(path);
        if (!success && mounted) {
          final msg = FileActionService().lastError ?? 'Could not open folder.';
          _showOpenFolderError(context, msg);
        }
      }
    }
  }

  void _showOpenFolderError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleOpenFile(
    BuildContext context,
    DownloadItem item, {
    bool useChooser = false,
  }) async {
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    final filePath = item.savePath ?? item.outputPath;
    final service = FileActionService();
    final success = await service.openFile(filePath, useChooser: useChooser);

    if (!success && context.mounted) {
      final msg = service.lastError ?? 'Could not open file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleShareFile(BuildContext context, DownloadItem item) async {
    if (widget.onShare != null) {
      widget.onShare!();
      return;
    }
    final filePath = item.savePath ?? item.outputPath;
    final service = FileActionService();
    final success = await service.shareFile(filePath, title: item.title);

    if (!success && context.mounted) {
      final msg = service.lastError ?? 'Could not share file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final aero = context.aero;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Symbols.play_arrow_rounded, size: 20, color: aero.primary),
              const SizedBox(width: 12),
              const Text('Open'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'open_with',
          child: Row(
            children: [
              Icon(
                Symbols.open_in_new_rounded,
                size: 20,
                color: aero.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('Open with...'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Symbols.share_rounded, size: 20, color: aero.onSurface),
              const SizedBox(width: 12),
              const Text('Share'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'show_folder',
          child: Row(
            children: [
              Icon(
                Symbols.folder_open_rounded,
                size: 20,
                color: aero.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('Show in folder'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Symbols.delete_rounded, size: 20, color: aero.danger),
              const SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: aero.danger)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !mounted || !context.mounted) return;
      switch (value) {
        case 'open':
          _handleOpenFile(context, widget.item);
          break;
        case 'open_with':
          _handleOpenFile(context, widget.item, useChooser: true);
          break;
        case 'share':
          _handleShareFile(context, widget.item);
          break;
        case 'show_folder':
          _openContainingFolder();
          break;
        case 'delete':
          widget.onDelete?.call();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.item.status == DownloadStatus.completed;
    final isHistoryMode = widget.isHistory || isCompleted;

    if (isHistoryMode) {
      return _buildHistoryCard(context);
    }
    return _buildActiveCard(context);
  }

  // ==========================================
  // ACTIVE DOWNLOAD CARD
  // ==========================================
  Widget _buildActiveCard(BuildContext context) {
    final aero = context.aero;
    final item = widget.item;
    final isPaused = item.status == DownloadStatus.paused;
    final isMerging = item.status == DownloadStatus.merging;
    final isFailed = item.status == DownloadStatus.failed;

    // State colors: downloading = violet, merging = info shimmer, paused = warning, failed = danger
    final Color progressColor = isFailed
        ? aero.danger
        : isPaused
        ? aero.warning
        : isMerging
        ? aero.info
        : aero.primary;

    return AeroCard(
      margin: const EdgeInsets.only(bottom: AeroSpace.sm + 4),
      padding: const EdgeInsets.all(AeroSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ThumbnailTile 96x54
              ThumbnailTile(
                width: 96,
                height: 54,
                imageUrl: item.thumbnailUrl,
                imagePath: item.thumbnailPath,
              ),
              const SizedBox(width: AeroSpace.md),

              // 2. Title & Buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AeroText.titleSm.copyWith(
                              color: aero.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: AeroSpace.xs),
                        _buildActiveActions(context, aero),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // State line: "1080p MP4 · 4.2 MB/s · 00:41 left" using tabular figures
                    _buildActiveStateLine(context, aero),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.sm),

          // 3. AeroProgress bar (4 px) with percentage
          Row(
            children: [
              Expanded(
                child: AeroProgress(
                  value: isMerging ? null : item.progress.clamp(0.0, 1.0),
                  height: 4.0,
                  color: progressColor,
                ),
              ),
              const SizedBox(width: AeroSpace.sm),
              Text(
                isMerging
                    ? 'Merging'
                    : isFailed
                    ? 'Failed'
                    : '${(item.progress.clamp(0.0, 1.0) * 100).toInt()}%',
                style: AeroText.caption.withTabularFigures().copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveActions(BuildContext context, AeroColors aero) {
    final item = widget.item;
    final isPaused = item.status == DownloadStatus.paused;
    final isFailed = item.status == DownloadStatus.failed;
    final isMerging = item.status == DownloadStatus.merging;

    if (isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onRetry != null)
            AeroButton(
              text: 'Retry',
              icon: const Icon(Symbols.refresh_rounded, size: 16),
              variant: AeroButtonVariant.primary,
              height: 32,
              onPressed: widget.onRetry,
            ),
          const SizedBox(width: 4),
          if (widget.onCancel != null || widget.onDelete != null)
            IconButton(
              icon: Icon(
                Symbols.close_rounded,
                size: 18,
                color: aero.onSurfaceMuted,
              ),
              tooltip: 'Cancel',
              onPressed: widget.onCancel ?? widget.onDelete,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      );
    }

    if (isPaused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Symbols.play_arrow_rounded,
              size: 20,
              color: aero.primary,
            ),
            tooltip: 'Resume',
            onPressed: widget.onResume,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(
              Symbols.close_rounded,
              size: 18,
              color: aero.onSurfaceMuted,
            ),
            tooltip: 'Cancel',
            onPressed: widget.onCancel,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      );
    }

    if (isMerging) {
      return IconButton(
        icon: Icon(Symbols.close_rounded, size: 18, color: aero.onSurfaceMuted),
        tooltip: 'Cancel',
        onPressed: widget.onCancel,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      );
    }

    // Downloading or queued / pending
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onPause != null)
          IconButton(
            icon: Icon(Symbols.pause_rounded, size: 20, color: aero.warning),
            tooltip: 'Pause',
            onPressed: widget.onPause,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        const SizedBox(width: 2),
        IconButton(
          icon: Icon(
            Symbols.close_rounded,
            size: 18,
            color: aero.onSurfaceMuted,
          ),
          tooltip: 'Cancel',
          onPressed: widget.onCancel,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildActiveStateLine(BuildContext context, AeroColors aero) {
    final item = widget.item;
    final isFailed = item.status == DownloadStatus.failed;
    final isPaused = item.status == DownloadStatus.paused;
    final isMerging = item.status == DownloadStatus.merging;

    if (isFailed) {
      final reason = item.error ?? 'Download failed';
      return Text(
        reason,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AeroText.caption.copyWith(
          color: aero.danger,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (isMerging) {
      return Text(
        item.statusText ?? 'Merging video & audio...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AeroText.caption.copyWith(
          color: aero.info,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final format = _formatFormat(item);

    if (isPaused) {
      return Text(
        '$format · Paused',
        style: AeroText.caption.withTabularFigures().copyWith(
          color: aero.warning,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // Active downloading: format · speed · eta left
    final parts = <String>[format];
    final speed = _formatSpeed(item);
    if (speed.isNotEmpty) parts.add(speed);

    final etaLeft = _formatEta(item);
    if (etaLeft.isNotEmpty) parts.add(etaLeft);

    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AeroText.caption.withTabularFigures().copyWith(
        color: aero.onSurfaceMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ==========================================
  // HISTORY DOWNLOAD ROW / CARD
  // ==========================================
  Widget _buildHistoryCard(BuildContext context) {
    final aero = context.aero;
    final item = widget.item;
    final isFailed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.cancelled;

    final cardContent = AeroCard(
      selected: widget.isSelected,
      margin: const EdgeInsets.only(bottom: AeroSpace.sm + 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AeroSpace.md,
        vertical: AeroSpace.sm + 2,
      ),
      hoverable: true,
      onTap: isFailed ? null : () => _handleOpenFile(context, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Windows Multi-select checkbox
          if (widget.showCheckbox) ...[
            Checkbox(
              value: widget.isSelected,
              onChanged: widget.onSelectChanged,
              activeColor: aero.primary,
              checkColor: aero.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: AeroRadius.smBorderRadius,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: AeroSpace.xs),
          ],

          // ThumbnailTile 96x54
          ThumbnailTile(
            width: 96,
            height: 54,
            imageUrl: item.thumbnailUrl,
            imagePath: item.thumbnailPath,
          ),
          const SizedBox(width: AeroSpace.md),

          // Title & Metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AeroText.body.copyWith(
                    color: aero.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                // size · format · date
                if (!isFailed)
                  Text(
                    _buildHistoryMetadata(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AeroText.caption.withTabularFigures().copyWith(
                      color: aero.onSurfaceMuted,
                    ),
                  )
                else
                  Text(
                    item.error ??
                        (item.status == DownloadStatus.cancelled
                            ? 'Cancelled'
                            : 'Failed'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AeroText.caption.copyWith(
                      color: aero.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AeroSpace.xs),

          // Action buttons & overflow menu
          _buildHistoryActions(context, aero),
        ],
      ),
    );

    if (PlatformUtils.isWindows) {
      return GestureDetector(
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildHistoryActions(BuildContext context, AeroColors aero) {
    final item = widget.item;
    final isFailed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.cancelled;

    if (isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onRetry != null)
            IconButton(
              icon: Icon(
                Symbols.refresh_rounded,
                size: 20,
                color: aero.primary,
              ),
              tooltip: 'Retry',
              onPressed: widget.onRetry,
            ),
          if (widget.onDelete != null)
            IconButton(
              icon: Icon(Symbols.delete_rounded, size: 20, color: aero.danger),
              tooltip: 'Delete',
              onPressed: widget.onDelete,
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Symbols.play_arrow_rounded, size: 22, color: aero.primary),
          tooltip: 'Open',
          onPressed: () => _handleOpenFile(context, item),
        ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          icon: Icon(
            Symbols.more_vert_rounded,
            size: 20,
            color: aero.onSurfaceMuted,
          ),
          color: aero.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: AeroRadius.mdBorderRadius,
            side: BorderSide(color: aero.outline),
          ),
          onSelected: (value) {
            switch (value) {
              case 'open':
                _handleOpenFile(context, item);
                break;
              case 'open_with':
                _handleOpenFile(context, item, useChooser: true);
                break;
              case 'share':
                _handleShareFile(context, item);
                break;
              case 'show_folder':
                _openContainingFolder();
                break;
              case 'delete':
                widget.onDelete?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Symbols.play_arrow_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Open'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'open_with',
              child: Row(
                children: [
                  Icon(Symbols.open_in_new_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Open with...'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Symbols.share_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'show_folder',
              child: Row(
                children: [
                  Icon(Symbols.folder_open_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Show in folder'),
                ],
              ),
            ),
            if (widget.onDelete != null) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Symbols.delete_rounded, size: 18, color: aero.danger),
                    const SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: aero.danger)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _buildHistoryMetadata(DownloadItem item) {
    final parts = <String>[];
    final size = _formatSize(item.totalBytes ?? 0);
    if (size.isNotEmpty) parts.add(size);

    final format = _formatFormat(item);
    if (format.isNotEmpty) parts.add(format);

    final date = _formatDate(item.completedDate);
    if (date.isNotEmpty) parts.add(date);

    return parts.join(' · ');
  }

  // ==========================================
  // FORMATTING HELPERS
  // ==========================================
  String _formatFormat(DownloadItem item) {
    if (item.audioOnly) {
      return item.audioQuality ?? 'MP3';
    }
    final res = item.videoQuality;
    if (res != null && res.isNotEmpty) {
      if (res.toLowerCase().contains('mp4') ||
          res.toLowerCase().contains('mkv')) {
        return res;
      }
      return '$res MP4';
    }
    return '1080p MP4';
  }

  String _formatSpeed(DownloadItem item) {
    if (item.speed <= 0) return '';
    return item.formattedSpeed;
  }

  String _formatEta(DownloadItem item) {
    if (item.eta <= 0) return '';
    final h = item.eta ~/ 3600;
    final m = (item.eta % 3600) ~/ 60;
    final s = item.eta % 60;
    final padM = m.toString().padLeft(2, '0');
    final padS = s.toString().padLeft(2, '0');
    if (h > 0) {
      final padH = h.toString().padLeft(2, '0');
      return '$padH:$padM:$padS left';
    }
    return '$padM:$padS left';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute';
    }
    if (difference.inDays == 1 ||
        (now.day - date.day == 1 && date.month == now.month)) {
      return 'Yesterday';
    }
    final months = [
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
    return '${months[date.month - 1]} ${date.day}';
  }
}
