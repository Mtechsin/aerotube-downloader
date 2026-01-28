
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../providers/download_provider.dart';
import '../download_item_card.dart';

class ActiveDownloadsTab extends StatelessWidget {
  const ActiveDownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final downloads = provider.activeDownloads;

        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'No active downloads',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  'Paste a URL to start!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ).animate().fadeIn().scale(),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: downloads.length,
          itemBuilder: (context, index) {
            final item = downloads[index];
            return DownloadItemCard(
              item: item,
              onCancel: () {
                 // Confirm dialog if needed, for now direct action
                 context.read<DownloadProvider>().cancelDownload(item.id);
              },
            ).animate(delay: (index * 50).ms).fadeIn().slideY(begin: 0.1);
          },
        );
      },
    );
  }
}
