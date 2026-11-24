import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/download_item.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../components/aero_progress.dart';

/// Persistent 56 dp mini download tray docked above bottom nav (on Android / mobile)
/// or docked at the bottom of the main content column (on Windows / desktop).
///
/// Shows top active download, thin progress line, and pause/cancel button.
/// Tap anywhere on the tray navigates to the Library tab (index 2).
class MiniDownloadTray extends StatelessWidget {
  const MiniDownloadTray({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isMobile) {
      final activeDownloads = context
          .select<MobileDownloadProvider, List<DownloadItem>>(
            (p) => p.activeDownloads,
          );
      if (activeDownloads.isEmpty) return const SizedBox.shrink();
      final topItem = activeDownloads.first;
      return _TrayContent(
        item: topItem,
        onPause: () {
          context.read<MobileDownloadProvider>().pauseDownload(topItem.id);
        },
        onResume: () {
          context.read<MobileDownloadProvider>().resumeDownload(topItem.id);
        },
        onCancel: () {
          context.read<MobileDownloadProvider>().cancelDownload(topItem.id);
        },
      );
    } else {
      final activeDownloads = context
          .select<DownloadProvider, List<DownloadItem>>(
            (p) => p.activeDownloads,
          );
      if (activeDownloads.isEmpty) return const SizedBox.shrink();
      final topItem = activeDownloads.first;
      return _TrayContent(
        item: topItem,
        onPause: () {
          context.read<DownloadProvider>().pauseDownload(topItem.id);
        },
        onResume: () {
          context.read<DownloadProvider>().resumeDownload(topItem.id);
        },
        onCancel: () {
          context.read<DownloadProvider>().cancelDownload(topItem.id);
        },
      );
    }
  }
}

class _TrayContent extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _TrayContent({
    required this.item,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  String _formatSubtitle() {
    final speed = item.speed > 0
        ? '${(item.speed / (1024 * 1024)).toStringAsFixed(1)} MB/s'
        : null;
    final percent = (item.progress * 100).clamp(0, 100).toInt();

    final parts = <String>[];
    if (item.audioOnly) {
      parts.add('Audio');
    } else if (item.videoQuality != null && item.videoQuality!.isNotEmpty) {
      parts.add(item.videoQuality!);
    }

    if (item.status == DownloadStatus.paused) {
      parts.add('Paused');
    } else if (item.status == DownloadStatus.merging) {
      parts.add('Merging');
    } else if (speed != null) {
      parts.add(speed);
    }

    parts.add('$percent%');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final isPaused = item.status == DownloadStatus.paused;

    return Material(
      color: colors.surface1,
      child: InkWell(
        onTap: () {
          context.read<NavigationProvider>().switchToLibrary();
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.outline, width: 0.5),
              bottom: BorderSide(color: colors.outline, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              // Thin progress line at the very top of the tray
              AeroProgress(
                value: isPaused
                    ? item.progress
                    : (item.progress > 0 ? item.progress : null),
                height: 2.0,
                color: isPaused ? colors.warning : colors.primary,
                backgroundColor: colors.surface3.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Status or download icon
                      Icon(
                        isPaused
                            ? Symbols.pause_circle_filled_rounded
                            : Symbols.downloading_rounded,
                        size: 22,
                        color: isPaused ? colors.warning : colors.primary,
                      ),
                      const SizedBox(width: 12),
                      // Title and status line
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AeroText.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatSubtitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AeroText.caption
                                  .copyWith(color: colors.onSurfaceMuted)
                                  .withTabularFigures(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Pause / Resume toggle button
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: isPaused ? 'Resume' : 'Pause',
                        icon: Icon(
                          isPaused
                              ? Symbols.play_arrow_rounded
                              : Symbols.pause_rounded,
                          color: colors.onSurfaceMuted,
                        ),
                        onPressed: isPaused ? onResume : onPause,
                      ),
                      // Cancel button
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Cancel',
                        icon: Icon(
                          Symbols.close_rounded,
                          color: colors.onSurfaceMuted,
                        ),
                        onPressed: onCancel,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
