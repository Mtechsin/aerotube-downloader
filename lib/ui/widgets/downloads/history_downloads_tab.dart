import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../models/download_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/mobile_download_provider.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../services/core/file_action_service.dart';
import '../download_item_card.dart';
import '../motion_effects.dart';

class HistoryDownloadsTab extends StatelessWidget {
  const HistoryDownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DownloadItem> downloads = PlatformUtils.isMobile
        ? context.select<MobileDownloadProvider, List<DownloadItem>>(
            (p) => [...p.completedDownloads, ...p.failedDownloads],
          )
        : context.select<DownloadProvider, List<DownloadItem>>(
            (p) => p.historyDownloads,
          );
    final theme = Theme.of(context);

    if (downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 56,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No finished downloads yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final item = downloads[index];
        // No per-card entrance: the view-level shared-axis transition on the
        // tab switch is the single motion for this screen.
        return CompletionPop.recent(
          item,
          child: DownloadItemCard(
            key: ValueKey(item.id),
            item: item,
            onDelete: () {
              if (PlatformUtils.isMobile) {
                context.read<MobileDownloadProvider>().removeDownload(item.id);
              } else {
                context.read<DownloadProvider>().deleteFromHistory(item.id);
              }
            },
            onOpenFolder: () {
              final targetPath = item.savePath ?? item.outputPath;
              FileActionService().openFolder(targetPath);
            },
            onRetry:
                (item.status == DownloadStatus.failed ||
                    item.status == DownloadStatus.cancelled)
                ? () {
                    if (PlatformUtils.isMobile) {
                      context.read<MobileDownloadProvider>().retryDownload(
                        item.id,
                      );
                    } else {
                      context.read<DownloadProvider>().retryDownload(item.id);
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}
