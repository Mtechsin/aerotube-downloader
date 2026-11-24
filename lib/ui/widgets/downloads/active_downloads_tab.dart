import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/mobile_download_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../components/empty_state.dart';
import '../download_item_card.dart';

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

    if (downloads.isEmpty) {
      return EmptyState(
        icon: Symbols.download_rounded,
        title: 'No active downloads',
        description: 'Paste a video URL to start downloading',
        actionLabel: 'Go to Home',
        onAction: () => context.read<NavigationProvider>().switchToHome(),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AeroSpace.lg,
            vertical: AeroSpace.sm,
          ),
          itemCount: downloads.length,
          itemBuilder: (context, index) {
            final item = downloads[index];
            return DownloadItemCard(
              key: ValueKey(item.id),
              item: item,
              onCancel: () {
                if (PlatformUtils.isMobile) {
                  context.read<MobileDownloadProvider>().cancelDownload(
                    item.id,
                  );
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
                  context.read<MobileDownloadProvider>().resumeDownload(
                    item.id,
                  );
                } else {
                  context.read<DownloadProvider>().resumeDownload(item.id);
                }
              },
              onRetry: () {
                if (PlatformUtils.isMobile) {
                  context.read<MobileDownloadProvider>().retryDownload(item.id);
                } else {
                  context.read<DownloadProvider>().retryDownload(item.id);
                }
              },
            );
          },
        ),
      ),
    );
  }
}
