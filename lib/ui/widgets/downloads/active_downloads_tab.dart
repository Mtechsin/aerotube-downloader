import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../models/download_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/mobile_download_provider.dart';
import '../../../core/utils/platform_utils.dart';
import '../download_item_card.dart';
import '../motion_effects.dart';

class ActiveDownloadsTab extends StatelessWidget {
  const ActiveDownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DownloadItem> downloads = PlatformUtils.isMobile
        ? context.select<MobileDownloadProvider, List<DownloadItem>>(
            (p) => p.activeDownloads,
          )
        : context.select<DownloadProvider, List<DownloadItem>>(
            (p) => p.activeDownloads,
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
                Icons.download_outlined,
                size: 56,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No active downloads',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a URL to start!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
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
        return CompletionPop(
          completed: item.status == DownloadStatus.completed,
          child: DownloadItemCard(
            key: ValueKey(item.id),
            item: item,
            onCancel: () {
              if (PlatformUtils.isMobile) {
                context.read<MobileDownloadProvider>().cancelDownload(item.id);
              } else {
                context.read<DownloadProvider>().cancelDownload(item.id);
              }
            },
            onPause: () {
              if (PlatformUtils.isMobile) {
                context.read<MobileDownloadProvider>().pauseDownload(item.id);
              } else {
                context.read<DownloadProvider>().pauseDownload(item.id);
              }
            },
            onResume: () {
              if (PlatformUtils.isMobile) {
                context.read<MobileDownloadProvider>().resumeDownload(item.id);
              } else {
                context.read<DownloadProvider>().resumeDownload(item.id);
              }
            },
          ),
        );
      },
    );
  }
}
