import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/tool_update_provider.dart';
import '../../services/core/logging_service.dart';
import '../../providers/mobile_download_provider.dart';
import '../../core/utils/platform_utils.dart';

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
      backgroundColor = theme.colorScheme.error.withValues(alpha: 0.9);
      icon = Icons.error_rounded;
    } else if (log.isWarning) {
      backgroundColor = Colors.orange.withValues(alpha: 0.9);
      icon = Icons.warning_rounded;
    } else {
      backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.9);
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
                        color: Colors.black.withValues(alpha: 0.2),
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

// ---------------------------------------------------------------------------
// PF8 fix: granular Selectors + RepaintBoundary isolation
// ---------------------------------------------------------------------------

@immutable
class _DownloadRowSnapshot {
  const _DownloadRowSnapshot({
    required this.title,
    required this.progress,
    required this.speed,
    required this.eta,
  });

  final String title;
  final double progress;
  final double speed;
  final int eta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DownloadRowSnapshot &&
          title == other.title &&
          progress == other.progress &&
          speed == other.speed &&
          eta == other.eta;

  @override
  int get hashCode => Object.hash(title, progress, speed, eta);
}

@immutable
class _CompactSnapshot {
  const _CompactSnapshot({
    required this.activeCount,
    required this.hasValidActive,
    required this.progress,
  });

  final int activeCount;
  final bool hasValidActive;
  final double progress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CompactSnapshot &&
          activeCount == other.activeCount &&
          hasValidActive == other.hasValidActive &&
          progress == other.progress;

  @override
  int get hashCode => Object.hash(activeCount, hasValidActive, progress);
}

@immutable
class _ToolSnapshot {
  const _ToolSnapshot({
    required this.isYtdlpBusy,
    required this.isFfmpegBusy,
    this.statusMessage,
    required this.toolName,
  });

  final bool isYtdlpBusy;
  final bool isFfmpegBusy;
  final String? statusMessage;
  final String toolName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ToolSnapshot &&
          isYtdlpBusy == other.isYtdlpBusy &&
          isFfmpegBusy == other.isFfmpegBusy &&
          statusMessage == other.statusMessage &&
          toolName == other.toolName;

  @override
  int get hashCode =>
      Object.hash(isYtdlpBusy, isFfmpegBusy, statusMessage, toolName);
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

/// Download progress widget — PF8: Selector + RepaintBoundary isolated.
class _DownloadProgressWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isMobile) {
      return Selector<MobileDownloadProvider, int>(
        selector: (_, p) => p.activeDownloadsCount,
        builder: (context, activeCount, _) {
          if (activeCount == 0) return const SizedBox.shrink();
          return _MobileDownloadCard(activeCount: activeCount);
        },
      );
    } else {
      return Selector<DownloadProvider, int>(
        selector: (_, p) => p.activeCount,
        builder: (context, activeCount, _) {
          if (activeCount == 0) return const SizedBox.shrink();
          return _DesktopDownloadCard(activeCount: activeCount);
        },
      );
    }
  }
}

