import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../models/download_item.dart';
import '../widgets/downloads/active_downloads_tab.dart';
import '../widgets/downloads/history_downloads_tab.dart';
import '../widgets/animated_button.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildStatusIndicators(context),
          const SizedBox(height: 16),
          // Tab Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTabSegmentedControl(),
          ),
          const SizedBox(height: 16),

          // Content View
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: PlatformUtils.isAndroid
                  ? (_selectedIndex == 0
                        ? _buildMobileDownloadsList(
                            context,
                            context
                                .watch<MobileDownloadProvider>()
                                .activeDownloads,
                            emptyTitle: 'No active downloads',
                            emptySubtitle: 'Paste a URL to start!',
                            emptyIcon: Icons.download_outlined,
                            onAction: (item) => context
                                .read<MobileDownloadProvider>()
                                .cancelDownload(item.id),
                            isHistory: false,
                          )
                        : _buildMobileDownloadsList(
                            context,
                            [
                              ...context
                                  .watch<MobileDownloadProvider>()
                                  .completedDownloads,
                              ...context
                                  .watch<MobileDownloadProvider>()
                                  .failedDownloads,
                            ],
                            emptyTitle: 'No finished downloads yet',
                            emptySubtitle: null,
                            emptyIcon: Icons.history,
                            onAction: (item) async {
                              context
                                  .read<MobileDownloadProvider>()
                                  .removeDownload(item.id);
                            },
                            isHistory: true,
                          ))
                  : (_selectedIndex == 0
                        ? const ActiveDownloadsTab()
                        : const HistoryDownloadsTab()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Downloads',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 28.0,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.folder_open_rounded, color: Colors.grey[400]),
                onPressed: () async {
                  final settingsProvider = context
                      .read<PlatformSettingsProvider>();
                  final outputPath =
                      settingsProvider.settings.outputPath ??
                      (Platform.isWindows
                          ? '${Platform.environment['USERPROFILE']}\\Downloads'
                          : await settingsProvider.getDefaultOutputPath());

                  final dir = Directory(outputPath);
                  if (!await dir.exists()) {
                    await dir.create(recursive: true);
                  }

                  if (Platform.isWindows) {
                    Process.run('explorer', [outputPath]);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloads folder: $outputPath'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                tooltip: 'Open Downloads Folder',
              ),
              PopupMenuButton<String>(
                iconColor: Colors.grey[400],
                color: theme.colorScheme.surface,
                onSelected: (value) {
                  if (value == 'clear_finished') {
                    if (PlatformUtils.isAndroid) {
                      context.read<MobileDownloadProvider>().clearCompleted();
                      context.read<MobileDownloadProvider>().clearFailed();
                      context.read<MobileDownloadProvider>().clearCancelled();
                    } else {
                      context.read<DownloadProvider>().clearCompleted();
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear_finished',
                    child: Text(
                      'Clear Finished',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSegmentedControl() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryPurple = const Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildSegmentTab('Active', 0, primaryPurple, isDark),
          _buildSegmentTab('History', 1, primaryPurple, isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(
    String label,
    int index,
    Color primaryPurple,
    bool isDark,
  ) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: AnimatedButton(
        onPressed: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(BuildContext context) {
    final primaryPurple = const Color(0xFF8B5CF6);

    if (PlatformUtils.isAndroid) {
      return Consumer<MobileDownloadProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildMobileStatusIndicator(
                  label: 'Active',
                  count: provider.activeDownloadsCount,
                  color: primaryPurple,
                ),
                const SizedBox(width: 12),
                _buildMobileStatusIndicator(
                  label: 'Done',
                  count: provider.completedDownloads.length,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _buildMobileStatusIndicator(
                  label: 'Failed',
                  count: provider.failedDownloads.length,
                  color: Colors.red,
                ),
              ],
            ),
          );
        },
      );
    }

    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatusIndicator(
                context,
                label: 'Active',
                count: provider.activeRunningCount,
                color: primaryPurple,
                icon: Icons.downloading_rounded,
              ),
              const SizedBox(width: 12),
              _buildStatusIndicator(
                context,
                label: 'Pending',
                count: provider.pendingCount,
                color: Colors.orange,
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(width: 12),
              _buildStatusIndicator(
                context,
                label: 'Done',
                count: provider.completedCount,
                color: Colors.green,
                icon: Icons.check_circle_rounded,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileStatusIndicator({
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDownloadsList(
    BuildContext context,
    List<DownloadItem> downloads, {
    required String emptyTitle,
    required String? emptySubtitle,
    required IconData emptyIcon,
    required Future<void> Function(DownloadItem item) onAction,
    required bool isHistory,
  }) {
    if (downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (emptySubtitle != null)
              Text(
                emptySubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      cacheExtent: 600,
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final item = downloads[index];
        return _MobileDownloadItem(
          item: item,
          onCancel: isHistory ? null : () => onAction(item),
          onDelete: isHistory ? () => onAction(item) : null,
        );
      },
    );
  }
}

class _MobileDownloadItem extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const _MobileDownloadItem({required this.item, this.onCancel, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive =
        item.status == DownloadStatus.downloadingVideo ||
        item.status == DownloadStatus.downloadingAudio ||
        item.status == DownloadStatus.merging ||
        item.status == DownloadStatus.pending ||
        item.status == DownloadStatus.queued;
    final isFailed = item.status == DownloadStatus.failed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 56,
                  child: _buildThumbnail(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusRow(context),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (onCancel != null)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: onCancel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
          if (isActive && item.progress > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 320),
                tween: Tween<double>(begin: 0, end: item.progress),
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                    minHeight: 4,
                  );
                },
              ),
            ),
          ],
          if (isFailed && item.error != null) ...[
            const SizedBox(height: 8),
            Text(
              item.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);
    final localPath = item.thumbnailPath;

    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        cacheWidth: 256,
        errorBuilder: (_, __, ___) => _buildThumbnailFallback(theme),
      );
    }

    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        item.thumbnailUrl!,
        fit: BoxFit.cover,
        cacheWidth: 256,
        errorBuilder: (_, __, ___) => _buildThumbnailFallback(theme),
      );
    }

    return _buildThumbnailFallback(theme);
  }

  Widget _buildThumbnailFallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        item.audioOnly ? Icons.music_note_rounded : Icons.movie_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    final theme = Theme.of(context);
    final isActive =
        item.status == DownloadStatus.downloadingVideo ||
        item.status == DownloadStatus.downloadingAudio ||
        item.status == DownloadStatus.merging ||
        item.status == DownloadStatus.pending ||
        item.status == DownloadStatus.queued;
    final isCompleted = item.status == DownloadStatus.completed;

    Color color;
    String text;
    IconData icon;

    switch (item.status) {
      case DownloadStatus.pending:
        color = theme.colorScheme.outline;
        text = 'Pending';
        icon = Icons.schedule_rounded;
        break;
      case DownloadStatus.queued:
        color = Colors.orange;
        text = 'Queued';
        icon = Icons.queue_rounded;
        break;
      case DownloadStatus.downloadingVideo:
        color = theme.colorScheme.primary;
        text = 'Video';
        icon = Icons.videocam_rounded;
        break;
      case DownloadStatus.downloadingAudio:
        color = Colors.amber;
        text = 'Audio';
        icon = Icons.music_note_rounded;
        break;
      case DownloadStatus.merging:
        color = Colors.orange;
        text = 'Merging';
        icon = Icons.merge_rounded;
        break;
      case DownloadStatus.completed:
        color = Colors.green;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
      case DownloadStatus.failed:
        color = theme.colorScheme.error;
        text = 'Failed';
        icon = Icons.error_rounded;
        break;
      case DownloadStatus.cancelled:
        color = theme.colorScheme.outline;
        text = 'Cancelled';
        icon = Icons.cancel_rounded;
        break;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (isActive)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              item.formattedSpeed,
              key: ValueKey('${item.id}-${item.speed.toStringAsFixed(1)}'),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        if (isCompleted)
          Text(
            _formatSize(item.totalBytes ?? 0),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
