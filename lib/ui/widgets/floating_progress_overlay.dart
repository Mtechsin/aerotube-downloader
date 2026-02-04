import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/tool_update_provider.dart';
import '../../services/logging_service.dart';

/// Floating widget that shows download progress and user logs
class FloatingProgressOverlay extends StatelessWidget {
  const FloatingProgressOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // User logs (top-right)
        Positioned(top: 20, right: 20, child: _UserLogsWidget()),

        // Download progress (bottom-right)
        Positioned(bottom: 20, right: 20, child: _DownloadProgressWidget()),

        // Tool update progress (bottom-left, shows during updates)
        Positioned(bottom: 20, left: 20, child: _ToolUpdateProgressWidget()),
      ],
    );
  }
}

/// User-facing logs widget (temporary notifications)
class _UserLogsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserLogEntry>>(
      stream: LoggingService().userLogsStream,
      initialData: const [],
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

        if (logs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: logs.map((log) => _buildLogCard(context, log)).toList(),
        );
      },
    );
  }

  Widget _buildLogCard(BuildContext context, UserLogEntry log) {
    final theme = Theme.of(context);

    Color backgroundColor;
    IconData icon;

    if (log.isError) {
      backgroundColor = theme.colorScheme.error.withOpacity(0.9);
      icon = Icons.error_rounded;
    } else if (log.isWarning) {
      backgroundColor = Colors.orange.withOpacity(0.9);
      icon = Icons.warning_rounded;
    } else {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.9);
      icon = Icons.info_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child:
          Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          log.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => LoggingService().dismissUserLog(log.id),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .slideX(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut)
              .fadeIn(duration: 200.ms),
    );
  }
}

/// Download progress widget
class _DownloadProgressWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final activeCount = provider.activeCount;

        if (activeCount == 0) return const SizedBox.shrink();

        final theme = Theme.of(context);

        return Material(
              color: Colors.transparent,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activeCount == 1
                              ? 'Downloading...'
                              : '$activeCount downloads active',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Show first 3 active downloads
                    ...provider.activeDownloads.take(3).map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title.length > 30
                                  ? '${item.title.substring(0, 30)}...'
                                  : item.title,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: item.progress,
                                backgroundColor: theme.colorScheme.onSurface
                                    .withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                                minHeight: 6,
                              ),
                            ),
                            if (item.speed != null && item.speed! > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${_formatSpeed(item.speed!)} • ${_formatEta(item.eta)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    if (provider.activeDownloads.length > 3)
                      Text(
                        '+${provider.activeDownloads.length - 3} more',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            )
            .animate()
            .slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOut)
            .fadeIn(duration: 300.ms);
      },
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String _formatEta(int? seconds) {
    if (seconds == null || seconds <= 0) return 'calculating...';
    if (seconds < 60) return '${seconds}s remaining';
    if (seconds < 3600) return '${(seconds / 60).floor()}m remaining';
    return '${(seconds / 3600).floor()}h ${((seconds % 3600) / 60).floor()}m remaining';
  }
}

/// Tool update progress widget
class _ToolUpdateProgressWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ToolUpdateProvider>(
      builder: (context, provider, child) {
        final isYtdlpBusy = provider.ytdlpState.isBusy;
        final isFfmpegBusy = provider.ffmpegState.isBusy;

        if (!isYtdlpBusy && !isFfmpegBusy) return const SizedBox.shrink();

        final theme = Theme.of(context);

        // Show the active update
        final activeState = isYtdlpBusy
            ? provider.ytdlpState
            : provider.ffmpegState;
        final toolName = isYtdlpBusy ? 'yt-dlp' : 'FFmpeg';

        return Material(
              color: Colors.transparent,
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Updating $toolName...',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeState.statusMessage != null)
                      Text(
                        activeState.statusMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: activeState.progress > 0
                            ? activeState.progress
                            : null,
                        backgroundColor: theme.colorScheme.onSurface
                            .withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    if (activeState.progress > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${(activeState.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
            .animate()
            .slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOut)
            .fadeIn(duration: 300.ms);
      },
    );
  }
}

/// A simpler inline widget for showing download progress in a smaller space
class CompactDownloadProgress extends StatelessWidget {
  final bool showWhenEmpty;

  const CompactDownloadProgress({super.key, this.showWhenEmpty = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final activeCount = provider.activeCount;

        if (activeCount == 0 && !showWhenEmpty) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_rounded,
                color: theme.colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              if (activeCount > 0) ...[
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: provider.activeDownloads.first.progress,
                      backgroundColor: theme.colorScheme.onSurface.withOpacity(
                        0.1,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(provider.activeDownloads.first.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Text(
                  'No active downloads',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