class _MobileDownloadCard extends StatelessWidget {
  const _MobileDownloadCard({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — static, does not rebuild on progress ticks
                  _DownloadHeader(activeCount: activeCount),
                  const SizedBox(height: 12),
                  // Rows — each isolates its own progress slice
                  _MobileDownloadRow(index: 0),
                  _MobileDownloadRow(index: 1),
                  _MobileDownloadRow(index: 2),
                  if (activeCount > 3)
                    Text(
                      '+${activeCount - 3} more',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOut)
        .fadeIn(duration: 300.ms);
  }
}

class _DesktopDownloadCard extends StatelessWidget {
  const _DesktopDownloadCard({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DownloadHeader(activeCount: activeCount),
                  const SizedBox(height: 12),
                  _DesktopDownloadRow(index: 0),
                  _DesktopDownloadRow(index: 1),
                  _DesktopDownloadRow(index: 2),
                  if (activeCount > 3)
                    Text(
                      '+${activeCount - 3} more',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOut)
        .fadeIn(duration: 300.ms);
  }
}

class _DownloadHeader extends StatelessWidget {
  const _DownloadHeader({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.download_rounded,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          activeCount == 1 ? 'Downloading...' : '$activeCount downloads active',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _MobileDownloadRow extends StatelessWidget {
  const _MobileDownloadRow({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Selector<MobileDownloadProvider, _DownloadRowSnapshot?>(
      selector: (_, p) {
        final list = p.activeDownloads;
        if (index >= list.length) return null;
        final item = list[index];
        return _DownloadRowSnapshot(
          title: item.title,
          progress: item.progress,
          speed: item.speed,
          eta: item.eta,
        );
      },
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, snap, _) {
        if (snap == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snap.title.length > 30 ? '${snap.title.substring(0, 30)}...' : snap.title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: snap.progress,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              if (snap.speed > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${_formatSpeed(snap.speed)} • ${_formatEta(snap.eta)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
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

class _DesktopDownloadRow extends StatelessWidget {
  const _DesktopDownloadRow({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Selector<DownloadProvider, _DownloadRowSnapshot?>(
      selector: (_, p) {
        final list = p.activeDownloads;
        if (index >= list.length) return null;
        final item = list[index];
        return _DownloadRowSnapshot(
          title: item.title,
          progress: item.progress,
          speed: item.speed,
          eta: item.eta,
        );
      },
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, snap, _) {
        if (snap == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snap.title.length > 30 ? '${snap.title.substring(0, 30)}...' : snap.title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: snap.progress,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              if (snap.speed > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${_formatSpeed(snap.speed)} • ${_formatEta(snap.eta)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
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

/// Tool update progress widget — PF8 Selector + RepaintBoundary.
class _ToolUpdateProgressWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<ToolUpdateProvider, _ToolSnapshot>(
      selector: (_, p) {
        final isYtdlpBusy = p.ytdlpState.isBusy;
        final isFfmpegBusy = p.ffmpegState.isBusy;
        final activeState = isYtdlpBusy ? p.ytdlpState : p.ffmpegState;
        final toolName = isYtdlpBusy ? 'yt-dlp' : 'FFmpeg';
        return _ToolSnapshot(
          isYtdlpBusy: isYtdlpBusy,
          isFfmpegBusy: isFfmpegBusy,
          statusMessage: activeState.statusMessage,
          toolName: toolName,
        );
      },
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, snap, _) {
        if (!snap.isYtdlpBusy && !snap.isFfmpegBusy) return const SizedBox.shrink();

        final theme = Theme.of(context);

        return RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header — static, does not rebuild on progress ticks
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
                              'Updating ${snap.toolName}...',
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
                      if (snap.statusMessage != null)
                        Text(
                          snap.statusMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // PF8: progress bar isolated — only this subtree rebuilds per tick
                      _ToolProgressSection(),
                    ],
                  ),
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

class _ToolProgressSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<ToolUpdateProvider, double>(
      selector: (_, p) {
        final busy = p.ytdlpState.isBusy;
        return busy ? p.ytdlpState.progress : p.ffmpegState.progress;
      },
      builder: (context, progress, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.secondary,
                  ),
                  minHeight: 6,
                ),
              ),
            ),
            if (progress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        );
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
    return Selector<DownloadProvider, _CompactSnapshot>(
      selector: (_, p) {
        final activeCount = p.activeCount;
        final hasValidActive = activeCount > 0 && p.activeDownloads.isNotEmpty;
        final progress = hasValidActive
            ? p.activeDownloads.first.progress.clamp(0.0, 1.0)
            : 0.0;
        return _CompactSnapshot(
          activeCount: activeCount,
          hasValidActive: hasValidActive,
          progress: progress,
        );
      },
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, snap, _) {
        if (snap.activeCount == 0 && !showWhenEmpty) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);

        return RepaintBoundary(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_rounded,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                if (snap.hasValidActive) ...[
                  RepaintBoundary(
                    child: SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: snap.progress,
                          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${(snap.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ] else ...[
                  Flexible(
                    child: Text(
                      'No active downloads',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
