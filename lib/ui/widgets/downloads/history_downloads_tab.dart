import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/download_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/mobile_download_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/theme/tokens/typography.dart';
import '../../../services/core/file_action_service.dart';
import '../../components/aero_button.dart';
import '../../components/aero_dialog.dart';
import '../../components/empty_state.dart';
import '../download_item_card.dart';

class HistoryDownloadsTab extends StatelessWidget {
  const HistoryDownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DownloadItem> downloads = PlatformUtils.isMobile
        ? context.select<MobileDownloadProvider, List<DownloadItem>>(
            (p) => [
              ...p.completedDownloads,
              ...p.failedDownloads,
              ...p.cancelledDownloads,
            ],
          )
        : context.select<DownloadProvider, List<DownloadItem>>(
            (p) => p.historyDownloads,
          );

    if (downloads.isEmpty) {
      return EmptyState(
        icon: Symbols.history_rounded,
        title: 'No downloads in history',
        description: 'Finished, failed, and cancelled transfers appear here.',
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
              isHistory: true,
              onDelete: () async {
                // H20: confirm before destroying a history entry.
                final aero = context.aero;
                final confirmed = await showAeroDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AeroDialog(
                    titleText: 'Remove download?',
                    content: Text(
                      '"${item.title}" will be removed from history. '
                      'The downloaded file is not deleted.',
                      style: AeroText.body.copyWith(color: aero.onSurfaceMuted),
                    ),
                    actions: [
                      AeroButton(
                        variant: AeroButtonVariant.ghost,
                        text: 'Cancel',
                        onPressed: () => Navigator.pop(dialogContext, false),
                      ),
                      AeroButton(
                        variant: AeroButtonVariant.danger,
                        text: 'Remove',
                        onPressed: () => Navigator.pop(dialogContext, true),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                if (PlatformUtils.isMobile) {
                  context.read<MobileDownloadProvider>().removeDownload(
                    item.id,
                  );
                } else {
                  context.read<DownloadProvider>().deleteFromHistory(item.id);
                }
              },
              onOpenFolder: () async {
                final targetPath = item.savePath ?? item.outputPath;
                if (targetPath.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No file path available for this download.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                final opened = await FileActionService().openFolder(targetPath);
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not open folder. Path: $targetPath'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
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
            );
          },
        ),
      ),
    );
  }
}
