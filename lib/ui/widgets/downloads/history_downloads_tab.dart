
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../providers/download_provider.dart';
import '../download_item_card.dart';

class HistoryDownloadsTab extends StatelessWidget {
  const HistoryDownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final downloads = provider.historyDownloads;
        
        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'No finished downloads yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                     color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ).animate().fadeIn(),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: downloads.length,
          itemBuilder: (context, index) {
            final item = downloads[index];
            return DownloadItemCard(
              item: item,
              onDelete: () {
                context.read<DownloadProvider>().deleteFromHistory(item.id);
              },
              onOpenFolder: () {
                // TODO: Wire up open folder
              },
            ).animate(delay: (index * 50).ms).fadeIn().slideY(begin: 0.1);
          },
        );
      },
    );
  }
}
